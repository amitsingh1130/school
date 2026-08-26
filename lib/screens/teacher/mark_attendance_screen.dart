import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/location_service.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String classId;
  final bool isTab;

  const MarkAttendanceScreen({super.key, required this.classId, this.isTab = false});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  Map<String, String> attendanceStatus = {}; 
  String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? holidayReason;
  bool isHoliday = false;

  @override
  void initState() {
    super.initState();
    _checkHoliday();
    _loadExistingData();
  }

  void _checkHoliday() async {
    var doc = await FirebaseFirestore.instance.collection('holidays').doc(today).get();
    if (doc.exists && mounted) {
      String target = doc.data()?['target'] ?? "All School";
      String? targetClass = doc.data()?['targetClass'];
      
      bool appliesToThisClass = false;
      if (target == "All School" || target == "Students Only") {
        appliesToThisClass = true;
      } else if (target == "Specific Class" && targetClass == widget.classId) {
        appliesToThisClass = true;
      }

      if (appliesToThisClass) {
        setState(() {
          isHoliday = true;
          holidayReason = doc.data()?['reason'] ?? "School Holiday";
        });
      }
    }
  }

  void _loadExistingData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc("${widget.classId}_$today")
          .get();

      if (doc.exists && mounted) {
        setState(() {
          Map<String, dynamic> existing = doc.data()?['records'] ?? {};
          existing.forEach((key, value) {
            attendanceStatus[key] = value.toString();
          });
        });
      }
    } catch (e) {
      debugPrint("Load Error: $e");
    }
  }

  void _submitAttendance() async {
    try {
      // 1. Check Location
      bool inSchool = await LocationService.checkLocation(context);
      if (!inSchool) return;

      String currentTime = DateFormat('hh:mm a').format(DateTime.now());
      
      await FirebaseFirestore.instance.collection('attendance').doc("${widget.classId}_$today").set({
        'classId': widget.classId,
        'date': today,
        'time': currentTime,
        'records': attendanceStatus,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attendance saved successfully!"), backgroundColor: Colors.green)
        );
        if (!widget.isTab) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isHoliday) {
      return Scaffold(
        appBar: AppBar(title: Text("Class ${widget.classId}"), automaticallyImplyLeading: !widget.isTab),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration, size: 80, color: Colors.pink),
              const SizedBox(height: 20),
              Text("Today is a Holiday!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.pink.shade700)),
              const SizedBox(height: 10),
              Text(holidayReason ?? "", style: const TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 10),
              Text("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              const Text("No attendance needed for today.", style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Class ${widget.classId}"),
        automaticallyImplyLeading: !widget.isTab,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('students')
            .where('classId', isEqualTo: widget.classId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var students = snapshot.data!.docs;

          students.sort((a, b) {
            int r1 = int.tryParse(a['rollNumber'].toString()) ?? 999;
            int r2 = int.tryParse(b['rollNumber'].toString()) ?? 999;
            return r1.compareTo(r2);
          });

          if (students.isEmpty) return const Center(child: Text("No students found."));

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    var s = students[index];
                    String sRoll = s['rollNumber'].toString();
                    attendanceStatus.putIfAbsent(sRoll, () => 'PRESENT');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(s['name']),
                        subtitle: Text("Roll: $sRoll"),
                        trailing: DropdownButton<String>(
                          value: attendanceStatus[sRoll],
                          items: const [
                            DropdownMenuItem(value: 'PRESENT', child: Text("PRESENT", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'ABSENT', child: Text("ABSENT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'HALF DAY', child: Text("HALF DAY", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'ON LEAVE', child: Text("ON LEAVE", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) => setState(() => attendanceStatus[sRoll] = val!),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _submitAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("SUBMIT ATTENDANCE"),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
