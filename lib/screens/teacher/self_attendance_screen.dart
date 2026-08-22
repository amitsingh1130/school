import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/location_service.dart';

class TeacherSelfAttendanceManagement extends StatelessWidget {
  final String teacherId;
  const TeacherSelfAttendanceManagement({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Attendance"),
          bottom: const TabBar(
            labelColor: Colors.black,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black,
            tabs: [
              Tab(text: "Mark Attendance"),
              Tab(text: "Attendance History"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TeacherSelfAttendanceScreen(teacherId: teacherId),
            TeacherSelfHistoryTab(teacherId: teacherId),
          ],
        ),
      ),
    );
  }
}

class TeacherSelfAttendanceScreen extends StatefulWidget {
  final String teacherId;
  const TeacherSelfAttendanceScreen({super.key, required this.teacherId});

  @override
  State<TeacherSelfAttendanceScreen> createState() => _TeacherSelfAttendanceScreenState();
}

class _TeacherSelfAttendanceScreenState extends State<TeacherSelfAttendanceScreen> {
  bool _isMarked = false;
  bool _isHoliday = false;
  String? _holidayReason;
  String? _markedTime;
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _checkHoliday();
    _checkStatus();
  }

  void _checkHoliday() async {
    var doc = await FirebaseFirestore.instance.collection('holidays').doc(today).get();
    if (doc.exists && mounted) {
      setState(() {
        _isHoliday = true;
        _holidayReason = doc.data()?['reason'] ?? "School Holiday";
      });
    }
  }

  void _checkStatus() async {
    var doc = await FirebaseFirestore.instance.collection('teacher_attendance').doc("${widget.teacherId}_$today").get();
    if (doc.exists && mounted) {
       setState(() {
         _isMarked = true;
         _markedTime = doc.data()?['time'];
       });
    }
  }

  void _markAttendance() async {
    if (_isHoliday) return;

    setState(() => _isMarked = true); // Temporary loading state or similar

    // 1. Check Location
    bool inSchool = await LocationService.checkLocation(context);
    if (!inSchool) {
      setState(() => _isMarked = false);
      return;
    }

    String currentTime = DateFormat('hh:mm a').format(DateTime.now());
    await FirebaseFirestore.instance.collection('teacher_attendance').doc("${widget.teacherId}_$today").set({
      'teacherId': widget.teacherId,
      'date': today,
      'time': currentTime,
      'status': 'Present',
      'timestamp': FieldValue.serverTimestamp(),
    });
    setState(() {
      _isMarked = true;
      _markedTime = currentTime;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Attendance Marked for Today!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isHoliday) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 100, color: Colors.pink),
            const SizedBox(height: 20),
            const Text("Today is a Holiday!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink)),
            const SizedBox(height: 10),
            Text(_holidayReason ?? "", style: const TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 10),
            Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text("Enjoy your day off!"),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_isMarked ? Icons.check_circle : Icons.fingerprint, size: 100, color: _isMarked ? Colors.green : Colors.red),
          const SizedBox(height: 20),
          Text(today, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_isMarked && _markedTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Marked at: $_markedTime", style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 10),
          Text(_isMarked ? "You are PRESENT today!" : "Please mark your attendance"),
          const SizedBox(height: 30),
          if (!_isMarked)
            ElevatedButton(
              onPressed: _markAttendance,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15)),
              child: const Text("MARK PRESENT", style: TextStyle(color: Colors.black)),
            ),
        ],
      ),
    );
  }
}

class TeacherSelfHistoryTab extends StatelessWidget {
  final String teacherId;
  const TeacherSelfHistoryTab({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('holidays').snapshots(),
      builder: (context, holidaySnapshot) {
        Map<String, String> holidays = {};
        if (holidaySnapshot.hasData) {
          for (var doc in holidaySnapshot.data!.docs) {
            holidays[doc.id] = doc['reason'] ?? "Holiday";
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('teacher_attendance')
              .where('teacherId', isEqualTo: teacherId)
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

                String status = "ABSENT";
                String time = "--:--";
                String? reason = isHoliday ? holidays[date] : null;

                if (isHoliday) {
                  status = "HOLIDAY";
                } else if (data != null) {
                  status = (data['status'] ?? 'Absent').toString().toUpperCase();
                  time = data['time'] ?? '--:--';
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isHoliday ? Colors.pink.shade50 : Colors.white,
                  child: ListTile(
                    leading: Icon(
                      isHoliday ? Icons.celebration : Icons.check_circle, 
                      color: isHoliday ? Colors.pink : (status == 'PRESENT' ? Colors.green : Colors.red)
                    ),
                    title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isHoliday ? "SCHOOL HOLIDAY: $reason" : "Time: $time"),
                    trailing: Text(
                      status,
                      style: TextStyle(
                        color: isHoliday ? Colors.pink : (status == 'PRESENT' ? Colors.green : Colors.red),
                        fontWeight: FontWeight.bold,
                        fontSize: 12
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
