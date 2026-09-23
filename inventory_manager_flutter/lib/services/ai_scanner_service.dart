import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'asset_api_service.dart';

class AIScannerService {
  static Future<Map<String, dynamic>> analyzeItemImage(
      Uint8List bytes, String token,
      {String mimeType = 'image/jpeg'}) async {
    final response = await http
        .post(Uri.parse('${AssetApiService.baseUrl}/api/ai/analyze'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({
              'provider': 'gemini',
              'consent': true,
              'mimeType': mimeType,
              'image': base64Encode(bytes),
              'question':
                  'Extract IT asset details from this image. Return ONLY a JSON object with string fields itemCategory, deviceType, modelName, serialNumber, vendorName, notes. Use empty strings for unknown values.'
            }))
        .timeout(const Duration(seconds: 55));
    final body = jsonDecode(response.body);
    if (response.statusCode >= 400)
      throw Exception(body['error']?['message'] ?? 'Image analysis failed.');
    final text = (body['text'] as String)
        .replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$'), '')
        .trim();
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    } catch (_) {
      throw Exception(
          'AI returned an unreadable result. Please enter details manually.');
    }
  }
}
