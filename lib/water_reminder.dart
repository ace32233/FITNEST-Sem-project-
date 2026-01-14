import 'package:fittness_app/home_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'calorie_page.dart';
import 'services/notification_service.dart';
import 'dart:ui'; // Required for glassmorphism

class WaterTrackerPage extends StatefulWidget {
  const WaterTrackerPage({Key? key}) : super(key: key);

  @override
  State<WaterTrackerPage> createState() => _WaterTrackerPageState();
}

class _WaterTrackerPageState extends State<WaterTrackerPage> {
  // --- BUSINESS LOGIC (UNCHANGED) ---
  int currentWater = 0;
  int targetWater = 2500;
  int quickAddAmount = 50;
  Map<String, ReminderData> reminders = {};
  List<Map<String, dynamic>> customReminders = [];
  final NotificationService _notificationService = NotificationService();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadTodayData();
    _initializeDefaultReminders();
  }

  void _initializeDefaultReminders() {
    reminders = {
      'morning_7': ReminderData(
        id: 'morning_7',
        label: 'Morning',
        time: '7 am',
        hour: 7,
        minute: 0,
        isEnabled: false,
        activeDays: {0, 1, 2, 3, 4, 5, 6},
      ),
      'noon_11': ReminderData(
        id: 'noon_11',
        label: 'Noon',
        time: '11 am',
        hour: 11,
        minute: 0,
        isEnabled: false,
        activeDays: {0, 1, 2, 3, 4, 5, 6},
      ),
      'afternoon_2': ReminderData(
        id: 'afternoon_2',
        label: 'Afternoon',
        time: '2 pm',
        hour: 14,
        minute: 0,
        isEnabled: false,
        activeDays: {0, 1, 2, 3, 4, 5, 6},
      ),
      'afternoon_4': ReminderData(
        id: 'afternoon_4',
        label: 'Afternoon',
        time: '4 pm',
        hour: 16,
        minute: 0,
        isEnabled: false,
        activeDays: {0, 1, 2, 3, 4, 5, 6},
      ),
      'evening_7': ReminderData(
        id: 'evening_7',
        label: 'Evening',
        time: '7 pm',
        hour: 19,
        minute: 0,
        isEnabled: false,
        activeDays: {0, 1, 2, 3, 4, 5, 6},
      ),
    };
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];

      final response = await _supabase
          .from('daily_activities')
          .select('water_intake_ml, water_goal_ml')
          .eq('user_id', userId)
          .eq('activity_date', today)
          .maybeSingle();

      if (response != null) {
        setState(() {
          currentWater = response['water_intake_ml'] ?? 0;
          targetWater = response['water_goal_ml'] ?? 2500;
        });
      } else {
        await _supabase.from('daily_activities').insert({
          'user_id': userId,
          'activity_date': today,
          'water_intake_ml': 0,
          'water_goal_ml': targetWater,
        });
      }
    } catch (e) {
      print('Error loading water data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateWaterIntake() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];

      await _supabase
          .from('daily_activities')
          .update({
        'water_intake_ml': currentWater,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId)
          .eq('activity_date', today);
    } catch (e) {
      print('Error updating water intake: $e');
    }
  }

  Future<void> _scheduleReminder(ReminderData reminder) async {
    if (!reminder.isEnabled || reminder.activeDays.isEmpty) {
      await _cancelReminder(reminder.id);
      return;
    }

    final notificationId = reminder.id.hashCode.abs();

    await _notificationService.scheduleWaterReminder(
      id: notificationId,
      title: 'Time to Drink Water! 💧',
      body: 'Stay hydrated! Drink ${quickAddAmount}ml of water now.',
      hour: reminder.hour,
      minute: reminder.minute,
      activeDays: reminder.activeDays,
    );
  }

  Future<void> _cancelReminder(String id) async {
    final notificationId = id.hashCode.abs();
    await _notificationService.cancelNotification(notificationId);
  }

  void addWater() {
    setState(() {
      if (currentWater + quickAddAmount <= targetWater) {
        currentWater += quickAddAmount;
      } else {
        currentWater = targetWater;
      }
    });
    _updateWaterIntake();
  }

  void increaseQuickAddAmount() {
    setState(() {
      quickAddAmount += 50;
    });
  }

  void decreaseQuickAddAmount() {
    setState(() {
      if (quickAddAmount > 50) {
        quickAddAmount -= 50;
      }
    });
  }

  void showSetTargetDialog() {
    final TextEditingController controller = TextEditingController(
      text: targetWater.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Daily Target'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Target (ml)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final newTarget = int.tryParse(controller.text) ?? targetWater;
                setState(() {
                  targetWater = newTarget;
                  if (currentWater > targetWater) {
                    currentWater = targetWater;
                  }
                });

                try {
                  final userId = _supabase.auth.currentUser?.id;
                  if (userId != null) {
                    final today = DateTime.now().toIso8601String().split('T')[0];
                    await _supabase
                        .from('daily_activities')
                        .update({'water_goal_ml': targetWater})
                        .eq('user_id', userId)
                        .eq('activity_date', today);
                  }
                } catch (e) {
                  print('Error updating target: $e');
                }

                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
    );
  }

  void showReminderSettingsDialog(String reminderId) {
    final reminder = reminders[reminderId]!;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${reminder.label} Reminder Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time: ${reminder.time}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Active Days:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDayChip('Mon', 1, reminder, setDialogState),
                      _buildDayChip('Tue', 2, reminder, setDialogState),
                      _buildDayChip('Wed', 3, reminder, setDialogState),
                      _buildDayChip('Thu', 4, reminder, setDialogState),
                      _buildDayChip('Fri', 5, reminder, setDialogState),
                      _buildDayChip('Sat', 6, reminder, setDialogState),
                      _buildDayChip('Sun', 0, reminder, setDialogState),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {});
                    _scheduleReminder(reminder);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDayChip(String label, int dayIndex, ReminderData reminder, StateSetter setDialogState) {
    final isActive = reminder.activeDays.contains(dayIndex);

    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (selected) {
        setDialogState(() {
          if (selected) {
            reminder.activeDays.add(dayIndex);
          } else {
            reminder.activeDays.remove(dayIndex);
          }
        });
      },
      selectedColor: const Color(0xFF5865A1),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isActive ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void showCustomReminderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Custom Reminders'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (customReminders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No custom reminders yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customReminders.length,
                          itemBuilder: (context, index) {
                            final reminder = customReminders[index];
                            return ListTile(
                              title: Text(reminder['label']),
                              subtitle: Text(reminder['time']),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  await _cancelReminder('custom_$index');

                                  setDialogState(() {
                                    customReminders.removeAt(index);
                                  });
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          final customId = 'custom_${customReminders.length}';
                          final timeString = picked.format(context);

                          setDialogState(() {
                            customReminders.add({
                              'id': customId,
                              'label': 'Custom',
                              'time': timeString,
                              'hour': picked.hour,
                              'minute': picked.minute,
                            });
                          });

                          await _notificationService.scheduleWaterReminder(
                            id: customId.hashCode.abs(),
                            title: 'Time to Drink Water! 💧',
                            body: 'Stay hydrated! Drink ${quickAddAmount}ml of water now.',
                            hour: picked.hour,
                            minute: picked.minute,
                          );

                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Custom Reminder'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showHistoryDialog() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('daily_activities')
          .select('activity_date, water_intake_ml, water_goal_ml')
          .eq('user_id', userId)
          .gt('water_intake_ml', 0)
          .order('activity_date', ascending: false)
          .limit(30);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Water Intake History'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: response.isEmpty
                  ? const Center(
                child: Text(
                  'No history available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                itemCount: response.length,
                itemBuilder: (context, index) {
                  final day = response[index];
                  final date = DateTime.parse(day['activity_date']);
                  final intake = day['water_intake_ml'];
                  final goal = day['water_goal_ml'];
                  final percentage = (intake / goal * 100).toInt();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: percentage >= 100
                            ? Colors.green
                            : percentage >= 75
                            ? Colors.orange
                            : Colors.red,
                        child: Text(
                          '${percentage}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        '${date.day}/${date.month}/${date.year}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${intake}ml / ${goal}ml'),
                      trailing: Icon(
                        percentage >= 100
                            ? Icons.check_circle
                            : Icons.water_drop,
                        color: percentage >= 100
                            ? Colors.green
                            : const Color(0xFF5DC0F0),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }

  void resetProgress() {
    setState(() {
      currentWater = 0;
    });
    _updateWaterIntake();
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add Activity',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAddOption(
                  icon: Icons.restaurant,
                  label: 'Calories',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NutritionPage(),
                      ),
                    );
                  },
                ),
                _buildAddOption(
                  icon: Icons.fitness_center,
                  label: 'Exercise',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILD METHOD START ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D2F5C),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // New Gradient Background
    return Scaffold(
      extendBody: true, // Allows content behind FAB
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F2027), // Deep Dark Blue/Black
              Color(0xFF203A43),
              Color(0xFF2C5364), // Lighter Teal-ish Blue
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.maybePop(context)
                    ),
                    Text(
                      "Hydration Tracker",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white70),
                          onPressed: showHistoryDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          onPressed: resetProgress,
                        ),
                      ],
                    )
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.05,
                      vertical: size.height * 0.02,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildWaterProgress(size, isSmallScreen),
                        SizedBox(height: size.height * 0.04),
                        _buildQuickAddSection(size, isSmallScreen),
                        SizedBox(height: size.height * 0.03),
                        _buildReminderSection(isSmallScreen),
                        SizedBox(height: size.height * 0.12), // Space for FAB
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Stylish Floating Action Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4FACFE), // Bright Blue
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Stylish Bottom Bar
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home_rounded, color: Color(0xFF4FACFE), size: 30),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                },
              ),
              const SizedBox(width: 40), // Gap for FAB
              IconButton(
                icon: const Icon(Icons.bar_chart_rounded, color: Colors.white54, size: 30),
                onPressed: () {
                  // TODO: Navigate to stats page
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Improved Progress Indicator: Glassy + Gradient Fill
  Widget _buildWaterProgress(Size size, bool isSmallScreen) {
    double progress = currentWater / targetWater;
    double circleSize = size.width * 0.60;
    if (circleSize > 280) circleSize = 280;
    if (circleSize < 200) circleSize = 200;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Outer Glow
        Container(
          width: circleSize + 20,
          height: circleSize + 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4FACFE).withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        // Main Circle Background
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
          ),
        ),
        // Water Fill (Gradient)
        ClipOval(
          child: SizedBox(
            width: circleSize,
            height: circleSize,
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    height: circleSize * progress,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF4FACFE), // Bright Blue
                          Color(0xFF00F2FE), // Cyan
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentWater}ml',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 36 : 46,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black26, blurRadius: 10)],
              ),
            ),
            Text(
              'of ${targetWater}ml goal',
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        // "Set Target" Button
        Positioned(
          right: 0,
          bottom: circleSize * 0.1,
          child: GestureDetector(
            onTap: showSetTargetDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    color: const Color(0xFF0D2F5C),
                    size: isSmallScreen ? 14 : 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Goal',
                    style: TextStyle(
                      color: const Color(0xFF0D2F5C),
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Modern "Glass" Quick Add Section
Widget _buildQuickAddSection(Size size, bool isSmallScreen) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.05,
          vertical: size.height * 0.025,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              'Quick Add',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: size.height * 0.02),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircleButton(
                  icon: Icons.remove,
                  onTap: decreaseQuickAddAmount,
                  isSmall: isSmallScreen,
                ),
                
                // --- FIX STARTS HERE ---
                GestureDetector(
                  onTap: addWater, // This was missing!
                  child: Container(
                    width: size.width * 0.4,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FACFE).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF4FACFE), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${quickAddAmount}ml',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isSmallScreen ? 20 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // --- FIX ENDS HERE ---

                _buildCircleButton(
                  icon: Icons.add,
                  onTap: increaseQuickAddAmount,
                  isSmall: isSmallScreen,
                  isPrimary: true,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isSmall,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isSmall ? 45 : 50,
        height: isSmall ? 45 : 50,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isPrimary ? const Color(0xFF0D2F5C) : Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // Modern Reminder Grid
  Widget _buildReminderSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            'Reminders',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            ...reminders.entries.map((entry) {
              final reminder = entry.value;
              final isEnabled = reminder.isEnabled;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    reminder.isEnabled = !reminder.isEnabled;
                  });
                  _scheduleReminder(reminder);
                },
                onLongPress: () => showReminderSettingsDialog(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? const Color(0xFF4FACFE) // Active Blue
                        : Colors.white.withOpacity(0.08), // Inactive Glass
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isEnabled ? Colors.transparent : Colors.white.withOpacity(0.1),
                    ),
                    boxShadow: isEnabled
                        ? [BoxShadow(color: const Color(0xFF4FACFE).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              reminder.label,
                              style: TextStyle(
                                color: isEnabled ? Colors.white : Colors.white70,
                                fontSize: isSmallScreen ? 13 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reminder.time,
                              style: TextStyle(
                                color: isEnabled ? Colors.white.withOpacity(0.9) : Colors.white54,
                                fontSize: isSmallScreen ? 11 : 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isEnabled)
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.check_circle, size: 14, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),

            // Custom Button
            GestureDetector(
              onTap: showCustomReminderDialog,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1), style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.white70, size: 24),
                    SizedBox(height: 4),
                    Text(
                      'Custom',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Logic classes remain exactly the same
class ReminderData {
  final String id;
  final String label;
  final String time;
  final int hour;
  final int minute;
  bool isEnabled;
  Set<int> activeDays;

  ReminderData({
    required this.id,
    required this.label,
    required this.time,
    required this.hour,
    required this.minute,
    required this.isEnabled,
    required this.activeDays,
  });
}