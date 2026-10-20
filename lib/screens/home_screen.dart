import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/mock_config.dart';
import '../models/place.dart';
import '../models/rule.dart';
import '../models/slot.dart';
import '../services/mock_location_channel.dart';
import 'place_editor_screen.dart';
import 'rule_editor_screen.dart';
import 'slot_editor_screen.dart';

/// Shows setup status, the mode and its locations, and the start/stop control.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _defaultCenter = LatLng(28.6139, 77.2090);

  final _channel = MockLocationChannel();
  MockConfig _config = const MockConfig();
  bool _loaded = false;
  bool _running = false;
  String? _status;
  bool _mockSelected = false;
  bool _locationGranted = false;
  bool _backgroundLocationGranted = false;
  bool _batteryExempt = false;
  Timer? _statusTimer;

  /// Set when the service was paused because the current mode has no location yet.
  bool _resumeWhenReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refreshRunning());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  LatLng get _anyKnownPosition =>
      _config.fixed?.position ??
      (_config.slots.isNotEmpty ? _config.slots.first.position : null) ??
      (_config.rules.isNotEmpty ? _config.rules.first.anchor.position : null) ??
      _defaultCenter;

  Future<void> _load() async {
    final config = await _channel.loadConfig();
    setState(() {
      _config = config;
      _loaded = true;
    });
    await _refreshStatus();
  }

  Future<void> _refreshRunning() async {
    final running = await _channel.isRunning();
    final status = running ? await _channel.status() : null;
    if (!mounted) return;
    if (running != _running || status != _status) {
      setState(() {
        _running = running;
        _status = status;
      });
    }
  }

  Future<void> _refreshStatus() async {
    final mock = await _channel.isMockAppSelected();
    final location = await Permission.locationWhenInUse.isGranted;
    final background = await Permission.locationAlways.isGranted;
    final battery = await _channel.isIgnoringBatteryOptimizations();
    await _refreshRunning();
    if (!mounted) return;
    setState(() {
      _mockSelected = mock;
      _locationGranted = location;
      _backgroundLocationGranted = background;
      _batteryExempt = battery;
    });
  }

  Future<void> _update(MockConfig config) async {
    setState(() => _config = config);
    await _channel.saveConfig(config);
    if (!_running && !_resumeWhenReady) return;
    // Restart so the service picks up the change; pause while the mode has nothing to report.
    if (config.isRunnable) {
      _resumeWhenReady = false;
      await _channel.start();
    } else {
      _resumeWhenReady = true;
      await _channel.stop();
      _showSnack('Paused until this mode has a location');
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await _refreshRunning();
  }

  // Schedule mode

  Future<void> _editSlot(int? index) async {
    final slots = _config.slots;
    final initial = index == null
        ? Slot(
            name: 'Location ${String.fromCharCode(65 + slots.length)}',
            position: _anyKnownPosition,
            start: const TimeOfDay(hour: 8, minute: 0),
            end: const TimeOfDay(hour: 20, minute: 0),
          )
        : slots[index];
    final result = await Navigator.push<Slot>(
      context,
      MaterialPageRoute(builder: (_) => SlotEditorScreen(initial: initial)),
    );
    if (result == null) return;
    final updated = index == null ? [...slots, result] : ([...slots]..[index] = result);
    await _update(_config.copyWith(slots: updated));
  }

  // Fixed mode

  Future<void> _editFixed() async {
    final place = await Navigator.push<Place>(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditorScreen(
          title: 'Fixed location',
          initial: _config.fixed,
          fallbackCenter: _anyKnownPosition,
        ),
      ),
    );
    if (place != null) await _update(_config.copyWith(fixed: place));
  }

  // Rules mode

  Future<void> _editRule(int? index) async {
    final rules = _config.rules;
    final result = await Navigator.push<Rule>(
      context,
      MaterialPageRoute(
        builder: (_) => RuleEditorScreen(
          initial: index == null ? null : rules[index],
          fallbackCenter: _anyKnownPosition,
        ),
      ),
    );
    if (result == null) return;
    final updated = index == null ? [...rules, result] : ([...rules]..[index] = result);
    await _update(_config.copyWith(rules: updated));
  }

  Future<void> _toggle() async {
    final starting = !_running;
    _resumeWhenReady = false;
    if (!starting) {
      await _channel.stop();
    } else {
      await [Permission.locationWhenInUse, Permission.notification].request();
      await _refreshStatus();
      if (!_locationGranted || !_mockSelected) {
        _showSnack('Finish the setup steps first');
        return;
      }
      if (_config.mode == MockMode.rules && !_backgroundLocationGranted) {
        _showSnack('Near-place rules need location access "Allow all the time"');
        return;
      }
      if (!_config.isRunnable) {
        _showSnack(switch (_config.mode) {
          MockMode.schedule => 'Add at least one time slot',
          MockMode.fixed => 'Choose the fixed location',
          MockMode.rules => 'Add at least one rule',
        });
        return;
      }
      await _channel.start();
    }
    await Future.delayed(const Duration(milliseconds: 500));
    await _refreshRunning();
    if (starting && !_running && mounted) {
      // Service stops itself when mock location access is refused.
      _showSnack('Could not start. Check the mock location app setting.');
    }
  }

  Future<void> _requestBackgroundLocation() async {
    if (!await Permission.locationWhenInUse.request().isGranted) return;
    await Permission.locationAlways.request();
    await _refreshStatus();
  }

  void _showSnack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _window(Slot s) => '${s.start.format(context)} – ${s.end.format(context)}';

  @override
  Widget build(BuildContext context) {
    final needsBackground = _config.mode == MockMode.rules;
    final setupDone = _locationGranted && _mockSelected && _batteryExempt &&
        (!needsBackground || _backgroundLocationGranted);
    return Scaffold(
      appBar: AppBar(title: const Text('Fake Location')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loaded ? _toggle : null,
        backgroundColor: _running ? Colors.red.shade400 : null,
        icon: Icon(_running ? Icons.stop : Icons.play_arrow),
        label: Text(_running ? 'Stop' : 'Start'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStatus,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  if (_running && _status != null) _StatusCard(text: _status!),
                  if (!setupDone) ...[
                    const _SectionHeader('Setup'),
                    _SetupTile(
                      done: _locationGranted,
                      title: 'Location permission',
                      onTap: () async {
                        await Permission.locationWhenInUse.request();
                        _refreshStatus();
                      },
                    ),
                    _SetupTile(
                      done: _mockSelected,
                      title: 'Select as mock location app',
                      subtitle: 'Developer options → Select mock location app → Fake Location',
                      onTap: _channel.openDeveloperSettings,
                    ),
                    if (needsBackground)
                      _SetupTile(
                        done: _backgroundLocationGranted,
                        title: 'Location: Allow all the time',
                        subtitle: 'Needed to notice when you reach a place and to read Wi-Fi in the background',
                        onTap: _requestBackgroundLocation,
                      ),
                    _SetupTile(
                      done: _batteryExempt,
                      title: 'Allow running in background',
                      subtitle: 'Recommended so the system does not stop the service',
                      onTap: _channel.requestIgnoreBatteryOptimizations,
                    ),
                  ],
                  const _SectionHeader('Mode'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SegmentedButton<MockMode>(
                      segments: [
                        for (final m in MockMode.values) ButtonSegment(value: m, label: Text(m.label)),
                      ],
                      selected: {_config.mode},
                      onSelectionChanged: (s) => _update(_config.copyWith(mode: s.first)),
                    ),
                  ),
                  ...switch (_config.mode) {
                    MockMode.schedule => _scheduleSection(),
                    MockMode.fixed => _fixedSection(),
                    MockMode.rules => _rulesSection(),
                  },
                  const _SectionHeader('Natural drift'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _config.driftMeters.clamp(0, 30),
                            min: 0,
                            max: 30,
                            divisions: 30,
                            label: '${_config.driftMeters.round()} m',
                            onChanged: (v) => setState(() => _config = _config.copyWith(driftMeters: v)),
                            onChangeEnd: (v) => _update(_config.copyWith(driftMeters: v)),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            _config.driftMeters.round() == 0 ? 'Off' : '${_config.driftMeters.round()} m',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _Hint('The shown location wanders slowly within this radius, like a real phone lying still.'),
                ],
              ),
            ),
    );
  }

  List<Widget> _scheduleSection() => [
        _SectionHeader(_running ? 'Time slots (active)' : 'Time slots'),
        if (_config.slots.isEmpty) const _Hint('No time slots yet.'),
        for (var i = 0; i < _config.slots.length; i++)
          ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text(_config.slots[i].name),
            subtitle: Text('${_window(_config.slots[i])}\n${_config.slots[i].place.coordinates}'),
            isThreeLine: true,
            onTap: () => _editSlot(i),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _update(_config.copyWith(slots: [..._config.slots]..removeAt(i))),
            ),
          ),
        _AddButton(label: 'Add time slot', onPressed: () => _editSlot(null)),
        const _Hint('If windows overlap, the first matching slot wins. Outside every window, the first slot is used.'),
      ];

  List<Widget> _fixedSection() => [
        const _SectionHeader('Fixed location'),
        ListTile(
          leading: const Icon(Icons.push_pin_outlined),
          title: Text(_config.fixed?.name ?? 'Choose location'),
          subtitle: Text(_config.fixed?.coordinates ?? 'Search for a place or tap the map'),
          trailing: const Icon(Icons.chevron_right),
          onTap: _editFixed,
        ),
        const _Hint('This location is shown all the time while running.'),
      ];

  List<Widget> _rulesSection() => [
        _SectionHeader(_running ? 'Rules (active)' : 'Rules'),
        if (_config.rules.isEmpty) const _Hint('No rules yet.'),
        for (var i = 0; i < _config.rules.length; i++)
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(_config.rules[i].name),
            subtitle: Text(_ruleSummary(_config.rules[i])),
            isThreeLine: true,
            onTap: () => _editRule(i),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _update(_config.copyWith(rules: [..._config.rules]..removeAt(i))),
            ),
          ),
        _AddButton(label: 'Add rule', onPressed: () => _editRule(null)),
        const _Hint('Away from every rule\'s place, your real location is shown. '
            'If rules overlap, Wi-Fi matches win, then the first rule in the list.'),
      ];

  String _ruleSummary(Rule r) {
    final when = 'Within ${r.radiusMeters.round()} m of ${r.anchor.name}'
        '${r.ssid == null ? '' : ' or on Wi-Fi "${r.ssid}"'}';
    return '$when\n→ show ${r.target.name}';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.location_on, color: scheme.onPrimaryContainer),
        title: Text(text, style: TextStyle(color: scheme.onPrimaryContainer)),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(text, style: const TextStyle(color: Colors.grey)),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(label),
        ),
      );
}

class _SetupTile extends StatelessWidget {
  const _SetupTile({required this.done, required this.title, this.subtitle, required this.onTap});

  final bool done;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.green : null,
        ),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: done ? null : const Icon(Icons.chevron_right),
        onTap: done ? null : onTap,
      );
}
