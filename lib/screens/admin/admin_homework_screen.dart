import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import 'package:intl/intl.dart';

class AdminHomeworkClassListScreen extends StatelessWidget {
  const AdminHomeworkClassListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("View Class Homework"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Extract unique class names
          Set<String> classes = {};
          for (var doc in snapshot.data!.docs) {
            classes.add(doc['classId'] ?? 'Unassigned');
          }
          List<String> sortedClasses = classes.toList()..sort();

          if (sortedClasses.isEmpty) {
            return const Center(child: Text("No classes found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: sortedClasses.length,
            itemBuilder: (context, index) {
              String className = sortedClasses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_shared, color: Colors.orange),
                  title: Text("Class $className"),
                  subtitle: const Text("View homework history"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminHomeworkHistoryScreen(classId: className),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminHomeworkHistoryScreen extends StatelessWidget {
  final String classId;
  const AdminHomeworkHistoryScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: Text("Homework: Class $classId")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('homework')
            .where('classId', isEqualTo: classId)
            .where('academicSession', isEqualTo: session)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No homework found for this session."));
          }

          // Sort by date manually
          docs.sort((a, b) {
            var ta = a['createdAt'] as Timestamp?;
            var tb = b['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String teacherName = data['teacherName'] ?? 'Unknown Teacher';
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(data['subject'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['description']),
                      const SizedBox(height: 5),
                      Text("By: $teacherName", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey)),
                      Text(
                        data['createdAt'] != null 
                            ? DateFormat('dd MMM yyyy | hh:mm a').format((data['createdAt'] as Timestamp).toDate())
                            : '',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
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
