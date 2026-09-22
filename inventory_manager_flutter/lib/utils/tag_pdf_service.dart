import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/models/asset_tag.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/utils/asset_tag_payload.dart';
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
    final logoImage = await _decodeLogo(companyLogo);

    final showDeviceName = config['showDeviceName'] ?? true;
    final showUser = config['showUser'] ?? true;
    final showCompany = config['showCompany'] ?? true;
    final double qrSize = (config['qrSize'] ?? 100.0) / 5.0; // scale to mm

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12.0),
        build: (pw.Context context) {
          final gridItems = <pw.Widget>[];

          for (final tag in tags) {
            final qrData = AssetTagPayload.encode(
              tagNumber: tag.tagNumber,
              assetId: tag.assetId,
              deviceType: tag.deviceType,
              modelName: tag.modelName,
            );

            final isPeripheral = [
              'Keyboard', 'Mouse', 'Headphones', 'Monitor', 'Display', 'Peripheral'
            ].contains(tag.itemCategory);

            gridItems.add(
              pw.Container(
                width: 85 * PdfPageFormat.mm,
                height: isPeripheral ? 50 * PdfPageFormat.mm : 70 * PdfPageFormat.mm,
                padding: const pw.EdgeInsets.all(7.0),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey, width: 0.5 * PdfPageFormat.mm),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2 * PdfPageFormat.mm)),
                  color: PdfColors.white,
                ),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (showCompany && companyName.isNotEmpty) ...[
                      pw.Text(
                        companyName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                    ],
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: (85 - qrSize - 10) * PdfPageFormat.mm,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                isPeripheral ? 'Peripheral Tag' : 'Device Details',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue700,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Tag No: ${tag.tagNumber}',
                                style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                              if (showDeviceName) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Device: ${tag.deviceType}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              ],
                              if (showUser && tag.username.isNotEmpty) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'User: ${tag.username}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              ],
                              if (isPeripheral) ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'Date Purchase: ${tag.purchaseDate}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              ] else ...[
                                pw.SizedBox(height: 2),
                                pw.Text(
                                  'CPU: ${tag.cpu}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                                pw.Text(
                                  'RAM: ${tag.ram}',
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              ],
                            ],
                          ),
                        ),
                        pw.Container(
                          width: qrSize * PdfPageFormat.mm,
                          height: qrSize * PdfPageFormat.mm,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.grey300,
                              width: 1 * PdfPageFormat.mm,
                              style: pw.BorderStyle.dashed,
                            ),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2 * PdfPageFormat.mm)),
                          ),
                          child: pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: qrData,
                                width: (qrSize - 2) * PdfPageFormat.mm,
                                height: (qrSize - 2) * PdfPageFormat.mm,
                              ),
                              if (logoImage != null)
                                pw.Positioned(
                                  top: 1 * PdfPageFormat.mm,
                                  right: 1 * PdfPageFormat.mm,
                                  child: pw.Container(
                                    width: (qrSize * 0.3) * PdfPageFormat.mm,
                                    height: (qrSize * 0.3) * PdfPageFormat.mm,
                                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            );
          }

          final rows = <pw.Widget>[];
          for (int i = 0; i < gridItems.length; i += 2) {
            final rowChildren = <pw.Widget>[gridItems[i]];
            if (i + 1 < gridItems.length) {
              rowChildren.add(pw.SizedBox(width: 8 * PdfPageFormat.mm));
              rowChildren.add(gridItems[i + 1]);
            }
            rows.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8.0),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: rowChildren,
                ),
              ),
            );
          }

          return rows;
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> buildTagsPdf({
    required InventoryProvider provider,
    required List<String> assetIds,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _decodeLogo(provider.companyLogo);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(12.0),
        build: (pw.Context context) {
          final gridItems = <pw.Widget>[];

          for (final assetId in assetIds) {
            final asset = provider.assets.where((a) => a.id == assetId).toList();
            if (asset.isEmpty) continue;

            final tag = provider.getTagByAssetId(assetId);
            final effectiveTag = _effectiveTag(tag, asset.first);
            final qrData = AssetTagPayload.encode(
              tagNumber: effectiveTag.tagNumber,
              assetId: asset.first.id,
              deviceType: effectiveTag.deviceType,
              modelName: effectiveTag.modelName,
            );

            gridItems.add(_buildTagCard(
              asset: asset.first,
              tag: effectiveTag,
              qrData: qrData,
              logoImage: logoImage,
            ));
          }

          final rows = <pw.Widget>[];
          for (int i = 0; i < gridItems.length; i += 2) {
            final rowChildren = <pw.Widget>[gridItems[i]];
            if (i + 1 < gridItems.length) {
              rowChildren.add(pw.SizedBox(width: 8 * PdfPageFormat.mm));
              rowChildren.add(gridItems[i + 1]);
            }
            rows.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8.0),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.start,
                  children: rowChildren,
                ),
              ),
            );
          }

          return rows;
        },
      ),
    );

    return pdf.save();
  }

  static Future<pw.ImageProvider?> _decodeLogo(String logoBase64) async {
    if (logoBase64.isNotEmpty) {
      try {
        final base64Content = logoBase64.contains(',')
            ? logoBase64.split(',')[1]
            : logoBase64;
        return pw.MemoryImage(base64Decode(base64Content));
      } catch (e) {
        debugPrint('Failed to decode logo: $e');
      }
    }
    
    try {
      final ByteData data = await rootBundle.load('assets/images/default_logo.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (e) {
      debugPrint('Failed to load default logo: $e');
      return null;
    }
  }

  static AssetTag _effectiveTag(AssetTag? tag, Asset asset) {
    final fallbackModel = asset.customFields['model']?.toString() ?? asset.name;
    final fallbackDeviceType = asset.customFields['deviceType']?.toString() ?? asset.category;
    final fallbackPurchaseDate = asset.customFields['purchaseDate']?.toString() ?? asset.dateAdded;

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

  static pw.Widget _buildTagCard({
    required Asset asset,
    required AssetTag tag,
    required String qrData,
    required pw.ImageProvider? logoImage,
  }) {
    final isPeripheral = [
      'Keyboard', 'Mouse', 'Headphones', 'Monitor', 'Display', 'Peripheral'
    ].contains(tag.itemCategory);

    return pw.Container(
      width: isPeripheral ? 85 * PdfPageFormat.mm : 85 * PdfPageFormat.mm,
      height: isPeripheral ? 50 * PdfPageFormat.mm : 70 * PdfPageFormat.mm,
      padding: const pw.EdgeInsets.all(7.0),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 0.5 * PdfPageFormat.mm),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(2 * PdfPageFormat.mm)),
        color: PdfColors.white,
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 55 * PdfPageFormat.mm,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isPeripheral ? 'Peripheral Tag' : 'Device Details',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tag No: ${tag.tagNumber}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                      ),
                    ),
                    if (isPeripheral) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Date Purchase: ${tag.purchaseDate}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                    ] else ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Username: ${tag.username}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                      pw.Text(
                        'CPU: ${tag.cpu}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                      pw.Text(
                        'Motherboard: ${tag.motherboard}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                      pw.Text(
                        'Storage: ${tag.storage}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                      pw.Text(
                        'RAM: ${tag.ram}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                      pw.Text(
                        'GPU: ${tag.gpu}',
                        style: const pw.TextStyle(fontSize: 7.5),
                      ),
                    ],
                  ],
                ),
              ),
              pw.Container(
                width: 22 * PdfPageFormat.mm,
                height: 22 * PdfPageFormat.mm,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                    width: 1 * PdfPageFormat.mm,
                    style: pw.BorderStyle.dashed,
                  ),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(2 * PdfPageFormat.mm)),
                ),
                child: pw.Stack(
                  alignment: pw.Alignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: qrData,
                      width: 20 * PdfPageFormat.mm,
                      height: 20 * PdfPageFormat.mm,
                    ),
                    if (logoImage != null)
                      pw.Positioned(
                        top: 2 * PdfPageFormat.mm,
                        right: 2 * PdfPageFormat.mm,
                        child: pw.Container(
                          width: 6 * PdfPageFormat.mm,
                          height: 6 * PdfPageFormat.mm,
                          child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}