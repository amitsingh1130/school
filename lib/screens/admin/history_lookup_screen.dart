import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'admin_attendance_screen.dart';

class HistoryLookupScreen extends StatefulWidget {
  const HistoryLookupScreen({super.key});

  @override
  State<HistoryLookupScreen> createState() => _HistoryLookupScreenState();
}

class _HistoryLookupScreenState extends State<HistoryLookupScreen> {
  DateTime _selectedDate = DateTime.now();

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020), 
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(title: const Text("Past Data Lookup")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFFFFD700)),
                title: const Text("Select Date to View Records"),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                onTap: () => _pickDate(context),
              ),
            ),
            const SizedBox(height: 20),
            _historyOption(Icons.checklist, "View Attendance for this date", () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AdminStudentAttendanceDetails(
                classId: "ALL", 
                date: dateStr,
                time: "History Lookup",
              )));
            }),
            _historyOption(Icons.money, "View Fee Collections for this date", () {
              // Logic to view specific date fees
            }),
            _historyOption(Icons.book, "View Homeworks posted on this date", () {
              // Logic to view specific date homework
            }),
          ],
        ),
      ),
    );
  }

  Widget _historyOption(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
