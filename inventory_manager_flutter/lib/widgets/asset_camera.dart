import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Let MobileScanner own its controller and app lifecycle. Supplying a controller
/// disables its automatic resume handling (including Android permission dialogs).
class AssetCamera extends StatefulWidget {
  const AssetCamera({super.key, required this.onCode, this.active = true});
  final ValueChanged<String> onCode;
  final bool active;
  @override
  State<AssetCamera> createState() => _AssetCameraState();
}

class _AssetCameraState extends State<AssetCamera> {
  int _attempt = 0;
  @override
  Widget build(BuildContext context) {
    if (!widget.active) return const Center(child: Text('Camera paused'));
    return Column(children: [
      Expanded(
          child: MobileScanner(
        key: ValueKey(_attempt),
        onDetect: (capture) {
          final code = capture.barcodes.firstOrNull?.rawValue;
          if (code != null) widget.onCode(code);
        },
        errorBuilder: (_, error) => Center(
            child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
              error.errorCode == MobileScannerErrorCode.permissionDenied
                  ? 'Allow camera access in Android Settings → Apps → AssetFlow → Permissions, then return and tap Retry camera.'
                  : 'Camera could not start (${error.errorCode.name}). Close other camera apps and tap Retry camera. Manual tag entry is available below.',
              textAlign: TextAlign.center),
        )),
      )),
      TextButton.icon(
          onPressed: () => setState(() => _attempt++),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry camera')),
    ]);
  }
}
