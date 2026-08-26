import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeworkDetailScreen extends StatelessWidget {
  final Map<String, dynamic> homeworkData;

  const HomeworkDetailScreen({super.key, required this.homeworkData});

  @override
  Widget build(BuildContext context) {
    String teacherName = homeworkData['teacherName'] ?? 'Teacher';
    String? gender = homeworkData['teacherGender'];
    if (gender != null) {
      String honorific = (gender == "Male") ? " Sir" : (gender == "Female" ? " Ma'am" : "");
      teacherName = "${teacherName.split(" ").first}$honorific";
    }

    DateTime? dt = (homeworkData['createdAt'] as dynamic)?.toDate();
    String timeStr = dt != null ? DateFormat('dd MMM yyyy | hh:mm a').format(dt) : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Homework Details"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homeworkData['subject'] ?? 'No Subject',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 5),
                      Text("By: $teacherName", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 5),
                      Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              "Instruction / Description:",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 10),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: Text(
                homeworkData['description'] ?? 'No details provided.',
                style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
              ),
            ),
            
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "Please complete your homework on time.",
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
