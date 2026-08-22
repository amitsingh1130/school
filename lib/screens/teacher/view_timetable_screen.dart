import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class ViewTimetableScreen extends StatefulWidget {
  final String teacherId;
  const ViewTimetableScreen({super.key, required this.teacherId});

  @override
  State<ViewTimetableScreen> createState() => _ViewTimetableScreenState();
}

class _ViewTimetableScreenState extends State<ViewTimetableScreen> {
  String selectedDay = DateFormat('EEEE').format(DateTime.now());
  final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  
  final List<String> periodHeaders = [
    "PRAYER", "1st Subject", "2nd Subject", "3rd Subject", "4th Subject", "LUNCH", "5th Subject", "6th Subject", "7th Subject"
  ];

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: Text("Weekly Schedule ($session)")),
      body: Column(
        children: [
          _buildDaySelector(),
          const Divider(),
          Expanded(child: _buildTeacherGrid(session)),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 55,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ChoiceChip(
            label: Text(days[index]),
            selected: selectedDay == days[index],
            onSelected: (s) => setState(() => selectedDay = days[index]),
            selectedColor: const Color(0xFFFFD700),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherGrid(String session) {
    // Note: We show entries where teacherId matches OR special school-wide periods like PRAYER/LUNCH
    // Actually, usually Admin assigns a teacher to PRAYER/LUNCH supervision.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('timetable')
          .where('day', isEqualTo: selectedDay)
          .where('academicSession', isEqualTo: session)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        // Filter in memory for this specific teacher
        var allPeriods = snapshot.data?.docs ?? [];
        Map<String, Map<String, dynamic>> schedule = {};
        
        for (var doc in allPeriods) {
          var data = doc.data() as Map<String, dynamic>;
          // Show if assigned to this teacher OR if it's PRAYER/LUNCH (school-wide view)
          if (data['teacherId'] == widget.teacherId) {
            schedule[data['period'] ?? ""] = data;
          } else if (data['period'] == "PRAYER" || data['period'] == "LUNCH") {
            // Only add if not already assigned (teacher might be assigned to a specific class prayer)
            schedule.putIfAbsent(data['period'] ?? "", () => data);
          }
        }

        if (schedule.isEmpty) {
          return Center(child: Text("No classes assigned for $selectedDay."));
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(const Color(0xFFFFD700).withOpacity(0.3)),
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: [
                const DataColumn(label: Text("Period", style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text("Time", style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text("Class", style: TextStyle(fontWeight: FontWeight.bold))),
                const DataColumn(label: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: periodHeaders.map((p) {
                var data = schedule[p];
                bool isSpecial = p == "PRAYER" || p == "LUNCH";
                
                return DataRow(cells: [
                  DataCell(Text(p, style: TextStyle(fontWeight: FontWeight.w500, color: isSpecial ? Colors.red : Colors.black))),
                  DataCell(Text(data?['time'] ?? "--:--", style: TextStyle(color: isSpecial ? Colors.red : Colors.black87))),
                  DataCell(Text(data?['classId'] ?? (isSpecial ? "School" : "-"), style: TextStyle(color: data != null ? Colors.blue : Colors.grey))),
                  DataCell(Text(data?['subject'] ?? (isSpecial ? p : "Free"), style: TextStyle(fontStyle: data != null ? FontStyle.normal : FontStyle.italic))),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
