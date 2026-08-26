import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/pref_service.dart';
import '../../models/user_model.dart';
import 'add_student_screen.dart';
import 'student_details_screen.dart';
import 'edit_student_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Management"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => searchQuery = value.toLowerCase().trim()),
              decoration: InputDecoration(
                hintText: "Search by Name or Class (e.g. Rahul 9)",
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var allStudents = snapshot.data!.docs;
          
          // --- LOGIC 1: If Search is active, show flat list of students ---
          if (searchQuery.isNotEmpty) {
            var filtered = allStudents.where((doc) {
              String name = doc['name'].toString().toLowerCase();
              String cls = doc['classId'].toString().toLowerCase();
              return name.contains(searchQuery) || cls.contains(searchQuery) || "$name $cls".contains(searchQuery);
            }).toList();

            // SORT BY ROLL NUMBER
            filtered.sort((a, b) {
              int r1 = int.tryParse(a['rollNumber'].toString()) ?? 999;
              int r2 = int.tryParse(b['rollNumber'].toString()) ?? 999;
              return r1.compareTo(r2);
            });

            if (filtered.isEmpty) return const Center(child: Text("No students found"));

            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                var doc = filtered[index];
                var data = doc.data() as Map<String, dynamic>;
                return _studentTile(doc.id, data);
              },
            );
          }

          // --- LOGIC 2: If no search, show class folders ---
          Map<String, List<DocumentSnapshot>> groups = {};
          for (var doc in allStudents) {
            String cls = doc['classId'] ?? 'Unassigned';
            groups.putIfAbsent(cls, () => []);
            groups[cls]!.add(doc);
          }
          var sortedClasses = groups.keys.toList()..sort();

          return ListView.builder(
            itemCount: sortedClasses.length,
            itemBuilder: (context, index) {
              String cls = sortedClasses[index];
              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  leading: const Icon(Icons.folder, color: Colors.orange),
                  title: Text("Class $cls"),
                  subtitle: Text("${groups[cls]!.length} Students"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentListByClassScreen(classId: cls)));
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<UserModel?>(
        future: PrefService().getUser(),
        builder: (context, userSnapshot) {
          final currentUser = userSnapshot.data;
          final bool canAddStudent = currentUser?.role == 'admin' || currentUser?.role == 'principal' || currentUser?.role == 'vice_principal';

          if (!canAddStudent) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddStudentScreen()));
            },
            label: const Text("Add Student"),
            icon: const Icon(Icons.person_add),
          );
        },
      ),
    );
  }

  Widget _studentTile(String docId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(data['name'][0])),
        title: Text(data['name']),
        subtitle: Text("Roll: ${data['rollNumber']} | Class: ${data['classId']}"),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailsScreen(studentDocId: docId, studentData: data)));
        },
      ),
    );
  }
}

class StudentListByClassScreen extends StatelessWidget {
  final String classId;
  const StudentListByClassScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: PrefService().getUser(),
      builder: (context, userSnapshot) {
        final bool isAdmin = userSnapshot.hasData && userSnapshot.data!.role == 'admin';

        return Scaffold(
          appBar: AppBar(title: Text("Students - Class $classId")),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('students').where('classId', isEqualTo: classId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var students = snapshot.data!.docs;

              // SORT BY ROLL NUMBER
              students.sort((a, b) {
                int r1 = int.tryParse(a['rollNumber'].toString()) ?? 999;
                int r2 = int.tryParse(b['rollNumber'].toString()) ?? 999;
                return r1.compareTo(r2);
              });

              return ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  var doc = students[index];
                  var data = doc.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(child: Text(data['name'][0])),
                      title: Text(data['name']),
                      subtitle: Text("Roll: ${data['rollNumber']}"),
                      trailing: const Icon(Icons.chevron_right, size: 16),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => StudentDetailsScreen(studentDocId: doc.id, studentData: data)));
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      }
    );
  }
}
