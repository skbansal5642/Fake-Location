import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/rule.dart';
import '../services/mock_location_channel.dart';
import 'place_editor_screen.dart';

/// Edits a "when near A (or on Wi-Fi X), show B" rule.
class RuleEditorScreen extends StatefulWidget {
  const RuleEditorScreen({super.key, this.initial, required this.fallbackCenter});

  final Rule? initial;
  final LatLng fallbackCenter;

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  final _channel = MockLocationChannel();
  late final _nameController = TextEditingController(text: widget.initial?.name ?? '');
  late final _ssidController = TextEditingController(text: widget.initial?.ssid ?? '');
  late Place? _anchor = widget.initial?.anchor;
  late Place? _target = widget.initial?.target;
  late double _radius = widget.initial?.radiusMeters ?? Rule.defaultRadius;

  @override
  void dispose() {
    _nameController.dispose();
    _ssidController.dispose();
    super.dispose();
  }

  Future<void> _pickAnchor() async {
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditorScreen(
          title: 'When I am near',
          initial: _anchor,
          fallbackCenter: _target?.position ?? widget.fallbackCenter,
          radiusMeters: _radius,
        ),
      ),
    );
    if (place != null) setState(() => _anchor = place);
  }

  Future<void> _pickTarget() async {
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditorScreen(
          title: 'Show my location as',
          initial: _target,
          fallbackCenter: _anchor?.position ?? widget.fallbackCenter,
        ),
      ),
    );
    if (place != null) setState(() => _target = place);
  }

  Future<void> _useCurrentWifi() async {
    final ssid = await _channel.currentSsid();
    if (!mounted) return;
    if (ssid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Not connected to Wi-Fi, or location permission is missing'),
      ));
      return;
    }
    setState(() => _ssidController.text = ssid);
  }

  void _save() {
    final anchor = _anchor;
    final target = _target;
    if (anchor == null || target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose both places first')),
      );
      return;
    }
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      Rule(
        name: name.isEmpty ? '${anchor.name} → ${target.name}' : name,
        anchor: anchor,
        radiusMeters: _radius,
        ssid: Rule.normalizeSsid(_ssidController.text),
        target: target,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Near-place rule'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Rule name (optional)'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('When I am', style: textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: Text(_anchor == null ? 'Choose place A' : 'Within ${_radius.round()} m of ${_anchor!.name}'),
            subtitle: Text(_anchor?.coordinates ?? 'Search or tap the map'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickAnchor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Radius'),
                Expanded(
                  child: Slider(
                    value: _radius,
                    min: 30,
                    max: 300,
                    divisions: 27,
                    label: '${_radius.round()} m',
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                ),
                SizedBox(width: 56, child: Text('${_radius.round()} m', textAlign: TextAlign.end)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('or connected to Wi-Fi', style: textTheme.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ssidController,
                    decoration: const InputDecoration(
                      labelText: 'Wi-Fi name (optional)',
                      hintText: 'e.g. Office_5G',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _useCurrentWifi,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Current'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Show my location as', style: textTheme.titleSmall),
          ),
          ListTile(
            leading: const Icon(Icons.place),
            title: Text(_target?.name ?? 'Choose place B'),
            subtitle: Text(_target?.coordinates ?? 'Search or tap the map'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickTarget,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Away from A (and off that Wi-Fi), your real location is shown. '
              'While B is shown, leaving A is detected from Wi-Fi and cell changes, '
              'which can take a minute or two.',
              style: textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
