import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Merged subscription for kcal, distance, and steps
  StreamSubscription<QuerySnapshot>?
      _todayStatsSubscription; 
  // Subscription for recent running records
  StreamSubscription<QuerySnapshot>? _recentRunsSubscription; 
  final List<Map<String, dynamic>> _recentRuns = [];
  double _totalKcal = 0;
  double _totalDistanceKm = 0;
  int _totalSteps = 0;
  bool _isLoading = true;
  String _currentDate = '';
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _currentDate = DateFormat('EEEE, dd MMMM').format(DateTime.now());
    _setupDataListeners(); // A unified method to set up all data listeners
  }

  @override
  void dispose() {
    // Cancel all active subscriptions to prevent memory leaks
    _todayStatsSubscription?.cancel();
    _recentRunsSubscription?.cancel();
    super.dispose();
  }

  void _setupDataListeners() {
    if (_userId == null) {
      setState(() {
        _isLoading = false;
      });
      print("User not logged in, cannot load data.");
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayStartTimestamp = todayStart.millisecondsSinceEpoch;
    final todayEndTimestamp = todayEnd.millisecondsSinceEpoch;

    bool allTodayStatsLoaded = false;
    bool allRecentRunsLoaded = false;

    // Listen for today's total calories, distance, and steps
    _todayStatsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('records')
        .where('timestamp', isGreaterThanOrEqualTo: todayStartTimestamp)
        .where('timestamp', isLessThan: todayEndTimestamp)
        .snapshots()
        .listen(
          (snapshot) {
        double currentTotalCalories = 0;
        double currentTotalDistance = 0;
        int currentTotalSteps = 0;

        print(
            '=== Debug: Found ${snapshot.docs.length} documents for today ===',
        );

        for (var doc in snapshot.docs) {
          final data = doc.data();
          print('Document ID: ${doc.id}');
          print('Raw data: $data');

          // Safely parse Calories
          final caloriesValue = data['calories'];
          if (caloriesValue is String) {
            currentTotalCalories += double.tryParse(caloriesValue) ?? 0.0;
          } else if (caloriesValue is num) {
            currentTotalCalories += caloriesValue.toDouble();
          }
          print(
              'Calories value: $caloriesValue (type: ${caloriesValue.runtimeType})',
          );

          // Safely parse Distance
          final distanceValue = data['distance_time_based_km'];
          print(
              'Distance raw value: $distanceValue (type: ${distanceValue.runtimeType})',
          );
          if (distanceValue is String) {
            final parsedDistance = double.tryParse(distanceValue) ?? 0.0;
            currentTotalDistance += parsedDistance;
            print('Distance parsed as String: $parsedDistance');
          } else if (distanceValue is num) {
            currentTotalDistance += distanceValue.toDouble();
            print('Distance parsed as num: ${distanceValue.toDouble()}');
          } else {
            currentTotalDistance += 0.0;
            print('Distance is null or unknown type, adding 0.0');
          }

          // Safely parse Steps
          final stepsValue = data['steps'];
          print(
              'Steps raw value: $stepsValue (type: ${stepsValue.runtimeType})',
          );
          if (stepsValue is String) {
            final parsedSteps = int.tryParse(stepsValue) ?? 0;
            currentTotalSteps += parsedSteps;
            print('Steps parsed as String: $parsedSteps');
          } else if (stepsValue is num) {
            currentTotalSteps += stepsValue.toInt();
          } else {
            currentTotalSteps += 0;
            print('Steps is null or unknown type, adding 0');
          }
        }

        print('=== Final totals ===');
        print('Total Calories: $currentTotalCalories');
        print('Total Distance: $currentTotalDistance');
        print('Total Steps: $currentTotalSteps');
        print('Today range: $todayStartTimestamp to $todayEndTimestamp');

        setState(() {
          _totalKcal = currentTotalCalories;
          _totalDistanceKm = currentTotalDistance;
          _totalSteps = currentTotalSteps;
          allTodayStatsLoaded = true;
          if (allRecentRunsLoaded) _isLoading = false;
        });
      },
      onError: (error) {
        print('Error listening to today stats: $error');
        setState(() {
          allTodayStatsLoaded = true;
          if (allRecentRunsLoaded) _isLoading = false;
        });
      },
    );

    // Listen for the 3 most recent running records
    _recentRunsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('records')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots()
        .listen(
          (snapshot) {
        final List<Map<String, dynamic>> loadedRuns = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final timestamp = data['timestamp'];
          final date =
          timestamp is int
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();
          final formattedDate = DateFormat('MMM d').format(date);

          double calories = 0.0;
          final caloriesValue = data['calories'];
          if (caloriesValue is String) {
            calories = double.tryParse(caloriesValue) ?? 0.0;
          } else if (caloriesValue is num) {
            calories = caloriesValue.toDouble();
          }

          final durationStr = data['duration']?.toString() ?? '00:00:00';

          String difficulty = '?'; // Default to '?' for unknown or pending

          // Core logic for determining difficulty, now includes a check for 'completed'
          final bool completed =
              data['completed'] ??
                  false; // Read the completed status from Firebase, defaults to false

          if (!completed) {
            difficulty = 'failed'; // If the run wasn't completed, set difficulty to 'failed'
          } else {
            final typeValue = data['type']?.toString().toLowerCase();
            final targetStr = data['target']?.toString().toLowerCase();

            if (typeValue == 'predefined' && targetStr != null) {
              // If it's a 'predefined' run, determine difficulty from the 'target' field
              if (targetStr.contains('easy')) {
                difficulty = 'easy';
              } else if (targetStr.contains('medium')) {
                difficulty = 'medium';
              } else if (targetStr.contains('hard')) {
                difficulty = 'hard';
              } else {
                // If the predefined target lacks a clear difficulty keyword, calculate based on duration
                difficulty = _getDifficultyFromDuration(durationStr);
              }
            } else if (typeValue == 'custom') {
              // If it's a 'custom' run, set difficulty to 'custom' directly
              difficulty = 'custom';
            } else {
              // For all other cases (e.g., type is missing), calculate based on duration
              difficulty = _getDifficultyFromDuration(durationStr);
            }
          }

          double? distance;
          final distanceValue = data['distance_time_based_km'];
          if (distanceValue is String) {
            distance = double.tryParse(distanceValue);
          } else if (distanceValue is num) {
            distance = distanceValue.toDouble();
          }
          // Ensure distance is not null
          distance = distance ?? 0.0;

          int? steps;
          final stepsValue = data['steps'];
          if (stepsValue is String) {
            steps = int.tryParse(stepsValue);
          } else if (stepsValue is num) {
            steps = stepsValue.toInt();
          }
          // Ensure steps is not null
          steps = steps ?? 0;

          loadedRuns.add({
            'date': formattedDate,
            'duration': durationStr,
            'difficulty': difficulty, // Pass the determined difficulty to loadedRuns
            'kcal': calories,
            'timestamp': timestamp,
            'distance': distance,
            'steps': steps,
          });
        }

        print('Loaded ${loadedRuns.length} recent records');
        setState(() {
          _recentRuns.clear();
          _recentRuns.addAll(loadedRuns);
          allRecentRunsLoaded = true;
          if (allTodayStatsLoaded) _isLoading = false;
        });
      },
      onError: (e) {
        print('Error loading recent workout records: $e');
        setState(() {
          allRecentRunsLoaded = true;
          if (allTodayStatsLoaded) _isLoading = false;
        });
      },
    );
  }

  // This function serves as a fallback: if no explicit difficulty field is retrieved from Firebase, it calculates it based on duration.
  String _getDifficultyFromDuration(String durationStr) {
    final durationParts = durationStr.split(':');
    if (durationParts.length != 3) return 'easy'; // Ensure the format is correct, otherwise default to 'easy'

    final hours = int.tryParse(durationParts[0]) ?? 0;
    final minutes = int.tryParse(durationParts[1]) ?? 0;
    final seconds = int.tryParse(durationParts[2]) ?? 0;

    final totalSeconds = hours * 3600 + minutes * 60 + seconds;

    // Redefining thresholds: these values are in seconds.
    // Based on your workout times, you can define the boundaries for Easy, Medium, and Hard.
    // Hard: Greater than or equal to 30 minutes (1800 seconds)
				
											  
    if (totalSeconds >= 1800) return 'hard';
    // Medium: Greater than or equal to 10 minutes (600 seconds)
    if (totalSeconds >= 600) return 'medium';
    // Easy: Less than 10 minutes
    return 'easy';
  }
}

@override
  Widget build(BuildContext context) {
    // Get the onSurface color from the current theme, which auto-adjusts for Light/Dark Mode
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<DocumentSnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  final data =
                      snapshot.data?.data() as Map<String, dynamic>? ??
                          {};
                  final name = data['name'] ?? 'User';
                  final photoUrl = data['photoUrl'] ?? '';

                  // User profile header
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage:
                            photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : const AssetImage(
                              'assets/images/profile.png',
                            )
                                as ImageProvider,
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello $name !',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Display the current date, adjusted for Dark Mode
                              Text(
                                _currentDate,
                                style: TextStyle(
                                  color: onSurfaceColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        onPressed: () {
                          Navigator.pushNamed(context, '/record');
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              // Display total calories
              Center(
                child: Column(
                  children: [
                    Text(
                      '${_totalKcal.toStringAsFixed(1)} Kcal',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Total Kilocalories Today',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              // Display dynamic stats for Distance, Steps, and Points
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
											
                  _StatItem(
                    label: 'Distance',
                    value: '${_totalDistanceKm.toStringAsFixed(2)} km',
                  ),
									   
                  _StatItem(
                    label: 'Steps',
                    value: '${_totalSteps} steps',
                  ),
																   
                  _StatItem(label: 'Points', value: '1 248'),
                ],
              ),

              const SizedBox(height: 24),
              // Card displaying current time and rank
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),

                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Current time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Times',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.alarm,
                              color: Colors.amber,
                              size: 28,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '4m 15s',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text('', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    // Right: Rank
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Rank',
                          style: TextStyle(
                            color: Colors.grey,

                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.emoji_events,

                              color: Colors.orange,

                              size: 28,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '#2',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section for recent runs
              const Text(
                'Recent Runs',

                style: TextStyle(
                  fontSize: 20,

                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const double fixedCardWidth = 120.0;
                    const double spacing = 8.0;

                    // Display static data if no user data is available
                    if (_recentRuns.isEmpty) {
                      return Row(
                        children: [
                          SizedBox(
                            width: fixedCardWidth,
                            child: const _RunCard(
                              date: '?',
                              duration: '?',
                              difficulty: '?',
                              kcal: 0.0,
                              distance: 0,
                              steps: 0,
                            ),
                          ),
                          const SizedBox(width: spacing),
                          SizedBox(
                            width: fixedCardWidth,
                            child: const _RunCard(
                              date: '?',
                              duration: '?',
                              difficulty: '?',
                              kcal: 0,
                              distance: 0,
                              steps: 0,
                            ),
                          ),
                          const SizedBox(width: spacing),
                          SizedBox(
                            width: fixedCardWidth,
                            child: const _RunCard(
                              date: '?',
                              duration: '?',
                              difficulty: '?',
                              kcal: 0,
                              distance: 0,
                              steps: 0,
                            ),
                          ),
                        ],
                      );
                    }

                    // Dynamically generate run cards from fetched data
                    final displayRuns = _recentRuns.take(3).toList();
                    final List<Widget> runCards = [];

                    for (int i = 0; i < displayRuns.length; i++) {
                      final run = displayRuns[i];
                      if (i > 0) {
                        runCards.add(const SizedBox(width: spacing));
                      }
                      runCards.add(
                        SizedBox(
                          width: fixedCardWidth,
                          child: _RunCard(
                            date: run['date'],
                            duration: run['duration'],
                            difficulty:
                            run['difficulty'],
                            kcal: run['kcal'].toDouble(),
                            distance: run['distance'] as double?,
                            steps: run['steps'] as int?,
                          ),
                        ),
                      );
                    }

                    // Fill remaining space with placeholder cards if fewer than 3 runs exist
																																 
                    if (displayRuns.length == 1) {
                      runCards.add(const SizedBox(width: spacing));
                      runCards.add(
                        SizedBox(
                          width: fixedCardWidth,
                          child: const _RunCard(
                            date: '?',
                            duration: '?',
                            difficulty: '?',
                            kcal: 0.0,
                            distance: 0,
                            steps: 0,
                          ),
                        ),
                      );
                      runCards.add(const SizedBox(width: spacing));
                      runCards.add(
                        SizedBox(
                          width: fixedCardWidth,
                          child: const _RunCard(
                            date: '?',
                            duration: '?',
                            difficulty: '?',
                            kcal: 0.0,
                            distance: 0,
                            steps: 0,
                          ),
                        ),
                      );
                    } else if (displayRuns.length == 2) {
                      runCards.add(const SizedBox(width: spacing));
                      runCards.add(
                        SizedBox(
                          width: fixedCardWidth,
                          child: const _RunCard(
                            date: '?',
                            duration: '?',
                            difficulty: '?',
                            kcal: 0.0,
                            distance: 0,
                            steps: 0,
                          ),
                        ),
                      );
                    }
                    return Row(children: runCards);
                  },
                ),
              ),
            ],
          ),
        ),
      ),

      // Main navigation bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,

        iconSize: 32,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        selectedIconTheme: const IconThemeData(size: 36),
        unselectedIconTheme: const IconThemeData(size: 28),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),

        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/team');
              break;
            case 1:
              Navigator.pushNamed(context, '/start');
              break;
            case 2:
            // Current page, no navigation needed
              break;
            case 3:
              Navigator.pushNamed(context, '/health');
              break;
            case 4:
              Navigator.pushNamed(context, '/setting');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Team'),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: 'Start',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Health'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  final String date;
  final String duration;
  final String difficulty;
  final double kcal;
  final double? distance;
  final int? steps;

  const _RunCard({
    required this.date,
    required this.duration,
    required this.difficulty,
    required this.kcal,
    this.distance,
    this.steps,
  });

  // Determine the background color based on the run's difficulty
  Color get _bgColor {
    switch (difficulty.toLowerCase()) {
      case 'failed':
        return Colors.red.withOpacity(0.1);
      case 'easy':
        return Colors.green.withOpacity(0.1);
      case 'medium':
        return Colors.yellow.withOpacity(0.1);
      case 'hard':
        return Colors.orange.withOpacity(0.1);
      case 'custom':
        return Colors.purple.withOpacity(0.1);
      case '?':
        return Colors.grey.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    switch (difficulty.toLowerCase()) {
      case 'failed':
        iconColor = Colors.red;
        break;
      case 'easy':
        iconColor = Colors.green;
        break;
      case 'medium':
        iconColor = Colors.lightBlue;
        break;
      case 'hard':
        iconColor = Colors.orange;
        break;
      case 'custom':
        iconColor = Colors.purple;
        break;
      case '?':
        iconColor = Colors.grey;
        break;
      default:
        iconColor = Colors.grey;
    }

    // Format kcal text, showing '?' if the value is 0.0
    String kcalText = (kcal == 0.0) ? '?' : '${kcal.toStringAsFixed(1)} kcal';

    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_run, size: 30, color: iconColor),
          const SizedBox(height: 8),
          Text(
            date,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          // Adjust TextStyle to use the theme's onSurface color for Dark Mode support
          Text(
            'Time : $duration',
            style: TextStyle(
												  
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 20,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 4),
												   
              Text(
                kcalText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          // Display distance if available
          if (distance != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.map, size: 20, color: Colors.blue),
                const SizedBox(width: 4),
																			   
                Expanded(
															  
                  child: Text(
                    (distance == 0.0)
                        ? '0.00 km'
                        : '${distance!.toStringAsFixed(2)} km',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ],
          // Display steps if available
          if (steps != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.alt_route, size: 20, color: Colors.purple),
                const SizedBox(width: 4),
													  
                Expanded(
															  
                  child: Text(
                    (steps == 0) ? '0 steps' : '${steps} steps',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              // Display 'UNKNOWN' for '?' difficulty, otherwise show uppercase difficulty
																			  
              (difficulty == '?') ? 'UNKNOWN' : difficulty.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                color: iconColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
		
