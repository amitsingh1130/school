import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/pref_service.dart';
import '../../models/user_model.dart';
import 'edit_student_screen.dart';
import 'package:intl/intl.dart';

class StudentDetailsScreen extends StatelessWidget {
  final String studentDocId;
  final Map<String, dynamic> studentData; // Initial data

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
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final currentUser = userSnapshot.data;
        // Edit/Delete access: Only Admin, Principal and Vice Principal
        final bool canEditOrManage = currentUser?.role == 'admin' || currentUser?.role == 'principal' || currentUser?.role == 'vice_principal';
        // View access for Credentials: Now visible to Teachers as well
        final bool canSeeCredentials = canEditOrManage || currentUser?.role == 'teacher';

        // --- STEP 1: Listen to Student Record in Real-time ---
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('students').doc(studentDocId).snapshots(),
          builder: (context, studentSnapshot) {
            if (!studentSnapshot.hasData || !studentSnapshot.data!.exists) {
              return const Scaffold(body: Center(child: Text("Student not found.")));
            }

            var freshStudentData = studentSnapshot.data!.data() as Map<String, dynamic>;
            String currentUserId = (freshStudentData['userId'] ?? '').toString().trim();

            return Scaffold(
              appBar: AppBar(
                title: Text(freshStudentData['name'] ?? "Student Details"),
                actions: [
                  if (canEditOrManage)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditStudentScreen(
                              docId: studentDocId,
                              currentData: freshStudentData,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
              body: SingleChildScrollView(
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
                    
                    // --- STEP 2: Listen to User Credentials in Real-time (Restricted) ---
                    if (canSeeCredentials)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('userId', isEqualTo: currentUserId)
                            .limit(1)
                            .snapshots(),
                        builder: (context, userCredSnap) {
                          String password = 'Loading...';
                          if (userCredSnap.hasData && userCredSnap.data!.docs.isNotEmpty) {
                            var userData = userCredSnap.data!.docs.first.data() as Map<String, dynamic>;
                            password = userData['password'] ?? 'N/A';
                          } else if (userCredSnap.connectionState != ConnectionState.waiting) {
                            password = "Not Linked (Tap Edit)";
                          }

                          return Container(
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
                                _credentialRow("User ID:", currentUserId),
                                _credentialRow("Password:", password),
                              ],
                            ),
                          );
                        },
                      ),
                    if (canSeeCredentials) const SizedBox(height: 20),

                    _detailTile("Admission ID", freshStudentData['admissionId']),
                    _detailTile("Admission Date & Time", _formatTimestamp(freshStudentData['admissionDate'])),
                    _detailTile("Full Name", freshStudentData['name']),
                    _detailTile("Gender", freshStudentData['gender']),
                    _detailTile("Roll Number", freshStudentData['rollNumber']),
                    _detailTile("Class", freshStudentData['classId']),
                    _detailTile("Father's Name", freshStudentData['fatherName']),
                    _detailTile("Mother's Name", freshStudentData['motherName']),
                    _detailTile("Date of Birth", freshStudentData['dob']),
                    _detailTile("Mobile Number", freshStudentData['mobile']),
                    _detailTile("Aadhaar Number", freshStudentData['aadhaar']),
                    _detailTile("Address", freshStudentData['address']),
                    _detailTile("Registration No.", freshStudentData['regNo']),
                    _detailTile("Birth Certificate No.", freshStudentData['birthCertNo']),
                    const SizedBox(height: 30),
                    
                    if (canEditOrManage)
                      ElevatedButton.icon(
                        onPressed: () => _confirmDelete(context, currentUserId),
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Student"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFF9C4), foregroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
            );
          },
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      return DateFormat('dd-MM-yyyy | hh:mm a').format(timestamp.toDate());
    }
    return timestamp.toString();
  }

  void _confirmDelete(BuildContext context, String currentUserId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Student?"),
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () async {
            // 1. Delete from students collection
            await FirebaseFirestore.instance.collection('students').doc(studentDocId).delete();
            
            // 2. Delete from users collection (Login Account)
            if (currentUserId.isNotEmpty) {
              var userQuery = await FirebaseFirestore.instance
                  .collection('users')
                  .where('userId', isEqualTo: currentUserId)
                  .get();
              for (var doc in userQuery.docs) {
                await doc.reference.delete();
              }
            }

            if (context.mounted) {
              Navigator.pop(ctx); 
              Navigator.pop(context);
            }
          }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
