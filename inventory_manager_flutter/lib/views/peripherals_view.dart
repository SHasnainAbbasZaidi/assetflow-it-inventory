import 'dart:convert';
import '../utils/hardware_groups.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inventory_manager_flutter/models/asset.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/utils/asset_category_schemas.dart';
import 'package:inventory_manager_flutter/views/asset_qr_dialog.dart';
import 'package:inventory_manager_flutter/utils/tag_pdf_service.dart';
import 'package:inventory_manager_flutter/utils/file_saver_stub.dart'
    if (dart.library.html) 'package:inventory_manager_flutter/utils/file_saver_web.dart'
    if (dart.library.io) 'package:inventory_manager_flutter/utils/file_saver_mobile.dart';

class PeripheralsView extends StatefulWidget {
  final String searchQuery;
  final String? hardwareGroup;
  const PeripheralsView({super.key, this.searchQuery = '', this.hardwareGroup});

  @override
  State<PeripheralsView> createState() => _PeripheralsViewState();
}

class _PeripheralsViewState extends State<PeripheralsView> {
  final Set<String> _selectedAssetIds = {};

  Future<void> _exportCSV(BuildContext context) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final csv = provider.getCSVContent();

    try {
      await saveAndLaunchFile(utf8.encode(csv), 'peripherals_export.csv', mimeType: 'text/csv');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV Exported successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  Future<void> _importCSV(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        final bytes = result.files.single.bytes;
        if (bytes != null) {
          final csvString = utf8.decode(bytes);
          final provider = Provider.of<InventoryProvider>(context, listen: false);
          await provider.importAssetsFromCSV(csvString, targetType: 'peripheral');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Peripherals imported successfully!')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import CSV: $e')),
        );
      }
    }
  }

  Future<void> _printSelectedTags(BuildContext context) async {
    if (_selectedAssetIds.isEmpty) return;
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final selectedTags = provider.tags.where((t) => _selectedAssetIds.contains(t.assetId)).toList();
    if (selectedTags.isEmpty) return;

    try {
      final pdfBytes = await TagPdfService.generateBulkTagsPdf(
        tags: selectedTags,
        companyName: provider.companyName,
        companyLogo: provider.companyLogo,
        config: provider.tagConfig,
      );
      await saveAndLaunchFile(pdfBytes, 'bulk_tags.pdf', mimeType: 'application/pdf');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  void _openAssetForm(BuildContext context, [Asset? asset]) {
    // We pass Peripheral as the base category, but peripheral could be Keyboard, Mouse, etc.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AssetFormDialog(
        asset: asset,
        category: 'Peripheral',
      ),
    );
  }

  void _openQrDialog(BuildContext context, Asset asset) {
    showDialog(
      context: context,
      builder: (context) => AssetQrDialog(asset: asset),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final assets = provider.peripherals;

    final filteredAssets = assets.where((asset) {
      if(widget.hardwareGroup!=null && HardwareGroups.classify(asset.category)!=widget.hardwareGroup) return false;
      final query = widget.searchQuery.toLowerCase();
      if (query.isEmpty) return true;

      return asset.name.toLowerCase().contains(query) ||
          asset.id.toLowerCase().contains(query) ||
          asset.serial.toLowerCase().contains(query) ||
          asset.assignee.toLowerCase().contains(query) ||
          asset.status.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAssetForm(context),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Peripherals',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage accessories and add-on hardware.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (_selectedAssetIds.isNotEmpty) ...[
                      ElevatedButton.icon(
                        onPressed: () => _printSelectedTags(context),
                        icon: const Icon(Icons.print_rounded, size: 18),
                        label: Text('Print (${_selectedAssetIds.length})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _importCSV(context),
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Import CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _exportCSV(context),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Export CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: filteredAssets.isEmpty
                    ? const Center(
                        child: Text(
                          'No peripherals found matching the criteria.',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.white.withOpacity(0.05),
                            ),
                            child: DataTable(
                              columnSpacing: 36.0,
                              columns: [
                                DataColumn(
                                  label: Checkbox(
                                    value: _selectedAssetIds.length == filteredAssets.length && filteredAssets.isNotEmpty,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedAssetIds.addAll(filteredAssets.map((a) => a.id));
                                        } else {
                                          _selectedAssetIds.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const DataColumn(label: Text('ID / TAG')),
                                const DataColumn(label: Text('CATEGORY')),
                                const DataColumn(label: Text('ASSIGNED WS')),
                                const DataColumn(label: Text('STATUS')),
                                const DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: filteredAssets.map((asset) {
                                final Color statusColor;
                                final Color statusBg;
                                switch (asset.status) {
                                  case 'In Store':
                                    statusColor = const Color(0xFF10B981);
                                    statusBg = const Color(0xFF10B981).withOpacity(0.12);
                                    break;
                                  case 'Assigned':
                                    statusColor = const Color(0xFF3B82F6);
                                    statusBg = const Color(0xFF3B82F6).withOpacity(0.12);
                                    break;
                                  case 'Out of Order':
                                    statusColor = const Color(0xFFF59E0B);
                                    statusBg = const Color(0xFFF59E0B).withOpacity(0.12);
                                    break;
                                  default:
                                    statusColor = const Color(0xFFEF4444);
                                    statusBg = const Color(0xFFEF4444).withOpacity(0.12);
                                }

                                final bool isRetired = ['Retired', 'Scrapped'].contains(asset.status);

                                return DataRow(
                                  selected: _selectedAssetIds.contains(asset.id),
                                  onSelectChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedAssetIds.add(asset.id);
                                      } else {
                                        _selectedAssetIds.remove(asset.id);
                                      }
                                    });
                                  },
                                  cells: [
                                    DataCell(
                                      Checkbox(
                                        value: _selectedAssetIds.contains(asset.id),
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedAssetIds.add(asset.id);
                                            } else {
                                              _selectedAssetIds.remove(asset.id);
                                            }
                                          });
                                        },
                                      )
                                    ),
                                    DataCell(
                                      Opacity(
                                        opacity: isRetired ? 0.6 : 1.0,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              asset.id,
                                              style: const TextStyle(
                                                color: Color(0xFF6366F1),
                                                fontFamily: 'monospace',
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(Opacity(opacity: isRetired ? 0.6 : 1.0, child: Text(asset.category))),
                                    DataCell(Opacity(opacity: isRetired ? 0.6 : 1.0, child: Text(asset.customFields['personnel']?['fullName']?.toString() ?? (asset.assignee.isEmpty ? 'Unassigned' : asset.assignee)))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          asset.status,
                                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF6366F1)),
                                            onPressed: () => _openQrDialog(context, asset),
                                            tooltip: 'View QR Code',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: asset.status == 'Scrapped' ? null : () => _openAssetForm(context, asset),
                                            tooltip: 'Edit Asset',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                            onPressed: asset.status == 'Scrapped' ? null : () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Retire Asset'),
                                                  content: Text('Retire ${asset.name}? Its history and audit trail will be preserved.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        provider.deleteAsset(asset.id);
                                                        Navigator.pop(ctx);
                                                      },
                                                      child: const Text('Retire', style: TextStyle(color: Color(0xFFEF4444))),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            tooltip: 'Delete Asset',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// NOTE: I am reusing the same AssetFormDialog class from WorkstationsView for simplicity in this artifact,
// but in the actual implementation it could be a shared widget.
// For now, I will just paste it here to ensure this view compiles and works independently.

class AssetFormDialog extends StatefulWidget {
  final Asset? asset;
  final String category;

  const AssetFormDialog({
    super.key,
    this.asset,
    required this.category,
  });

  @override
  State<AssetFormDialog> createState() => _AssetFormDialogState();
}

class _AssetFormDialogState extends State<AssetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _category;
  late String _status;
  late String _assignee;
  Map<String, dynamic> _customFields = {};

  final Map<String, TextEditingController> _customControllers = {};

  @override
  void initState() {
    super.initState();
    _name = widget.asset?.name ?? '';
    _category = widget.asset?.category ?? widget.category;
    _status = widget.asset?.status ?? 'In Store';
    _assignee = widget.asset?.assignee ?? '';
    _customFields = Map<String, dynamic>.from(widget.asset?.customFields ?? {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeCustomControllers(context);
  }

  void _initializeCustomControllers(BuildContext context) {
    if (_customControllers.isNotEmpty) return;
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    // Core fields
    final coreFields = AssetCategorySchemas.fieldsFor(_category);
    for (final field in coreFields) {
      final id = field['id']!;
      final val = _customFields[id]?.toString() ?? '';
      _customControllers[id] = TextEditingController(text: val);
    }

    // Dynamic fields
    final dynamicFields = provider.customFieldsConfig.where((f) => f['target'] == 'Peripheral');
    for (final field in dynamicFields) {
      final id = field['id'] as String;
      final val = _customFields[id]?.toString() ?? '';
      _customControllers[id] = TextEditingController(text: val);
    }
  }

  @override
  void dispose() {
    _customControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final isEdit = widget.asset != null;

    final coreFields = AssetCategorySchemas.fieldsFor(_category);
    final dynamicFields = provider.customFieldsConfig.where((f) => f['target'] == 'Peripheral').toList();

    return AlertDialog(
      title: Text(isEdit ? 'Edit Peripheral' : 'Add New Peripheral'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _category.isEmpty ? null : _category,
                  decoration: const InputDecoration(labelText: 'Peripheral Type'),
                  items: {...AssetCategorySchemas.categories, _category}.map((cat) {
                    return DropdownMenuItem<String>(value: cat, child: Text(cat));
                  }).toList(),
                  validator: (value) => value == null ? 'Select a category' : null,
                  onChanged: (val) {
                    setState(() {
                      _category = val!;
                      _customControllers.clear();
                      _initializeCustomControllers(context);
                    });
                  },
                  onSaved: (val) => _category = val!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'In Store', child: Text('In Store')),
                    DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                    DropdownMenuItem(value: 'Out of Order', child: Text('Out of Order')),
                    DropdownMenuItem(value: 'Retired', child: Text('Retired (Deprecated)')),
                  ],
                  onChanged: (val) => setState(() => _status = val!),
                  onSaved: (val) => _status = val!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _assignee.isEmpty ? '' : _assignee,
                  decoration: const InputDecoration(labelText: 'Assigned To (Workstation Tag)'),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Unassigned')),
                    ...provider.workstations.map((w) {
                      return DropdownMenuItem(value: w.id, child: Text(w.id));
                    }),
                  ],
                  onChanged: (val) => setState(() => _assignee = val ?? ''),
                  onSaved: (val) => _assignee = val ?? '',
                ),
                if (coreFields.isNotEmpty || dynamicFields.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    '$_category Specifications',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                  ),
                  const Divider(color: Color(0xFF6366F1), height: 16, thickness: 1),

                  // Render core fields
                  ...coreFields.map((field) {
                    final id = field['id']!;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: TextFormField(
                        controller: _customControllers[id],
                        decoration: InputDecoration(
                          labelText: field['label'],
                          hintText: field['placeholder'],
                        ),
                      ),
                    );
                  }),

                  // Render dynamic fields
                  ...dynamicFields.map((field) {
                    final id = field['id'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: TextFormField(
                        controller: _customControllers[id],
                        decoration: InputDecoration(
                          labelText: field['name'],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();

              final customData = <String, dynamic>{};
              _customControllers.forEach((key, controller) {
                customData[key] = controller.text.trim();
              });

              if (isEdit) {
                await provider.updateAsset(
                  widget.asset!.id,
                  name: _name,
                  category: _category,
                  serial: '',
                  status: _status,
                  assignee: _assignee,
                  customFields: customData,
                );
              } else {
                await provider.addAsset(
                  name: _name,
                  category: _category,
                  serial: '',
                  status: _status,
                  assignee: _assignee,
                  customFields: customData,
                );
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save Peripheral'),
        ),
      ],
    );
  }
}
