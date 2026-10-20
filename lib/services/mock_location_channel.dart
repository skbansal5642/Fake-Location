import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/mock_config.dart';

/// Bridge to the native mock location service.
class MockLocationChannel {
  static const _channel = MethodChannel('fake_location/mock');

  Future<MockConfig> loadConfig() async {
    final json = await _channel.invokeMethod<String>('loadConfig') ?? '{}';
    return MockConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> saveConfig(MockConfig config) =>
      _channel.invokeMethod('saveConfig', {'json': jsonEncode(config.toJson())});

  Future<void> start() => _channel.invokeMethod('start');
  Future<void> stop() => _channel.invokeMethod('stop');

  Future<bool> isRunning() async => await _channel.invokeMethod<bool>('isRunning') ?? false;

  /// A short description of what the service is reporting right now.
  Future<String?> status() => _channel.invokeMethod<String>('status');

  /// The connected Wi-Fi network's name, or null if unavailable.
  Future<String?> currentSsid() => _channel.invokeMethod<String>('currentSsid');

  Future<bool> isMockAppSelected() async =>
      await _channel.invokeMethod<bool>('isMockAppSelected') ?? false;

  Future<void> openDeveloperSettings() => _channel.invokeMethod('openDeveloperSettings');

  Future<bool> isIgnoringBatteryOptimizations() async =>
      await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;

  Future<void> requestIgnoreBatteryOptimizations() =>
      _channel.invokeMethod('requestIgnoreBatteryOptimizations');
}
