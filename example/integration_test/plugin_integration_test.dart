// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bluetodev/bluetodev.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('initService test', (WidgetTester tester) async {
    // BluetodevController uses static methods, no instantiation needed.
    // initService should return a bool (true/false) without throwing.
    final bool result = await BluetodevController.initService();
    expect(result, isA<bool>());
  });
}
