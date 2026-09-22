import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/utils/file_saver_stub.dart'
    if (dart.library.html) 'package:inventory_manager_flutter/utils/file_saver_web.dart'
    if (dart.library.io) 'package:inventory_manager_flutter/utils/file_saver_mobile.dart';

class UsersView extends StatefulWidget {
  final String searchQuery;
  const UsersView({super.key, this.searchQuery = ''});

  @override
  State<UsersView> createState() => _UsersViewState();
}

class _UsersViewState extends State<UsersView> {
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

  void _openUserForm(BuildContext context, [User? user]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserFormDialog(user: user),
    );
  }

  void _showInventoryDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<InventoryProvider>(
          builder: (context, provider, child) {
            final userAssets = provider.assets.where((a) => a.assignee == user.id && a.status != 'Retired').toList();

            return AlertDialog(
              title: Text('Assigned Inventory: ${user.name}'),
              content: SizedBox(
                width: 600,
                child: userAssets.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'No active assets assigned to this person.',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      )
                    : SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 24.0,
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Serial')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: userAssets.map((asset) {
                            return DataRow(cells: [
                              DataCell(Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(asset.category)),
                              DataCell(Text(asset.serial, style: const TextStyle(fontFamily: 'monospace'))),
                              DataCell(Text(asset.status)),
                            ]);
                          }).toList(),
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final users = provider.users.where((u) => u.name != 'Unassigned').toList();
    final assets = provider.assets;

    final filteredUsers = users.where((user) {
      final query = widget.searchQuery.toLowerCase();
      if (query.isEmpty) return true;

      return user.name.toLowerCase().contains(query) ||
          user.department.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openUserForm(context),
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
                      'Personnel Directory',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage employees and their assigned inventory.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
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
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: filteredUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'No personnel found matching the criteria.',
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
                              columnSpacing: 48.0,
                              columns: const [
                                DataColumn(label: Text('NAME')),
                                DataColumn(label: Text('DEPARTMENT')),
                                DataColumn(label: Text('EMAIL')),
                                DataColumn(label: Text('ASSIGNED ITEMS')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: filteredUsers.map((user) {
                                final userAssetsCount = assets.where((a) => a.assignee == user.id && a.status != 'Retired').length;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(user.department)),
                                    DataCell(Text(user.email)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6366F1).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$userAssetsCount Items',
                                          style: const TextStyle(
                                            color: Color(0xFF818CF8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.list_alt_rounded, size: 20),
                                            onPressed: () => _showInventoryDialog(context, user),
                                            tooltip: 'View Inventory',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 20),
                                            onPressed: () => _openUserForm(context, user),
                                            tooltip: 'Edit Personnel Details',
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete Personnel'),
                                                  content: Text('Are you sure you want to delete ${user.name}? All active items assigned to this person will be unassigned.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        provider.deleteUser(user.id);
                                                        Navigator.pop(ctx);
                                                      },
                                                      child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            tooltip: 'Delete Personnel',
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

class UserFormDialog extends StatefulWidget {
  final User? user;

  const UserFormDialog({super.key, this.user});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _department;
  late String _email;

  @override
  void initState() {
    super.initState();
    _name = widget.user?.name ?? '';
    _department = widget.user?.department ?? '';
    _email = widget.user?.email ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final isEdit = widget.user != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Personnel' : 'Add Personnel'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Full Name', hintText: 'e.g. John Doe'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter full name' : null,
                onSaved: (val) => _name = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _department,
                decoration: const InputDecoration(labelText: 'Department', hintText: 'e.g. Engineering'),
                validator: (value) => value == null || value.trim().isEmpty ? 'Enter department' : null,
                onSaved: (val) => _department = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(labelText: 'Email Address', hintText: 'john@example.com'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter email address';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email';
                  return null;
                },
                onSaved: (val) => _email = val!.trim(),
              ),
            ],
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
              if (isEdit) {
                await provider.updateUser(widget.user!.id, name: _name, department: _department, email: _email);
              } else {
                await provider.addUser(name: _name, department: _department, email: _email, password: '', isAdmin: false);
              }
              Navigator.pop(context);
            }
          },
          child: const Text('Save Person'),
        ),
      ],
    );
  }
}
