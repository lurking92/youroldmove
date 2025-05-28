import 'package:flutter/material.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({Key? key}) : super(key: key);

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController systolicController = TextEditingController();
  final TextEditingController diastolicController = TextEditingController();
  final TextEditingController heartRateController = TextEditingController();

  double? bmi;

  void calculateBMI() {
    final height = double.tryParse(heightController.text);
    final weight = double.tryParse(weightController.text);

    if (height != null && weight != null && height > 0) {
      setState(() {
        bmi = weight / ((height / 100) * (height / 100));
      });
    } else {
      setState(() {
        bmi = null;
      });
    }
  }

  void saveData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('資料已儲存', style: TextStyle(fontSize: 20))),
    );
  }

  Widget buildTextField(String label, TextEditingController controller,
      {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onChanged: (label == '身高 (cm)' || label == '體重 (kg)')
            ? (_) => calculateBMI()
            : null,
        style: const TextStyle(fontSize: 24),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 24),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          fillColor: Colors.white,
          filled: true,
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('健康紀錄', style: TextStyle(fontSize: 26)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            buildTextField('身高 (cm)', heightController),
            buildTextField('體重 (kg)', weightController),
            buildTextField('收縮壓 (mmHg)', systolicController),
            buildTextField('舒張壓 (mmHg)', diastolicController),
            buildTextField('心率 (bpm)', heartRateController),
            buildTextField(
              'BMI',
              TextEditingController(
                text: bmi != null ? bmi!.toStringAsFixed(1) : '',
              ),
              readOnly: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saveData,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                textStyle: const TextStyle(fontSize: 24),
              ),
              child: const Text('儲存資料'),
            ),
          ],
        ),
      ),
    );
  }
}
