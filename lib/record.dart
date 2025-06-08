import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// 假設您的 ThemeProvider 在另一個檔案中，並已正確引入
// import 'path/to/your/theme_provider.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  late final CollectionReference<Map<String, dynamic>> _recordsRef;
  bool _isUserLoggedIn = false;
  Set<DateTime> _daysWithEvents = {};

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("User not logged in, cannot load records.");
      _isUserLoggedIn = false;
    } else {
      _isUserLoggedIn = true;
      _recordsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records');
      _loadDaysWithEvents();
    }

    _selectedDay = DateTime.now(); // Initially select today
  }

  Future<void> _loadDaysWithEvents() async {
    if (_isUserLoggedIn) {
      final now = DateTime.now();
      // Adjust to get the first day of the current month and the last day of the current month
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      final snapshot =
          await _recordsRef
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: firstDayOfMonth.millisecondsSinceEpoch,
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: lastDayOfMonth.millisecondsSinceEpoch,
              )
              .get();

      Set<DateTime> days = {};
      for (final doc in snapshot.docs) {
        final timestamp = doc.data()['timestamp'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        days.add(DateTime(date.year, date.month, date.day));
      }
      setState(() {
        _daysWithEvents = days;
      });
    }
  }

  Stream<List<Record>> _eventsForDay(DateTime day) {
    if (!_isUserLoggedIn) {
      return Stream.value([]);
    }

    final start = DateTime(day.year, day.month, day.day);
    final startTimestamp = start.millisecondsSinceEpoch;

    final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
    final endTimestamp = end.millisecondsSinceEpoch;

    print(
      "Querying date range: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(start)} to ${DateFormat('yyyy-MM-dd HH:mm:ss').format(end)}",
    );
    print("Timestamp range: $startTimestamp to $endTimestamp");

    return _recordsRef
        .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
        .where('timestamp', isLessThanOrEqualTo: endTimestamp)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) {
          print("Number of documents found: ${snap.docs.length}");
          return snap.docs.map((d) {
            print("Document ID: ${d.id}, Timestamp: ${d.data()['timestamp']}");
            return Record.fromDoc(d);
          }).toList();
        });
  }

  Future<void> _deleteRecord(Record record) async {
    if (_isUserLoggedIn) {
      try {
        await _recordsRef.doc(record.id).delete();
        print('Successfully deleted record, ID: ${record.id}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Record deleted')));
      } catch (e) {
        print('Error deleting record: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete record: $e')));
      }
    } else {
      print('User not logged in, cannot delete records.');
    }
  }

  String _formatTimestamp(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    // 獲取當前主題的亮度
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // 定義在亮色和暗色模式下通用的文字顏色
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
    final Color dialogTextColor = isDarkMode ? Colors.white70 : Colors.black87;

    if (!_isUserLoggedIn) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'My Records',
            style: TextStyle(
              color: isDarkMode ? Colors.white : null, // 調整 AppBar 標題顏色
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Please log in to view your workout records',
                style: TextStyle(fontSize: 20, color: hintColor),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text(
                  'Go to Login',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Workout Records',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white, // AppBar 標題顏色調整
          ),
        ),
        backgroundColor:
            isDarkMode ? Colors.grey[850] : Colors.redAccent, // AppBar 背景色調整
        elevation: 4,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              print(
                "Selected date: ${DateFormat('yyyy-MM-dd').format(selected)}",
              );
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            eventLoader: (day) {
              if (_daysWithEvents.contains(day)) {
                return ['event'];
              } else {
                return [];
              }
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                color:
                    isDarkMode ? Colors.white : Colors.redAccent, // 日曆頭部文字顏色調整
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: isDarkMode ? Colors.white70 : Colors.grey, // 箭頭圖示顏色調整
                size: 30,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: isDarkMode ? Colors.white70 : Colors.grey, // 箭頭圖示顏色調整
                size: 30,
              ),
            ),
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: TextStyle(
                color: isDarkMode ? Colors.red[300] : Colors.red, // 週末文字顏色調整
                fontSize: 18,
              ),
              defaultTextStyle: TextStyle(
                fontSize: 18,
                color: textColor, // 預設日期文字顏色調整
              ),
              todayTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.7),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.lightGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              markersMaxCount: 1,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child:
                _selectedDay == null
                    ? Center(
                      child: Text(
                        'Please select a date to view records',
                        style: TextStyle(
                          fontSize: 20,
                          color: hintColor, // 提示文字顏色調整
                        ),
                      ),
                    )
                    : StreamBuilder<List<Record>>(
                      stream: _eventsForDay(_selectedDay!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading data: ${snapshot.error}',
                              style: TextStyle(
                                color:
                                    isDarkMode
                                        ? Colors.red[300]
                                        : Colors.red, // 錯誤文字顏色調整
                                fontSize: 20,
                              ),
                            ),
                          );
                        }

                        final records = snapshot.data ?? [];
                        if (records.isEmpty) {
                          return Center(
                            child: Text(
                              'No records for this day',
                              style: TextStyle(
                                fontSize: 20,
                                color: hintColor, // 提示文字顏色調整
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final r = records[index];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              color:
                                  isDarkMode
                                      ? Colors.grey[900]
                                      : null, // 卡片背景色調整
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            r.target,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 22,
                                              color: textColor, // 目標名稱顏色調整
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (r.completed)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 24,
                                          )
                                        else
                                          const Icon(
                                            Icons.warning,
                                            color: Colors.orange,
                                            size: 24,
                                          ),
                                        IconButton(
                                          icon: Icon(
                                            Icons.delete_outline,
                                            color:
                                                isDarkMode
                                                    ? Colors.white70
                                                    : Colors.grey, // 刪除圖示顏色調整
                                            size: 28,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder:
                                                  (context) => AlertDialog(
                                                    backgroundColor:
                                                        isDarkMode
                                                            ? Colors.grey[800]
                                                            : null, // AlertDialog 背景色調整
                                                    title: Text(
                                                      'Delete Record',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        color:
                                                            isDarkMode
                                                                ? Colors.white
                                                                : null, // 標題顏色調整
                                                      ),
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete the record for "${r.target}" on ${_formatTimestamp(r.timestamp)}?',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color:
                                                            dialogTextColor, // 內容顏色調整
                                                      ),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed:
                                                            () => Navigator.pop(
                                                              context,
                                                            ),
                                                        child: Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            color:
                                                                isDarkMode
                                                                    ? Colors
                                                                        .blue[300]
                                                                    : null, // 按鈕文字顏色調整
                                                          ),
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                          _deleteRecord(r);
                                                        },
                                                        child: Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color:
                                                                isDarkMode
                                                                    ? Colors
                                                                        .red[300]
                                                                    : Colors
                                                                        .red, // 按鈕文字顏色調整
                                                            fontSize: 18,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16, thickness: 1),
                                    Wrap(
                                      spacing: 16,
                                      runSpacing: 8,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.timer,
                                              size: 20,
                                              color:
                                                  isDarkMode
                                                      ? Colors.blueGrey[200]
                                                      : Colors
                                                          .blueGrey, // 圖示顏色調整
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${r.duration}',
                                              style: TextStyle(
                                                fontSize: 19,
                                                color: textColor, // 文字顏色調整
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.local_fire_department,
                                              size: 20,
                                              color:
                                                  isDarkMode
                                                      ? Colors.red[300]
                                                      : Colors.red, // 圖示顏色調整
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${r.calories} kcal',
                                              style: TextStyle(
                                                fontSize: 19,
                                                color: textColor, // 文字顏色調整
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (r.distanceKm != null &&
                                            r.distanceKm! >= 0)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.directions_run,
                                                size: 20,
                                                color:
                                                    isDarkMode
                                                        ? Colors.teal[200]
                                                        : Colors.teal, // 圖示顏色調整
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${r.distanceKm!.toStringAsFixed(2)} km',
                                                style: TextStyle(
                                                  fontSize: 19,
                                                  color: textColor, // 文字顏色調整
                                                ),
                                              ),
                                            ],
                                          ),
                                        if (r.steps != null && r.steps! >= 0)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.directions_walk,
                                                size: 20,
                                                color:
                                                    isDarkMode
                                                        ? Colors.purple[200]
                                                        : Colors
                                                            .purple, // 圖示顏色調整
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${r.steps} steps',
                                                style: TextStyle(
                                                  fontSize: 19,
                                                  color: textColor, // 文字顏色調整
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        'Recorded at: ${_formatTimestamp(r.timestamp)}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: hintColor, // 時間戳顏色調整
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class Record {
  final String id;
  final String duration;
  final String calories;
  final int timestamp;
  final String target;
  final String type;
  final bool completed;
  final double? distanceKm;
  final int? steps;

  Record({
    required this.id,
    required this.duration,
    required this.calories,
    required this.timestamp,
    required this.target,
    required this.type,
    required this.completed,
    this.distanceKm,
    this.steps,
  });

  factory Record.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    double? parsedDistance;
    final distanceValue = data['distance_time_based_km'];
    if (distanceValue is num) {
      parsedDistance = distanceValue.toDouble();
    } else if (distanceValue is String) {
      parsedDistance = double.tryParse(distanceValue);
    }

    int? parsedSteps;
    final stepsValue = data['steps'];
    if (stepsValue is num) {
      parsedSteps = stepsValue.toInt();
    } else if (stepsValue is String) {
      parsedSteps = int.tryParse(stepsValue);
    }

    return Record(
      id: doc.id,
      duration: data['duration']?.toString() ?? '',
      calories: data['calories']?.toString() ?? '',
      timestamp: data['timestamp'] as int,
      target: data['target'] as String,
      type: data['type'] as String,
      completed: data['completed'] as bool,
      distanceKm: parsedDistance,
      steps: parsedSteps,
    );
  }
}
