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
import 'homework_list_screen.dart'; // Import added
import 'package:intl/intl.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Dashboard")),
      body: FutureBuilder<UserModel?>(
        future: PrefService().getUser(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final user = snapshot.data!;
          final session = Provider.of<SessionProvider>(context).currentSession;

          return SingleChildScrollView(
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FeeHistoryScreen(studentId: user.userId)));
                    }),
                    _actionItem(context, Icons.exit_to_app, "My Leaves", Colors.red, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveManagementScreen(user: user)));
                    }),
                    _actionItem(context, Icons.book, "Homework", Colors.blue, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => HomeworkListScreen(classId: user.classId ?? '')));
                    }),
                  ],
                ),
                const SizedBox(height: 25),

                const Text("Latest Homework", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('homework')
                      .where('classId', isEqualTo: user.classId)
                      .where('academicSession', isEqualTo: session)
                      .snapshots(),
                  builder: (context, hwSnap) {
                    if (hwSnap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    if (!hwSnap.hasData || hwSnap.data!.docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: Text("No homework for this session", style: TextStyle(color: Colors.grey))),
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
                      itemCount: docs.length > 3 ? 3 : docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        String teacherName = data['teacherName'] ?? 'Teacher';
                        DateTime? dt = (data['createdAt'] as Timestamp?)?.toDate();
                        String timeStr = dt != null ? DateFormat('dd MMM | hh:mm a').format(dt) : '';

                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.book, color: Colors.blue),
                            title: Text(data['subject'] ?? 'No Subject'),
                            subtitle: Text("By: $teacherName | $timeStr", style: const TextStyle(fontSize: 11)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HomeworkListScreen(classId: user.classId ?? ''),
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
          );
        },
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
