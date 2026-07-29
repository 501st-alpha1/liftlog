import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../models/exercise_history.dart';
import '../repositories/workout_repository.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';

class ExercisePickerScreen extends StatefulWidget {
  /// If provided, pre-selects this category filter and pre-loads history
  /// sorted by least-recently-done. The user can still change the filter.
  final MuscleCategory? initialCategory;

  const ExercisePickerScreen({super.key, this.initialCategory});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  List<Exercise> _exercises = [];
  Map<String, ExerciseHistory> _historyCache = {};
  MuscleCategory? _filterCategory;
  String _search = '';
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _filterCategory = widget.initialCategory;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final library = await WorkoutRepository.instance.loadExerciseLibrary();
      // Eagerly load history for all exercises so we can sort by
      // last-occurrence date synchronously in _filtered.
      final histories = await Future.wait(
        library.exercises.map((e) =>
            WorkoutRepository.instance.getExerciseHistory(e.id)),
      );
      if (!mounted) return;
      final cache = <String, ExerciseHistory>{};
      for (var i = 0; i < library.exercises.length; i++) {
        cache[library.exercises[i].id] = histories[i];
      }
      setState(() {
        _exercises = library.exercises;
        _historyCache = cache;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loading = false;
      });
    }
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
    final results = _exercises.where((e) {
      final matchesCategory =
          _filterCategory == null || e.category == _filterCategory;
      final matchesSearch = _search.isEmpty ||
          e.name.toLowerCase().contains(_search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    // When a category filter is active (either user-selected or from the
    // session's split), sort by last-occurrence date ascending so the
    // exercises done least recently (or never) float to the top. This acts
    // as a soft suggestion: "you haven't done these in a while."
    // When showing all categories or searching, keep library order.
    if (_filterCategory != null && _search.isEmpty) {
      results.sort((a, b) {
        final aDate = _historyCache[a.id]?.lastOccurrence?.date;
        final bDate = _historyCache[b.id]?.lastOccurrence?.date;
        // Never done sorts before any dated occurrence
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;
        return aDate.compareTo(bDate); // ascending: oldest first
      });
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_filterCategory != null && _search.isEmpty
            ? '${titleCase(_filterCategory!.name)} exercises'
            : 'Choose Exercise'),
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
                : _loadError != null
                    ? _LoadErrorState(error: _loadError!, onRetry: _load)
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
                                onLongPress: () => _editExercise(context, ex),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _editExercise(BuildContext context, Exercise exercise) async {
    final updated = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditWeightModeSheet(exercise: exercise),
    );
    if (updated == null || !mounted) return;
    final library = await WorkoutRepository.instance.loadExerciseLibrary();
    final exercises = library.exercises
        .map((e) => e.id == updated.id ? updated : e)
        .toList();
    await WorkoutRepository.instance
        .saveExerciseLibrary(library.copyWith(exercises: exercises));
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${updated.name} updated')),
      );
    }
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
  final VoidCallback onLongPress;

  const _ExerciseRow({
    required this.exercise,
    required this.historyFuture,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
      parts.add('Last: ${last.sets.first.summaryFor(exercise)}');
    }

    final pr = history.prLabel(exercise);
    if (pr != null) parts.add(pr);

    return Text(
      parts.join('  \u00b7  '),
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

class _LoadErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _LoadErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 44, color: kDestructive),
            const SizedBox(height: 16),
            Text(
              "Couldn't load exercise library",
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
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
  final _restCtrl = TextEditingController(text: '120');

  MuscleCategory _category = MuscleCategory.push;
  ExerciseType _type = ExerciseType.weighted;
  WeightMode _weightMode = WeightMode.total;
  String? _equipment;

  @override
  void dispose() {
    _nameCtrl.dispose();
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

    final exercise = Exercise(
      id: id,
      name: name,
      category: _category,
      type: _type,
      weightMode: _type == ExerciseType.cardio ? WeightMode.total : _weightMode,
      equipment: _equipment,
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
                    onChanged: (v) => setState(() {
                      _type = v!;
                      // Cardio doesn't use weight modes; reset to default
                      if (_type == ExerciseType.cardio) {
                        _weightMode = WeightMode.total;
                      }
                    }),
                    title: Text(opt.$2,
                        style: Theme.of(context).textTheme.bodyMedium),
                    subtitle: Text(opt.$3,
                        style: Theme.of(context).textTheme.bodySmall),
                    activeColor: kAccent,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              const SizedBox(height: 16),

              // Weight mode (not shown for cardio)
              if (_type != ExerciseType.cardio) ...[
                const _Label('Weight Mode'),
                const SizedBox(height: 8),
                ..._weightModeOptions.map((opt) => RadioListTile<WeightMode>(
                      value: opt.$1,
                      groupValue: _weightMode,
                      onChanged: (v) => setState(() => _weightMode = v!),
                      title: Text(opt.$2,
                          style: Theme.of(context).textTheme.bodyMedium),
                      subtitle: Text(opt.$3,
                          style: Theme.of(context).textTheme.bodySmall),
                      activeColor: kAccent,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    )),
                const SizedBox(height: 16),
              ],

              // Equipment
              const _Label('Equipment'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _equipmentOptions.map((eq) {
                  final selected = _equipment == eq;
                  return ChoiceChip(
                    label: Text(eq == 'none' ? 'None' : titleCase(eq)),
                    selected: selected,
                    onSelected: (_) => setState(() =>
                        _equipment = selected ? null : eq),
                  );
                }).toList(),
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

const _equipmentOptions = ['barbell', 'dumbbell', 'machine', 'none'];

const _typeOptions = [
  (
    ExerciseType.weighted,
    'Weighted',
    'Tracks weight (lbs) + reps — barbell, dumbbell, machine',
  ),
  (
    ExerciseType.bodyweight,
    'Bodyweight',
    'Tracks reps, optionally \u00b1 weight — push-ups, weighted dips, assisted pull-ups',
  ),
  (
    ExerciseType.cardio,
    'Cardio',
    'Tracks duration and/or distance — running, rowing',
  ),
];

const _weightModeOptions = [
  (
    WeightMode.total,
    'Total weight',
    'One weight for the whole set — e.g. "185 lbs \u00d7 5"',
  ),
  (
    WeightMode.perSide,
    'Per side (ea)',
    'Each limb works independently — e.g. "30 lbs ea \u00d7 14" (dumbbells, split machines)',
  ),
  (
    WeightMode.perPart,
    'Per part (reps ea)',
    'One weight, reps counted per side — e.g. "20 lbs \u00d7 14 ea" (compound curl machines)',
  ),
  (
    WeightMode.timedReps,
    'Timed reps (sec)',
    'Reps field is seconds — e.g. "0 lbs \u00d7 10 sec" (bar hangs, loaded planks)',
  ),
];

// ── Edit Weight Mode Sheet ────────────────────────────────────────────────────
// Opened by long-pressing an existing exercise. Only exposes weight mode
// for now since that's the field most likely to need updating after creation.
// Shows a warning that changing it affects how all historical sets display.

class _EditWeightModeSheet extends StatefulWidget {
  final Exercise exercise;
  const _EditWeightModeSheet({required this.exercise});

  @override
  State<_EditWeightModeSheet> createState() => _EditWeightModeSheetState();
}

class _EditWeightModeSheetState extends State<_EditWeightModeSheet> {
  late WeightMode _weightMode;

  @override
  void initState() {
    super.initState();
    _weightMode = widget.exercise.weightMode;
  }

  bool get _changed => _weightMode != widget.exercise.weightMode;

  void _submit() {
    Navigator.pop(context, widget.exercise.copyWith(weightMode: _weightMode));
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
              Text(widget.exercise.name,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Long press to edit weight mode',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),

              // Warning banner (shown when a change is pending)
              if (_changed)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kDestructive.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kDestructive.withOpacity(0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: kDestructive, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Changing weight mode affects how all past sets '
                          'for this exercise are displayed. The numbers '
                          'themselves are unchanged.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: kDestructive),
                        ),
                      ),
                    ],
                  ),
                ),

              const _Label('Weight Mode'),
              const SizedBox(height: 8),
              ..._weightModeOptions.map((opt) => RadioListTile<WeightMode>(
                    value: opt.$1,
                    groupValue: _weightMode,
                    onChanged: widget.exercise.type == ExerciseType.cardio
                        ? null
                        : (v) => setState(() => _weightMode = v!),
                    title: Text(opt.$2,
                        style: Theme.of(context).textTheme.bodyMedium),
                    subtitle: Text(opt.$3,
                        style: Theme.of(context).textTheme.bodySmall),
                    activeColor: kAccent,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _changed ? _submit : null,
                child: const Text('Save'),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}
