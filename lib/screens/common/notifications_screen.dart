import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';
import '../admin/manage_leaves_screen.dart';
import '../student/fee_history_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final UserModel user;
  final Function(int)? onSwitchTab;

  const NotificationsScreen({super.key, required this.user, this.onSwitchTab});

  // Function to delete a single notification
  void _deleteNotification(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(docId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notification removed"), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: $e")),
        );
      }
    }
  }

  // Function to clear all relevant notifications for this user
  void _clearAll(List<DocumentSnapshot> visibleNotes, BuildContext context) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All?"),
        content: const Text("Do you want to remove all visible notifications?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Clear All")),
        ],
      ),
    );

    if (confirm == true) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in visibleNotes) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('notifications').snapshots(),
      builder: (context, snapshot) {
        List<DocumentSnapshot> filteredNotes = [];
        if (snapshot.hasData) {
          filteredNotes = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            
            // 1. Direct target check
            if (data['toUserId'] == user.userId) return true;
            
            // 2. Class-specific check (If class is specified, must match)
            if (data['toClassId'] != null) {
              return data['toClassId'] == user.classId && data['toRole'] == user.role;
            }
            
            // 3. Role-wide check (only if no specific user or class is targetted)
            return data['toRole'] == user.role && data['toUserId'] == null;
          }).toList();

          // Sort Latest First
          filteredNotes.sort((a, b) {
            var ta = a.get('createdAt') as Timestamp?;
            var tb = b.get('createdAt') as Timestamp?;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return tb.compareTo(ta);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text("System Notifications"),
            actions: [
              if (filteredNotes.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: "Clear All",
                  onPressed: () => _clearAll(filteredNotes, context),
                )
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : filteredNotes.isEmpty
                  ? const Center(child: Text("No notifications yet."))
                  : ListView.builder(
                      itemCount: filteredNotes.length,
                      itemBuilder: (context, index) {
                        var doc = filteredNotes[index];
                        var data = doc.data() as Map<String, dynamic>;
                        bool isLeave = data['type'] == 'leave';
                        bool isFee = data['type'] == 'fee';
                        bool isHomework = data['type'] == 'homework';

                        return Dismissible(
                          key: Key(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) => _deleteNotification(context, doc.id),
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            color: isFee ? Colors.green.shade50 : (isHomework ? Colors.blue.shade50 : Colors.white),
                            child: ListTile(
                              onTap: () {
                                if (user.role == 'student') {
                                  if (isHomework && onSwitchTab != null) {
                                    onSwitchTab!(1);
                                  } else if (isFee) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => FeeHistoryScreen(studentId: user.userId)));
                                  }
                                } else if (user.role == 'teacher') {
                                  if (isLeave) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLeavesScreen(viewRole: 'student', classId: user.classId)));
                                  }
                                } else if (user.role == 'admin') {
                                  if (isLeave) {
                                    String msg = (data['message'] ?? '').toString().toLowerCase();
                                    String targetRole = msg.contains('student') ? 'student' : 'teacher';
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLeavesScreen(viewRole: targetRole)));
                                  } else if (isFee) {
                                    if (onSwitchTab != null) onSwitchTab!(1);
                                  }
                                }
                              },
                              leading: Icon(
                                isLeave ? Icons.exit_to_app : (isFee ? Icons.money : (isHomework ? Icons.book : Icons.notifications)),
                                color: Colors.black,
                              ),
                              title: Text(data['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['message'] ?? ''),
                                  const SizedBox(height: 5),
                                  Text(
                                    data['createdAt'] != null 
                                        ? DateFormat('dd MMM, hh:mm a').format((data['createdAt'] as Timestamp).toDate())
                                        : '',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                onPressed: () => _deleteNotification(context, doc.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }
}
