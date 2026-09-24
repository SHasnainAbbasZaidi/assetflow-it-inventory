import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/models/asset_tag.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TagPdfService {
  static Future<Uint8List> generateBulkTagsPdf({
    required List<AssetTag> tags,
    required String companyName,
    required String companyLogo,
    required Map<String, dynamic> config,
  }) async {
    final pdf = pw.Document();
    final logo = await _decodeLogo(companyLogo);
    bool isWorkstation(AssetTag tag) => const ['workstation','computer','desktop','laptop','pc','motherboard','mini pc','all-in-one pc','assembled pc'].contains(tag.itemCategory.toLowerCase());
    for (final workstation in [true, false]) {
      final group = tags.where((tag) => isWorkstation(tag) == workstation).toList();
      final perPage = workstation ? 8 : 16;
      for (var offset = 0; offset < group.length; offset += perPage) {
        final chunk = group.skip(offset).take(perPage).toList();
        pw.Widget label(AssetTag tag) {
          final fields = ['CPU: ${tag.cpu}', 'Motherboard: ${tag.motherboard}', 'RAM: ${tag.ram}', 'Storage: ${tag.storage}', 'GPU: ${tag.gpu}'];
          // Refuse unreadably dense labels; no whole-label shrinking or clipped text.
          if (tag.tagNumber.length > 66 || tag.username.length > 66 || (workstation && fields.fold<int>(0, (n,v) => n + (v.length /  fiftyChars).ceil()) > 8)) {
            throw FormatException('Tag ${tag.tagNumber} has too much text for a compact label. Use the web Tag Customizer to print a larger label.');
          }
          return pw.Container(width: 93*PdfPageFormat.mm, height:(workstation?65:30)*PdfPageFormat.mm,
            decoration: pw.BoxDecoration(border:pw.Border.all(color:PdfColors.grey400),borderRadius:pw.BorderRadius.circular(3)),
            padding:pw.EdgeInsets.all(3*PdfPageFormat.mm),
            child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
              pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
                pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[
                  pw.Text(workstation?'Device Details':'Peripheral Tag',style:pw.TextStyle(fontSize:10,fontWeight:pw.FontWeight.bold,color:PdfColors.blue700)),
                  pw.SizedBox(height:5),
                  pw.Text('Tag No: ${tag.tagNumber}',style:const pw.TextStyle(fontSize:8)),
                  pw.SizedBox(height:5),
                  pw.Text(workstation?'Username: ${tag.username}':'Date Purchase: ${tag.purchaseDate}',style:const pw.TextStyle(fontSize:8)),
                ])),
                pw.SizedBox(width:3*PdfPageFormat.mm),
                pw.Container(color:PdfColors.white,padding:const pw.EdgeInsets.all(2),child:pw.Stack(alignment:pw.Alignment.center,children:[
                  pw.BarcodeWidget(barcode:pw.Barcode.qrCode(errorCorrectLevel:pw.BarcodeQRCorrectionLevel.high),data:tag.tagNumber,width:20*PdfPageFormat.mm,height:20*PdfPageFormat.mm),
                  if(logo!=null) pw.Container(color:PdfColors.white,padding:const pw.EdgeInsets.all(1),child:pw.Image(logo,width:9,height:9)),
                ])),
              ]),
              if(workstation) ...[pw.SizedBox(height:6),for(final field in fields) pw.Padding(padding:const pw.EdgeInsets.only(bottom:3),child:pw.Text(field,style:const pw.TextStyle(fontSize:8)))],
            ]));
        }
        pdf.addPage(pw.Page(pageFormat:PdfPageFormat.a4,margin:pw.EdgeInsets.all(10*PdfPageFormat.mm),build:(_)=>pw.Column(children:[
          for(var row=0;row<chunk.length;row+=2) pw.Padding(padding:pw.EdgeInsets.only(bottom:row+2<chunk.length?4*PdfPageFormat.mm:0),child:pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[label(chunk[row]),if(row+1<chunk.length)...[pw.SizedBox(width:4*PdfPageFormat.mm),label(chunk[row+1])]])),
        ])));
      }
    }
    return pdf.save();
  }
  static const fiftyChars = 50;

  static Future<Uint8List> buildTagsPdf({
    required InventoryProvider provider,
    required List<String> assetIds,
  }) async {
    final tags = <AssetTag>[];
    for (final id in assetIds) {
      final matches = provider.assets.where((asset) => asset.id == id);
      if (matches.isNotEmpty)
        tags.add(_effectiveTag(provider.getTagByAssetId(id), matches.first));
    }
    return generateBulkTagsPdf(
        tags: tags,
        companyName: provider.companyName,
        companyLogo: provider.companyLogo,
        config: provider.tagConfig);
  }

  static Future<pw.ImageProvider?> _decodeLogo(String logoBase64) async {
    if (logoBase64.isNotEmpty) {
      try {
        final base64Content =
            logoBase64.contains(',') ? logoBase64.split(',')[1] : logoBase64;
        return pw.MemoryImage(base64Decode(base64Content));
      } catch (e) {
        debugPrint('Failed to decode logo: $e');
      }
    }

    try {
      final ByteData data =
          await rootBundle.load('assets/images/default_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Failed to load default logo: $e');
      return null;
    }
  }

  static AssetTag _effectiveTag(AssetTag? tag, Asset asset) {
    final fallbackModel = asset.customFields['model']?.toString() ?? asset.name;
    final fallbackDeviceType =
        asset.customFields['deviceType']?.toString() ?? asset.category;
    final fallbackPurchaseDate =
        asset.customFields['purchaseDate']?.toString() ?? asset.dateAdded;

    if (tag != null) return tag;

    return AssetTag(
      id: 'fallback-${asset.id}',
      tagNumber: asset.serial.isNotEmpty ? asset.serial : asset.id,
      assetId: asset.id,
      purchaseDate: fallbackPurchaseDate,
      deviceType: fallbackDeviceType,
      itemCategory: asset.category,
      modelName: fallbackModel,
      quantity: 1,
      vendorName: asset.customFields['vendorName']?.toString() ?? '',
      requestedBy: asset.customFields['requestedBy']?.toString() ?? '',
      purchaseCost: asset.customFields['purchaseCost']?.toString() ?? '',
      warrantyExpiry: asset.customFields['warrantyExpiry']?.toString() ?? '',
      department: asset.customFields['department']?.toString() ?? '',
      notes: asset.customFields['notes']?.toString() ?? '',
      createdAt: asset.dateAdded,
      username: asset.customFields['username']?.toString() ?? '',
      cpu: asset.customFields['cpu']?.toString() ?? '',
      motherboard: asset.customFields['motherboard']?.toString() ?? '',
      storage: asset.customFields['storage']?.toString() ?? '',
      ram: asset.customFields['ram']?.toString() ?? '',
      gpu: asset.customFields['gpu']?.toString() ?? '',
    );
  }

}
