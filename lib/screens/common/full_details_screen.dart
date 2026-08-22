import 'package:flutter/material.dart';
import '../../models/user_model.dart';

class FullDetailsScreen extends StatelessWidget {
  final UserModel user;
  const FullDetailsScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(user.role == 'student' ? "Student Details" : "Teacher Details"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          _detailItem("Full Name", user.name),
          if (user.role == 'student') _detailItem("Roll Number", user.rollNumber ?? "N/A"),
          _detailItem("Father's Name", user.fatherName ?? "N/A"),
          _detailItem("Mother's Name", user.motherName ?? "N/A"),
          _detailItem("Date of Birth", user.dob ?? "N/A"),
          _detailItem("Mobile Number", user.mobile ?? "N/A"),
          if (user.role == 'student') ...[
             _detailItem("Class", user.classId ?? "N/A"),
             _detailItem("Registration No.", user.regNo ?? "N/A"),
          ],
          if (user.role == 'teacher') ...[
             _detailItem("Subject", user.subject ?? "N/A"),
             _detailItem("Designation", user.designation ?? "N/A"),
             _detailItem("Joining Date", user.joiningDate ?? "N/A"),
          ]
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
