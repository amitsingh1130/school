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

  String _getGrade(double percentage) {
    if (percentage >= 76) return "A";
    if (percentage >= 61) return "B";
    if (percentage >= 34) return "C";
    return "D";
  }

  void _calculateAndSave() async {
    double totalObtained = 0;
    double totalMax = 0;

    List<Map<String, dynamic>> finalSubjects = [];

    for (var s in subjects) {
      if (s['name'].isEmpty) continue;
      double obtained = double.tryParse(s['obtained'].toString()) ?? 0;
      double max = double.tryParse(s['max'].toString()) ?? 100;
      totalObtained += obtained;
      totalMax += max;

      double subPerc = max > 0 ? (obtained / max) * 100 : 0;
      finalSubjects.add({
        'name': s['name'],
        'max': max.toString(),
        'obtained': obtained.toString(),
        'grade': _getGrade(subPerc),
      });
    }

    double percentage = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;
    String grade = _getGrade(percentage);

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
        'subjects': finalSubjects,
        'totalObtained': totalObtained,
        'totalMax': totalMax,
        'percentage': percentage.toStringAsFixed(1),
        'grade': grade,
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
                Expanded(flex: 1, child: Text("Gr", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: subjects.length,
              itemBuilder: (context, index) {
                double obt = double.tryParse(subjects[index]['obtained'].toString()) ?? 0;
                double max = double.tryParse(subjects[index]['max'].toString()) ?? 100;
                String subGrade = _getGrade(max > 0 ? (obt / max) * 100 : 0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(flex: 1, child: Text("${index + 1}")),
                      Expanded(
                        flex: 4,
                        child: TextFormField(
                          initialValue: subjects[index]['name'],
                          onChanged: (v) => setState(() => subjects[index]['name'] = v),
                          decoration: const InputDecoration(hintText: "Subject", isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: subjects[index]['max'].toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() => subjects[index]['max'] = v),
                          decoration: const InputDecoration(hintText: "Max", isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: subjects[index]['obtained'].toString(),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => setState(() => subjects[index]['obtained'] = v),
                          decoration: const InputDecoration(hintText: "Obtained", isDense: true),
                        ),
                      ),
                      Expanded(
                        flex: 1, 
                        child: Text(subGrade, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
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
          
          // --- LIVE GRADE & SUMMARY ---
          Builder(
            builder: (context) {
              double tObt = 0; double tMax = 0;
              for (var s in subjects) {
                tObt += double.tryParse(s['obtained'].toString()) ?? 0;
                tMax += double.tryParse(s['max'].toString()) ?? 0;
              }
              double perc = tMax > 0 ? (tObt / tMax) * 100 : 0;
              String grade = _getGrade(perc);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(top: BorderSide(color: Colors.blue.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Total: ${tObt.toInt()}/${tMax.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("${perc.toStringAsFixed(1)}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("Grade: $grade", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }
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
