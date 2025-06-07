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
  StreamSubscription<QuerySnapshot>?
  _todayStatsSubscription; // 合併 kcal, distance, steps 的訂閱
  StreamSubscription<QuerySnapshot>? _recentRunsSubscription; // 最近跑步紀錄的訂閱
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
    _setupDataListeners(); // 統一設置所有數據監聽器
  }

  @override
  void dispose() {
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

    // 監聽今天的總卡路里、距離和步數
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

              // 安全解析 Calories
              final caloriesValue = data['calories'];
              if (caloriesValue is String) {
                currentTotalCalories += double.tryParse(caloriesValue) ?? 0.0;
              } else if (caloriesValue is num) {
                currentTotalCalories += caloriesValue.toDouble();
              }
              print(
                'Calories value: $caloriesValue (type: ${caloriesValue.runtimeType})',
              );

              // 安全解析 Distance
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

              // 安全解析 Steps
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

    // 監聽最近 3 筆跑步紀錄
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

              String difficulty = '?'; // 預設為 '?'，表示未知或待定

              // **核心修正：難度判斷邏輯再次優化，新增 completed 判斷**
              final bool completed =
                  data['completed'] ??
                  false; // 從 Firebase 讀取 completed 狀態，預設為 false

              if (!completed) {
                difficulty = 'failed'; // 如果未完成，直接設定為 'failed'
              } else {
                final typeValue = data['type']?.toString().toLowerCase();
                final targetStr = data['target']?.toString().toLowerCase();

                if (typeValue == 'predefined' && targetStr != null) {
                  // 如果是 'predefined' 類型，則根據 'target' 欄位判斷難度
                  if (targetStr.contains('easy')) {
                    difficulty = 'easy';
                  } else if (targetStr.contains('medium')) {
                    difficulty = 'medium';
                  } else if (targetStr.contains('hard')) {
                    difficulty = 'hard';
                  } else {
                    // 如果 predefined 的 target 中沒有明確的難度關鍵字，則根據 duration 計算
                    difficulty = _getDifficultyFromDuration(durationStr);
                  }
                } else if (typeValue == 'custom') {
                  // 如果是 'custom' 類型，則直接設定為 'custom'
                  difficulty = 'custom';
                } else {
                  // 其他所有情況（如 type 不存在或不為 predefined/custom），都根據 duration 計算
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
              // 確保 distance 不為 null
              distance = distance ?? 0.0;

              int? steps;
              final stepsValue = data['steps'];
              if (stepsValue is String) {
                steps = int.tryParse(stepsValue);
              } else if (stepsValue is num) {
                steps = stepsValue.toInt();
              }
              // 確保 steps 不為 null
              steps = steps ?? 0;

              loadedRuns.add({
                'date': formattedDate,
                'duration': durationStr,
                'difficulty': difficulty, // 將讀取或判斷到的難度傳遞給 loadedRuns
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

  // 此函數作為備用，如果從 Firebase 獲取不到明確的難度欄位，則根據 duration 計算
  String _getDifficultyFromDuration(String durationStr) {
    final durationParts = durationStr.split(':');
    if (durationParts.length != 3) return 'easy'; // 確保格式正確，否則預設為 easy

    final hours = int.tryParse(durationParts[0]) ?? 0;
    final minutes = int.tryParse(durationParts[1]) ?? 0;
    final seconds = int.tryParse(durationParts[2]) ?? 0;

    final totalSeconds = hours * 3600 + minutes * 60 + seconds;

    // **重新調整閾值：這些數字是秒數**
    // 根據您的實際運動時間來定義 Easy, Medium, Hard 的界線。
    // 考慮到您有 1 分鐘甚至 5 秒的記錄，我們需要更細緻的劃分。
    // 建議：
    // Hard: 大於等於 30 分鐘 (1800 秒)
    if (totalSeconds >= 1800) return 'hard';
    // Medium: 大於等於 10 分鐘 (600 秒)
    if (totalSeconds >= 600) return 'medium';
    // Easy: 低於 10 分鐘
    return 'easy';
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

                          // Header
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
                                      Text(
                                        _currentDate,
                                        style: TextStyle(color: Colors.black),
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
                      // Stats section - Dynamic data for Distance and Steps
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 使用 _totalDistanceKm
                          _StatItem(
                            label: 'Distance',
                            value: '${_totalDistanceKm.toStringAsFixed(2)} km',
                          ),
                          // 使用 _totalSteps
                          _StatItem(
                            label: 'Steps',
                            value: '${_totalSteps} steps',
                          ),
                          // Points 保持靜態或根據實際情況調整
                          const _StatItem(label: 'Points', value: '1 248'),
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

                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double spacing = 8.0 * 2;
                          final double cardWidth =
                              (constraints.maxWidth - spacing) / 3;

                          // If no data or user not logged in, display static data
                          if (_recentRuns.isEmpty) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: cardWidth,
                                  child: const _RunCard(
                                    date: '?',
                                    duration: '?',
                                    difficulty: '?', // 預設為 '?'
                                    kcal: 0.0,
                                    distance: 0,
                                    steps: 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: cardWidth,
                                  child: const _RunCard(
                                    date: '?',
                                    duration: '?',
                                    difficulty: '?', // 預設為 '?'
                                    kcal: 0,
                                    distance: 0,
                                    steps: 0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: cardWidth,
                                  child: const _RunCard(
                                    date: '?',
                                    duration: '?',
                                    difficulty: '?', // 預設為 '?'
                                    kcal: 0,
                                    distance: 0,
                                    steps: 0,
                                  ),
                                ),
                              ],
                            );
                          }

                          final displayRuns = _recentRuns.take(3).toList();
                          final List<Widget> runCards = [];

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
                                  difficulty:
                                      run['difficulty'], // 直接使用從 Firebase 讀取到的難度
                                  kcal: run['kcal'].toDouble(),
                                  distance: run['distance'] as double?,
                                  steps: run['steps'] as int?,
                                ),
                              ),
                            );
                          }

                          // If fewer than 3 records, fill with static data (同時更新難度)
                          // 根據您的需求，將這些靜態數據的 difficulty 也設為 '?'，讓使用者知道這是空數據
                          if (displayRuns.length == 1) {
                            runCards.add(const SizedBox(width: 8));
                            runCards.add(
                              SizedBox(
                                width: cardWidth,
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
                            runCards.add(const SizedBox(width: 8));
                            runCards.add(
                              SizedBox(
                                width: cardWidth,
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
                            runCards.add(const SizedBox(width: 8));
                            runCards.add(
                              SizedBox(
                                width: cardWidth,
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

  Color get _bgColor {
    switch (difficulty.toLowerCase()) {
      case 'failed':
        return Colors.red.withOpacity(0.1); // 未完成為紅色
      case 'easy':
        return Colors.green.withOpacity(0.1);
      case 'medium':
        return Colors.yellow.withOpacity(0.1); // Medium 改為黃色
      case 'hard':
        return Colors.orange.withOpacity(0.1); // Hard 改為橘色
      case 'custom':
        return Colors.purple.withOpacity(0.1); // Custom 為紫色
      case '?':
        return Colors.grey.withOpacity(0.1); // 未知為灰色
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    switch (difficulty.toLowerCase()) {
      case 'failed':
        iconColor = Colors.red; // 未完成為紅色
        break;
      case 'easy':
        iconColor = Colors.green;
        break;
      case 'medium':
        iconColor = Colors.yellow; // Medium 改為黃色
        break;
      case 'hard':
        iconColor = Colors.orange; // Hard 改為橘色
        break;
      case 'custom':
        iconColor = Colors.purple; // Custom 為紫色
        break;
      case '?':
        iconColor = Colors.grey; // 未知為灰色
        break;
      default:
        iconColor = Colors.grey;
    }

    // 處理當 kcal 為 0 時的顯示
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
          Text(
            'Time : $duration',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
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
                kcalText, // 使用處理過後的 kcalText
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          // **修正：距離為 0 時也要顯示**
          if (distance != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.map, size: 20, color: Colors.blue),
                const SizedBox(width: 4),
                Text(
                  (distance == 0.0)
                      ? '0.0 km'
                      : '${distance!.toStringAsFixed(2)} km', // 如果為0則顯示?
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          // **修正：步數為 0 時也要顯示**
          if (steps != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.alt_route, size: 20, color: Colors.purple),
                const SizedBox(width: 4),
                Text(
                  (steps == 0) ? '0' : '${steps} steps', // 如果為0則顯示?
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
              // 如果 difficulty 是 '?' 或 null，則顯示 'UNKNOWN' 或保持 '?'
              // 否則顯示大寫的難度，如果 'failed' 顯示 'FAILED'
              (difficulty == '?') ? 'UNKNOWN' : difficulty.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
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
