import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';


class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  // Define variables for the calendar's state.
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Firebase Firestore references and user login status.
  late final CollectionReference<Map<String, dynamic>> _recordsRef;
  bool _isUserLoggedIn = false;
  Set<DateTime> _daysWithEvents = {};

  // Connect to the Firebase database and check the user's login status.
  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    // Check if the user is currently logged in.
    if (user == null) {
      print("User not logged in, cannot load records.");
      _isUserLoggedIn = false;
    } else {
      _isUserLoggedIn = true;
      // Initialize the Firestore reference to the user's 'records' collection.
      _recordsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('records');
      // Load event data for the days in the current month.
      _loadDaysWithEvents();
    }

    _selectedDay = DateTime.now(); // Initially select the current day.
  }

  // Asynchronously loads all days with events for the current month.
  Future<void> _loadDaysWithEvents() async {
    // Only proceed if a user is logged in.
    if (_isUserLoggedIn) {
      final now = DateTime.now();

      // Calculate the start and end dates for the current month.
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      // Fetch records from Firestore that fall within the current month.
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

      // Create a set to store the dates with events.
      Set<DateTime> days = {};
      for (final doc in snapshot.docs) {
        final timestamp = doc.data()['timestamp'] as int;
        // Convert the timestamp to a DateTime object.
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        // Add the day part (year, month, day) to the set.
        days.add(DateTime(date.year, date.month, date.day));
      }
      // Update the state to reflect the new set of days with events.
      setState(() {
        _daysWithEvents = days;
      });
    }
  }
}

  // Returns a stream of records for a specific day.
Stream<List<Record>> _eventsForDay(DateTime day) {
  // Return an empty stream if the user is not logged in.
  if (!_isUserLoggedIn) {
    return Stream.value([]);
  }

  // Calculate the start and end timestamps for the selected day.
  final start = DateTime(day.year, day.month, day.day);
  final end = DateTime(day.year, day.month, day.day, 23, 59, 59, 999);
  
  // Query Firestore for documents within the day's timestamp range.
  return _recordsRef
      .where('timestamp', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
      .where('timestamp', isLessThanOrEqualTo: end.millisecondsSinceEpoch)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) {
        // Map document snapshots to a list of Record objects.
        return snap.docs.map((d) => Record.fromDoc(d)).toList();
      });
}

// Deletes a specific record from Firestore.
Future<void> _deleteRecord(Record record) async {
  if (_isUserLoggedIn) {
    try {
      // Delete the document by its ID.
      await _recordsRef.doc(record.id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record deleted')));
    } catch (e) {
      // Handle any errors during deletion.
      print('Error deleting record: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete record: $e')));
    }
  }
}

// Converts an integer timestamp to a formatted date-time string.
String _formatTimestamp(int timestamp) {
  final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
  return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
}

  // The main build method for the RecordPage widget.
@override
Widget build(BuildContext context) {
  // Determine the current theme's brightness.
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  // Define colors that adapt to both light and dark themes.
  final Color textColor = isDarkMode ? Colors.white : Colors.black87;
  final Color hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey;
  final Color dialogTextColor = isDarkMode ? Colors.white70 : Colors.black87;

  // If the user is not logged in, display a login prompt.
  if (!_isUserLoggedIn) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Records',
          style: TextStyle(
            color: isDarkMode ? Colors.white : null,
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

  // Display the main content for logged-in users.
  return Scaffold(
    appBar: AppBar(
      title: Text(
        'My Workout Records',
        style: TextStyle(
          fontSize: 24,
          color: Colors.white,
        ),
      ),
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.redAccent,
      elevation: 4,
    ),
    body: Column(
      children: [
        // TableCalendar widget to display the calendar.
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
          onDaySelected: (selected, focused) {
            // Update the selected and focused day when a day is tapped.
            setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            });
            print("Selected date: ${DateFormat('yyyy-MM-dd').format(selected)}");
          },
          onFormatChanged: (format) {
            setState(() => _calendarFormat = format);
          },
          eventLoader: (day) {
            // Check if a day has events and return an indicator.
            return _daysWithEvents.contains(day) ? ['event'] : [];
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(
              color: isDarkMode ? Colors.white : Colors.redAccent,
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
            ),
            leftChevronIcon: Icon(
              Icons.chevron_left,
              color: isDarkMode ? Colors.white70 : Colors.grey,
              size: 30,
            ),
            rightChevronIcon: Icon(
              Icons.chevron_right,
              color: isDarkMode ? Colors.white70 : Colors.grey,
              size: 30,
            ),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            weekendTextStyle: TextStyle(
              color: isDarkMode ? Colors.red[300] : Colors.red,
              fontSize: 18,
            ),
            defaultTextStyle: TextStyle(
              fontSize: 18,
              color: textColor,
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
        // Display records for the selected day or a placeholder.
        Expanded(
          child: _selectedDay == null
              ? Center(
                  child: Text(
                    'Please select a date to view records',
                    style: TextStyle(
                      fontSize: 20,
                      color: hintColor,
                    ),
                  ),
                )
              : StreamBuilder<List<Record>>(
                  stream: _eventsForDay(_selectedDay!),
                  builder: (context, snapshot) {
                    // Handle loading, error, and no data states.
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading data: ${snapshot.error}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.red[300] : Colors.red,
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
                            color: hintColor,
                          ),
                        ),
                      );
                    }

                    // Build a list of record cards.
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
                          color: isDarkMode ? Colors.grey[900] : null,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Record title and icons.
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        r.target,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 22,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Display check or warning icon based on completion status.
                                    if (r.completed)
                                      const Icon(Icons.check_circle, color: Colors.green, size: 24)
                                    else
                                      const Icon(Icons.warning, color: Colors.orange, size: 24),
                                    // Delete button with a confirmation dialog.
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: isDarkMode ? Colors.white70 : Colors.grey,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: isDarkMode ? Colors.grey[800] : null,
                                            title: Text(
                                              'Delete Record',
                                              style: TextStyle(
                                                fontSize: 20,
                                                color: isDarkMode ? Colors.white : null,
                                              ),
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete the record for "${r.target}" on ${_formatTimestamp(r.timestamp)}?',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: dialogTextColor,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(
                                                  'Cancel',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    color: isDarkMode ? Colors.blue[300] : null,
                                                  ),
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  _deleteRecord(r);
                                                },
                                                child: Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: isDarkMode ? Colors.red[300] : Colors.red,
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
                                // Display record details: duration, calories, distance, and steps.
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
                                          color: isDarkMode ? Colors.blueGrey[200] : Colors.blueGrey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${r.duration}',
                                          style: TextStyle(fontSize: 19, color: textColor),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.local_fire_department,
                                          size: 20,
                                          color: isDarkMode ? Colors.red[300] : Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${r.calories} kcal',
                                          style: TextStyle(fontSize: 19, color: textColor),
                                        ),
                                      ],
                                    ),
                                    if (r.distanceKm != null && r.distanceKm! >= 0)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.directions_run,
                                            size: 20,
                                            color: isDarkMode ? Colors.teal[200] : Colors.teal,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${r.distanceKm!.toStringAsFixed(2)} km',
                                            style: TextStyle(fontSize: 19, color: textColor),
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
                                            color: isDarkMode ? Colors.purple[200] : Colors.purple,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${r.steps} steps',
                                            style: TextStyle(fontSize: 19, color: textColor),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Display the timestamp of the record.
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    'Recorded at: ${_formatTimestamp(r.timestamp)}',
                                    style: TextStyle(fontSize: 15, color: hintColor),
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

  // Constructor for creating a Record object.
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

  // Factory constructor to create a Record object from a Firestore DocumentSnapshot.
  factory Record.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Safely parse the 'distance_time_based_km' field into a double.
    double? parsedDistance;
    final distanceValue = data['distance_time_based_km'];
    if (distanceValue is num) {
      parsedDistance = distanceValue.toDouble();
    } else if (distanceValue is String) {
      parsedDistance = double.tryParse(distanceValue);
    }

    // Safely parse the 'steps' field into an integer.
    int? parsedSteps;
    final stepsValue = data['steps'];
    if (stepsValue is num) {
      parsedSteps = stepsValue.toInt();
    } else if (stepsValue is String) {
      parsedSteps = int.tryParse(stepsValue);
    }

    // Return a new Record instance with data from the document.
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
