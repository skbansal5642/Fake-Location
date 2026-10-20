import 'place.dart';

/// Shows [target] while the device is within [radiusMeters] of [anchor] or connected to [ssid].
class Rule {
  const Rule({
    required this.name,
    required this.anchor,
    required this.radiusMeters,
    required this.ssid,
    required this.target,
  });

  static const defaultRadius = 60.0;

  final String name;
  final Place anchor;
  final double radiusMeters;
  final String? ssid;
  final Place target;

  /// Trims [ssid], treating blank as no Wi-Fi condition.
  static String? normalizeSsid(String? ssid) {
    final trimmed = ssid?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'anchor': anchor.toJson(),
        'radius': radiusMeters,
        'ssid': ssid,
        'target': target.toJson(),
      };

  factory Rule.fromJson(Map<String, dynamic> json) => Rule(
        name: json['name'] as String,
        anchor: Place.fromJson(json['anchor'] as Map<String, dynamic>),
        radiusMeters: (json['radius'] as num?)?.toDouble() ?? defaultRadius,
        ssid: normalizeSsid(json['ssid'] as String?),
        target: Place.fromJson(json['target'] as Map<String, dynamic>),
      );
}
