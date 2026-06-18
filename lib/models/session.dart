import 'package:json_annotation/json_annotation.dart';
import 'workout_set.dart';

part 'session.g.dart';

@JsonSerializable()
class ExerciseEntry {
  final String exerciseId;
  final int order;
  final String? notes;
  final List<WorkoutSet> sets;

  const ExerciseEntry({
    required this.exerciseId,
    required this.order,
    this.notes,
    required this.sets,
  });

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) =>
      _$ExerciseEntryFromJson(json);

  Map<String, dynamic> toJson() => _$ExerciseEntryToJson(this);

  ExerciseEntry copyWith({
    String? exerciseId,
    int? order,
    String? notes,
    List<WorkoutSet>? sets,
    bool clearNotes = false,
  }) {
    return ExerciseEntry(
      exerciseId: exerciseId ?? this.exerciseId,
      order: order ?? this.order,
      notes: clearNotes ? null : (notes ?? this.notes),
      sets: sets ?? this.sets,
    );
  }
}

@JsonSerializable()
class WorkoutSession {
  final int version;
  final String id;
  final String date; // ISO 8601: YYYY-MM-DD
  final String split; // push, pull, legs, etc.
  final String? startedAt; // ISO 8601 datetime
  final String? endedAt;
  final String? notes;
  final List<ExerciseEntry> exercises;

  const WorkoutSession({
    this.version = 1,
    required this.id,
    required this.date,
    required this.split,
    this.startedAt,
    this.endedAt,
    this.notes,
    required this.exercises,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) =>
      _$WorkoutSessionFromJson(json);

  Map<String, dynamic> toJson() => _$WorkoutSessionToJson(this);

  /// Filename for this session: YYYY-MM-DD_<split>.json
  String get filename => '${date}_$split.json';

  WorkoutSession copyWith({
    String? id,
    String? date,
    String? split,
    String? startedAt,
    String? endedAt,
    String? notes,
    List<ExerciseEntry>? exercises,
    bool clearNotes = false,
    bool clearEndedAt = false,
  }) {
    return WorkoutSession(
      version: version,
      id: id ?? this.id,
      date: date ?? this.date,
      split: split ?? this.split,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      notes: clearNotes ? null : (notes ?? this.notes),
      exercises: exercises ?? this.exercises,
    );
  }
}
