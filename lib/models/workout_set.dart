import 'package:json_annotation/json_annotation.dart';
import 'exercise.dart';

part 'workout_set.g.dart';

/// One set within an exercise entry. Fields populated depend on ExerciseType.
@JsonSerializable()
class WorkoutSet {
  final int setNumber;

  /// Weighted exercises
  final double? weightLbs;

  /// Barbell exercises: weight added per side (supplementary to weightLbs).
  /// Total = barWeight + 2 × addedPerSideLbs. weightLbs remains canonical
  /// for all PR/volume math; this field is display/input context only.
  final double? addedPerSideLbs;

  /// Bodyweight-plus exercises (0 = no added weight, negative = assisted)
  final double? addedWeightLbs;

  /// Weighted / bodyweight exercises (or seconds when WeightMode.timedReps)
  final int? reps;

  /// Cardio exercises
  final int? durationSeconds;
  final double? distanceMeters;

  /// Actual rest taken after this set, in seconds
  final int? restAfterSeconds;

  /// Timestamp when this set was completed/logged (ISO 8601 datetime).
  final String? completedAt;

  final String? notes;

  const WorkoutSet({
    required this.setNumber,
    this.weightLbs,
    this.addedPerSideLbs,
    this.addedWeightLbs,
    this.reps,
    this.durationSeconds,
    this.distanceMeters,
    this.restAfterSeconds,
    this.completedAt,
    this.notes,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSetFromJson(json);

  Map<String, dynamic> toJson() => _$WorkoutSetToJson(this);

  WorkoutSet copyWith({
    int? setNumber,
    double? weightLbs,
    double? addedPerSideLbs,
    double? addedWeightLbs,
    int? reps,
    int? durationSeconds,
    double? distanceMeters,
    int? restAfterSeconds,
    String? completedAt,
    String? notes,
    bool clearNotes = false,
    bool clearWeightLbs = false,
    bool clearAddedPerSideLbs = false,
    bool clearAddedWeightLbs = false,
    bool clearDistanceMeters = false,
    bool clearCompletedAt = false,
  }) {
    return WorkoutSet(
      setNumber: setNumber ?? this.setNumber,
      weightLbs: clearWeightLbs ? null : (weightLbs ?? this.weightLbs),
      addedPerSideLbs: clearAddedPerSideLbs
          ? null
          : (addedPerSideLbs ?? this.addedPerSideLbs),
      addedWeightLbs: clearAddedWeightLbs
          ? null
          : (addedWeightLbs ?? this.addedWeightLbs),
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceMeters:
          clearDistanceMeters ? null : (distanceMeters ?? this.distanceMeters),
      restAfterSeconds: restAfterSeconds ?? this.restAfterSeconds,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  // ── Display helpers ───────────────────────────────────────────────────────

  /// Formats the weight value as a string, handling bodyweight/added cases.
  String _weightLabel(Exercise? exercise) {
    final w = weightLbs ?? addedWeightLbs;
    if (w == null) {
      return exercise?.type == ExerciseType.bodyweight ? 'BW' : '—';
    }
    if (exercise?.type == ExerciseType.bodyweight) {
      if (w > 0) return '+${_fmt(w)} lbs';
      if (w < 0) return '-${_fmt(w.abs())} lbs (assist)';
      return 'BW';
    }
    return '${_fmt(w)} lbs';
  }

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  /// Returns a human-readable summary of this set, using the exercise's
  /// WeightMode to correctly place "ea" and "sec" labels.
  /// For barbell sets (addedPerSideLbs != null), shows the full breakdown:
  /// "[45] +15e [=75] × 5"
  ///
  /// Falls back to [summary] when no exercise is provided.
  String summaryFor(Exercise? exercise) {
    // Cardio sets are unaffected by WeightMode
    if (exercise?.type == ExerciseType.cardio) return summary;

    // Barbell breakdown takes priority over WeightMode formatting
    if (addedPerSideLbs != null && weightLbs != null) {
      return _barbellSummary(reps);
    }

    final mode = exercise?.weightMode ?? WeightMode.total;
    final w = _weightLabel(exercise);
    final r = reps;

    switch (mode) {
      case WeightMode.total:
        // "185 lbs x 5"
        if (r != null) return '$w \u00d7 $r';
        return w;

      case WeightMode.perSide:
        // "30 lbs ea x 14"
        if (r != null) return '$w ea \u00d7 $r';
        return '$w ea';

      case WeightMode.perPart:
        // "20 lbs x 14 ea"
        if (r != null) return '$w \u00d7 $r ea';
        return w;

      case WeightMode.timedReps:
        // "0 lbs x 10 sec"  (reps field stores seconds)
        if (r != null) return '$w \u00d7 ${r}sec';
        return w;
    }
  }

  /// Barbell breakdown string: "[45] +15e [=75] × 5"
  /// Bar weight is derived as: total - 2 × perSide, rounded to nearest 0.5.
  String _barbellSummary(int? r) {
    final perSide = addedPerSideLbs!;
    final total = weightLbs!;
    final bar = total - 2 * perSide;
    final perSideStr = _fmt(perSide.abs());
    final totalStr = _fmt(total);
    final barStr = _fmt(bar);
    final sign = perSide >= 0 ? '+' : '-';
    final core = '[$barStr] ${sign}${perSideStr}e [=${totalStr}]';
    if (r != null) return '$core \u00d7 $r';
    return core;
  }

  /// Fallback summary with no exercise context (used in places that
  /// don't have access to the exercise definition).
  String get summary {
    final parts = <String>[];
    if (weightLbs != null && addedPerSideLbs != null) {
      parts.add(_barbellSummary(reps));
      return parts.first;
    } else if (weightLbs != null && reps != null) {
      parts.add('${_fmt(weightLbs!)} lbs \u00d7 $reps');
    } else if (addedWeightLbs != null && reps != null) {
      if (addedWeightLbs! > 0) {
        parts.add('+${_fmt(addedWeightLbs!)} lbs \u00d7 $reps');
      } else if (addedWeightLbs! < 0) {
        parts.add('-${_fmt(addedWeightLbs!.abs())} lbs (assist) \u00d7 $reps');
      } else {
        parts.add('BW \u00d7 $reps');
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
    return parts.isEmpty ? '—' : parts.join(' \u00b7 ');
  }
}
