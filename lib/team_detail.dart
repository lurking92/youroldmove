import 'package:flutter/material.dart';

class TeamDetailPage extends StatelessWidget {
  final String teamName;

  const TeamDetailPage({super.key, required this.teamName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(teamName ?? 'Team Details'), // 團隊詳細資訊
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Name
            Text(
              teamName ?? 'Loading...', // 載入中...
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Team Members Title
            // Team Members Title
            const Text(
              'Team Members', // 隊伍成員
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Team Members List (先用模擬資料)
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // 如果外層有 SingleChildScrollView
                itemCount: 5, // 模擬 5 個成員
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(
                      // Display member avatar
                      child: Icon(Icons.person),
                    ),
                    title: Text('Member ${index + 1}'), // 成員
                    // You can add more member info, e.g., points
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Leaderboard Title
            const Text(
              'Leaderboard', // 排行榜
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Leaderboard (先用模擬資料)
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // 如果外層有 SingleChildScrollView
                itemCount: 10, // 模擬 10 個排行榜條目
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Text('${index + 1}'), // 排名
                    title: Text('User ${index + 1}'), // 使用者
                    trailing: Text('${(1000 - index * 50)} pts'), // 模擬分數
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}