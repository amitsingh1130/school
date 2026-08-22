import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class StudentResultScreen extends StatelessWidget {
  final String studentId;
  const StudentResultScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: Text("My Result ($session)")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('results_v2')
            .where('studentId', isEqualTo: studentId)
            .where('academicSession', isEqualTo: session)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No results published yet for this session."));
          }
          
          var exams = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exams.length,
            itemBuilder: (context, index) {
              var data = exams[index].data() as Map<String, dynamic>;
              List subjects = data['subjects'] ?? [];

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFFFFF9C4), child: Icon(Icons.assessment, color: Colors.orange)),
                  title: Text(data['examName'] ?? 'Exam', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Total: ${data['totalObtained']}/${data['totalMax']} | Percentage: ${data['percentage']}%"),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
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
                                  Text(sub['name']),
                                  Text("${sub['obtained']} / ${sub['max']}"),
                                ],
                              ),
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
                              Text("${data['totalObtained']} / ${data['totalMax']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
      ),
    );
  }
}
