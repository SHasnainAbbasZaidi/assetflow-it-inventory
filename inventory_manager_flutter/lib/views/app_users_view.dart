import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/models/user.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';

class AppUsersView extends StatefulWidget {
  const AppUsersView({super.key});

  @override
  State<AppUsersView> createState() => _AppUsersViewState();
}

class _AppUsersViewState extends State<AppUsersView> {
  void _openUserForm(BuildContext context, [User? user]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppUserFormDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUserForm(context),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: AppUserManagementSection(
          showHeader: true,
          onAddUser: () => _openUserForm(context),
        ),
      ),
    );
  }
}

class AppUserManagementSection extends StatelessWidget {
  final bool showHeader;
  final VoidCallback? onAddUser;

  const AppUserManagementSection({
    super.key,
    this.showHeader = false,
    this.onAddUser,
  });

  void _openUserForm(BuildContext context, [User? user]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppUserFormDialog(user: user),
    );
  }

  void _confirmDelete(
      BuildContext context, InventoryProvider provider, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: Text(
          'Are you sure you want to delete the account for "${user.name}"?\n'
          'This cannot be undone.',
        ),
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
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final appUsers =
            provider.users.where((u) => u.id != 'unassigned').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrative Users',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage app login accounts and access levels.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (onAddUser != null)
                    FloatingActionButton.extended(
                      heroTag: 'add-admin-user',
                      onPressed: onAddUser,
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Add User'),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
            Expanded(
              child: Card(
                child: appUsers.isEmpty
                    ? const Center(
                        child: Text(
                          'No administrative users found.',
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
                                DataColumn(label: Text('USERNAME')),
                                DataColumn(label: Text('EMAIL')),
                                DataColumn(label: Text('DEPARTMENT')),
                                DataColumn(label: Text('ROLE')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: appUsers.map((user) {
                                final isAdmin = user.isAdmin;
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: isAdmin
                                                ? const Color(0xFF6366F1)
                                                    .withOpacity(0.2)
                                                : Colors.white
                                                    .withOpacity(0.08),
                                            child: Text(
                                              user.name.isNotEmpty
                                                  ? user.name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: isAdmin
                                                    ? const Color(0xFF6366F1)
                                                    : const Color(0xFF9CA3AF),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(user.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    DataCell(Text(user.email)),
                                    DataCell(Text(user.department)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isAdmin
                                              ? const Color(0xFF6366F1)
                                                  .withOpacity(0.12)
                                              : Colors.white.withOpacity(0.06),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isAdmin
                                                ? const Color(0xFF6366F1)
                                                    .withOpacity(0.3)
                                                : Colors.white.withOpacity(0.1),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isAdmin
                                                  ? Icons.shield_rounded
                                                  : Icons.person_rounded,
                                              size: 12,
                                              color: isAdmin
                                                  ? const Color(0xFF818CF8)
                                                  : const Color(0xFF9CA3AF),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isAdmin
                                                  ? 'Administrator'
                                                  : 'Standard User',
                                              style: TextStyle(
                                                color: isAdmin
                                                    ? const Color(0xFF818CF8)
                                                    : const Color(0xFF9CA3AF),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _openUserForm(context, user),
                                            tooltip: 'Edit User',
                                          ),
                                          if (user.id != 'admin')
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 20,
                                                  color: Color(0xFFEF4444)),
                                              onPressed: () => _confirmDelete(
                                                  context, provider, user),
                                              tooltip: 'Delete User',
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
        );
      },
    );
  }
}

class AppUserFormDialog extends StatefulWidget {
  final User? user;
  const AppUserFormDialog({super.key, this.user});

  @override
  State<AppUserFormDialog> createState() => _AppUserFormDialogState();
}

class _AppUserFormDialogState extends State<AppUserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _email;
  late String _department;
  late String _password;
  late bool _isAdmin;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _name = widget.user?.name ?? '';
    _email = widget.user?.email ?? '';
    _department = widget.user?.department ?? '';
    _password = '';
    _isAdmin = widget.user?.isAdmin ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final isEdit = widget.user != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit User Account' : 'Create User Account'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Username / Full Name',
                  hintText: 'e.g. John Doe',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                onSaved: (v) => _name = v!.trim(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'john@company.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v))
                    return 'Enter valid email';
                  return null;
                },
                onSaved: (v) => _email = v!.trim(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: _department,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  hintText: 'e.g. IT',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
                onSaved: (v) => _department = v!.trim(),
              ),
              const SizedBox(height: 14),
              TextFormField(
                decoration: InputDecoration(
                  labelText: isEdit
                      ? 'New Password (leave blank to keep)'
                      : 'Password',
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (v) {
                  if (!isEdit && (v == null || v.trim().isEmpty))
                    return 'Password required for new users';
                  return null;
                },
                onSaved: (v) => _password = v?.trim() ?? '',
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded,
                        size: 18, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Administrator Access',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          Text(
                              'Full access to all features including user management',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _isAdmin,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (v) => setState(() => _isAdmin = v),
                    ),
                  ],
                ),
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
                final finalPassword =
                    _password.isEmpty ? widget.user!.password : _password;
                await provider.updateAppUser(
                  widget.user!.id,
                  name: _name,
                  email: _email,
                  department: _department,
                  password: finalPassword,
                  isAdmin: _isAdmin,
                );
              } else {
                await provider.addUser(
                  name: _name,
                  email: _email,
                  department: _department,
                  password: _password,
                  isAdmin: _isAdmin,
                );
              }
              Navigator.pop(context);
            }
          },
          child: Text(isEdit ? 'Save Changes' : 'Create User'),
        ),
      ],
    );
  }
}
