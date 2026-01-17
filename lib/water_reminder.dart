import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui'; // For ImageFilter
import 'calorie_page.dart'; // Navigation
import 'services/notification_service.dart';
import 'personalized_exercise_screen.dart'; // Navigation
import 'home_page.dart'; // Navigation

// --- GLOSSY DESIGN CONSTANTS (MATCHING HOME & NUTRITION PAGE) ---
const Color kDarkTeal = Color(0xFF132F38); 
const Color kDarkSlate = Color(0xFF0F172A); 
const Color kCardSurface = Color(0xFF1E293B); 
const Color kGlassBorder = Color(0x33FFFFFF); 
const Color kGlassBase = Color(0x1AFFFFFF); 
const Color kAccentCyan = Color(0xFF22D3EE); 
const Color kAccentBlue = Color(0xFF3B82F6); 
const Color kTextWhite = Colors.white;
const Color kTextGrey = Color(0xFF94A3B8);

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
      debugPrint('Error loading water data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      debugPrint('Error updating water intake: $e');
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
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: kDarkSlate.withOpacity(0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: kGlassBorder)),
            title: const Text('Set Daily Target', style: TextStyle(color: kTextWhite)),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: kTextWhite),
              decoration: InputDecoration(
                labelText: 'Target (ml)',
                labelStyle: const TextStyle(color: kTextGrey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: kGlassBorder), borderRadius: BorderRadius.circular(12)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: kTextGrey)),
              ),
              ElevatedButton(
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
                    debugPrint('Error updating target: $e');
                  }

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Set', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
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
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: AlertDialog(
                backgroundColor: kDarkSlate.withOpacity(0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: kGlassBorder)),
                title: Text('${reminder.label} Settings', style: const TextStyle(color: kTextWhite)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time: ${reminder.time}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kAccentCyan),
                    ),
                    const SizedBox(height: 20),
                    const Text('Active Days:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextGrey)),
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
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: kTextGrey))),
                  TextButton(
                    onPressed: () {
                      setState(() {});
                      _scheduleReminder(reminder);
                      Navigator.pop(context);
                    },
                    child: const Text('Save', style: TextStyle(color: kAccentBlue)),
                  ),
                ],
              ),
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
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedColor: kAccentBlue,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(color: isActive ? Colors.white : kTextGrey, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isActive ? kAccentBlue : kGlassBorder)),
    );
  }

  void showCustomReminderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: AlertDialog(
                backgroundColor: kDarkSlate.withOpacity(0.95),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: kGlassBorder)),
                title: const Text('Custom Reminders', style: TextStyle(color: kTextWhite)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (customReminders.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No custom reminders yet', style: TextStyle(color: kTextGrey)),
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
                                title: Text(reminder['label'], style: const TextStyle(color: kTextWhite)),
                                subtitle: Text(reminder['time'], style: const TextStyle(color: kTextGrey)),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
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
                        style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Add Custom Reminder', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: kTextGrey))),
                ],
              ),
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
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: kDarkSlate.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: kGlassBorder)),
              title: const Text('Water Intake History', style: TextStyle(color: kTextWhite)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: response.isEmpty
                    ? const Center(child: Text('No history available', style: TextStyle(color: kTextGrey)))
                    : ListView.builder(
                        itemCount: response.length,
                        itemBuilder: (context, index) {
                          final day = response[index];
                          final date = DateTime.parse(day['activity_date']);
                          final intake = day['water_intake_ml'];
                          final goal = day['water_goal_ml'];
                          final percentage = (intake / goal * 100).toInt();

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: kCardSurface.withOpacity(0.6), // Matched card surface
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kGlassBorder),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: percentage >= 100 ? Colors.green : (percentage >= 75 ? Colors.orange : Colors.red),
                                child: Text('${percentage}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              title: Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.w600)),
                              subtitle: Text('${intake}ml / ${goal}ml', style: const TextStyle(color: kTextGrey)),
                              trailing: Icon(
                                percentage >= 100 ? Icons.check_circle : Icons.water_drop,
                                color: percentage >= 100 ? Colors.green : kAccentBlue,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: kTextGrey)))],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void resetProgress() {
    setState(() {
      currentWater = 0;
    });
    _updateWaterIntake();
  }

  // --- UI BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    // EXACT BACKGROUND FROM HOME/NUTRITION PAGE
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
          // --- CHANGE: REMOVED LEADING ICON & DISABLED DEFAULT ---
          automaticallyImplyLeading: false,
          title: const Text("Hydration", style: TextStyle(color: kTextWhite, fontWeight: FontWeight.bold, fontSize: 24)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.history_rounded, color: kTextGrey), onPressed: showHistoryDialog),
            IconButton(icon: const Icon(Icons.refresh_rounded, color: kTextGrey), onPressed: resetProgress),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kAccentCyan))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
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
                      SizedBox(height: size.height * 0.15), // Bottom padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildWaterProgress(Size size, bool isSmallScreen) {
    double progress = (targetWater == 0) ? 0 : (currentWater / targetWater).clamp(0.0, 1.0);
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
                color: kAccentBlue.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        // Main Glassy Circle
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05), // Glassy white
            border: Border.all(color: kGlassBorder, width: 2),
          ),
        ),
        // Water Fill (Animated)
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          kAccentBlue.withOpacity(0.8),
                          kAccentCyan.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Text Content
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentWater}ml',
              style: TextStyle(
                color: kTextWhite,
                fontSize: isSmallScreen ? 36 : 46,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 10)],
              ),
            ),
            Text(
              'of ${targetWater}ml goal',
              style: TextStyle(
                color: kTextWhite.withOpacity(0.7),
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: kTextWhite, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        // Set Target Edit Button
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: kDarkSlate, size: isSmallScreen ? 14 : 16),
                  const SizedBox(width: 4),
                  Text(
                    'Goal',
                    style: TextStyle(color: kDarkSlate, fontSize: isSmallScreen ? 11 : 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddSection(Size size, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.05,
        vertical: size.height * 0.025,
      ),
      decoration: BoxDecoration(
        color: kCardSurface.withOpacity(0.6), // Matched solid glassy surface
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kGlassBorder),
      ),
      child: Column(
        children: [
          Text(
            'Quick Add',
            style: TextStyle(color: kTextWhite, fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: size.height * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCircleButton(icon: Icons.remove, onTap: decreaseQuickAddAmount, isSmall: isSmallScreen),
              GestureDetector(
                onTap: addWater,
                child: Container(
                  width: size.width * 0.4,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: kAccentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: kAccentBlue, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${quickAddAmount}ml',
                      style: TextStyle(color: kTextWhite, fontSize: isSmallScreen ? 20 : 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              _buildCircleButton(icon: Icons.add, onTap: increaseQuickAddAmount, isSmall: isSmallScreen, isPrimary: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({required IconData icon, required VoidCallback onTap, required bool isSmall, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isSmall ? 45 : 50,
        height: isSmall ? 45 : 50,
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white : Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isPrimary ? kDarkSlate : kTextWhite, size: 28),
      ),
    );
  }

  Widget _buildReminderSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text('Reminders', style: TextStyle(color: kTextWhite, fontSize: 18, fontWeight: FontWeight.w600)),
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
                    color: isEnabled ? kAccentBlue : kCardSurface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isEnabled ? Colors.transparent : kGlassBorder),
                    boxShadow: isEnabled ? [BoxShadow(color: kAccentBlue.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))] : [],
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(reminder.label, style: TextStyle(color: isEnabled ? kTextWhite : kTextGrey, fontSize: isSmallScreen ? 13 : 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(reminder.time, style: TextStyle(color: isEnabled ? kTextWhite.withOpacity(0.9) : kTextGrey.withOpacity(0.7), fontSize: isSmallScreen ? 11 : 12)),
                          ],
                        ),
                      ),
                      if (isEnabled) const Positioned(top: 8, right: 8, child: Icon(Icons.check_circle, size: 14, color: kTextWhite)),
                    ],
                  ),
                ),
              );
            }).toList(),
            GestureDetector(
              onTap: showCustomReminderDialog,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kGlassBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline, color: kTextGrey, size: 24),
                    SizedBox(height: 4),
                    Text('Custom', style: TextStyle(color: kTextGrey, fontSize: isSmallScreen ? 13 : 14)),
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