import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';

class TeacherDashboard extends StatelessWidget {
  final String teacherClassId; // In a real app, fetch this from Teacher's profile
  final DatabaseService _dbService = DatabaseService();

  TeacherDashboard({super.key, required this.teacherClassId});

  @override
  Widget build(BuildContext context) {
    // Get current day for timetable (e.g., 'Monday')
    String currentDay = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Dashboard - Class $teacherClassId'),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.people), text: 'Students'),
            Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
          ],
        ),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Theme.of(context).primaryColor,
              child: const TabBar(
                tabs: [
                  Tab(text: 'Students'),
                  Tab(text: 'Timetable'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // --- TAB 1: REAL-TIME STUDENT LIST ---
                  _buildStudentList(),

                  // --- TAB 2: DYNAMIC TIMETABLE ---
                  _buildTimetable(currentDay),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return StreamBuilder<List<StudentModel>>(
      stream: _dbService.getStudentsByClass(teacherClassId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No students found for this class.'));
        }

        final students = snapshot.data!;

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];
            return ListTile(
              leading: CircleAvatar(child: Text(student.name[0])),
              title: Text(student.name),
              subtitle: Text('Roll No: ${student.rollNumber}'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Navigate to student details/attendance upload
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTimetable(String day) {
    return StreamBuilder(
      stream: _dbService.getTimetable(teacherClassId, day),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data.docs.isEmpty) {
          return Center(child: Text('No schedule for $day.'));
        }

        return ListView.builder(
          itemCount: snapshot.data.docs.length,
          itemBuilder: (context, index) {
            var period = snapshot.data.docs[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(period['subject']),
                subtitle: Text('${period['startTime']} - ${period['endTime']}'),
                trailing: const Chip(label: Text('Live')),
              ),
            );
          },
        );
      },
    );
  }
}
