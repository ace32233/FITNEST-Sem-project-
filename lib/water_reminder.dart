import 'package:fittness_app/home_page.dart';
import 'package:flutter/material.dart';
import 'calorie_page.dart';

class WaterTrackerPage extends StatefulWidget {
  const WaterTrackerPage({Key? key}) : super(key: key);

  @override
  State<WaterTrackerPage> createState() => _WaterTrackerPageState();
}

class _WaterTrackerPageState extends State<WaterTrackerPage> {
  int currentWater = 0;
  int targetWater = 2500;
  int quickAddAmount = 50;
  Set<String> selectedReminders = {};
  List<Map<String, String>> customReminders = [];

  void addWater() {
    setState(() {
      if (currentWater + quickAddAmount <= targetWater) {
        currentWater += quickAddAmount;
      } else {
        currentWater = targetWater;
      }
    });
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
              onPressed: () {
                setState(() {
                  targetWater = int.tryParse(controller.text) ?? targetWater;
                  if (currentWater > targetWater) {
                    currentWater = targetWater;
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Set'),
            ),
          ],
        );
      },
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
                            return ListTile(
                              title: Text(customReminders[index]['label']!),
                              subtitle: Text(customReminders[index]['time']!),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedReminders.remove('custom_$index');
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
                          setDialogState(() {
                            customReminders.add({
                              'label': 'Custom',
                              'time': picked.format(context),
                            });
                          });
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

  void resetProgress() {
    setState(() {
      currentWater = 0;
    });
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
                    // TODO: Navigate to exercise input screen
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D2F5C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2F5C),
        elevation: 0,
        title: Text(
          "Today's Hydration",
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 20 : 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: resetProgress,
            tooltip: 'Reset Progress',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.05,
              vertical: size.height * 0.02,
            ),
            child: Column(
              children: [
                // Water Progress Circle
                _buildWaterProgress(size, isSmallScreen),
                SizedBox(height: size.height * 0.03),
                
                // Quick Add Section
                _buildQuickAddSection(size, isSmallScreen),
                SizedBox(height: size.height * 0.02),
                
                // Set Reminder Section
                _buildReminderSection(isSmallScreen),
                SizedBox(height: size.height * 0.1),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        onPressed: _showAddDialog,
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1E293B),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: Colors.blue, size: 28),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(
                        builder: (_) => HomePage(),
                      ),);
                },
              ),
              const SizedBox(width: 40), // Space for FAB
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white, size: 28),
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

  Widget _buildWaterProgress(Size size, bool isSmallScreen) {
    double progress = currentWater / targetWater;
    double circleSize = size.width * 0.55;
    if (circleSize > 280) circleSize = 280;
    if (circleSize < 200) circleSize = 200;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Background circle with border
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
          ),
        ),
        // Progress circle (water fill)
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
                  child: Container(
                    height: circleSize * progress,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5DC0F0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Text overlay
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentWater}ml',
              style: TextStyle(
                color: Colors.black,
                fontSize: isSmallScreen ? 36 : 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '/${targetWater}ml',
              style: TextStyle(
                color: Colors.black,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.black54,
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        // Set target button with bottle icon
        Positioned(
          right: -5,
          bottom: circleSize * 0.15,
          child: GestureDetector(
            onTap: showSetTargetDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2F5C),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_drink,
                    color: Colors.white,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Set target',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildQuickAddSection(Size size, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: size.width * 0.04,
        vertical: size.height * 0.018,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFB8B3E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Quick Add',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF0D2F5C),
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: size.height * 0.012),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minus button - decrease amount by 50ml
              GestureDetector(
                onTap: decreaseQuickAddAmount,
                child: Container(
                  width: isSmallScreen ? 45 : 50,
                  height: isSmallScreen ? 45 : 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.remove,
                    color: Color(0xFF0D2F5C),
                    size: 28,
                  ),
                ),
              ),
              SizedBox(width: size.width * 0.04),
              // Amount display - tappable to add water
              GestureDetector(
                onTap: addWater,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.08,
                    vertical: size.height * 0.012,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B72C8),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Text(
                    '${quickAddAmount}ml',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 18 : 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: size.width * 0.04),
              // Plus button - increase amount by 50ml
              GestureDetector(
                onTap: increaseQuickAddAmount,
                child: Container(
                  width: isSmallScreen ? 45 : 50,
                  height: isSmallScreen ? 45 : 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Color(0xFF0D2F5C),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection(bool isSmallScreen) {
    final reminders = [
      {'id': 'morning_7', 'label': 'Morning', 'time': '7 am'},
      {'id': 'noon_11', 'label': 'Noon', 'time': '11 am'},
      {'id': 'afternoon_2', 'label': 'Afternoon', 'time': '2 pm'},
      {'id': 'afternoon_4', 'label': 'Afternoon', 'time': '4 pm'},
      {'id': 'evening_7', 'label': 'Evening', 'time': '7 pm'},
      {'id': 'custom', 'label': 'Custom', 'time': ''},
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: MediaQuery.of(context).size.height * 0.025,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFB8B3E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Reminder',
            style: TextStyle(
              color: const Color(0xFF0D2F5C),
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.015),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: reminders.map((reminder) {
              final isSelected = selectedReminders.contains(reminder['id']);
              final isCustom = reminder['id'] == 'custom';
              
              return GestureDetector(
                onTap: () {
                  if (isCustom) {
                    showCustomReminderDialog();
                  } else {
                    setState(() {
                      if (selectedReminders.contains(reminder['id'])) {
                        selectedReminders.remove(reminder['id']);
                      } else {
                        selectedReminders.add(reminder['id']!);
                      }
                    });
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isCustom 
                        ? const Color(0xFF5865A1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected && !isCustom
                        ? Border.all(color: const Color(0xFF5865A1), width: 2.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        reminder['label']!,
                        style: TextStyle(
                          color: isCustom
                              ? Colors.white
                              : const Color(0xFF0D2F5C),
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (reminder['time']!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          reminder['time']!,
                          style: TextStyle(
                            color: isCustom 
                                ? Colors.white70
                                : const Color(0xFF6B6B9E),
                            fontSize: isSmallScreen ? 11 : 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}