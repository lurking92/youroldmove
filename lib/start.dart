import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:myapp/record.dart';

enum PredefinedTarget { easy, medium, hard }

enum NextTargetType { predefined, custom }

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  _StartPageState createState() => _StartPageState();
}

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

  // 再次調整老年人平均步頻，降低到更符合非常慢的速度
  final _stepsPerMinute = 30.0;

  // 從 50 降低到 30 步/分鐘，非常慢的走路速度

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

  void _resetSaveFlags() {
    _incompleteSaved = false;
    _completeSaved = false;
  }

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

  // 調整卡路里計算，使之更慢
  double _calculateCalories(Duration elapsed) {
    // 降低 MET 值，例如從 2.0 降至 1.5 或更低，代表活動強度更低，卡路里消耗更慢
    double metValue = 1.5; // 從 2.0 降低到 1.5
    double durationInHours =
        elapsed.inMinutes / 60.0 + elapsed.inSeconds / 3600.0;
    return metValue * _weightKg * durationInHours;
  }

  // 根據走路時間推測距離 (速度保持不變)
  double _calculateDistanceByTime(Duration elapsed) {
    const double walkingSpeedMetersPerSecond = 0.5; // 老年人平均步行速度為 0.5 米/秒
    return elapsed.inSeconds * walkingSpeedMetersPerSecond / 1000; // 返回公里
  }

  // 根據時間推測步數 (老年人公式，再次降低步頻)
  int _calculateSteps(Duration elapsed) {
    return (elapsed.inSeconds * (_stepsPerMinute / 60)).round();
  }

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
          ).toStringAsFixed(2), // 根據時間推測距離
          'steps': _calculateSteps(_elapsed), // 只儲存步數
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
                                  fontSize: 22, // 調整字體大小
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

  void _checkCustomTargetReached(Duration elapsed, Duration target) {
    if (elapsed >= target && !_targetReached) {
      setState(() {
        _targetReached = true;
      });
      _showCongratulationsDialog();
      _toggleTimer();
    }
  }

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
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final kcal = _calculateCalories(_elapsed);
    final distanceKmTimeBased = _calculateDistanceByTime(_elapsed); // 根據時間計算距離
    final totalSteps = _calculateSteps(_elapsed); // 計算步數

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.orange[50],
      appBar: AppBar(
        title: const Text(
          'Slow Jog Timer',
          style: TextStyle(
            fontSize: 20, // 字體更小
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: isDark ? Colors.grey[900] : Colors.redAccent,
        elevation: 2, // 陰影更小
        centerTitle: true,
        toolbarHeight: 60, // 高度更小
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 20.0,
        ), // 調整整體 padding
        child: Column(
          children: [
            // 計時卡片
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20), // 調整底部間距
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      isDark
                          ? [Colors.grey.shade900, Colors.grey.shade800]
                          : [Colors.orange.shade100, Colors.orange.shade300],
                ),
                borderRadius: BorderRadius.circular(15), // 調整圓角
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.2), // 調整陰影顏色和透明度
                    blurRadius: 10, // 調整模糊半徑
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 25,
                horizontal: 20,
              ), // 調整 padding
              child: Column(
                children: [
                  Text(
                    _formatDuration(_elapsed),
                    style: TextStyle(
                      // 將顏色改為黑色
                      fontSize: 55, // 字體更小
                      fontWeight: FontWeight.w800, // 字體粗細調整
                      color:
                          isDark ? Colors.white : Colors.black, // 修改計時器數字顏色為黑色
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 12), // 調整間距
                  // 卡路里顯示 (格式調整)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ), // 調整 padding
                    decoration: BoxDecoration(
                      color: Colors.orange.shade500, // 調整背景顏色
                      borderRadius: BorderRadius.circular(12), // 調整圓角
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
                        fontSize: 20, // 字體更小
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10), // 新增間距
                  // 距離和步數並排顯示
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center, // 水平居中
                    children: [
                      // 距離顯示 (新的容器樣式)
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
                      const SizedBox(width: 20), // 增加間距
                      // 步數顯示 (新的容器樣式)
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
                          '$totalSteps Steps', // 修改標籤為 'Steps'
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

            // 目標設定卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20), // 調整 padding
              margin: const EdgeInsets.only(bottom: 20), // 調整底部間距
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12), // 調整圓角
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1.5,
                ), // 調整邊框顏色和粗細
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
                  // Goal Type 標題
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flag,
                        size: 24,
                        color: Colors.orange.shade600,
                      ), // 圖示微調大
                      const SizedBox(width: 10), // 調整間距
                      Text(
                        'Goal Type',
                        style: TextStyle(
                          fontSize: 19, // 字體加大
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18), // 調整間距
                  // 左右選擇按鈕 (Predefined / Custom) - 整合風格
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
                                          .shade600 // 選中時的橘色
                                      : Colors.orange.shade200, // 未選中時的深一點橘色
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // 與Kcal統一的圓角
                              border: Border.all(
                                color:
                                    _nextTargetType == NextTargetType.predefined
                                        ? Colors.orange.shade800
                                        : Colors.orange.shade400,
                                width: 1.5,
                              ),
                              boxShadow: [
                                // 添加陰影以匹配 Kcal 樣式
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
                                    color: Colors.black, // 正常模式下固定為黑色
                                  ),
                                ),
                              ],
                            ),
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
                              ), // 與Kcal統一的圓角
                              border: Border.all(
                                color:
                                    _nextTargetType == NextTargetType.custom
                                        ? Colors.orange.shade800
                                        : Colors.orange.shade400,
                                width: 1.5,
                              ),
                              boxShadow: [
                                // 添加陰影以匹配 Kcal 樣式
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
                                    color: Colors.black, // 正常模式下固定為黑色
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
                          'Current Difficulty:', // Predefined Time 的標題
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          // 新增 Row 來並排放置 Text 和 Button
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              // 固定 Easy/Medium/Hard 容器大小
                              width: 190, // 再次增加寬度
                              height: 60, // 再次增加高度
                              child: Container(
                                // 將顯示當前難度的 Text 包裹在 Container 中
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade500, // 與Kcal按鈕背景色一致
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // 與Kcal統一的圓角
                                  boxShadow: [
                                    // 添加陰影以匹配 Kcal 樣式
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: FittedBox(
                                  // 使用 FittedBox 確保文字適應容器
                                  fit: BoxFit.scaleDown, // 縮小文字以適應，但不會放大
                                  child: Text(
                                    _predefinedTargetLabel(_predefinedTarget),
                                    style: TextStyle(
                                      fontSize: 22, // 再次調整字體大小
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10), // 調整間距
                            ElevatedButton(
                              onPressed: _showPredefinedPicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.orange.shade500, // 與Kcal按鈕背景色一致
                                foregroundColor: Colors.black,
                                // 直接設定 fixedSize 來控制按鈕的寬高
                                fixedSize: const Size(
                                  150,
                                  60,
                                ), // 調整寬度為150，高度與SizedBox一致為60
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // 與Kcal統一的圓角
                                ),
                                elevation: 3,
                              ),
                              child: const Text(
                                'Set Difficulty', // 將按鈕文字改為 Set Difficulty
                                style: TextStyle(
                                  fontSize: 17.2, // 再次調整字體大小，以適應新的按鈕大小
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // 修改文字顏色為黑色
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
                          // 修改字體顏色為黑色
                          'Custom Time:',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? Colors.white
                                    : Colors.black, // 修改 Custom Time 字體顏色為黑色
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Custom Time 時間顯示 (整合風格)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade500, // 與Kcal按鈕背景色一致
                                borderRadius: BorderRadius.circular(
                                  12,
                                ), // 與Kcal統一的圓角
                                boxShadow: [
                                  // 添加陰影以匹配 Kcal 樣式
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
                            // Set Time 按鈕 (整合風格)
                            ElevatedButton(
                              onPressed: _showCustomTimePicker,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Colors.orange.shade500, // 與Kcal按鈕背景色一致
                                foregroundColor: Colors.black, // 文字顏色改為黑色
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                  horizontal: 25,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // 與Kcal統一的圓角
                                ),
                                elevation: 3, // 陰影保持
                              ),
                              child: const Text(
                                'Set Time',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black, // 修改 Set Time 字體顏色為黑色
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

            // 控制按鈕
            Row(
              children: [
                // START / PAUSE
                Expanded(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400, // 按鈕顏色統一為橘色
                        foregroundColor: Colors.black, // 文字顏色改為黑色
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), // 調整圓角
                        ),
                        elevation: 4, // 陰影更小
                      ),
                      onPressed: _toggleTimer,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRunning ? Icons.pause_circle : Icons.play_circle,
                            size: 30, // 圖示微調大
                            color: Colors.black, // 修改 START/PAUSE 圖示顏色為黑色
                          ),
                          const SizedBox(width: 10), // 調整間距
                          Text(
                            _isRunning ? 'PAUSE' : 'START',
                            style: const TextStyle(
                              fontSize: 19, // 字體加大
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15), // 調整間距
                // RESET
                Expanded(
                  child: SizedBox(
                    height: 60, // 高度微調大
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400, // 按鈕顏色統一為橘色
                        foregroundColor: Colors.black, // 文字顏色改為黑色
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15), // 調整圓角
                        ),
                        elevation: 4, // 陰影更小
                      ),
                      onPressed: _resetWorkout,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restart_alt,
                            size: 28,
                            color: Colors.black, // 修改 RESET 圖示顏色為黑色
                          ), // 圖示微調大
                          SizedBox(width: 10), // 調整間距
                          Text(
                            'RESET',
                            style: TextStyle(
                              fontSize: 19, // 字體加大
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25), // 調整間距
            // 查看紀錄按鈕
            SizedBox(
              width: double.infinity,
              height: 55, // 高度微調大
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.orange.shade400,
                    width: 2,
                  ), // 調整邊框顏色和粗細
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15), // 調整圓角
                  ),
                  foregroundColor: Colors.orange.shade700, // 文字顏色調整
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecordPage(),
                    ), // 正確導航到 RecordPage
                  );
                },
                child: const Text(
                  'VIEW RECORDS',
                  style: TextStyle(
                    fontSize: 18, // 字體更小
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
