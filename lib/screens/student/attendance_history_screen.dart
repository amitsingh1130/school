import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  final String rollNumber;
  final String classId;

  const AttendanceHistoryScreen({super.key, required this.rollNumber, required this.classId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Attendance History"),
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
              
              // Get all unique dates from both attendance and holidays
              Set<String> allDates = {};
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  allDates.add(doc['date']);
                }
              }
              allDates.addAll(holidays.keys);

              if (allDates.isEmpty) return const Center(child: Text("No records found."));
              
              List<String> sortedDates = allDates.toList()..sort((a, b) => b.compareTo(a));

              // Map attendance docs for easy lookup
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
                  var attData = attendanceDocs[date];
                  
                  String status = "ABSENT";
                  String time = "--:--";
                  
                  if (isHoliday) {
                    status = "HOLIDAY";
                  } else if (attData != null) {
                    Map<String, dynamic> studentList = attData['records'] ?? {};
                    status = studentList[rollNumber] ?? 'ABSENT';
                    time = attData['time'] ?? '--:--';
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        isHoliday ? Icons.celebration : Icons.event_available, 
                        color: isHoliday ? Colors.pink : Colors.blueGrey
                      ),
                      title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isHoliday ? "Reason: ${holidays[date]}" : "Time: $time"),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _getColor(status)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: _getColor(status), fontWeight: FontWeight.bold, fontSize: 10),
                        ),
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

  Color _getColor(String status) {
    if (status == 'PRESENT') return Colors.green;
    if (status == 'HALF DAY') return Colors.orange;
    if (status == 'ON LEAVE') return Colors.blue;
    if (status == 'HOLIDAY') return Colors.pink;
    return Colors.red;
  }
}
