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

  if (unique.length > 7) return unique.sublist(0, 7);
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
    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    final decoded = (raw != null && raw.isNotEmpty)
        ? (json.decode(raw) as Map<String, dynamic>? ?? {})
        : <String, dynamic>{};

    decoded[history.date] = history.toJson();
    await prefs.setString(_prefsKey, json.encode(decoded));
    
    // Save to Supabase
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('workout_history').upsert({
          'user_id': userId,
          'date': history.date,
          'completed': history.completed,
          'duration_minutes': history.durationMinutes,
          'muscle_group': history.muscleGroup,
          'exercise_ids': history.exerciseIds,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,date');
      }
    } catch (e) {
      // Log error but don't fail the save - local storage is primary
      print('Error saving to Supabase: $e');
    }
  }
}

final historyRepoProvider = Provider<HistoryRepo>((ref) => HistoryRepo());

final todayHistoryProvider = FutureProvider.autoDispose<WorkoutHistory?>((ref) async {
  final repo = ref.watch(historyRepoProvider);
  return repo.getToday();
});

// --- MAIN SCREEN ---

class PersonalizedExerciseScreen extends ConsumerStatefulWidget {
  final VoidCallback? onWorkoutCompleted;
  
  const PersonalizedExerciseScreen({super.key, this.onWorkoutCompleted});

  @override
  ConsumerState<PersonalizedExerciseScreen> createState() =>
      _PersonalizedExerciseScreenState();
}

class _PersonalizedExerciseScreenState extends ConsumerState<PersonalizedExerciseScreen> {
  MuscleGroup? _selectedGroup;
  bool _inWorkout = false;

  @override
  Widget build(BuildContext context) {
    final asyncProf = ref.watch(userProfileProvider);
    final level = ref.watch(personalizedLevelProvider);
    final selectedGroup = ref.watch(selectedGroupProvider);

    return Scaffold(
      backgroundColor: kDarkSlate,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    kDarkTeal.withOpacity(0.8),
                    kDarkSlate.withOpacity(0.8),
                  ],
                ),
                border: const Border(
                  bottom: BorderSide(color: kGlassBorder, width: 1),
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Personalized Workout',
          style: TextStyle(
            color: kTextWhite,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: kTextWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kDarkTeal,
              kDarkSlate,
              kDarkSlate,
            ],
          ),
        ),
        child: SafeArea(
          child: asyncProf.when(
            data: (profile) {
              return _inWorkout
                  ? _WorkoutSessionView(
                      onDone: () {
                        setState(() => _inWorkout = false);
                        // Call the callback when workout is completed
                        widget.onWorkoutCompleted?.call();
                      },
                    )
                  : _buildMainView(profile, level, selectedGroup);
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: kAccentCyan),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _InfoBanner(
                  icon: Icons.error_outline,
                  text: 'Error loading profile: ${e.toString()}',
                  color: Colors.redAccent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainView(UserProfile profile, String level, MuscleGroup? selectedGroup) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(profile, level),
          const SizedBox(height: 24),
          _buildTodayWorkoutBanner(),
          const SizedBox(height: 24),
          _buildMuscleGroupSection(selectedGroup),
          const SizedBox(height: 20),
          if (selectedGroup != null) ...[
            _buildExerciseList(selectedGroup),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileCard(UserProfile profile, String level) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kCardSurface.withOpacity(0.9),
            kCardSurface.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kGlassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kAccentCyan.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kAccentCyan.withOpacity(0.3), kAccentBlue.withOpacity(0.3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccentCyan.withOpacity(0.5)),
                ),
                child: const Icon(Icons.person_outline, color: kAccentCyan, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Profile',
                      style: TextStyle(
                        color: kTextGrey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.gender}, ${profile.age} years',
                      style: const TextStyle(
                        color: kTextWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kAccentCyan, kAccentBlue],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kAccentCyan.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  level,
                  style: const TextStyle(
                    color: kDarkSlate,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: kGlassBorder, thickness: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Weight',
                  '${profile.weightKg.toStringAsFixed(1)} kg',
                  Icons.fitness_center,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: kGlassBorder,
              ),
              Expanded(
                child: _buildStatItem(
                  'Height',
                  '${profile.heightCm.toStringAsFixed(0)} cm',
                  Icons.height,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: kGlassBorder,
              ),
              Expanded(
                child: _buildStatItem(
                  'BMI',
                  profile.bmi.toStringAsFixed(1),
                  Icons.monitor_weight_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: kAccentCyan.withOpacity(0.7), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: kTextWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: kTextGrey.withOpacity(0.8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTodayWorkoutBanner() {
    final historyAsync = ref.watch(todayHistoryProvider);
    return historyAsync.when(
      data: (h) {
        if (h == null) {
          return _InfoBanner(
            icon: Icons.info_outline,
            text: 'No workout completed today',
            color: kAccentBlue,
          );
        }
        if (h.completed) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.withOpacity(0.2),
                  Colors.green.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Workout Completed!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${h.muscleGroup} • ${h.durationMinutes} min • ${h.exerciseIds.length} exercises',
                            style: const TextStyle(
                              color: kTextGrey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Come back tomorrow to train another muscle group!',
                          style: TextStyle(
                            color: Colors.orange.shade200,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return _InfoBanner(
          icon: Icons.pending_actions,
          text: 'Workout in progress: ${h.muscleGroup}',
          color: Colors.orangeAccent,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMuscleGroupSection(MuscleGroup? selectedGroup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kAccentCyan.withOpacity(0.3), kAccentBlue.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center, color: kAccentCyan, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Select Muscle Group',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kTextWhite,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: MuscleGroup.values.map((group) {
            final isSelected = group == selectedGroup;
            return _buildMuscleGroupChip(group, isSelected);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMuscleGroupChip(MuscleGroup group, bool isSelected) {
    final historyAsync = ref.watch(todayHistoryProvider);
    
    return historyAsync.when(
      data: (todayHistory) {
        // Check if user has already completed a workout today
        final hasCompletedToday = todayHistory != null && todayHistory.completed;
        final isDisabled = hasCompletedToday && !isSelected;
        
        return Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled 
                ? null 
                : () {
                    setState(() => _selectedGroup = group);
                    ref.read(selectedGroupProvider.notifier).state = group;
                  },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [kAccentCyan, kAccentBlue],
                        )
                      : null,
                  color: isSelected 
                      ? null 
                      : isDisabled 
                          ? kCardSurface.withOpacity(0.3)
                          : kCardSurface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected 
                        ? kAccentCyan 
                        : isDisabled 
                            ? kGlassBorder.withOpacity(0.3)
                            : kGlassBorder,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: kAccentCyan.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getGroupIcon(group),
                      color: isSelected ? kDarkSlate : kAccentCyan,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      group.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? kDarkSlate : kTextWhite,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: kCardSurface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kGlassBorder, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getGroupIcon(group),
                color: kAccentCyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                group.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: kTextWhite,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (_, __) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedGroup = group);
            ref.read(selectedGroupProvider.notifier).state = group;
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: kCardSurface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kGlassBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getGroupIcon(group),
                  color: kAccentCyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  group.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: kTextWhite,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGroupIcon(MuscleGroup group) {
    switch (group) {
      case MuscleGroup.back:
        return Icons.accessibility_new;
      case MuscleGroup.chest:
        return Icons.favorite;
      case MuscleGroup.legs:
        return Icons.directions_run;
      case MuscleGroup.arms:
        return Icons.fitness_center;
      case MuscleGroup.cardio:
        return Icons.favorite_border;
      case MuscleGroup.core:
        return Icons.sports_gymnastics;
    }
  }

  Widget _buildExerciseList(MuscleGroup group) {
    final asyncExercises = ref.watch(exercisesForGroupProvider);
    return asyncExercises.when(
      data: (exercises) {
        if (exercises.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: kCardSurface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kGlassBorder),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: kTextGrey.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(
                    'No exercises found for ${group.label}',
                    style: TextStyle(color: kTextGrey, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${exercises.length} Exercises',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kTextWhite,
                  ),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final historyAsync = ref.watch(todayHistoryProvider);
                    return historyAsync.when(
                      data: (todayHistory) {
                        final hasCompletedToday = todayHistory != null && todayHistory.completed;
                        
                        return ElevatedButton.icon(
                          onPressed: hasCompletedToday 
                            ? null 
                            : () => setState(() => _inWorkout = true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasCompletedToday 
                              ? kTextGrey.withOpacity(0.3) 
                              : kAccentCyan,
                            foregroundColor: kDarkSlate,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: hasCompletedToday ? 0 : 4,
                          ),
                          icon: Icon(
                            hasCompletedToday ? Icons.block : Icons.play_arrow, 
                            size: 20,
                          ),
                          label: Text(
                            hasCompletedToday ? 'Completed Today' : 'Start Workout',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        );
                      },
                      loading: () => ElevatedButton.icon(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kTextGrey.withOpacity(0.3),
                          foregroundColor: kDarkSlate,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kTextGrey),
                        ),
                        label: const Text(
                          'Loading...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      error: (_, __) => ElevatedButton.icon(
                        onPressed: () => setState(() => _inWorkout = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kAccentCyan,
                          foregroundColor: kDarkSlate,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: const Text(
                          'Start Workout',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...exercises.map((ex) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ExerciseCard(exercise: ex),
                )),
          ],
        );
      },
      loading: () => Column(
        children: List.generate(3, (i) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _SkeletonBox(height: 120),
        )),
      ),
      error: (e, _) => _InfoBanner(
        icon: Icons.error_outline,
        text: 'Error: ${e.toString()}',
        color: Colors.redAccent,
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kCardSurface.withOpacity(0.8),
            kCardSurface.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
              ),
              child: _ExerciseGif(
                exerciseId: exercise.id,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _prettyName(exercise.name),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: kTextWhite,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(exercise.target),
                        if (exercise.equipment.isNotEmpty)
                          _Pill(exercise.equipment),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WORKOUT SESSION ---

class _WorkoutSessionView extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _WorkoutSessionView({required this.onDone});

  @override
  ConsumerState<_WorkoutSessionView> createState() => _WorkoutSessionViewState();
}

class _WorkoutSessionViewState extends ConsumerState<_WorkoutSessionView> {
  late Timer _timer;
  int _elapsedSeconds = 0;
  final Set<String> _completedIds = {};
  bool _sessionFinished = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _finishWorkout() async {
    final group = ref.read(selectedGroupProvider);
    if (group == null) return;

    final history = WorkoutHistory(
      date: _todayDateKey(),
      completed: true,
      durationMinutes: (_elapsedSeconds / 60).ceil(),
      muscleGroup: group.label,
      exerciseIds: _completedIds.toList(),
    );

    final repo = ref.read(historyRepoProvider);
    await repo.save(history);
    ref.invalidate(todayHistoryProvider);

    if (mounted) {
      setState(() => _sessionFinished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionFinished) {
      return _CompletedView(onDone: widget.onDone);
    }

    final asyncExercises = ref.watch(exercisesForGroupProvider);
    return asyncExercises.when(
      data: (exercises) {
        if (exercises.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: kTextGrey),
                const SizedBox(height: 16),
                const Text(
                  'No exercises available',
                  style: TextStyle(color: kTextWhite, fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: widget.onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentCyan,
                    foregroundColor: kDarkSlate,
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildWorkoutHeader(exercises.length),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: exercises.length,
                itemBuilder: (context, i) {
                  final ex = exercises[i];
                  final isDone = _completedIds.contains(ex.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _WorkoutExerciseCard(
                      exercise: ex,
                      isDone: isDone,
                      onToggle: () {
                        setState(() {
                          if (isDone) {
                            _completedIds.remove(ex.id);
                          } else {
                            _completedIds.add(ex.id);
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            _buildBottomActions(),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: kAccentCyan)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _InfoBanner(
            icon: Icons.error_outline,
            text: 'Error: ${e.toString()}',
            color: Colors.redAccent,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutHeader(int totalExercises) {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kCardSurface.withOpacity(0.95),
            kCardSurface.withOpacity(0.8),
          ],
        ),
        border: const Border(
          bottom: BorderSide(color: kGlassBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: kTextWhite),
                  onPressed: widget.onDone,
                ),
                const Text(
                  'Workout Session',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: kTextWhite,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kAccentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kAccentCyan.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, color: kAccentCyan, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: kAccentCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _WorkoutProgress(done: _completedIds.length, total: totalExercises),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            kCardSurface.withOpacity(0.95),
            kCardSurface.withOpacity(0.8),
          ],
        ),
        border: const Border(
          top: BorderSide(color: kGlassBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Requirement hint
            if (_completedIds.length < 3 || _completedIds.length > 6)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _completedIds.length < 3
                      ? 'Complete at least 3 exercises (${_completedIds.length}/3)'
                      : 'Maximum 6 exercises allowed (${_completedIds.length}/6)',
                  style: TextStyle(
                    color: _completedIds.length > 6 ? Colors.orange : kTextGrey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onDone,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextWhite,
                      side: const BorderSide(color: kGlassBorder, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_completedIds.length < 3 || _completedIds.length > 6) ? null : _finishWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (_completedIds.length < 3 || _completedIds.length > 6)
                          ? kTextGrey.withOpacity(0.3)
                          : kAccentCyan,
                      foregroundColor: kDarkSlate,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: (_completedIds.length < 3 || _completedIds.length > 6) ? 0 : 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Finish Workout',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final bool isDone;
  final VoidCallback onToggle;

  const _WorkoutExerciseCard({
    required this.exercise,
    required this.isDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDone
                  ? [
                      Colors.green.withOpacity(0.3),
                      Colors.green.withOpacity(0.2),
                    ]
                  : [
                      kCardSurface.withOpacity(0.8),
                      kCardSurface.withOpacity(0.6),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDone ? Colors.greenAccent.withOpacity(0.5) : kGlassBorder,
              width: isDone ? 2 : 1,
            ),
            boxShadow: isDone
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: _ExerciseGif(
                    exerciseId: exercise.id,
                    fit: BoxFit.cover,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _prettyName(exercise.name),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDone ? Colors.greenAccent : kTextWhite,
                                  height: 1.3,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isDone
                                    ? Colors.greenAccent.withOpacity(0.3)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDone ? Colors.greenAccent : kTextGrey,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                isDone ? Icons.check : Icons.circle_outlined,
                                color: isDone ? Colors.greenAccent : kTextGrey,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Pill(exercise.target),
                            if (exercise.equipment.isNotEmpty)
                              _Pill(exercise.equipment),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              kCardSurface.withOpacity(0.9),
              kCardSurface.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kAccentCyan.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: kAccentCyan.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kAccentCyan.withOpacity(0.3), kAccentBlue.withOpacity(0.3)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration, size: 64, color: kAccentCyan),
            ),
            const SizedBox(height: 24),
            const Text(
              'Workout Completed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: kTextWhite,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Great job! Keep up the momentum.',
              style: TextStyle(
                fontSize: 15,
                color: kTextGrey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentCyan,
                  foregroundColor: kDarkSlate,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                onPressed: onDone,
                child: const Text(
                  'Back to Home',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kAccentCyan.withOpacity(0.2),
            kAccentBlue.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAccentCyan.withOpacity(0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: kAccentCyan,
          letterSpacing: 0.3,
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kCardSurface.withOpacity(0.7),
            kCardSurface.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  color: kTextGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$done/$total completed',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kTextWhite,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kAccentCyan, kAccentBlue],
                      ),
                      borderRadius: BorderRadius.circular(99),
                      boxShadow: [
                        BoxShadow(
                          color: kAccentCyan.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 14,
              ),
            ),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionText!,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseGif extends StatefulWidget {
  final String exerciseId;
  final BoxFit fit;
  const _ExerciseGif({required this.exerciseId, this.fit = BoxFit.cover});

  @override
  State<_ExerciseGif> createState() => _ExerciseGifState();
}

class _ExerciseGifState extends State<_ExerciseGif> {
  late Future<Uint8List> _future;

  @override
  void initState() {
    super.initState();
    _future = ExerciseService.fetchExerciseGifBytes(
      exerciseId: widget.exerciseId,
      resolutionPx: 180,
    );
  }

  @override
  void didUpdateWidget(_ExerciseGif oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseId != widget.exerciseId) {
      _future = ExerciseService.fetchExerciseGifBytes(
        exerciseId: widget.exerciseId,
        resolutionPx: 180,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.exerciseId.trim().isEmpty) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Text('No Preview', style: TextStyle(color: kTextGrey)),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: kAccentCyan, strokeWidth: 2),
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
                Text('No Preview', style: TextStyle(color: kTextGrey, fontSize: 11)),
              ],
            ),
          );
        }

        return Image.memory(
          bytes,
          fit: widget.fit,
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
                  Text('No Preview', style: TextStyle(color: kTextGrey, fontSize: 11)),
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
        gradient: LinearGradient(
          colors: [
            kCardSurface.withOpacity(0.7),
            kCardSurface.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kGlassBorder),
      ),
      child: Center(
        child: SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(kAccentCyan.withOpacity(0.5)),
          ),
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