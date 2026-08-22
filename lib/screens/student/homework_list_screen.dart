import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class HomeworkListScreen extends StatelessWidget {
  final String classId;
  const HomeworkListScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: Text("My Homework ($session)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('homework')
            .where('classId', isEqualTo: classId)
            .where('academicSession', isEqualTo: session)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
             return const Center(child: Text("No homework found for this session."));
          }
          
          var homeworks = snapshot.data!.docs;

          // Manual sort (Latest First)
          homeworks.sort((a, b) {
            var ta = a['createdAt'] as Timestamp?;
            var tb = b['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          return ListView.builder(
            itemCount: homeworks.length,
            itemBuilder: (context, index) {
              var data = homeworks[index].data() as Map<String, dynamic>;
              String teacherName = data['teacherName'] ?? 'Subject Teacher';
              DateTime? dt = (data['createdAt'] as Timestamp?)?.toDate();
              String timeStr = dt != null ? DateFormat('dd MMM yyyy | hh:mm a').format(dt) : '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF9C4), child: Icon(Icons.book, color: Colors.blue)),
                  title: Text(data['subject'] ?? 'Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description'] ?? ''),
                      const SizedBox(height: 8),
                      Text("By: $teacherName", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
                      Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
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
