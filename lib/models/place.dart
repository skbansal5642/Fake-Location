import 'package:latlong2/latlong.dart';

/// A named point on the map.
class Place {
  const Place({required this.name, required this.position});

  final String name;
  final LatLng position;

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': position.latitude,
        'lng': position.longitude,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        name: json['name'] as String,
        position: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      );

  String get coordinates =>
      '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
}
