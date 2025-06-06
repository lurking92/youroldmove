import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:google_fonts/google_fonts.dart';

class FirstCollectDataPage extends StatefulWidget {
  const FirstCollectDataPage({super.key});

  @override
  State<FirstCollectDataPage> createState() => _ProfileSetupFlowState();
}

class _ProfileSetupFlowState extends State<FirstCollectDataPage> {
  final PageController _pageController = PageController();
  final int _totalPages = 4;
  int _currentPage = 0;

  String? _gender;
  DateTime? _birthDate;
  int _height = 170;
  int _weight = 65;
  List<String> _selectedGoals = [];

  final _genders = ['Male', 'Female', 'Other'];
  final _goals = ['Maintain Health', 'Improve Fitness', 'Control Weight'];

  bool _isSaving = false;
  final user = FirebaseAuth.instance.currentUser;

  void _nextPage() {
    if (_currentPage == 0 && (_gender == null || _birthDate == null)) {
      _showDialog('Please fill in gender and birth date.');
      return;
    } else if (_currentPage == 1 && (_height == 0 || _weight == 0)) {
      _showDialog('Please set height and weight.');
      return;
    }

    if (_currentPage < _totalPages - 1) {
      setState(() => _currentPage++);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveData() async {
    if (_gender == null || _birthDate == null || _height == 0 || _weight == 0) {
      _showDialog('Please fill in all required fields.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'gender': _gender,
        'birthDate': _birthDate!.toIso8601String(),
        if (_selectedGoals.isNotEmpty) 'goals': _selectedGoals,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('healthData').doc(uid).set({
        'height': _height,
        'weight': _weight,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      _showDialog('Failed to save: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notice'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _birthDate = DateTime.tryParse(
      FirebaseAuth.instance.currentUser?.metadata.creationTime?.toIso8601String() ?? '',
    ) ?? DateTime(2000);
  }

  Widget _buildPageContent() {
    final iconMap = {
      'Male': Icons.male,
      'Female': Icons.female,
      'Other': Icons.transgender,
    };

    switch (_currentPage) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Select Your Gender', style: GoogleFonts.notoSans(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: _genders.map((g) {
                final isSelected = _gender == g;
                return GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.orange.shade100 : Colors.white,
                      border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade300, width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconMap[g], size: 40, color: Colors.black87),
                        const SizedBox(height: 12),
                        Text(g, style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            ListTile(
              title: Text('Birth Date', style: GoogleFonts.notoSans(fontSize: 20)),
              subtitle: Text(
                _birthDate != null
                    ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
                    : 'Select a date',
                style: GoogleFonts.notoSans(fontSize: 18),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _birthDate!,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
          ],
        );

      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Your Height (cm)', style: GoogleFonts.notoSans(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            NumberPicker(
              value: _height,
              minValue: 100,
              maxValue: 220,
              step: 1,
              itemHeight: 50,
              selectedTextStyle: GoogleFonts.notoSans(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange),
              onChanged: (val) => setState(() => _height = val),
            ),
            const SizedBox(height: 40),
            Text('Your Weight (kg)', style: GoogleFonts.notoSans(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            NumberPicker(
              value: _weight,
              minValue: 30,
              maxValue: 150,
              step: 1,
              itemHeight: 50,
              selectedTextStyle: GoogleFonts.notoSans(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange),
              onChanged: (val) => setState(() => _weight = val),
            ),
          ],
        );

      case 2:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Select your fitness goals',
              style: GoogleFonts.notoSans(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ..._goals.map((goal) {
              final isSelected = _selectedGoals.contains(goal);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    isSelected
                        ? _selectedGoals.remove(goal)
                        : _selectedGoals.add(goal);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade100 : Colors.white,
                    border: Border.all(
                        color: isSelected ? Colors.orange : Colors.grey.shade300,
                        width: 2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      )
                    ]
                        : [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle : Icons.circle_outlined,
                        color: isSelected ? Colors.orange : Colors.grey,
                        size: 26,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          goal,
                          style: GoogleFonts.notoSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            if (_selectedGoals.isEmpty)
              TextButton(
                onPressed: _nextPage,
                child: Text('Skip',
                    style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700)),
              ),
          ],
        );

      case 3:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 72, color: Colors.green),
              const SizedBox(height: 24),
              Text(
                'Setup Complete!',
                style: GoogleFonts.notoSans(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  textStyle: GoogleFonts.notoSans(fontSize: 20),
                ),
                child: const Text('Start Using the App'),
              ),
            ],
          ),
        );


      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: _currentPage < _totalPages -1
          ? Text('Step ${_currentPage + 1} of ${_totalPages - 1}',
                style: GoogleFonts.notoSans(fontSize: 22))
          : const SizedBox.shrink(),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : PageView.builder(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _totalPages,
          itemBuilder: (context, index) => _buildPageContent(),
        ),
      ),
      bottomNavigationBar: _currentPage == _totalPages - 1
          ? null
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: _currentPage > 0
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.end,
          children: [
            if (_currentPage > 0)
              TextButton(
                onPressed: _previousPage,
                child: Text('Back', style: GoogleFonts.notoSans(fontSize: 18)),
              ),
            ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Next', style: GoogleFonts.notoSans(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
