import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        // backgroundImage: AssetImage(
                        //   'assets/images/profile.png',
                        // ),
                        radius: 24,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hello Linh!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Thursday, 08 July',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Calories
              const Center(
                child: Column(
                  children: [
                    Text(
                      '1 883 Kcal',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Total Kilocalories',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  _StatItem(label: 'Distance', value: '7580 m'),
                  _StatItem(label: 'Steps', value: '9832'),
                  _StatItem(label: 'Points', value: '1248'),
                ],
              ),

              const SizedBox(height: 24),

              // Activity Bars (Mocked)
              Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: const Center(child: Text('Activity Chart Placeholder')),
              ),

              const SizedBox(height: 24),

              // Exercise Cards
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _ExerciseCard(
                    title: 'Dumbbell',
                    kcal: 628,
                    icon: Icons.fitness_center,
                    color: Color(0xFFFF6B6B),
                  ),
                  _ExerciseCard(
                    title: 'Treadmill',
                    kcal: 235,
                    icon: Icons.directions_run,
                    color: Colors.deepPurpleAccent,
                  ),
                  _ExerciseCard(
                    title: 'Rope',
                    kcal: 432,
                    icon: Icons.sports,
                    color: Colors.orange,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Plan Section
              const Text(
                'My Plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text('July, 2021', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text('Training Plan Placeholder')),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        iconSize: 32,
        selectedFontSize: 14,
        unselectedFontSize: 12,
        selectedIconTheme: const IconThemeData(size: 36),
        unselectedIconTheme: const IconThemeData(size: 28),
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/team');
              break;
            case 1:
              Navigator.pushNamed(context, '/start');
              break;
            case 2:
              // Already on Home
              break;
            case 3:
              Navigator.pushNamed(context, '/health');
              break;
            case 4:
              Navigator.pushNamed(context, '/settings');
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Team'),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle),
            label: 'Start',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Health'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final int kcal;
  final IconData icon;
  final Color color;

  const _ExerciseCard({
    required this.title,
    required this.kcal,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 8),
            Text(
              '$kcal Kcal',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Colors.black)),
          ],
        ),
      ),
    );
  }
}
