import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/exercise_history.dart';
import '../repositories/workout_repository.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  List<Exercise> _exercises = [];
  Map<String, ExerciseHistory> _historyCache = {};
  MuscleCategory? _filterCategory;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final library = await WorkoutRepository.instance.loadExerciseLibrary();
    if (!mounted) return;
    setState(() {
      _exercises = library.exercises;
      _loading = false;
    });
  }

  Future<ExerciseHistory> _getHistory(String exerciseId) async {
    if (_historyCache.containsKey(exerciseId)) {
      return _historyCache[exerciseId]!;
    }
    final history =
        await WorkoutRepository.instance.getExerciseHistory(exerciseId);
    _historyCache[exerciseId] = history;
    return history;
  }

  List<Exercise> get _filtered {
    return _exercises.where((e) {
      final matchesCategory =
          _filterCategory == null || e.category == _filterCategory;
      final matchesSearch = _search.isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Exercise'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add exercise',
            onPressed: () => _showAddExerciseSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchBar(onChanged: (v) => setState(() => _search = v)),
          _CategoryFilter(
            selected: _filterCategory,
            onSelected: (c) => setState(() => _filterCategory = c),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const _EmptySearch()
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final ex = _filtered[i];
                          return _ExerciseRow(
                            exercise: ex,
                            historyFuture: _getHistory(ex.id),
                            onTap: () => Navigator.pop(context, ex),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddExerciseSheet(BuildContext context) async {
    // TODO: add exercise form
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add exercise coming soon')),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        autofocus: true,
        onChanged: onChanged,
        decoration: const InputDecoration(
          hintText: 'Search exercises…',
          prefixIcon: Icon(Icons.search, size: 20),
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final MuscleCategory? selected;
  final ValueChanged<MuscleCategory?> onSelected;
  const _CategoryFilter({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final categories = MuscleCategory.values;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          ...categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(titleCase(cat.name)),
                  selected: selected == cat,
                  onSelected: (_) =>
                      onSelected(selected == cat ? null : cat),
                ),
              )),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final Future<ExerciseHistory> historyFuture;
  final VoidCallback onTap;

  const _ExerciseRow({
    required this.exercise,
    required this.historyFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  FutureBuilder<ExerciseHistory>(
                    future: historyFuture,
                    builder: (ctx, snap) {
                      if (!snap.hasData) {
                        return Text('—',
                            style: Theme.of(context).textTheme.bodySmall);
                      }
                      return _HistoryLine(
                          exercise: exercise, history: snap.data!);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CategoryBadge(category: exercise.category),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: kOnSurfaceDim, size: 20),
          ],
        ),
      ),
    );
  }
}

class _HistoryLine extends StatelessWidget {
  final Exercise exercise;
  final ExerciseHistory history;

  const _HistoryLine({required this.exercise, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Text('Never done', style: Theme.of(context).textTheme.bodySmall);
    }

    final parts = <String>[];

    final last = history.lastOccurrence;
    if (last != null && last.sets.isNotEmpty) {
      parts.add('Last: ${last.sets.first.summary}');
    }

    switch (exercise.type) {
      case ExerciseType.weighted:
        final pr = history.bestWeightSet;
        if (pr != null) parts.add('PR: ${formatWeight(pr.weightLbs)}');
        break;
      case ExerciseType.bodweightPlus:
        final pr = history.bestAddedWeightSet;
        if (pr != null && (pr.addedWeightLbs ?? 0) > 0) {
          parts.add('PR: +${formatWeight(pr.addedWeightLbs)}');
        }
        break;
      case ExerciseType.cardio:
        final best = history.bestDistanceSet;
        if (best != null) {
          final km = (best.distanceMeters ?? 0) / 1000;
          parts.add('Best: ${km.toStringAsFixed(2)} km');
        }
        break;
      case ExerciseType.bodyweight:
        final pr = history.bestRepSet;
        if (pr != null) parts.add('PR: ${pr.reps} reps');
        break;
    }

    return Text(
      parts.join('  ·  '),
      style: Theme.of(context).textTheme.bodySmall,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final MuscleCategory category;
  const _CategoryBadge({required this.category});

  Color get _color => switch (category) {
        MuscleCategory.push => const Color(0xFF3A6BC9),
        MuscleCategory.pull => const Color(0xFF7B52C9),
        MuscleCategory.legs => const Color(0xFF2E9E6B),
        MuscleCategory.core => const Color(0xFFB07A2A),
        MuscleCategory.cardio => const Color(0xFFB84040),
        MuscleCategory.full => const Color(0xFF4A8A9E),
        MuscleCategory.other => const Color(0xFF555860),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _color.withOpacity(0.5)),
      ),
      child: Text(
        category.name.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 40, color: kOnSurfaceDim),
          const SizedBox(height: 12),
          Text('No exercises found',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('Tap + to add a new one',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
