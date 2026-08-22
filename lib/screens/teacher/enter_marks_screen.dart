import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/session_provider.dart';
import 'detailed_result_entry_screen.dart';

class EnterMarksScreen extends StatefulWidget {
  final String classId;
  const EnterMarksScreen({super.key, required this.classId});

  @override
  State<EnterMarksScreen> createState() => _EnterMarksScreenState();
}

class _EnterMarksScreenState extends State<EnterMarksScreen> {
  void _startResultEntry(String studentId, String studentName, String rollNumber) {
    final TextEditingController examTypeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Exam Type"),
        content: TextField(
          controller: examTypeController,
          decoration: const InputDecoration(hintText: "e.g. Unit Test 1, Final Exam"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (examTypeController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetailedResultEntryScreen(
                    studentId: studentId,
                    studentName: studentName,
                    rollNumber: rollNumber,
                    classId: widget.classId,
                    examName: examTypeController.text.trim(),
                  ),
                ),
              );
            },
            child: const Text("Next"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Student Results"),
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.black,
            tabs: [Tab(text: "Select Student"), Tab(text: "History")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildStudentListTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: widget.classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var students = snapshot.data!.docs;

        students.sort((a, b) {
          int r1 = int.tryParse(a['rollNumber']?.toString() ?? '999') ?? 999;
          int r2 = int.tryParse(b['rollNumber']?.toString() ?? '999') ?? 999;
          return r1.compareTo(r2);
        });

        if (students.isEmpty) return const Center(child: Text("No students found in this class."));

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            var s = students[index];
            var data = s.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(child: Text(data['rollNumber']?.toString() ?? '-')),
                title: Text(data['name'] ?? 'Unknown'),
                subtitle: Text("Roll No: ${data['rollNumber']}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _startResultEntry(data['userId'], data['name'], data['rollNumber'].toString()),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    final session = Provider.of<SessionProvider>(context).currentSession;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('results_v2')
          .where('classId', isEqualTo: widget.classId)
          .where('academicSession', isEqualTo: session)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var results = snapshot.data!.docs;
        if (results.isEmpty) return const Center(child: Text("No records for this session."));

        // Sort by timestamp latest first
        results.sort((a, b) {
          Timestamp? ta = a['createdAt'] as Timestamp?;
          Timestamp? tb = b['createdAt'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            var doc = results[index];
            var data = doc.data() as Map<String, dynamic>;
            List subjects = data['subjects'] ?? [];
            DateTime? dt = (data['createdAt'] as Timestamp?)?.toDate();
            String timeStr = dt != null ? DateFormat('dd MMM | hh:mm a').format(dt) : '';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ExpansionTile(
                backgroundColor: const Color(0xFFFFFDE7), // Light schoolish yellow
                collapsedBackgroundColor: Colors.white,
                leading: const CircleAvatar(backgroundColor: Color(0xFFFFF9C4), child: Icon(Icons.person, color: Colors.orange)),
                title: Text(data['studentName'] ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Exam: ${data['examName']}\nDate: $timeStr", style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailedResultEntryScreen(
                              studentId: data['studentId'],
                              studentName: data['studentName'],
                              rollNumber: data['rollNumber'],
                              classId: data['classId'],
                              examName: data['examName'],
                              existingDocId: doc.id,
                              existingData: data,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(doc.id),
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Subject", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("Marks", style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                        for (var sub in subjects)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(sub['name'] ?? ''),
                                Text("${sub['obtained']} / ${sub['max']}"),
                              ],
                            ),
                          ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${data['totalObtained']} / ${data['totalMax']}", 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("PERCENTAGE", style: TextStyle(fontWeight: FontWeight.bold)),
                            Text("${data['percentage']}%", 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Result?"),
        content: const Text("Are you sure you want to delete this report card?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('results_v2').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
