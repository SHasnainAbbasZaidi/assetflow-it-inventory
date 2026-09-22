import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/asset_api_service.dart';
import 'package:inventory_manager_flutter/providers/auth_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final TextEditingController _manualInputController = TextEditingController();
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _manualInputController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _processScannedCode(String code) async {
    if (_isProcessing || code.trim().isEmpty) return;
    setState(() => _isProcessing = true);
    try {
      final token = context.read<AuthProvider>().apiToken;
      if (token == null || token.isEmpty) throw const AssetApiException('Sign in to the Node API before scanning.');
      // This is deliberately the only lookup: the server checks Workstations first, then Peripherals.
      final result = await AssetApiService(token: token).lookup(code.trim());
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AssetLookupDialog(result: result));
    } on AssetNotFoundException {
      if (mounted) _handleSearchError(code);
    } on AssetApiException catch (error) {
      if (mounted) _showError('Lookup Failed', error.message);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handleSearchError(String text) {
    setState(() => _isProcessing = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Asset Not Found'),
        content: Text('Could not find any asset with Tag ID or Serial: "$text"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String title, String message) => showDialog<void>(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));

  void _processManualCode() {
    final text = _manualInputController.text.trim().toUpperCase();
    if (text.isEmpty) return;
    _processScannedCode(text);
    _manualInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'QR Tag Scanner',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                'Scan an asset tag to quickly view, edit, or check it out.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Permission failures stay visible and manual lookup remains available.
              Container(
                width: 320,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null) _processScannedCode(code);
                    },
                    errorBuilder: (_, error, __) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          error.errorCode == MobileScannerErrorCode.permissionDenied
                              ? 'Camera permission denied. Enable it in system settings or use manual entry below.'
                              : 'Camera unavailable. Use manual entry below.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              const Text(
                'Enter Asset ID or Serial Number:',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              ),
              const SizedBox(height: 12),

              // Manual input field
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _manualInputController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'e.g. A1B2C3',
                    prefixIcon: const Icon(Icons.keyboard_rounded),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6366F1)),
                      onPressed: _processManualCode,
                    ),
                  ),
                  onSubmitted: (_) => _processManualCode(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssetLookupDialog extends StatelessWidget {
  const AssetLookupDialog({super.key, required this.result});
  final AssetLookup result;

  @override
  Widget build(BuildContext context) {
    final title = result.type == 'workstation' ? 'Workstation Details' : 'Peripheral Details';
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: result.data.entries.where((entry) => entry.value != null).map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('${entry.key}: ${entry.value}'),
            )).toList(),
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}
