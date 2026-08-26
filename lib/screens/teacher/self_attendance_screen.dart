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
  String? _markedStatus;
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
      String target = doc.data()?['target'] ?? "All School";
      // Teacher ke liye tabhi holiday hoga agar "All School" ho. 
      // Agar "Students Only" ya "Specific Class" hai toh teacher ko aana hai.
      if (target == "All School") {
        setState(() {
          _isHoliday = true;
          _holidayReason = doc.data()?['reason'] ?? "School Holiday";
        });
      }
    }
  }

  void _checkStatus() async {
    var doc = await FirebaseFirestore.instance.collection('teacher_attendance').doc("${widget.teacherId}_$today").get();
    if (doc.exists && mounted) {
       setState(() {
         _isMarked = true;
         _markedTime = doc.data()?['time'];
         _markedStatus = doc.data()?['status'];
       });
    }
  }

  void _markAttendance() async {
    if (_isHoliday || _isMarked) return;

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
      _markedStatus = 'Present';
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

    String statusText = "Please mark your attendance";
    Color statusColor = Colors.red;
    IconData iconData = Icons.fingerprint;

    if (_isMarked) {
      String status = (_markedStatus ?? 'Present').toUpperCase();
      if (status == 'PRESENT') {
        statusText = "You are PRESENT today!";
        statusColor = Colors.green;
        iconData = Icons.check_circle;
      } else if (status == 'ABSENT') {
        statusText = "You are marked ABSENT today!";
        statusColor = Colors.red;
        iconData = Icons.cancel;
      } else {
        statusText = "You are $status today!";
        statusColor = Colors.orange;
        iconData = Icons.info;
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, size: 100, color: statusColor),
          const SizedBox(height: 20),
          Text(today, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (_isMarked && _markedTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Marked at: $_markedTime", style: const TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 10),
          Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
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
            var data = doc.data() as Map<String, dynamic>;
            String target = data['target'] ?? "All School";
            if (target == "All School") {
              holidays[doc.id] = data['reason'] ?? "Holiday";
            }
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

                Color statusColor = Colors.red;
                IconData statusIcon = Icons.cancel;

                if (isHoliday) {
                  status = "HOLIDAY";
                  statusColor = Colors.pink;
                  statusIcon = Icons.celebration;
                } else if (data != null) {
                  status = (data['status'] ?? 'Absent').toString().toUpperCase();
                  time = data['time'] ?? '--:--';
                  if (status == 'PRESENT') {
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                  } else if (status.contains('LEAVE') || status.contains('HALF')) {
                    statusColor = Colors.orange;
                    statusIcon = Icons.info;
                  }
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isHoliday ? Colors.pink.shade50 : Colors.white,
                  child: ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isHoliday ? "SCHOOL HOLIDAY: $reason" : "Time: $time"),
                    trailing: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
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
