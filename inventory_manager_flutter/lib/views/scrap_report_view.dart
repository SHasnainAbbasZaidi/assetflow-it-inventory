// Mahzaidex Tech — developed by Hasnain Zaidi.
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/auth_provider.dart';
import '../services/asset_api_service.dart';
import '../services/database_service.dart';

class ScrapReportView extends StatefulWidget {
  const ScrapReportView({super.key});
  @override
  State<ScrapReportView> createState() => _ScrapReportViewState();
}

class _ScrapReportViewState extends State<ScrapReportView> {
  final tags = TextEditingController();
  Map<String, dynamic>? preview, report;
  List<dynamic> history = [];
  String requestId = '', previewTags = '';
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run(load));
  }

  @override
  void dispose() {
    tags.dispose();
    super.dispose();
  }

  Future<http.Response> request(String route,
      {Map<String, dynamic>? body}) async {
    final headers = {
      'Authorization': 'Bearer ${context.read<AuthProvider>().apiToken}',
      'Content-Type': 'application/json'
    };
    final uri = Uri.parse('${AssetApiService.baseUrl}/api/admin/scrap$route');
    final response = body == null
        ? await http.get(uri, headers: headers)
        : await http.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode >= 400)
      throw Exception(
          jsonDecode(response.body)['error']?['message'] ?? 'Request failed.');
    return response;
  }

  Future<void> load() async {
    history = jsonDecode((await request('')).body);
  }

  Future<void> run(Future<void> Function() fn) async {
    if (busy || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await fn();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String uuid() {
    final r = Random.secure();
    final values = List.generate(16, (_) => r.nextInt(256));
    values[6] = (values[6] & 15) | 64;
    values[8] = (values[8] & 63) | 128;
    final s = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  Future<void> commit() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Confirm scrap'),
                content: const Text(
                    'Mark every previewed item as SCRAPPED and save the report? Scrapped items cannot be assigned again.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'))
                ]));
    if (confirmed != true) return;
    report = jsonDecode((await request('', body: {
      'tags': previewTags,
      'fingerprint': preview!['fingerprint'],
      'requestId': requestId
    }))
        .body);
    preview = null;
    if (mounted)
      await context
          .read<InventoryProvider>()
          .syncWithServer(context.read<AuthProvider>().apiToken!);
    await load();
  }

  Future<void> pdf() async {
    final value = report!, doc = pw.Document();
    doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        header: (_) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Scrap Items Report',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Reference: ${value['id']} | Date: ${value['date']}'),
                  pw.Text(
                      'Operator: ${value['operator']['name']} | ${value['operator']['email']} | ${value['operator']['role']}'),
                  pw.SizedBox(height: 10)
                ]),
        footer: (_) => pw.Text('Mahzaidex Tech - Developed by Hasnain Zaidi',
            style: const pw.TextStyle(fontSize: 8)),
        build: (_) => [
              pw.TableHelper.fromTextArray(
                  headers: [
                    'Tag',
                    'Type',
                    'Description',
                    'Previous status',
                    'Status',
                    'Previous owner',
                    'Qty',
                    'Details'
                  ],
                  data: (value['rows'] as List)
                      .map((r) => [
                            r['tag'],
                            r['type'],
                            r['description'],
                            r['previousStatus'],
                            r['status'],
                            r['person'],
                            r['quantity'].toString(),
                            jsonEncode(r['details'])
                          ])
                      .toList(),
                  cellStyle: const pw.TextStyle(fontSize: 7),
                  headerStyle:
                      pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.topLeft)
            ]));
    await FilePicker.platform.saveFile(
        fileName: 'scrap-report-${value['id']}.pdf', bytes: await doc.save());
  }

  @override
  Widget build(BuildContext context) {
    if (!(context.watch<AuthProvider>().currentUser?.isAdmin ?? false))
      return const Scaffold(
          body: Center(child: Text('Administrator access required.')));
    final value = report ?? preview;
    return Scaffold(
        appBar: AppBar(title: const Text('Scrap Items Report')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Text(
              'Paste up to 200 tags. Include attached peripherals when scrapping a workstation.'),
          TextField(
              controller: tags,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Tag numbers'),
              onChanged: (_) => setState(() => preview = null)),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.redAccent)),
          Wrap(spacing: 8, children: [
            FilledButton(
                onPressed: busy
                    ? null
                    : () => run(() async {
                          previewTags = tags.text;
                          preview = jsonDecode((await request('/preview',
                                  body: {'tags': previewTags}))
                              .body);
                          requestId = uuid();
                          report = null;
                        }),
                child: const Text('Retrieve item details')),
            OutlinedButton(
                onPressed: busy || preview == null ? null : () => run(commit),
                child: const Text('Confirm scrap & generate'))
          ]),
          if (value != null) ...[
            Text(report == null
                ? 'Preview - nothing changed yet'
                : 'Report: ${report!['id']}'),
            if (report != null) ...[
              Text('Date: ${report!['date']}'),
              Text(
                  'Operator: ${report!['operator']['name']} - ${report!['operator']['email']}'),
              Wrap(spacing: 8, children: [
                OutlinedButton(
                    onPressed: busy ? null : () => run(pdf),
                    child: const Text('Printable PDF')),
                OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => run(() async {
                              final response = await request(
                                  '/${report!['id']}?format=xlsx');
                              await FilePicker.platform.saveFile(
                                  fileName:
                                      'scrap-report-${report!['id']}.xlsx',
                                  bytes: response.bodyBytes);
                            }),
                    child: const Text('Export Excel'))
              ])
            ],
            for (final row in value['rows'])
              Card(
                  child: ListTile(
                      title: Text('${row['tag']} - ${row['type']}'),
                      subtitle: Text(
                          '${row['description']}\n${row['previousStatus']} → SCRAPPED\n${row['person']} | Quantity: ${row['quantity']}')))
          ],
          const SizedBox(height: 20),
          const Text('Previous scrap reports'),
          for (final item in history)
            ListTile(
                title: Text('${item['date']} - ${item['count']} items'),
                subtitle: Text(item['operator']['name']),
                onTap: busy
                    ? null
                    : () => run(() async {
                          report = jsonDecode(
                              (await request('/${item['id']}')).body);
                          preview = null;
                        }))
        ]));
  }
}
