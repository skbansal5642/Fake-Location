import 'place.dart';
import 'rule.dart';
import 'slot.dart';

enum MockMode {
  schedule('schedule', 'Schedule'),
  fixed('fixed', 'Fixed'),
  rules('rules', 'Near place');

  const MockMode(this.id, this.label);

  final String id;
  final String label;

  static MockMode of(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => MockMode.schedule);
}

/// Everything the native service needs to decide what location to report.
class MockConfig {
  const MockConfig({
    this.mode = MockMode.schedule,
    this.slots = const [],
    this.fixed,
    this.rules = const [],
    this.driftMeters = defaultDrift,
  });

  static const defaultDrift = 10.0;

  final MockMode mode;
  final List<Slot> slots;
  final Place? fixed;
  final List<Rule> rules;
  final double driftMeters;

  bool get isRunnable => switch (mode) {
        MockMode.schedule => slots.isNotEmpty,
        MockMode.fixed => fixed != null,
        MockMode.rules => rules.isNotEmpty,
      };

  Map<String, dynamic> toJson() => {
        'mode': mode.id,
        'slots': slots.map((s) => s.toJson()).toList(),
        'fixed': fixed?.toJson(),
        'rules': rules.map((r) => r.toJson()).toList(),
        'drift': driftMeters,
      };

  factory MockConfig.fromJson(Map<String, dynamic> json) => MockConfig(
        mode: MockMode.of(json['mode'] as String?),
        slots: ((json['slots'] as List?) ?? [])
            .map((e) => Slot.fromJson(e as Map<String, dynamic>))
            .toList(),
        fixed: json['fixed'] == null ? null : Place.fromJson(json['fixed'] as Map<String, dynamic>),
        rules: ((json['rules'] as List?) ?? [])
            .map((e) => Rule.fromJson(e as Map<String, dynamic>))
            .toList(),
        driftMeters: (json['drift'] as num?)?.toDouble() ?? defaultDrift,
      );

  MockConfig copyWith({
    MockMode? mode,
    List<Slot>? slots,
    Place? fixed,
    List<Rule>? rules,
    double? driftMeters,
  }) =>
      MockConfig(
        mode: mode ?? this.mode,
        slots: slots ?? this.slots,
        fixed: fixed ?? this.fixed,
        rules: rules ?? this.rules,
        driftMeters: driftMeters ?? this.driftMeters,
      );
}
