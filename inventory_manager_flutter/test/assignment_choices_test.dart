import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/models/personnel.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/views/peripherals_view.dart';

class AssignmentInventory extends InventoryProvider {
  @override List<Personnel> get personnel => [Personnel(id: 'person-1', fullName: 'Test Owner')];
  @override List<Asset> get workstations => [Asset(id:'WS-1',name:'PC',category:'Workstation',serial:'',status:'Assigned',assignee:'Test Owner',dateAdded:'2026-10-01',customFields:{})];
}
void main() {
  testWidgets('peripheral assignment offers people and workstation owners on a phone', (tester) async {
    tester.view.physicalSize=const Size(390,844); tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<InventoryProvider>(create:(_)=>AssignmentInventory(),child:const MaterialApp(home:Scaffold(body:AssetFormDialog(category:'Keyboard')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned').first); await tester.pumpAndSettle();
    expect(find.text('Person: Test Owner'),findsOneWidget);
    expect(find.text('Workstation: WS-1 — Test Owner'),findsOneWidget);
    await tester.tap(find.text('Person: Test Owner')); await tester.pumpAndSettle();
    expect(find.text('Person: Test Owner'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
}
