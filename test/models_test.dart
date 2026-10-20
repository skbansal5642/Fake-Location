import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_location/models/mock_config.dart';
import 'package:fake_location/models/place.dart';
import 'package:fake_location/models/rule.dart';
import 'package:fake_location/models/slot.dart';
import 'package:fake_location/services/geocoding_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('MockConfig', () {
    test('round-trips through JSON', () {
      final config = MockConfig(
        mode: MockMode.rules,
        slots: const [
          Slot(name: 'A', position: LatLng(1, 2), start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 20, minute: 30)),
        ],
        fixed: const Place(name: 'F', position: LatLng(3, 4)),
        rules: const [
          Rule(
            name: 'R',
            anchor: Place(name: 'X', position: LatLng(5, 6)),
            radiusMeters: 60,
            ssid: 'Home',
            target: Place(name: 'Y', position: LatLng(7, 8)),
          ),
        ],
        driftMeters: 15,
      );
      final decoded = MockConfig.fromJson(jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>);
      expect(jsonEncode(decoded.toJson()), jsonEncode(config.toJson()));
      expect(decoded.slots.single.end, const TimeOfDay(hour: 20, minute: 30));
      expect(decoded.rules.single.ssid, 'Home');
    });

    test('reads legacy and partial JSON with defaults', () {
      final config = MockConfig.fromJson({});
      expect(config.mode, MockMode.schedule);
      expect(config.driftMeters, MockConfig.defaultDrift);
      expect(config.isRunnable, isFalse);
    });

    test('blank Wi-Fi name means no Wi-Fi condition', () {
      expect(Rule.normalizeSsid('  '), isNull);
      expect(Rule.normalizeSsid(' Office '), 'Office');
    });
  });

  group('parseCoordinates', () {
    test('accepts comma or space separated pairs', () {
      expect(GeocodingService.parseCoordinates('28.6139, 77.2090'), const LatLng(28.6139, 77.2090));
      expect(GeocodingService.parseCoordinates('-33.86 151.21'), const LatLng(-33.86, 151.21));
    });

    test('rejects text and out-of-range values', () {
      expect(GeocodingService.parseCoordinates('India Gate'), isNull);
      expect(GeocodingService.parseCoordinates('95, 10'), isNull);
    });
  });
}
