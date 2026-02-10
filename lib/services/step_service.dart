import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ========================================
/// STEP SERVICE - BACKGROUND STEP COUNTER
/// ========================================
/// 
/// This service handles persistent step counting that works even when:
/// - The app is closed
/// - The device is rebooted
/// - The app is in the background
/// 
/// Key Features:
/// - Automatic daily reset at midnight
/// - Persistent data storage
/// - Foreground service for Android
/// - Real-time step count updates
/// - Boot persistence
/// 
class StepService {
  // Singleton pattern - only one instance exists
  static final StepService instance = StepService._internal();
  StepService._internal();

  // Private variables
  StreamSubscription<StepCount>? _stepSubscription;
  int _todaySteps = 0;
  String _lastDate = '';
  int _initialStepCount = 0; // Stores the pedometer count at midnight for daily calculation

  // Public getter for current steps
  int get todaySteps => _todaySteps;

  /// ========================================
  /// INITIALIZATION
  /// ========================================
  /// 
  /// Initialize and start the step counting service
  /// 
  /// Parameters:
  /// - enableAndroidForeground: Whether to start foreground service (default: true)
  /// 
  Future<void> initAndStart({bool enableAndroidForeground = true}) async {
    try {
      debugPrint('🚀 Initializing Step Service...');
      
      // Load previously saved steps
      await _loadStepsFromPrefs();

      // Start foreground service for Android
      if (enableAndroidForeground) {
        await _initForegroundTask();
        await _startForegroundTask();
      }

      // Start listening to pedometer
      _listenToPedometer();
      
      debugPrint('✅ Step Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing Step Service: $e');
    }
  }

  /// ========================================
  /// FOREGROUND TASK SETUP
  /// ========================================
  /// 
  /// Initialize the foreground task configuration
  /// This creates a persistent notification and keeps the service alive
  /// 
  Future<void> _initForegroundTask() async {
    try {
      FlutterForegroundTask.init(
        // Android notification configuration
        androidNotificationOptions: AndroidNotificationOptions(
          // Notification channel settings
          channelId: 'step_counter_channel',
          channelName: 'Step Counter Service',
          channelDescription: 'Keeps step counting active in the background',
          channelImportance: NotificationChannelImportance.LOW,
          priority: NotificationPriority.LOW,
          
          // Show notification on lock screen
          visibility: NotificationVisibility.VISIBILITY_PUBLIC,
          
          // Optional: Add buttons to notification
          // buttons: [
          //   const NotificationButton(
          //     id: 'pause',
          //     text: 'Pause',
          //   ),
          // ],
        ),
        
        // iOS notification configuration
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        
        // Foreground task options
        foregroundTaskOptions: ForegroundTaskOptions(
          // Update notification every 5 seconds
          eventAction: ForegroundTaskEventAction.repeat(5000),
          
          // Auto-start service on device boot
          autoRunOnBoot: true,
          
          // Restart service when app is updated
          autoRunOnMyPackageReplaced: true,
          
          // Allow service to keep device awake
          allowWakeLock: true,
          
          // Don't keep WiFi on (battery saving)
          allowWifiLock: false,
        ),
      );
      
      debugPrint('✅ Foreground task initialized');
    } catch (e) {
      debugPrint('❌ Error initializing foreground task: $e');
    }
  }

  /// ========================================
  /// START FOREGROUND SERVICE
  /// ========================================
  /// 
  /// Starts the Android foreground service
  /// This creates the persistent notification
  /// 
  Future<void> _startForegroundTask() async {
    try {
      // Check if service is already running
      if (await FlutterForegroundTask.isRunningService) {
        debugPrint('ℹ️ Step service already running');
        return;
      }

      // Start the service
      final serviceStarted = await FlutterForegroundTask.startService(
        notificationTitle: 'Step Counter Active',
        notificationText: 'Tracking your steps in the background',
        callback: startCallback, // Top-level callback function
      );

      // Check if service started successfully using pattern matching
      if (serviceStarted is ServiceRequestSuccess) {
        debugPrint('✅ Step foreground service started successfully');
      } else {
        debugPrint('❌ Failed to start step foreground service');
      }
    } catch (e) {
      debugPrint('❌ Error starting foreground service: $e');
    }
  }

  /// ========================================
  /// PEDOMETER LISTENER
  /// ========================================
  /// 
  /// Listens to the device's step sensor and handles step counting logic
  /// 
  void _listenToPedometer() {
    try {
      // Cancel any existing subscription
      _stepSubscription?.cancel();
      
      // Start listening to step count stream
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          _handleStepCount(event);
        },
        onError: (error) {
          debugPrint('❌ Pedometer error: $error');
          // Handle common errors
          if (error.toString().contains('not available')) {
            debugPrint('⚠️ Step sensor not available on this device');
          }
        },
        cancelOnError: false, // Keep listening even if there's an error
      );

      debugPrint('✅ Pedometer listener started');
    } catch (e) {
      debugPrint('❌ Error starting pedometer listener: $e');
    }
  }

  /// ========================================
  /// STEP COUNT HANDLER
  /// ========================================
  /// 
  /// Processes incoming step count data from the pedometer
  /// Handles daily resets and step calculation
  /// 
  void _handleStepCount(StepCount event) {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Check if it's a new day
      if (_lastDate != today) {
        debugPrint('🔄 New day detected! Resetting step count.');
        debugPrint('   Previous date: $_lastDate');
        debugPrint('   Current date: $today');
        debugPrint('   Previous steps: $_todaySteps');
        
        // Reset for new day
        _initialStepCount = event.steps;
        _todaySteps = 0;
        _lastDate = today;
        _saveStepsToPrefs();
        
        debugPrint('   Initial count set to: $_initialStepCount');
      } else {
        // Same day - calculate steps since midnight
        
        // First time setup
        if (_initialStepCount == 0) {
          _initialStepCount = event.steps;
          debugPrint('🔢 Initial step count set: $_initialStepCount');
        }
        
        // Calculate today's steps
        _todaySteps = event.steps - _initialStepCount;
        
        // Handle device reboot (pedometer resets to 0 or small number)
        if (_todaySteps < 0 || event.steps < _initialStepCount) {
          debugPrint('⚠️ Pedometer reset detected (device reboot?)');
          debugPrint('   Resetting initial count to: ${event.steps}');
          _initialStepCount = event.steps;
          _todaySteps = 0;
        }
      }

      // Save current state
      _saveStepsToPrefs();

      // Update notification
      _updateNotification();
      
      // Debug log (comment out in production for performance)
      // debugPrint('👣 Steps: $_todaySteps (Raw: ${event.steps}, Initial: $_initialStepCount)');
      
    } catch (e) {
      debugPrint('❌ Error handling step count: $e');
    }
  }

  /// ========================================
  /// UPDATE NOTIFICATION
  /// ========================================
  /// 
  /// Updates the foreground service notification with current step count
  /// 
  Future<void> _updateNotification() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'Step Counter Active',
          notificationText: '$_todaySteps steps today 🚶',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating notification: $e');
    }
  }

  /// ========================================
  /// LOAD STEPS FROM STORAGE
  /// ========================================
  /// 
  /// Loads previously saved step data from SharedPreferences
  /// Handles daily reset if needed
  /// 
  Future<void> _loadStepsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];

      // Load saved values
      _lastDate = prefs.getString('step_last_date') ?? today;
      _todaySteps = prefs.getInt('step_count') ?? 0;
      _initialStepCount = prefs.getInt('step_initial_count') ?? 0;

      debugPrint('📂 Loading saved step data:');
      debugPrint('   Last date: $_lastDate');
      debugPrint('   Today\'s steps: $_todaySteps');
      debugPrint('   Initial count: $_initialStepCount');

      // Check if it's a new day
      if (_lastDate != today) {
        debugPrint('🔄 New day on load! Resetting step data.');
        _todaySteps = 0;
        _initialStepCount = 0;
        _lastDate = today;
        await _saveStepsToPrefs();
      }

      debugPrint('✅ Step data loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading step data: $e');
    }
  }

  /// ========================================
  /// SAVE STEPS TO STORAGE
  /// ========================================
  /// 
  /// Saves current step data to SharedPreferences
  /// 
  Future<void> _saveStepsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('step_last_date', _lastDate);
      await prefs.setInt('step_count', _todaySteps);
      await prefs.setInt('step_initial_count', _initialStepCount);
      
      // Debug log (comment out in production)
      // debugPrint('💾 Saved: $_todaySteps steps on $_lastDate (initial: $_initialStepCount)');
    } catch (e) {
      debugPrint('❌ Error saving step data: $e');
    }
  }

  /// ========================================
  /// STOP SERVICE
  /// ========================================
  /// 
  /// Stops the step counting service
  /// Useful for debugging or when user wants to pause tracking
  /// 
  Future<void> stopService() async {
    try {
      await _stepSubscription?.cancel();
      
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
        debugPrint('✅ Step service stopped');
      }
    } catch (e) {
      debugPrint('❌ Error stopping service: $e');
    }
  }

  /// ========================================
  /// RESTART SERVICE
  /// ========================================
  /// 
  /// Restarts the step counting service
  /// Useful if the service crashes or needs to be refreshed
  /// 
  Future<void> restartService() async {
    try {
      debugPrint('🔄 Restarting step service...');
      await stopService();
      await Future.delayed(const Duration(milliseconds: 500));
      await initAndStart(enableAndroidForeground: true);
      debugPrint('✅ Step service restarted');
    } catch (e) {
      debugPrint('❌ Error restarting service: $e');
    }
  }

  /// ========================================
  /// DISPOSE
  /// ========================================
  /// 
  /// Clean up resources
  /// 
  void dispose() {
    _stepSubscription?.cancel();
  }
}

/// ========================================
/// FOREGROUND TASK CALLBACK
/// ========================================
/// 
/// This MUST be a top-level function (not inside a class)
/// Called when the foreground service starts
/// 
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(StepTaskHandler());
}

/// ========================================
/// STEP TASK HANDLER
/// ========================================
/// 
/// Handles the background foreground task
/// Keeps the service alive and processes background events
/// 
class StepTaskHandler extends TaskHandler {
  
  /// Called when the task starts
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('✅ Step task handler started at $timestamp');
  }

  /// Called repeatedly (every 5 seconds as configured)
  /// This keeps the service alive
  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat to keep service alive
    // The actual step counting happens in the main isolate
    debugPrint('💓 Step service heartbeat: ${timestamp.toIso8601String()}');
    
    // Optional: Send data back to main app
    FlutterForegroundTask.sendDataToMain({
      'timestamp': timestamp.toIso8601String(),
      'status': 'running',
    });
  }

  /// Called when the task is destroyed
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('❌ Step task handler destroyed at $timestamp');
  }

  /// Called when a notification button is pressed
  @override
  void onNotificationButtonPressed(String id) {
    debugPrint('🔘 Notification button pressed: $id');
    
    // Handle button actions
    switch (id) {
      case 'pause':
        debugPrint('⏸️ Pause button pressed');
        // Implement pause logic here
        break;
      case 'resume':
        debugPrint('▶️ Resume button pressed');
        // Implement resume logic here
        break;
      default:
        debugPrint('Unknown button: $id');
    }
  }

  /// Called when the notification itself is pressed
  @override
  void onNotificationPressed() {
    debugPrint('🔔 Notification pressed - opening app');
    
    // Launch the app
    FlutterForegroundTask.launchApp();
  }
}