import 'package:flutter/material.dart';
import 'mark_attendance_screen.dart';
import 'class_attendance_history_screen.dart';

class StudentAttendanceManagement extends StatelessWidget {
  final String classId;
  const StudentAttendanceManagement({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Class $classId Attendance"),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Mark Attendance"),
              Tab(text: "Class History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MarkAttendanceScreen(classId: classId, isTab: true),
            ClassAttendanceHistoryScreen(classId: classId),
          ],
        ),
      ),
    );
  }
}
