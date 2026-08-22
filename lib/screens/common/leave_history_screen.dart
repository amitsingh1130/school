import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';

class LeaveHistoryScreen extends StatelessWidget {
  final UserModel user;
  final bool isTab;
  const LeaveHistoryScreen({super.key, required this.user, this.isTab = false});

  @override
  Widget build(BuildContext context) {
    Widget body = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaves')
          .where('userId', isEqualTo: user.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No leave history found."));

        var docs = snapshot.data!.docs;
        
        // Manual sort (Latest first)
        docs.sort((a, b) {
          var ta = a['appliedAt'] as Timestamp?;
          var tb = b['appliedAt'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String status = (data['status'] ?? 'pending').toString().toUpperCase();
            String type = data['leaveType'] ?? 'Full Day';
            String dateRange = "${data['startDate']} to ${data['endDate']}";
            if (type == 'Half Day') dateRange = "${data['startDate']} (${data['halfDaySession']})";

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text(type, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Date: $dateRange"),
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(status).withOpacity(0.1),
                  child: Icon(Icons.history, color: _getStatusColor(status)),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getStatusColor(status)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Reason: ${data['reason'] ?? 'N/A'}", style: const TextStyle(fontSize: 14)),
                        if (data['adminRemark'] != null && data['adminRemark'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Admin/Teacher Remark:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                                  const SizedBox(height: 4),
                                  Text("${data['adminRemark']}", style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );

    if (isTab) return body;

    return Scaffold(
      appBar: AppBar(title: const Text("My Leave History")),
      body: body,
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'APPROVED') return Colors.green;
    if (status == 'REJECTED') return Colors.red;
    return Colors.orange;
  }
}
