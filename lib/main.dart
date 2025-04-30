import 'package:flutter/material.dart';
import 'dart:math';
import 'login.dart';

void main() {
  runApp(const SportApp());
}

class SportApp extends StatelessWidget {
  const SportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '複利計算機',
      theme: ThemeData(primarySwatch: Colors.pink),
      initialRoute: '/',
      routes: {
        '/': (context) => const Login(),
        '/calculator': (context) => const CalculatorPage(),
      },
      // home: const CalculatorPage(),
    );
  }
}

// 下拉式選單
class DropdownWidget extends StatefulWidget {
  final int selectedValue; // 用來表示下拉選單當前被選中的值,被宣告為final，在Widget建構後就不能再改變
  final ValueChanged<int?> onChanged; // 在下拉選單中選擇新的值時，這個函式就會被呼叫，并更新其狀態
  const DropdownWidget({
    super.key,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  _DropdownWidgetState createState() => _DropdownWidgetState();
}

class _DropdownWidgetState extends State<DropdownWidget> {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value: widget.selectedValue,
      hint: const Text('請選擇', style: TextStyle(fontSize: 20)),
      items: const <DropdownMenuItem<int>>[
        DropdownMenuItem(
          value: 1, // 選項1
          child: Text('複利計算機', style: TextStyle(fontSize: 15)),
        ),
        DropdownMenuItem<int>(
          enabled: false, // 分割綫
          value: null, // 不可點選
          child: Divider(thickness: 0.5),
        ),
        DropdownMenuItem(
          value: 2, // 選項2
          child: Text('借款還款試算計算機', style: TextStyle(fontSize: 15)),
        ),
      ],
      onChanged: widget.onChanged, //當選擇新的選擇的時候，onChanged就會被呼叫並傳送新的值出去
    );
  }
}

enum ActiveField {
  none,
  field1,
  field2,
  field3,
} // none：沒有欄位被選中， field1: 第一個欄位， field2: 第二個欄位， field3: 第三個欄位

// Calculator，使用Stateful爲了能夠動態更新 UI（例如當輸入數字或進行計算時）
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  // 使用 TextEditingController 管理 TextField 的內容
  final TextEditingController _costcontroller =
      TextEditingController(); // 本金/貸款金額
  final TextEditingController _ratecontroller = TextEditingController(); // 利率
  final TextEditingController _yearscontroller =
      TextEditingController(); // 年數/期數

  ActiveField _activeField = ActiveField.field1; // 預設為field1

  int _selectedCalculator = 1; //記錄當前選擇的計算模式（1 為複利計算，2 為借款試算）
  double sum = 0;
  double total = 0;
  // 按鈕按下時的處理邏輯

  void _onButtonPressed(String value) {
    setState(() {
      TextEditingController? controller;
      if (_selectedCalculator == 1) {
        // 根據當前_activeField 判斷應該更新哪個 TextEditingController，使得輸入能夠正確地加到目前正在編輯的欄位中
        if (_activeField == ActiveField.field1) {
          controller = _costcontroller;
        }
        if (_activeField == ActiveField.field2) {
          controller = _ratecontroller;
        }
        if (_activeField == ActiveField.field3) {
          controller = _yearscontroller;
        }
      } else {
        if (_activeField == ActiveField.field1) {
          controller = _costcontroller;
        }
        if (_activeField == ActiveField.field2) {
          controller = _ratecontroller;
        }
        if (_activeField == ActiveField.field3) {
          controller = _yearscontroller;
        }
      }
      if (controller == null) return;

      double cost = double.tryParse(_costcontroller.text) ?? 0;
      double rate = double.tryParse(_ratecontroller.text) ?? 0;
      double years = double.tryParse(_yearscontroller.text) ?? 0;

      switch (value) {
        case 'C': //backspace icon
          if (controller.text.isNotEmpty) {
            controller.text = controller.text.substring(
              0,
              controller.text.length - 1,
            ); // delete text
          }
          break;
        case '=': // 計算結果
          if (_selectedCalculator == 1) {
            sum = cost * pow(1 + rate / 100, years); //本利和
            total = sum - cost; //利息
          } else {
            double r = rate / 100;
            sum =
                cost *
                (r / 12) *
                pow(1 + (r / 12), years) /
                (pow(1 + (r / 12), years) - 1); // 每月應繳，這裏years是月
            total = sum * years; // 總還款金額
          }
          break;
        default:
          // 對於其他按鈕輸入（例如數字），直接追加到文字內容中
          controller.text += value;
      }
    });
  }

  // 建立圓形按鈕的 Widget，使用文字
  Widget _buildButton(
    String text, {
    Color? backgroundColor,
    Color textColor = Colors.black,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(),
      child: ElevatedButton(
        // 透過CircleBorder 呈現圓形按鈕
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: textColor,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
          elevation: 3,
        ),
        onPressed:
            () => _onButtonPressed(text), // 當按下按鈕時，調用 _onButtonPressed 傳入按鈕的文字值
        child: Text(
          text,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 建立圓形按鈕的 Widget，使用圖示（例如 backspace）
  Widget _buildIconButton(
    IconData icon, {
    Color? backgroundColor,
    Color iconColor = Colors.black,
    String value = 'C', // 預設用 'C' 作為刪除最後一個字元的動作
  }) {
    return Container(
      margin: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? Colors.white,
          foregroundColor: iconColor,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
        ),
        onPressed: () => _onButtonPressed(value),
        child: Icon(icon, size: 32),
      ),
    );
  }

  // 根據計算模式動態顯示計算結果（例如複利模式下顯示本利和與利息，借款模式下顯示每月應繳與總還款金額）
  Widget _buildResultText() {
    String resultText;
    if (_selectedCalculator == 1) {
      resultText =
          '本利和： ${sum.toStringAsFixed(2)} 元\n利息： ${total.toStringAsFixed(2)} 元';
    } else {
      resultText =
          '總還款金額：${total.toStringAsFixed(2)} 元\n每月應繳：${sum.toStringAsFixed(2)} 元'; // toStringAsFixed(2) 將數字格式化為小數點後兩位
    }
    return Padding(
      padding: const EdgeInsets.all(1.0),
      child: Text(
        resultText,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  // 選擇的計算模式（複利或借款）分別顯示對應的三個輸入欄位
  Widget _buildInputArea() {
    if (_selectedCalculator == 1) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 複利模式：本金
            TextField(
              controller: _costcontroller,
              decoration: const InputDecoration(
                labelText: '本金',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                setState(() {
                  _activeField = ActiveField.field1;
                });
              },
            ),
            const SizedBox(height: 10),
            // 複利模式：年利率
            TextField(
              controller: _ratecontroller,
              decoration: const InputDecoration(
                labelText: '年利率（%）',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                setState(() {
                  _activeField = ActiveField.field2;
                });
              },
            ),
            const SizedBox(height: 10),
            // 複利模式：年數
            TextField(
              controller: _yearscontroller,
              decoration: const InputDecoration(
                labelText: '年數',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                setState(() {
                  _activeField =
                      ActiveField
                          .field3; // onTap 事件都會呼叫 setState 更新 _activeField,這樣可以精準地知道應該更新哪個欄位
                });
              },
            ),
          ],
        ),
      );
    } else {
      // 借款模式：輸入貸款金額、利率與還款期數（單位：月）
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _costcontroller,
              decoration: const InputDecoration(
                labelText: '貸款金額',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                setState(() {
                  _activeField = ActiveField.field1;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ratecontroller,
              decoration: const InputDecoration(
                labelText: '利率（%）',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                setState(() {
                  _activeField = ActiveField.field2;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _yearscontroller,
              decoration: const InputDecoration(
                labelText: '還款期數（月）',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                setState(() {
                  _activeField = ActiveField.field3;
                });
              },
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        title: const Text('複利計算機'),
      ),
      body: Column(
        children: [
          // 下拉選單區塊
          Padding(
            padding: const EdgeInsets.all(1.0),
            child: DropdownWidget(
              selectedValue: _selectedCalculator,
              onChanged: (value) {
                // 當選擇不同模式時，透過 setState 重置所有輸入欄位（清空文字、重置計算結果）
                setState(() {
                  _selectedCalculator = value!;
                  _activeField = ActiveField.none; //不爲null
                  _costcontroller.clear();
                  _ratecontroller.clear();
                  _yearscontroller.clear();
                  sum = 0;
                  total = 0;
                });
              },
            ),
          ),
          // 輸入欄位
          _buildInputArea(),
          // 結果顯示
          _buildResultText(),
          // button區塊
          Expanded(
            // 使用 GridView.count 將按鈕排成 3 欄的布局
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
              padding: const EdgeInsets.all(4),
              children: [
                // 數字按鈕 7, 8, 9
                _buildButton('7'),
                _buildButton('8'),
                _buildButton('9'),
                // 數字按鈕 4, 5, 6
                _buildButton('4'),
                _buildButton('5'),
                _buildButton('6'),
                // 數字按鈕 1, 2, 3
                _buildButton('1'),
                _buildButton('2'),
                _buildButton('3'),
                // 最後一排：0, 00, backspace 按鈕（圖示）
                _buildButton('0'),
                _buildButton('='),
                _buildIconButton(Icons.backspace, backgroundColor: Colors.pink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
