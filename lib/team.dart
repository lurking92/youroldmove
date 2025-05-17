import 'package:flutter/material.dart';
import 'package:myapp/team_detail.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  // 模擬已加入的團隊列表
  final List<String> _joinedTeams = ['Team A', 'Team B', 'Team C'];

  void _showAddTeamOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Creat a new team'),
              onTap: () {
                Navigator.pop(context);
                // 導航到創建團隊頁面或顯示創建團隊的對話框
                print('創建團隊');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Join team'),
              onTap: () {
                Navigator.pop(context);
                // 導航到加入團隊頁面或顯示加入團隊的對話框
                print('加入團隊');
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToTeamDetail(String teamName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailPage(teamName: teamName),
      ),
    );
    print('導航到 $teamName 的詳細頁面');
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTeamOptions,
        child: const Icon(Icons.add),
      ),
      body: _joinedTeams.isEmpty
          ? const Center(
        child: Text('您尚未加入任何團隊'),
      )
          : ListView.builder(
        itemCount: _joinedTeams.length,
        itemBuilder: (context, index) {
          final teamName = _joinedTeams[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(teamName),
              onTap: () => _navigateToTeamDetail(teamName),
            ),
          );
        },
      ),
    );
  }
}
