/// Lepu SDK device model constants.
///
/// These constants map to `Bluetooth.MODEL_*` values in the Android SDK.
/// Use them when calling [BluetodevController.scan] with model filters
/// or when checking which device type was discovered.
class DeviceModels {
  DeviceModels._();

  // ═══════════════════════════════════════════════════════════════
  // ECG — ER1 family
  // ═══════════════════════════════════════════════════════════════
  static const int er1 = 11;
  static const int er1N = 28;
  static const int hhm1 = 27;
  static const int er1s = 64;
  static const int er1S = 65;
  static const int er1H = 78;
  static const int er1W = 82;
  static const int er1L = 91;

  static const List<int> er1Family = [
    er1,
    er1N,
    hhm1,
    er1s,
    er1S,
    er1H,
    er1W,
    er1L,
  ];

  // ═══════════════════════════════════════════════════════════════
  // ECG — ER2 family
  // ═══════════════════════════════════════════════════════════════
  static const int er2 = 12;
  static const int lpEr2 = 13;
  static const int duoek = 33;
  static const int lepuEr2 = 75;
  static const int hhm2 = 29;
  static const int hhm3 = 30;
  static const int er2S = 14;

  static const List<int> er2Family = [
    er2,
    lpEr2,
    duoek,
    lepuEr2,
    hhm2,
    hhm3,
    er2S,
  ];

  // ═══════════════════════════════════════════════════════════════
  // ECG — ER3
  // ═══════════════════════════════════════════════════════════════
  static const int er3 = 38;
  static const int m12 = 67;

  static const List<int> er3Family = [er3, m12];

  /// All ECG models
  static const List<int> allEcg = [...er1Family, ...er2Family, ...er3Family];

  // ═══════════════════════════════════════════════════════════════
  // Oximeter — O2Ring family
  // ═══════════════════════════════════════════════════════════════
  static const int o2ring = 6;
  static const int o2m = 7;
  static const int babyO2 = 18;
  static const int babyO2N = 57;
  static const int checkO2 = 19;
  static const int sleepO2 = 20;
  static const int snoreO2 = 21;
  static const int wearO2 = 24;
  static const int sleepU = 22;
  static const int oxylink = 23;
  static const int kidsO2 = 25;
  static const int oxyfit = 26;
  static const int oxyring = 58;
  static const int bbsmS1 = 59;
  static const int bbsmS2 = 60;
  static const int oxyu = 61;
  static const int aiS100 = 63;
  static const int o2mWps = 79;
  static const int cmring = 80;
  static const int oxyfitWps = 81;
  static const int kidsO2Wps = 83;
  static const int bbsmS3 = 84;
  static const int o2ringRe = 85;
  static const int o2ringF = 99;

  static const List<int> o2RingFamily = [
    o2ring,
    o2m,
    babyO2,
    babyO2N,
    checkO2,
    sleepO2,
    snoreO2,
    wearO2,
    sleepU,
    oxylink,
    kidsO2,
    oxyfit,
    oxyring,
    bbsmS1,
    bbsmS2,
    oxyu,
    aiS100,
    o2mWps,
    cmring,
    oxyfitWps,
    kidsO2Wps,
    bbsmS3,
    o2ringRe,
    o2ringF,
  ];

  // ═══════════════════════════════════════════════════════════════
  // Oximeter — PC60FW / PF10 family
  // ═══════════════════════════════════════════════════════════════
  static const int pc60fw = 1;
  static const int pc60nw = 31;
  static const int pc60nw1 = 32;
  static const int pc66b = 34;
  static const int pf10 = 3;
  static const int pf20 = 4;
  static const int oxysmart = 35;
  static const int pod2b = 36;
  static const int pod1w = 37;
  static const int s5w = 39;

  static const List<int> pc60fwFamily = [
    pc60fw,
    pc60nw,
    pc60nw1,
    pc66b,
    pf10,
    pf20,
    oxysmart,
    pod2b,
    pod1w,
    s5w,
  ];

  // ═══════════════════════════════════════════════════════════════
  // Oximeter — PF10AW1 / PF10BWS family
  // ═══════════════════════════════════════════════════════════════
  static const int pf10Aw1 = 73;
  static const int pf10Bws = 70;
  static const int sa10AwPu = 71;
  static const int pf10BwVe = 72;

  static const List<int> pf10Aw1Family = [pf10Aw1, pf10Bws, sa10AwPu, pf10BwVe];

  /// All oximeter models
  static const List<int> allOximeter = [
    ...o2RingFamily,
    ...pc60fwFamily,
    ...pf10Aw1Family,
  ];

  // ═══════════════════════════════════════════════════════════════
  // Blood Pressure — BP2 family
  // ═══════════════════════════════════════════════════════════════
  static const int bp2 = 15;
  static const int bp2a = 16;
  static const int bp2t = 17;
  static const int bp2w = 50;
  static const int lpBp2w = 49;

  static const List<int> bp2Family = [bp2, bp2a, bp2t, bp2w, lpBp2w];

  // ═══════════════════════════════════════════════════════════════
  // Blood Pressure — BP3 family
  // ═══════════════════════════════════════════════════════════════
  static const int bp3a = 51;
  static const int bp3b = 52;
  static const int bp3c = 53;

  static const List<int> bp3Family = [bp3a, bp3b, bp3c];

  // ═══════════════════════════════════════════════════════════════
  // Blood Pressure — Others
  // ═══════════════════════════════════════════════════════════════
  static const int bpm = 10;
  static const int airbp = 69;

  /// All blood pressure models
  static const List<int> allBp = [...bp2Family, ...bp3Family, bpm, airbp];
}
