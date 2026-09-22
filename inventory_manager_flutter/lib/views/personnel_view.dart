import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/models/personnel.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';

/// Personnel View — displays real people who own / are assigned physical assets.
/// This is NOT the Users & Access view (login accounts). That lives inside Settings.
class PersonnelView extends StatefulWidget {
  final String searchQuery;
  const PersonnelView({super.key, this.searchQuery = ''});

  @override
  State<PersonnelView> createState() => _PersonnelViewState();
}

class _PersonnelViewState extends State<PersonnelView> {
  void _openPersonnelForm(BuildContext context, [Personnel? person]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PersonnelFormDialog(person: person),
    );
  }

  void _showOwnershipDialog(BuildContext context, Personnel person) {
    showDialog(
      context: context,
      builder: (context) {
        final wsList = person.workstations;
        return AlertDialog(
          title: Text('Assets Assigned to ${person.fullName}'),
          content: SizedBox(
            width: 640,
            child: wsList.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'No assets currently assigned to this person.',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: wsList.map((ws) {
                        final tag = ws['workstationTag'] ?? '';
                        final deviceType = ws['deviceType'] ?? 'Workstation';
                        final status = ws['status'] ?? 'IN_STORE';
                        final peripherals = ws['peripherals'] is List
                            ? ws['peripherals'] as List
                            : [];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.computer_rounded,
                                        size: 20, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 8),
                                    Text(
                                      tag,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          fontSize: 15),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: _statusColor(status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (deviceType.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text('Type: $deviceType',
                                      style: const TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 13)),
                                ],
                                if (peripherals.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${peripherals.length} Peripheral(s):',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF818CF8)),
                                  ),
                                  const SizedBox(height: 4),
                                  ...peripherals.map((per) {
                                    final pMap = per is Map<String, dynamic>
                                        ? per
                                        : <String, dynamic>{};
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          left: 16.0, bottom: 2),
                                      child: Text(
                                        '• ${pMap['peripheralTag'] ?? ''} — ${pMap['category'] ?? 'Peripheral'}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFD1D5DB)),
                                      ),
                                    );
                                  }),
                                ],
                              ],
                            ),
                          ),
                        );
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
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'IN_STORE':
        return const Color(0xFF10B981);
      case 'ASSIGNED':
        return const Color(0xFF3B82F6);
      case 'OUT_OF_ORDER':
        return const Color(0xFFF59E0B);
      case 'RETIRED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'IN_STORE':
        return 'In Store';
      case 'ASSIGNED':
        return 'Assigned';
      case 'OUT_OF_ORDER':
        return 'Out of Order';
      case 'RETIRED':
        return 'Retired';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context);
    final personnelList = provider.personnel;

    final filtered = personnelList.where((p) {
      final query = widget.searchQuery.toLowerCase();
      if (query.isEmpty) return true;
      return p.fullName.toLowerCase().contains(query) ||
          p.department.toLowerCase().contains(query) ||
          p.contactEmail.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPersonnelForm(context),
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add_rounded),
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'People who own or are assigned physical assets. Not app login accounts.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                // Summary chips
                Row(
                  children: [
                    _summaryChip(
                        Icons.people_alt_rounded,
                        '${personnelList.length}',
                        'People',
                        const Color(0xFF6366F1)),
                    const SizedBox(width: 8),
                    _summaryChip(
                        Icons.computer_rounded,
                        '${personnelList.fold(0, (sum, p) => sum + p.workstationsCount)}',
                        'Workstations',
                        const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _summaryChip(
                        Icons.mouse_rounded,
                        '${personnelList.fold(0, (sum, p) => sum + p.peripheralsCount)}',
                        'Peripherals',
                        const Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Card(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 64,
                                color: Colors.white.withOpacity(0.1)),
                            const SizedBox(height: 16),
                            const Text(
                              'No personnel found.',
                              style: TextStyle(color: Color(0xFF9CA3AF)),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add people who own assets using the + button.',
                              style: TextStyle(
                                  color: Color(0xFF6B7280), fontSize: 13),
                            ),
                          ],
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
                                DataColumn(label: Text('CONTACT')),
                                DataColumn(label: Text('WORKSTATIONS')),
                                DataColumn(label: Text('PERIPHERALS')),
                                DataColumn(label: Text('ACTIONS')),
                              ],
                              rows: filtered.map((person) {
                                return DataRow(
                                  cells: [
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: const Color(0xFF6366F1)
                                              .withOpacity(0.2),
                                          child: Text(
                                            person.fullName.isNotEmpty
                                                ? person.fullName[0]
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Color(0xFF818CF8),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(person.fullName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    )),
                                    DataCell(Text(person.department.isEmpty
                                        ? '—'
                                        : person.department)),
                                    DataCell(Text(person.contactEmail.isEmpty
                                        ? '—'
                                        : person.contactEmail)),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${person.workstationsCount}',
                                          style: const TextStyle(
                                            color: Color(0xFF60A5FA),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${person.peripheralsCount}',
                                          style: const TextStyle(
                                            color: Color(0xFF34D399),
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
                                            icon: const Icon(
                                                Icons.inventory_2_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _showOwnershipDialog(
                                                    context, person),
                                            tooltip: 'View Assigned Assets',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 20),
                                            onPressed: () =>
                                                _openPersonnelForm(
                                                    context, person),
                                            tooltip: 'Edit',
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: Color(0xFFEF4444)),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                      'Delete Personnel'),
                                                  content: Text(
                                                      'Delete ${person.fullName}? All assets assigned to them will be unassigned.'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        provider
                                                            .deletePersonnel(
                                                                person.id);
                                                        Navigator.pop(ctx);
                                                      },
                                                      child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                              color: Color(
                                                                  0xFFEF4444))),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            tooltip: 'Delete',
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

  Widget _summaryChip(
      IconData icon, String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(count,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }
}

// =============================================================================
// Personnel Form Dialog (Add / Edit)
// =============================================================================
class PersonnelFormDialog extends StatefulWidget {
  final Personnel? person;
  const PersonnelFormDialog({super.key, this.person});

  @override
  State<PersonnelFormDialog> createState() => _PersonnelFormDialogState();
}

class _PersonnelFormDialogState extends State<PersonnelFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _fullName;
  late String _department;
  late String _contactEmail;
  late String _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fullName = widget.person?.fullName ?? '';
    _department = widget.person?.department ?? '';
    _contactEmail = widget.person?.contactEmail ?? '';
    _notes = widget.person?.notes ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final isEdit = widget.person != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Personnel' : 'Add Personnel'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: _fullName,
                decoration: const InputDecoration(
                    labelText: 'Full Name', hintText: 'e.g. John Smith'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
                onSaved: (v) => _fullName = v!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _department,
                decoration: const InputDecoration(
                    labelText: 'Department', hintText: 'e.g. Engineering'),
                onSaved: (v) => _department = v?.trim() ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _contactEmail,
                decoration: const InputDecoration(
                    labelText: 'Contact Email',
                    hintText: 'john@company.com'),
                keyboardType: TextInputType.emailAddress,
                onSaved: (v) => _contactEmail = v?.trim() ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _notes,
                decoration: const InputDecoration(
                    labelText: 'Notes', hintText: 'Optional notes'),
                maxLines: 2,
                onSaved: (v) => _notes = v?.trim() ?? '',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    setState(() => _saving = true);
                    try {
                      if (isEdit) {
                        await provider.updatePersonnel(
                          widget.person!.id,
                          fullName: _fullName,
                          department: _department,
                          contactEmail: _contactEmail,
                          notes: _notes,
                        );
                      } else {
                        await provider.addPersonnel(
                          fullName: _fullName,
                          department: _department,
                          contactEmail: _contactEmail,
                          notes: _notes,
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _saving = false);
                    }
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save Changes' : 'Add Person'),
        ),
      ],
    );
  }
}
