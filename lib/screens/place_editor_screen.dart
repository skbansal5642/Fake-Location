import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../widgets/location_picker.dart';

/// Picks a named place by search or by tapping the map.
class PlaceEditorScreen extends StatefulWidget {
  const PlaceEditorScreen({
    super.key,
    required this.title,
    this.initial,
    required this.fallbackCenter,
    this.radiusMeters,
  });

  final String title;
  final Place? initial;
  final LatLng fallbackCenter;
  final double? radiusMeters;

  @override
  State<PlaceEditorScreen> createState() => _PlaceEditorScreenState();
}

class _PlaceEditorScreenState extends State<PlaceEditorScreen> {
  late LatLng _position = widget.initial?.position ?? widget.fallbackCenter;
  late final _nameController = TextEditingController(text: widget.initial?.name ?? '');
  bool _nameEdited = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    Navigator.pop(context, Place(name: name.isEmpty ? 'Place' : name, position: _position));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (_) => _nameEdited = true,
            ),
          ),
          Expanded(
            child: LocationPicker(
              initial: _position,
              radiusMeters: widget.radiusMeters,
              onChanged: (p, title) {
                setState(() => _position = p);
                // Search results name the place unless the user typed their own name.
                if (title != null && !_nameEdited) _nameController.text = title;
              },
            ),
          ),
        ],
      ),
    );
  }
}
