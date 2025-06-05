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
  StreamSubscription<QuerySnapshot>? _todayKcalSubscription;
  StreamSubscription<QuerySnapshot>? _runsSubscription;
  final List<Map<String, dynamic>> _recentRuns = [];
  double _totalKcal = 0;
  bool _isLoading = true;
  String _currentDate = '';
  String? _userId;
  // Add a stream subscription to update in real-time


  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _currentDate = DateFormat('EEEE, dd MMMM').format(DateTime.now());
    _setupRecentRunsListener();
  }

  @override
  void dispose() {
    _runsSubscription?.cancel();
    super.dispose();
    _todayKcalSubscription?.cancel();
  }
  void _setupRecentRunsListener() {
    if (_userId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayStartTimestamp = todayStart.millisecondsSinceEpoch;
    final todayEndTimestamp = todayEnd.millisecondsSinceEpoch;

    bool kcalLoaded = false;
    bool recentRunsLoaded = false;

    // Step 1: 計算今天總 kcal
    FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('records')
        .where('timestamp', isGreaterThanOrEqualTo: todayStartTimestamp)
        .where('timestamp', isLessThan: todayEndTimestamp)
        .snapshots()
        .listen(
          (snapshot) {
        double totalCaloriesToday = 0;
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final caloriesData = data['calories'];
          if (caloriesData is String) {
            totalCaloriesToday +=
                double.tryParse(caloriesData.replaceAll(' ', '')) ?? 0.0;
          } else if (caloriesData is num) {
            totalCaloriesToday += caloriesData.toDouble();
          }
        }
        print('Updated total kcal: $totalCaloriesToday');
        setState(() {
          _totalKcal = totalCaloriesToday;
          kcalLoaded = true;
          if (recentRunsLoaded) _isLoading = false;
        });
      },
      onError: (error) {
        print('Error listening to kcal changes: $error');
        kcalLoaded = true;
        if (recentRunsLoaded) {
          setState(() => _isLoading = false);
        }
      },
    );

    // Step 2: recent 3 runs listener
    final runsStream =
    FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('records')
        .orderBy('timestamp', descending: true)
        .limit(3)
        .snapshots();

    _runsSubscription = runsStream.listen(
          (snapshot) {
        final allRuns =
        snapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = data['timestamp'];
          final date =
          timestamp is int
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.now();
          final formattedDate = DateFormat('MMM d').format(date);
          final caloriesData = data['calories'];
          double calories = 0.0;
          if (caloriesData is String) {
            calories =
                double.tryParse(caloriesData.replaceAll(' ', '')) ?? 0.0;
          } else if (caloriesData is num) {
            calories = caloriesData.toDouble();
          }
          final durationStr = data['duration']?.toString() ?? '00:00:00';
          return {
            'date': formattedDate,
            'duration': durationStr,
            'difficulty': _getDifficultyFromDuration(durationStr),
            'kcal': calories,
            'timestamp': timestamp,
          };
        }).toList();

        print('Loaded ${allRuns.length} recent records');
        setState(() {
          _recentRuns.clear();
          _recentRuns.addAll(allRuns);
        });

        recentRunsLoaded = true;
        if (kcalLoaded) {
          setState(() {
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        print('Error loading recent workout records: $e');
        recentRunsLoaded = true;
        if (kcalLoaded) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  // Get difficulty level based on duration

  String _getDifficultyFromDuration(String durationStr) {
    final durationParts = durationStr.split(':');
    if (durationParts.length != 3) return 'Easy';
    final hours = int.tryParse(durationParts[0]) ?? 0;
    final minutesPart = int.tryParse(durationParts[1]) ?? 0;
    final minutes = hours * 60 + minutesPart;
    if (minutes >= 45) return 'Hard';
    if (minutes >= 25) return 'Medium';
    return 'Easy';
  }

  @override
  Widget build(BuildContext context) {
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
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot){
                  final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final name = data['name'] ?? 'User' ;
                  final photoUrl = data['photoUrl'] ?? '';

              // Header
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : const AssetImage('assets/images/profile.png') as ImageProvider,
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello $name !',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentDate,
                                style: TextStyle(color: Colors.grey[600]),
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
              // Calories - Using calculated total calories
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
              // Stats section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _StatItem(label: 'Distance', value: '7 580 m'),
                  _StatItem(label: 'Steps', value: '9 832'),
                  _StatItem(label: 'Points', value: '1 248'),
                ],
              ),

              const SizedBox(height: 24),
              // Current Points & Rank Card
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
                    // Left: Current Points
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Points',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),

                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 28,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '1 234',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text('pts', style: TextStyle(fontSize: 16)),
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
                              '#5',
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

              // Recent Runs Section - Using data loaded from Firebase
              const Text(
                'Recent Runs',

                style: TextStyle(
                  fontSize: 20,

                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Fix for line 513 in the LayoutBuilder
              LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing =
                      8.0 * 2; // Ensure this is explicitly a double
                  final double cardWidth =
                      (constraints.maxWidth - spacing) / 3;

                  // If no data or user not logged in, display static data
                  if (_recentRuns.isEmpty) {
                    return Row(
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: const _RunCard(
                            date: 'Jul 7',
                            duration: '00:30:00',
                            difficulty: 'Easy',
                            kcal: 300.0, // Make sure this is a double
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: cardWidth,
                          child: const _RunCard(
                            date: 'Jul 6',
                            duration: '00:35:00',
                            difficulty: 'Medium',
                            kcal: 380.0, // Make sure this is a double
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: cardWidth,
                          child: const _RunCard(
                            date: 'Jul 5',
                            duration: '00:25:00',
                            difficulty: 'Easy',
                            kcal: 260.0, // Make sure this is a double
                          ),
                        ),
                      ],
                    );
                  }

                  // Use Firebase loaded data - only take the first 3 runs
                  final displayRuns = _recentRuns.take(3).toList();
                  final List<Widget> runCards = [];

                  // Add dynamic data cards
                  for (int i = 0; i < displayRuns.length; i++) {
                    final run = displayRuns[i];
                    if (i > 0) {
                      runCards.add(const SizedBox(width: 8));
                    }
                    runCards.add(
                      SizedBox(
                        width: cardWidth,
                        child: _RunCard(
                          date: run['date'],
                          duration: run['duration'],
                          difficulty: run['difficulty'],
                          kcal:
                          run['kcal']
                              .toDouble(), // Ensure this is converted to double
                        ),
                      ),
                    );
                  }

                  // If fewer than 3 records, fill with static data
                  if (displayRuns.length == 1) {
                    runCards.add(const SizedBox(width: 8));
                    runCards.add(
                      SizedBox(
                        width: cardWidth,
                        child: const _RunCard(
                          date: 'Jul 6',
                          duration: '00:35:00',
                          difficulty: 'Medium',
                          kcal: 380.0,
                        ),
                      ),
                    );
                    runCards.add(const SizedBox(width: 8));
                    runCards.add(
                      SizedBox(
                        width: cardWidth,
                        child: const _RunCard(
                          date: 'Jul 5',
                          duration: '00:25:00',
                          difficulty: 'Easy',
                          kcal: 260.0,
                        ),
                      ),
                    );
                  } else if (displayRuns.length == 2) {
                    runCards.add(const SizedBox(width: 8));
                    runCards.add(
                      SizedBox(
                        width: cardWidth,
                        child: const _RunCard(
                          date: 'Jul 5',
                          duration: '00:25:00',
                          difficulty: 'Easy',
                          kcal: 260.0,
                        ),
                      ),
                    );
                  }
                  return Row(children: runCards);
                },
              ),
              const SizedBox(height: 24),
              // Plan Section
              const Text(
                'My Plan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'July, 2021',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('Training Plan Placeholder'),
                ),
              ),
            ],
          ),
        ),
      ),

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
  final dynamic kcal; // 修改為 dynamic 以接受不同型別

  const _RunCard({
    required this.date,
    required this.duration,
    required this.difficulty,
    required this.kcal,
  });

  Color get _bgColor {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.withOpacity(0.1);
      case 'medium':
        return Colors.orange.withOpacity(0.1);
      case 'hard':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
    difficulty.toLowerCase() == 'easy'
        ? Colors.green
        : difficulty.toLowerCase() == 'medium'
        ? Colors.orange
        : Colors.red;

    // 處理不同型別的 kcal 值
    String kcalText;
    if (kcal is double) {
      kcalText = '${kcal.toStringAsFixed(1)} kcal'; // 顯示一位小數
    } else {
      kcalText = 'N/A kcal'; // 如果是其他型別，顯示 N/A
    }

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
          Text(
            duration, // 顯示原始的時:分:秒格式
            style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                kcalText, // 使用處理後的 kcalText
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              difficulty,
              style: TextStyle(fontSize: 16, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}
