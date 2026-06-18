import 'workout_set.dart';

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
  final List<ExerciseOccurrence> occurrences; // oldest → newest

  const ExerciseHistory({
    required this.exerciseId,
    required this.occurrences,
  });

  bool get isEmpty => occurrences.isEmpty;

  ExerciseOccurrence? get lastOccurrence =>
      occurrences.isEmpty ? null : occurrences.last;

  /// All-time best set by weight (for weighted exercises)
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

  /// All-time best set by added weight (for bodyweight_plus exercises)
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

  /// All-time most reps in a single set
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

  /// All-time longest duration
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

  /// All-time longest distance
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
}
