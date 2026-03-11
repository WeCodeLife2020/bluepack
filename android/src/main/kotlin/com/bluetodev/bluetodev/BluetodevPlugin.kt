package com.bluetodev.bluetodev

import android.Manifest
import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.jeremyliao.liveeventbus.LiveEventBus
import com.lepu.blepro.constants.Ble
import com.lepu.blepro.event.EventMsgConst
import com.lepu.blepro.event.InterfaceEvent
import com.lepu.blepro.ext.BleServiceHelper
import com.lepu.blepro.objs.Bluetooth
import com.lepu.blepro.objs.BluetoothController
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import no.nordicsemi.android.ble.observer.ConnectionObserver

import cn.icomon.icdevicemanager.ICDeviceManager
import cn.icomon.icdevicemanager.callback.ICScanDeviceDelegate
import cn.icomon.icdevicemanager.model.device.ICDevice
import cn.icomon.icdevicemanager.model.device.ICScanDeviceInfo
import cn.icomon.icdevicemanager.model.device.ICUserInfo
import cn.icomon.icdevicemanager.model.other.ICConstant
import cn.icomon.icdevicemanager.model.other.ICDeviceManagerConfig
import cn.icomon.icdevicemanager.model.data.ICWeightData
import cn.icomon.icdevicemanager.model.data.ICWeightCenterData

/**
 * BluetodevPlugin — Flutter MethodChannel + EventChannel bridge to Lepu BLE SDK.
 *
 * MethodChannel "viatom_ble"         → commands (scan, connect, startMeasurement, etc.)
 * EventChannel "viatom_ble_stream"   → events  (scan results, connection state, RT data)
 */
class BluetodevPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val TAG = "BluetodevPlugin"
        private const val METHOD_CHANNEL = "viatom_ble"
        private const val EVENT_CHANNEL = "viatom_ble_stream"
        private const val PERMISSION_REQUEST_CODE = 9527
    }

    // ── Flutter binding ─────────────────────────────────────────────────
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private var context: Context? = null
    private var activity: Activity? = null
    private var pendingPermissionResult: Result? = null

    // ── SDK state ───────────────────────────────────────────────────────
    private var serviceInitialized = false
    private var connectedModel: Int = -1
    private val mainHandler = Handler(Looper.getMainLooper())

    // ── iComon Delegates ────────────────────────────────────────────────
    private val iComonScaleKeywords = listOf("lescale", "icomon", "fi2016", "f4", "qn-scale", "adore", "health scale", "chipsea")

    private val iComonScanDelegate = object : ICScanDeviceDelegate {
        override fun onScanResult(deviceInfo: ICScanDeviceInfo?) {
            deviceInfo?.let {
                val name = (it.name ?: "").lowercase()
                // Only emit devices that look like iComon scales
                val isScale = iComonScaleKeywords.any { kw -> name.contains(kw) }
                if (isScale) {
                    sendEvent(mapOf(
                        "event" to "deviceFound",
                        "name" to (it.name ?: ""),
                        "mac" to it.macAddr,
                        "rssi" to it.rssi,
                        "sdk" to "icomon"
                    ))
                }
            }
        }
    }

    private val iComonDeviceDelegate = object : IComonDelegateBase() {
        override fun onDeviceConnectionChanged(device: ICDevice?, state: ICConstant.ICDeviceConnectState?) {
            device?.let {
                val stateStr = if (state == ICConstant.ICDeviceConnectState.ICDeviceConnectStateConnected) "connected" else "disconnected"
                sendEvent(mapOf(
                    "event" to "connectionState",
                    "state" to stateStr,
                    "mac" to it.macAddr,
                    "sdk" to "icomon"
                ))
            }
        }

        override fun onReceiveMeasureStepData(device: ICDevice?, step: ICConstant.ICMeasureStep?, data2: Any?) {
            if (device == null || step == null || data2 == null) return
            when (step) {
                ICConstant.ICMeasureStep.ICMeasureStepMeasureWeightData -> {
                    (data2 as? ICWeightData)?.let { onReceiveWeightData(device, it) }
                }
                ICConstant.ICMeasureStep.ICMeasureStepMeasureCenterData -> {
                    (data2 as? ICWeightCenterData)?.let {
                        sendEvent(mapOf(
                            "event" to "rtData",
                            "deviceType" to "scale",
                            "deviceFamily" to "icomon",
                            "mac" to device.macAddr,
                            "sdk" to "icomon",
                            "isStabilized" to it.isStabilized,
                            "leftPercent" to it.leftPercent,
                            "rightPercent" to it.rightPercent
                        ))
                    }
                }
                ICConstant.ICMeasureStep.ICMeasureStepHrResult -> {
                    (data2 as? ICWeightData)?.let {
                        sendEvent(mapOf(
                            "event" to "rtData",
                            "deviceType" to "scale",
                            "deviceFamily" to "icomon",
                            "mac" to device.macAddr,
                            "sdk" to "icomon",
                            "hr" to it.hr,
                            "step" to "ICMeasureStepHrResult"
                        ))
                    }
                }
                ICConstant.ICMeasureStep.ICMeasureStepMeasureOver -> {
                    (data2 as? ICWeightData)?.let {
                        it.isStabilized = true
                        onReceiveWeightData(device, it)
                    }
                }
                else -> {}
            }
        }

        override fun onReceiveWeightData(device: ICDevice?, data: ICWeightData?) {
            if (device == null || data == null) return

            val w = data.weight_kg.toDouble()
            // Round helper
            fun r1(v: Double) = Math.round(v * 10.0) / 10.0
            fun r2(v: Double) = Math.round(v * 100.0) / 100.0

            // Convert percentages to kg where the original app shows kg
            val muscleKg = r1(data.musclePercent.toDouble() / 100.0 * w)
            val skeletalMuscleKg = r1(data.smPercent.toDouble() / 100.0 * w)
            val fatMassKg = r1(data.bodyFatPercent.toDouble() / 100.0 * w)

            sendEvent(mapOf(
                "event" to "rtData",
                "deviceType" to "scale",
                "deviceFamily" to "icomon",
                "mac" to device.macAddr,
                "sdk" to "icomon",
                "isLocked" to data.isStabilized,
                "weightKg" to r2(w),
                "bmi" to r1(data.bmi.toDouble()),
                "fat" to r1(data.bodyFatPercent.toDouble()),
                "fat_mass" to fatMassKg,
                "muscle" to muscleKg,
                "musclePercent" to r1(data.musclePercent.toDouble()),
                "water" to r1(data.moisturePercent.toDouble()),
                "bone" to r1(data.boneMass.toDouble()),
                "protein" to r1(data.proteinPercent.toDouble()),
                "bmr" to data.bmr,
                "visceral" to r1(data.visceralFat.toDouble()),
                "skeletal_muscle" to skeletalMuscleKg,
                "skeletalMusclePercent" to r1(data.smPercent.toDouble()),
                "subcutaneous" to r1(data.subcutaneousFatPercent.toDouble()),
                "body_age" to data.physicalAge,
                "ci" to r1(data.smi.toDouble()),
                "body_score" to r1(data.bodyScore.toDouble()),
                "temperature" to data.temperature,
                "heartRate" to data.hr,
                "impedance" to data.imp
            ))
        }
    }

    // ── All supported device models ─────────────────────────────────────
    private val allModels = intArrayOf(
        // ECG — ER1 family
        Bluetooth.MODEL_ER1, Bluetooth.MODEL_ER1_N, Bluetooth.MODEL_HHM1,
        Bluetooth.MODEL_ER1S, Bluetooth.MODEL_ER1_S, Bluetooth.MODEL_ER1_H,
        Bluetooth.MODEL_ER1_W, Bluetooth.MODEL_ER1_L,
        // ECG — ER2 family
        Bluetooth.MODEL_ER2, Bluetooth.MODEL_LP_ER2, Bluetooth.MODEL_DUOEK,
        Bluetooth.MODEL_LEPU_ER2, Bluetooth.MODEL_HHM2, Bluetooth.MODEL_HHM3,
        Bluetooth.MODEL_ER2_S,
        // ECG — ER3
        Bluetooth.MODEL_ER3, Bluetooth.MODEL_M12,
        // Oximeter — O2Ring family
        Bluetooth.MODEL_O2RING, Bluetooth.MODEL_O2M, Bluetooth.MODEL_BABYO2,
        Bluetooth.MODEL_BABYO2N, Bluetooth.MODEL_CHECKO2, Bluetooth.MODEL_SLEEPO2,
        Bluetooth.MODEL_SNOREO2, Bluetooth.MODEL_WEARO2, Bluetooth.MODEL_SLEEPU,
        Bluetooth.MODEL_OXYLINK, Bluetooth.MODEL_KIDSO2, Bluetooth.MODEL_OXYFIT,
        Bluetooth.MODEL_OXYRING, Bluetooth.MODEL_BBSM_S1, Bluetooth.MODEL_BBSM_S2,
        Bluetooth.MODEL_OXYU, Bluetooth.MODEL_AI_S100, Bluetooth.MODEL_O2M_WPS,
        Bluetooth.MODEL_CMRING, Bluetooth.MODEL_OXYFIT_WPS, Bluetooth.MODEL_KIDSO2_WPS,
        Bluetooth.MODEL_BBSM_S3, Bluetooth.MODEL_O2RING_RE, Bluetooth.MODEL_O2RINGF,
        // Oximeter — PC60FW/PF10 family
        Bluetooth.MODEL_PC60FW, Bluetooth.MODEL_PC_60NW, Bluetooth.MODEL_PC_60NW_1,
        Bluetooth.MODEL_PC66B, Bluetooth.MODEL_PF_10, Bluetooth.MODEL_PF_20,
        Bluetooth.MODEL_OXYSMART, Bluetooth.MODEL_POD2B, Bluetooth.MODEL_POD_1W,
        Bluetooth.MODEL_S5W, Bluetooth.MODEL_PF_10AW, Bluetooth.MODEL_PF_10AW1,
        Bluetooth.MODEL_PF_10BW, Bluetooth.MODEL_PF_10BW1, Bluetooth.MODEL_PF_20AW,
        Bluetooth.MODEL_PF_20B, Bluetooth.MODEL_S7W, Bluetooth.MODEL_S7BW,
        Bluetooth.MODEL_S6W, Bluetooth.MODEL_S6W1, Bluetooth.MODEL_PC60NW_BLE,
        Bluetooth.MODEL_PC60NW_WPS, Bluetooth.MODEL_PC_60NW_NO_SN,
        // Oximeter — PF10AW1/PF10BWS family
        Bluetooth.MODEL_PF_10AW_1, Bluetooth.MODEL_PF_10BWS,
        Bluetooth.MODEL_SA10AW_PU, Bluetooth.MODEL_PF10BW_VE,
        // OxyII family
        Bluetooth.MODEL_O2RING_S, Bluetooth.MODEL_S8_AW,
        Bluetooth.MODEL_BAND_WU, Bluetooth.MODEL_SHQO2_PRO,
        // BP — BP2 family
        Bluetooth.MODEL_BP2, Bluetooth.MODEL_BP2A, Bluetooth.MODEL_BP2T,
        Bluetooth.MODEL_BP2W, Bluetooth.MODEL_LP_BP2W,
        // BP — BP3 family
        Bluetooth.MODEL_BP3A, Bluetooth.MODEL_BP3B, Bluetooth.MODEL_BP3C,
        Bluetooth.MODEL_BP3D, Bluetooth.MODEL_BP3E, Bluetooth.MODEL_BP3F,
        Bluetooth.MODEL_BP3G, Bluetooth.MODEL_BP3H, Bluetooth.MODEL_BP3K,
        Bluetooth.MODEL_BP3L, Bluetooth.MODEL_BP3Z,
        // BP — others
        Bluetooth.MODEL_BPM, Bluetooth.MODEL_AIRBP,
        // PC80B
        Bluetooth.MODEL_PC80B, Bluetooth.MODEL_PC80B_BLE, Bluetooth.MODEL_PC80B_BLE2,
        // PC100
        Bluetooth.MODEL_PC100,
        // AP20
        Bluetooth.MODEL_AP20, Bluetooth.MODEL_AP20_WPS,
        // SP20
        Bluetooth.MODEL_SP20, Bluetooth.MODEL_SP20_BLE, Bluetooth.MODEL_SP20_WPS,
        // PC68B
        Bluetooth.MODEL_PC_68B,
        // PulsebitEX
        Bluetooth.MODEL_PULSEBITEX, Bluetooth.MODEL_HHM4,
        // CheckMe
        Bluetooth.MODEL_CHECKME, Bluetooth.MODEL_CHECKME_LE,
        Bluetooth.MODEL_CHECK_POD, Bluetooth.MODEL_CHECKME_POD_WPS,
        Bluetooth.MODEL_VETCORDER, Bluetooth.MODEL_CHECK_ADV,
        // PC303
        Bluetooth.MODEL_PC300, Bluetooth.MODEL_PC300_BLE,
        Bluetooth.MODEL_GM_300SNT, Bluetooth.MODEL_GM_300SNT_BLE,
        Bluetooth.MODEL_CMI_PC303,
        // Others
        Bluetooth.MODEL_TV221U, Bluetooth.MODEL_AOJ20A,
        Bluetooth.MODEL_BIOLAND_BGM, Bluetooth.MODEL_POCTOR_M3102,
        Bluetooth.MODEL_LPM311, Bluetooth.MODEL_LEM, Bluetooth.MODEL_ECN,
        Bluetooth.MODEL_LEPOD, Bluetooth.MODEL_LEPOD_PRO,
        Bluetooth.MODEL_R20, Bluetooth.MODEL_R21, Bluetooth.MODEL_R10,
        Bluetooth.MODEL_R11, Bluetooth.MODEL_LERES,
        Bluetooth.MODEL_FHR, Bluetooth.MODEL_VTM_AD5, Bluetooth.MODEL_FETAL,
        Bluetooth.MODEL_VCOMIN, Bluetooth.MODEL_BBSM_BS1,
    )

    // ════════════════════════════════════════════════════════════════════
    // FlutterPlugin lifecycle
    // ════════════════════════════════════════════════════════════════════

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        context = null
    }

    // ════════════════════════════════════════════════════════════════════
    // ActivityAware
    // ════════════════════════════════════════════════════════════════════

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }
    override fun onDetachedFromActivity() { activity = null }

    // ════════════════════════════════════════════════════════════════════
    // MethodChannel handler
    // ════════════════════════════════════════════════════════════════════

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initService"       -> handleInitService(result)
            "checkPermissions"  -> handleCheckPermissions(result)
            "requestPermissions"-> handleRequestPermissions(result)
            "scan"              -> handleStartScan(call, result)
            "stopScan"          -> handleStopScan(result)
            "connect"           -> handleConnect(call, result)
            "disconnect"        -> handleDisconnect(result)
            "startMeasurement"  -> handleStartMeasurement(call, result)
            "stopMeasurement"   -> handleStopMeasurement(call, result)
            "getDeviceInfo"     -> handleGetDeviceInfo(call, result)
            "getFileList"       -> handleGetFileList(call, result)
            "factoryReset"      -> handleFactoryReset(call, result)
            "updateUserInfo"    -> handleUpdateUserInfo(call, result)
            "isServiceReady"    -> result.success(serviceInitialized)
            "getConnectedModel" -> result.success(connectedModel)
            else                -> result.notImplemented()
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Permission handling
    // ════════════════════════════════════════════════════════════════════

    private fun handleCheckPermissions(result: Result) {
        result.success(hasBluetoothPermissions())
    }

    private fun handleRequestPermissions(result: Result) {
        if (hasBluetoothPermissions()) {
            result.success(true)
            return
        }
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "No activity to request permissions", null)
            return
        }
        pendingPermissionResult = result
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        } else {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            )
        }
        ActivityCompat.requestPermissions(act, permissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResult?.success(allGranted)
        pendingPermissionResult = null
        return true
    }

    private fun hasBluetoothPermissions(): Boolean {
        val ctx = context ?: return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // BLE Service init
    // ════════════════════════════════════════════════════════════════════

    private fun handleInitService(result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Application context is null", null)
            return
        }
        try {
            if (!serviceInitialized) {
                val app = ctx.applicationContext as Application
                registerLiveEventBus()
                BleServiceHelper.BleServiceHelper.initService(app).initLog(true)
                
                // Initialize iComon SDK
                val config = ICDeviceManagerConfig().apply {
                    context = app
                }
                val userInfo = ICUserInfo().apply {
                    age = 25
                    height = 175
                    sex = ICConstant.ICSexType.ICSexTypeMale
                    peopleType = ICConstant.ICPeopleType.ICPeopleTypeNormal
                }
                ICDeviceManager.shared().setDelegate(iComonDeviceDelegate)
                ICDeviceManager.shared().updateUserInfo(userInfo)
                ICDeviceManager.shared().initMgrWithConfig(config)

                serviceInitialized = true
            } else {
                // If already initialized, manually trigger serviceReady to unblock UI
                sendEvent(mapOf("event" to "serviceReady"))
            }
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "initService failed", e)
            result.error("INIT_FAILED", e.message, null)
        }
    }

    private fun handleUpdateUserInfo(call: MethodCall, result: Result) {
        val height = call.argument<Double>("height") ?: 170.0
        val age = call.argument<Int>("age") ?: 25
        val isMale = call.argument<Boolean>("isMale") ?: true

        val userInfo = ICUserInfo().apply {
            this.age = age
            this.height = height.toInt()
            this.sex = if (isMale) ICConstant.ICSexType.ICSexTypeMale else ICConstant.ICSexType.ICSexTypeFemal
            this.peopleType = ICConstant.ICPeopleType.ICPeopleTypeNormal
        }
        ICDeviceManager.shared().updateUserInfo(userInfo)
        result.success(true)
    }

    // ════════════════════════════════════════════════════════════════════
    // Scanning
    // ════════════════════════════════════════════════════════════════════

    private fun handleStartScan(call: MethodCall, result: Result) {
        if (!serviceInitialized) {
            result.error("NOT_INITIALIZED", "Call initService first", null)
            return
        }
        if (!hasBluetoothPermissions()) {
            result.error("NO_PERMISSION", "Bluetooth permissions not granted", null)
            return
        }
        try {
            val modelList = call.argument<List<Int>>("models")
            val models = modelList?.toIntArray() ?: allModels
            BluetoothController.clear()
            BleServiceHelper.BleServiceHelper.startScan(models)
            ICDeviceManager.shared().scanDevice(iComonScanDelegate)
            result.success(true)
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException during scan", e)
            result.error("SECURITY_EXCEPTION", "BLE scan denied: ${e.message}", null)
        } catch (e: Exception) {
            Log.e(TAG, "Scan failed", e)
            result.error("SCAN_FAILED", e.message, null)
        }
    }

    private fun handleStopScan(result: Result) {
        try {
            BleServiceHelper.BleServiceHelper.stopScan()
            ICDeviceManager.shared().stopScan()
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_SCAN_FAILED", e.message, null)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Connection
    // ════════════════════════════════════════════════════════════════════

    private fun handleConnect(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "Context is null", null)
            return
        }

        val mac = call.argument<String>("mac") ?: run {
            result.error("INVALID_ARGS", "mac is required", null)
            return
        }
        val sdk = call.argument<String>("sdk") ?: "lepu"

        if (sdk == "icomon") {
            try {
                val icDevice = ICDevice()
                icDevice.macAddr = mac
                ICDeviceManager.shared().addDevice(icDevice) { _, code ->
                    Log.d(TAG, "iComon addDevice result: $code")
                }
                result.success(true)
            } catch (e: Exception) {
                result.error("CONNECT_FAILED", e.message, null)
            }
            return
        }

        // Lepu logic
        val model = call.argument<Int>("model")
        if (model == null) {
            result.error("INVALID_ARGS", "model is required for lepu", null)
            return
        }

        try {
            val devices = BluetoothController.getDevices()
            var target: Bluetooth? = null
            for (d in devices) {
                if (d.macAddr == mac) {
                    target = d
                    break
                }
            }
            if (target == null) {
                result.error("DEVICE_NOT_FOUND", "Device $mac not in scan results", null)
                return
            }

            BleServiceHelper.BleServiceHelper.setInterfaces(model)
            BleServiceHelper.BleServiceHelper.connect(ctx.applicationContext, model, target.device)
            connectedModel = model
            result.success(true)
        } catch (e: SecurityException) {
            result.error("SECURITY_EXCEPTION", "BLE connect denied: ${e.message}", null)
        } catch (e: Exception) {
            result.error("CONNECT_FAILED", e.message, null)
        }
    }

    private fun handleDisconnect(result: Result) {
        try {
            BleServiceHelper.BleServiceHelper.disconnect(false)
            connectedModel = -1
            result.success(true)
        } catch (e: Exception) {
            result.error("DISCONNECT_FAILED", e.message, null)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Real-time measurement
    // ════════════════════════════════════════════════════════════════════

    private fun handleStartMeasurement(call: MethodCall, result: Result) {
        val model = call.argument<Int>("model") ?: connectedModel
        if (model < 0) {
            result.error("NOT_CONNECTED", "No device connected", null)
            return
        }
        try {
            BleServiceHelper.BleServiceHelper.startRtTask(model)
            result.success(true)
        } catch (e: Exception) {
            result.error("START_RT_FAILED", e.message, null)
        }
    }

    private fun handleStopMeasurement(call: MethodCall, result: Result) {
        val model = call.argument<Int>("model") ?: connectedModel
        if (model < 0) {
            result.error("NOT_CONNECTED", "No device connected", null)
            return
        }
        try {
            BleServiceHelper.BleServiceHelper.stopRtTask(model)
            result.success(true)
        } catch (e: Exception) {
            result.error("STOP_RT_FAILED", e.message, null)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // Device info / file list / factory reset
    // ════════════════════════════════════════════════════════════════════

    private fun handleGetDeviceInfo(call: MethodCall, result: Result) {
        val model = call.argument<Int>("model") ?: connectedModel
        if (model < 0) { result.error("NOT_CONNECTED", "No device connected", null); return }
        try {
            when (model) {
                Bluetooth.MODEL_ER1, Bluetooth.MODEL_ER1_N, Bluetooth.MODEL_HHM1,
                Bluetooth.MODEL_ER1S, Bluetooth.MODEL_ER1_S, Bluetooth.MODEL_ER1_H,
                Bluetooth.MODEL_ER1_W, Bluetooth.MODEL_ER1_L ->
                    BleServiceHelper.BleServiceHelper.er1GetInfo(model)
                Bluetooth.MODEL_ER2, Bluetooth.MODEL_LP_ER2, Bluetooth.MODEL_DUOEK,
                Bluetooth.MODEL_LEPU_ER2, Bluetooth.MODEL_HHM2, Bluetooth.MODEL_HHM3,
                Bluetooth.MODEL_ER2_S ->
                    BleServiceHelper.BleServiceHelper.er2GetInfo(model)
                Bluetooth.MODEL_O2RING, Bluetooth.MODEL_O2M, Bluetooth.MODEL_BABYO2,
                Bluetooth.MODEL_BABYO2N, Bluetooth.MODEL_CHECKO2, Bluetooth.MODEL_SLEEPO2,
                Bluetooth.MODEL_SNOREO2, Bluetooth.MODEL_WEARO2, Bluetooth.MODEL_SLEEPU,
                Bluetooth.MODEL_OXYLINK, Bluetooth.MODEL_KIDSO2, Bluetooth.MODEL_OXYFIT,
                Bluetooth.MODEL_OXYRING, Bluetooth.MODEL_BBSM_S1, Bluetooth.MODEL_BBSM_S2,
                Bluetooth.MODEL_OXYU, Bluetooth.MODEL_AI_S100, Bluetooth.MODEL_O2M_WPS,
                Bluetooth.MODEL_CMRING, Bluetooth.MODEL_OXYFIT_WPS, Bluetooth.MODEL_KIDSO2_WPS,
                Bluetooth.MODEL_BBSM_S3, Bluetooth.MODEL_O2RING_RE, Bluetooth.MODEL_O2RINGF ->
                    BleServiceHelper.BleServiceHelper.oxyGetInfo(model)
                Bluetooth.MODEL_BP2, Bluetooth.MODEL_BP2A, Bluetooth.MODEL_BP2T ->
                    BleServiceHelper.BleServiceHelper.bp2GetInfo(model)
                Bluetooth.MODEL_PF_10AW_1, Bluetooth.MODEL_PF_10BWS,
                Bluetooth.MODEL_SA10AW_PU, Bluetooth.MODEL_PF10BW_VE ->
                    BleServiceHelper.BleServiceHelper.pf10Aw1GetInfo(model)
                else -> {}
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("GET_INFO_FAILED", e.message, null)
        }
    }

    private fun handleGetFileList(call: MethodCall, result: Result) {
        val model = call.argument<Int>("model") ?: connectedModel
        if (model < 0) { result.error("NOT_CONNECTED", "No device connected", null); return }
        try {
            when (model) {
                Bluetooth.MODEL_ER1, Bluetooth.MODEL_ER1_N, Bluetooth.MODEL_HHM1,
                Bluetooth.MODEL_ER1S, Bluetooth.MODEL_ER1_S, Bluetooth.MODEL_ER1_H,
                Bluetooth.MODEL_ER1_W, Bluetooth.MODEL_ER1_L ->
                    BleServiceHelper.BleServiceHelper.er1GetFileList(model)
                Bluetooth.MODEL_ER2, Bluetooth.MODEL_LP_ER2, Bluetooth.MODEL_DUOEK,
                Bluetooth.MODEL_LEPU_ER2, Bluetooth.MODEL_HHM2, Bluetooth.MODEL_HHM3,
                Bluetooth.MODEL_ER2_S ->
                    BleServiceHelper.BleServiceHelper.er2GetFileList(model)
                Bluetooth.MODEL_BP2, Bluetooth.MODEL_BP2A, Bluetooth.MODEL_BP2T ->
                    BleServiceHelper.BleServiceHelper.bp2GetFileList(model)
                Bluetooth.MODEL_PF_10AW_1, Bluetooth.MODEL_PF_10BWS,
                Bluetooth.MODEL_SA10AW_PU, Bluetooth.MODEL_PF10BW_VE ->
                    BleServiceHelper.BleServiceHelper.pf10Aw1GetFileList(model)
                else -> {}
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("GET_FILE_LIST_FAILED", e.message, null)
        }
    }

    private fun handleFactoryReset(call: MethodCall, result: Result) {
        val model = call.argument<Int>("model") ?: connectedModel
        if (model < 0) { result.error("NOT_CONNECTED", "No device connected", null); return }
        try {
            when (model) {
                Bluetooth.MODEL_ER1, Bluetooth.MODEL_ER1_N, Bluetooth.MODEL_HHM1,
                Bluetooth.MODEL_ER1S, Bluetooth.MODEL_ER1_S, Bluetooth.MODEL_ER1_H,
                Bluetooth.MODEL_ER1_W, Bluetooth.MODEL_ER1_L ->
                    BleServiceHelper.BleServiceHelper.er1FactoryReset(model)
                Bluetooth.MODEL_ER2, Bluetooth.MODEL_LP_ER2, Bluetooth.MODEL_DUOEK,
                Bluetooth.MODEL_LEPU_ER2, Bluetooth.MODEL_HHM2, Bluetooth.MODEL_HHM3,
                Bluetooth.MODEL_ER2_S ->
                    BleServiceHelper.BleServiceHelper.er2FactoryReset(model)
                Bluetooth.MODEL_O2RING, Bluetooth.MODEL_O2M, Bluetooth.MODEL_BABYO2,
                Bluetooth.MODEL_BABYO2N, Bluetooth.MODEL_CHECKO2, Bluetooth.MODEL_SLEEPO2,
                Bluetooth.MODEL_SNOREO2, Bluetooth.MODEL_WEARO2, Bluetooth.MODEL_SLEEPU,
                Bluetooth.MODEL_OXYLINK, Bluetooth.MODEL_KIDSO2, Bluetooth.MODEL_OXYFIT,
                Bluetooth.MODEL_OXYRING, Bluetooth.MODEL_BBSM_S1, Bluetooth.MODEL_BBSM_S2,
                Bluetooth.MODEL_OXYU, Bluetooth.MODEL_AI_S100 ->
                    BleServiceHelper.BleServiceHelper.oxyFactoryReset(model)
                Bluetooth.MODEL_BP2, Bluetooth.MODEL_BP2A, Bluetooth.MODEL_BP2T ->
                    BleServiceHelper.BleServiceHelper.bp2FactoryReset(model)
                Bluetooth.MODEL_PF_10AW_1, Bluetooth.MODEL_PF_10BWS,
                Bluetooth.MODEL_SA10AW_PU, Bluetooth.MODEL_PF10BW_VE ->
                    BleServiceHelper.BleServiceHelper.pf10Aw1FactoryReset(model)
                else -> {}
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("FACTORY_RESET_FAILED", e.message, null)
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // LiveEventBus → EventChannel bridge
    // ════════════════════════════════════════════════════════════════════

    private fun sendEvent(map: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(map) }
    }

    private fun registerLiveEventBus() {
        // ── Service ready ───────────────────────────────────────────
        LiveEventBus.get<Boolean>(EventMsgConst.Ble.EventServiceConnectedAndInterfaceInit)
            .observeForever { _ ->
                sendEvent(mapOf("event" to "serviceReady"))
            }

        // ── Device discovered ───────────────────────────────────────
        LiveEventBus.get<Bluetooth>(EventMsgConst.Discovery.EventDeviceFound)
            .observeForever { _ ->
                val devices = BluetoothController.getDevices()
                for (d in devices) {
                    sendEvent(mapOf(
                        "event" to "deviceFound",
                        "name" to (d.name ?: ""),
                        "mac" to (d.macAddr ?: ""),
                        "model" to d.model,
                        "rssi" to d.rssi,
                        "sdk" to "lepu"
                    ))
                }
            }

        // ── Device ready (connection complete) ──────────────────────
        LiveEventBus.get<Int>(EventMsgConst.Ble.EventBleDeviceReady)
            .observeForever { model ->
                connectedModel = model
                sendEvent(mapOf(
                    "event" to "connectionState",
                    "state" to "connected",
                    "model" to model,
                ))
            }

        // ── Device disconnect reason ────────────────────────────────
        LiveEventBus.get<Int>(EventMsgConst.Ble.EventBleDeviceDisconnectReason)
            .observeForever { reason ->
                val reasonStr = when (reason) {
                    ConnectionObserver.REASON_SUCCESS -> "user_initiated"
                    ConnectionObserver.REASON_TERMINATE_LOCAL_HOST -> "local_disconnect"
                    ConnectionObserver.REASON_TERMINATE_PEER_USER -> "remote_disconnect"
                    ConnectionObserver.REASON_LINK_LOSS -> "link_loss"
                    ConnectionObserver.REASON_NOT_SUPPORTED -> "not_supported"
                    ConnectionObserver.REASON_TIMEOUT -> "timeout"
                    else -> "unknown"
                }
                connectedModel = -1
                sendEvent(mapOf(
                    "event" to "connectionState",
                    "state" to "disconnected",
                    "reason" to reasonStr,
                ))
            }

        // ════════════════════════════════════════════════════════════
        // ER1 real-time data
        // ════════════════════════════════════════════════════════════
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER1.EventEr1RtData)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.er1.RtData
                    sendEvent(mapOf(
                        "event" to "rtData",
                        "deviceType" to "ecg",
                        "deviceFamily" to "er1",
                        "model" to event.model,
                        "hr" to data.param.hr,
                        "battery" to data.param.battery,
                        "batteryState" to data.param.batteryState,
                        "recordTime" to data.param.recordTime,
                        "curStatus" to data.param.curStatus,
                        "ecgFloats" to data.wave.ecgFloats?.toList(),
                        "ecgShorts" to data.wave.ecgShorts?.toList(),
                        "samplingRate" to 125,
                        "mvConversion" to 0.002467,
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "ER1 RT error", e)
                }
            }

        // ════════════════════════════════════════════════════════════
        // ER2 real-time data
        // ════════════════════════════════════════════════════════════
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER2.EventEr2RtData)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.er2.RtData
                    sendEvent(mapOf(
                        "event" to "rtData",
                        "deviceType" to "ecg",
                        "deviceFamily" to "er2",
                        "model" to event.model,
                        "hr" to data.param.hr,
                        "battery" to data.param.battery,
                        "batteryState" to data.param.batteryState,
                        "recordTime" to data.param.recordTime,
                        "curStatus" to data.param.curStatus,
                        "ecgFloats" to data.wave.ecgFloats?.toList(),
                        "ecgShorts" to data.wave.ecgShorts?.toList(),
                        "samplingRate" to 125,
                        "mvConversion" to 0.002467,
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "ER2 RT error", e)
                }
            }

        // ER2 connection events
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER2.EventEr2SetTime)
            .observeForever { event ->
                sendEvent(mapOf(
                    "event" to "connectionState", "state" to "connected",
                    "model" to event.model, "subEvent" to "setTime",
                ))
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER2.EventEr2Info)
            .observeForever { event ->
                try {
                    sendEvent(mapOf("event" to "deviceInfo", "model" to event.model, "data" to event.data.toString()))
                } catch (e: Exception) { Log.e(TAG, "ER2 Info error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER2.EventEr2FileList)
            .observeForever { event ->
                try {
                    val files = event.data as? ArrayList<String> ?: arrayListOf()
                    sendEvent(mapOf("event" to "fileList", "model" to event.model, "files" to files))
                } catch (e: Exception) { Log.e(TAG, "ER2 FileList error", e) }
            }

        // ER1 connection events
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER1.EventEr1SetTime)
            .observeForever { event ->
                sendEvent(mapOf(
                    "event" to "connectionState", "state" to "connected",
                    "model" to event.model, "subEvent" to "setTime",
                ))
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER1.EventEr1Info)
            .observeForever { event ->
                try {
                    sendEvent(mapOf("event" to "deviceInfo", "model" to event.model, "data" to event.data.toString()))
                } catch (e: Exception) { Log.e(TAG, "ER1 Info error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.ER1.EventEr1FileList)
            .observeForever { event ->
                try {
                    val files = event.data as? ArrayList<String> ?: arrayListOf()
                    sendEvent(mapOf("event" to "fileList", "model" to event.model, "files" to files))
                } catch (e: Exception) { Log.e(TAG, "ER1 FileList error", e) }
            }

        // ════════════════════════════════════════════════════════════
        // Oximeter (O2Ring family)
        // ════════════════════════════════════════════════════════════
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Oxy.EventOxyRtParamData)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.oxy.RtParam
                    sendEvent(mapOf(
                        "event" to "rtData",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "oxy",
                        "model" to event.model,
                        "spo2" to data.spo2,
                        "pr" to data.pr,
                        "pi" to data.pi,
                        "battery" to data.battery,
                        "batteryState" to data.batteryState,
                        "state" to data.state,
                    ))
                } catch (e: Exception) { Log.e(TAG, "Oxy RT error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Oxy.EventOxyRtData)
            .observeForever { event ->
                try {
                    sendEvent(mapOf(
                        "event" to "rtWaveform",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "oxy",
                        "model" to event.model,
                        "waveData" to event.data.toString(),
                    ))
                } catch (e: Exception) { Log.e(TAG, "Oxy Wave error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Oxy.EventOxySyncDeviceInfo)
            .observeForever { event ->
                try {
                    val types = event.data as? Array<String> ?: return@observeForever
                    if (types.isNotEmpty() && types[0] == "SetTIME") {
                        sendEvent(mapOf(
                            "event" to "connectionState", "state" to "connected",
                            "model" to event.model, "subEvent" to "setTime",
                        ))
                    }
                } catch (e: Exception) { Log.e(TAG, "Oxy Sync error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Oxy.EventOxyInfo)
            .observeForever { event ->
                try {
                    sendEvent(mapOf("event" to "deviceInfo", "model" to event.model, "data" to event.data.toString()))
                } catch (e: Exception) { Log.e(TAG, "Oxy Info error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Oxy.EventOxyPpgData)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.oxy.RtPpg
                    sendEvent(mapOf(
                        "event" to "rtWaveform",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "oxy",
                        "model" to event.model,
                        "waveType" to "ppg",
                        "irSize" to data.ir.size,
                        "ir" to data.ir.toList(),
                        "red" to data.red.toList(),
                    ))
                } catch (e: Exception) { Log.e(TAG, "Oxy PPG error", e) }
            }

        // ════════════════════════════════════════════════════════════
        // PC60FW / PF10 family
        // ════════════════════════════════════════════════════════════
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.PC60Fw.EventPC60FwRtParam)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.pc60fw.RtParam
                    sendEvent(mapOf(
                        "event" to "rtData",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "pc60fw",
                        "model" to event.model,
                        "spo2" to data.spo2,
                        "pr" to data.pr,
                        "pi" to data.pi,
                    ))
                } catch (e: Exception) { Log.e(TAG, "PC60FW RT error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.PC60Fw.EventPC60FwRtWave)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.pc60fw.RtWave
                    sendEvent(mapOf(
                        "event" to "rtWaveform",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "pc60fw",
                        "model" to event.model,
                        "waveData" to data.waveIntData?.toList(),
                    ))
                } catch (e: Exception) { Log.e(TAG, "PC60FW Wave error", e) }
            }

        // ════════════════════════════════════════════════════════════
        // PF10AW1/PF10BWS family
        // ════════════════════════════════════════════════════════════
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Pf10Aw1.EventPf10Aw1RtParam)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.pf10aw1.RtParam
                    sendEvent(mapOf(
                        "event" to "rtData",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "pf10aw1",
                        "model" to event.model,
                        "spo2" to data.spo2,
                        "pr" to data.pr,
                        "pi" to data.pi,
                        "batLevel" to data.batLevel,
                    ))
                } catch (e: Exception) { Log.e(TAG, "PF10AW1 RT error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Pf10Aw1.EventPf10Aw1RtWave)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.pf10aw1.RtWave
                    sendEvent(mapOf(
                        "event" to "rtWaveform",
                        "deviceType" to "oximeter",
                        "deviceFamily" to "pf10aw1",
                        "model" to event.model,
                        "waveData" to data.waveIntData?.toList(),
                    ))
                } catch (e: Exception) { Log.e(TAG, "PF10AW1 Wave error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.Pf10Aw1.EventPf10Aw1SetTime)
            .observeForever { event ->
                sendEvent(mapOf(
                    "event" to "connectionState", "state" to "connected",
                    "model" to event.model, "subEvent" to "setTime",
                ))
            }

        // ════════════════════════════════════════════════════════════
        // BP2 real-time data
        // ════════════════════════════════════════════════════════════
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.BP2.EventBp2SyncTime)
            .observeForever { event ->
                sendEvent(mapOf(
                    "event" to "connectionState", "state" to "connected",
                    "model" to event.model, "subEvent" to "setTime",
                ))
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.BP2.EventBp2RtData)
            .observeForever { event ->
                try {
                    val data = event.data as com.lepu.blepro.ext.bp2.RtData
                    val baseMap = mutableMapOf<String, Any?>(
                        "event" to "rtData",
                        "deviceType" to "bp",
                        "deviceFamily" to "bp2",
                        "model" to event.model,
                        "deviceStatus" to data.status.deviceStatus,
                        "batteryStatus" to data.status.batteryStatus,
                        "batteryPercent" to data.status.percent,
                        "paramDataType" to data.param.paramDataType,
                    )
                    when (data.param.paramDataType) {
                        0 -> {
                            val bpIng = com.lepu.blepro.ext.bp2.RtBpIng(data.param.paramData)
                            baseMap["measureType"] = "bp_measuring"
                            baseMap["pressure"] = bpIng.pressure
                            baseMap["pr"] = bpIng.pr
                            baseMap["isDeflate"] = bpIng.isDeflate
                            baseMap["isPulse"] = bpIng.isPulse
                        }
                        1 -> {
                            val bpResult = com.lepu.blepro.ext.bp2.RtBpResult(data.param.paramData)
                            baseMap["measureType"] = "bp_result"
                            baseMap["sys"] = bpResult.sys
                            baseMap["dia"] = bpResult.dia
                            baseMap["mean"] = bpResult.mean
                            baseMap["pr"] = bpResult.pr
                            baseMap["result"] = bpResult.result
                        }
                        2 -> {
                            val ecgIng = com.lepu.blepro.ext.bp2.RtEcgIng(data.param.paramData)
                            baseMap["measureType"] = "ecg_measuring"
                            baseMap["hr"] = ecgIng.hr
                            baseMap["isLeadOff"] = ecgIng.isLeadOff
                            baseMap["isPoolSignal"] = ecgIng.isPoolSignal
                            baseMap["curDuration"] = ecgIng.curDuration
                            baseMap["ecgFloats"] = data.param.ecgFloats?.toList()
                            baseMap["ecgShorts"] = data.param.ecgShorts?.toList()
                            baseMap["samplingRate"] = 250
                            baseMap["mvConversion"] = 0.003098
                        }
                        3 -> {
                            val ecgResult = com.lepu.blepro.ext.bp2.RtEcgResult(data.param.paramData)
                            baseMap["measureType"] = "ecg_result"
                            baseMap["hr"] = ecgResult.hr
                            baseMap["qrs"] = ecgResult.qrs
                            baseMap["pvcs"] = ecgResult.pvcs
                            baseMap["qtc"] = ecgResult.qtc
                            baseMap["resultMessage"] = ecgResult.diagnosis.resultMess
                        }
                    }
                    sendEvent(baseMap)
                } catch (e: Exception) { Log.e(TAG, "BP2 RT error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.BP2.EventBp2Info)
            .observeForever { event ->
                try {
                    sendEvent(mapOf("event" to "deviceInfo", "model" to event.model, "data" to event.data.toString()))
                } catch (e: Exception) { Log.e(TAG, "BP2 Info error", e) }
            }
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.BP2.EventBp2FileList)
            .observeForever { event ->
                try {
                    val files = event.data as? ArrayList<String> ?: arrayListOf()
                    sendEvent(mapOf("event" to "fileList", "model" to event.model, "files" to files))
                } catch (e: Exception) { Log.e(TAG, "BP2 FileList error", e) }
            }

        // OxyII family
        LiveEventBus.get<InterfaceEvent>(InterfaceEvent.OxyII.EventOxyIISetTime)
            .observeForever { event ->
                sendEvent(mapOf(
                    "event" to "connectionState", "state" to "connected",
                    "model" to event.model, "subEvent" to "setTime",
                ))
            }

        // Encrypt verification (PC60FW family)
        LiveEventBus.get<InterfaceEvent>(EventMsgConst.Ble.EventBleDeviceEncryptVerificationCompleted)
            .observeForever { event ->
                sendEvent(mapOf(
                    "event" to "connectionState", "state" to "connected",
                    "model" to event.model, "subEvent" to "encryptVerified",
                ))
            }

        Log.d(TAG, "LiveEventBus observers registered")
    }
}
