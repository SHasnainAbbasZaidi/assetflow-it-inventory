import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:inventory_manager_flutter/utils/common_asset_models.dart';

class ModelSuggestionService {
  static const Map<String, String> _searchTerms = {
    'PC/Laptop': 'laptop notebook model',
    'Desktop': 'desktop workstation model',
    'Monitor': 'monitor display model',
    'Display': 'monitor display model',
    'Printer': 'printer model',
    'Scanner': 'scanner model',
    'Projector': 'projector model',
    'Server': 'server model',
    'Network Device': 'network switch router access point model',
    'Mobile': 'smartphone mobile model',
    'Tablet': 'tablet model',
    'Keyboard': 'keyboard model',
    'Mouse': 'computer mouse model',
    'Headphones': 'headphones headset model',
    'Software': 'software product edition',
    'Peripheral': 'peripheral accessory model',
  };

  static final Map<String, List<String>> _internetCache = {};

  static List<String> offlineModelsFor({
    required String itemCategory,
    required String deviceType,
  }) {
    return CommonAssetModels.modelsFor(itemCategory, deviceType);
  }

  static Future<List<String>> suggestionsFor({
    required String itemCategory,
    required String deviceType,
    String query = '',
    bool fetchFromInternet = true,
  }) async {
    final fallback = offlineModelsFor(
      itemCategory: itemCategory,
      deviceType: deviceType,
    );
    final merged = <String>{...fallback};

    if (fetchFromInternet) {
      try {
        final fetched = await _fetchInternetModels(
          itemCategory: itemCategory,
          deviceType: deviceType,
        );
        merged.addAll(fetched);
      } catch (_) {
        // Fallback models are always returned when internet fetch fails.
      }
    }

    final normalizedQuery = query.trim().toLowerCase();
    final suggestions = merged
        .where((model) => model.toLowerCase().contains(normalizedQuery))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return suggestions.isEmpty && normalizedQuery.isNotEmpty ? merged.toList() : suggestions;
  }

  static Future<List<String>> _fetchInternetModels({
    required String itemCategory,
    required String deviceType,
  }) async {
    final cacheKey = '$itemCategory|$deviceType';
    if (_internetCache.containsKey(cacheKey)) {
      return _internetCache[cacheKey] ?? const [];
    }

    final cleanDevice = deviceType.trim();
    if (cleanDevice.isEmpty || cleanDevice.toLowerCase() == 'other') {
      return const [];
    }

    final productType = _searchTerms[itemCategory] ?? 'IT asset model';
    final searchQuery = '$cleanDevice $productType';
    final uri = Uri.https(
      'en.wikipedia.org',
      '/w/api.php',
      {
        'action': 'query',
        'list': 'search',
        'srsearch': searchQuery,
        'format': 'json',
        'srlimit': '12',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      return const [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['query'] is! Map || decoded['query']['search'] is! List) {
      return const [];
    }

    final titles = (decoded['query']['search'] as List)
        .whereType<Map>()
        .map((item) => item['title']?.toString() ?? '')
        .map(_cleanModelTitle)
        .where((title) => title.isNotEmpty)
        .take(12)
        .toList();

    _internetCache[cacheKey] = titles;
    return titles;
  }

  static String _cleanModelTitle(String title) {
    var cleaned = title
        .replaceAll(RegExp(r'\s+\(.*?\)'), '')
        .replaceAll(RegExp(r'List of', caseSensitive: false), '')
        .replaceAll(RegExp(r'Inc\.', caseSensitive: false), '')
        .replaceAll(RegExp(r'Company', caseSensitive: false), '')
        .trim();

    final parts = cleaned.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length > 6) {
      cleaned = parts.take(6).join(' ');
    }

    return cleaned;
  }
}
