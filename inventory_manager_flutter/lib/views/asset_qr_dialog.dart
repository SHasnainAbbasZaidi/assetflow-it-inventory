import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/utils/asset_tag_payload.dart';
import 'package:inventory_manager_flutter/utils/tag_pdf_service.dart';

import 'package:inventory_manager_flutter/utils/file_saver_stub.dart'
    if (dart.library.html) 'package:inventory_manager_flutter/utils/file_saver_web.dart'
    if (dart.library.io) 'package:inventory_manager_flutter/utils/file_saver_mobile.dart';

class AssetQrDialog extends StatelessWidget {
  final Asset asset;

  const AssetQrDialog({super.key, required this.asset});

  static const List<String> peripheralCategories = [
    'Keyboard', 'Mouse', 'Headphones', 'Monitor', 'Display', 'Peripheral'
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final tag = provider.getTagByAssetId(asset.id);
    final tagNumber = tag?.tagNumber ?? (asset.serial.isNotEmpty ? asset.serial : asset.id);
    final deviceType = tag?.deviceType ?? asset.customFields['deviceType']?.toString() ?? asset.category;
    final modelName = tag?.modelName ?? asset.customFields['model']?.toString() ?? asset.name;
    final purchaseDate = tag?.purchaseDate ?? asset.customFields['purchaseDate']?.toString() ?? asset.dateAdded;
    final qrData = AssetTagPayload.encode(
      tagNumber: tagNumber,
      assetId: asset.id,
      deviceType: deviceType,
      modelName: modelName,
    );

    final isPeripheral = peripheralCategories.contains(asset.category);

    return AlertDialog(
      title: Text(isPeripheral ? 'Peripheral Tag' : 'Device Details Tag'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6).withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6).withValues(alpha: 0.08)),
              ),
              child: QrImageView(
                data: qrData,
                size: 190,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF6366F1),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF6366F1),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _buildInfoRow('Tag Number', tagNumber),
            if (isPeripheral) ...[
              _buildInfoRow('Date Purchase', purchaseDate),
            ] else ...[
              _buildInfoRow('Username', tag?.username ?? asset.customFields['username']?.toString() ?? ''),
              _buildInfoRow('CPU', tag?.cpu ?? asset.customFields['cpu']?.toString() ?? ''),
              _buildInfoRow('Motherboard', tag?.motherboard ?? asset.customFields['motherboard']?.toString() ?? ''),
              _buildInfoRow('Storage', tag?.storage ?? asset.customFields['storage']?.toString() ?? ''),
              _buildInfoRow('RAM', tag?.ram ?? asset.customFields['ram']?.toString() ?? ''),
              _buildInfoRow('GPU', tag?.gpu ?? asset.customFields['gpu']?.toString() ?? ''),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: qrData));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR payload copied to clipboard')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy QR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF6366F1),
            side: const BorderSide(color: Color(0xFF6366F1)),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            try {
              final bytes = await TagPdfService.buildTagsPdf(
                provider: provider,
                assetIds: [asset.id],
              );
              final fileName = 'Asset_Tag_${tagNumber}_${DateTime.now().toIso8601String().split('T')[0]}.pdf';
              await saveAndLaunchFile(bytes, fileName);
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Successfully generated $fileName')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error generating tag PDF: $e')),
                );
              }
            }
          },
          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
          label: const Text('Print Tag'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}