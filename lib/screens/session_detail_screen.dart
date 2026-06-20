import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../repositories/workout_repository.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class SessionDetailScreen extends StatefulWidget {
  final WorkoutSession session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late WorkoutSession _session;
  Map<String, Exercise> _exerciseMap = {};

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final library = await WorkoutRepository.instance.loadExerciseLibrary();
    if (!mounted) return;
    setState(() {
      _exerciseMap = {for (final e in library.exercises) e.id: e};
    });
  }

  String? get _duration {
    if (_session.startedAt == null || _session.endedAt == null) return null;
    final start = DateTime.tryParse(_session.startedAt!);
    final end = DateTime.tryParse(_session.endedAt!);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  int get _totalSets =>
      _session.exercises.fold(0, (sum, e) => sum + e.sets.length);

  int get _totalVolumeLbs {
    var total = 0.0;
    for (final entry in _session.exercises) {
      for (final set in entry.sets) {
        if (set.weightLbs != null && set.reps != null) {
          total += set.weightLbs! * set.reps!;
        } else if (set.addedWeightLbs != null && set.reps != null) {
          total += set.addedWeightLbs! * set.reps!;
        }
      }
    }
    return total.round();
  }

  Future<void> _deleteSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Delete session?'),
        content: const Text(
            'This will permanently delete this workout session. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kDestructive),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await WorkoutRepository.instance.deleteSession(_session);
    if (mounted) Navigator.pop(context, true); // true = was deleted
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${titleCase(_session.split)} — ${formatDate(_session.date)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kDestructive),
            tooltip: 'Delete session',
            onPressed: _deleteSession,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          // ── Summary strip ───────────────────────────────────────────────
          _SummaryStrip(
            exerciseCount: _session.exercises.length,
            setCount: _totalSets,
            duration: _duration,
            volumeLbs: _totalVolumeLbs > 0 ? _totalVolumeLbs : null,
            startedAt: _session.startedAt,
          ),

          if (_session.notes != null && _session.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _NotesCard(notes: _session.notes!),
          ],

          const SizedBox(height: 20),
          Text('EXERCISES', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),

          // ── Exercise cards ───────────────────────────────────────────────
          ..._session.exercises.map((entry) {
            final exercise = _exerciseMap[entry.exerciseId];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExerciseDetailCard(
                entry: entry,
                exercise: exercise,
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Summary Strip ─────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final int exerciseCount;
  final int setCount;
  final String? duration;
  final int? volumeLbs;
  final String? startedAt;

  const _SummaryStrip({
    required this.exerciseCount,
    required this.setCount,
    required this.duration,
    required this.volumeLbs,
    required this.startedAt,
  });

  @override
  Widget build(BuildContext context) {
    String? timeStr;
    if (startedAt != null) {
      final dt = DateTime.tryParse(startedAt!);
      if (dt != null) {
        final h = dt.hour;
        final m = dt.minute.toString().padLeft(2, '0');
        final period = h >= 12 ? 'PM' : 'AM';
        final hour = h % 12 == 0 ? 12 : h % 12;
        timeStr = '$hour:$m $period';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timeStr != null) ...[
              Text(
                'Started at $timeStr',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                _StatCell(label: 'Exercises', value: '$exerciseCount'),
                _Divider(),
                _StatCell(label: 'Sets', value: '$setCount'),
                if (duration != null) ...[
                  _Divider(),
                  _StatCell(label: 'Duration', value: duration!),
                ],
                if (volumeLbs != null) ...[
                  _Divider(),
                  _StatCell(
                    label: 'Volume',
                    value: '${_formatVolume(volumeLbs!)} lbs',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatVolume(int lbs) {
    if (lbs >= 1000) {
      return '${(lbs / 1000).toStringAsFixed(1)}k';
    }
    return '$lbs';
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFF2C2F33),
    );
  }
}

// ── Notes Card ────────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notes, size: 16, color: kOnSurfaceDim),
            const SizedBox(width: 10),
            Expanded(
              child: Text(notes, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise Detail Card ──────────────────────────────────────────────────────

class _ExerciseDetailCard extends StatelessWidget {
  final ExerciseEntry entry;
  final Exercise? exercise;

  const _ExerciseDetailCard({required this.entry, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final name = exercise?.name ?? entry.exerciseId;
    final type = exercise?.type ?? ExerciseType.weighted;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Expanded(
                  child:
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                ),
                if (exercise != null)
                  _TypeBadge(type: exercise!.type),
              ],
            ),

            if (entry.notes != null && entry.notes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.notes!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            ],

            if (entry.sets.isNotEmpty) ...[
              const SizedBox(height: 12),
              // Column headers
              _SetTableHeader(type: type),
              const Divider(height: 12),
              // Set rows
              ...entry.sets.map((set) => _SetTableRow(set: set, type: type)),

              // Per-exercise summary for weighted/bodyweight
              if (type == ExerciseType.weighted ||
                  type == ExerciseType.bodyweight) ...[
                const Divider(height: 16),
                _ExerciseSummaryRow(sets: entry.sets, type: type),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SetTableHeader extends StatelessWidget {
  final ExerciseType type;
  const _SetTableHeader({required this.type});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall!
        .copyWith(fontWeight: FontWeight.w600);

    return Row(
      children: [
        SizedBox(
            width: 28, child: Text('SET', style: style, textAlign: TextAlign.center)),
        const SizedBox(width: 8),
        if (type == ExerciseType.weighted)
          Expanded(child: Text('WEIGHT', style: style)),
        if (type == ExerciseType.bodyweight)
          Expanded(child: Text('ADDED', style: style)),
        if (type != ExerciseType.cardio)
          SizedBox(width: 56, child: Text('REPS', style: style, textAlign: TextAlign.right)),
        if (type == ExerciseType.cardio) ...[
          Expanded(child: Text('DURATION', style: style)),
          SizedBox(
              width: 80,
              child: Text('DISTANCE', style: style, textAlign: TextAlign.right)),
        ],
        SizedBox(
            width: 52,
            child: Text('REST', style: style, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _SetTableRow extends StatelessWidget {
  final WorkoutSet set;
  final ExerciseType type;
  const _SetTableRow({required this.set, required this.type});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;
    final dimStyle = style.copyWith(color: kOnSurfaceDim);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${set.setNumber}',
              style: Theme.of(context).textTheme.labelLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          if (type == ExerciseType.weighted)
            Expanded(
              child: Text(
                set.weightLbs != null ? formatWeight(set.weightLbs) : '—',
                style: style,
              ),
            ),
          if (type == ExerciseType.bodyweight)
            Expanded(
              child: Text(
                set.addedWeightLbs != null && set.addedWeightLbs != 0
                    ? (set.addedWeightLbs! > 0
                        ? '+${formatWeight(set.addedWeightLbs)}'
                        : '-${formatWeight(set.addedWeightLbs!.abs())} (assist)')
                    : 'BW',
                style: style,
              ),
            ),
          if (type != ExerciseType.cardio)
            SizedBox(
              width: 56,
              child: Text(
                set.reps != null ? '${set.reps}' : '—',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
          if (type == ExerciseType.cardio) ...[
            Expanded(
              child: Text(
                set.durationSeconds != null
                    ? formatDuration(set.durationSeconds!)
                    : '—',
                style: style,
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                set.distanceMeters != null
                    ? '${(set.distanceMeters! / 1000).toStringAsFixed(2)} km'
                    : '—',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
          ],
          SizedBox(
            width: 52,
            child: Text(
              set.restAfterSeconds != null
                  ? formatDuration(set.restAfterSeconds!)
                  : '—',
              style: dimStyle,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSummaryRow extends StatelessWidget {
  final List<WorkoutSet> sets;
  final ExerciseType type;
  const _ExerciseSummaryRow({required this.sets, required this.type});

  @override
  Widget build(BuildContext context) {
    // Total volume for this exercise
    var volume = 0.0;
    var totalReps = 0;
    for (final s in sets) {
      final w = s.weightLbs ?? s.addedWeightLbs ?? 0;
      final r = s.reps ?? 0;
      volume += w * r;
      totalReps += r;
    }

    return Row(
      children: [
        Text(
          '${sets.length} sets · $totalReps reps',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (volume != 0) ...[
          Text(' · ', style: Theme.of(context).textTheme.bodySmall),
          Text(
            '${volume.round()} lbs volume',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ExerciseType type;
  const _TypeBadge({required this.type});

  String get _label => switch (type) {
        ExerciseType.weighted => 'weighted',
        ExerciseType.bodyweight => 'BW',
        ExerciseType.cardio => 'cardio',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceVariant,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        _label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
