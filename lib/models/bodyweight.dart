import 'package:json_annotation/json_annotation.dart';

part 'bodyweight.g.dart';

@JsonSerializable()
class BodyweightEntry {
  final String date; // YYYY-MM-DD
  final double weightLbs;

  const BodyweightEntry({required this.date, required this.weightLbs});

  factory BodyweightEntry.fromJson(Map<String, dynamic> json) =>
      _$BodyweightEntryFromJson(json);

  Map<String, dynamic> toJson() => _$BodyweightEntryToJson(this);
}

@JsonSerializable()
class BodyweightLog {
  final int version;
  final String unit;
  final List<BodyweightEntry> entries;

  const BodyweightLog({
    this.version = 1,
    this.unit = 'lbs',
    required this.entries,
  });

  factory BodyweightLog.fromJson(Map<String, dynamic> json) =>
      _$BodyweightLogFromJson(json);

  Map<String, dynamic> toJson() => _$BodyweightLogToJson(this);

  BodyweightLog copyWith({List<BodyweightEntry>? entries}) {
    return BodyweightLog(
      version: version,
      unit: unit,
      entries: entries ?? this.entries,
    );
  }

  /// Most recent entry
  BodyweightEntry? get latest =>
      entries.isEmpty ? null : entries.last;
}
