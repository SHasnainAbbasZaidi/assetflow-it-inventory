import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/main.dart';
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:inventory_manager_flutter/providers/auth_provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/utils/hardware_groups.dart';
import 'package:inventory_manager_flutter/views/main_layout.dart';

class DemoInventory extends InventoryProvider {
  @override bool get initialized => true;
  final fixtures = ['Workstation','Motherboard','Keyboard','Mouse','Printer','Webcam','RAM','SSD'].asMap().entries.map((e)=>Asset(id:'DEMO-${e.key+1001}',name:e.value,category:e.value,serial:'',status:e.key.isEven?'In Store':'Assigned',assignee:e.key.isEven?'':'Demo operator',dateAdded:'2026-09-24',customFields:{'deviceType':'Mini PC','processorGen':'Intel Core i7'})).toList();
  @override List<Asset> get assets => fixtures;
  @override List<Asset> get workstations => fixtures.where((a)=>a.category=='Workstation').toList();
  @override List<Asset> get peripherals => fixtures.where((a)=>a.category!='Workstation').toList();
}
void main() {
  test('editing retains custom values without recursively embedding saved JSON', () {
    final result=InventoryProvider.editableAssetFields({'processorGen':'i7','customFields':'{"room":"Lab 1"}','personnel':{'fullName':'Owner'}},{'cpu':'i7'});
    expect(result['room'],'Lab 1');expect(result['cpu'],'i7');expect(result.containsKey('customFields'),false);expect(result.containsKey('personnel'),false);
  });
  test('hardware classification covers requested groups and legacy names', () {
    for(final c in ['Assembled PC','Motherboard','Laptop','Mini PC','All-in-One PC']) {expect(HardwareGroups.classify(c),'Workstations');}
    for(final c in ['Keyboard','Mouse','Headphones','Unknown legacy accessory']) {expect(HardwareGroups.classify(c),'Peripherals');}
    for(final c in ['Printer','Network Device','VR','Webcam']) {expect(HardwareGroups.classify(c),'Devices');}
    for(final c in ['RAM','SSD','HDD','GPU']) {expect(HardwareGroups.classify(c),'Components');}
  });
  testWidgets('phone dashboard switches categories without overflow and preserves all items', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final fontPath=Platform.environment['ASSETFLOW_TEST_FONT'];
    if(fontPath!=null) {await tester.runAsync(() async {for(final family in ['Inter','Roboto']) {final loader=FontLoader(family)..addFont(File(fontPath).readAsBytes().then((bytes)=>ByteData.sublistView(bytes)));await loader.load();} final icons=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));await icons.load();});}
    final auth=AuthProvider()..setCurrentUser(User(id:'demo',name:'Demo operator',email:'demo@example.invalid',department:'IT',password:'',isAdmin:true));
    final capture=GlobalKey();
    await tester.pumpWidget(MultiProvider(providers:[ChangeNotifierProvider.value(value:auth),ChangeNotifierProvider<InventoryProvider>(create:(_)=>DemoInventory())],child:Builder(builder:(context){final app=const AssetFlowApp().build(context) as MaterialApp;return MaterialApp(theme:app.darkTheme,home:RepaintBoundary(key:capture,child:const MainLayout()));})));
    await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    expect(find.text('Inventory Dashboard'),findsOneWidget);
    final out=Platform.environment['ASSETFLOW_SCREENSHOTS'];
    if(out!=null) {await tester.runAsync(() async {final boundary=capture.currentContext!.findRenderObject() as RenderRepaintBoundary;final image=await boundary.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await Directory(out).create(recursive:true);await File('$out/mobile-dashboard.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});}
    await tester.ensureVisible(find.widgetWithText(ChoiceChip,'Devices  2'));await tester.tap(find.widgetWithText(ChoiceChip,'Devices  2'));await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip,'Components  2'));await tester.tap(find.widgetWithText(ChoiceChip,'Components  2'));await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    await tester.drag(find.byType(ListView).last,const Offset(0,-480));await tester.pumpAndSettle();expect(tester.takeException(),isNull);
    if(out!=null) {await tester.runAsync(() async {final boundary=capture.currentContext!.findRenderObject() as RenderRepaintBoundary;final image=await boundary.toImage(pixelRatio:2);final bytes=await image.toByteData(format:ui.ImageByteFormat.png);await File('$out/mobile-inventory.png').writeAsBytes(bytes!.buffer.asUint8List());image.dispose();});}
  });
}
