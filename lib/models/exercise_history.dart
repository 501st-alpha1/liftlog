import 'workout_set.dart';
import 'exercise.dart';

/// A single past appearance of an exercise in a session.
class ExerciseOccurrence {
  final String date;
  final String sessionId;
  final List<WorkoutSet> sets;

  const ExerciseOccurrence({
    required this.date,
    required this.sessionId,
    required this.sets,
  });
}

/// Computed summary for an exercise across all sessions.
class ExerciseHistory {
  final String exerciseId;
  final List<ExerciseOccurrence> occurrences; // oldest to newest

  const ExerciseHistory({
    required this.exerciseId,
    required this.occurrences,
  });

  bool get isEmpty => occurrences.isEmpty;

  ExerciseOccurrence? get lastOccurrence =>
      occurrences.isEmpty ? null : occurrences.last;

  /// All-time best set by weight (for weighted exercises).
  WorkoutSet? get bestWeightSet {
    WorkoutSet? best;
    for (final occ in occurrences) {
      for (final set in occ.sets) {
        if (set.weightLbs != null) {
          if (best == null || set.weightLbs! > best.weightLbs!) {
            best = set;
          }
        }
      }
    }
    return best;
  }

  /// All-time best set by added weight (positive = added, negative = assisted).
  /// Highest value wins, so unassisted always ranks above assisted.
  WorkoutSet? get bestAddedWeightSet {
    WorkoutSet? best;
    for (final occ in occurrences) {
      for (final set in occ.sets) {
        if (set.addedWeightLbs != null) {
          if (best == null || set.addedWeightLbs! > best.addedWeightLbs!) {
            best = set;
          }
        }
      }
    }
    return best;
  }

  /// All-time most reps in a single set.
  /// Also used for WeightMode.timedReps (reps field = seconds).
  WorkoutSet? get bestRepSet {
    WorkoutSet? best;
    for (final occ in occurrences) {
      for (final set in occ.sets) {
        if (set.reps != null) {
          if (best == null || set.reps! > best.reps!) {
            best = set;
          }
        }
      }
    }
    return best;
  }

  /// All-time longest duration (cardio).
  WorkoutSet? get bestDurationSet {
    WorkoutSet? best;
    for (final occ in occurrences) {
      for (final set in occ.sets) {
        if (set.durationSeconds != null) {
          if (best == null ||
              set.durationSeconds! > best.durationSeconds!) {
            best = set;
          }
        }
      }
    }
    return best;
  }

  /// All-time longest distance (cardio).
  WorkoutSet? get bestDistanceSet {
    WorkoutSet? best;
    for (final occ in occurrences) {
      for (final set in occ.sets) {
        if (set.distanceMeters != null) {
          if (best == null ||
              set.distanceMeters! > best.distanceMeters!) {
            best = set;
          }
        }
      }
    }
    return best;
  }

  /// Returns a short PR label string appropriate for the given exercise type
  /// and weight mode. Returns null if no PR data is available.
  String? prLabel(Exercise exercise) {
    switch (exercise.type) {
      case ExerciseType.weighted:
        switch (exercise.weightMode) {
          case WeightMode.timedReps:
            final pr = bestRepSet;
            return pr?.reps != null ? 'PR: ${pr!.reps}sec' : null;
          default:
            final pr = bestWeightSet;
            if (pr == null) return null;
            return 'PR: ${pr.summaryFor(exercise)}';
        }
      case ExerciseType.bodyweight:
        final addedPr = bestAddedWeightSet;
        if (addedPr != null && (addedPr.addedWeightLbs ?? 0) != 0) {
          return 'PR: ${addedPr.summaryFor(exercise)}';
        }
        switch (exercise.weightMode) {
          case WeightMode.timedReps:
            final pr = bestRepSet;
            return pr?.reps != null ? 'PR: ${pr!.reps}sec' : null;
          default:
            final pr = bestRepSet;
            return pr?.reps != null ? 'PR: ${pr!.reps} reps' : null;
        }
      case ExerciseType.cardio:
        final best = bestDistanceSet;
        if (best != null && best.distanceMeters != null) {
          final km = best.distanceMeters! / 1000;
          return 'Best: ${km.toStringAsFixed(2)} km';
        }
        return null;
    }
  }
}
