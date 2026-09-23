import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/asset_api_service.dart';
import '../providers/auth_provider.dart';
import 'scan_assignment_view.dart';

class GlobalSearchView extends StatefulWidget {
  const GlobalSearchView({super.key, required this.query});
  final String query;
  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends State<GlobalSearchView> {
  Timer? _timer;
  String _query = '';
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _query = widget.query.trim().toLowerCase();
  }

  @override
  void didUpdateWidget(GlobalSearchView old) {
    super.didUpdateWidget(old);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _query = widget.query.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _open(String tag) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final item =
          await AssetApiService(token: context.read<AuthProvider>().apiToken!)
              .lookup(tag)
              .timeout(const Duration(seconds: 12));
      if (mounted)
        await showDialog<void>(
            context: context, builder: (_) => AssignmentDialog(result: item));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is AssetApiException
                ? e.message
                : 'Connection unavailable. Retry when online.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final results = <Widget>[];
    if (_query.isNotEmpty)
      for (final asset in provider.assets) {
        final fields = {
          'Tag number': asset.id,
          'Asset name':
              '${asset.name} ${asset.customFields['modelSpecs'] ?? ''}',
          'Asset type':
              '${asset.category} ${asset.customFields['deviceType'] ?? ''}',
          'Company': provider.companyName
        };
        final matched = fields.entries
            .where((e) => e.value.toLowerCase().contains(_query))
            .map((e) => e.key)
            .toList();
        if (matched.isNotEmpty)
          results.add(Card(
              child: ListTile(
                  enabled: !_busy,
                  title: Text(asset.id),
                  subtitle:
                      Text('${asset.category} · matched ${matched.join(', ')}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(asset.id))));
        if (results.length == 40) break;
      }
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Search results', style: Theme.of(context).textTheme.headlineSmall),
      if (_busy) const LinearProgressIndicator(),
      const SizedBox(height: 12),
      if (results.isEmpty)
        const Text(
            'No matching assets. Try part of a tag number, name, type or company.'),
      ...results
    ]);
  }
}
