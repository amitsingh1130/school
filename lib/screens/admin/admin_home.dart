import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import 'student_management_screen.dart';
import 'teacher_management_screen.dart';
import 'admin_attendance_screen.dart';
import 'fee_management_screen.dart';
import 'manage_timetable_screen.dart';
import 'manage_leaves_screen.dart';
import 'teacher_attendance_list_screen.dart';
import 'admin_homework_screen.dart';
import 'admin_results_screen.dart';
import 'manage_holidays_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final UserModel user;

  const AdminHomeScreen({super.key, required this.user});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Dashboard khulte hi background mein sync check karega
    DatabaseService().autoSyncExistingStudents();
  }

  @override
  Widget build(BuildContext context) {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text("Admin Dashboard")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Attendance Summary Row
            Row(
              children: [
                _buildLiveStat(
                  context,
                  "Stud. Attendance",
                  FirebaseFirestore.instance.collection('attendance').where('date', isEqualTo: today).snapshots(),
                  FirebaseFirestore.instance.collection('students').snapshots(), // Total Students
                  Colors.blue,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAttendanceClassListScreen())),
                  isStudent: true
                ),
                const SizedBox(width: 10),
                _buildLiveStat(
                  context,
                  "Teach. Attendance",
                  FirebaseFirestore.instance.collection('teacher_attendance').where('date', isEqualTo: today).snapshots(),
                  FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(), // Total Teachers
                  Colors.purple,
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherAttendanceHistoryScreen())),
                  isStudent: false
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5, 
              children: [
                _actionCard(context, Icons.person_add, "Students", Colors.orange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentManagementScreen()));
                }),
                _actionCard(context, Icons.group_add, "Teachers", Colors.indigo, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TeacherManagementScreen()));
                }),
                _actionCard(context, Icons.money, "Fees", Colors.green, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FeeManagementScreen()));
                }),
                _actionCard(context, Icons.calendar_month, "Timetable", Colors.deepOrange, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageTimetableScreen()));
                }),
                _actionCard(context, Icons.book, "Homework", Colors.brown, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHomeworkClassListScreen()));
                }),
                _actionCard(context, Icons.assessment, "Results", Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminResultsClassListScreen()));
                }),
                _actionCard(context, Icons.celebration, "Holidays", Colors.pink, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageHolidaysScreen()));
                }),
                // --- SEPARATE LEAVE CARDS WITH COUNTS ---
                _buildLeaveCard(context, "Teach. Leaves", 'teacher', Colors.red),
                _buildLeaveCard(context, "Stud. Leaves", 'student', Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStat(BuildContext context, String title, Stream<QuerySnapshot> presentStream, Stream<QuerySnapshot> totalStream, Color color, VoidCallback onTap, {required bool isStudent}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 5),
              StreamBuilder<QuerySnapshot>(
                stream: totalStream,
                builder: (context, totalSnapshot) {
                  int total = totalSnapshot.hasData ? totalSnapshot.data!.docs.length : 0;
                  return StreamBuilder<QuerySnapshot>(
                    stream: presentStream,
                    builder: (context, presentSnapshot) {
                      int present = 0;
                      if (presentSnapshot.hasData) {
                        if (isStudent) {
                          for (var doc in presentSnapshot.data!.docs) {
                            Map<String, dynamic> records = doc['records'] ?? {};
                            present += records.values.where((v) => 
                              v == 'PRESENT' || v == 'HALF DAY' || v == 'ON LEAVE' || v == 'P' || v == true
                            ).length;
                          }
                        } else {
                          present = presentSnapshot.data!.docs.length;
                        }
                      }
                      return Text("$present / $total", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color));
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveCard(BuildContext context, String title, String role, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leaves').where('role', isEqualTo: role).snapshots(),
      builder: (context, snapshot) {
        int pendingCount = 0;
        if (snapshot.hasData) {
          pendingCount = snapshot.data!.docs.where((doc) {
            String s = (doc['status'] ?? 'pending').toString().toLowerCase();
            return s == 'pending';
          }).length;
        }
        return _actionCard(
          context, 
          Icons.exit_to_app, 
          "$title ($pendingCount)",
          color, 
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLeavesScreen(viewRole: role)))
        );
      }
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, spreadRadius: 1)],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
