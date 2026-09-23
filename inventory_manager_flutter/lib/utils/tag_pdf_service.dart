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
    bool isWorkstation(AssetTag tag) => [
          'workstation',
          'computer',
          'desktop',
          'laptop',
          'pc'
        ].contains(tag.itemCategory.toLowerCase());
    for (final workstation in [true, false]) {
      final group =
          tags.where((tag) => isWorkstation(tag) == workstation).toList();
      final perPage = workstation ? 4 : 8;
      final height = workstation ? 131.09 : 65.54;
      for (var offset = 0; offset < group.length; offset += perPage) {
        final chunk = group.skip(offset).take(perPage).toList();
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(10 * PdfPageFormat.mm),
          build: (_) => pw.Column(children: [
            for (var row = 0; row < chunk.length; row += 2)
              pw.Padding(
                  padding: pw.EdgeInsets.only(bottom: 4 * PdfPageFormat.mm),
                  child: pw.Row(children: [
                    for (var col = 0;
                        col < 2 && row + col < chunk.length;
                        col++) ...[
                      if (col > 0) pw.SizedBox(width: 4 * PdfPageFormat.mm),
                      pw.Container(
                        width: 93 * PdfPageFormat.mm,
                        height: height * PdfPageFormat.mm,
                        padding: pw.EdgeInsets.all(5 * PdfPageFormat.mm),
                        decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300)),
                        child: pw.FittedBox(
                            fit: pw.BoxFit.scaleDown,
                            alignment: pw.Alignment.topLeft,
                            child: pw.SizedBox(
                              width: 83 * PdfPageFormat.mm,
                              child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    if (config['showCompany'] != false) ...[
                                      if (logo != null)
                                        pw.Image(logo,
                                            width: 35,
                                            height: 25,
                                            fit: pw.BoxFit.contain),
                                      pw.Text(companyName,
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 12)),
                                      pw.SizedBox(height: 8),
                                    ],
                                    pw.Text(chunk[row + col].tagNumber,
                                        style: pw.TextStyle(
                                            fontSize: 14,
                                            fontWeight: pw.FontWeight.bold)),
                                    pw.SizedBox(height: 8),
                                    pw.Row(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Expanded(
                                              child: pw.Column(
                                                  crossAxisAlignment: pw
                                                      .CrossAxisAlignment.start,
                                                  children: [
                                                if (config['showDeviceName'] !=
                                                    false)
                                                  pw.Text(
                                                      '${chunk[row + col].deviceType} ${chunk[row + col].modelName}',
                                                      style: const pw.TextStyle(
                                                          fontSize: 10)),
                                                if (config['showUser'] != false)
                                                  pw.Text(
                                                      'User: ${chunk[row + col].username}',
                                                      style: const pw.TextStyle(
                                                          fontSize: 10)),
                                                if (workstation) ...[
                                                  pw.Text(
                                                      'CPU: ${chunk[row + col].cpu}'),
                                                  pw.Text(
                                                      'RAM: ${chunk[row + col].ram}'),
                                                  pw.Text(
                                                      'Storage: ${chunk[row + col].storage}'),
                                                ] else
                                                  pw.Text(
                                                      'Purchased: ${chunk[row + col].purchaseDate}'),
                                              ])),
                                          pw.SizedBox(width: 8),
                                          pw.BarcodeWidget(
                                              barcode: pw.Barcode.qrCode(),
                                              data: chunk[row + col].tagNumber,
                                              width: 65,
                                              height: 65),
                                        ]),
                                  ]),
                            )),
                      ),
                    ],
                  ])),
          ]),
        ));
      }
    }
    return pdf.save();
  }

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
