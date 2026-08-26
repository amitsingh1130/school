import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/attendance_report_service.dart';

class AdminAttendanceClassListScreen extends StatelessWidget {
  const AdminAttendanceClassListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Attendance"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          Set<String> classes = {};
          for (var doc in snapshot.data!.docs) {
            classes.add(doc['classId'] ?? 'Unassigned');
          }
          List<String> sortedClasses = classes.toList()..sort();

          if (sortedClasses.isEmpty) return const Center(child: Text("No classes found."));

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: sortedClasses.length,
            itemBuilder: (context, index) {
              String cls = sortedClasses[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder, color: Color(0xFFFFD700)),
                  title: Text("Class $cls"),
                  subtitle: const Text("View Attendance History"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminAttendanceDateListScreen(classId: cls),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AdminAttendanceDateListScreen extends StatelessWidget {
  final String classId;
  const AdminAttendanceDateListScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("History: Class $classId"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: "Download Monthly Report",
            onPressed: () => AttendanceReportService.showMonthPicker(context, classId),
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
              String? targetClass = data['targetClass'];
              
              bool applies = false;
              if (target == "All School" || target == "Students Only") {
                applies = true;
              } else if (target == "Specific Class" && targetClass == classId) {
                applies = true;
              }

              if (applies) {
                holidays[doc.id] = data['reason'] ?? "Holiday";
              }
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('attendance')
                .where('classId', isEqualTo: classId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              Set<String> allDates = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  allDates.add(doc['date']);
                }
              }
              allDates.addAll(holidays.keys);

              if (allDates.isEmpty) return const Center(child: Text("No records found."));
              
              List<String> sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

              Map<String, dynamic> attendanceDocs = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  attendanceDocs[doc['date']] = doc.data();
                }
              }

              return ListView.builder(
                itemCount: sortedDates.length,
                itemBuilder: (context, index) {
                  String date = sortedDates[index];
                  bool isHoliday = holidays.containsKey(date);
                  var data = attendanceDocs[date];

                  if (isHoliday) {
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      color: Colors.pink.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.celebration, color: Colors.pink),
                        title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("SCHOOL HOLIDAY: ${holidays[date]}"),
                        trailing: const Text("OFF", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.pink)),
                      ),
                    );
                  }

                  if (data == null) return const SizedBox.shrink();

                  Map<String, dynamic> records = data['records'] ?? {};
                  int present = records.values.where((v) => 
                    v == 'PRESENT' || v == 'HALF DAY' || v == 'ON LEAVE' || v == 'P' || v == true
                  ).length;
                  String time = data['time'] ?? '--:--';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.event_note, color: Colors.blueGrey),
                      title: Text(data['date'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Time: $time | Attendance: $present / ${records.length}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminStudentAttendanceDetails(
                              classId: classId,
                              date: data['date'],
                              time: time,
                            ),
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

class AdminStudentAttendanceDetails extends StatelessWidget {
  final String classId;
  final String date;
  final String time;

  const AdminStudentAttendanceDetails({super.key, required this.classId, required this.date, required this.time});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance ($date)"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('attendance')
            .doc("${classId}_$date")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Data not found."));
          }

          Map<String, dynamic> records = snapshot.data!.get('records') ?? {};
          
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .where('classId', isEqualTo: classId)
                .snapshots(),
            builder: (context, studentSnapshot) {
              if (!studentSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              var students = studentSnapshot.data!.docs;

              students.sort((a, b) {
                int r1 = int.tryParse(a['rollNumber'].toString()) ?? 999;
                int r2 = int.tryParse(b['rollNumber'].toString()) ?? 999;
                return r1.compareTo(r2);
              });

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFFFF9C4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Class $classId | Marked at: $time",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        var student = students[index];
                        String roll = student['rollNumber'].toString();
                        dynamic status = records[roll] ?? 'ABSENT';
                        
                        return ListTile(
                          leading: CircleAvatar(child: Text(student['name'][0])),
                          title: Text(student['name']),
                          subtitle: Text("Roll No: $roll"),
                          trailing: _getStatusChip(status),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _getStatusChip(dynamic status) {
    String label = "ABSENT";
    Color color = Colors.red;

    if (status == 'PRESENT' || status == 'P' || status == true) {
      label = "PRESENT";
      color = Colors.green;
    } else if (status == 'HALF DAY' || status == 'HD') {
      label = "HALF DAY";
      color = Colors.orange;
    } else if (status == 'ON LEAVE' || status == 'L') {
      label = "ON LEAVE";
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
