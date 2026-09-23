import '../providers/auth_provider.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/model_suggestion_service.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/utils/asset_category_schemas.dart';
import 'package:inventory_manager_flutter/utils/tag_pdf_service.dart';
import 'package:inventory_manager_flutter/utils/file_saver_stub.dart'
    if (dart.library.html) 'package:inventory_manager_flutter/utils/file_saver_web.dart'
    if (dart.library.io) 'package:inventory_manager_flutter/utils/file_saver_mobile.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_manager_flutter/services/ai_scanner_service.dart';

class TagsView extends StatefulWidget {
  const TagsView({super.key});

  @override
  State<TagsView> createState() => _TagsViewState();
}

class _TagsViewState extends State<TagsView> {
  Future<void> _exportCSV(BuildContext context) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final csv = provider.getCSVContent();

    try {
      await saveAndLaunchFile(utf8.encode(csv), 'inventory_export.csv', mimeType: 'text/csv');
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
          await provider.importAssetsFromCSV(csvString);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data imported successfully!')),
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

  final _deviceTypeController = TextEditingController();
  final _itemCategoryController = TextEditingController(text: AssetCategorySchemas.categories.first);
  final _modelNameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _vendorController = TextEditingController();
  final _requestedByController = TextEditingController();
  final _purchaseCostController = TextEditingController();
  final _departmentController = TextEditingController();
  final _notesController = TextEditingController();
  final _usernameController = TextEditingController();
  final _cpuController = TextEditingController();
  final _motherboardController = TextEditingController();
  final _storageController = TextEditingController();
  final _ramController = TextEditingController();
  final _gpuController = TextEditingController();

  bool _isGenerating = false;
  final Set<String> _selectedAssetIds = {};

  @override
  void initState() {
    super.initState();
    _refreshModelSuggestions();
  }

  @override
  void dispose() {
    _deviceTypeController.dispose();
    _itemCategoryController.dispose();
    _modelNameController.dispose();
    _quantityController.dispose();
    _vendorController.dispose();
    _requestedByController.dispose();
    _purchaseCostController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    _usernameController.dispose();
    _cpuController.dispose();
    _motherboardController.dispose();
    _storageController.dispose();
    _ramController.dispose();
    _gpuController.dispose();
    super.dispose();
  }

  void _toggleAssetSelect(String id) {
    setState(() {
      if (_selectedAssetIds.contains(id)) {
        _selectedAssetIds.remove(id);
      } else {
        _selectedAssetIds.add(id);
      }
    });
  }

  Future<void> _refreshModelSuggestions() async {
    try {
      await ModelSuggestionService.suggestionsFor(
        itemCategory: _itemCategoryController.text.trim(),
        deviceType: _deviceTypeController.text.trim(),
        fetchFromInternet: false,
      );
    } catch (_) {}
  }

  Future<void> _generatePdf(BuildContext context, {List<String>? assetIds}) async {
    final selectedList = assetIds ?? _selectedAssetIds.toList();
    if (selectedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one asset to generate tags.')));
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      final bytes = await TagPdfService.buildTagsPdf(provider: provider, assetIds: selectedList);
      final category = _itemCategoryController.text.trim().isEmpty ? 'Tags' : _safeFileNamePart(_itemCategoryController.text);
      final fileName = 'Asset_Tags_${DateTime.now().toIso8601String().split('T')[0]}_$category.pdf';
      await saveAndLaunchFile(bytes, fileName);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully generated $fileName')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    } finally { if (mounted) setState(() => _isGenerating = false); }
  }

  String _safeFileNamePart(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '-').replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'_+'), '_').trim();
    return cleaned.isEmpty ? 'Tags' : cleaned;
  }

  Future<void> _showBulkGenerateDialog() async {
    final itemCategoryController = TextEditingController(text: AssetCategorySchemas.categories.first);
    final deviceTypeController = TextEditingController();
    final modelNameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final vendorController = TextEditingController();
    final requestedByController = TextEditingController();
    final purchaseCostController = TextEditingController();
    final departmentController = TextEditingController();
    final notesController = TextEditingController();
    final usernameController = TextEditingController();
    final cpuController = TextEditingController();
    final motherboardController = TextEditingController();
    final storageController = TextEditingController();
    final ramController = TextEditingController();
    final gpuController = TextEditingController();
    DateTime? selectedPurchaseDate = DateTime.now();
    DateTime? selectedWarrantyExpiry;
    bool isScanning = false;

    List<String> availableBrands = AssetCategorySchemas.getBrandsForCategory(itemCategoryController.text);
    List<String> availableModels = [];
    bool isFetchingModels = false;
    StateSetter? dialogSetState;

    void updateBrands() {
      if (dialogSetState != null) {
        dialogSetState!(() {
          availableBrands = AssetCategorySchemas.getBrandsForCategory(itemCategoryController.text);
          deviceTypeController.text = '';
          modelNameController.text = '';
          availableModels = [];
        });
      }
    }

    Future<void> updateModels() async {
      if (deviceTypeController.text.isEmpty) return;
      if (dialogSetState != null) {
        dialogSetState!(() {
          isFetchingModels = true;
          availableModels = [];
        });
      }
      final models = await ModelSuggestionService.suggestionsFor(
        itemCategory: itemCategoryController.text,
        deviceType: deviceTypeController.text,
        fetchFromInternet: true,
      );
      if (dialogSetState != null) {
        dialogSetState!(() {
          availableModels = models;
          isFetchingModels = false;
        });
      }
    }

    itemCategoryController.addListener(updateBrands);
    deviceTypeController.addListener(updateModels);

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) {
          dialogSetState = setStateDialog;
          return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Generate New Tags'),
              IconButton(
                icon: isScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt, color: Color(0xFF6366F1)),
                tooltip: 'Scan Item with Camera',
                onPressed: isScanning ? null : () async {
                  final auth = context.read<AuthProvider>();
                  final consent = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(title: const Text('Analyze image with Gemini'),content: const Text('The photo you take will be sent to Google Gemini using your encrypted personal API key. Review extracted details before saving.'),actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Cancel')),TextButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Continue'))]));
                  if(consent != true || auth.apiToken == null) return;
                  try {
                    final picker = ImagePicker();
                    final image = await picker.pickImage(source: ImageSource.camera);
                    if (image == null) return;

                    setStateDialog(() => isScanning = true);
                    final bytes = await image.readAsBytes();

                    final result = await AIScannerService.analyzeItemImage(bytes, auth.apiToken!, mimeType: image.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');

                    setStateDialog(() {
                      if (result['itemCategory']?.isNotEmpty == true) itemCategoryController.text = result['itemCategory'];
                      if (result['deviceType']?.isNotEmpty == true) deviceTypeController.text = result['deviceType'];
                      if (result['modelName']?.isNotEmpty == true) modelNameController.text = result['modelName'];
                      if (result['vendorName']?.isNotEmpty == true) vendorController.text = result['vendorName'];

                      final serial = result['serialNumber']?.toString() ?? '';
                      if (serial.isNotEmpty) {
                        final currentNotes = notesController.text;
                        notesController.text = currentNotes.isEmpty ? 'S/N: $serial' : '$currentNotes\nS/N: $serial';
                      }

                      final notes = result['notes']?.toString() ?? '';
                      if (notes.isNotEmpty) {
                        final currentNotes = notesController.text;
                        notesController.text = currentNotes.isEmpty ? notes : '$currentNotes\n$notes';
                      }

                      isScanning = false;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item scanned successfully!')));
                  } catch (e) {
                    setStateDialog(() => isScanning = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
                  }
                },
              ),
            ],
          ),
          content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDropdownField(itemCategoryController, AssetCategorySchemas.categories, 'Item Category', 'Select or type category'),
                const SizedBox(height: 12),
                _buildDropdownField(deviceTypeController, availableBrands, 'Device Type / Brand', 'Select or type device type / brand'),
                const SizedBox(height: 12),
                _buildModelAutocomplete(modelNameController, availableModels, 'Model Name', 'Select or type model name', isFetchingModels, updateModels),
                const SizedBox(height: 12),
                TextFormField(controller: quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Purchase Date'),
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: dialogContext, initialDate: selectedPurchaseDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) selectedPurchaseDate = picked;
                    },
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(selectedPurchaseDate == null ? '' : '${selectedPurchaseDate!.toLocal()}'.split(' ')[0])),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Warranty Expiry (optional)'),
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(context: dialogContext, initialDate: selectedWarrantyExpiry ?? DateTime.now().add(const Duration(days: 365)), firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) selectedWarrantyExpiry = picked;
                    },
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Text(selectedWarrantyExpiry == null ? '' : '${selectedWarrantyExpiry!.toLocal()}'.split(' ')[0])),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(controller: vendorController, decoration: const InputDecoration(labelText: 'Vendor Name (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: requestedByController, decoration: const InputDecoration(labelText: 'Requested By (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: purchaseCostController, decoration: const InputDecoration(labelText: 'Purchase Cost (optional)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 12),
                TextFormField(controller: departmentController, decoration: const InputDecoration(labelText: 'Department (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: notesController, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
                const SizedBox(height: 16),
                TextFormField(controller: usernameController, decoration: const InputDecoration(labelText: 'Username (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: cpuController, decoration: const InputDecoration(labelText: 'CPU (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: motherboardController, decoration: const InputDecoration(labelText: 'Motherboard (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: storageController, decoration: const InputDecoration(labelText: 'Storage (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: ramController, decoration: const InputDecoration(labelText: 'RAM (optional)')),
                const SizedBox(height: 12),
                TextFormField(controller: gpuController, decoration: const InputDecoration(labelText: 'GPU (optional)')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              final newIds = await provider.generateAssetTags(
                purchaseDate: '${selectedPurchaseDate!.toLocal()}'.split(' ')[0],
                deviceType: deviceTypeController.text.trim(),
                itemCategory: itemCategoryController.text.trim(),
                modelName: modelNameController.text.trim(),
                quantity: int.parse(quantityController.text),
                vendorName: vendorController.text.trim(),
                requestedBy: requestedByController.text.trim(),
                purchaseCost: purchaseCostController.text.trim(),
                warrantyExpiry: selectedWarrantyExpiry == null ? '' : '${selectedWarrantyExpiry!.toLocal()}'.split(' ')[0],
                department: departmentController.text.trim(),
                notes: notesController.text.trim(),
                username: usernameController.text.trim(),
                cpu: cpuController.text.trim(),
                motherboard: motherboardController.text.trim(),
                storage: storageController.text.trim(),
                ram: ramController.text.trim(),
                gpu: gpuController.text.trim(),
              );
              setState(() { _selectedAssetIds.clear(); _selectedAssetIds.addAll(newIds); });
              Navigator.pop(dialogContext);
              await _generatePdf(context, assetIds: newIds);
            },
            child: const Text('Generate Tags'),
          ),
        ],
      );
        },
      ),
    );
  }

  Widget _buildDropdownField(TextEditingController controller, List<String> options, String label, String hintText) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        return [...options, controller.text].where((o) => o.toLowerCase().contains(query)).toList();
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: label, hintText: hintText, suffixIcon: const Icon(Icons.edit, size: 18)),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(options.elementAt(index)),
                  onTap: () => onSelected(options.elementAt(index)),
                ),
              ),
            ),
          ),
        );
      },
      onSelected: (v) => controller.text = v,
    );
  }

  Widget _buildModelAutocomplete(TextEditingController controller, List<String> options, String label, String hintText, bool isLoading, VoidCallback onRefresh) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.toLowerCase();
        return [...options, controller.text].where((o) => o.toLowerCase().contains(query)).toList();
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(icon: const Icon(Icons.refresh_rounded, size: 18), onPressed: onRefresh),
              ],
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(options.elementAt(index)),
                  onTap: () => onSelected(options.elementAt(index)),
                ),
              ),
            ),
          ),
        );
      },
      onSelected: (v) => controller.text = v,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final activeAssets = provider.assets.where((a) => a.status != 'Retired').toList();
    final allIds = activeAssets.map((a) => a.id).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
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
                    Text('Tag Generator', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text('Generate production asset tag numbers, QR payloads, and printable asset tags.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                Row(
                  children: [
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
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _isGenerating ? null : _showBulkGenerateDialog,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Generate New Tags'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6366F1), side: const BorderSide(color: Color(0xFF6366F1))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isGenerating || _selectedAssetIds.isEmpty ? null : () => _generatePdf(context),
                      icon: _isGenerating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                      label: Text(_isGenerating ? 'Generating...' : 'Generate PDF'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: activeAssets.isEmpty
                    ? const Center(child: Text('No assets available for tag generation.', style: TextStyle(color: Color(0xFF9CA3AF))))
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.white.withOpacity(0.05)),
                            child: DataTable(
                              columnSpacing: 36.0,
                              columns: const [
                                DataColumn(label: Text('SELECT')),
                                DataColumn(label: Text('TAG NUMBER')),
                                DataColumn(label: Text('ASSET ID')),
                                DataColumn(label: Text('DEVICE NAME')),
                                DataColumn(label: Text('DEVICE TYPE')),
                                DataColumn(label: Text('CATEGORY')),
                                DataColumn(label: Text('MODEL')),
                                DataColumn(label: Text('PURCHASE DATE')),
                                DataColumn(label: Text('QTY')),
                                DataColumn(label: Text('VENDOR')),
                                DataColumn(label: Text('DEPARTMENT')),
                              ],
                              rows: activeAssets.map((asset) {
                                final isSelected = _selectedAssetIds.contains(asset.id);
                                final tag = provider.getTagByAssetId(asset.id);
                                final tagNumber = tag?.tagNumber ?? asset.serial;
                                final deviceType = tag?.deviceType ?? asset.customFields['deviceType']?.toString() ?? asset.category;
                                final modelName = tag?.modelName ?? asset.customFields['model']?.toString() ?? asset.name;
                                final purchaseDate = tag?.purchaseDate ?? asset.customFields['purchaseDate']?.toString() ?? asset.dateAdded;

                                return DataRow(
                                  selected: isSelected,
                                  onSelectChanged: (_) => _toggleAssetSelect(asset.id),
                                  cells: [
                                    DataCell(Checkbox(value: isSelected, activeColor: const Color(0xFF6366F1), onChanged: (_) => _toggleAssetSelect(asset.id))),
                                    DataCell(Text(tagNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Color(0xFF6366F1)))),
                                    DataCell(Text(asset.id, style: const TextStyle(fontFamily: 'monospace'))),
                                    DataCell(Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(deviceType)),
                                    DataCell(Text(asset.category)),
                                    DataCell(Text(modelName)),
                                    DataCell(Text(purchaseDate)),
                                    DataCell(Text('${tag?.quantity ?? 1}')),
                                    DataCell(Text(tag?.vendorName ?? asset.customFields['vendorName']?.toString() ?? '')),
                                    DataCell(Text(tag?.department ?? asset.customFields['department']?.toString() ?? '')),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedAssetIds.length == activeAssets.length && activeAssets.isNotEmpty ? 0 : 1,
        onTap: (index) {
          setState(() {
            if (index == 0) {
              _selectedAssetIds.clear();
            } else {
              _selectedAssetIds.addAll(allIds);
            }
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.clear_all), label: 'Clear'),
          BottomNavigationBarItem(icon: Icon(Icons.select_all), label: 'Select All'),
        ],
      ),
    );
  }
}
