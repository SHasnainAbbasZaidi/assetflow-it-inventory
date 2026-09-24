import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../utils/hardware_groups.dart';
import 'dashboard_view.dart';

class InventoryOverviewView extends StatelessWidget {
  const InventoryOverviewView({super.key});
  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final assets = inventory.assets;
    final metrics = {
      'Total inventory': assets.length,
      'Assigned': assets.where((a) => a.status == 'Assigned').length,
      'In store': assets.where((a) => a.status == 'In Store').length,
      'Needs attention': assets.where((a) => a.status == 'Out of Order').length,
    };
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('Dashboard Overview', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      const Text('Inventory health and recent activity across all hardware'),
      const SizedBox(height: 20),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final entry in metrics.entries)
          SizedBox(width: 150, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key), Text('${entry.value}', style: Theme.of(context).textTheme.headlineMedium)])))),
      ]),
      const SizedBox(height: 20),
      Text('Hardware categories', style: Theme.of(context).textTheme.titleLarge),
      for (final group in HardwareGroups.names)
        Card(child: ListTile(contentPadding: const EdgeInsets.all(16), title: Text(group), subtitle: Text(HardwareGroups.descriptions[group]!), trailing: Text('${assets.where((a) => HardwareGroups.classify(a.category, workstation: inventory.workstations.contains(a)) == group).length}'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(group)), body: DashboardView(initialGroup: group)))))),
      const SizedBox(height: 20),
      Text('Lifecycle summary', style: Theme.of(context).textTheme.titleLarge),
      Text('Retired: ${assets.where((a) => a.status == 'Retired').length}'),
      Text('Scrapped: ${assets.where((a) => a.status == 'Scrapped').length}'),
      Text('Personnel: ${inventory.personnel.length}'),
      const SizedBox(height: 20),
      Text('Recent activity', style: Theme.of(context).textTheme.titleLarge),
      if (inventory.logs.isEmpty) const Text('No recent activity.'),
      for (final log in inventory.logs.take(5)) ListTile(title: Text(log.action), subtitle: Text('${log.assetId} · ${log.timestamp}')),
      const SizedBox(height: 80),
    ]);
  }
}
