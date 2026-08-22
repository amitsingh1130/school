import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class DetailedResultEntryScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String rollNumber;
  final String classId;
  final String examName;
  final String? existingDocId;
  final Map<String, dynamic>? existingData;

  const DetailedResultEntryScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.rollNumber,
    required this.classId,
    required this.examName,
    this.existingDocId,
    this.existingData,
  });

  @override
  State<DetailedResultEntryScreen> createState() => _DetailedResultEntryScreenState();
}

class _DetailedResultEntryScreenState extends State<DetailedResultEntryScreen> {
  List<Map<String, dynamic>> subjects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingData != null) {
      subjects = List<Map<String, dynamic>>.from(widget.existingData!['subjects'] ?? []);
    } else {
      // Default subjects
      subjects = [
        {'name': 'Hindi', 'max': '100', 'obtained': ''},
        {'name': 'English', 'max': '100', 'obtained': ''},
        {'name': 'Maths', 'max': '100', 'obtained': ''},
        {'name': 'Science', 'max': '100', 'obtained': ''},
        {'name': 'Social Science', 'max': '100', 'obtained': ''},
      ];
    }
  }

  void _addSubject() {
    setState(() {
      subjects.add({'name': '', 'max': '100', 'obtained': ''});
    });
  }

  void _calculateAndSave() async {
    double totalObtained = 0;
    double totalMax = 0;

    for (var s in subjects) {
      if (s['name'].isEmpty) continue;
      double obtained = double.tryParse(s['obtained'].toString()) ?? 0;
      double max = double.tryParse(s['max'].toString()) ?? 100;
      totalObtained += obtained;
      totalMax += max;
    }

    double percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;

    setState(() => _isLoading = true);
    try {
      final session = Provider.of<SessionProvider>(context, listen: false).currentSession;
      
      Map<String, dynamic> resultData = {
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'rollNumber': widget.rollNumber,
        'classId': widget.classId,
        'academicSession': session,
        'examName': widget.examName,
        'subjects': subjects,
        'totalObtained': totalObtained,
        'totalMax': totalMax,
        'percentage': percentage.toStringAsFixed(1),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.existingDocId != null) {
        await FirebaseFirestore.instance.collection('results_v2').doc(widget.existingDocId).update(resultData);
      } else {
        resultData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('results_v2').add(resultData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Result Saved Successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.studentName} - ${widget.examName}"),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _addSubject, tooltip: "Add Subject"),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade200,
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("S.No", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 4, child: Text("Subject", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("Max", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text("Obt", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text("${index + 1}")),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          initialValue: subjects[index]['name'],
                          onChanged: (v) => subjects[index]['name'] = v,
                          decoration: const InputDecoration(hintText: "Subject", isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: subjects[index]['max'].toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => subjects[index]['max'] = v,
                          decoration: const InputDecoration(hintText: "Max", isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: subjects[index]['obtained'].toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => subjects[index]['obtained'] = v,
                          decoration: const InputDecoration(hintText: "Obtained", isDense: true),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        onPressed: () => setState(() => subjects.removeAt(index)),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _calculateAndSave, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("SAVE REPORT CARD"),
                ),
          )
        ],
      ),
    );
  }
}
