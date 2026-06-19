import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/session.dart';
import '../repositories/workout_repository.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import 'log_workout_screen.dart';
import 'session_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<WorkoutSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await WorkoutRepository.instance.loadAllSessions();
    if (!mounted) return;
    setState(() {
      _sessions = sessions.reversed.toList(); // newest first
      _loading = false;
    });
  }

  Future<void> _startWorkout() async {
    final split = await _pickSplit(context);
    if (split == null || !mounted) return;
    final now = DateTime.now();
    final date = todayIso();
    final id = '${date}_$split';
    final session = WorkoutSession(
      id: id,
      date: date,
      split: split,
      startedAt: nowIso(),
      exercises: const [],
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LogWorkoutScreen(session: session),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(onStart: _startWorkout),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                      ? const _EmptyState()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            itemCount: _sessions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                _SessionCard(session: _sessions[i], onTap: () async {
                                  final deleted = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionDetailScreen(
                                        session: _sessions[i],
                                      ),
                                    ),
                                  );
                                  if (deleted == true) _load();
                                }),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onStart;
  const _Header({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LiftLog',
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: kAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            formatDayName(todayIso()),
            style: Theme.of(context).appBarTheme.titleTextStyle!.copyWith(
                  fontSize: 28,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Start Workout'),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 4),
          Text(
            'RECENT',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback onTap;
  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final exerciseCount = session.exercises.length;
    final setCount =
        session.exercises.fold<int>(0, (sum, e) => sum + e.sets.length);
    final duration = _duration();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _SplitChip(split: session.split),
                  const Spacer(),
                  Text(formatShortDate(session.date),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(label: 'exercises', value: '$exerciseCount'),
                  const SizedBox(width: 20),
                  _Stat(label: 'sets', value: '$setCount'),
                  if (duration != null) ...[
                    const SizedBox(width: 20),
                    _Stat(label: 'duration', value: duration),
                  ],
                ],
              ),
              if (session.exercises.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  session.exercises.map((e) => e.exerciseId).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _duration() {
    if (session.startedAt == null || session.endedAt == null) return null;
    final start = DateTime.tryParse(session.startedAt!);
    final end = DateTime.tryParse(session.endedAt!);
    if (start == null || end == null) return null;
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SplitChip extends StatelessWidget {
  final String split;
  const _SplitChip({required this.split});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kAccentDim.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kAccentDim, width: 1),
      ),
      child: Text(
        split.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: 11),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: kOnSurfaceDim),
            const SizedBox(height: 16),
            Text(
              'No sessions yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap Start Workout to log your first session.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Split picker ─────────────────────────────────────────────────────────────

final _commonSplits = [
  'push', 'pull', 'legs', 'upper', 'lower', 'full', 'cardio', 'core',
];

Future<String?> _pickSplit(BuildContext context) async {
  String? custom;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: kSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("What's today's split?",
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _commonSplits.map((split) {
                  return ActionChip(
                    label: Text(titleCase(split)),
                    onPressed: () => Navigator.pop(ctx, split),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Custom split name…',
                  prefixIcon: Icon(Icons.edit_outlined, size: 18),
                ),
                textCapitalization: TextCapitalization.none,
                onSubmitted: (val) {
                  final trimmed = val.trim().toLowerCase();
                  if (trimmed.isNotEmpty) Navigator.pop(ctx, trimmed);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
