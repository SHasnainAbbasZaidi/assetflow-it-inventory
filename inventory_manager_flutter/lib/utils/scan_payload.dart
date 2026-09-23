import 'dart:convert';

String parseScanPayload(String value) {
  final clean = value.trim();
  if (clean.isEmpty || clean.length > 4096)
    throw const FormatException(
        'Empty or damaged QR code. Enter the tag manually.');
  String tag = clean;
  if (clean.startsWith('{')) {
    try {
      final decoded = jsonDecode(clean);
      tag =
          (decoded['tagNumber'] ?? decoded['assetId'] ?? '').toString().trim();
    } catch (_) {
      throw const FormatException(
          'Damaged or unsupported QR code. Enter the tag manually.');
    }
  }
  if (tag.isEmpty ||
      tag.length > 200 ||
      tag.contains('://') ||
      RegExp(r'[\x00-\x1f]').hasMatch(tag))
    throw const FormatException(
        'Unsupported QR code. Scan an inventory tag or enter its number.');
  return tag;
}
