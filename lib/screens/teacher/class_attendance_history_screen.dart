import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/attendance_report_service.dart';

class ClassAttendanceHistoryScreen extends StatelessWidget {
  final String classId;
  const ClassAttendanceHistoryScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Class $classId History"),
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
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.pink.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.celebration, color: Colors.pink),
                        title: Text("Date: $date", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.event, color: Colors.blue),
                      title: Text("Date: ${data['date']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Time: $time | Present: $present / ${records.length}"),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showDetailedReport(context, data['date'], records);
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

  void _showDetailedReport(BuildContext context, String date, Map<String, dynamic> records) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Detailed Report: $date", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('students').where('classId', isEqualTo: classId).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  var students = snap.data!.docs;

                  // SORT BY ROLL NUMBER
                  students.sort((a, b) {
                    int r1 = int.tryParse(a['rollNumber']?.toString() ?? '999') ?? 999;
                    int r2 = int.tryParse(b['rollNumber']?.toString() ?? '999') ?? 999;
                    return r1.compareTo(r2);
                  });

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      var s = students[index];
                      String roll = s['rollNumber'].toString();
                      dynamic status = records[roll] ?? 'ABSENT';
                      return ListTile(
                        leading: CircleAvatar(child: Text(s['name'][0])),
                        title: Text(s['name']),
                        subtitle: Text("Roll No: $roll"),
                        trailing: _getStatusLabel(status),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getStatusLabel(dynamic status) {
    String label = "ABSENT";
    Color color = Colors.red;

    if (status == 'PRESENT' || status == 'P' || status == true) { 
      label = "PRESENT"; color = Colors.green; 
    } else if (status == 'HALF DAY' || status == 'HD') { 
      label = "HALF DAY"; color = Colors.orange; 
    } else if (status == 'ON LEAVE' || status == 'L') { 
      label = "ON LEAVE"; color = Colors.blue; 
    }

    return Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11));
  }
}
