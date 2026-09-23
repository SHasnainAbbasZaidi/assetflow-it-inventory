import 'scrap_report_view.dart';
// A product of Mahzaidex Tech Developed by Hasnain Zaidi.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../services/asset_api_service.dart';
import '../services/database_service.dart';
import 'login_view.dart';

class AdminToolsView extends StatefulWidget {
  final String mode;
  const AdminToolsView({super.key, required this.mode});
  @override
  State<AdminToolsView> createState() => _AdminToolsViewState();
}

class _AdminToolsViewState extends State<AdminToolsView> {
  bool busy = false;
  String? error;
  String reportType = 'inventory', status = '', kind = 'workstation';
  String? tag;
  Map<String, dynamic>? report, backups;
  List<dynamic> assets = [];
  final confirmation = TextEditingController();
  final person = TextEditingController(),
      from = TextEditingController(),
      to = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run(load));
  }

  @override
  void dispose() {
    confirmation.dispose();
    person.dispose();
    from.dispose();
    to.dispose();
    super.dispose();
  }

  Future<http.Response> request(String path,
      {Map<String, dynamic>? body}) async {
    final auth = context.read<AuthProvider>();
    final uri = Uri.parse('${AssetApiService.baseUrl}/api/admin$path');
    final headers = {
      'Authorization': 'Bearer ${auth.apiToken}',
      'Content-Type': 'application/json'
    };
    final response = body == null
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));
    check(response.statusCode, response.bodyBytes);
    return response;
  }

  void check(int status, Uint8List bytes) {
    if (status >= 400) {
      final body = jsonDecode(utf8.decode(bytes));
      throw Exception(body['error']?['message'] ?? 'Request failed.');
    }
  }

  Future<void> run(Future<void> Function() task) async {
    if (busy || !(context.read<AuthProvider>().currentUser?.isAdmin ?? false))
      return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    if (widget.mode == 'backups')
      backups = jsonDecode((await request('/backups')).body);
    if (widget.mode == 'delete') {
      final auth = context.read<AuthProvider>();
      final api =
          AssetApiService(token: auth.apiToken!, serverUrl: auth.serverUrl);
      assets = kind == 'workstation'
          ? await api.getWorkstations()
          : await api.getPeripherals();
      tag = null;
    }
  }

  Future<void> save(String name, Uint8List bytes) async {
    await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup or report',
        fileName: name,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: [name.split('.').last]);
  }

  Future<bool> confirmRestore() async => await ask(
      'Restore complete application state',
      'Current inventory, accounts, passwords and settings will be replaced. A recovery copy is saved first. Type RESTORE to continue.',
      'RESTORE');
  Future<bool> ask(String title, String message, String expected) async {
    String typed = '';
    return await showDialog<bool>(
            context: context,
            builder: (dialog) => AlertDialog(
                    title: Text(title),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(message),
                      TextField(
                          onChanged: (v) => typed = v,
                          decoration:
                              const InputDecoration(labelText: 'Confirmation'))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () {
                            if (typed == expected) Navigator.pop(dialog, true);
                          },
                          child: const Text('Confirm'))
                    ])) ??
        false;
  }

  Future<void> restore({String? name, String? source, Uint8List? bytes}) async {
    if (!await confirmRestore()) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (bytes != null) {
      final req = http.MultipartRequest(
          'POST', Uri.parse('${AssetApiService.baseUrl}/api/admin/restore'));
      req.headers['Authorization'] = 'Bearer ${auth.apiToken}';
      req.fields['confirmation'] = 'RESTORE';
      req.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: 'backup.json'));
      final response = await http.Response.fromStream(await req.send());
      check(response.statusCode, response.bodyBytes);
    } else {
      await request('/restore',
          body: {'kind': source, 'name': name, 'confirmation': 'RESTORE'});
    }
    if (mounted) {
      // Refresh the local inventory cache before ending the administrator session.
      try {
        await context.read<InventoryProvider>().syncWithServer(auth.apiToken!);
      } catch (_) {}
      await auth.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginView()), (_) => false);
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'State restored. Sign in with an account from the backup.')));
    }
  }

  Widget button(String text, Future<void> Function() task) => OutlinedButton(
      onPressed: busy ? null : () => run(task), child: Text(text));
  Widget select(String label, String value, Map<String, String> choices,
          void Function(String) change) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: choices.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: busy ? null : (v) => setState(() => change(v!))));
  Future<void> generate(bool download) async {
    final query = Uri(queryParameters: {
      'type': reportType,
      'status': status,
      'personnelId': person.text.trim(),
      'from': from.text.trim(),
      'to': to.text.trim(),
      if (download) 'format': 'xlsx'
    }).query;
    final response = await request('/reports?$query');
    if (download) {
      await save('assetflow-$reportType.xlsx', response.bodyBytes);
    } else {
      report = jsonDecode(response.body);
    }
  }

  List<Widget> reportWidgets() => [
        OutlinedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ScrapReportView())),
            child: const Text('Scrap Items Report')),
        const Text('Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        select(
            'Report',
            reportType,
            {
              'inventory': 'Inventory items',
              'personnel': 'Person-wise inventory',
              'warranty': 'Warranty register',
              'users': 'User accounts',
              'audit': 'Audit records'
            },
            (v) => reportType = v),
        select(
            'Asset status',
            status,
            {
              '': 'All statuses',
              'IN_STORE': 'In store',
              'ASSIGNED': 'Assigned',
              'RETIRED': 'Retired',
              'SCRAPPED': 'Scrapped',
              'OUT_OF_ORDER': 'Out of order'
            },
            (v) => status = v),
        DropdownButtonFormField<String>(
            initialValue: person.text.isEmpty ? '' : person.text,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Person'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Everyone')),
              ...context.read<InventoryProvider>().personnel.map(
                  (p) => DropdownMenuItem(value: p.id, child: Text(p.fullName)))
            ],
            onChanged: (v) => person.text = v ?? ''),
        if (reportType == 'audit') ...[
          TextField(
              controller: from,
              decoration:
                  const InputDecoration(labelText: 'From (YYYY-MM-DD)')),
          TextField(
              controller: to,
              decoration:
                  const InputDecoration(labelText: 'Through (YYYY-MM-DD)'))
        ],
        Wrap(spacing: 12, children: [
          button('Generate report', () => generate(false)),
          button('Download Excel', () => generate(true))
        ]),
        if (report != null) ...[
          Text('${report!['total']} records (preview up to 500)'),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  columns: (report!['columns'] as List)
                      .map((c) => DataColumn(label: Text('$c')))
                      .toList(),
                  rows: (report!['rows'] as List)
                      .map((row) => DataRow(
                          cells: (report!['columns'] as List)
                              .map((c) => DataCell(Text('${row[c] ?? ''}')))
                              .toList()))
                      .toList()))
        ]
      ];
  List<Widget> backupWidgets() => [
        const Text('Backup and Restore',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text(
            'Daily backups run on the server. The latest 10 Excel exports and 10 automatic full-state backups are kept separately. Manual and recovery copies are retained.'),
        const Text(
            'Full-state files include accounts and password hashes. Keep downloaded files secure. Restoring replaces all application data.'),
        Wrap(spacing: 12, children: [
          button('Back up complete state', () async {
            final saved =
                jsonDecode((await request('/backups', body: {})).body);
            final response = await request(
                '/backups/manual/${Uri.encodeComponent(saved['name'])}');
            await save(saved['name'], response.bodyBytes);
            await load();
          }),
          button('Restore from file', () async {
            final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
                withData: true);
            if (result?.files.first.bytes != null)
              await restore(bytes: result!.files.first.bytes);
          }),
          button('Refresh', load)
        ]),
        if (backups?['lastError'] != null)
          Text(backups!['lastError'],
              style: const TextStyle(color: Colors.redAccent)),
        for (final source in ['automatic', 'manual', 'excel']) ...[
          Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                  {
                    'automatic': 'Automatic restorable backups',
                    'manual': 'Manual & recovery backups',
                    'excel': 'Excel exports (Backup folder)'
                  }[source]!,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          if ((backups?[source] as List? ?? []).isEmpty)
            const Text('No backups yet.'),
          for (final file in (backups?[source] as List? ?? []))
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(file['createdAt']),
                          Text(file['name'],
                              style: const TextStyle(fontSize: 11)),
                          Wrap(spacing: 8, children: [
                            button('Download', () async {
                              final response = await request(
                                  '/backups/$source/${Uri.encodeComponent(file['name'])}');
                              await save(file['name'], response.bodyBytes);
                            }),
                            if (source != 'excel')
                              button(
                                  'Restore',
                                  () => restore(
                                      name: file['name'], source: source))
                          ])
                        ]))),
        ]
      ];
  List<Widget> deleteWidgets() => [
        const Text('Super Power Delete',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text(
            'Permanently deletes one item without a new log or notification. Historical records remain. Attached peripherals are kept when deleting a workstation.'),
        select('Item type', kind,
            {'workstation': 'Workstation', 'peripheral': 'Peripheral'}, (v) {
          kind = v;
          assets = [];
          tag = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => run(load));
        }),
        DropdownButtonFormField<String>(
            key: ValueKey('$kind-$tag-${assets.length}'),
            initialValue: tag,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Inventory item'),
            items: assets
                .map((a) => DropdownMenuItem<String>(
                    value: a['${kind}Tag'], child: Text(a['${kind}Tag'])))
                .toList(),
            onChanged: busy ? null : (v) => setState(() => tag = v)),
        TextField(
            controller: confirmation,
            decoration: const InputDecoration(
                labelText: 'Type the exact tag to confirm')),
        button('Permanently delete item', () async {
          if (tag == null || confirmation.text != tag)
            throw Exception('Type the exact selected tag to confirm.');
          await request('/super-delete', body: {
            'kind': kind,
            'tag': tag,
            'confirmation': confirmation.text
          });
          confirmation.clear();
          if (mounted)
            await context
                .read<InventoryProvider>()
                .syncWithServer(context.read<AuthProvider>().apiToken!);
          await load();
        }),
      ];
  @override
  Widget build(BuildContext context) {
    if (!(context.watch<AuthProvider>().currentUser?.isAdmin ?? false))
      return const SizedBox.shrink();
    final children = <Widget>[
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.redAccent)),
      ...widget.mode == 'reports'
          ? reportWidgets()
          : widget.mode == 'backups'
              ? backupWidgets()
              : deleteWidgets()
    ];
    return widget.mode == 'reports'
        ? ListView(padding: const EdgeInsets.all(20), children: children)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
