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
                        backgroundImage: AssetImage(
                          'assets/images/profile.png',
                        ),
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
                    onPressed: () {
                      Navigator.pushNamed(context, '/record');
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Calories
              const Center(
                child: Column(
                  children: [
                    Text(
                      '1 883 Kcal',
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
                  _StatItem(label: 'Distance', value: '7 580 m'),
                  _StatItem(label: 'Steps', value: '9 832'),
                  _StatItem(label: 'Points', value: '1 248'),
                ],
              ),

              const SizedBox(height: 24),

              // Current Points & Rank Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Current Points
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Points',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(Icons.star, color: Colors.amber, size: 28),
                            SizedBox(width: 4),
                            Text(
                              '1 234',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Text('pts', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ],
                    ),

                    // Right: Rank
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Rank',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.emoji_events,
                              color: Colors.orange,
                              size: 28,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '#5',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Recent Runs Section
              const Text(
                'Recent Runs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 8.0 * 2;
                  final cardWidth = (constraints.maxWidth - spacing) / 3;
                  return Row(
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: const _RunCard(
                          date: 'Jul 7',
                          distanceKm: 5.0,
                          duration: '30 min',
                          difficulty: 'Easy',
                          kcal: 300,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: cardWidth,
                        child: const _RunCard(
                          date: 'Jul 6',
                          distanceKm: 6.2,
                          duration: '35 min',
                          difficulty: 'Medium',
                          kcal: 380,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: cardWidth,
                        child: const _RunCard(
                          date: 'Jul 5',
                          distanceKm: 4.5,
                          duration: '25 min',
                          difficulty: 'Easy',
                          kcal: 260,
                        ),
                      ),
                    ],
                  );
                },
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
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/team');
              break;
            case 1:
              Navigator.pushNamed(context, '/start');
              break;
            case 2:
              break;
            case 3:
              Navigator.pushNamed(context, '/health');
              break;
            case 4:
              Navigator.pushNamed(context, '/setting');
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

class _RunCard extends StatelessWidget {
  final String date;
  final double distanceKm;
  final String duration;
  final String difficulty;
  final int kcal;

  const _RunCard({
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.difficulty,
    required this.kcal,
  });

  Color get _bgColor {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green.withOpacity(0.1);
      case 'medium':
        return Colors.orange.withOpacity(0.1);
      case 'hard':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
        difficulty.toLowerCase() == 'easy'
            ? Colors.green
            : difficulty.toLowerCase() == 'medium'
            ? Colors.orange
            : Colors.red;
    return Container(
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.directions_run, size: 30, color: iconColor),
          const SizedBox(height: 8),
          Text(
            date,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            duration,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 20,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 4),
              Text(
                '$kcal kcal',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              difficulty,
              style: TextStyle(fontSize: 16, color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}
