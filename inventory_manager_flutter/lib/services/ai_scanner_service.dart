import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIScannerService {
  static Future<Map<String, dynamic>> analyzeItemImage(Uint8List imageBytes, String apiKey) async {
    if (apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please add it in Settings.');
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final prompt = TextPart('''
Analyze this image of an IT asset/item. 
Extract the following information and return ONLY a valid JSON object without markdown wrappers or formatting.
Keys required (if found, otherwise leave empty string):
- "itemCategory" (e.g., PC/Laptop, Display, Mobile, Keyboard, Mouse, Headphones, etc.)
- "deviceType" (Manufacturer/Brand e.g., Dell, Apple, Logitech)
- "modelName" (e.g., XPS 15, MacBook Pro, MX Master 3)
- "serialNumber" (e.g., alphanumeric string usually labeled SN, S/N, Serial)
- "vendorName"
- "notes" (Any other prominent text or labels)

Example JSON:
{
  "itemCategory": "Keyboard",
  "deviceType": "Logitech",
  "modelName": "MX Keys Mini",
  "serialNumber": "LZ12345",
  "vendorName": "",
  "notes": "Color: Graphite"
}
''');

    final imageParts = [
      DataPart('image/jpeg', imageBytes),
    ];

    try {
      final response = await model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);

      final text = response.text ?? '{}';
      
      // Clean markdown if present
      String cleanedText = text.trim();
      if (cleanedText.startsWith('```json')) {
        cleanedText = cleanedText.substring(7);
      } else if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.substring(3);
      }
      if (cleanedText.endsWith('```')) {
        cleanedText = cleanedText.substring(0, cleanedText.length - 3);
      }
      
      return jsonDecode(cleanedText.trim());
    } catch (e) {
      debugPrint('Error analyzing image: $e');
      throw Exception('Failed to analyze image: $e');
    }
  }
}
