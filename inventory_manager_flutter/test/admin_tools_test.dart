import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:inventory_manager_flutter/providers/auth_provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/views/admin_tools_view.dart';

void main() {
  Widget screen(String mode, bool admin) {
    final auth = AuthProvider()
      ..setCurrentUser(User(
          id: 'test',
          name: 'Test',
          department: 'IT',
          email: 'test',
          password: '',
          isAdmin: admin));
    return MultiProvider(providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => InventoryProvider())
    ], child: MaterialApp(home: Scaffold(body: AdminToolsView(mode: mode))));
  }

  testWidgets('non-administrators cannot see any new administration tools',
      (tester) async {
    for (final mode in ['reports', 'backups', 'delete']) {
      await tester.pumpWidget(screen(mode, false));
      await tester.pump();
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('administrator report controls fit a narrow phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(screen('reports', true));
    await tester.pumpAndSettle();
    expect(find.text('Generate report'), findsOneWidget);
    expect(find.text('Download Excel'), findsOneWidget);
    await tester.tap(find.text('Inventory items'));
    await tester.pumpAndSettle();
    expect(find.text('Person-wise inventory'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
