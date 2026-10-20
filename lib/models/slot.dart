import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'place.dart';

/// A location reported during a daily time window.
class Slot {
  const Slot({
    required this.name,
    required this.position,
    required this.start,
    required this.end,
  });

  final String name;
  final LatLng position;
  final TimeOfDay start;
  final TimeOfDay end;

  Place get place => Place(name: name, position: position);

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _time(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': position.latitude,
        'lng': position.longitude,
        'start': _minutes(start),
        'end': _minutes(end),
      };

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        name: json['name'] as String,
        position: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lng'] as num).toDouble(),
        ),
        start: _time(json['start'] as int),
        end: _time(json['end'] as int),
      );

  Slot copyWith({String? name, LatLng? position, TimeOfDay? start, TimeOfDay? end}) => Slot(
        name: name ?? this.name,
        position: position ?? this.position,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}
