import 'package:flutter_test/flutter_test.dart';
import 'package:liftlog/models/workout_set.dart';

void main() {
  group('WorkoutSet.actualRestSeconds', () {
    test('calculates rest from completion timestamps', () {
      final previous = WorkoutSet(
        setNumber: 1,
        completedAt: '2026-08-02T10:00:00',
      );

      final current = WorkoutSet(
        setNumber: 2,
        completedAt: '2026-08-02T10:02:37',
      );

      expect(current.actualRestSeconds(previous), 157);
    });

    test('returns null when previous set has no timestamp', () {
      final previous = WorkoutSet(setNumber: 1);

      final current = WorkoutSet(
        setNumber: 2,
        completedAt: '2026-08-02T10:02:37',
      );

      expect(current.actualRestSeconds(previous), isNull);
    });

    test('returns null when current set has no timestamp', () {
      final previous = WorkoutSet(
        setNumber: 1,
        completedAt: '2026-08-02T10:00:00',
      );

      final current = WorkoutSet(setNumber: 2);

      expect(current.actualRestSeconds(previous), isNull);
    });

    test('returns null for invalid timestamps', () {
      final previous = WorkoutSet(
        setNumber: 1,
        completedAt: 'not-a-date',
      );

      final current = WorkoutSet(
        setNumber: 2,
        completedAt: '2026-08-02T10:02:37',
      );

      expect(current.actualRestSeconds(previous), isNull);
    });

    test('returns zero when sets have identical timestamps', () {
      final previous = WorkoutSet(
        setNumber: 1,
        completedAt: '2026-08-02T10:00:00',
      );

      final current = WorkoutSet(
        setNumber: 2,
        completedAt: '2026-08-02T10:00:00',
      );

      expect(current.actualRestSeconds(previous), 0);
    });

    test('returns null when current timestamp precedes previous timestamp', () {
      final previous = WorkoutSet(
        setNumber: 1,
        completedAt: '2026-08-02T10:05:00',
      );

      final current = WorkoutSet(
        setNumber: 2,
        completedAt: '2026-08-02T10:02:00',
      );

      expect(current.actualRestSeconds(previous), isNull);
    });
  });
}
