import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentNotificationsScreen extends StatelessWidget {
  final String studentId;
  const StudentNotificationsScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Notifications"),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: studentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No new notifications."));
          }

          var alerts = snapshot.data!.docs;

          // Sort in memory
          alerts.sort((a, b) {
            var ta = a['createdAt'] as Timestamp?;
            var tb = b['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              var data = alerts[index].data() as Map<String, dynamic>;
              bool isFee = data['type'] == 'fee';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: isFee ? Colors.green.shade50 : Colors.white,
                child: ListTile(
                  leading: Icon(
                    isFee ? Icons.receipt_long : Icons.notifications,
                    color: isFee ? Colors.green : Colors.red,
                  ),
                  title: Text(data['title'] ?? 'Notification',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['message'] ?? ''),
                  trailing: Text(
                    data['createdAt'] != null 
                        ? (data['createdAt'] as Timestamp).toDate().toString().substring(0, 10)
                        : '',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
