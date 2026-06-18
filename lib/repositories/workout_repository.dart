import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/bodyweight.dart';
import '../models/exercise.dart';
import '../models/exercise_history.dart';
import '../models/session.dart';
import '../utils/default_exercises.dart';

/// All file I/O for LiftLog. Single source of truth.
///
/// Directory layout:
///   <root>/
///     exercises.json
///     bodyweight.json
///     sessions/
///       YYYY-MM-DD_<split>.json
///       ...
class WorkoutRepository {
  WorkoutRepository._();
  static final WorkoutRepository instance = WorkoutRepository._();

  String? _rootPath;

  Future<String> get rootPath async {
    if (_rootPath != null) return _rootPath!;
    final dir = await getApplicationDocumentsDirectory();
    _rootPath = p.join(dir.path, 'liftlog');
    await Directory(p.join(_rootPath!, 'sessions')).create(recursive: true);
    return _rootPath!;
  }

  // ── Exercise Library ────────────────────────────────────────────────────

  Future<String> get _exercisesPath async =>
      p.join(await rootPath, 'exercises.json');

  Future<ExerciseLibrary> loadExerciseLibrary() async {
    final path = await _exercisesPath;
    final file = File(path);
    if (!await file.exists()) {
      final library = ExerciseLibrary(exercises: defaultExercises);
      await _writeJson(path, library.toJson());
      return library;
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return ExerciseLibrary.fromJson(json);
  }

  Future<void> saveExerciseLibrary(ExerciseLibrary library) async {
    await _writeJson(await _exercisesPath, library.toJson());
  }

  Future<Exercise> addExercise(Exercise exercise) async {
    final library = await loadExerciseLibrary();
    final updated = library.copyWith(
      exercises: [...library.exercises, exercise],
    );
    await saveExerciseLibrary(updated);
    return exercise;
  }

  // ── Bodyweight Log ──────────────────────────────────────────────────────

  Future<String> get _bodyweightPath async =>
      p.join(await rootPath, 'bodyweight.json');

  Future<BodyweightLog> loadBodyweightLog() async {
    final path = await _bodyweightPath;
    final file = File(path);
    if (!await file.exists()) {
      return const BodyweightLog(entries: []);
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return BodyweightLog.fromJson(json);
  }

  Future<void> logBodyweight(String date, double weightLbs) async {
    final log = await loadBodyweightLog();
    final entries = [...log.entries];
    // Replace if same date, otherwise append
    final idx = entries.indexWhere((e) => e.date == date);
    final entry = BodyweightEntry(date: date, weightLbs: weightLbs);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      entries.add(entry);
      entries.sort((a, b) => a.date.compareTo(b.date));
    }
    await _writeJson(
        await _bodyweightPath, log.copyWith(entries: entries).toJson());
  }

  // ── Sessions ────────────────────────────────────────────────────────────

  Future<String> get _sessionsDir async =>
      p.join(await rootPath, 'sessions');

  Future<List<WorkoutSession>> loadAllSessions() async {
    final dir = Directory(await _sessionsDir);
    final files = await dir
        .list()
        .where((e) => e.path.endsWith('.json'))
        .toList();
    final sessions = <WorkoutSession>[];
    for (final file in files) {
      try {
        final json =
            jsonDecode(await File(file.path).readAsString()) as Map<String, dynamic>;
        sessions.add(WorkoutSession.fromJson(json));
      } catch (e) {
        // Skip malformed files; log in debug
        assert(() {
          // ignore: avoid_print
          print('Failed to parse ${file.path}: $e');
          return true;
        }());
      }
    }
    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  Future<WorkoutSession?> loadSession(String id) async {
    final dir = await _sessionsDir;
    // id == YYYY-MM-DD_split
    final path = p.join(dir, '$id.json');
    final file = File(path);
    if (!await file.exists()) return null;
    final json =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return WorkoutSession.fromJson(json);
  }

  Future<void> saveSession(WorkoutSession session) async {
    final dir = await _sessionsDir;
    final path = p.join(dir, session.filename);
    await _writeJson(path, session.toJson());
  }

  Future<void> deleteSession(WorkoutSession session) async {
    final dir = await _sessionsDir;
    final file = File(p.join(dir, session.filename));
    if (await file.exists()) await file.delete();
  }

  // ── Exercise History (computed) ─────────────────────────────────────────

  Future<ExerciseHistory> getExerciseHistory(String exerciseId) async {
    final sessions = await loadAllSessions();
    final occurrences = <ExerciseOccurrence>[];
    for (final session in sessions) {
      for (final entry in session.exercises) {
        if (entry.exerciseId == exerciseId) {
          occurrences.add(ExerciseOccurrence(
            date: session.date,
            sessionId: session.id,
            sets: entry.sets,
          ));
        }
      }
    }
    return ExerciseHistory(exerciseId: exerciseId, occurrences: occurrences);
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _writeJson(String path, Map<String, dynamic> data) async {
    const encoder = JsonEncoder.withIndent('  ');
    await File(path).writeAsString(encoder.convert(data));
  }
}
