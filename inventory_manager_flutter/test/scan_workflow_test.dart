import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/utils/scan_payload.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/views/dashboard_view.dart';

void main() {
  test('scans preserve case and support both existing QR formats', () {
    expect(parseScanPayload('  Ws-001  '), 'Ws-001');
    expect(parseScanPayload('{"tagNumber":"PER-12","assetId":"other"}'), 'PER-12');
    expect(parseScanPayload('{"assetId":"WS-9"}'), 'WS-9');
  });
  test('damaged, empty and unrelated QR payloads are rejected', () {
    for (final code in ['', '{bad', '{}', 'https://example.com', 'a\nb']) {
      expect(() => parseScanPayload(code), throwsFormatException);
    }
  });
  testWidgets('mobile dashboard fits narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(create: (_) => InventoryProvider(), child: const MaterialApp(home: DashboardView())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
