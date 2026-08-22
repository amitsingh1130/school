import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/pref_service.dart';
import '../../models/user_model.dart';
import 'edit_student_screen.dart';
import 'package:intl/intl.dart';

class StudentDetailsScreen extends StatelessWidget {
  final String studentDocId;
  final Map<String, dynamic> studentData;

  const StudentDetailsScreen({
    super.key,
    required this.studentDocId,
    required this.studentData,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: PrefService().getUser(),
      builder: (context, userSnapshot) {
        final bool isAdmin = userSnapshot.hasData && userSnapshot.data!.role == 'admin';

        return Scaffold(
          appBar: AppBar(
            title: Text(studentData['name'] ?? "Student Details"),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditStudentScreen(
                          docId: studentDocId,
                          currentData: studentData,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: studentData['userId'] != null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .where('userId', isEqualTo: studentData['userId'])
                    .limit(1)
                    .snapshots()
                : FirebaseFirestore.instance
                    .collection('users')
                    .where('rollNumber', isEqualTo: studentData['rollNumber'])
                    .where('classId', isEqualTo: studentData['classId'])
                    .limit(1)
                    .snapshots(),
            builder: (context, snapshot) {
              String userId = studentData['userId'] ?? studentData['rollNumber'] ?? 'N/A';
              String password = 'Loading...';

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                var userData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                userId = userData['userId'] ?? userId;
                password = userData['password'] ?? 'N/A';
              }

              // Format admission date
              String admissionDateStr = "N/A";
              if (studentData['admissionDate'] != null) {
                DateTime dt = (studentData['admissionDate'] as Timestamp).toDate();
                admissionDateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFFFF9C4),
                        child: Icon(Icons.person, size: 50, color: Color(0xFFFFD700)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                // --- LOGIN CREDENTIALS SECTION ---
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.vpn_key, size: 18, color: Colors.blue),
                          SizedBox(width: 10),
                          Text("Official Login Credentials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        ],
                      ),
                      const Divider(),
                      _credentialRow("User ID:", userId),
                      _credentialRow("Password:", password),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                    _detailTile("Admission ID", studentData['admissionId']),
                    _detailTile("Admission Date & Time", admissionDateStr),
                    _detailTile("Full Name", studentData['name']),
                    _detailTile("Gender", studentData['gender']), // NEW
                    _detailTile("Roll Number", studentData['rollNumber']),
                    _detailTile("Class", studentData['classId']),
                    _detailTile("Father's Name", studentData['fatherName']),
                    _detailTile("Mother's Name", studentData['motherName']),
                    _detailTile("Date of Birth", studentData['dob']),
                    _detailTile("Mobile Number", studentData['mobile']),
                    _detailTile("Aadhaar Number", studentData['aadhaar']),
                    _detailTile("Address", studentData['address']), // NEW
                    _detailTile("Birth Certificate No.", studentData['birthCertNo']),
                    _detailTile("Registration No.", studentData['regNo']),
                    const SizedBox(height: 30),
                    
                    if (isAdmin)
                      ElevatedButton.icon(
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Student"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFF9C4),
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
              );
            }
          ),
        );
      }
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
        subtitle: Text(value?.toString() ?? "N/A", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Student?"),
        content: const Text("Are you sure you want to remove this student record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('students').doc(studentDocId).delete();
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
