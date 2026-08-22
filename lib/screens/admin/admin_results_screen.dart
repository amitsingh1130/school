import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../student/result_screen.dart';

class AdminResultsClassListScreen extends StatelessWidget {
  const AdminResultsClassListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Results")),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch from 'users' collection with role 'student' for consistent ID mapping
        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          Set<String> classes = {};
          for (var doc in snapshot.data!.docs) {
            classes.add(doc['classId'] ?? 'Unassigned');
          }
          List<String> sortedClasses = classes.toList()..sort();

          if (sortedClasses.isEmpty) return const Center(child: Text("No classes found."));

          return ListView.builder(
            itemCount: sortedClasses.length,
            itemBuilder: (context, index) {
              String cls = sortedClasses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder_shared, color: Colors.orange),
                  title: Text("Class $cls"),
                  subtitle: const Text("View student results"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStudentListForResultScreen(classId: cls)));
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

class AdminStudentListForResultScreen extends StatelessWidget {
  final String classId;
  const AdminStudentListForResultScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Results - Class $classId")),
      body: StreamBuilder<QuerySnapshot>(
        // Fetch from 'users' collection to get the login 'userId'
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('classId', isEqualTo: classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var students = snapshot.data!.docs;

          // SORT BY ROLL NUMBER
          students.sort((a, b) {
            int r1 = int.tryParse(a['rollNumber'].toString()) ?? 999;
            int r2 = int.tryParse(b['rollNumber'].toString()) ?? 999;
            return r1.compareTo(r2);
          });

          if (students.isEmpty) return const Center(child: Text("No students found in this class."));

          return ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              var s = students[index];
              var data = s.data() as Map<String, dynamic>;
              String userId = data['userId'] ?? s.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(child: Text(data['name']?[0] ?? 'S')),
                  title: Text(data['name'] ?? 'Unknown'),
                  subtitle: Text("Roll No: ${data['rollNumber'] ?? 'N/A'}"),
                  trailing: const Icon(Icons.assessment, color: Colors.blue),
                  onTap: () {
                    // Pass the login userId to match EnterMarksScreen logic
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentResultScreen(studentId: userId)));
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
