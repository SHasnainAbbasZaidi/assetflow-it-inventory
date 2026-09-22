import 'dart:convert';

class AssetTagPayload {
  static const String tagNumberKey = 'tagNumber';
  static const String assetIdKey = 'assetId';
  static const String deviceTypeKey = 'deviceType';
  static const String modelNameKey = 'modelName';

  static String encode({
    required String tagNumber,
    required String assetId,
    required String deviceType,
    required String modelName,
  }) {
    return jsonEncode({
      tagNumberKey: tagNumber,
      assetIdKey: assetId,
      deviceTypeKey: deviceType,
      modelNameKey: modelName,
    });
  }

  static Map<String, String> decode(String code) {
    final decoded = jsonDecode(code);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    return {
      tagNumberKey: decoded[tagNumberKey]?.toString() ?? '',
      assetIdKey: decoded[assetIdKey]?.toString() ?? '',
      deviceTypeKey: decoded[deviceTypeKey]?.toString() ?? '',
      modelNameKey: decoded[modelNameKey]?.toString() ?? '',
    };
  }

  static bool isAssetTagPayload(String code) {
    try {
      return decode(code).isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
