import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeamDetailPage extends StatefulWidget {
  final String teamName;
  final String teamId; // 新增 teamId

  const TeamDetailPage({super.key, required this.teamName, required this.teamId}); // 建構函數

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.teamName), // 使用 widget.teamName
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Name (已經在 AppBar 顯示，這裡可以選擇是否再顯示一次)
            // Text(
            //   widget.teamName,
            //   style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            // ),
            // const SizedBox(height: 20),

            const Text(
              'Team Members', // 隊伍成員
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // --- Real Team Members List from Firebase ---
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                // 監聽特定 teamId 的團隊文件
                stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
                builder: (context, teamSnapshot) {
                  if (teamSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator()); // 載入中
                  }
                  if (teamSnapshot.hasError) {
                    return Center(child: Text('Error: ${teamSnapshot.error}')); // 錯誤
                  }
                  if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                    return const Center(child: Text('Team not found.')); // 團隊不存在
                  }

                  // 獲取團隊數據
                  final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
                  if (teamData == null) {
                    return const Center(child: Text('Team data is empty.'));
                  }

                  // 獲取成員 ID 列表
                  final List<dynamic> memberIds = teamData['memberIds'] ?? [];

                  if (memberIds.isEmpty) {
                    return const Center(child: Text('No members in this team yet.')); // 團隊中尚無成員
                  }

                  // 根據 memberIds 查詢每個成員的詳細資料（主要是姓名）
                  // 使用 FutureBuilder 來處理一次性獲取所有成員姓名
                  return FutureBuilder<List<DocumentSnapshot>>(
                    future: _getMembersData(memberIds), // 呼叫一個異步函數來獲取成員資料
                    builder: (context, membersSnapshot) {
                      if (membersSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator()); // 載入中
                      }
                      if (membersSnapshot.hasError) {
                        return Center(child: Text('Error loading members: ${membersSnapshot.error}')); // 錯誤
                      }
                      if (!membersSnapshot.hasData || membersSnapshot.data!.isEmpty) {
                        return const Center(child: Text('No member details found.')); // 無成員詳情
                      }

                      final List<DocumentSnapshot> memberDocs = membersSnapshot.data!;

                      return ListView.builder(
                        itemCount: memberDocs.length,
                        itemBuilder: (context, index) {
                          final memberData = memberDocs[index].data() as Map<String, dynamic>?;
                          final memberName = memberData?['name'] as String? ?? 'Unknown User'; // 獲取成員姓名

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              title: Text(memberName), // 顯示真實的成員姓名
                              // 您可以在這裡添加更多成員資訊，例如他們的總分等
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // --- End Real Team Members List ---

            const SizedBox(height: 20),

            // Leaderboard Title
            const Text(
              'Leaderboard', // 排行榜
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Leaderboard (暫時仍使用模擬資料，待後續處理)
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

  // 非同步函數：根據成員 ID 列表獲取成員的詳細資料
  Future<List<DocumentSnapshot>> _getMembersData(List<dynamic> memberIds) async {
    if (memberIds.isEmpty) {
      return [];
    }

    // Firestore 的 'whereIn' 查詢有 10 個元素的限制，如果 memberIds 超過 10 個，需要分批查詢
    // 這裡為了簡化，假設 memberIds 不會超過 10 個。
    // 如果您的團隊成員會很多，需要實作分批查詢邏輯。
    final querySnapshot = await _firestore.collection('users')
        .where(FieldPath.documentId, whereIn: memberIds)
        .get();

    return querySnapshot.docs;
  }
}