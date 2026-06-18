// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bodyweight.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BodyweightEntry _$BodyweightEntryFromJson(Map<String, dynamic> json) =>
    BodyweightEntry(
      date: json['date'] as String,
      weightLbs: (json['weightLbs'] as num).toDouble(),
    );

Map<String, dynamic> _$BodyweightEntryToJson(BodyweightEntry instance) =>
    <String, dynamic>{
      'date': instance.date,
      'weightLbs': instance.weightLbs,
    };

BodyweightLog _$BodyweightLogFromJson(Map<String, dynamic> json) =>
    BodyweightLog(
      version: (json['version'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? 'lbs',
      entries: (json['entries'] as List<dynamic>)
          .map((e) => BodyweightEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$BodyweightLogToJson(BodyweightLog instance) =>
    <String, dynamic>{
      'version': instance.version,
      'unit': instance.unit,
      'entries': instance.entries,
    };
