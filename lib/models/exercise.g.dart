// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Exercise _$ExerciseFromJson(Map<String, dynamic> json) => Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      category: $enumDecode(_$MuscleCategoryEnumMap, json['category']),
      type: $enumDecode(_$ExerciseTypeEnumMap, json['type']),
      equipment: json['equipment'] as String?,
      defaultRestSeconds: (json['defaultRestSeconds'] as num?)?.toInt() ?? 120,
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$ExerciseToJson(Exercise instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': _$MuscleCategoryEnumMap[instance.category]!,
      'type': _$ExerciseTypeEnumMap[instance.type]!,
      'equipment': instance.equipment,
      'defaultRestSeconds': instance.defaultRestSeconds,
      'notes': instance.notes,
    };

const _$MuscleCategoryEnumMap = {
  MuscleCategory.push: 'push',
  MuscleCategory.pull: 'pull',
  MuscleCategory.legs: 'legs',
  MuscleCategory.core: 'core',
  MuscleCategory.cardio: 'cardio',
  MuscleCategory.full: 'full',
  MuscleCategory.other: 'other',
};

const _$ExerciseTypeEnumMap = {
  ExerciseType.weighted: 'weighted',
  ExerciseType.bodweightPlus: 'bodweightPlus',
  ExerciseType.bodyweight: 'bodyweight',
  ExerciseType.cardio: 'cardio',
};

ExerciseLibrary _$ExerciseLibraryFromJson(Map<String, dynamic> json) =>
    ExerciseLibrary(
      version: (json['version'] as num?)?.toInt() ?? 1,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ExerciseLibraryToJson(ExerciseLibrary instance) =>
    <String, dynamic>{
      'version': instance.version,
      'exercises': instance.exercises,
    };
