import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../teacher/self_attendance_screen.dart';
import '../common/leave_management_screen.dart';
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
    // Dashboard opens and sync check happens in background
    DatabaseService().autoSyncExistingStudents();
    _checkAndSendFeeReminders();
  }

  Future<void> _checkAndSendFeeReminders() async {
    try {
      final DateTime now = DateTime.now();
      String todayStr = DateFormat('yyyy-MM-dd').format(now);
      String monthName = DateFormat('MMMM').format(now);
      final session = Provider.of<SessionProvider>(context, listen: false).currentSession;

      var structureSnap = await FirebaseFirestore.instance
          .collection('class_fees')
          .where('academicSession', isEqualTo: session)
          .get();

      for (var feeDoc in structureSnap.docs) {
        var feeData = feeDoc.data();
        String category = feeData['feeCategory'] ?? '';
        String fullTitle = feeData['feeTitle'] ?? category; 
        String classId = feeData['classId'];
        String feeAmount = feeData['amount'];

        bool isDueToday = false;
        String feeTitleToNotify = fullTitle;

        if (category == 'Monthly Fee') {
          int classDueDay = int.tryParse(feeData['dueDay'] ?? "10") ?? 10;
          if (now.day == classDueDay) {
            isDueToday = true;
            feeTitleToNotify = "Monthly Fee - $monthName";
          }
        } else {
          if (feeData['dueDate'] == todayStr) {
            isDueToday = true;
            feeTitleToNotify = fullTitle;
          }
        }

        if (isDueToday) {
          // AVOID MULTIPLE DISPATCHES: Check if this fee notification was already sent today
          String dispatchId = "fee_rem_${feeDoc.id}_$todayStr";
          var dispatchCheck = await FirebaseFirestore.instance.collection('system_logs').doc(dispatchId).get();
          if (dispatchCheck.exists) continue; 

          var studentsSnap = await FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('classId', isEqualTo: classId)
              .get();

          for (var studentDoc in studentsSnap.docs) {
            String sId = studentDoc['userId'];
            
            var paymentCheck = await FirebaseFirestore.instance
                .collection('fees')
                .where('studentId', isEqualTo: sId)
                .where('feeTitle', isEqualTo: feeTitleToNotify)
                .where('academicSession', isEqualTo: session)
                .limit(1)
                .get();

            if (paymentCheck.docs.isEmpty) {
              await FirebaseFirestore.instance.collection('notifications').add({
                'toUserId': sId,
                'title': "Fee Due: $feeTitleToNotify",
                'message': "Dear Student, your fee of ₹$feeAmount for $feeTitleToNotify is due today. Please pay at the office.",
                'type': 'fee',
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }

          // Mark as dispatched
          await FirebaseFirestore.instance.collection('system_logs').doc(dispatchId).set({
            'type': 'fee_reminder',
            'date': todayStr,
            'feeId': feeDoc.id,
            'sentAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Fee Reminder Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    String dashboardTitle = "Admin Dashboard";
    Color appBarColor = const Color(0xFFFFD700);
    Color welcomeBoxColor = const Color(0xFFFFF9C4);

    if (widget.user.role == 'principal') {
      dashboardTitle = "Principal Dashboard";
      appBarColor = Colors.deepPurple;
      welcomeBoxColor = Colors.purple.shade50;
    } else if (widget.user.role == 'vice_principal') {
      dashboardTitle = "Vice Principal Dashboard";
      appBarColor = Colors.indigo;
      welcomeBoxColor = Colors.indigo.shade50;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(dashboardTitle),
        backgroundColor: appBarColor,
        foregroundColor: (widget.user.role == 'admin') ? Colors.black : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- WELCOME SECTION ---
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: welcomeBoxColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: appBarColor.withValues(alpha: 0.2)),
              ),
              child: Builder(builder: (context) {
                String honorific = "";
                if (widget.user.gender == "Male") honorific = " Sir";
                if (widget.user.gender == "Female") honorific = " Ma'am";
                String firstName = widget.user.name.split(" ").first;
                return Text(
                  "Welcome, $firstName$honorific",
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold, 
                    color: (widget.user.role == 'admin') ? Colors.black : appBarColor
                  ),
                );
              }),
            ),

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
                  "Teacher Attendance",
                  FirebaseFirestore.instance.collection('teacher_attendance').where('date', isEqualTo: today).snapshots(),
                  FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(), // Strictly Teachers
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
                _buildLeaveCard(context, "Staff Leaves", ['teacher', 'principal', 'vice_principal'], Colors.red),
                _buildLeaveCard(context, "Stud. Leaves", ['student'], Colors.teal),
              ],
            ),

            // --- PERSONAL STAFF ACTIONS (For Principal & Vice Principal) ---
            if (widget.user.role == 'principal' || widget.user.role == 'vice_principal') ...[
              const SizedBox(height: 25),
              const Row(
                children: [
                  Icon(Icons.person_pin, color: Colors.blueGrey, size: 20),
                  SizedBox(width: 8),
                  Text("My Personal Staff Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionCard(
                      context, 
                      Icons.fingerprint, 
                      "Mark My Attendance", 
                      Colors.deepOrange, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherSelfAttendanceManagement(teacherId: widget.user.userId)))
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _actionCard(
                      context, 
                      Icons.exit_to_app, 
                      "My Leaves", 
                      Colors.redAccent, 
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveManagementScreen(user: widget.user)))
                    ),
                  ),
                ],
              ),
            ],
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
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
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
                          // Filter strictly for PRESENT status for teachers
                          for (var doc in presentSnapshot.data!.docs) {
                            String status = (doc['status'] ?? '').toString().toLowerCase();
                            if (status == 'present' || status == 'p') {
                              present++;
                            }
                          }
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

  Widget _buildLeaveCard(BuildContext context, String title, List<String> roles, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leaves').where('role', whereIn: roles).snapshots(),
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
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageLeavesScreen(viewRoles: roles)))
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
          boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1)],
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
