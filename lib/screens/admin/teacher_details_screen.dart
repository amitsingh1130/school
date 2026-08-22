import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_teacher_screen.dart';

class TeacherDetailsScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> teacherData;

  const TeacherDetailsScreen({super.key, required this.docId, required this.teacherData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(teacherData['name'] ?? "Teacher Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditTeacherScreen(
                    docId: docId,
                    currentData: teacherData,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(docId).snapshots(),
        builder: (context, snapshot) {
          String userId = teacherData['userId'] ?? 'N/A';
          String password = 'Loading...';

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            userId = data['userId'] ?? userId;
            password = data['password'] ?? 'N/A';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Center(child: CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50))),
                const SizedBox(height: 20),
                
                // --- LOGIN CREDENTIALS SECTION ---
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.lock_person, size: 18, color: Colors.purple),
                          SizedBox(width: 10),
                          Text("Teacher Login Credentials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                        ],
                      ),
                      const Divider(),
                      _credentialRow("User ID:", userId),
                      _credentialRow("Password:", password),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _detailTile("Full Name", teacherData['name']),
                _detailTile("Gender", teacherData['gender']), // NEW
                _detailTile("Subject", teacherData['subject']),
                _detailTile("Designation", teacherData['designation']),
                _detailTile("Class Teacher of", teacherData['classId']),
                _detailTile("Joining Date", teacherData['joiningDate']),
                _detailTile("Father's Name", teacherData['fatherName']),
                _detailTile("Mother's Name", teacherData['motherName']),
                _detailTile("Date of Birth", teacherData['dob']),
                _detailTile("Mobile Number", teacherData['mobile']),
                _detailTile("Aadhaar Number", teacherData['aadhaar']),
                _detailTile("Address", teacherData['address']), // NEW
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete Teacher Account"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDE7ED), foregroundColor: Colors.red),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _detailTile(String label, dynamic value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        subtitle: Text(value?.toString() ?? "N/A", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text("Are you sure you want to remove this teacher?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(docId).delete();
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
