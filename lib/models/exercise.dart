import 'package:json_annotation/json_annotation.dart';

part 'exercise.g.dart';

enum ExerciseType {
  /// Barbell, dumbbell, machine: tracks weight_lbs + reps
  weighted,

  /// Bodyweight + optional added weight: tracks added_weight_lbs + reps
  bodweightPlus,

  /// Pure bodyweight: tracks reps only
  bodyweight,

  /// Runs, rows, bike: tracks duration_seconds and/or distance_meters
  cardio,
}

enum MuscleCategory {
  push,
  pull,
  legs,
  core,
  cardio,
  full,
  other,
}

@JsonSerializable()
class Exercise {
  final String id;
  final String name;
  final MuscleCategory category;
  final ExerciseType type;
  final String? equipment;
  final int defaultRestSeconds;
  final String? notes;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    this.equipment,
    this.defaultRestSeconds = 120,
    this.notes,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);

  Map<String, dynamic> toJson() => _$ExerciseToJson(this);

  Exercise copyWith({
    String? id,
    String? name,
    MuscleCategory? category,
    ExerciseType? type,
    String? equipment,
    int? defaultRestSeconds,
    String? notes,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      type: type ?? this.type,
      equipment: equipment ?? this.equipment,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      notes: notes ?? this.notes,
    );
  }
}

@JsonSerializable()
class ExerciseLibrary {
  final int version;
  final List<Exercise> exercises;

  const ExerciseLibrary({
    this.version = 1,
    required this.exercises,
  });

  factory ExerciseLibrary.fromJson(Map<String, dynamic> json) =>
      _$ExerciseLibraryFromJson(json);

  Map<String, dynamic> toJson() => _$ExerciseLibraryToJson(this);

  ExerciseLibrary copyWith({List<Exercise>? exercises}) {
    return ExerciseLibrary(
      version: version,
      exercises: exercises ?? this.exercises,
    );
  }
}
