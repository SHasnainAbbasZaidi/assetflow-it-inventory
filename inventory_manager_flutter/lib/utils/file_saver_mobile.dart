import 'dart:io';

Future<void> saveAndLaunchFile(List<int> bytes, String fileName, {String mimeType = 'application/pdf'}) async {
  try {
    final file = File(fileName);
    await file.writeAsBytes(bytes);
    print('File saved to: ${file.absolute.path}');
  } catch (e) {
    print('Error saving file on mobile: $e');
  }
}
