import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VoiceCredentials {
  VoiceCredentials({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _apiKeyName = 'openai_api_key';
  final FlutterSecureStorage _storage;

  Future<void> save(String apiKey) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Voice credentials are Android-only');
    }
    if (!apiKey.startsWith('sk-') || apiKey.length < 20) {
      throw const FormatException('Invalid OpenAI API key');
    }
    await _storage.write(key: _apiKeyName, value: apiKey);
  }

  Future<String?> read() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    return _storage.read(key: _apiKeyName);
  }

  Future<void> clear() => _storage.delete(key: _apiKeyName);
}
