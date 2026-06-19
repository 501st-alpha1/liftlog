import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/exercise.dart';
import '../models/exercise_history.dart';
import '../models/session.dart';
import '../models/workout_set.dart';
import '../repositories/workout_repository.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import 'exercise_picker_screen.dart';

class LogWorkoutScreen extends StatefulWidget {
  final WorkoutSession session;
  const LogWorkoutScreen({super.key, required this.session});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  late WorkoutSession _session;
  Map<String, Exercise> _exerciseMap = {};
  Map<String, ExerciseHistory> _historyCache = {};
  bool _saving = false;

  // Rest timer state
  Timer? _restTimer;
  int _restRemaining = 0;
  bool _restActive = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadExercises();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final library = await WorkoutRepository.instance.loadExerciseLibrary();
    if (!mounted) return;
    setState(() {
      _exerciseMap = {for (final e in library.exercises) e.id: e};
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

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = _session.copyWith(endedAt: nowIso());
    await WorkoutRepository.instance.saveSession(saved);
    setState(() {
      _session = saved;
      _saving = false;
    });
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null || !mounted) return;
    final entry = ExerciseEntry(
      exerciseId: exercise.id,
      order: _session.exercises.length + 1,
      sets: const [],
    );
    setState(() {
      _session = _session.copyWith(
        exercises: [..._session.exercises, entry],
      );
    });
    await WorkoutRepository.instance.saveSession(_session);
  }

  void _addSet(int exerciseIndex) {
    final entry = _session.exercises[exerciseIndex];
    final exercise = _exerciseMap[entry.exerciseId];
    final prevSet = entry.sets.isNotEmpty ? entry.sets.last : null;

    // Pre-fill with previous set values
    final newSet = WorkoutSet(
      setNumber: entry.sets.length + 1,
      weightLbs: prevSet?.weightLbs,
      addedWeightLbs: prevSet?.addedWeightLbs,
      reps: prevSet?.reps,
      durationSeconds: prevSet?.durationSeconds,
      distanceMeters: prevSet?.distanceMeters,
      restAfterSeconds:
          exercise?.defaultRestSeconds ?? prevSet?.restAfterSeconds,
    );

    _showSetEditor(exerciseIndex, newSet, isNew: true);
  }

  void _editSet(int exerciseIndex, int setIndex) {
    final set = _session.exercises[exerciseIndex].sets[setIndex];
    _showSetEditor(exerciseIndex, set, isNew: false, setIndex: setIndex);
  }

  void _showSetEditor(int exerciseIndex, WorkoutSet set,
      {required bool isNew, int? setIndex}) {
    final entry = _session.exercises[exerciseIndex];
    final exercise = _exerciseMap[entry.exerciseId];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SetEditorSheet(
        set: set,
        exercise: exercise,
        historyFuture: _getHistory(entry.exerciseId),
        onSave: (updated) async {
          final sets = [...entry.sets];
          if (isNew) {
            sets.add(updated);
          } else {
            sets[setIndex!] = updated;
          }
          final entries = [..._session.exercises];
          entries[exerciseIndex] = entry.copyWith(sets: sets);
          setState(() {
            _session = _session.copyWith(exercises: entries);
          });
          await WorkoutRepository.instance.saveSession(_session);

          // Start rest timer if rest set
          if (updated.restAfterSeconds != null &&
              updated.restAfterSeconds! > 0) {
            _startRestTimer(updated.restAfterSeconds!);
          }
        },
        onDelete: isNew
            ? null
            : () async {
                final sets = [...entry.sets];
                sets.removeAt(setIndex!);
                // Renumber
                final renumbered = sets
                    .asMap()
                    .entries
                    .map((e) => e.value.copyWith(setNumber: e.key + 1))
                    .toList();
                final entries = [..._session.exercises];
                entries[exerciseIndex] = entry.copyWith(sets: renumbered);
                setState(() {
                  _session = _session.copyWith(exercises: entries);
                });
                await WorkoutRepository.instance.saveSession(_session);
              },
      ),
    );
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restRemaining = seconds;
      _restActive = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _restRemaining--;
        if (_restRemaining <= 0) {
          _restActive = false;
          t.cancel();
          HapticFeedback.heavyImpact();
        }
      });
    });
  }

  void _dismissRestTimer() {
    _restTimer?.cancel();
    setState(() => _restActive = false);
  }

  Future<void> _finishWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Finish workout?'),
        content: Text(
          '${_session.exercises.length} exercise(s), '
          '${_session.exercises.fold(0, (s, e) => s + e.sets.length)} set(s) logged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await _save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${titleCase(_session.split)} — ${formatShortDate(_session.date)}'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _finishWorkout,
              child: const Text('Finish'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_restActive) _RestBanner(
            remaining: _restRemaining,
            onDismiss: _dismissRestTimer,
          ),
          Expanded(
            child: _session.exercises.isEmpty
                ? _EmptyExerciseState(onAdd: _addExercise)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _session.exercises.length,
                    itemBuilder: (_, i) {
                      final entry = _session.exercises[i];
                      final exercise = _exerciseMap[entry.exerciseId];
                      return _ExerciseCard(
                        entry: entry,
                        exercise: exercise,
                        historyFuture: _getHistory(entry.exerciseId),
                        onAddSet: () => _addSet(i),
                        onEditSet: (si) => _editSet(i, si),
                        onNotesChanged: (notes) async {
                          final entries = [..._session.exercises];
                          entries[i] = entry.copyWith(
                            notes: notes,
                            clearNotes: notes == null,
                          );
                          setState(() {
                            _session = _session.copyWith(exercises: entries);
                          });
                          await WorkoutRepository.instance.saveSession(_session);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Add Exercise'),
        backgroundColor: kAccent,
        foregroundColor: const Color(0xFF1A1000),
      ),
    );
  }
}

// ── Rest Timer Banner ─────────────────────────────────────────────────────────

class _RestBanner extends StatelessWidget {
  final int remaining;
  final VoidCallback onDismiss;
  const _RestBanner({required this.remaining, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final isWarning = remaining <= 10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isWarning ? kDestructive.withOpacity(0.15) : kAccentDim.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.timer,
            color: isWarning ? kDestructive : kAccent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            'Rest: ${formatDuration(remaining)}',
            style: TextStyle(
              color: isWarning ? kDestructive : kAccent,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: kOnSurfaceDim, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Exercise Card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final ExerciseEntry entry;
  final Exercise? exercise;
  final Future<ExerciseHistory> historyFuture;
  final VoidCallback onAddSet;
  final ValueChanged<int> onEditSet;
  final ValueChanged<String?> onNotesChanged;

  const _ExerciseCard({
    required this.entry,
    required this.exercise,
    required this.historyFuture,
    required this.onAddSet,
    required this.onEditSet,
    required this.onNotesChanged,
  });

  Future<void> _editNotes(BuildContext context) async {
    final ctrl = TextEditingController(text: entry.notes ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: Text(exercise?.name ?? entry.exerciseId,
            style: Theme.of(ctx).textTheme.titleMedium),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Form cues, RPE, how it felt…',
          ),
        ),
        actions: [
          if (entry.notes != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              style: TextButton.styleFrom(foregroundColor: kDestructive),
              child: const Text('Clear'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return; // cancelled
    onNotesChanged(result.isEmpty ? null : result);
  }

  @override
  Widget build(BuildContext context) {
    final name = exercise?.name ?? entry.exerciseId;
    final hasNotes = entry.notes != null && entry.notes!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exercise name + notes button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  GestureDetector(
                    onTap: () => _editNotes(context),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        hasNotes ? Icons.notes : Icons.add_comment_outlined,
                        size: 18,
                        color: hasNotes ? kAccent : kOnSurfaceDim,
                      ),
                    ),
                  ),
                ],
              ),

              // Exercise notes (if set)
              if (hasNotes) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _editNotes(context),
                  child: Text(
                    entry.notes!,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          fontStyle: FontStyle.italic,
                          color: kOnSurfaceDim,
                        ),
                  ),
                ),
              ],

              // History hint
              const SizedBox(height: 4),
              FutureBuilder<ExerciseHistory>(
                future: historyFuture,
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final hist = snap.data!;
                  final last = hist.lastOccurrence;
                  final parts = <String>[];
                  if (last != null) {
                    parts.add('Last ${formatShortDate(last.date)}: '
                        '${last.sets.map((s) => s.summary).join(', ')}');
                  }
                  if (exercise?.type == ExerciseType.weighted) {
                    final pr = hist.bestWeightSet;
                    if (pr != null) parts.add('PR ${formatWeight(pr.weightLbs)}');
                  }
                  return Text(
                    parts.join('   ·   '),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: kAccent.withOpacity(0.8)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),

              if (entry.sets.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Set rows
                ...entry.sets.asMap().entries.map((e) => _SetRow(
                      set: e.value,
                      onTap: () => onEditSet(e.key),
                    )),
              ],

              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Set'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: kSurfaceVariant,
                  foregroundColor: kOnSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final WorkoutSet set;
  final VoidCallback onTap;
  const _SetRow({required this.set, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${set.setNumber}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Expanded(
              child: Text(set.summary,
                  style: Theme.of(context).textTheme.bodyLarge),
            ),
            if (set.notes != null)
              Icon(Icons.note_outlined, size: 14, color: kOnSurfaceDim),
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 14, color: kOnSurfaceDim),
          ],
        ),
      ),
    );
  }
}

// ── Set Editor Sheet ──────────────────────────────────────────────────────────

class _SetEditorSheet extends StatefulWidget {
  final WorkoutSet set;
  final Exercise? exercise;
  final Future<ExerciseHistory> historyFuture;
  final Future<void> Function(WorkoutSet) onSave;
  final Future<void> Function()? onDelete;

  const _SetEditorSheet({
    required this.set,
    required this.exercise,
    required this.historyFuture,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_SetEditorSheet> createState() => _SetEditorSheetState();
}

class _SetEditorSheetState extends State<_SetEditorSheet> {
  late TextEditingController _weightCtrl;
  late TextEditingController _repsCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _distanceCtrl;
  late TextEditingController _restCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.set;
    _weightCtrl = TextEditingController(
        text: s.weightLbs?.toString() ?? s.addedWeightLbs?.toString() ?? '');
    _repsCtrl =
        TextEditingController(text: s.reps?.toString() ?? '');
    _durationCtrl =
        TextEditingController(text: s.durationSeconds?.toString() ?? '');
    _distanceCtrl =
        TextEditingController(text: s.distanceMeters?.toString() ?? '');
    _restCtrl =
        TextEditingController(text: s.restAfterSeconds?.toString() ?? '');
    _notesCtrl = TextEditingController(text: s.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _weightCtrl, _repsCtrl, _durationCtrl,
      _distanceCtrl, _restCtrl, _notesCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  WorkoutSet _buildSet() {
    final type = widget.exercise?.type ?? ExerciseType.weighted;
    final weight = double.tryParse(_weightCtrl.text);
    final reps = int.tryParse(_repsCtrl.text);
    final duration = int.tryParse(_durationCtrl.text);
    final distance = double.tryParse(_distanceCtrl.text);
    final rest = int.tryParse(_restCtrl.text);
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    return WorkoutSet(
      setNumber: widget.set.setNumber,
      weightLbs: type == ExerciseType.weighted ? weight : null,
      addedWeightLbs: type == ExerciseType.bodweightPlus ? weight : null,
      reps: (type != ExerciseType.cardio) ? reps : null,
      durationSeconds: duration,
      distanceMeters: distance,
      restAfterSeconds: rest,
      notes: notes,
    );
  }

  Future<void> _save() async {
    await widget.onSave(_buildSet());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.exercise?.type ?? ExerciseType.weighted;
    final isCardio = type == ExerciseType.cardio;
    final isBodyweightPlus = type == ExerciseType.bodweightPlus;
    final isBodyweight = type == ExerciseType.bodyweight;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    widget.exercise?.name ?? 'Set ${widget.set.setNumber}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: kDestructive, size: 20),
                      onPressed: () async {
                        await widget.onDelete!();
                        if (mounted) Navigator.pop(context);
                      },
                    ),
                ],
              ),

              // History hint
              FutureBuilder<ExerciseHistory>(
                future: widget.historyFuture,
                builder: (ctx, snap) {
                  if (!snap.hasData || snap.data!.isEmpty) {
                    return const SizedBox(height: 12);
                  }
                  final h = snap.data!;
                  final lastOcc = h.lastOccurrence;
                  if (lastOcc == null) return const SizedBox(height: 12);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 4),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kAccentDim.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: kAccentDim.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last (${formatShortDate(lastOcc.date)})',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          ...lastOcc.sets.map((s) => Text(
                                'Set ${s.setNumber}: ${s.summary}',
                                style: Theme.of(context).textTheme.bodySmall,
                              )),
                          if (type == ExerciseType.weighted &&
                              h.bestWeightSet != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'PR: ${h.bestWeightSet!.summary}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(color: kAccent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 8),

              // Weight field (weighted + bodyweight_plus)
              if (!isBodyweight && !isCardio) ...[
                _FieldLabel(
                  isBodyweightPlus
                      ? 'Added Weight (lbs, 0 = bodyweight)'
                      : 'Weight (lbs)',
                ),
                const SizedBox(height: 6),
                _NumField(
                  controller: _weightCtrl,
                  hintText: '135',
                  decimal: true,
                ),
                const SizedBox(height: 14),
              ],

              // Reps
              if (!isCardio) ...[
                const _FieldLabel('Reps'),
                const SizedBox(height: 6),
                _NumField(controller: _repsCtrl, hintText: '5'),
                const SizedBox(height: 14),
              ],

              // Duration (cardio + optional for others)
              if (isCardio) ...[
                const _FieldLabel('Duration (seconds)'),
                const SizedBox(height: 6),
                _NumField(controller: _durationCtrl, hintText: '600'),
                const SizedBox(height: 14),
                const _FieldLabel('Distance (meters, optional)'),
                const SizedBox(height: 6),
                _NumField(
                    controller: _distanceCtrl,
                    hintText: '1000',
                    decimal: true),
                const SizedBox(height: 14),
              ],

              // Rest
              const _FieldLabel('Rest after (seconds)'),
              const SizedBox(height: 6),
              _NumField(controller: _restCtrl, hintText: '180'),
              const SizedBox(height: 14),

              // Notes
              const _FieldLabel('Notes (optional)'),
              const SizedBox(height: 6),
              TextField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(hintText: 'Form cues, RPE…'),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _save,
                child: Text(
                  widget.onDelete == null ? 'Log Set' : 'Save',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool decimal;

  const _NumField({
    required this.controller,
    required this.hintText,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'^\d*'),
        ),
      ],
      decoration: InputDecoration(hintText: hintText),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: kOnBackground,
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyExerciseState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyExerciseState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_circle_outline, size: 52, color: kOnSurfaceDim),
            const SizedBox(height: 16),
            Text('No exercises yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Tap Add Exercise to get started.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
