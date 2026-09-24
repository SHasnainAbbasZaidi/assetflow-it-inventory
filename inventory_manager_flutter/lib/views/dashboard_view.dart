import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/asset.dart';
import '../services/database_service.dart';
import '../utils/hardware_groups.dart';
import 'asset_qr_dialog.dart';
import 'workstations_view.dart' as ws;
import 'peripherals_view.dart' as peripheral;

class DashboardView extends StatefulWidget {
  final String initialGroup;
  const DashboardView({super.key, this.initialGroup = 'Workstations'});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}
class _DashboardViewState extends State<DashboardView> {
  late String group = widget.initialGroup;
  String query = '', status = '';
  @override
  void didUpdateWidget(covariant DashboardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialGroup != widget.initialGroup) group = widget.initialGroup;
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final assets = provider.assets;
    String category(Asset a) => HardwareGroups.classify(a.category, workstation: provider.workstations.contains(a));
    final categoryAssets = assets.where((a) => category(a) == group).toList();
    final filtered = categoryAssets.where((a) => (status.isEmpty || a.status == status) && '${a.id} ${a.category} ${a.assignee} ${a.customFields}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(backgroundColor: Colors.transparent, body: LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 600;
      return ListView(padding: EdgeInsets.all(narrow ? 16 : 28), children: [
        Text(group, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Search, edit and print tags for ${group.toLowerCase()}'),
        const SizedBox(height: 22),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final entry in {'Total items': categoryAssets.length, 'Assigned': categoryAssets.where((a) => a.status == 'Assigned').length, 'In store': categoryAssets.where((a) => a.status == 'In Store').length, 'Scrapped': categoryAssets.where((a) => a.status == 'Scrapped').length}.entries)
            SizedBox(width: (constraints.maxWidth - (narrow ? 44 : 92)) / (narrow ? 2 : 4), child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key), const SizedBox(height: 8), Text('${entry.value}', style: Theme.of(context).textTheme.headlineMedium)])))),
        ]),
        const SizedBox(height: 20),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final name in HardwareGroups.names) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text('$name  ${assets.where((a) => category(a) == name).length}'), selected: group == name, onSelected: (_) => setState(() { group = name; status = ''; }))),
        ])),
        const SizedBox(height: 20),
        Text(group, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(HardwareGroups.descriptions[group]!),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(icon: const Icon(Icons.table_rows_outlined), label: const Text('Full list, import & bulk print'), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(group)), body: group == 'Workstations' ? const ws.WorkstationsView() : peripheral.PeripheralsView(hardwareGroup: group)))))),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Add item'), onPressed: () => showDialog(context: context, builder: (_) => group == 'Workstations' ? const ws.AssetFormDialog(category: 'Workstation') : peripheral.AssetFormDialog(category: group == 'Devices' ? 'Printer' : group == 'Components' ? 'RAM' : 'Keyboard')))),
        const SizedBox(height: 16),
        TextField(decoration: const InputDecoration(labelText: 'Search tag, details or owner', prefixIcon: Icon(Icons.search)), onChanged: (value) => setState(() => query = value)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(key: ValueKey(group), initialValue: status, decoration: const InputDecoration(labelText: 'Status'), items: [const DropdownMenuItem(value: '', child: Text('All statuses')), for (final s in ['In Store','Assigned','Out of Order','Retired','Scrapped']) DropdownMenuItem(value: s, child: Text(s))], onChanged: (value) => setState(() => status = value ?? '')),
        const SizedBox(height: 16),
        if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No items match this category and filter.')),
        for (final asset in filtered) Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [Text(asset.id, style: const TextStyle(fontWeight: FontWeight.bold)), Chip(label: Text(asset.status))]),
          Text(provider.workstations.contains(asset) ? asset.customFields['deviceType']?.toString() ?? 'Workstation' : asset.category, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Owner: ${asset.assignee.isEmpty ? 'Unassigned' : asset.assignee}'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(icon: const Icon(Icons.qr_code), label: const Text('Details & tag'), onPressed: () => showDialog(context: context, builder: (_) => AssetQrDialog(asset: asset))),
            if (asset.status != 'Scrapped') OutlinedButton.icon(icon: const Icon(Icons.edit_outlined), label: const Text('Edit'), onPressed: () => showDialog(context: context, builder: (_) => provider.workstations.contains(asset) ? ws.AssetFormDialog(asset: asset, category: 'Workstation') : peripheral.AssetFormDialog(asset: asset, category: asset.category))),
          ]),
        ]))),
        const SizedBox(height: 80),
      ]);
    }));
  }
}
