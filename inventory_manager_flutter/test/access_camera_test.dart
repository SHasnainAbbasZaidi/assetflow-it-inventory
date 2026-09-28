import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
import 'package:mobile_scanner/src/objects/start_options.dart';
import 'package:inventory_manager_flutter/widgets/asset_camera.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/views/app_users_view.dart';

class FakeCamera extends MobileScannerPlatform {
  int starts = 0, stops = 0;
  bool deny = false;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const Text('Camera preview');
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    if (deny)
      throw const MobileScannerException(
          errorCode: MobileScannerErrorCode.permissionDenied);
    return const MobileScannerViewAttributes(
        currentTorchMode: TorchState.off,
        size: Size(640, 480),
        numberOfCameras: 1);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

void main() {
  testWidgets('individual access form fits a phone and keeps Save accessible',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => InventoryProvider(),
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AppUserFormDialog(
                                    user: User(
                                        id: 'test@example.com',
                                        name: 'Test',
                                        email: 'test@example.com',
                                        department: 'EDITOR',
                                        password: '',
                                        customPermissions: {
                                      for (final key in User.accessLabels.keys)
                                        key: true
                                    }))),
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Individual permissions'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(tester.getBottomRight(find.text('Save Changes')).dy, lessThan(844));
    expect(tester.takeException(), isNull);
  });
  test(
      'user permissions override role defaults without granting administrator access',
      () {
    final user = User.fromApi({
      'email': 'test',
      'role': 'VIEWER',
      'permissions': {'view': true, 'add': true, 'edit': false, 'reports': true}
    });
    expect(user.can('add'), true);
    expect(user.can('edit'), false);
    expect(user.can('reports'), true);
    expect(user.isAdmin, false);
  });
  testWidgets(
      'camera restarts on app resume and retries after permission denial',
      (tester) async {
    final old = MobileScannerPlatform.instance, fake = FakeCamera();
    MobileScannerPlatform.instance = fake;
    addTearDown(() => MobileScannerPlatform.instance = old);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(height: 260, child: AssetCamera(onCode: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.text('Camera preview'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fake.starts, 2);
    expect(fake.stops, greaterThanOrEqualTo(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    fake.deny = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(height: 260, child: AssetCamera(onCode: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Allow camera access'), findsOneWidget);
    fake.deny = false;
    await tester.tap(find.text('Retry camera'));
    await tester.pumpAndSettle();
    expect(find.text('Camera preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
