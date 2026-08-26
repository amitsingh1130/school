import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';
import 'edit_teacher_screen.dart';

class TeacherDetailsScreen extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> teacherData;

  const TeacherDetailsScreen({super.key, required this.docId, required this.teacherData});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: PrefService().getUser(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final currentUser = userSnapshot.data;
        final bool canManage = currentUser?.role == 'admin' || currentUser?.role == 'principal' || currentUser?.role == 'vice_principal';

        // --- STEP 1: Listen to Staff Record in Real-time ---
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(docId).snapshots(),
          builder: (context, staffSnapshot) {
            if (!staffSnapshot.hasData || !staffSnapshot.data!.exists) {
              return const Scaffold(body: Center(child: Text("Staff record not found.")));
            }

            var freshStaffData = staffSnapshot.data!.data() as Map<String, dynamic>;
            String currentUserId = (freshStaffData['userId'] ?? docId).toString().trim();

            return Scaffold(
              appBar: AppBar(
                title: Text(freshStaffData['name'] ?? "Teacher Details"),
                actions: [
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditTeacherScreen(
                              docId: docId,
                              currentData: freshStaffData,
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
                    const Center(child: CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50))),
                    const SizedBox(height: 20),
                    
                    // --- STEP 2: Show Credentials (using fresh field data) ---
                    if (canManage)
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
                                Text("Staff Login Credentials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                              ],
                            ),
                            const Divider(),
                            _credentialRow("User ID:", currentUserId),
                            _credentialRow("Password:", freshStaffData['password'] ?? 'N/A'),
                          ],
                        ),
                      ),
                    if (canManage) const SizedBox(height: 20),

                    _detailTile("Full Name", freshStaffData['name']),
                    _detailTile("Gender", freshStaffData['gender']),
                    _detailTile("Designation", freshStaffData['designation']),
                    _detailTile("Class Teacher of", freshStaffData['classId']),
                    _detailTile("Subject", freshStaffData['subject']),
                    _detailTile("Mobile Number", freshStaffData['mobile']),
                    _detailTile("Father's Name", freshStaffData['fatherName']),
                    _detailTile("Mother's Name", freshStaffData['motherName']),
                    _detailTile("Date of Birth", freshStaffData['dob']),
                    _detailTile("Aadhaar Number", freshStaffData['aadhaar']),
                    _detailTile("Joining Date", freshStaffData['joiningDate']),
                    _detailTile("Address", freshStaffData['address']),
                    const SizedBox(height: 30),
                    
                    if (canManage)
                      ElevatedButton.icon(
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete),
                        label: const Text("Delete Teacher Account"),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFDE7ED), foregroundColor: Colors.red),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
        content: const Text("Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(docId).delete();
            Navigator.pop(ctx);
            Navigator.pop(context);
          }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
