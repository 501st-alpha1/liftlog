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
    final exercise = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _AddExerciseSheet(),
    );
    if (exercise == null) return;
    await WorkoutRepository.instance.addExercise(exercise);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${exercise.name} added')),
      );
    }
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
      case ExerciseType.bodyweight:
        final addedPr = history.bestAddedWeightSet;
        if (addedPr != null && (addedPr.addedWeightLbs ?? 0) != 0) {
          final w = addedPr.addedWeightLbs!;
          parts.add(w > 0
              ? 'PR: +${formatWeight(w)}'
              : 'Best assist: ${formatWeight(w)}');
        } else {
          final repPr = history.bestRepSet;
          if (repPr != null) parts.add('PR: ${repPr.reps} reps');
        }
        break;
      case ExerciseType.cardio:
        final best = history.bestDistanceSet;
        if (best != null) {
          final km = (best.distanceMeters ?? 0) / 1000;
          parts.add('Best: ${km.toStringAsFixed(2)} km');
        }
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

// ── Add Exercise Sheet ────────────────────────────────────────────────────────

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet();

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _nameCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  final _restCtrl = TextEditingController(text: '120');

  MuscleCategory _category = MuscleCategory.push;
  ExerciseType _type = ExerciseType.weighted;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _equipmentCtrl.dispose();
    _restCtrl.dispose();
    super.dispose();
  }

  String _generateId(String name) {
    return name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an exercise name')),
      );
      return;
    }
    final id = _generateId(name);
    final rest = int.tryParse(_restCtrl.text.trim()) ?? 120;
    final equipment = _equipmentCtrl.text.trim();

    final exercise = Exercise(
      id: id,
      name: name,
      category: _category,
      type: _type,
      equipment: equipment.isEmpty ? null : equipment,
      defaultRestSeconds: rest,
    );
    Navigator.pop(context, exercise);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Exercise',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),

              // Name
              const _Label('Exercise Name'),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'e.g. Incline Dumbbell Press',
                ),
              ),
              const SizedBox(height: 16),

              // Category
              const _Label('Muscle Group'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MuscleCategory.values.map((cat) {
                  final selected = _category == cat;
                  return ChoiceChip(
                    label: Text(titleCase(cat.name)),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Type
              const _Label('Exercise Type'),
              const SizedBox(height: 8),
              ..._typeOptions.map((opt) => RadioListTile<ExerciseType>(
                    value: opt.$1,
                    groupValue: _type,
                    onChanged: (v) => setState(() => _type = v!),
                    title: Text(opt.$2,
                        style: Theme.of(context).textTheme.bodyMedium),
                    subtitle: Text(opt.$3,
                        style: Theme.of(context).textTheme.bodySmall),
                    activeColor: kAccent,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              const SizedBox(height: 16),

              // Equipment
              const _Label('Equipment (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _equipmentCtrl,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  hintText: 'e.g. barbell, dumbbell, cable…',
                ),
              ),
              const SizedBox(height: 16),

              // Default rest
              const _Label('Default Rest (seconds)'),
              const SizedBox(height: 6),
              TextField(
                controller: _restCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '120'),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _submit,
                child: const Text('Add Exercise'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _typeOptions = [
  (
    ExerciseType.weighted,
    'Weighted',
    'Tracks weight (lbs) + reps — barbell, dumbbell, machine',
  ),
  (
    ExerciseType.bodyweight,
    'Bodyweight',
    'Tracks reps, optionally ± weight — push-ups, weighted dips, assisted pull-ups',
  ),
  (
    ExerciseType.cardio,
    'Cardio',
    'Tracks duration and/or distance — running, rowing',
  ),
];

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}
