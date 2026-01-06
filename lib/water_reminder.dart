import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const WaterTrackerPage(),
    );
  }
}

class WaterTrackerPage extends StatefulWidget {
  const WaterTrackerPage({Key? key}) : super(key: key);

  @override
  State<WaterTrackerPage> createState() => _WaterTrackerPageState();
}

class _WaterTrackerPageState extends State<WaterTrackerPage> {
  int currentWater = 0;
  int targetWater = 2500;
  int quickAddAmount = 0;
  Set<String> selectedReminders = {};
  List<Map<String, String>> customReminders = [];
  final List<int> quickAddOptions = [150, 200, 300, 400, 500];

  void addWater() {
    setState(() {
      if (currentWater + quickAddAmount <= targetWater) {
        currentWater += quickAddAmount;
      } else {
        currentWater = targetWater;
      }
    });
  }

  void removeWater() {
    setState(() {
      if (currentWater - quickAddAmount >= 0) {
        currentWater -= quickAddAmount;
      } else {
        currentWater = 0;
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

  void showQuickAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFB8B3E8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Amount',
                style: TextStyle(
                  color: Color(0xFF0D2F5C),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              ...quickAddOptions.map((amount) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      quickAddAmount = amount;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: quickAddAmount == amount
                          ? Colors.white.withOpacity(0.3)
                          : Colors.transparent,
                    ),
                    child: Text(
                      '${amount}ml',
                      style: TextStyle(
                        color: const Color(0xFF0D2F5C),
                        fontSize: 16,
                        fontWeight: quickAddAmount == amount
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0D2F5C),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.05,
              vertical: size.height * 0.02,
            ),
            child: Column(
              children: [
                // Title
                Text(
                  "Today's Hydration",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 22 : 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: size.height * 0.03),
                
                // Water Progress Circle with Wave
                _buildWaterProgress(size, isSmallScreen),
                SizedBox(height: size.height * 0.03),
                
                // Quick Add Section
                _buildQuickAddSection(size, isSmallScreen),
                SizedBox(height: size.height * 0.02),
                
                // Weekly Hydration Plan
                _buildWeeklyPlanCard(size, isSmallScreen),
                SizedBox(height: size.height * 0.02),
                
                // Set Reminder Section
                _buildReminderSection(isSmallScreen),
                SizedBox(height: size.height * 0.02),
              ],
            ),
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
          child: Container(
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
          ],
        ),
        // Set target button with bottle icon
        Positioned(
          right: -5,
          bottom: circleSize * 0.15,
          child: GestureDetector(
            onTap: showSetTargetDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2F5C),
                borderRadius: BorderRadius.circular(12),
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
                      fontSize: isSmallScreen ? 10 : 11,
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

  Widget _buildWeeklyPlanCard(Size size, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(size.width * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFB8B3E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Hydration Plan',
                  style: TextStyle(
                    color: const Color(0xFF0D2F5C),
                    fontSize: isSmallScreen ? 15 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan your hydration for the week',
                  style: TextStyle(
                    color: const Color(0xFF4A4A7E),
                    fontSize: isSmallScreen ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: const Color(0xFF0D2F5C),
            size: isSmallScreen ? 24 : 28,
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

// Custom painter for wave decoration
class WavePainter extends CustomPainter {
  final bool isLeft;

  WavePainter({required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5DC0F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final path = Path();

    if (isLeft) {
      path.moveTo(size.width, 0);
      path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.15,
        size.width, size.height * 0.3,
      );
      path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.45,
        size.width, size.height * 0.6,
      );
      path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.75,
        size.width, size.height * 0.9,
      );
    } else {
      path.moveTo(0, 0);
      path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.15,
        0, size.height * 0.3,
      );
      path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.45,
        0, size.height * 0.6,
      );
      path.quadraticBezierTo(
        size.width * 0.5, size.height * 0.75,
        0, size.height * 0.9,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}