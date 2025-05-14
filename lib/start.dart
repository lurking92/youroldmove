import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ✅ Move enum outside of class
enum PredefinedTarget { slowWalk30, slowRun15 }

enum NextTargetType { predefined, custom }

class StartPage extends StatefulWidget {
  @override
  _StartPageState createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with WidgetsBindingObserver {
  DateTime? _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  NextTargetType _nextTargetType = NextTargetType.predefined;
  PredefinedTarget _predefinedTarget = PredefinedTarget.slowWalk30;
  Duration _customTarget = Duration(minutes: 20);
  double _weightKg = 60.0;
  bool _targetReached = false;
  bool _isWeightLoaded = false;
  final TextEditingController _weightController = TextEditingController();
  Timer? _weightSaveTimer; // 👈 新增這一行
  double? _tempWeight; // 👈 新增這一行，暫存輸入中的體重
  bool _incompleteSaved = false; // 新增：是否已儲存過未完成的紀錄
  bool _completeSaved = false; // 新增：是否已儲存過完成的紀錄

  String? _userId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    if (_userId != null) {
      _loadWeightFromFirestore();
    } else {
      _isWeightLoaded = true;
      _weightController.text = _weightKg.toString(); // 設定預設值到 controller
    }
    print("Current User UID: $_userId");
    // 一進畫面就初始化旗標
    _resetSaveFlags();
  }

  // 每次新一輪計時時呼叫
  void _resetSaveFlags() {
    _incompleteSaved = false;
    _completeSaved = false;
  }

  Future<void> _loadWeightFromFirestore() async {
    if (_userId != null) {
      try {
        DocumentSnapshot doc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_userId)
                .get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _weightKg =
                (doc.data() as Map<String, dynamic>)['weight'] as double? ??
                60.0;
            _weightController.text =
                _weightKg.toString(); // 👈 設定載入的值到 controller
            _isWeightLoaded = true;
          });
        } else {
          _isWeightLoaded = true;
          _weightController.text = _weightKg.toString(); // 設定預設值到 controller
        }
      } catch (e) {
        print("Error loading weight from Firestore: $e");
        _isWeightLoaded = true;
        _weightController.text = _weightKg.toString(); // 設定預設值到 controller
      }
    }
  }

  Future<void> _saveWeightToFirestore(double weight) async {
    if (_userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId) // 👈 確保指定使用者的 document ID
            .set({'weight': weight}, SetOptions(merge: true));
      } catch (e) {
        print("Error saving weight to Firestore: $e");
      }
    } else {
      print("User not logged in, cannot save weight.");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed && _isRunning) {
      _startTime = DateTime.now().subtract(_elapsed);
      _timer = Timer.periodic(Duration(seconds: 1), (_) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      });
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      // 開始新一輪 → 清除儲存旗標
      _resetSaveFlags();
      _startTime = DateTime.now().subtract(_elapsed);
      _timer = Timer.periodic(Duration(seconds: 1), (_) => _updateElapsed());
    }
    setState(() => _isRunning = !_isRunning);
  }

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

  double _calculateCalories(Duration elapsed) {
    double metValue = 2.0;
    double durationInHours =
        elapsed.inMinutes / 60.0 + elapsed.inSeconds / 3600.0;
    return metValue * _weightKg * durationInHours;
  }

  String _predefinedTargetLabel(PredefinedTarget target) {
    switch (target) {
      case PredefinedTarget.slowWalk30:
        return '30 min slow walk';
      case PredefinedTarget.slowRun15:
        return '15 min slow jog';
    }
  }

  void _showCustomTimePicker() {
    // 👈 補上這個方法
    showModalBottomSheet(
      context: context,
      builder: (BuildContext builder) {
        return Container(
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

  void _resetWorkout() {
    // 只有在還沒完成、且還沒儲存過「未完成」時才存一次
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

  Future<void> _saveRecordToFirestore(bool completed) async {
    if (_userId != null) {
      try {
        final now = DateTime.now().millisecondsSinceEpoch;
        String targetDescription = '';
        if (_nextTargetType == NextTargetType.predefined) {
          targetDescription = _predefinedTargetLabel(_predefinedTarget);
        } else if (_nextTargetType == NextTargetType.custom) {
          targetDescription = 'Custom: ${_formatDuration(_customTarget)}';
        }

        final recordData = {
          // <-- 打印這個 Map
          'type':
              _nextTargetType == NextTargetType.predefined
                  ? 'predefined'
                  : 'custom',
          'target': targetDescription,
          'duration': _formatDuration(_elapsed),
          'calories': _calculateCalories(_elapsed).toStringAsFixed(1),
          'timestamp': now,
          'completed': completed,
        };
        print(
          "Attempting to save record for user $_userId: $recordData",
        ); // <-- 新增打印

        await FirebaseFirestore.instance
            .collection('users')
            .doc(_userId)
            .collection('records')
            .add(recordData); // 使用準備好的 Map
        print('Record saved to Firestore');
      } catch (e) {
        print('Error saving record: $e');
      }
    } else {
      print('User not logged in, cannot save record.');
    }
  }

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
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TextButton(
                    child: Text('Done'),
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
                            .map((e) => Text(_predefinedTargetLabel(e)))
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _checkPredefinedTargetReached(
    Duration elapsed,
    PredefinedTarget target,
  ) {
    Duration targetDuration;
    switch (target) {
      case PredefinedTarget.slowWalk30:
        targetDuration = Duration(minutes: 30);
        break;
      case PredefinedTarget.slowRun15:
        targetDuration = Duration(minutes: 15);
        break;
    }
    if (elapsed >= targetDuration && !_targetReached) {
      setState(() {
        _targetReached = true;
      });
      _showCongratulationsDialog();
      _toggleTimer(); // 停止計時器
    }
  }

  void _checkCustomTargetReached(Duration elapsed, Duration target) {
    if (elapsed >= target && !_targetReached) {
      setState(() {
        _targetReached = true;
      });
      _showCongratulationsDialog();
      _toggleTimer(); // 停止計時器
    }
  }

  void _showCongratulationsDialog() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Congratulations!'),
            content: Text("You've reached your goal!"),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  // 只有第一次完成才存一次
                  if (!_completeSaved) {
                    _saveRecordToFirestore(true);
                    _completeSaved = true;
                  }
                  // 完成後就結束並重置畫面
                  _resetWorkout();
                },
              ),
            ],
          ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:${twoDigitMinutes}:${twoDigitSeconds}";
  }

  @override
  Widget build(BuildContext context) {
    final kcal = _calculateCalories(_elapsed);
    return Scaffold(
      appBar: AppBar(title: Text('Slow Jog Start')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      _elapsed.toString().split('.').first,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${kcal.toStringAsFixed(1)} Kcal',
                      style: TextStyle(fontSize: 24, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            ),
            TextField(
              key: ValueKey(_weightKg),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Your weight (kg)',
                border: OutlineInputBorder(),
              ),
              controller: _weightController,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null) {
                  setState(() => _tempWeight = parsed); // 暫存輸入的值

                  if (_weightSaveTimer?.isActive ?? false) {
                    _weightSaveTimer?.cancel(); // 取消之前的 timer
                  }
                  _weightSaveTimer = Timer(Duration(milliseconds: 2000), () {
                    // 延遲 2 秒後儲存
                    if (_tempWeight != null && _tempWeight != _weightKg) {
                      setState(() => _weightKg = _tempWeight!);
                      _saveWeightToFirestore(_weightKg!);
                    }
                  });
                }
              },
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Goal type:'),
                SizedBox(width: 16),
                DropdownButton<NextTargetType>(
                  value: _nextTargetType,
                  items: [
                    DropdownMenuItem(
                      value: NextTargetType.predefined,
                      child: Text('Predefined'),
                    ),
                    DropdownMenuItem(
                      value: NextTargetType.custom,
                      child: Text('Custom'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _nextTargetType = v!),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_nextTargetType == NextTargetType.predefined)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Goal:'),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _showPredefinedPicker,
                    child: Text(_predefinedTargetLabel(_predefinedTarget)),
                  ),
                ],
              ),
            if (_nextTargetType == NextTargetType.custom)
              Column(
                children: [
                  Text('Custom time: ${_formatDuration(_customTarget)}'),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showCustomTimePicker,
                    child: Text('Set Time'),
                  ),
                ],
              ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Start / Pause
                ElevatedButton.icon(
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _isRunning ? 'Pause' : 'Start',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  onPressed: _toggleTimer,
                ),
                // Reset (moved here, same style as Start)
                ElevatedButton.icon(
                  icon: Icon(Icons.restart_alt),
                  label: Text('Reset', style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    // no backgroundColor override → uses same default (green)
                  ),
                  onPressed: _resetWorkout,
                ),
              ],
            ),
            SizedBox(height: 16),

            TextButton.icon(
              icon: Icon(Icons.history),
              label: Text('View History', style: TextStyle(fontSize: 16)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/record');
              },
            ),
          ],
        ),
      ),
    );
  }
}
