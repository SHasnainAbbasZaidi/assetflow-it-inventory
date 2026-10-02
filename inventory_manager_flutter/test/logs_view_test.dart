import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/models/activity_log.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/views/logs_view.dart';
class LogInventory extends InventoryProvider {
  bool fail=false;
  @override List<ActivityLog> get logs=>List.generate(150,(i)=>ActivityLog(id:'$i',timestamp:'2026-10-02T10:20:30Z',user:'Operator',action:'Assigned item $i to Person',assetId:'TAG-$i',details:''));
  @override Future<bool> refreshLogs({bool older=false})async {if(fail)throw Exception('offline');return false;}
}
void main(){testWidgets('log view retains entries beyond 100 and preserves them on refresh failure',(tester)async{
  final inventory=LogInventory();
  await tester.pumpWidget(ChangeNotifierProvider<InventoryProvider>.value(value:inventory,child:const MaterialApp(home:LogsView())));
  await tester.pumpAndSettle();
  expect(find.text('Assigned item 149 to Person'),findsOneWidget);
  inventory.fail=true;
  await tester.tap(find.text('Refresh logs'));await tester.pumpAndSettle();
  expect(find.textContaining('Existing entries are preserved'),findsOneWidget);
  expect(find.text('Assigned item 149 to Person'),findsOneWidget);
  expect(tester.takeException(),isNull);
});}
