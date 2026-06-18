// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_set.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WorkoutSet _$WorkoutSetFromJson(Map<String, dynamic> json) => WorkoutSet(
      setNumber: (json['setNumber'] as num).toInt(),
      weightLbs: (json['weightLbs'] as num?)?.toDouble(),
      addedWeightLbs: (json['addedWeightLbs'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      restAfterSeconds: (json['restAfterSeconds'] as num?)?.toInt(),
      notes: json['notes'] as String?,
    );

Map<String, dynamic> _$WorkoutSetToJson(WorkoutSet instance) =>
    <String, dynamic>{
      'setNumber': instance.setNumber,
      'weightLbs': instance.weightLbs,
      'addedWeightLbs': instance.addedWeightLbs,
      'reps': instance.reps,
      'durationSeconds': instance.durationSeconds,
      'distanceMeters': instance.distanceMeters,
      'restAfterSeconds': instance.restAfterSeconds,
      'notes': instance.notes,
    };
