import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherSelfHistoryScreen extends StatelessWidget {
  final String teacherId;
  const TeacherSelfHistoryScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Attendance History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teacher_attendance')
            .where('teacherId', isEqualTo: teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("No records found."));

          // Sort in memory
          docs.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String rawStatus = data['status'] ?? 'Absent';
              String status = rawStatus.toUpperCase();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.check_circle, 
                    color: status == 'PRESENT' ? Colors.green : Colors.red
                  ),
                  title: Text(data['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                    status,
                    style: TextStyle(
                      color: status == 'PRESENT' ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
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
