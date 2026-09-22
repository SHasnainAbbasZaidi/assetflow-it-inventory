import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_manager_flutter/utils/asset_tag_payload.dart';

void main() {
  test('Asset tag QR payload encodes and decodes required fields', () {
    const tagNumber = '2026-LAPTOP-DELL-0001';
    const assetId = 'A1B2C3';
    const deviceType = 'DELL';
    const modelName = 'Latitude 5540';

    final payload = AssetTagPayload.encode(
      tagNumber: tagNumber,
      assetId: assetId,
      deviceType: deviceType,
      modelName: modelName,
    );
    final decoded = AssetTagPayload.decode(payload);

    expect(decoded['tagNumber'], tagNumber);
    expect(decoded['assetId'], assetId);
    expect(decoded['deviceType'], deviceType);
    expect(decoded['modelName'], modelName);
  });
}
