import 'package:json_annotation/json_annotation.dart';

part 'workout_set.g.dart';

/// One set within an exercise entry. Fields populated depend on ExerciseType.
@JsonSerializable()
class WorkoutSet {
  final int setNumber;

  /// Weighted exercises
  final double? weightLbs;

  /// Bodyweight-plus exercises (0 = no added weight)
  final double? addedWeightLbs;

  /// Weighted / bodyweight exercises
  final int? reps;

  /// Cardio exercises
  final int? durationSeconds;
  final double? distanceMeters;

  /// Actual rest taken after this set, in seconds
  final int? restAfterSeconds;

  final String? notes;

  const WorkoutSet({
    required this.setNumber,
    this.weightLbs,
    this.addedWeightLbs,
    this.reps,
    this.durationSeconds,
    this.distanceMeters,
    this.restAfterSeconds,
    this.notes,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSetFromJson(json);

  Map<String, dynamic> toJson() => _$WorkoutSetToJson(this);

  WorkoutSet copyWith({
    int? setNumber,
    double? weightLbs,
    double? addedWeightLbs,
    int? reps,
    int? durationSeconds,
    double? distanceMeters,
    int? restAfterSeconds,
    String? notes,
    bool clearNotes = false,
    bool clearWeightLbs = false,
    bool clearAddedWeightLbs = false,
    bool clearDistanceMeters = false,
  }) {
    return WorkoutSet(
      setNumber: setNumber ?? this.setNumber,
      weightLbs: clearWeightLbs ? null : (weightLbs ?? this.weightLbs),
      addedWeightLbs: clearAddedWeightLbs
          ? null
          : (addedWeightLbs ?? this.addedWeightLbs),
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters:
          clearDistanceMeters ? null : (distanceMeters ?? this.distanceMeters),
      restAfterSeconds: restAfterSeconds ?? this.restAfterSeconds,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  /// Returns a human-readable summary of this set.
  String get summary {
    final parts = <String>[];
    if (weightLbs != null && reps != null) {
      final w = weightLbs! % 1 == 0
          ? weightLbs!.toInt().toString()
          : weightLbs!.toStringAsFixed(1);
      parts.add('${w}lbs × $reps');
    } else if (addedWeightLbs != null && reps != null) {
      if (addedWeightLbs! > 0) {
        final w = addedWeightLbs! % 1 == 0
            ? addedWeightLbs!.toInt().toString()
            : addedWeightLbs!.toStringAsFixed(1);
        parts.add('+${w}lbs × $reps');
      } else {
        parts.add('BW × $reps');
      }
    } else if (reps != null) {
      parts.add('$reps reps');
    }
    if (durationSeconds != null) {
      final m = durationSeconds! ~/ 60;
      final s = durationSeconds! % 60;
      parts.add(m > 0 ? '${m}m ${s}s' : '${s}s');
    }
    if (distanceMeters != null) {
      final km = distanceMeters! / 1000;
      parts.add('${km.toStringAsFixed(2)} km');
    }
    return parts.join(' · ');
  }
}
