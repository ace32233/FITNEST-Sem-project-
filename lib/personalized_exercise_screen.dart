import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'dart:typed_data';
import '/services/exercise_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- CONSTANTS ---
const Color kDarkTeal = Color(0xFF132F38);
const Color kDarkSlate = Color(0xFF0F172A);
const Color kGlassBorder = Color(0x1AFFFFFF);
const Color kCardSurface = Color(0xFF1E293B);
const Color kAccentCyan = Color(0xFF22D3EE);
const Color kAccentBlue = Color(0xFF3B82F6);
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

// --- MODELS ---

class UserProfile {
  final int age;
  final double weightKg;
  final double heightCm;
  final String gender;

  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.gender,
  });

  // Exact Logic from Profile Page
  double get bmi {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final hM = heightCm / 100.0;
    return weightKg / (hM * hM);
  }
}

class Exercise {
  final String id;
  final String name;
  final String bodyPart;
  final String target;
  final String equipment;
  final String gifUrl;

  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.target,
    required this.equipment,
    required this.gifUrl,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    String pickStr(List<String> keys, {String fallback = ''}) {
      for (final k in keys) {
        final v = json[k];
        if (v != null) return v.toString();
      }
      return fallback;
    }

    String rawGif = pickStr(['gifUrl', 'gif_url'], fallback: '').trim();
    if (rawGif.startsWith('http://')) {
      rawGif = rawGif.replaceFirst('http://', 'https://');
    }

    return Exercise(
      id: pickStr(['id', 'uuid', 'exerciseId'], fallback: '').trim(),
      name: pickStr(['name'], fallback: '').trim(),
      bodyPart: pickStr(['bodyPart', 'body_part'], fallback: '').trim(),
      target: pickStr(['target'], fallback: '').trim(),
      equipment: pickStr(['equipment'], fallback: '').trim(),
      gifUrl: rawGif,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bodyPart': bodyPart,
        'target': target,
        'equipment': equipment,
        'gifUrl': gifUrl,
      };
}

// --- HELPER FUNCTIONS ---

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double _asDouble(dynamic v) {
  if (v == null) return 0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _todayDateKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

String levelFromBmiAndAge({required double bmi, required int age}) {
  if (bmi < 18.5) return 'Beginner';
  if (bmi < 25) return age < 30 ? 'Intermediate' : 'Beginner';
  if (bmi < 30) return 'Intermediate';
  return 'Beginner';
}

// --- PROVIDERS ---

final userProfileProvider = StreamProvider.autoDispose<UserProfile>((ref) async* {
  while (true) {
    final prefs = await SharedPreferences.getInstance();
    
    final ageStr = prefs.getString('profile_age') ?? '25';
    final heightStr = prefs.getString('profile_height') ?? '175';
    final weightStr = prefs.getString('profile_weight') ?? '70';
    final gender = prefs.getString('profile_gender') ?? 'Male';

    final age = int.tryParse(ageStr) ?? 25;
    final height = double.tryParse(heightStr) ?? 175.0;
    final weight = double.tryParse(weightStr) ?? 70.0;

    yield UserProfile(
      age: age,
      weightKg: weight,
      heightCm: height,
      gender: gender,
    );

    await Future.delayed(const Duration(seconds: 1));
  }
});

final personalizedLevelProvider = Provider<String>((ref) {
  final p = ref.watch(userProfileProvider).valueOrNull;
  if (p == null) return 'Beginner';
  return levelFromBmiAndAge(bmi: p.bmi, age: p.age);
});

enum MuscleGroup { back, chest, legs, arms, cardio, core }

extension MuscleGroupX on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.back: return 'Back';
      case MuscleGroup.chest: return 'Chest';
      case MuscleGroup.legs: return 'Legs';
      case MuscleGroup.arms: return 'Arms';
      case MuscleGroup.cardio: return 'Cardio';
      case MuscleGroup.core: return 'Core';
    }
  }
}

const Map<MuscleGroup, List<String>> groupToBodyParts = {
  MuscleGroup.back: ['back'],
  MuscleGroup.chest: ['chest'],
  MuscleGroup.legs: ['upper legs', 'lower legs'],
  MuscleGroup.arms: ['upper arms', 'lower arms'],
  MuscleGroup.cardio: ['cardio'],
  MuscleGroup.core: ['waist'],
};

final selectedGroupProvider = StateProvider<MuscleGroup?>((ref) => null);

Future<List<Exercise>> _fetchExercisesForBodyPart(String bodyPart) async {
  final list = await ExerciseService.fetchExercisesForBodyPart(bodyPart);
  return list
      .map((m) => Exercise.fromJson(m))
      .where((e) => e.name.trim().isNotEmpty && e.id.trim().isNotEmpty)
      .toList();
}

final exercisesForGroupProvider = FutureProvider.autoDispose<List<Exercise>>((ref) async {
  final group = ref.watch(selectedGroupProvider);
  if (group == null) return const [];

  final parts = groupToBodyParts[group] ?? const [];
  if (parts.isEmpty) return const [];

  final futures = parts.map(_fetchExercisesForBodyPart).toList();
  final lists = await Future.wait(futures);

  final merged = <Exercise>[];
  for (final l in lists) merged.addAll(l);

  final seen = <String>{};
  final unique = <Exercise>[];
  for (final ex in merged) {
    final key = ex.id.isNotEmpty
        ? ex.id
        : '${ex.name}_${ex.bodyPart}_${ex.target}_${ex.equipment}';
    if (seen.add(key)) unique.add(ex);
  }

  if (unique.length > 80) return unique.sublist(0, 80);
  return unique;
});

// History & Logic
class WorkoutHistory {
  final String date;
  final bool completed;
  final int durationMinutes;
  final String muscleGroup;
  final List<String> exerciseIds;

  const WorkoutHistory({
    required this.date,
    required this.completed,
    required this.durationMinutes,
    required this.muscleGroup,
    required this.exerciseIds,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'completed': completed,
        'durationMinutes': durationMinutes,
        'muscleGroup': muscleGroup,
        'exerciseIds': exerciseIds,
      };

  factory WorkoutHistory.fromJson(Map<String, dynamic> json) {
    return WorkoutHistory(
      date: (json['date'] ?? '').toString(),
      completed: (json['completed'] ?? false) == true,
      durationMinutes: _asInt(json['durationMinutes']),
      muscleGroup: (json['muscleGroup'] ?? '').toString(),
      exerciseIds: (json['exerciseIds'] is List)
          ? (json['exerciseIds'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class HistoryRepo {
  static const _prefsKey = 'workout_history_by_date';

  Future<WorkoutHistory?> getToday() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;

    final decoded = json.decode(raw);
    if (decoded is! Map) return null;

    final today = _todayDateKey();
    final entry = decoded[today];
    if (entry is Map<String, dynamic>) return WorkoutHistory.fromJson(entry);
    return null;
  }

  Future<void> save(WorkoutHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    Map<String, dynamic> map = {};
    if (raw != null) {
      final decoded = json.decode(raw);
      if (decoded is Map) map = Map<String, dynamic>.from(decoded);
    }

    map[history.date] = history.toJson();
    await prefs.setString(_prefsKey, json.encode(map));
  }
}

final historyRepoProvider = Provider<HistoryRepo>((ref) => HistoryRepo());
final todayHistoryProvider = FutureProvider.autoDispose<WorkoutHistory?>((ref) async {
  return ref.read(historyRepoProvider).getToday();
});

@immutable
class WorkoutState {
  final List<Exercise> workout;
  final int index;
  final Set<String> completedIds;
  final DateTime? startedAt;
  final MuscleGroup? muscleGroup;

  const WorkoutState({
    required this.workout,
    required this.index,
    required this.completedIds,
    required this.startedAt,
    required this.muscleGroup,
  });

  bool get hasWorkout => workout.isNotEmpty;
  bool get isFinished => hasWorkout && completedIds.length >= workout.length;
  int get total => workout.length;
  int get done => completedIds.length;

  Exercise? get current {
    if (!hasWorkout) return null;
    final safe = index.clamp(0, workout.length - 1);
    return workout[safe];
  }

  WorkoutState copyWith({
    List<Exercise>? workout,
    int? index,
    Set<String>? completedIds,
    DateTime? startedAt,
    MuscleGroup? muscleGroup,
  }) {
    return WorkoutState(
      workout: workout ?? this.workout,
      index: index ?? this.index,
      completedIds: completedIds ?? this.completedIds,
      startedAt: startedAt ?? this.startedAt,
      muscleGroup: muscleGroup ?? this.muscleGroup,
    );
  }

  static WorkoutState empty() => const WorkoutState(
        workout: [],
        index: 0,
        completedIds: {},
        startedAt: null,
        muscleGroup: null,
      );
}

class WorkoutController extends StateNotifier<WorkoutState> {
  WorkoutController(this._ref) : super(WorkoutState.empty());
  final Ref _ref;
  bool _isSaving = false;

  void reset() {
    state = WorkoutState.empty();
    _isSaving = false;
  }

  void startFromSource(List<Exercise> source, {required MuscleGroup group}) {
    if (source.length < 3) {
      state = WorkoutState.empty();
      return;
    }
    final maxLen = min(6, source.length);
    final len = max(3, maxLen);
    final picked = _pickUniqueRandom(source, len);

    state = WorkoutState(
      workout: picked,
      index: 0,
      completedIds: {},
      startedAt: DateTime.now(),
      muscleGroup: group,
    );
    _isSaving = false;
  }

  void completeCurrentAndNext() {
    if (state.isFinished || _isSaving) return;
    final cur = state.current;
    if (cur == null) return;

    final newCompleted = {...state.completedIds, cur.id};
    final nextIndex = min(state.workout.length - 1, state.index + 1);
    state = state.copyWith(completedIds: newCompleted, index: nextIndex);

    if (state.isFinished) _persistCompletion();
  }

  void goPrev() {
    if (!state.hasWorkout) return;
    state = state.copyWith(index: max(0, state.index - 1));
  }

  void goNext() {
    if (!state.hasWorkout) return;
    state = state.copyWith(
      index: min(state.workout.length - 1, state.index + 1),
    );
  }

  static List<Exercise> _pickUniqueRandom(List<Exercise> source, int count) {
    final rng = Random();
    final indices = <int>{};
    final safeCount = min(count, source.length);
    while (indices.length < safeCount) {
      indices.add(rng.nextInt(source.length));
    }
    return indices.map((i) => source[i]).toList();
  }

  Future<void> _persistCompletion() async {
    if (_isSaving) return;
    _isSaving = true;

    final startedAt = state.startedAt ?? DateTime.now();
    final minutes = max(1, DateTime.now().difference(startedAt).inMinutes);
    final today = _todayDateKey();
    final groupLabel = (state.muscleGroup?.label ?? 'Unknown');

    final history = WorkoutHistory(
      date: today,
      completed: true,
      durationMinutes: minutes,
      muscleGroup: groupLabel,
      exerciseIds: state.workout.map((e) => e.id).toList(),
    );
    await _ref.read(historyRepoProvider).save(history);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final existingDay = await Supabase.instance.client
        .from('daily_activities')
        .select('id, goals_met, workout_duration_minutes')
        .eq('user_id', user.id)
        .eq('activity_date', today)
        .maybeSingle();

    if (existingDay == null) {
      await Supabase.instance.client.from('daily_activities').insert({
        'user_id': user.id,
        'activity_date': today,
        'workout_completed': true,
        'workout_duration_minutes': minutes,
        'is_active_day': true,
        'goals_met': 1,
      });
    } else {
      final prevGoals = _asInt(existingDay['goals_met']);
      final prevWorkoutMinutes = _asInt(existingDay['workout_duration_minutes']);
      await Supabase.instance.client
          .from('daily_activities')
          .update({
            'workout_completed': true,
            'workout_duration_minutes': max(prevWorkoutMinutes, minutes),
            'is_active_day': true,
            'goals_met': prevGoals + 1,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existingDay['id']);
    }

    final exercisesJson = state.workout.map((e) => e.toJson()).toList();

    final existingLog = await Supabase.instance.client
        .from('workout_logs')
        .select('id')
        .eq('user_id', user.id)
        .eq('activity_date', today)
        .maybeSingle();

    if (existingLog == null) {
      await Supabase.instance.client.from('workout_logs').insert({
        'user_id': user.id,
        'activity_date': today,
        'muscle_group': groupLabel,
        'duration_minutes': minutes,
        'total_exercises': state.workout.length,
        'completed_exercises': state.completedIds.length,
        'exercises': exercisesJson,
      });
    } else {
      await Supabase.instance.client
          .from('workout_logs')
          .update({
            'muscle_group': groupLabel,
            'duration_minutes': minutes,
            'total_exercises': state.workout.length,
            'completed_exercises': state.completedIds.length,
            'exercises': exercisesJson,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', existingLog['id']);
    }

    _ref.invalidate(todayHistoryProvider);
  }
}

final workoutControllerProvider =
    StateNotifierProvider<WorkoutController, WorkoutState>(
      (ref) => WorkoutController(ref),
    );

// ==========================================
// SCREEN WIDGET
// ==========================================

class PersonalizedExerciseScreen extends ConsumerWidget {
  const PersonalizedExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);
    final exercisesAsync = ref.watch(exercisesForGroupProvider);
    final workout = ref.watch(workoutControllerProvider);
    final todayHistoryAsync = ref.watch(todayHistoryProvider);

    final bool alreadyDoneToday =
        todayHistoryAsync.valueOrNull?.completed ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDarkSlate, kDarkTeal],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: const Text(
            'Personalized Exercises',
            style: TextStyle(color: kTextWhite, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              profileAsync.when(
                data: (p) => _ProfileCard(
                  age: p.age,
                  bmi: p.bmi,
                  level: ref.watch(personalizedLevelProvider),
                ),
                loading: () => const _SkeletonBox(height: 56),
                error: (e, _) => Text(
                  'Profile error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
              todayHistoryAsync.when(
                data: (h) {
                  if (h == null || h.completed != true)
                    return const SizedBox.shrink();
                  return _InfoBanner(
                    icon: Icons.check_circle,
                    text: 'Today completed • ${h.durationMinutes} min • ${h.muscleGroup}',
                    color: kAccentCyan,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose muscle group',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: kTextWhite,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: MuscleGroup.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final g = MuscleGroup.values[i];
                    final isSelected = g == selectedGroup;
                    return InkWell(
                      onTap: () {
                        ref.read(workoutControllerProvider.notifier).reset();
                        ref.read(selectedGroupProvider.notifier).state = g;
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kAccentCyan.withOpacity(0.8)
                              : kCardSurface.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isSelected ? kAccentCyan : kGlassBorder,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          g.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? kDarkSlate : kTextWhite,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                selectedGroup == null
                    ? 'Exercises'
                    : 'Exercises for: ${selectedGroup.label}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: kTextWhite,
                ),
              ),
              const SizedBox(height: 10),
              if (workout.hasWorkout)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _WorkoutProgress(
                    done: workout.done,
                    total: workout.total,
                  ),
                ),
              Expanded(
                child: exercisesAsync.when(
                  data: (items) {
                    if (selectedGroup == null) {
                      return const Center(
                        child: Text(
                          'Select a muscle group to load exercises.',
                          style: TextStyle(color: kTextGrey),
                        ),
                      );
                    }
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'No exercises found.',
                          style: TextStyle(color: kTextGrey),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      cacheExtent: 1000,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _ExerciseCard(ex: items[i]),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: kAccentCyan),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Exercises error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: exercisesAsync.when(
              data: (items) {
                final canStart = selectedGroup != null && items.length >= 3;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (workout.hasWorkout && !workout.isFinished)
                      _InfoBanner(
                        icon: Icons.fitness_center,
                        text: 'Workout in progress • ${workout.done}/${workout.total} done',
                        actionText: 'Open',
                        color: kAccentBlue,
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WorkoutPlayerScreen(),
                            ),
                          );
                        },
                      ),
                    if (workout.isFinished)
                      const _InfoBanner(
                        icon: Icons.celebration,
                        text: 'Workout completed for today 🎉',
                        color: Colors.greenAccent,
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (workout.isFinished || alreadyDoneToday)
                                  ? Colors.grey.withOpacity(0.3)
                                  : kAccentCyan,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          foregroundColor: kDarkSlate,
                        ),
                        onPressed: (workout.isFinished || alreadyDoneToday)
                            ? null
                            : () {
                                if (!workout.hasWorkout) {
                                  if (!canStart) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Pick a group with at least 3 exercises.'),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                    return;
                                  }
                                  ref
                                      .read(workoutControllerProvider.notifier)
                                      .startFromSource(
                                        items,
                                        group: selectedGroup!,
                                      );
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WorkoutPlayerScreen(),
                                  ),
                                );
                              },
                        child: Text(
                          alreadyDoneToday
                              ? 'Come back tomorrow!'
                              : (workout.hasWorkout
                                  ? 'Continue Workout'
                                  : 'Start Workout (3-6)'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 54,
                child: Center(
                  child: CircularProgressIndicator(color: kAccentCyan),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUB-WIDGETS (VISUALS)
// ==========================================

class _ProfileCard extends StatelessWidget {
  final int age;
  final double bmi;
  final String level;

  const _ProfileCard({
    required this.age,
    required this.bmi,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kAccentBlue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, size: 22, color: kAccentBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Profile',
                  style: TextStyle(
                    color: kTextGrey.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Age: $age  •  BMI: ${bmi.toStringAsFixed(1)}  •  $level',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: kTextWhite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise ex;
  const _ExerciseCard({required this.ex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 90,
              height: 90,
              color: Colors.black12,
              child: ex.id.trim().isEmpty
                  ? const Center(child: Icon(Icons.image_not_supported, color: kTextGrey))
                  : _ExerciseGif(exerciseId: ex.id),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _prettyName(ex.name),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: kTextWhite,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill('Body: ${ex.bodyPart}'),
                    _Pill('Target: ${ex.target}'),
                    _Pill('Equip: ${ex.equipment}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkoutPlayerScreen extends ConsumerWidget {
  const WorkoutPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutControllerProvider);
    final controller = ref.read(workoutControllerProvider.notifier);
    final cur = workout.current;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kDarkSlate, kDarkTeal],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: kTextWhite),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            workout.isFinished
                ? 'Completed'
                : 'Workout (${workout.done}/${workout.total})',
            style: const TextStyle(
              color: kTextWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                controller.reset();
                Navigator.pop(context);
              },
              child: const Text('Reset', style: TextStyle(color: kAccentCyan)),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: workout.hasWorkout
              ? (workout.isFinished
                  ? _CompletedView(onDone: () => Navigator.pop(context))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center, // Centers content
                      children: [
                        _WorkoutStepView(
                          exercise: cur!,
                          isDone: workout.completedIds.contains(cur.id),
                          onPrev: controller.goPrev,
                          onNext: controller.goNext,
                          onComplete: controller.completeCurrentAndNext,
                        ),
                      ],
                    ))
              : const Center(
                  child: Text(
                    'No workout started.\nGo back and press Start Workout.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: kTextWhite),
                  ),
                ),
        ),
      ),
    );
  }
}

class _WorkoutStepView extends StatelessWidget {
  final Exercise exercise;
  final bool isDone;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onComplete;

  const _WorkoutStepView({
    required this.exercise,
    required this.isDone,
    required this.onPrev,
    required this.onNext,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min, // Shrinks to fit content
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kCardSurface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kGlassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _prettyName(exercise.name),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kTextWhite,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // ✅ FIXED: Shorter (210), Full Width (BoxFit.cover)
              Container(
                width: double.infinity,
                height: 210,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _ExerciseGif(
                    exerciseId: exercise.id, 
                    fit: BoxFit.cover // Forces image to fill width
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill('Body: ${exercise.bodyPart}'),
                  _Pill('Target: ${exercise.target}'),
                  _Pill('Equip: ${exercise.equipment}'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAccentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAccentBlue.withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: kAccentBlue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Controlled reps, full range of motion.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kTextGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Controls
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kGlassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: kTextWhite,
                ),
                child: const Text('Prev'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onNext,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: kGlassBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: kTextWhite,
                ),
                child: const Text('Next'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDone ? Colors.green : kAccentCyan,
              foregroundColor: kDarkSlate,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onComplete,
            child: Text(
              isDone ? 'Done ✓ (Next)' : 'Mark Done',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompletedView extends StatelessWidget {
  final VoidCallback onDone;
  const _CompletedView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardSurface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kGlassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 50, color: kAccentCyan),
            const SizedBox(height: 10),
            const Text(
              'Workout Completed!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextWhite,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccentCyan,
                foregroundColor: kDarkSlate,
              ),
              onPressed: onDone,
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- VISUALS ---

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kAccentCyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccentCyan.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kAccentCyan),
      ),
    );
  }
}

class _WorkoutProgress extends StatelessWidget {
  final int done;
  final int total;
  const _WorkoutProgress({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation(kAccentCyan),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$done/$total',
            style: const TextStyle(fontWeight: FontWeight.bold, color: kTextWhite),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;
  final Color color;

  const _InfoBanner({
    required this.icon,
    required this.text,
    this.actionText,
    this.onAction,
    this.color = kAccentCyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionText!, style: TextStyle(color: color)),
            ),
        ],
      ),
    );
  }
}

class _ExerciseGif extends StatelessWidget {
  final String exerciseId;
  final BoxFit fit; 
  const _ExerciseGif({required this.exerciseId, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (exerciseId.trim().isEmpty) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('No Preview', style: TextStyle(color: kTextGrey)),
      );
    }

    return FutureBuilder<Uint8List>(
      future: ExerciseService.fetchExerciseGifBytes(
        exerciseId: exerciseId,
        resolutionPx: 180,
      ),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: kAccentCyan),
          );
        }

        final bytes = snap.data;
        if (bytes == null || bytes.isEmpty || snap.hasError) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, color: kTextGrey, size: 32),
                SizedBox(height: 4),
                Text('No Preview', style: TextStyle(color: kTextGrey)),
              ],
            ),
          );
        }

        return Image.memory(
          bytes,
          fit: fit, 
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) {
            return Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, color: kTextGrey, size: 32),
                  SizedBox(height: 4),
                  Text('No Preview', style: TextStyle(color: kTextGrey)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
      ),
      child: Center(
        child: LinearProgressIndicator(
          minHeight: 3,
          color: kAccentCyan.withOpacity(0.5),
        ),
      ),
    );
  }
}

String _prettyName(String s) {
  if (s.trim().isEmpty) return s;
  return s
      .split(' ')
      .where((w) => w.trim().isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}