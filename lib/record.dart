import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class RecordPage extends StatefulWidget {
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
        ).showSnackBar(SnackBar(content: Text('Record deleted')));
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
    if (!_isUserLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: Text('My Records')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Please log in to view your workout records'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/login',
                  ); // Assuming you have a login page
                },
                child: Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('My Workout Records')),
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
            calendarStyle: CalendarStyle(
              markersMaxCount: 3,
              markerDecoration: BoxDecoration(
                color: Colors.green, // You can change the color if needed
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child:
                _selectedDay == null
                    ? Center(
                      child: Text('Please select a date to view records'),
                    )
                    : StreamBuilder<List<Record>>(
                      stream: _eventsForDay(_selectedDay!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading data: ${snapshot.error}',
                            ),
                          );
                        }

                        final records = snapshot.data ?? [];
                        if (records.isEmpty) {
                          return Center(child: Text('No records for this day'));
                        }

                        return ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final r = records[index];
                            return Card(
                              margin: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                r.target,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              if (r.completed)
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                  size: 18,
                                                )
                                              else
                                                Icon(
                                                  Icons.warning,
                                                  color: Colors.orange,
                                                  size: 18,
                                                ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Duration: ${r.duration} | Calories: ${r.calories}',
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Recorded at: ${_formatTimestamp(r.timestamp)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        // Confirmation dialog
                                        showDialog(
                                          context: context,
                                          builder:
                                              (context) => AlertDialog(
                                                title: Text('Delete Record'),
                                                content: Text(
                                                  'Are you sure you want to delete this record?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                        ),
                                                    child: Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _deleteRecord(r);
                                                    },
                                                    child: Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
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

  Record({
    required this.id,
    required this.duration,
    required this.calories,
    required this.timestamp,
    required this.target,
    required this.type,
    required this.completed,
  });

  factory Record.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Record(
      id: doc.id,
      duration: data['duration']?.toString() ?? '', // 使用 ?.toString() 並提供預設值
      calories: data['calories']?.toString() ?? '', // 使用 ?.toString() 並提供預設值
      timestamp: data['timestamp'] as int,
      target: data['target'] as String,
      type: data['type'] as String,
      completed: data['completed'] as bool,
    );
  }
}
