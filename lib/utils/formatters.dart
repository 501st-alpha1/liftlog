import 'package:intl/intl.dart';

final _dateFormat = DateFormat('MMM d, yyyy');
final _dayFormat = DateFormat('EEEE');
final _shortDateFormat = DateFormat('MMM d');

String formatDate(String isoDate) {
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return isoDate;
  return _dateFormat.format(dt);
}

String formatDayName(String isoDate) {
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return isoDate;
  return _dayFormat.format(dt);
}

String formatShortDate(String isoDate) {
  final dt = DateTime.tryParse(isoDate);
  if (dt == null) return isoDate;
  return _shortDateFormat.format(dt);
}

String todayIso() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String nowIso() => DateTime.now().toIso8601String().substring(0, 19);

String formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}

String formatWeight(double? lbs) {
  if (lbs == null) return '—';
  if (lbs % 1 == 0) return '${lbs.toInt()} lbs';
  return '${lbs.toStringAsFixed(1)} lbs';
}

/// Capitalizes first letter of each word
String titleCase(String s) {
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
