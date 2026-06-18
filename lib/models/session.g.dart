// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExerciseEntry _$ExerciseEntryFromJson(Map<String, dynamic> json) =>
    ExerciseEntry(
      exerciseId: json['exerciseId'] as String,
      order: (json['order'] as num).toInt(),
      notes: json['notes'] as String?,
      sets: (json['sets'] as List<dynamic>)
          .map((e) => WorkoutSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ExerciseEntryToJson(ExerciseEntry instance) =>
    <String, dynamic>{
      'exerciseId': instance.exerciseId,
      'order': instance.order,
      'notes': instance.notes,
      'sets': instance.sets,
    };

WorkoutSession _$WorkoutSessionFromJson(Map<String, dynamic> json) =>
    WorkoutSession(
      version: (json['version'] as num?)?.toInt() ?? 1,
      id: json['id'] as String,
      date: json['date'] as String,
      split: json['split'] as String,
      startedAt: json['startedAt'] as String?,
      endedAt: json['endedAt'] as String?,
      notes: json['notes'] as String?,
      exercises: (json['exercises'] as List<dynamic>)
          .map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$WorkoutSessionToJson(WorkoutSession instance) =>
    <String, dynamic>{
      'version': instance.version,
      'id': instance.id,
      'date': instance.date,
      'split': instance.split,
      'startedAt': instance.startedAt,
      'endedAt': instance.endedAt,
      'notes': instance.notes,
      'exercises': instance.exercises,
    };
