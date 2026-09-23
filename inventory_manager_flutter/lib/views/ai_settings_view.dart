// Mahzaidex Tech — developed by Hasnain Zaidi.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/asset_api_service.dart';

class AISettingsView extends StatefulWidget {
  const AISettingsView({super.key});
  @override
  State<AISettingsView> createState() => _AISettingsViewState();
}

class _AISettingsViewState extends State<AISettingsView> {
  final keyInput = TextEditingController(),
      model = TextEditingController(text: 'gemini-2.5-flash'),
      question = TextEditingController();
  String provider = 'gemini', answer = '';
  bool busy = false, consent = false;
  List<dynamic> keys = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => run(load));
  }

  @override
  void dispose() {
    keyInput.dispose();
    model.dispose();
    question.dispose();
    super.dispose();
  }

  Future<dynamic> request(String route,
      {String method = 'GET', Map<String, dynamic>? body}) async {
    final token = context.read<AuthProvider>().apiToken;
    final req = http.Request(
        method, Uri.parse('${AssetApiService.baseUrl}/api/ai$route'));
    req.headers.addAll(
        {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    if (body != null) req.body = jsonEncode(body);
    final response = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: 55)));
    final value = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400)
      throw Exception(value?['error']?['message'] ?? 'Request failed.');
    return value;
  }

  Future<void> load() async {
    keys = await request('/keys') as List<dynamic>;
  }

  Future<void> run(Future<void> Function() fn) async {
    if (busy || !mounted) return;
    setState(() => busy = true);
    try {
      await fn();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured =
        keys.any((k) => k['provider'] == provider && k['configured'] == true);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('AI API Keys',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const Text(
          'Personal keys are encrypted on the server. Previously saved local keys must be entered here again.'),
      if (busy) const LinearProgressIndicator(),
      DropdownButtonFormField<String>(
          initialValue: provider,
          items: const [
            DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
            DropdownMenuItem(value: 'openai', child: Text('OpenAI'))
          ],
          onChanged: busy
              ? null
              : (v) => setState(() {
                    provider = v!;
                    model.text =
                        v == 'gemini' ? 'gemini-2.5-flash' : 'gpt-4.1-mini';
                    keyInput.clear();
                  })),
      Text(configured ? 'Saved key: ••••••••' : 'No key saved'),
      TextField(
          controller: keyInput,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration:
              const InputDecoration(labelText: 'New or replacement API key')),
      TextField(
          controller: model,
          decoration: const InputDecoration(labelText: 'Model')),
      Wrap(spacing: 8, children: [
        FilledButton(
            onPressed: busy
                ? null
                : () => run(() async {
                      final value = keyInput.text;
                      keyInput.clear();
                      await request('/keys/$provider',
                          method: 'PUT',
                          body: {'apiKey': value, 'model': model.text});
                      await load();
                    }),
            child: const Text('Save key')),
        OutlinedButton(
            onPressed: busy || !configured
                ? null
                : () => run(() async {
                      await request('/keys/$provider', method: 'DELETE');
                      await load();
                    }),
            child: const Text('Remove key'))
      ]),
      const Divider(),
      const Text('AI inventory analysis', style: TextStyle(fontSize: 20)),
      TextField(
          controller: question,
          maxLines: 3,
          maxLength: 2000,
          decoration:
              const InputDecoration(labelText: 'Question about inventory')),
      CheckboxListTile(
          value: consent,
          onChanged: (v) => setState(() => consent = v ?? false),
          title: const Text(
              'Send this question and inventory counts by status/category to my selected provider. No records will be changed.')),
      FilledButton(
          onPressed: busy || !consent
              ? null
              : () => run(() async {
                    final result = await request('/analyze',
                        method: 'POST',
                        body: {
                          'provider': provider,
                          'question': question.text,
                          'consent': consent
                        });
                    answer = result['text'];
                  }),
          child: const Text('Analyze inventory')),
      SelectableText(answer)
    ]);
  }
}
