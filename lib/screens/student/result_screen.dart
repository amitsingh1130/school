import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../services/result_report_service.dart';

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

          // CONSOLIDATED REPORT DATA PREP
          List<Map<String, dynamic>> examResultsList = exams.map((e) => e.data() as Map<String, dynamic>).toList();
          // Sort by date or exam name if needed
          var firstExam = examResultsList.first;

          return Column(
            children: [
              // --- CONSOLIDATED DOWNLOAD CARD ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: InkWell(
                  onTap: () {
                    ResultReportService.generateConsolidatedReport(
                      studentName: firstExam['studentName'] ?? 'Student',
                      classId: firstExam['classId'] ?? 'N/A',
                      rollNumber: firstExam['rollNumber'] ?? 'N/A',
                      academicSession: session,
                      examResults: examResultsList,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.picture_as_pdf, color: Colors.white, size: 30),
                        SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Final Consolidated Result", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              Text("Download full session performance record", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.download, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
              
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("SUBJECT-WISE DETAILS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                    TextButton.icon(
                                      onPressed: () => ResultReportService.generateReportCard(data),
                                      icon: const Icon(Icons.print, size: 16),
                                      label: const Text("PRINT PDF", style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(flex: 3, child: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 2, child: Text("Marks", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                    Expanded(flex: 1, child: Text("Grade", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                ),
                                const Divider(),
                                for (var sub in subjects)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(flex: 3, child: Text(sub['name'] ?? '')),
                                        Expanded(flex: 2, child: Text("${sub['obtained']} / ${sub['max']}", textAlign: TextAlign.center)),
                                        Expanded(flex: 1, child: Text(sub['grade'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue), textAlign: TextAlign.right)),
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
                                if (data['grade'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("GRADE", style: TextStyle(fontWeight: FontWeight.bold)),
                                        Text("${data['grade']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
