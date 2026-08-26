import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';
import '../common/leave_management_screen.dart';
import 'attendance_history_screen.dart';
import 'result_screen.dart';
import 'fee_history_screen.dart';
import 'homework_list_screen.dart';
import 'homework_detail_screen.dart'; // Import added
import 'package:intl/intl.dart';

class StudentHomeScreen extends StatelessWidget {
  final UserModel user;
  const StudentHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: const Text("Student Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hi, ${user.name}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("Class: ${user.classId ?? 'N/A'} | Roll: ${user.rollNumber ?? 'N/A'}", style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
                const SizedBox(height: 25),
                
                const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    _actionItem(context, Icons.calendar_month, "Attendance", Colors.orange, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceHistoryScreen(
                        rollNumber: user.rollNumber ?? '', 
                        classId: user.classId ?? ''
                      )));
                    }),
                    _actionItem(context, Icons.assessment, "Report Card", Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => StudentResultScreen(studentId: user.userId)));
                    }),
                    _actionItem(context, Icons.receipt_long, "Fees", Colors.green, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FeeHistoryScreen(user: user)));
                    }),
                    _actionItem(context, Icons.exit_to_app, "My Leaves", Colors.red, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveManagementScreen(user: user)));
                    }),
                  ],
                ),
                const SizedBox(height: 25),

                const Text("Today's Homework", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: () {
                    DateTime now = DateTime.now();
                    DateTime startOfToday = DateTime(now.year, now.month, now.day);
                    DateTime endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

                    return FirebaseFirestore.instance
                        .collection('homework')
                        .where('classId', isEqualTo: user.classId)
                        .where('academicSession', isEqualTo: session)
                        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
                        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfToday))
                        .snapshots();
                  }(),
                  builder: (context, hwSnap) {
                    if (hwSnap.hasError) {
                      debugPrint("Firestore Query Error: ${hwSnap.error}");
                      return const Center(
                        child: Text("Error loading homework. Please check Firestore Indices.", 
                        style: TextStyle(color: Colors.red, fontSize: 12)),
                      );
                    }
                    if (hwSnap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    if (!hwSnap.hasData || hwSnap.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.assignment_turned_in_outlined, color: Colors.grey, size: 40),
                              SizedBox(height: 10),
                              Text("No homework assigned for today.", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }
                    var docs = hwSnap.data!.docs;

                    // Manual sort (Latest First)
                    docs.sort((a, b) {
                      var ta = a['createdAt'] as Timestamp?;
                      var tb = b['createdAt'] as Timestamp?;
                      if (ta == null || tb == null) return 0;
                      return tb.compareTo(ta);
                    });

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        
                        // Format Teacher Name
                        String teacherName = data['teacherName'] ?? 'Teacher';
                        String? gender = data['teacherGender'];
                        if (gender != null) {
                          String honorific = (gender == "Male") ? " Sir" : (gender == "Female" ? " Ma'am" : "");
                          teacherName = "${teacherName.split(" ").first}$honorific";
                        }

                        DateTime? dt = (data['createdAt'] as Timestamp?)?.toDate();
                        String timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : '';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            leading: const Icon(Icons.book, color: Colors.blue),
                            title: Text(data['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("By: $teacherName | $timeStr", style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HomeworkDetailScreen(homeworkData: data),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _actionItem(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: color),
            const SizedBox(height: 5),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
