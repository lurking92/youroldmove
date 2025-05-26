import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 導入 Firestore
import 'package:firebase_auth/firebase_auth.dart'; // 導入 Firebase Auth (用於獲取當前使用者ID)
import 'package:myapp/team_detail.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  // 獲取 Firestore 實例
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // 獲取 Firebase Auth 實例
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // 獲取當前登入的使用者 ID
  String? get currentUserId => _auth.currentUser?.uid;

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
                _showCreateTeamDialog(); // 呼叫創建團隊對話框
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Join team'),
              onTap: () {
                Navigator.pop(context);
                // 導航到加入團隊頁面或顯示加入團隊的對話框
                _showJoinTeamDialog(); // 呼叫加入團隊對話框
              },
            ),
          ],
        );
      },
    );
  }

  // 顯示創建團隊的對話框
  void _showCreateTeamDialog() {
    String newTeamName = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Team'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter team name'),
            onChanged: (value) {
              newTeamName = value.trim(); // 使用 .trim() 移除前後空白
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('Create'),
              onPressed: () async {
                if (newTeamName.isNotEmpty && currentUserId != null) {
                  try {
                    // 檢查團隊名稱是否已經存在 (可選)
                    final existingTeam = await _firestore.collection('teams')
                        .where('teamName', isEqualTo: newTeamName)
                        .limit(1)
                        .get();

                    if (existingTeam.docs.isNotEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Team "$newTeamName" already exists.')),
                      );
                      return;
                    }

                    // 1. 在 'teams' 集合中創建新團隊文件
                    DocumentReference teamRef = await _firestore.collection('teams').add({
                      'teamName': newTeamName,
                      'creatorId': currentUserId,
                      'memberIds': [currentUserId], // 創建者自動成為成員
                      'createdAt': FieldValue.serverTimestamp(), // 使用 Firebase 伺服器時間戳
                      'inviteCode': _generateInviteCode(), // 生成邀請碼 (簡化處理)
                    });

                    // 2. 更新當前使用者的 'users' 集合中的 'joinedTeamIds' 欄位
                    await _firestore.collection('users').doc(currentUserId).update({
                      'joinedTeamIds': FieldValue.arrayUnion([teamRef.id]), // 添加團隊ID到陣列
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Team "$newTeamName" created successfully!')),
                    );
                    print('創建團隊成功: $newTeamName, ID: ${teamRef.id}');
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating team: $e')),
                    );
                    print('創建團隊失敗: $e');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team name cannot be empty and you must be logged in.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 顯示加入團隊的對話框
  void _showJoinTeamDialog() {
    String teamCode = '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join Team'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter team code'),
            onChanged: (value) {
              teamCode = value.trim();
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text('Join'),
              onPressed: () async {
                if (teamCode.isNotEmpty && currentUserId != null) {
                  try {
                    // 1. 查詢團隊是否存在且邀請碼匹配
                    final teamSnapshot = await _firestore.collection('teams')
                        .where('inviteCode', isEqualTo: teamCode)
                        .limit(1)
                        .get();

                    if (teamSnapshot.docs.isEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Team not found or invalid code.')),
                      );
                      return;
                    }

                    final teamDoc = teamSnapshot.docs.first;
                    final String teamId = teamDoc.id;
                    final List<dynamic> memberIds = teamDoc.data()['memberIds'] ?? [];

                    // 檢查使用者是否已經在團隊中
                    if (memberIds.contains(currentUserId)) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You are already a member of this team.')),
                      );
                      return;
                    }

                    // 2. 更新 'teams' 集合中該團隊的 'memberIds' 欄位
                    await _firestore.collection('teams').doc(teamId).update({
                      'memberIds': FieldValue.arrayUnion([currentUserId]), // 添加使用者ID到陣列
                    });

                    // 3. 更新當前使用者的 'users' 集合中的 'joinedTeamIds' 欄位
                    await _firestore.collection('users').doc(currentUserId).update({
                      'joinedTeamIds': FieldValue.arrayUnion([teamId]), // 添加團隊ID到陣列
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully joined team "${teamDoc.data()['teamName']}"!')),
                    );
                    print('成功加入團隊: ${teamDoc.data()['teamName']}, ID: $teamId');
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining team: $e')),
                    );
                    print('加入團隊失敗: $e');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team code cannot be empty and you must be logged in.')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToTeamDetail(String teamName, String teamId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamDetailPage(teamName: teamName, teamId: teamId),
      ),
    );
    print('導航到 $teamName 的詳細頁面');
  }

  // 簡單的邀請碼生成器
  String _generateInviteCode() {
    return UniqueKey().toString().substring(2, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // 使用 StreamBuilder 從 Firebase 實時獲取使用者加入的團隊列表
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTeamOptions,
        child: const Icon(Icons.add),
      ),
      body: currentUserId == null
          ? const Center(
        child: Text('Please log in to view and manage your teams.'), // 請登入
      )
          : StreamBuilder<DocumentSnapshot>(
        // 監聽當前使用者的 document，以獲取其加入的團隊 IDs
        stream: _firestore.collection('users').doc(currentUserId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // 載入中
          }
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}')); // 錯誤
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('User data not found. Please ensure you are logged in.')); // 無使用者資料
          }

          final userJoinedTeamIds = userSnapshot.data!['joinedTeamIds'] as List<dynamic>? ?? [];

          if (userJoinedTeamIds.isEmpty) {
            return const Center(
              child: Text('You haven\'t joined any teams yet.'), // 您尚未加入任何團隊
            );
          }

          // 如果使用者加入了團隊，根據團隊 ID 查詢這些團隊的詳細資訊
          // 注意：Firestore 的 in 查詢有 10 個元素的限制，如果 joinedTeamIds 很多，需要分批查詢
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('teams')
                .where(FieldPath.documentId, whereIn: userJoinedTeamIds)
                .snapshots(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator()); // 載入中
              }
              if (teamSnapshot.hasError) {
                return Center(child: Text('Error loading teams: ${teamSnapshot.error}')); // 錯誤
              }
              if (!teamSnapshot.hasData || teamSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No teams found.')); // 無團隊
              }

              final List<DocumentSnapshot> teams = teamSnapshot.data!.docs;

              return ListView.builder(
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final teamDoc = teams[index];
                  final teamData = teamDoc.data() as Map<String, dynamic>;
                  final teamName = teamData['teamName'] as String? ?? 'Unnamed Team';
                  final teamId = teamDoc.id; // 獲取團隊文件 ID

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(teamName),
                      // 傳遞團隊名稱和團隊 ID 到詳細頁面
                      onTap: () => _navigateToTeamDetail(teamName, teamId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
