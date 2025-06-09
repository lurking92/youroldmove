import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);
  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _bloodSugarController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _heartRateController = TextEditingController();

  String _mood = 'Normal';
  double? _bmi;
  String? _lastSavedTime;

  List<Map<String, dynamic>> _history = [];
  String _selectedField = 'weight';

  final Map<String, String> _fieldNames = {
    'weight': 'Weight',
    'bloodPressure': 'Blood Pressure',
    'bloodSugar': 'Blood Sugar',
    'bodyFat': 'Body Fat',
    'heartRate': 'Heart Rate',
  };

  // 新增一個Map來儲存各個健康數據的單位
  final Map<String, String> _fieldUnits = {
    'weight': 'kg',
    'bloodPressure': 'mmHg',
    'bloodSugar': 'mg/dL',
    'bodyFat': '%',
    'heartRate': 'bpm',
  };

  @override
  void initState() {
    super.initState();
    _fetchLatestData();
    _fetchHistory();
    _weightController.addListener(_calculateBMI);
    _heightController.addListener(_calculateBMI);
  }

  void _calculateBMI() {
    final weight = double.tryParse(_weightController.text);
    final heightCm = double.tryParse(_heightController.text);
    if (weight != null && heightCm != null && heightCm > 0) {
      final heightM = heightCm / 100;
      setState(() {
        _bmi = weight / (heightM * heightM);
      });
    } else {
      setState(() => _bmi = null);
    }
  }

  Future<void> _fetchLatestData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot =
          await _firestore.collection('healthData').doc(user.uid).get();
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _weightController.text = data['weight']?.toString() ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _bloodPressureController.text =
              data['bloodPressure']?.toString() ?? '';
          _bloodSugarController.text = data['bloodSugar']?.toString() ?? '';
          _bodyFatController.text = data['bodyFat']?.toString() ?? '';
          _heartRateController.text = data['heartRate']?.toString() ?? '';

          _mood = data['mood'] ?? 'Normal';
          _calculateBMI();

          final ts = data['timestamp'];
          if (ts is int) {
            final dt = DateTime.fromMillisecondsSinceEpoch(ts);
            _lastSavedTime =
                '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
          }
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot =
          await _firestore
              .collection('healthHistory')
              .doc(user.uid)
              .collection('records')
              .orderBy('timestamp', descending: false)
              .get();
      setState(() {
        _history = snapshot.docs.map((doc) => doc.data()).toList();
      });
    }
  }

  Future<void> _saveData() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final now = DateTime.now(); // 獲取當前時間

    // 將當前時間轉換為當天的開始時間（例如 2023-10-27 00:00:00 的毫秒時間戳）
    final startOfDay =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    // 將當前時間轉換為當天的結束時間（例如 2023-10-27 23:59:59 的毫秒時間戳）
    final endOfDay =
        DateTime(
          now.year,
          now.month,
          now.day,
          23,
          59,
          59,
          999,
        ).millisecondsSinceEpoch;

    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final bloodPressure = double.tryParse(_bloodPressureController.text);
    final bloodSugar = double.tryParse(_bloodSugarController.text);
    final bodyFat = double.tryParse(_bodyFatController.text);
    final heartRate = double.tryParse(_heartRateController.text);

    final dataToSave = <String, dynamic>{
      'timestamp': now.millisecondsSinceEpoch, // 儲存精確的時間戳
      'mood': _mood,
    };
    if (weight != null) dataToSave['weight'] = weight;
    if (height != null) dataToSave['height'] = height;
    if (bloodPressure != null) dataToSave['bloodPressure'] = bloodPressure;
    if (bloodSugar != null) dataToSave['bloodSugar'] = bloodSugar;
    if (bodyFat != null) dataToSave['bodyFat'] = bodyFat;
    if (heartRate != null) dataToSave['heartRate'] = heartRate;

    try {
      // Step 1: 更新 healthData 主文件
      await _firestore
          .collection('healthData')
          .doc(user.uid)
          .set(dataToSave, SetOptions(merge: true));

      // Step 2: 處理 healthHistory 子集合
      // 查詢當天是否有已經存在的記錄
      final historySnapshot =
          await _firestore
              .collection('healthHistory')
              .doc(user.uid)
              .collection('records')
              .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
              .where('timestamp', isLessThanOrEqualTo: endOfDay)
              .limit(1) // 只需檢查一條
              .get();

      if (historySnapshot.docs.isNotEmpty) {
        // 如果當天已有記錄，則更新它
        final docIdToUpdate = historySnapshot.docs.first.id;
        await _firestore
            .collection('healthHistory')
            .doc(user.uid)
            .collection('records')
            .doc(docIdToUpdate)
            .set(
              dataToSave,
              SetOptions(merge: true),
            ); // 使用 merge: true 以免覆蓋其他字段
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health data updated for today!')),
        );
      } else {
        // 如果當天沒有記錄，則新增一條
        await _firestore
            .collection('healthHistory')
            .doc(user.uid)
            .collection('records')
            .add(dataToSave);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Health data saved!')));
      }

      await _fetchLatestData();
      await _fetchHistory();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.deepOrange),
          labelText: label,

          labelStyle: const TextStyle(fontSize: 18),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 24,
            horizontal: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMoodSelector() {
    final moods = {
      'Happy': Icons.sentiment_very_satisfied,
      'Normal': Icons.sentiment_neutral,
      'Sad': Icons.sentiment_dissatisfied,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mood',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Row(
          children:
              moods.entries.map((entry) {
                final selected = _mood == entry.key;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _mood = entry.key),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color:
                            selected ? Colors.deepOrange : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            entry.value,
                            size: 32,
                            color: selected ? Colors.white : Colors.black54,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: selected ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildBMI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _bmi != null
            ? 'Your BMI is: ${_bmi!.toStringAsFixed(1)}'
            : 'Please enter weight and height to calculate BMI',

        style: const TextStyle(fontSize: 18, color: Colors.black),
      ),
    );
  }

  Widget _buildChart(String fieldName) {
    final List<FlSpot> spots = [];
    final sortedHistory = [..._history]
      ..sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

    // 如果沒有足夠的數據來繪製圖表，則直接返回提示文字
    if (sortedHistory.isEmpty ||
        !sortedHistory.any((element) => element[fieldName] is num)) {
      return const Center(child: Text('Not enough data to display chart'));
    }

    // 找到數值的最大值和最小值，用於設定左右Y軸範圍
    double rawMinY = double.infinity;
    double rawMaxY = double.negativeInfinity;

    for (int i = 0; i < sortedHistory.length; i++) {
      final value = sortedHistory[i][fieldName];
      if (value is num) {
        spots.add(FlSpot(i.toDouble(), value.toDouble()));
        if (value.toDouble() < rawMinY) rawMinY = value.toDouble();
        if (value.toDouble() > rawMaxY) rawMaxY = value.toDouble();
      }
    }

    // 處理只有一個點的情況，避免圖表無法顯示或Y軸範圍為零
    if (spots.length == 1) {
      spots.add(FlSpot(spots[0].x + 0.001, spots[0].y)); // 添加一個微小的點
      // 如果只有一個點，設置一個合理的預設範圍
      rawMinY = rawMinY - 10;
      rawMaxY = rawMaxY + 10;
    } else if (rawMinY == rawMaxY) {
      // 如果所有數據點的值都相同
      rawMinY = rawMinY - 10;
      rawMaxY = rawMaxY + 10;
    }

    // 計算 Y 軸的顯示範圍和間隔
    double dataRange = rawMaxY - rawMinY;
    double yInterval;
    double minY, maxY;

    if (dataRange > 0) {
      // 根據數據範圍動態調整 interval，讓刻度更合理
      if (dataRange <= 10) {
        // 數據範圍很小，例如 0-10
        yInterval = 2;
      } else if (dataRange <= 50) {
        // 數據範圍較小，例如 0-50
        yInterval = 5;
      } else {
        // 數據範圍較大
        yInterval = (dataRange / 5).roundToDouble(); // 大約顯示5個刻度
        if (yInterval == 0) yInterval = 1; // 避免為0
      }
      minY = (rawMinY / yInterval).floor() * yInterval; // 向下取整到最近的 interval 倍數
      maxY = (rawMaxY / yInterval).ceil() * yInterval; // 向上取整到最近的 interval 倍數

      // 確保 minY 和 maxY 至少包含原始數據範圍
      if (minY > rawMinY) minY = (rawMinY - yInterval).floorToDouble();
      if (maxY < rawMaxY) maxY = (rawMaxY + yInterval).ceilToDouble();

      // 如果 min/max 相等，再次調整以避免範圍為零
      if (minY == maxY) {
        minY -= yInterval;
        maxY += yInterval;
      }
    } else {
      // 數據範圍為零 (只有一個點或所有點相同)
      yInterval = 10; // 預設間隔
      minY = rawMinY - 20; // 提供一個較大的預設範圍
      maxY = rawMaxY + 20;
    }

    // 取得選中數據的名稱和單位
    String fieldDisplayName = _fieldNames[fieldName] ?? 'Data';
    String unit = _fieldUnits[fieldName] ?? '';
    String yAxisLabel = '$fieldDisplayName($unit)'; // 左側Y軸的輔助說明文字

    return LineChart(
      LineChartData(
        minX: 0,
        maxX:
            (sortedHistory.length > 1)
                ? sortedHistory.length - 1
                : 1, // 確保至少有一個點
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(show: true),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          // 底部 X 軸標籤 (日期) - 保持不變
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < sortedHistory.length) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(
                    sortedHistory[index]['timestamp'],
                  );
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0, // 標籤與軸線的間距
                    child: Text(
                      "${dt.month}/${dt.day}",
                      style: const TextStyle(fontSize: 10, color: Colors.black),
                    ),
                  );
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: const Text(''),
                );
              },
            ),
          ),
          // 左側 Y 軸標籤 (動態文字說明: "數據名稱(單位)")
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              yAxisLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            axisNameSize: 30, // 為左側文字說明預留足夠空間
            sideTitles: SideTitles(
              showTitles: false, // 不顯示左側的數值標籤，只顯示輔助文字
            ),
          ),
          // 右側 Y 軸標籤 (數值) - 保持不變
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: yInterval, // 保持數值間隔
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(
                    value.toStringAsFixed(0), // 顯示數值，不帶小數點，符合圖片
                    style: const TextStyle(fontSize: 10, color: Colors.black),
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          // 頂部 X 軸標籤 (固定文字: "Date")
          topTitles: AxisTitles(
            axisNameWidget: const Text(
              'Date',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
            axisNameSize: 25, // 為頂部文字說明預留足夠空間
            sideTitles: SideTitles(
              showTitles: false, // 不顯示頂部的數值標籤，只顯示輔助文字
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.deepOrange,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Data'),
        backgroundColor: Colors.deepOrange,
        actions: [
          TextButton(
            onPressed: _saveData,
            child: const Text(
              'Save',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 圖表顯示區塊
            SizedBox(height: 250, child: _buildChart(_selectedField)),
            const SizedBox(height: 20), // 圖表和選擇器之間的間距
            // Select Chart 下拉選單
            Row(
              children: [
                const Text(
                  'Select Chart: ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.deepOrange),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.orange.shade50,
                    ),
                    child: DropdownButton<String>(
                      value: _selectedField,
                      isExpanded: true,
                      underline: const SizedBox(),
                      iconEnabledColor: Colors.deepOrange,
                      items:
                          _fieldNames.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedField = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30), // 下拉選單和輸入框之間的間距
            // 各種健康數據輸入框
            _buildTextField(
              'Weight (kg)',
              _weightController,
              Icons.monitor_weight,
            ),
            _buildTextField('Height (cm)', _heightController, Icons.height),
            _buildTextField(
              'Blood Pressure (mmHg)',
              _bloodPressureController,
              Icons.favorite,
            ),
            _buildTextField(
              'Blood Sugar (mg/dL)',
              _bloodSugarController,
              Icons.opacity,
            ),
            _buildTextField(
              'Body Fat (%)',
              _bodyFatController,
              Icons.water_drop,
            ),
            _buildTextField(
              'Heart Rate (bpm)',
              _heartRateController,
              Icons.favorite_border,
            ),
            const SizedBox(height: 10),
            _buildMoodSelector(),
            const SizedBox(height: 20),
            _buildBMI(),
            if (_lastSavedTime != null)
              Text(
                'Last saved: $_lastSavedTime',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const SizedBox(height: 10), // 為底部的 padding 增加一些間距
          ],
        ),
      ),
    );
  }
}
