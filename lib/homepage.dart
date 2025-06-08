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

class _HomePageState extends State<HomePage> { // <-- 移除 with WidgetsBindingObserver
  StreamSubscription<QuerySnapshot>? _todayStatsSubscription;
  StreamSubscription<QuerySnapshot>? _recentRunsSubscription;

  final List<Map<String, dynamic>> _recentRuns = [];
  Map<String, Map<String, dynamic>> _userTeamRanks = {};

  double _totalKcal = 0;
  double _totalDistanceKm = 0;
  int _totalSteps = 0;
  bool _isLoading = true;
  String _currentDate = '';
  String? _userId;

  // --- 定義一個 Future 來載入團隊排名數據，用於 FutureBuilder ---
  Future<Map<String, Map<String, dynamic>>>? _teamRanksFuture;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _currentDate = DateFormat('EEEE, dd MMMM').format(DateTime.now());
    _setupDataListeners();
    // 首次載入時啟動載入團隊排名的 Future
    _teamRanksFuture = _loadUserTeamRanks();
  }

  @override
  void dispose() {
    _todayStatsSubscription?.cancel();
    _recentRunsSubscription?.cancel();
    super.dispose();
  }

  // 將獲取團隊排名數據的邏輯單獨提取出來
  // 現在返回 Map<String, Map<String, dynamic>>
  Future<Map<String, Map<String, dynamic>>> _loadUserTeamRanks() async {
    if (_userId == null) {
      print("User not logged in, cannot load team ranks.");
      return {};
    }

    print('--- Start Loading User Team Ranks Manually ---'); // Debug
    print('Current User ID for team ranks: $_userId'); // Debug

    final userDocSnapshot = await FirebaseFirestore.instance.collection('users').doc(_userId).get();

    if (!userDocSnapshot.exists) {
      print("User document for team rank tracking does not exist.");
      return {};
    }

    final userData = userDocSnapshot.data();
    final List<String> joinedTeamIds = List<String>.from(userData?['joinedTeamIds'] ?? []);
    print('Joined Team IDs: $joinedTeamIds'); // Debug

    if (joinedTeamIds.isEmpty) {
      print("User is not part of any teams. _userTeamRanks is empty.");
      return {};
    }

    final Map<String, Map<String, dynamic>> loadedRanks = {};

    for (final teamId in joinedTeamIds) {
      print('Processing Team ID: $teamId'); // Debug
      try {
        final teamDoc = await FirebaseFirestore.instance.collection('teams').doc(teamId).get();
        if (teamDoc.exists) {
          final teamData = teamDoc.data();
          final teamName = teamData?['teamName'] ?? 'Unnamed Team';
          final List<String> memberIds = List<String>.from(teamData?['memberIds'] ?? []);
          print('Team "$teamName" member IDs: $memberIds'); // Debug

          List<Map<String, dynamic>> teamMembersData = [];

          for (final memberId in memberIds) {
            int totalDurationSeconds = 0;
            final memberRecordsSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(memberId)
                .collection('records')
                .where('completed', isEqualTo: true)
                .get();

            for (var recordDoc in memberRecordsSnapshot.docs) {
              final recordData = recordDoc.data();
              final durationString = recordData['duration'] as String? ?? '00:00:00';
              totalDurationSeconds += _durationToSeconds(durationString);
            }
            print('  Member $memberId: Total duration (seconds): $totalDurationSeconds'); // Debug

            teamMembersData.add({
              'userId': memberId,
              'totalExerciseSeconds': totalDurationSeconds,
            });
          }

          teamMembersData.sort((a, b) {
            final durationA = a['totalExerciseSeconds'] as int? ?? 0;
            final durationB = b['totalExerciseSeconds'] as int? ?? 0;
            return durationB.compareTo(durationA);
          });
          print('Sorted Team Members Data for "$teamName": $teamMembersData'); // Debug

          int userRank = 0;
          String userTotalTime = 'N/A';
          for (int i = 0; i < teamMembersData.length; i++) {
            if (teamMembersData[i]['userId'] == _userId) {
              userRank = i + 1;
              userTotalTime = _formatDuration(teamMembersData[i]['totalExerciseSeconds']);
              break;
            }
          }

          if (userRank > 0) {
            loadedRanks[teamId] = {
              'teamName': teamName,
              'rank': userRank,
              'time': userTotalTime,
            };
            print('  Added rank for user in "$teamName": Rank $userRank, Time $userTotalTime'); // Debug
          } else {
            print('  User has no completed record in "$teamName" for ranking, or is not in sorted list.'); // Debug
          }

        } else {
          print('Team document $teamId does not exist.'); // Debug
        }
      } catch (e) {
        print('Error loading team or member records for team $teamId: $e'); // Debug
      }
    }
    print('--- End Loading User Team Ranks Manually ---'); // Debug
    return loadedRanks; // 返回結果
  }

  void _setupDataListeners() {
    print('User ID from FirebaseAuth: ${FirebaseAuth.instance.currentUser?.uid}');
    _userId = FirebaseAuth.instance.currentUser?.uid;

    if (_userId == null) {
      setState(() {
        _isLoading = false;
      });
      print("User not logged in, cannot load data. _userId is null.");
      return;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayStartTimestamp = todayStart.millisecondsSinceEpoch;
    final todayEndTimestamp = todayEnd.millisecondsSinceEpoch;

    bool allTodayStatsLoaded = false;
    bool allRecentRunsLoaded = false;
    // 這裡不再需要 allUserTeamRanksLoaded，因為 FutureBuilder 會管理
    // bool allUserTeamRanksLoaded = false;

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
          final caloriesValue = data['calories'];
          if (caloriesValue is String) {
            currentTotalCalories += double.tryParse(caloriesValue) ?? 0.0;
          } else if (caloriesValue is num) {
            currentTotalCalories += caloriesValue.toDouble();
          }

          final distanceValue = data['distance_time_based_km'];
          if (distanceValue is String) {
            currentTotalDistance += double.tryParse(distanceValue) ?? 0.0;
          } else if (distanceValue is num) {
            currentTotalDistance += distanceValue.toDouble();
          }

          final stepsValue = data['steps'];
          if (stepsValue is String) {
            currentTotalSteps += int.tryParse(stepsValue) ?? 0;
          } else if (stepsValue is num) {
            currentTotalSteps += stepsValue.toInt();
          }
        }

        setState(() {
          _totalKcal = currentTotalCalories;
          _totalDistanceKm = currentTotalDistance;
          _totalSteps = currentTotalSteps;
          allTodayStatsLoaded = true;
          // 這裡的 _isLoading 判斷不再考慮 allUserTeamRanksLoaded，因為它由 FutureBuilder 管理
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
          final date = timestamp is int
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

          String difficulty = '?';
          final bool completed = data['completed'] ?? false;

          if (!completed) {
            difficulty = 'failed';
          } else {
            final typeValue = data['type']?.toString().toLowerCase();
            final targetStr = data['target']?.toString().toLowerCase();

            if (typeValue == 'predefined' && targetStr != null) {
              if (targetStr.contains('easy')) {
                difficulty = 'easy';
              } else if (targetStr.contains('medium')) {
                difficulty = 'medium';
              } else if (targetStr.contains('hard')) {
                difficulty = 'hard';
              } else {
                difficulty = _getDifficultyFromDuration(durationStr);
              }
            } else if (typeValue == 'custom') {
              difficulty = 'custom';
            } else {
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
          distance = distance ?? 0.0;

          int? steps;
          final stepsValue = data['steps'];
          if (stepsValue is String) {
            steps = int.tryParse(stepsValue);
          } else if (stepsValue is num) {
            steps = stepsValue.toInt();
          }
          steps = steps ?? 0;

          loadedRuns.add({
            'date': formattedDate,
            'duration': durationStr,
            'difficulty': difficulty,
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

    // _isLoading 的初始狀態處理
    // 這裡的 _isLoading 設置在 _todayStatsSubscription 和 _recentRunsSubscription 兩個Stream 的 onListen 回調中，
    // 但是 _teamRanksFuture 的載入是獨立的。
    // 為了確保首次載入的完整性，我們可以在 initState 中就將 _isLoading 設為 true，
    // 然後在 _todayStatsSubscription 和 _recentRunsSubscription 的 setState 中取消它。
    // FutureBuilder 自己會處理團隊排名的 loading 狀態。
    // 如果您在 `_setupDataListeners` 之外還有其他需要 _isLoading 監控的異步操作，可能需要調整。
    // 目前的調整是讓 FutureBuilder 管理 _teamRanksFuture 的狀態。
  }

  // 將 "HH:mm:ss" 格式的字串轉換為總秒數
  int _durationToSeconds(String durationString) {
    try {
      final parts = durationString.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return hours * 3600 + minutes * 60 + seconds;
      }
    } catch (e) {
      print('Error parsing duration string: $durationString, Error: $e');
    }
    return 0; // 解析失敗或格式不符則返回 0
  }

  // 將總秒數轉換為易讀的 "HH小時 MM分鐘 SS秒" 格式
  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return '0秒';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}小時 ${minutes}分 ${seconds}秒';
    } else if (minutes > 0) {
      return '${minutes}分 ${seconds}秒';
    } else {
      return '${seconds}秒';
    }
  }

  String _getDifficultyFromDuration(String durationStr) {
    final durationParts = durationStr.split(':');
    if (durationParts.length != 3) return 'easy';

    final hours = int.tryParse(durationParts[0]) ?? 0;
    final minutes = int.tryParse(durationParts[1]) ?? 0;
    final seconds = int.tryParse(durationParts[2]) ?? 0;

    final totalSeconds = hours * 3600 + minutes * 60 + seconds;

    if (totalSeconds >= 1800) return 'hard';
    if (totalSeconds >= 600) return 'medium';
    return 'easy';
  }

  Duration _parseDuration(String s) {
    try {
      List<String> parts = s.split(':');
      if (parts.length == 3) {
        return Duration(
          hours: int.parse(parts[0]),
          minutes: int.parse(parts[1]),
          seconds: int.parse(parts[2]),
        );
      } else if (parts.length == 2) {
        return Duration(
          minutes: int.parse(parts[0]),
          seconds: int.parse(parts[1]),
        );
      }
    } catch (e) {
      print('Error parsing duration string: $s - $e');
    }
    return const Duration(days: 9999);
  }

  @override
  Widget build(BuildContext context) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading // 這裡的 isLoading 只關心每日統計和最近跑步
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
                builder: (context, snapshot) {
                  final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                  final name = data['name'] ?? 'User';
                  final photoUrl = data['photoUrl'] ?? '';

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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                          // 從這個頁面導航到紀錄頁面
                          // 這裡的 Navigator.pushNamed 將會在紀錄頁面 Pop 後觸發 .then()
                          Navigator.pushNamed(context, '/record').then((result) {
                            // 當從 /record 頁面返回時，這裡會被觸發
                            // 如果 record 頁面有傳回 true，表示有新紀錄
                            if (result == true) {
                              print('Record page returned true, refreshing team ranks...'); // Debug
                              setState(() {
                                // 強制 FutureBuilder 重新執行 _loadUserTeamRanks
                                _teamRanksFuture = _loadUserTeamRanks();
                              });
                            }
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
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
                  const _StatItem(label: 'Points', value: '1 248'),
                ],
              ),

              const SizedBox(height: 24),

              // 使用 FutureBuilder 來處理團隊排名的異步載入和更新
              FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _teamRanksFuture, // 這裡使用我們定義的 Future
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    print('Error loading team ranks in FutureBuilder: ${snapshot.error}'); // Debug
                    return const Center(child: Text('Error loading team ranks.'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const _TeamRankCard(
                      teamName: 'No Team Joined',
                      displayTime: 'N/A',
                      displayRank: '?',
                    );
                  } else {
                    final loadedRanks = snapshot.data!;
                    return Column(
                      children: loadedRanks.entries.map((entry) {
                        final teamData = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _TeamRankCard(
                            teamName: teamData['teamName'],
                            displayTime: teamData['time'],
                            displayRank: '#${teamData['rank']}',
                          ),
                        );
                      }).toList(),
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

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
                            difficulty: run['difficulty'],
                            kcal: run['kcal'].toDouble(),
                            distance: run['distance'] as double?,
                            steps: run['steps'] as int?,
                          ),
                        ),
                      );
                    }

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
            // 從這裡導航到 Start 頁面，然後在 Start 頁面返回時也需要傳遞結果
              Navigator.pushNamed(context, '/start').then((result) {
                if (result == true) {
                  print('Start page returned true, refreshing team ranks...'); // Debug
                  setState(() {
                    _teamRanksFuture = _loadUserTeamRanks();
                  });
                }
              });
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

class _TeamRankCard extends StatelessWidget {
  final String teamName;
  final String displayTime;
  final String displayRank;

  const _TeamRankCard({
    required this.teamName,
    required this.displayTime,
    required this.displayRank,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.pink.shade50
            : Colors.blueGrey.shade800,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.timer,
                        color: Colors.blueAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayTime,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayRank,
                        style: const TextStyle(
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
        ],
      ),
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
