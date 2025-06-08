import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Used for Clipboard

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

  // --- 時間處理輔助函數 ---
  /// 將 "HH:mm:ss" 格式的字串轉換為總秒數
  int _durationToSeconds(String durationString) {
    try {
      final parts = durationString.split(':');
      if (parts.length == 3) {
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return hours * 3600 + minutes * 60 + seconds;
      }
    } catch (e) {
      print('Error parsing duration string: $durationString, Error: $e');
    }
    return 0; // 解析失敗或格式不符則返回 0
  }

  /// 將總秒數轉換為易讀的 "HH小時 MM分鐘 SS秒" 格式
  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 0) return '0秒';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}小時 ${minutes}分 ${seconds}秒';
    } else if (minutes > 0) {
      return '${minutes}分 ${seconds}秒';
    } else {
      return '${seconds}秒';
    }
  }
  // --- 時間處理輔助函數結束 ---


  // --- Delete Team Function (only callable by creator) ---
  Future<void> _confirmAndDeleteTeam(DocumentSnapshot teamDoc) async {
    final teamData = teamDoc.data() as Map<String, dynamic>?;
    if (teamData == null) return;

    final creatorId = teamData['creatorId'] as String?;
    final teamName = teamData['teamName'] as String? ?? 'Unnamed Team';
    final List<dynamic> memberIds = teamData['memberIds'] ?? [];

    if (_currentUserId == null || _currentUserId != creatorId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the team creator can delete this team.')),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Team', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete the team "$teamName"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Delete'),
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
        // Navigate back to the previous page (TeamPage) after successful deletion
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team "$teamName" successfully deleted!', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete team: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        print('Error deleting team: $e');
      }
    }
  }

  // --- Leave Team Function (callable by members) ---
  Future<void> _confirmAndLeaveTeam() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    final String currentUserId = currentUser.uid;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave Team', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to leave the team "${widget.teamName}"?'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, // Use orange for warning or leaving
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Leave'),
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

        // Remove current user's ID from 'teams' collection
        batch.update(_firestore.collection('teams').doc(widget.teamId), {
          'memberIds': FieldValue.arrayRemove([currentUserId]),
        });

        // Remove the team ID from 'users' collection for the current user
        batch.update(_firestore.collection('users').doc(currentUserId), {
          'joinedTeamIds': FieldValue.arrayRemove([widget.teamId]),
        });

        await batch.commit();

        if (!mounted) return;
        // Pop to the previous page (usually the team list page) after successful leave
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have successfully left the team "${widget.teamName}".', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave team: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        print('Error leaving team: $e');
      }
    }
  }

  /// 修改 _getMembersData 函數以獲取成員姓名和總運動時間
  Future<List<Map<String, dynamic>>> _getMembersData(List<dynamic> memberIds) async {
    if (memberIds.isEmpty) {
      return [];
    }

    List<Map<String, dynamic>> membersData = [];
    // 遍歷所有成員ID，為每個成員獲取其名稱和總運動時間
    for (String memberId in memberIds.cast<String>()) {
      String userName = 'Unknown User (ID: $memberId)'; // 預設名稱，包含 ID 以便調試
      int totalDurationSeconds = 0;

      try {
        final userDoc = await _firestore.collection('users').doc(memberId).get();

        if (userDoc.exists && userDoc.data() != null) {
          // 如果使用者文件存在且數據不為空
          userName = userDoc.data()!['name'] as String? ?? 'Unnamed User'; // 獲取真實名稱或預設 'Unnamed User'

          // 嘗試獲取該成員的 'records' 子集合中的所有運動記錄
          final recordsSnapshot = await _firestore.collection('users').doc(memberId).collection('records').get();
          for (var recordDoc in recordsSnapshot.docs) {
            final recordData = recordDoc.data();
            final durationString = recordData['duration'] as String? ?? '00:00:00';
            totalDurationSeconds += _durationToSeconds(durationString);
          }
        } else {
          // 如果 userDoc 不存在或 userDoc.data() 為 null
          userName = 'Invalid User (ID: $memberId)'; // 更明確的提示
          print('Warning: User document for ID $memberId does not exist or is empty.');
        }

        membersData.add({
          'id': memberId,
          'name': userName,
          'totalExerciseSeconds': totalDurationSeconds,
        });

      } catch (e) {
        // 如果在獲取任何數據時發生錯誤（例如網路問題、權限問題）
        print('Error fetching data for member $memberId: $e');
        membersData.add({
          'id': memberId,
          'name': 'Error loading name (ID: $memberId)',
          'totalExerciseSeconds': 0, // 運動時間仍為 0
        });
      }
    }
    return membersData;
  }


  // Helper method to build a single top 3 member card
  Widget _buildTop3MemberCard({
    required int rank,
    required String memberName,
    required int memberDurationSeconds,
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
                    // TODO: If user photo URL is available, load it here
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
                  // 顯示格式化後的運動時間
                  Text(
                    _formatDuration(memberDurationSeconds),
                    style: TextStyle(
                      fontSize: fontSizeScore,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade600,
                    ),
                    textAlign: TextAlign.center, // 居中顯示
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
  Widget build(BuildContext context) {
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
              final List<dynamic> memberIds = teamData?['memberIds'] ?? []; // Get member list

              // If the current user is the creator
              if (_currentUserId != null && _currentUserId == creatorId) {
                return IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 26),
                  tooltip: 'Delete Team',
                  onPressed: () => _confirmAndDeleteTeam(teamSnapshot.data!),
                );
              }
              // If the current user is not the creator, but is a team member
              else if (_currentUserId != null && memberIds.contains(_currentUserId)) {
                return IconButton(
                  icon: const Icon(Icons.exit_to_app, color: Colors.orange, size: 26), // Exit icon
                  tooltip: 'Leave Team',
                  onPressed: _confirmAndLeaveTeam,
                );
              }
              return const SizedBox.shrink(); // Hide button in other cases (e.g., not logged in or not a member)
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
                              'Team Invite Code',
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
                          tooltip: 'Copy Invite Code',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invite code copied!', style: TextStyle(color: Colors.white)),
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
                  'Team Overview',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                SizedBox(height: 5),
                Text(
                  'Current Active Member Exercise Duration',
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
                  return Center(child: Text('Error loading team data: ${teamSnapshot.error}'));
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
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey),
                        SizedBox(height: 20),
                        Text(
                          'This team currently has no members.\nShare the invite code to invite teammates!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>( // 改變 FutureBuilder 的類型
                  future: _getMembersData(memberIds), // 呼叫新的數據獲取方法
                  builder: (context, membersSnapshot) {
                    if (membersSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (membersSnapshot.hasError) {
                      return Center(child: Text('Error loading member data: ${membersSnapshot.error}'));
                    }
                    if (!membersSnapshot.hasData || membersSnapshot.data!.isEmpty) {
                      return const Center(child: Text('No member details found.'));
                    }

                    final List<Map<String, dynamic>> memberDetails = membersSnapshot.data!;
                    // 根據總運動時間排序，從高到低
                    memberDetails.sort((a, b) {
                      final durationA = a['totalExerciseSeconds'] as int? ?? 0;
                      final durationB = b['totalExerciseSeconds'] as int? ?? 0;
                      return durationB.compareTo(durationA);
                    });

                    final Map<String, dynamic>? firstPlace = memberDetails.isNotEmpty ? memberDetails[0] : null;
                    final Map<String, dynamic>? secondPlace = memberDetails.length > 1 ? memberDetails[1] : null;
                    final Map<String, dynamic>? thirdPlace = memberDetails.length > 2 ? memberDetails[2] : null;

                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Top 3 Display Area ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: SizedBox(
                              height: 220,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Second Place (Left) - Display only if there's a second place
                                  if (secondPlace != null)
                                    _buildTop3MemberCard(
                                      rank: 2,
                                      memberName: secondPlace['name'] as String,
                                      memberDurationSeconds: secondPlace['totalExerciseSeconds'] as int? ?? 0, // 傳遞時間
                                      cardBackgroundColor: Colors.blue.shade50,
                                      rankNumberColor: Colors.blue.shade200,
                                      cardHeight: 150,
                                      avatarRadius: 28,
                                      fontSizeName: 15,
                                      fontSizeScore: 13,
                                      bottomPadding: 15,
                                    ),
                                  // First Place (Middle) - Display if there's any member
                                  if (firstPlace != null)
                                    _buildTop3MemberCard(
                                      rank: 1,
                                      memberName: firstPlace['name'] as String,
                                      memberDurationSeconds: firstPlace['totalExerciseSeconds'] as int? ?? 0, // 傳遞時間
                                      cardBackgroundColor: Colors.amber.shade50,
                                      rankNumberColor: Colors.amber.shade200,
                                      cardHeight: 180,
                                      avatarRadius: 32,
                                      fontSizeName: 16,
                                      fontSizeScore: 14,
                                      bottomPadding: 10,
                                    ),
                                  // Third Place (Right) - Display only if there's a third place
                                  if (thirdPlace != null)
                                    _buildTop3MemberCard(
                                      rank: 3,
                                      memberName: thirdPlace['name'] as String, // 確保名稱存在
                                      memberDurationSeconds: thirdPlace['totalExerciseSeconds'] as int? ?? 0, // 傳遞時間
                                      cardBackgroundColor: Colors.green.shade50,
                                      rankNumberColor: Colors.green.shade200,
                                      cardHeight: 130,
                                      avatarRadius: 25,
                                      fontSizeName: 14,
                                      fontSizeScore: 12,
                                      bottomPadding: 10,
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'All Member Ranking',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 10),

                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: memberDetails.length, // 使用新的 memberDetails
                            itemBuilder: (context, index) {
                              final member = memberDetails[index];
                              final memberName = member['name'] as String; // 確保名稱存在
                              final memberTotalDuration = member['totalExerciseSeconds'] as int? ?? 0; // 獲取總運動時間
                              final rank = index + 1;

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                  leading: Container(
                                    width: 30,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$rank',
                                      style: TextStyle(
                                        fontSize: 30, // 榜單字體放大
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
                                    _formatDuration(memberTotalDuration), // 顯示格式化後的總運動時間
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
