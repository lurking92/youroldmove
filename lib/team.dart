import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth (for current user ID)
import 'package:myapp/team_detail.dart';

class TeamPage extends StatefulWidget {
  const TeamPage({super.key});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  // Get Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Get Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Get current logged-in user ID
  String? get currentUserId => _auth.currentUser?.uid;

  void _showAddTeamOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 增大「Create a new team」選項的觸控區域
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), // 增加垂直內邊距
              leading: const Icon(Icons.add, size: 36), // 增大圖標
              title: const Text(
                'Create a new team',
                style: TextStyle(fontSize: 22), // 增大文字大小
              ),
              onTap: () {
                Navigator.pop(context);
                _showCreateTeamDialog();
              },
            ),
            // 增大「Join team」選項的觸控區域
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), // 增加垂直內邊距
              leading: const Icon(Icons.group_add, size: 36), // 增大圖標
              title: const Text(
                'Join team',
                style: TextStyle(fontSize: 22), // 增大文字大小
              ),
              onTap: () {
                Navigator.pop(context);
                _showJoinTeamDialog();
              },
            ),
          ],
        );
      },
    );
  }

  // Display create team dialog
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
              newTeamName = value.trim();
            },
            style: const TextStyle(fontSize: 20), // 增大輸入文字大小
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 增大按鈕內邊距
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 18), // 增大按鈕文字
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 增大按鈕內邊距
              ),
              child: const Text(
                'Create',
                style: TextStyle(fontSize: 18), // 增大按鈕文字
              ),
              onPressed: () async {
                if (newTeamName.isNotEmpty && currentUserId != null) {
                  try {
                    final existingTeam = await _firestore.collection('teams')
                        .where('teamName', isEqualTo: newTeamName)
                        .limit(1)
                        .get();

                    if (existingTeam.docs.isNotEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Team "$newTeamName" already exists.', style: const TextStyle(fontSize: 18))), // 增大SnackBar文字
                      );
                      return;
                    }

                    DocumentReference teamRef = await _firestore.collection('teams').add({
                      'teamName': newTeamName,
                      'creatorId': currentUserId,
                      'memberIds': [currentUserId],
                      'createdAt': FieldValue.serverTimestamp(),
                      'inviteCode': _generateInviteCode(),
                    });

                    await _firestore.collection('users').doc(currentUserId).update({
                      'joinedTeamIds': FieldValue.arrayUnion([teamRef.id]),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Team "$newTeamName" created successfully!', style: const TextStyle(fontSize: 18))), // 增大SnackBar文字
                    );
                    print('Team created successfully: $newTeamName, ID: ${teamRef.id}');
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating team: $e', style: const TextStyle(fontSize: 18))), // 增大SnackBar文字
                    );
                    print('Error creating team: $e');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team name cannot be empty and you must be logged in.', style: TextStyle(fontSize: 18))), // 增大SnackBar文字
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Display join team dialog
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
            style: const TextStyle(fontSize: 20), // 增大輸入文字大小
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 增大按鈕內邊距
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 18), // 增大按鈕文字
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), // 增大按鈕內邊距
              ),
              child: const Text(
                'Join',
                style: TextStyle(fontSize: 18), // 增大按鈕文字
              ),
              onPressed: () async {
                if (teamCode.isNotEmpty && currentUserId != null) {
                  try {
                    final teamSnapshot = await _firestore.collection('teams')
                        .where('inviteCode', isEqualTo: teamCode)
                        .limit(1)
                        .get();

                    if (teamSnapshot.docs.isEmpty) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Team not found or invalid code.', style: TextStyle(fontSize: 18))), // 增大SnackBar文字
                      );
                      return;
                    }

                    final teamDoc = teamSnapshot.docs.first;
                    final String teamId = teamDoc.id;
                    final List<dynamic> memberIds = teamDoc.data()['memberIds'] ?? [];

                    if (memberIds.contains(currentUserId)) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You are already a member of this team.', style: TextStyle(fontSize: 18))), // 增大SnackBar文字
                      );
                      return;
                    }

                    await _firestore.collection('teams').doc(teamId).update({
                      'memberIds': FieldValue.arrayUnion([currentUserId]),
                    });

                    await _firestore.collection('users').doc(currentUserId).update({
                      'joinedTeamIds': FieldValue.arrayUnion([teamId]),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Successfully joined team "${teamDoc.data()['teamName']}"!', style: const TextStyle(fontSize: 18))), // 增大SnackBar文字
                    );
                    print('Successfully joined team: ${teamDoc.data()['teamName']}, ID: $teamId');
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error joining team: $e', style: const TextStyle(fontSize: 18))), // 增大SnackBar文字
                    );
                    print('Error joining team: $e');
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Team code cannot be empty and you must be logged in.', style: TextStyle(fontSize: 18))), // 增大SnackBar文字
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
    print('Navigating to team detail page for $teamName');
  }

  // Simple invite code generator
  String _generateInviteCode() {
    return UniqueKey().toString().substring(2, 8).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Team',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), // 增大AppBar標題字體
        ),
        centerTitle: true, // 標題居中
      ),
      // 增大 FloatingActionButton 的大小
      floatingActionButton: FloatingActionButton.large(
        onPressed: _showAddTeamOptions,
        backgroundColor: Colors.orange.shade500,
        foregroundColor: Colors.white, // 圖標顏色
        shape: const CircleBorder(), // 確保是圓形按鈕
        elevation: 6, // 增加陰影效果
        child: const Icon(
          Icons.add,
          size: 70, // 增大 + 號圖標
        ),
      ),
      body: currentUserId == null
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0), // 增加內邊距
          child: Text(
            'Please log in to view and manage your teams.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, color: Colors.grey), // 增大字體
          ),
        ),
      )
          : StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(currentUserId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 4)); // 增大進度條
          }
          if (userSnapshot.hasError) {
            return Center(child: Text('Error: ${userSnapshot.error}', style: const TextStyle(fontSize: 18))); // 增大字體
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'User data not found. Please ensure you are logged in.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.grey), // 增大字體
                ),
              ),
            );
          }

          final userJoinedTeamIds = userSnapshot.data!['joinedTeamIds'] as List<dynamic>? ?? [];

          if (userJoinedTeamIds.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'You haven\'t joined any teams yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.grey), // 增大字體
                ),
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('teams')
                .where(FieldPath.documentId, whereIn: userJoinedTeamIds)
                .snapshots(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 4)); // 增大進度條
              }
              if (teamSnapshot.hasError) {
                return Center(child: Text('Error loading teams: ${teamSnapshot.error}', style: const TextStyle(fontSize: 18))); // 增大字體
              }
              if (!teamSnapshot.hasData || teamSnapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No teams found.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.grey), // 增大字體
                    ),
                  ),
                );
              }

              final List<DocumentSnapshot> teams = teamSnapshot.data!.docs;

              return ListView.builder(
                itemCount: teams.length,
                itemBuilder: (context, index) {
                  final teamDoc = teams[index];
                  final teamData = teamDoc.data() as Map<String, dynamic>;
                  final teamName = teamData['teamName'] as String? ?? 'Unnamed Team';
                  final teamId = teamDoc.id;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // 增加垂直間距
                    elevation: 4, // 增加卡片陰影
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // 圓角邊框
                    ),
                    child: InkWell( // 使用 InkWell 讓點擊效果更明顯
                      onTap: () => _navigateToTeamDetail(teamName, teamId),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0), // 增加卡片內邊距
                        child: Row(
                          children: [
                            const Icon(Icons.group, size: 40, color: Colors.blueAccent), // 增大群組圖標
                            const SizedBox(width: 15), // 增加圖標和文字的間距
                            Expanded(
                              child: Text(
                                teamName,
                                style: const TextStyle(
                                  fontSize: 24, // 增大團隊名稱字體
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 28, color: Colors.grey), // 增大箭頭圖標
                          ],
                        ),
                      ),
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
