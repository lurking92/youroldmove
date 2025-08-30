import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/record.dart';

// Represents predefined workout duration goals.
enum PredefinedTarget { easy, medium, hard }

// Defines the type of the next workout target, either a predefined goal or a custom one.
enum NextTargetType { predefined, custom }

// A stateful widget to manage the workout timer and data.
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  _StartPageState createState() => _StartPageState();
}

// The State class for StartPage, managing all mutable data.
class _StartPageState extends State<StartPage> with WidgetsBindingObserver {
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  NextTargetType _nextTargetType = NextTargetType.predefined;
  PredefinedTarget _predefinedTarget = PredefinedTarget.easy;
  Duration _customTarget = const Duration(minutes: 01);
  double _weightKg = 60.0;
  bool _targetReached = false;
  bool _isWeightLoaded = false;
  bool _incompleteSaved = false;
  bool _completeSaved = false;

  String? _userId;

  // Average steps per minute for a very slow walking pace.
  final _stepsPerMinute = 30.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId != null) {
      _loadWeightFromFirestore();
    } else {
      _isWeightLoaded = true;
    }
    _resetSaveFlags();
  }

  // Resets the flags for saving incomplete and complete records.
  void _resetSaveFlags() {
    _incompleteSaved = false;
    _completeSaved = false;
  }

  // Fetches the user's weight from Firestore.
  Future<void> _loadWeightFromFirestore() async {
    if (_userId != null) {
      try {
        DocumentSnapshot doc =
            await FirebaseFirestore.instance
                .collection('healthData')
                .doc(_userId)
                .get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _weightKg =
                (doc.data() as Map<String, dynamic>)['weight'] as double? ??
                60.0;
            _isWeightLoaded = true;
          });
        } else {
          _isWeightLoaded = true;
        }
      } catch (e) {
        print("Error loading weight from Firestore: $e");
        _isWeightLoaded = true;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handles app lifecycle changes, pausing and resuming the timer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && _isRunning) {
      _startTime = DateTime.now().subtract(_elapsed);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      });
    }
  }

  // Starts or pauses the workout timer.
  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      _resetSaveFlags();
      _startTime = DateTime.now().subtract(_elapsed);
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _updateElapsed(),
      );
    }
    setState(() => _isRunning = !_isRunning);
  }

  // Updates the elapsed time and checks if the target has been reached.
  void _updateElapsed() {
    setState(() {
      _elapsed = DateTime.now().difference(_startTime!);
      if (_nextTargetType == NextTargetType.predefined) {
        _checkPredefinedTargetReached(_elapsed, _predefinedTarget);
      } else {
        _checkCustomTargetReached(_elapsed, _customTarget);
      }
    });
  }

  // Calculates calories burned based on elapsed time and weight.
  double _calculateCalories(Duration elapsed) {
    double metValue = 1.5; // Adjusted for a slower pace.
    double durationInHours =
        elapsed.inMinutes / 60.0 + elapsed.inSeconds / 3600.0;
    return metValue * _weightKg * durationInHours;
  }

  // Estimates distance traveled based on a fixed slow walking speed.
  double _calculateDistanceByTime(Duration elapsed) {
    const double walkingSpeedMetersPerSecond = 0.5; // Average walking speed for seniors.
    return elapsed.inSeconds * walkingSpeedMetersPerSecond / 1000; // Returns in kilometers.
  }

  // Estimates steps taken based on elapsed time and a low steps-per-minute rate.
  int _calculateSteps(Duration elapsed) {
    return (elapsed.inSeconds * (_stepsPerMinute / 60)).round();
  }

  // Provides a user-friendly string for predefined workout targets.
  String _predefinedTargetLabel(PredefinedTarget target) {
    switch (target) {
      case PredefinedTarget.easy:
        return 'Easy (20 min)';
      case PredefinedTarget.medium:
        return 'Medium (40 min)';
      case PredefinedTarget.hard:
        return 'Hard (60 min)';
    }
  }
}

  // A function to show a custom time picker using CupertinoTimerPicker.
void _showCustomTimePicker() {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext builder) {
      return SizedBox(
        height: MediaQuery.of(builder).size.height / 3,
        child: CupertinoTimerPicker(
          mode: CupertinoTimerPickerMode.hms,
          initialTimerDuration: _customTarget,
          onTimerDurationChanged: (Duration newDuration) {
            setState(() => _customTarget = newDuration);
          },
        ),
      );
    },
  );
}

// Resets the workout state, saves an incomplete record if necessary.
void _resetWorkout() {
  if (!_targetReached && !_incompleteSaved) {
    _saveRecordToFirestore(false);
    _incompleteSaved = true;
  }
  _timer?.cancel();
  setState(() {
    _elapsed = Duration.zero;
    _isRunning = false;
    _targetReached = false;
  });
}

// Saves the workout record to Firestore.
Future<void> _saveRecordToFirestore(bool completed) async {
  if (_userId != null) {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      String targetDescription = '';
      if (_nextTargetType == NextTargetType.predefined) {
        targetDescription = _predefinedTargetLabel(_predefinedTarget);
      } else {
        targetDescription = 'Custom: ${_formatDuration(_customTarget)}';
      }

      final recordData = {
        'type':
            _nextTargetType == NextTargetType.predefined
                ? 'predefined'
                : 'custom',
        'target': targetDescription,
        'duration': _formatDuration(_elapsed),
        'calories': _calculateCalories(_elapsed).toStringAsFixed(1),
        'distance_time_based_km': _calculateDistanceByTime(
          _elapsed,
        ).toStringAsFixed(2),
        'steps': _calculateSteps(_elapsed),
        'timestamp': now,
        'completed': completed,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('records')
          .add(recordData);
    } catch (e) {
      print('Error saving record: $e');
    }
  }
}

// Displays a modal popup for selecting a predefined workout target.
void _showPredefinedPicker() {
  showCupertinoModalPopup(
    context: context,
    builder:
        (_) => Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  scrollController: FixedExtentScrollController(
                    initialItem: PredefinedTarget.values.indexOf(
                      _predefinedTarget,
                    ),
                  ),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      _predefinedTarget = PredefinedTarget.values[index];
                    });
                  },
                  children:
                      PredefinedTarget.values
                          .map(
                            (e) => Text(
                              _predefinedTargetLabel(e),
                              style: TextStyle(
                                fontSize: 22,
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
  );
}

// Checks if the predefined target duration has been reached.
void _checkPredefinedTargetReached(
  Duration elapsed,
  PredefinedTarget target,
) {
  Duration targetDuration;
  switch (target) {
    case PredefinedTarget.easy:
      targetDuration = const Duration(minutes: 20);
      break;
    case PredefinedTarget.medium:
      targetDuration = const Duration(minutes: 40);
      break;
    case PredefinedTarget.hard:
      targetDuration = const Duration(hours: 1);
      break;
  }

  if (elapsed >= targetDuration && !_targetReached) {
    setState(() => _targetReached = true);
    _showCongratulationsDialog();
    _toggleTimer();
  }
}

// Checks if the custom target duration has been reached.
void _checkCustomTargetReached(Duration elapsed, Duration target) {
  if (elapsed >= target && !_targetReached) {
    setState(() {
      _targetReached = true;
    });
    _showCongratulationsDialog();
    _toggleTimer();
  }
}

// Displays a dialog to congratulate the user upon reaching their goal.
void _showCongratulationsDialog() {
  showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text("You've reached your goal!"),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                if (!_completeSaved) {
                  _saveRecordToFirestore(true);
                  _completeSaved = true;
                }
                _resetWorkout();
              },
            ),
          ],
        ),
  );
}

  String _formatDuration(Duration duration) {
    // Helper function to format a number with two digits
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    // Get minutes and seconds, formatted with two digits
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // Return formatted string in HH:MM:SS format
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // Check if the current theme is dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Calculate calories based on elapsed time
    final kcal = _calculateCalories(_elapsed);
    // Calculate distance based on elapsed time
    final distanceKmTimeBased = _calculateDistanceByTime(_elapsed);
    // Calculate total steps
    final totalSteps = _calculateSteps(_elapsed);

    return Scaffold(
      // Set background color based on theme
      backgroundColor: isDark ? Colors.black : Colors.orange[50],
      appBar: AppBar(
        title: const Text(
          'Slow Jog Timer',
          style: TextStyle(
            fontSize: 20, // Smaller font size
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.redAccent,
        elevation: 2, // Smaller shadow
        centerTitle: true,
        toolbarHeight: 60, // Smaller height
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 20.0,
        ), // Adjust overall padding
        child: Column(
          children: [
            // Timer card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20), // Adjust bottom margin
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDark
                          ? [Colors.grey.shade900, Colors.grey.shade800]
                          : [Colors.orange.shade100, Colors.orange.shade300],
                ),
                borderRadius: BorderRadius.circular(15), // Adjust border radius
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2), // Adjust shadow color and transparency
                    blurRadius: 10, // Adjust blur radius
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 25,
                horizontal: 20,
              ), // Adjust padding
              child: Column(
                children: [
                  Text(
                    _formatDuration(_elapsed),
                    style: TextStyle(
                      // Change color to black
                      fontSize: 55, // Smaller font size
                      fontWeight: FontWeight.w800, // Adjust font weight
                      color:
                          isDark ? Colors.white : Colors.black, // Change timer digit color to black
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12), // Adjust spacing
                  // Calorie display (format adjustment)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ), // Adjust padding
                    decoration: BoxDecoration(
                      color: Colors.orange.shade500, // Adjust background color
                      borderRadius: BorderRadius.circular(12), // Adjust border radius
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '${kcal.toStringAsFixed(1)} Kcal',
                      style: const TextStyle(
                        fontSize: 20, // Smaller font size
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10), // Add spacing
                  // Distance and steps displayed side-by-side
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // Center horizontally
                    children: [
                      // Distance display (new container style)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade500,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${distanceKmTimeBased.toStringAsFixed(2)} km',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20), // Increase spacing
                      // Step count display (new container style)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade500,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$totalSteps Steps', // Change label to 'Steps'
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Goal setting card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20), // Adjust padding
              margin: const EdgeInsets.only(bottom: 20), // Adjust bottom margin
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12), // Adjust border radius
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1.5,
                ), // Adjust border color and width
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Goal Type title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flag,
                        size: 24,
                        color: Colors.orange.shade600,
                      ), // Slightly larger icon
                      const SizedBox(width: 10), // Adjust spacing
                      Text(
                        'Goal Type',
                        style: TextStyle(
                          fontSize: 19, // Larger font size
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18), // Adjust spacing
                  // Left/right selection buttons (Predefined / Custom) - Integrated style
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _nextTargetType = NextTargetType.predefined;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color:
                                  _nextTargetType == NextTargetType.predefined
                                      ? Colors
                                          .orange
                                          .shade600 // Orange when selected
                                      : Colors.orange.shade200, // Darker orange when not selected
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // Consistent border radius with Kcal
                              border: Border.all(
                                color:
                                    _nextTargetType == NextTargetType.predefined
                                        ? Colors.orange.shade800
                                        : Colors.orange.shade400,
                                width: 1.5,
                              ),
                              boxShadow: [
                                // Add shadow to match Kcal style
                                BoxShadow(
                                  color: (_nextTargetType ==
                                              NextTargetType.predefined
                                          ? Colors.orange
                                          : Colors.grey)
                                      .withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Predefined',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black, // Fixed to black in normal mode
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _nextTargetType = NextTargetType.custom;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              color:
                                  _nextTargetType == NextTargetType.custom
                                      ? Colors.orange.shade600
                                      : Colors.orange.shade200,
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // Consistent border radius with Kcal
                              border: Border.all(
                                color:
                                    _nextTargetType == NextTargetType.custom
                                        ? Colors.orange.shade800
                                        : Colors.orange.shade400,
                                width: 1.5,
                              ),
                              boxShadow: [
                                // Add shadow to match Kcal style
                                BoxShadow(
                                  color: (_nextTargetType ==
                                              NextTargetType.custom
                                          ? Colors.orange
                                          : Colors.grey)
                                      .withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tune, size: 24, color: Colors.black),
                                const SizedBox(width: 8),
                                Text(
                                  'Custom',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black, // Fixed to black in normal mode
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_nextTargetType == NextTargetType.predefined)
                    Column(
                      children: [
                        Text(
                          'Current Difficulty:', // Predefined Time title
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          // Add a new Row to place Text and Button side by side
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              // Fix Easy/Medium/Hard container size
                              width: 190, // Increase width again
                              height: 60, // Increase height again
                              child: Container(
                                // Wrap the Text displaying current difficulty in a Container
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade500, // Same background color as Kcal button
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // Consistent border radius with Kcal
                                  boxShadow: [
                                    // Add shadow to match Kcal style
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: FittedBox(
                                  // Use FittedBox to ensure text fits the container
                                  fit: BoxFit.scaleDown, // Shrink text to fit, but don't enlarge
                                  child: Text(
                                    _predefinedTargetLabel(_predefinedTarget),
                                    style: TextStyle(
                                      fontSize: 22, // Adjust font size again
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10), // Adjust spacing
                            ElevatedButton(
                              onPressed: _showPredefinedPicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.orange.shade500, // Same background color as Kcal button
                                foregroundColor: Colors.black,
                                // Directly set fixedSize to control button width and height
                                fixedSize: const Size(
                                  150,
                                  60,
                                ), // Adjust width to 150, height to 60 consistent with SizedBox
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // Consistent border radius with Kcal
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'Set Difficulty', // Change button text to Set Difficulty
                                style: TextStyle(
                                  fontSize: 17.2, // Adjust font size again to fit new button size
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // Change text color to black
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                  if (_nextTargetType == NextTargetType.custom)
                    Column(
                      children: [
                        Text(
                          // Change font color to black
                          'Custom Time:',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? Colors.white
                                    : Colors.black, // Change Custom Time font color to black
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Custom Time display (integrated style)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade500, // Same background color as Kcal button
                                borderRadius: BorderRadius.circular(
                                  12,
                              ), // Consistent border radius with Kcal
                                boxShadow: [
                                  // Add shadow to match Kcal style
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _formatDuration(_customTarget),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            // Set Time button (integrated style)
                            ElevatedButton(
                              onPressed: _showCustomTimePicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.orange.shade500, // Same background color as Kcal button
                                foregroundColor: Colors.black, // Change text color to black
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 25,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // Consistent border radius with Kcal
                                ),
                                elevation: 3, // Keep shadow
                              ),
                              child: const Text(
                                'Set Time',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // Change Set Time font color to black
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Control buttons
            Row(
              children: [
                // START / PAUSE
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400, // Button color unified to orange
                        foregroundColor: Colors.black, // Change text color to black
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), // Adjust border radius
                        ),
                        elevation: 4, // Smaller shadow
                      ),
                      onPressed: _toggleTimer,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRunning ? Icons.pause_circle : Icons.play_circle,
                            size: 30, // Slightly larger icon
                            color: Colors.black, // Change START/PAUSE icon color to black
                          ),
                          const SizedBox(width: 10), // Adjust spacing
                          Text(
                            _isRunning ? 'PAUSE' : 'START',
                            style: const TextStyle(
                              fontSize: 19, // Larger font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ),
                ),
                const SizedBox(width: 15), // Adjust spacing
                // RESET
                Expanded(
                  child: SizedBox(
                    height: 60, // Slightly larger height
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400, // Button color unified to orange
                        foregroundColor: Colors.black, // Change text color to black
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), // Adjust border radius
                        ),
                        elevation: 4, // Smaller shadow
                      ),
                      onPressed: _resetWorkout,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restart_alt,
                            size: 28,
                            color: Colors.black, // Change RESET icon color to black
                          ), // Slightly larger icon
                          SizedBox(width: 10), // Adjust spacing
                          Text(
                            'RESET',
                            style: TextStyle(
                              fontSize: 19, // Larger font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ),
              ],
            ),

            const SizedBox(height: 25), // Adjust spacing
            // View records button
            SizedBox(
              width: double.infinity,
              height: 55, // Slightly larger height
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.orange.shade400,
                    width: 2,
                  ), // Adjust border color and width
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // Adjust border radius
                  ),
                  foregroundColor: Colors.orange.shade700, // Adjust text color
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecordPage(),
                    ), // Correctly navigate to RecordPage
                  );
                },
                child: const Text(
                  'VIEW RECORDS',
                  style: TextStyle(
                    fontSize: 18, // Smaller font size
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
