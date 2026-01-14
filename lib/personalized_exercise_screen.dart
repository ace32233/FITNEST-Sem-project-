import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ------------------------------
/// Models
/// ------------------------------
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

  double get bmi {
    final hM = heightCm / 100.0;
    if (hM <= 0) return 0;
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

    // FIX 1: Trim whitespace.
    // FIX 2: Force HTTPS (Android blocks HTTP).
    String rawGif = pickStr(['gifUrl', 'gif_url'], fallback: '').trim();
    if (rawGif.startsWith('http://')) {
      rawGif = rawGif.replaceFirst('http://', 'https://');
    }

    return Exercise(
      id: pickStr(['id', 'uuid', 'exerciseId'], fallback: ''),
      name: pickStr(['name'], fallback: ''),
      bodyPart: pickStr(['bodyPart', 'body_part'], fallback: ''),
      target: pickStr(['target'], fallback: ''),
      equipment: pickStr(['equipment'], fallback: ''),
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

/// ------------------------------
/// Helpers
/// ------------------------------
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
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

String levelFromBmiAndAge({required double bmi, required int age}) {
  if (bmi < 18.5) return 'beginner';
  if (bmi < 25) return age < 30 ? 'intermediate' : 'beginner';
  if (bmi < 30) return 'intermediate';
  return 'beginner';
}

/// ------------------------------
/// Supabase Profile
/// ------------------------------
final userProfileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw Exception('User not logged in.');

  final fitness = await Supabase.instance.client
      .from('user_fitness')
      .select('gender, age, weight_kg, height_ft, height_in')
      .eq('id', user.id)
      .maybeSingle();

  if (fitness == null) {
    throw Exception('No fitness profile found in user_fitness table for this user.');
  }

  final age = _asInt(fitness['age']);
  final weightKg = _asDouble(fitness['weight_kg']);
  final gender = (fitness['gender'] ?? 'unknown').toString();

  final heightFt = _asInt(fitness['height_ft']);
  final heightIn = _asInt(fitness['height_in']);
  final totalInches = (heightFt * 12) + heightIn;
  final heightCm = totalInches * 2.54;

  return UserProfile(
    age: age,
    weightKg: weightKg,
    heightCm: heightCm,
    gender: gender,
  );
});

final personalizedLevelProvider = Provider<String>((ref) {
  final p = ref.watch(userProfileProvider).valueOrNull;
  if (p == null) return 'beginner';
  return levelFromBmiAndAge(bmi: p.bmi, age: p.age);
});

/// ------------------------------
/// Muscle Groups (UI)
/// ------------------------------
enum MuscleGroup { back, chest, legs, arms, cardio, core }

extension MuscleGroupX on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.back:
        return 'Back';
      case MuscleGroup.chest:
        return 'Chest';
      case MuscleGroup.legs:
        return 'Legs';
      case MuscleGroup.arms:
        return 'Arms';
      case MuscleGroup.cardio:
        return 'Cardio';
      case MuscleGroup.core:
        return 'Core';
    }
  }
}

/// ExerciseDB bodyPart mapping
const Map<MuscleGroup, List<String>> groupToBodyParts = {
  MuscleGroup.back: ['back'],
  MuscleGroup.chest: ['chest'],
  MuscleGroup.legs: ['upper legs', 'lower legs'],
  MuscleGroup.arms: ['upper arms', 'lower arms'],
  MuscleGroup.cardio: ['cardio'],
  MuscleGroup.core: ['waist'],
};

final selectedGroupProvider = StateProvider<MuscleGroup?>((ref) => null);

/// ------------------------------
/// RapidAPI ExerciseDB
/// ------------------------------
Future<http.Response> _exerciseDbGet(Uri uri) async {
  final apiKey = dotenv.env['EXERCISE_API_KEY'] ?? '';
  final host = dotenv.env['EXERCISE_API_HOST'] ?? 'exercisedb.p.rapidapi.com';

  if (apiKey.isEmpty) {
    throw Exception('Exercise API credentials not found in .env');
  }

  final res = await http.get(
    uri,
    headers: {
      'X-RapidAPI-Key': apiKey,
      'X-RapidAPI-Host': host,
    },
  );

  if (res.statusCode == 429) {
    throw Exception('429: Rate limit exceeded on RapidAPI.');
  }
  return res;
}

Future<List<Exercise>> _fetchExercisesForBodyPart(String bodyPart) async {
  final host = dotenv.env['EXERCISE_API_HOST'] ?? 'exercisedb.p.rapidapi.com';
  final uri = Uri.https(host, '/exercises/bodyPart/$bodyPart');

  final res = await _exerciseDbGet(uri);
  if (res.statusCode != 200) {
    throw Exception('Failed to fetch exercises for "$bodyPart": ${res.statusCode}');
  }

  final decoded = json.decode(res.body);
  if (decoded is! List) throw Exception('Unexpected response format');

  return decoded
      .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
      .where((e) => e.name.trim().isNotEmpty)
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
    final key = ex.id.isNotEmpty ? ex.id : '${ex.name}_${ex.bodyPart}_${ex.target}_${ex.equipment}';
    if (seen.add(key)) unique.add(ex);
  }

  if (unique.length > 80) return unique.sublist(0, 80);
  return unique;
});

/// ------------------------------
/// Local history (SharedPreferences)
/// ------------------------------
class WorkoutHistory {
  final String date; // yyyy-mm-dd
  final bool completed;
  final int durationMinutes;
  final String muscleGroup; // Back/Chest...
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
    if (entry is Map) return WorkoutHistory.fromJson(Map<String, dynamic>.from(entry));
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

/// ------------------------------
/// Workout session
/// ------------------------------
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

    if (state.isFinished) {
      _persistCompletion();
    }
  }

  void goPrev() {
    if (!state.hasWorkout) return;
    state = state.copyWith(index: max(0, state.index - 1));
  }

  void goNext() {
    if (!state.hasWorkout) return;
    state = state.copyWith(index: min(state.workout.length - 1, state.index + 1));
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

    // 1) Local
    final history = WorkoutHistory(
      date: today,
      completed: true,
      durationMinutes: minutes,
      muscleGroup: groupLabel,
      exerciseIds: state.workout.map((e) => e.id).toList(),
    );
    await _ref.read(historyRepoProvider).save(history);

    // 2) Supabase
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // A) Upsert daily_activities
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
      await Supabase.instance.client.from('daily_activities').update({
        'workout_completed': true,
        'workout_duration_minutes': max(prevWorkoutMinutes, minutes),
        'is_active_day': true,
        'goals_met': prevGoals + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existingDay['id']);
    }

    // B) Upsert workout_logs
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
      await Supabase.instance.client.from('workout_logs').update({
        'muscle_group': groupLabel,
        'duration_minutes': minutes,
        'total_exercises': state.workout.length,
        'completed_exercises': state.completedIds.length,
        'exercises': exercisesJson,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existingLog['id']);
    }

    _ref.invalidate(todayHistoryProvider);
  }
}

final workoutControllerProvider =
    StateNotifierProvider<WorkoutController, WorkoutState>((ref) => WorkoutController(ref));

/// ------------------------------
/// UI
/// ------------------------------
class PersonalizedExerciseScreen extends ConsumerWidget {
  const PersonalizedExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);
    final exercisesAsync = ref.watch(exercisesForGroupProvider);
    final workout = ref.watch(workoutControllerProvider);
    final todayHistoryAsync = ref.watch(todayHistoryProvider);
    
    final bool alreadyDoneToday = todayHistoryAsync.valueOrNull?.completed ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF7F4FF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personalized Exercises',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
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
              error: (e, _) => Text('Profile error: $e'),
            ),
            const SizedBox(height: 12),

            todayHistoryAsync.when(
              data: (h) {
                if (h == null || h.completed != true) return const SizedBox.shrink();
                return _InfoBanner(
                  icon: Icons.check_circle,
                  text: 'Today completed • ${h.durationMinutes} min • ${h.muscleGroup}',
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 10),
            const Text(
              'Choose muscle group',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
                  return ChoiceChip(
                    label: Text(g.label),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(workoutControllerProvider.notifier).reset();
                      ref.read(selectedGroupProvider.notifier).state = g;
                    },
                    selectedColor: const Color(0xFFDED2FF),
                    backgroundColor: Colors.white,
                    shape: StadiumBorder(
                      side: BorderSide(color: isSelected ? Colors.black26 : Colors.black12),
                    ),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),
            Text(
              selectedGroup == null ? 'Exercises' : 'Exercises for: ${selectedGroup.label}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),

            if (workout.hasWorkout)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _WorkoutProgress(done: workout.done, total: workout.total),
              ),

            Expanded(
              child: exercisesAsync.when(
                data: (items) {
                  if (selectedGroup == null) {
                    return const Center(
                      child: Text(
                        'Select a muscle group to load exercises.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  }
                  if (items.isEmpty) return const Center(child: Text('No exercises found.'));
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ExerciseCard(ex: items[i]),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Exercises error: $e')),
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
                      onAction: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WorkoutPlayerScreen()),
                        );
                      },
                    ),
                  if (workout.isFinished)
                    const _InfoBanner(
                      icon: Icons.celebration,
                      text: 'Workout completed for today 🎉 (Saved to Supabase)',
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (workout.isFinished || alreadyDoneToday) 
                            ? Colors.grey 
                            : const Color(0xFF6D4CFF),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: (workout.isFinished || alreadyDoneToday)
                          ? null
                          : () {
                              if (!workout.hasWorkout) {
                                if (!canStart) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Pick a group with at least 3 exercises.')),
                                  );
                                  return;
                                }
                                ref.read(workoutControllerProvider.notifier).startFromSource(
                                      items,
                                      group: selectedGroup!,
                                    );
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const WorkoutPlayerScreen()),
                              );
                            },
                      child: Text(
                        alreadyDoneToday 
                            ? 'Come back tomorrow!'
                            : (workout.hasWorkout ? 'Continue Workout' : 'Start Workout (3-6)'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(height: 54, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// ------------------------------
/// Workout Player (sequence + GIF)
/// ------------------------------
class WorkoutPlayerScreen extends ConsumerWidget {
  const WorkoutPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(workoutControllerProvider);
    final controller = ref.read(workoutControllerProvider.notifier);
    final cur = workout.current;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F4FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          workout.isFinished ? 'Completed' : 'Workout (${workout.done}/${workout.total})',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.reset();
              Navigator.pop(context);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: workout.hasWorkout
            ? (workout.isFinished
                ? _CompletedView(onDone: () => Navigator.pop(context))
                : _WorkoutStepView(
                    exercise: cur!,
                    isDone: workout.completedIds.contains(cur.id),
                    onPrev: controller.goPrev,
                    onNext: controller.goNext,
                    onComplete: controller.completeCurrentAndNext,
                  ))
            : const Center(
                child: Text(
                  'No workout started.\nGo back and press Start Workout.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800),
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
    // FIX 3: Add API headers to image request
    final apiKey = dotenv.env['EXERCISE_API_KEY'] ?? '';
    final apiHost = dotenv.env['EXERCISE_API_HOST'] ?? '';
    
    // Safety check for empty keys
    final Map<String, String>? headers = (apiKey.isNotEmpty && apiHost.isNotEmpty) 
        ? {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost}
        : null;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12),
            boxShadow: const [
              BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x14000000)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _prettyName(exercise.name),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: _ExerciseGif(url: exercise.gifUrl, headers: headers),
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
                  color: const Color(0xFFF1ECFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text(
                  'Tip: Controlled reps, full range of motion, steady breathing.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPrev,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              backgroundColor: isDone ? Colors.green : const Color(0xFF6D4CFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onComplete,
            child: Text(
              isDone ? 'Done ✓ (Next)' : 'Mark Done',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseGif extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  
  const _ExerciseGif({required this.url, this.headers});

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Container(
        color: Colors.black12, 
        alignment: Alignment.center, 
        child: const Text('No Preview', style: TextStyle(color: Colors.black45)),
      );
    }

    return Image.network(
      url,
      headers: headers, // Pass auth headers here
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      loadingBuilder: (c, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      },
      errorBuilder: (_, error, stackTrace) {
        debugPrint('[IMAGE ERROR] Failed to load: $url\nError: $error');
        return Container(
          color: Colors.black12,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, color: Colors.black38, size: 32),
              const SizedBox(height: 4),
              const Text(
                'No Preview',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black45),
              ),
            ],
          ),
        );
      },
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 42),
            const SizedBox(height: 10),
            const Text('Workout Completed!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Saved locally + Supabase (daily_activities + workout_logs)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onDone, child: const Text('Back')),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------
/// UI bits
/// ------------------------------
class _ProfileCard extends StatelessWidget {
  final int age;
  final double bmi;
  final String level;

  const _ProfileCard({required this.age, required this.bmi, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x14000000))],
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Age: $age  •  BMI: ${bmi.toStringAsFixed(1)}  •  Level: $level',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
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
    // FIX 3: Also add headers to the list view thumbnail
    final apiKey = dotenv.env['EXERCISE_API_KEY'] ?? '';
    final apiHost = dotenv.env['EXERCISE_API_HOST'] ?? '';
    
    final Map<String, String>? headers = (apiKey.isNotEmpty && apiHost.isNotEmpty) 
        ? {'X-RapidAPI-Key': apiKey, 'X-RapidAPI-Host': apiHost}
        : null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [BoxShadow(blurRadius: 16, offset: Offset(0, 6), color: Color(0x14000000))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 90,
              height: 90,
              color: const Color(0xFFF1ECFF),
              child: ex.gifUrl.isEmpty
                  ? const Center(child: Icon(Icons.image_not_supported, color: Colors.black26))
                  : Image.network(
                      ex.gifUrl,
                      headers: headers, // Pass auth headers
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: Icon(Icons.image, color: Colors.black12));
                      },
                      errorBuilder: (_, error, stackTrace) {
                        debugPrint('[LIST IMAGE ERROR] ${ex.name}: ${ex.gifUrl}');
                        return const Center(child: Icon(Icons.broken_image, color: Colors.black26));
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_prettyName(ex.name), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: const Color(0xFFF1ECFF),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$done/$total', style: const TextStyle(fontWeight: FontWeight.w900)),
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

  const _InfoBanner({required this.icon, required this.text, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w900))),
          if (actionText != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionText!)),
        ],
      ),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: const Center(child: LinearProgressIndicator(minHeight: 3)),
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