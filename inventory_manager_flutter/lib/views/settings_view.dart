import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/providers/auth_provider.dart';
import 'package:inventory_manager_flutter/services/asset_api_service.dart';
import 'package:inventory_manager_flutter/views/app_users_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  String _currentLogoBase64 = '';
  Uint8List? _logoBytes;
  final _geminiApiController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _isTestingServer = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _currentLogoBase64 = provider.companyLogo;
    _geminiApiController.text = provider.geminiApiKey;
    _companyNameController.text = provider.companyName;
    _companyAddressController.text = provider.companyAddress;
    _serverUrlController.text = auth.serverUrl;
    _updateLogoBytes();
  }

  @override
  void dispose() {
    _geminiApiController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  void _updateLogoBytes() {
    if (_currentLogoBase64.isNotEmpty) {
      try {
        final cleanStr = _currentLogoBase64.contains(',')
            ? _currentLogoBase64.split(',')[1]
            : _currentLogoBase64;
        setState(() {
          _logoBytes = base64Decode(cleanStr);
        });
      } catch (e) {
        debugPrint('Error decoding saved logo: $e');
      }
    } else {
      setState(() {
        _logoBytes = null;
      });
    }
  }

  Future<void> _pickLogo(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        final bytes = file.bytes!;
        final extension = file.extension ?? 'png';
        final mimeType = 'image/$extension';
        final base64String = 'data:$mimeType;base64,${base64Encode(bytes)}';

        setState(() {
          _currentLogoBase64 = base64String;
          _logoBytes = bytes;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeLogo(BuildContext context) {
    setState(() {
      _currentLogoBase64 = '';
      _logoBytes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Logo removed. Save settings to apply removal.')),
    );
  }

  void _openAdminUserForm(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppUserFormDialog(),
    );
  }

  Future<void> _saveSettings(BuildContext context) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    await provider.saveBrandingLogo(_currentLogoBase64);
    await provider.saveCompanyDetails(_companyNameController.text.trim(), _companyAddressController.text.trim());
    await provider.saveGeminiApiKey(_geminiApiController.text.trim());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure branding and administrative users from one place.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            _buildServerConfigCard(context),
            const SizedBox(height: 28),
            _buildAIIntegrationsCard(context),
            const SizedBox(height: 28),
            _buildBrandingCard(context),
            const SizedBox(height: 28),
            _buildTagCustomizerCard(context),
            const SizedBox(height: 28),
            _buildCustomFieldsManagerCard(context),
            const SizedBox(height: 28),
            SizedBox(
              height: 520,
              child: AppUserManagementSection(
                showHeader: true,
                onAddUser: () => _openAdminUserForm(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerConfigCard(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 760,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.dns_rounded, color: Color(0xFF6366F1), size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'Server Configuration',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure the Node.js backend server URL. The mobile app connects to this endpoint for all operations and sync.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _serverUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Server Base URL',
                    hintText: 'e.g. http://192.168.1.100:3000 or https://myserver.com',
                    helperText: 'Must include protocol (http:// or https://) and port if applicable.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isTestingServer
                          ? null
                          : () async {
                              final url = _serverUrlController.text.trim();
                              if (url.isEmpty) return;
                              setState(() => _isTestingServer = true);
                              final ok = await AssetApiService.pingServer(url);
                              setState(() => _isTestingServer = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
                                    content: Text(ok
                                        ? 'Server connection successful! ($url)'
                                        : 'Failed to connect to server at $url. Check URL and server status.'),
                                  ),
                                );
                              }
                            },
                      icon: _isTestingServer
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: const Text('Test Connection'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        await auth.setServerUrl(_serverUrlController.text.trim());
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Server URL updated successfully!')),
                          );
                        }
                      },
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Server URL'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIIntegrationsCard(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 760,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Integrations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Configure Google Gemini Vision API to automatically extract item details from pictures.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _geminiApiController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Paste your API key here (AIzaSy...)',
                    helperText: 'Required for "Scan Item with Camera" feature in Tag Generator.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () => _saveSettings(context),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingCard(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 760,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Company Branding',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload, change, or remove the company logo used across the application, reports, and asset tags.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => _pickLogo(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: _logoBytes == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 36, color: Color(0xFF818CF8)),
                              SizedBox(height: 8),
                              Text(
                                'Click to upload or change logo image',
                                style: TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Supports PNG, JPG, GIF',
                                style: TextStyle(
                                    color: Color(0xFF6B7280), fontSize: 11),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Image.memory(
                                  _logoBytes!,
                                  height: 90,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Current logo preview',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _companyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Company Name',
                    hintText: 'e.g. Acme Corporation',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Company Address',
                    hintText: 'e.g. 123 Tech Lane, Silicon Valley',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickLogo(context),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit / Change Logo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6366F1),
                        side: const BorderSide(color: Color(0xFF6366F1)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _logoBytes == null
                          ? null
                          : () => _removeLogo(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Remove Logo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _saveSettings(context),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagCustomizerCard(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 760,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tag Customizer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customize the information displayed on printed asset tags.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 24),
                Consumer<InventoryProvider>(
                  builder: (context, provider, child) {
                    final config = provider.tagConfig;
                    return Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Show Device Name / Type'),
                          value: config['showDeviceName'] ?? true,
                          onChanged: (val) {
                            final newConfig = Map<String, dynamic>.from(config);
                            newConfig['showDeviceName'] = val;
                            provider.saveTagConfig(newConfig);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Show Assigned User'),
                          value: config['showUser'] ?? true,
                          onChanged: (val) {
                            final newConfig = Map<String, dynamic>.from(config);
                            newConfig['showUser'] = val;
                            provider.saveTagConfig(newConfig);
                          },
                        ),
                        SwitchListTile(
                          title: const Text('Show Company Name'),
                          value: config['showCompany'] ?? true,
                          onChanged: (val) {
                            final newConfig = Map<String, dynamic>.from(config);
                            newConfig['showCompany'] = val;
                            provider.saveTagConfig(newConfig);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('QR Code Size', style: TextStyle(fontSize: 16)),
                              Slider(
                                value: (config['qrSize'] ?? 100.0).toDouble(),
                                min: 50.0,
                                max: 150.0,
                                divisions: 10,
                                label: '${(config['qrSize'] ?? 100.0).toInt()}%',
                                onChanged: (val) {
                                  final newConfig = Map<String, dynamic>.from(config);
                                  newConfig['qrSize'] = val;
                                  provider.saveTagConfig(newConfig);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFieldsManagerCard(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 760,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Custom Fields Manager',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Define additional fields to be tracked for Workstations or Peripherals.',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                ),
                const SizedBox(height: 24),
                Consumer<InventoryProvider>(
                  builder: (context, provider, child) {
                    final fields = provider.customFieldsConfig;
                    return Column(
                      children: [
                        if (fields.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('No custom fields defined.', style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: fields.length,
                            itemBuilder: (context, index) {
                              final field = fields[index];
                              return ListTile(
                                title: Text(field['name'] ?? ''),
                                subtitle: Text('Target: ${field['target']} | ID: ${field['id']}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    final newFields = List<Map<String, dynamic>>.from(fields);
                                    newFields.removeAt(index);
                                    provider.saveCustomFieldsConfig(newFields);
                                  },
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddCustomFieldDialog(context, provider),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Custom Field'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddCustomFieldDialog(BuildContext context, InventoryProvider provider) {
    final _formKey = GlobalKey<FormState>();
    String _name = '';
    String _target = 'Workstation';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Field'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Field Name (e.g. Warranty Provider)'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _target,
                decoration: const InputDecoration(labelText: 'Target Category'),
                items: const [
                  DropdownMenuItem(value: 'Workstation', child: Text('Workstation')),
                  DropdownMenuItem(value: 'Peripheral', child: Text('Peripheral')),
                ],
                onChanged: (val) => _target = val!,
                onSaved: (val) => _target = val!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                _formKey.currentState!.save();
                final id = _name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
                final newFields = List<Map<String, dynamic>>.from(provider.customFieldsConfig);
                newFields.add({
                  'id': id,
                  'name': _name,
                  'target': _target,
                  'type': 'text', // extensible later
                });
                provider.saveCustomFieldsConfig(newFields);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
