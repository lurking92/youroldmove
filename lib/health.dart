import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

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

  String _mood = '普通';
  double? _bmi;
  String? _lastSavedTime;

  List<Map<String, dynamic>> _history = [];

  String _selectedField = 'weight';

  final Map<String, String> _fieldNames = {
    'weight': '體重',
    'bloodPressure': '血壓',
    'bloodSugar': '血糖',
    'bodyFat': '體脂',
    'heartRate': '心跳',
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
      final snapshot = await _firestore.collection('healthData').doc(user.uid).get();
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _weightController.text = data['weight']?.toString() ?? '';
          _heightController.text = data['height']?.toString() ?? '';
          _bloodPressureController.text = data['bloodPressure']?.toString() ?? '';
          _bloodSugarController.text = data['bloodSugar']?.toString() ?? '';
          _bodyFatController.text = data['bodyFat']?.toString() ?? '';
          _heartRateController.text = data['heartRate']?.toString() ?? '';
          _mood = data['mood'] ?? '普通';
          _calculateBMI();

          final ts = data['timestamp'];
          if (ts is int) {
            final dt = DateTime.fromMillisecondsSinceEpoch(ts);
            _lastSavedTime = '${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
          }
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    final user = _auth.currentUser;
    if (user != null) {
      final snapshot = await _firestore
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

    final now = DateTime.now().millisecondsSinceEpoch;

    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final bloodPressure = double.tryParse(_bloodPressureController.text);
    final bloodSugar = double.tryParse(_bloodSugarController.text);
    final bodyFat = double.tryParse(_bodyFatController.text);
    final heartRate = double.tryParse(_heartRateController.text);

    final data = <String, dynamic>{
      'timestamp': now,
      'mood': _mood,
    };
    if (weight != null) data['weight'] = weight;
    if (height != null) data['height'] = height;
    if (bloodPressure != null) data['bloodPressure'] = bloodPressure;
    if (bloodSugar != null) data['bloodSugar'] = bloodSugar;
    if (bodyFat != null) data['bodyFat'] = bodyFat;
    if (heartRate != null) data['heartRate'] = heartRate;

    try {
      await _firestore.collection('healthData').doc(user.uid).set(data, SetOptions(merge: true));
      await _firestore.collection('healthHistory').doc(user.uid).collection('records').add(data);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('健康資料已儲存')),
      );

      await _fetchLatestData();
      await _fetchHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存失敗：$e')),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
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
          contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildMoodSelector() {
    final moods = {
      '開心': Icons.sentiment_very_satisfied,
      '普通': Icons.sentiment_neutral,
      '難過': Icons.sentiment_dissatisfied,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('心情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: moods.entries.map((entry) {
            final selected = _mood == entry.key;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _mood = entry.key),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected ? Colors.deepOrange : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Icon(entry.value, size: 32, color: selected ? Colors.white : Colors.black54),
                      const SizedBox(height: 6),
                      Text(entry.key, style: TextStyle(color: selected ? Colors.white : Colors.black)),
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
        _bmi != null ? '你的 BMI 是：${_bmi!.toStringAsFixed(1)}' : '請輸入體重與身高以計算 BMI',
        style: const TextStyle(fontSize: 18),
      ),
    );
  }

  Widget _buildChart(String fieldName) {
    final List<FlSpot> spots = [];
    final sortedHistory = [..._history]..sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

    for (int i = 0; i < sortedHistory.length; i++) {
      final value = sortedHistory[i][fieldName];
      if (value is num) {
        spots.add(FlSpot(i.toDouble(), value.toDouble()));
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('沒有足夠的資料顯示圖表'));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, _) {
                int index = value.toInt();
                if (index >= 0 && index < sortedHistory.length) {
                  final dt = DateTime.fromMillisecondsSinceEpoch(sortedHistory[index]['timestamp']);
                  return Text("${dt.month}/${dt.day}", style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, interval: 5),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.deepOrange,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康資料'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveData,
            tooltip: '儲存資料',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('體重 (kg)', _weightController, Icons.monitor_weight),
            _buildTextField('身高 (cm)', _heightController, Icons.height),
            _buildTextField('血壓 (mmHg)', _bloodPressureController, Icons.favorite),
            _buildTextField('血糖 (mg/dL)', _bloodSugarController, Icons.opacity),
            _buildTextField('體脂 (%)', _bodyFatController, Icons.water_drop),
            _buildTextField('心跳 (bpm)', _heartRateController, Icons.favorite_border),
            const SizedBox(height: 10),
            _buildMoodSelector(),
            const SizedBox(height: 20),
            _buildBMI(),
            if (_lastSavedTime != null)
              Text('最後儲存時間：$_lastSavedTime', style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 30),

            // 下拉選單選擇圖表欄位
            Row(
              children: [
                const Text('選擇圖表：', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                      items: _fieldNames.entries
                          .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value, style: const TextStyle(fontSize: 16)),
                      ))
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

            const SizedBox(height: 20),
            SizedBox(
              height: 250,
              child: _buildChart(_selectedField),
            ),
          ],
        ),
      ),
    );
  }
}
