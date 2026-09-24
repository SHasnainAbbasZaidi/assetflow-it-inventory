import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager_flutter/models/asset_tag.dart';
import 'package:inventory_manager_flutter/utils/tag_pdf_service.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  AssetTag tag(String id,String category)=>AssetTag(id:id,tagNumber:id,assetId:id,purchaseDate:'2026-09-22',deviceType:category,itemCategory:category,modelName:'Test model',quantity:1,vendorName:'',requestedBy:'',purchaseCost:'',warrantyExpiry:'',department:'',notes:'',createdAt:'');
  test('mobile bulk PDF keeps compact groups on two intact A4 pages',()async{
    final tags=[...List.generate(5,(i)=>tag('WS-$i','Workstation')),...List.generate(9,(i)=>tag('PER-$i','Peripheral'))];
    final bytes=await TagPdfService.generateBulkTagsPdf(tags:tags,companyName:'Print test',companyLogo:'',config:{'showCompany':true});
    final pdf=latin1.decode(bytes);
    expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length,2);
    final path=Platform.environment['ASSETFLOW_TEST_PDF'];if(path!=null)await File(path).writeAsBytes(bytes);
  });
}
