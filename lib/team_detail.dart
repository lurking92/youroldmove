import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // 用於 Clipboard

class TeamDetailPage extends StatefulWidget {
  final String teamName;
  final String teamId;

  const TeamDetailPage({super.key, required this.teamName, required this.teamId});

  @override
  State<TeamDetailPage> createState() => _TeamDetailPageState();
}

class _TeamDetailPageState extends State<TeamDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid;
  }

  Future<void> _confirmAndDeleteTeam(DocumentSnapshot teamDoc) async {
    final teamData = teamDoc.data() as Map<String, dynamic>?;
    if (teamData == null) return;

    final creatorId = teamData['creatorId'] as String?;
    final teamName = teamData['teamName'] as String? ?? 'Unnamed Team';
    final List<dynamic> memberIds = teamData['memberIds'] ?? [];

    if (_currentUserId == null || _currentUserId != creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('只有隊伍創建者可以刪除此隊伍。')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('刪除隊伍', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('您確定要刪除隊伍 "$teamName" 嗎？此操作無法撤銷。'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('取消'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('刪除'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        );
      },
    );

    if (confirm == true) {
      try {
        WriteBatch batch = _firestore.batch();
        batch.delete(_firestore.collection('teams').doc(widget.teamId));
        for (String memberId in memberIds.cast<String>()) {
          batch.update(_firestore.collection('users').doc(memberId), {
            'joinedTeamIds': FieldValue.arrayRemove([widget.teamId]),
          });
        }
        await batch.commit();

        if (!mounted) return;
        // 刪除成功後返回上一頁 (TeamPage)
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('隊伍 "$teamName" 已成功刪除！', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除隊伍失敗：$e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        print('Error deleting team: $e');
      }
    }
  }

  Future<List<DocumentSnapshot>> _getMembersData(List<dynamic> memberIds) async {
    if (memberIds.isEmpty) {
      return [];
    }
    // Firestore in 查詢限制為 10 個，這裡假設成員數不多，若成員數多於 10 需要分批查詢
    final querySnapshot = await _firestore.collection('users')
        .where(FieldPath.documentId, whereIn: memberIds)
        .get();
    return querySnapshot.docs;
  }

  // Helper method to build a single top 3 member card
  Widget _buildTop3MemberCard({
    required int rank,
    required String memberName,
    required int memberScore,
    required Color cardBackgroundColor,
    required Color rankNumberColor,
    required double cardHeight,
    required double avatarRadius,
    required double fontSizeName,
    required double fontSizeScore,
    double? bottomPadding,
  }) {
    return Container(
      width: 100,
      height: cardHeight,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: cardBackgroundColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -30,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 100,
                fontWeight: FontWeight.w900,
                color: rankNumberColor.withOpacity(0.25),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding ?? 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: avatarRadius * 1.1, color: Colors.blueGrey.shade700),
                    // TODO: 如果有用戶頭像 URL，可以在這裡加載
                    // backgroundImage: NetworkImage('your_user_photo_url'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 90,
                    child: Text(
                      memberName,
                      style: TextStyle(
                        fontSize: fontSizeName,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${memberScore} XP',
                    style: TextStyle(
                      fontSize: fontSizeScore,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext){
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.teamName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox.shrink();
              }
              if (teamSnapshot.hasError || !teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
              final creatorId = teamData?['creatorId'] as String?;

              if (_currentUserId != null && _currentUserId == creatorId) {
                return IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 26),
                  tooltip: '刪除團隊',
                  onPressed: () => _confirmAndDeleteTeam(teamSnapshot.data!),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
            builder: (context, teamSnapshot) {
              if (teamSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (teamSnapshot.hasError || !teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                return const SizedBox.shrink();
              }

              final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
              final inviteCode = teamData?['inviteCode'] as String? ?? 'N/A';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '團隊邀請碼',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              inviteCode,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueAccent,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 28, color: Colors.blueAccent),
                          tooltip: '複製邀請碼',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('邀請碼已複製！', style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '團隊總覽',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(height: 5),
                Text(
                  '當前活躍成員表現',
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('teams').doc(widget.teamId).snapshots(),
              builder: (context, teamSnapshot) {
                if (teamSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (teamSnapshot.hasError) {
                  return Center(child: Text('載入團隊數據錯誤：${teamSnapshot.error}'));
                }
                if (!teamSnapshot.hasData || !teamSnapshot.data!.exists) {
                  return const Center(child: Text('找不到此團隊。'));
                }

                final teamData = teamSnapshot.data!.data() as Map<String, dynamic>?;
                if (teamData == null) {
                  return const Center(child: Text('團隊數據為空。'));
                }

                final List<dynamic> memberIds = teamData['memberIds'] ?? [];

                if (memberIds.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          '此團隊目前沒有成員。\n快分享邀請碼給隊友加入吧！',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<List<DocumentSnapshot>>(
                  future: _getMembersData(memberIds),
                  builder: (context, membersSnapshot) {
                    if (membersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (membersSnapshot.hasError) {
                      return Center(child: Text('載入成員數據錯誤：${membersSnapshot.error}'));
                    }
                    if (!membersSnapshot.hasData || membersSnapshot.data!.isEmpty) {
                      return const Center(child: Text('找不到任何成員詳細資料。'));
                    }

                    final List<DocumentSnapshot> memberDocs = membersSnapshot.data!;
                    memberDocs.sort((a, b) {
                      final scoreA = (a.data() as Map<String, dynamic>?)?['score'] as int? ?? 0;
                      final scoreB = (b.data() as Map<String, dynamic>?)?['score'] as int? ?? 0;
                      return scoreB.compareTo(scoreA);
                    });

                    final DocumentSnapshot? firstPlace = memberDocs.isNotEmpty ? memberDocs[0] : null;
                    final DocumentSnapshot? secondPlace = memberDocs.length > 1 ? memberDocs[1] : null;
                    final DocumentSnapshot? thirdPlace = memberDocs.length > 2 ? memberDocs[2] : null;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 前三名展示區 ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              height: 220,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // 第二名 (左邊) - 只有當有第二名時才顯示
                                  if (secondPlace != null)
                                    _buildTop3MemberCard(
                                      rank: 2,
                                      memberName: (secondPlace.data() as Map<String, dynamic>?)?['name'] as String? ?? '未知使用者',
                                      memberScore: (secondPlace.data() as Map<String, dynamic>?)?['score'] as int? ?? 0,
                                      cardBackgroundColor: Colors.blue.shade50,
                                      rankNumberColor: Colors.blue.shade200,
                                      cardHeight: 150,
                                      avatarRadius: 28,
                                      fontSizeName: 15,
                                      fontSizeScore: 13,
                                      bottomPadding: 15,
                                    ),
                                  // 第一名 (中間) - 只要有成員就顯示第一名
                                  if (firstPlace != null)
                                    _buildTop3MemberCard(
                                      rank: 1,
                                      memberName: (firstPlace.data() as Map<String, dynamic>?)?['name'] as String? ?? '未知使用者',
                                      memberScore: (firstPlace.data() as Map<String, dynamic>?)?['score'] as int? ?? 0,
                                      cardBackgroundColor: Colors.amber.shade50,
                                      rankNumberColor: Colors.amber.shade200,
                                      cardHeight: 180,
                                      avatarRadius: 32,
                                      fontSizeName: 16,
                                      fontSizeScore: 14,
                                      bottomPadding: 10,
                                    ),
                                  // 第三名 (右邊) - 只有當有第三名時才顯示
                                  if (thirdPlace != null)
                                    _buildTop3MemberCard(
                                      rank: 3,
                                      memberName: (thirdPlace.data() as Map<String, dynamic>?)?['name'] as String? ?? '未知使用者',
                                      memberScore: (thirdPlace.data() as Map<String, dynamic>?)?['score'] as int? ?? 0,
                                      cardBackgroundColor: Colors.green.shade50,
                                      rankNumberColor: Colors.green.shade200,
                                      cardHeight: 120,
                                      avatarRadius: 25,
                                      fontSizeName: 14,
                                      fontSizeScore: 12,
                                      bottomPadding: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              '所有成員排名',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 10),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: memberDocs.length,
                            itemBuilder: (context, index) {
                              final memberData = memberDocs[index].data() as Map<String, dynamic>?;
                              final memberName = memberData?['name'] as String? ?? '未知使用者';
                              final memberScore = memberData?['score'] as int? ?? 0;
                              final rank = index + 1;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: Container(
                                    width: 30,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$rank',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent.shade400,
                                      ),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.blueGrey.shade100,
                                        child: Icon(Icons.person, size: 20, color: Colors.blueGrey.shade700),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          memberName,
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Text(
                                    '${memberScore} XP',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}