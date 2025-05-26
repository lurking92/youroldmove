import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class TeamDetailPage extends StatefulWidget {
  final String teamName;
  final String teamId;

  const TeamDetailPage({super.key, required this.teamName, required this.teamId});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // 獲取 Firebase Auth
  String? _currentUserId; // 用於儲存當前登入使用者的 UID

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid; // 在 initState 中獲取當前使用者 UID
  }

  // 彈出確認對話框並執行刪除操作
  Future<void> _confirmAndDeleteTeam(DocumentSnapshot teamDoc) async {
    final teamData = teamDoc.data() as Map<String, dynamic>?;
    if (teamData == null) return; // defensive check

    final creatorId = teamData['creatorId'] as String?;
    final teamName = teamData['teamName'] as String? ?? 'Unnamed Team';
    final List<dynamic> memberIds = teamData['memberIds'] ?? []; // 獲取所有成員ID，以便後續清理

    // 檢查是否為團隊創建者
    if (_currentUserId == null || _currentUserId != creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the team creator can delete this team.')),
      );
      return; // 如果不是創建者，則不允許刪除
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Team'), // 刪除隊伍
          content: Text('Are you sure you want to delete the team "$teamName"? This action cannot be undone.'), // 您確定要刪除隊伍 "$teamName" 嗎？此操作無法撤銷。
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'), // 取消
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red), // 紅色按鈕
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        WriteBatch batch = _firestore.batch();

        // 1. 從 'teams' 集合中刪除團隊文件
        batch.delete(_firestore.collection('teams').doc(widget.teamId));

        // 2. 清理所有成員的 'users' 集合中的 'joinedTeamIds' 欄位
        // 這一步很關鍵：當團隊被刪除時，要將該團隊ID從所有成員的 joinedTeamIds 列表中移除
        for (String memberId in memberIds.cast<String>()) {
          batch.update(_firestore.collection('users').doc(memberId), {
            'joinedTeamIds': FieldValue.arrayRemove([widget.teamId]),
          });
        }

        // 提交批次操作
        await batch.commit();

        if (!mounted) return; // 檢查 widget 是否仍然在樹上，避免在 pop 後 setState
        Navigator.of(context).pop(); // 導航回上一頁 (TeamPage)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team "$teamName" deleted successfully!')), // 隊伍 "$teamName" 已成功刪除！
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete team: $e')), // 刪除隊伍失敗！
        );
        print('Error deleting team: $e');
      }
    }
  }

  // 非同步函數：根據成員 ID 列表獲取成員的詳細資料
  Future<List<DocumentSnapshot>> _getMembersData(List<dynamic> memberIds) async {
    if (memberIds.isEmpty) {
      return [];
    }
    // Firestore 的 'whereIn' 查詢有 10 個元素的限制。
    // 如果 memberIds 超過 10 個，這個查詢會失敗。
    final querySnapshot = await _firestore.collection('users')
        .where(FieldPath.documentId, whereIn: memberIds)
        .get();

    return querySnapshot.docs;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName),
        actions: [
          // 只有當前使用者是團隊創建者時才顯示刪除按鈕
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator()); // 載入中
              }
              if (teamSnapshot.hasError) {
                print("Error loading team data for delete button: ${teamSnapshot.error}");
                return const SizedBox.shrink(); // 錯誤時隱藏按鈕
              }
              if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                return const SizedBox.shrink(); // 團隊不存在時隱藏按鈕
              }

              final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
              final creatorId = teamData?['creatorId'] as String?;

              // 如果當前使用者已登入且是團隊創建者，則顯示刪除按鈕
              if (_currentUserId != null && _currentUserId == creatorId) {
                return IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmAndDeleteTeam(teamSnapshot.data!), // 傳遞 teamDoc 以獲取其數據
                );
              }
              return const SizedBox.shrink(); // 否則隱藏按鈕
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 邀請碼顯示區塊 ---
            StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
              builder: (context, teamSnapshot) {
                if (teamSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (teamSnapshot.hasError) {
                  print("Error loading team data for invite code: ${teamSnapshot.error}");
                  return const SizedBox.shrink();
                }
                if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
                final inviteCode = teamData?['inviteCode'] as String? ?? 'N/A'; // 獲取邀請碼

                // 移除創建者判斷，讓所有成員都可見
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Invite Code:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Invite code copied to clipboard!')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                inviteCode,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.blue),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, size: 18, color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
            const Text(
              'Team Members', // 隊伍成員
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
                builder: (context, teamSnapshot) {
                  if (teamSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (teamSnapshot.hasError) {
                    return Center(child: Text('Error: ${teamSnapshot.error}'));
                  }
                  if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                    return const Center(child: Text('Team not found.'));
                  }

                  final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
                  if (teamData == null) {
                    return const Center(child: Text('Team data is empty.'));
                  }

                  final List<dynamic> memberIds = teamData['memberIds'] ?? [];

                  if (memberIds.isEmpty) {
                    return const Center(child: Text('No members in this team yet.'));
                  }

                  return FutureBuilder<List<DocumentSnapshot>>(
                    future: _getMembersData(memberIds),
                    builder: (context, membersSnapshot) {
                      if (membersSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (membersSnapshot.hasError) {
                        return Center(child: Text('Error loading members: ${membersSnapshot.error}'));
                      }
                      if (!membersSnapshot.hasData || membersSnapshot.data!.isEmpty) {
                        return const Center(child: Text('No member details found.'));
                      }

                      final List<DocumentSnapshot> memberDocs = membersSnapshot.data!;

                      return ListView.builder(
                        itemCount: memberDocs.length,
                        itemBuilder: (context, index) {
                          final memberData = memberDocs[index].data() as Map<String, dynamic>?;
                          final memberName = memberData?['name'] as String? ?? 'Unknown User';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(memberName),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'Leaderboard',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 10,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Text('${index + 1}'),
                    title: Text('User ${index + 1}'),
                    trailing: Text('${(1000 - index * 50)} pts'),
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