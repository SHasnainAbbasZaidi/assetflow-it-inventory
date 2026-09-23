import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/asset_api_service.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'package:inventory_manager_flutter/providers/auth_provider.dart';
import 'package:inventory_manager_flutter/utils/scan_payload.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanAssignmentView extends StatefulWidget {
  const ScanAssignmentView({super.key});
  @override
  State<ScanAssignmentView> createState() => _ScanAssignmentViewState();
}

class _ScanAssignmentViewState extends State<ScanAssignmentView> {
  final _input = TextEditingController();
  final _camera = MobileScannerController();
  bool _busy = false, _paused = false;
  String? _error, _last;
  @override
  void dispose() {
    _input.dispose();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _scan(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _paused = true;
      _error = null;
      _last = code;
    });
    try {
      try {
        await _camera.stop();
      } catch (_) {}
      final tag = parseScanPayload(code);
      if (!mounted) return;
      final token = context.read<AuthProvider>().apiToken;
      if (token == null)
        throw const AssetApiException('Sign in before scanning.');
      final result = await AssetApiService(token: token)
          .lookup(tag)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AssignmentDialog(result: result));
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on AssetNotFoundException {
      if (mounted)
        setState(() => _error =
            'No matching item. Check the label or enter its tag manually.');
    } on AssetApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Cannot reach the server. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    try {
      await _camera.start();
      if (mounted)
        setState(() {
          _paused = false;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Camera unavailable. Enable camera permission in device settings or use manual entry.');
    }
  }

  @override
  Widget build(BuildContext context) => Center(
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Scan & assign',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('Scan a tag, confirm the item, then choose its owner.'),
            const SizedBox(height: 20),
            ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                    height: 260,
                    child: MobileScanner(
                        controller: _camera,
                        onDetect: (capture) {
                          if (!_paused && !_busy) {
                            final code = capture.barcodes.firstOrNull?.rawValue;
                            if (code != null) _scan(code);
                          }
                        },
                        errorBuilder: (_, error, __) => Center(
                            child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                    error.errorCode ==
                                            MobileScannerErrorCode
                                                .permissionDenied
                                        ? 'Camera permission denied. Enable it in device settings or enter the tag below.'
                                        : 'Camera unavailable. Retry or enter the tag below.',
                                    textAlign: TextAlign.center)))))),
            if (_busy)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.orangeAccent))),
            const SizedBox(height: 16),
            if (_paused && !_busy)
              FilledButton.icon(
                  onPressed: _resume,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan another item')),
            if (_error != null && _last != null && !_busy)
              TextButton(
                  onPressed: () => _scan(_last!),
                  child: const Text('Retry lookup')),
            const SizedBox(height: 16),
            TextField(
                controller: _input,
                enabled: !_busy,
                decoration: const InputDecoration(
                    labelText: 'Manual tag lookup',
                    hintText: 'Enter tag number',
                    prefixIcon: Icon(Icons.search)),
                onSubmitted: _scan),
            const SizedBox(height: 12),
            OutlinedButton(
                onPressed: _busy ? null : () => _scan(_input.text),
                child: const Text('Find item')),
          ])));
}

class AssignmentDialog extends StatefulWidget {
  const AssignmentDialog({super.key, required this.result});
  final AssetLookup result;
  @override
  State<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<AssignmentDialog> {
  List<dynamic> _people = [];
  String _query = '';
  String? _personId, _error, _assignedName;
  bool _loading = true, _saving = false, _confirm = false, _done = false;
  String get _tag => (widget.result.data[widget.result.type == 'workstation'
              ? 'workstationTag'
              : 'peripheralTag'] ??
          '')
      .toString();
  bool get _assigned =>
      widget.result.data['status'] == 'ASSIGNED' ||
      widget.result.data['personnelId'] != null ||
      (widget.result.type == 'peripheral' &&
          widget.result.data['workstationTag'] != null);
  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final people =
          await AssetApiService(token: context.read<AuthProvider>().apiToken!)
              .getPersonnel()
              .timeout(const Duration(seconds: 12));
      if (mounted) setState(() => _people = people);
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Cannot load people. Check your connection and retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign() async {
    if (_saving || _personId == null || _done) return;
    final token = context.read<AuthProvider>().apiToken!;
    final inventory = context.read<InventoryProvider>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response =
          await AssetApiService(token: token).assign(widget.result.type, _tag, {
        'personnelId': _personId,
        'expectedState': widget.result.data['assignmentState'],
        'allowReassign': _confirm
      }).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _done = true;
        _assignedName = response['person']['fullName'];
      });
      try {
        await inventory
            .syncWithServer(token)
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        if (mounted)
          setState(() => _error =
              'Assignment saved. Reconnect and refresh inventory to see the latest data.');
      }
    } on AssetApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Connection interrupted. Retry is safe: duplicate assignments are prevented.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.result.data;
    final owner = item['personnel']?['fullName'] ??
        item['workstation']?['personnel']?['fullName'] ??
        item['userName'] ??
        'Unassigned';
    final matches = _people
        .where((p) => '${p['fullName']} ${p['department'] ?? ''}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase()))
        .take(30)
        .toList();
    final blocked = ['RETIRED', 'OUT_OF_ORDER'].contains(item['status']);
    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
            title: Text(_done ? 'Assignment complete' : _tag),
            content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(
                          '${item['deviceType'] ?? item['category'] ?? widget.result.type} · ${item['modelSpecs'] ?? item['processorGen'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('Status: ${_done ? 'ASSIGNED' : item['status']}'),
                      Text('Owner: ${_done ? _assignedName : owner}'),
                      if (_done) ...[
                        const SizedBox(height: 16),
                        Text('$_tag is assigned to $_assignedName.',
                            style: const TextStyle(color: Colors.greenAccent))
                      ] else ...[
                        if (_assigned)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _confirm,
                              onChanged: _saving
                                  ? null
                                  : (v) =>
                                      setState(() => _confirm = v ?? false),
                              title: const Text('Confirm reassignment'),
                              subtitle: Text(widget.result.type ==
                                          'peripheral' &&
                                      item['workstationTag'] != null
                                  ? 'This detaches the peripheral from ${item['workstationTag']}.'
                                  : 'Linked peripherals follow their workstation owner.')),
                        if (blocked)
                          const Text(
                              'Restore this item to service before assigning.',
                              style: TextStyle(color: Colors.orangeAccent)),
                        const SizedBox(height: 16),
                        if (_loading) const LinearProgressIndicator(),
                        TextField(
                            enabled: !_saving,
                            decoration: const InputDecoration(
                                labelText: 'Search people',
                                prefixIcon: Icon(Icons.person_search)),
                            onChanged: (v) => setState(() => _query = v)),
                        if (_personId != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                  'Selected: ${_people.firstWhere((p) => p['id'] == _personId)['fullName']}')),
                        if (!_loading && matches.isEmpty)
                          const Text(
                              'No people found. Add a person in Personnel first.'),
                        ...matches.map((p) => ListTile(
                            selected: _personId == p['id'],
                            leading: Icon(_personId == p['id']
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            title: Text(p['fullName']),
                            subtitle: Text(p['department'] ?? ''),
                            onTap: _saving
                                ? null
                                : () => setState(() => _personId = p['id']))),
                      ],
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: Colors.orangeAccent))),
                      if (_error != null && _people.isEmpty)
                        TextButton(
                            onPressed: _loadPeople,
                            child: const Text('Retry loading people')),
                    ]))),
            actions: [
              TextButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: Text(_done ? 'Scan another item' : 'Cancel')),
              if (!_done)
                FilledButton(
                    onPressed: _loading ||
                            _saving ||
                            blocked ||
                            _personId == null ||
                            (_assigned && !_confirm)
                        ? null
                        : _assign,
                    child: Text(_saving ? 'Saving…' : 'Assign to person')),
            ]));
  }
}
