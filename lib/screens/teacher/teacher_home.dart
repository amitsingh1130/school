import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'mark_attendance_screen.dart';
import 'upload_homework_screen.dart';
import 'self_attendance_screen.dart';
import 'student_attendance_management.dart';
import 'homework_management_screen.dart';
import 'view_timetable_screen.dart';
import 'enter_marks_screen.dart';
import '../common/leave_management_screen.dart';
import '../admin/manage_leaves_screen.dart';
import '../admin/student_management_screen.dart';

class TeacherHomeScreen extends StatelessWidget {
  final UserModel user;

  const TeacherHomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- CLEAR CLASS HEAD INFO ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(builder: (context) {
                    String honorific = "";
                    if (user.gender == "Male") honorific = " Sir";
                    if (user.gender == "Female") honorific = " Ma'am";
                    String firstName = user.name.split(" ").first;
                    return Text("Welcome, $firstName$honorific", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black));
                  }),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.stars, color: Colors.orange, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            user.classId != null 
                                ? "Class Teacher of: ${user.classId}" 
                                : "No Class Assigned Yet",
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                      if (user.classId != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('students')
                              .where('classId', isEqualTo: user.classId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.people_outline, size: 14, color: Colors.black54),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Total Stud: $count",
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4, // Compact tiles
              children: [
                _teacherAction(Icons.people, "My Students", Colors.blue, () {
                  if (user.classId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentListByClassScreen(classId: user.classId!)));
                  }
                }),
                _teacherAction(Icons.fingerprint, "My Attendance", Colors.deepOrange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherSelfAttendanceManagement(teacherId: user.userId)));
                }),
                _teacherAction(Icons.checklist, "Class Attendance", Colors.green, () {
                  if (user.classId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => StudentAttendanceManagement(classId: user.classId!)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You are not assigned to any class yet.")));
                  }
                }),
                _teacherAction(Icons.upload_file, "Homework", Colors.indigo, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => HomeworkManagementScreen(user: user)));
                }),
                _teacherAction(Icons.grade, "Marks", Colors.purple, () {
                  if (user.classId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EnterMarksScreen(classId: user.classId!)));
                  }
                }),
                _teacherAction(Icons.calendar_month, "Timetable", Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ViewTimetableScreen(teacherId: user.userId)));
                }),
                _teacherAction(Icons.exit_to_app, "My Leaves", Colors.redAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveManagementScreen(user: user)));
                }),
                _teacherAction(Icons.people_outline, "Stud. Leaves", Colors.blueGrey, () {
                  if (user.classId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLeavesScreen(viewRole: 'student', classId: user.classId!)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No class assigned to you.")));
                  }
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _teacherAction(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
