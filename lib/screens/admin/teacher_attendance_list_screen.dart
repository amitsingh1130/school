import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/attendance_report_service.dart';

class TeacherAttendanceHistoryScreen extends StatelessWidget {
  const TeacherAttendanceHistoryScreen({super.key});

  Future<void> _syncAbsentees(BuildContext context) async {
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    DateTime now = DateTime.now();
    
    // 1. Check Time - Only allow after 09:30 AM
    if (now.hour < 9 || (now.hour == 9 && now.minute < 30)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Auto Absent can only be marked after 09:30 AM."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // 2. Check if today is Sunday
    if (now.weekday == DateTime.sunday) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Today is Sunday. No attendance sync needed.")));
      return;
    }

    // 3. Check if today is a holiday (Only for All School)
    var holidayDoc = await FirebaseFirestore.instance.collection('holidays').doc(today).get();
    if (holidayDoc.exists) {
      String target = holidayDoc.data()?['target'] ?? "All School";
      if (target == "All School") {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Today is a Holiday. No sync needed.")));
        return;
      }
    }

    // 4. Fetch All Staff (Teachers, Principal, Vice Principal)
    var staffSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: ['teacher', 'principal', 'vice_principal'])
        .get();
    
    // 5. Fetch Existing Attendance for Today
    var attSnap = await FirebaseFirestore.instance.collection('teacher_attendance').where('date', isEqualTo: today).get();
    Set<String> markedIds = attSnap.docs.map((d) => d['teacherId'].toString()).toSet();

    int absentCount = 0;
    for (var doc in staffSnap.docs) {
      String tId = doc['userId'];
      if (!markedIds.contains(tId)) {
        // Mark as Absent
        await FirebaseFirestore.instance.collection('teacher_attendance').doc("${tId}_$today").set({
          'teacherId': tId,
          'date': today,
          'time': 'Auto Marked',
          'status': 'Absent',
          'timestamp': FieldValue.serverTimestamp(),
        });
        absentCount++;
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Complete: $absentCount staff members marked ABSENT."), backgroundColor: Colors.orange));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Staff Attendance History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: "Sync Today's Absentees",
            onPressed: () => _syncAbsentees(context),
          ),
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
              var data = doc.data() as Map<String, dynamic>;
              String target = data['target'] ?? "All School";
              if (target == "All School") {
                holidays[doc.id] = data['reason'] ?? "Holiday";
              }
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
                var data = doc.data() as Map<String, dynamic>;
                String d = data['date'];
                String status = (data['status'] ?? '').toString().toLowerCase();
                
                if (status == 'present' || status == 'p') {
                  dailyCount[d] = (dailyCount[d] ?? 0) + 1;
                }
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
                      subtitle: Text("Present Staff: $count"),
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
      appBar: AppBar(title: Text("Staff Status ($date)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', whereIn: ['teacher', 'principal', 'vice_principal'])
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          var teachers = userSnap.data!.docs;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('teacher_attendance')
                .where('date', isEqualTo: date)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              // Map attendance by teacherId
              Map<String, dynamic> attendanceMap = {};
              for (var doc in snapshot.data!.docs) {
                attendanceMap[doc['teacherId']] = doc.data();
              }

              return ListView.builder(
                itemCount: teachers.length,
                itemBuilder: (context, index) {
                  var teacher = teachers[index].data() as Map<String, dynamic>;
                  String tId = teacher['userId'];
                  var att = attendanceMap[tId];

                  String status = (att != null) ? (att['status'] ?? 'Present') : "Absent";
                  String time = (att != null) ? (att['time'] ?? '--:--') : "Not Marked";
                  
                  Color statusColor = Colors.red;
                  IconData icon = Icons.cancel;

                  if (status.toLowerCase().contains('present')) {
                    statusColor = Colors.green;
                    icon = Icons.check_circle;
                  } else if (status.toLowerCase().contains('leave') || status.toLowerCase().contains('half')) {
                    statusColor = Colors.orange;
                    icon = Icons.info;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: statusColor.withOpacity(0.1),
                        child: Icon(icon, color: statusColor, size: 20),
                      ),
                      title: Text(teacher['name'] ?? 'Unknown'),
                      subtitle: Text("Status: ${status.toUpperCase()} | $time"),
                      trailing: Text(
                        status.toUpperCase(), 
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)
                      ),
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
