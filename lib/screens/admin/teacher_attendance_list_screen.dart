import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/attendance_report_service.dart';

class TeacherAttendanceHistoryScreen extends StatelessWidget {
  const TeacherAttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Attendance History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Download Monthly Report",
            onPressed: () => AttendanceReportService.showTeacherMonthPicker(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('holidays').snapshots(),
        builder: (context, holidaySnapshot) {
          Map<String, String> holidays = {};
          if (holidaySnapshot.hasData) {
            for (var doc in holidaySnapshot.data!.docs) {
              holidays[doc.id] = doc['reason'] ?? "Holiday";
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('teacher_attendance').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              // Combine unique dates from attendance and holidays
              Set<String> allDates = {};
              for (var doc in snapshot.data!.docs) {
                allDates.add(doc['date']);
              }
              allDates.addAll(holidays.keys);

              List<String> sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

              if (sortedDates.isEmpty) return const Center(child: Text("No records found."));

              // Map to track how many teachers are present on each date
              Map<String, int> dailyCount = {};
              for (var doc in snapshot.data!.docs) {
                String d = doc['date'];
                dailyCount[d] = (dailyCount[d] ?? 0) + 1;
              }

              return ListView.builder(
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  String date = sortedDates[index];
                  bool isHoliday = holidays.containsKey(date);
                  int count = dailyCount[date] ?? 0;

                  if (isHoliday) {
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.pink.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.celebration, color: Colors.pink),
                        title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("SCHOOL HOLIDAY: ${holidays[date]}"),
                        trailing: const Text("OFF", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
                      ),
                    );
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today, color: Colors.blue),
                      title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Present Teachers: $count"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherAttendanceDateDetails(date: date),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class TeacherAttendanceDateDetails extends StatelessWidget {
  final String date;
  const TeacherAttendanceDateDetails({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Present Teachers ($date)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teacher_attendance')
            .where('date', isEqualTo: date)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snapshot.data!.docs;

          if (docs.isEmpty) return const Center(child: Text("No teachers marked present for this day."));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var attendanceData = docs[index].data() as Map<String, dynamic>;
              String tId = attendanceData['teacherId'];
              String markedTime = attendanceData['time'] ?? '--:--';

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').where('userId', isEqualTo: tId).limit(1).snapshots(),
                builder: (context, uSnap) {
                  String name = "Loading...";
                  if (uSnap.hasData && uSnap.data!.docs.isNotEmpty) name = uSnap.data!.docs.first['name'];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name),
                      subtitle: Text("Marked at: $markedTime"),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
