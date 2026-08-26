import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/session_provider.dart';

class FeeDefaultersScreen extends StatefulWidget {
  const FeeDefaultersScreen({super.key});

  @override
  State<FeeDefaultersScreen> createState() => _FeeDefaultersScreenState();
}

class _FeeDefaultersScreenState extends State<FeeDefaultersScreen> {
  String? _selectedClass;
  String? _selectedMonth;
  final List<String> _months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: const Text("Fee Defaulters List")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('students').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      Set<String> classes = {};
                      for (var d in snapshot.data!.docs) { classes.add(d['classId']); }
                      var sortedClasses = classes.toList()..sort();
                      return DropdownButtonFormField<String>(
                        value: _selectedClass,
                        decoration: const InputDecoration(labelText: "Class", border: OutlineInputBorder()),
                        items: sortedClasses.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                        onChanged: (v) => setState(() => _selectedClass = v),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedMonth,
                    decoration: const InputDecoration(labelText: "Month", border: OutlineInputBorder()),
                    items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) => setState(() => _selectedMonth = v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: (_selectedClass == null || _selectedMonth == null)
                ? const Center(child: Text("Select Class and Month to view defaulters"))
                : _buildDefaultersList(session),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultersList(String session) {
    String feeTitle = "Monthly Fee - $_selectedMonth";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: _selectedClass)
          .snapshots(),
      builder: (context, studentSnap) {
        if (!studentSnap.hasData) return const Center(child: CircularProgressIndicator());
        var students = studentSnap.data!.docs;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('fees')
              .where('feeTitle', isEqualTo: feeTitle)
              .where('academicSession', isEqualTo: session)
              .snapshots(),
          builder: (context, paymentSnap) {
            if (!paymentSnap.hasData) return const Center(child: CircularProgressIndicator());
            
            Set<String> paidStudentIds = paymentSnap.data!.docs
                .map((d) => (d.data() as Map<String, dynamic>)['studentId'].toString())
                .toSet();

            var defaulters = students.where((s) => !paidStudentIds.contains(s['userId'])).toList();

            // SORT BY ROLL NUMBER
            defaulters.sort((a, b) {
              int r1 = int.tryParse(a['rollNumber']?.toString() ?? '999') ?? 999;
              int r2 = int.tryParse(b['rollNumber']?.toString() ?? '999') ?? 999;
              return r1.compareTo(r2);
            });

            if (defaulters.isEmpty) {
              return const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 60),
                  SizedBox(height: 10),
                  Text("No defaulters! Everyone has paid.", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ));
            }

            return ListView.builder(
              itemCount: defaulters.length,
              itemBuilder: (context, index) {
                var s = defaulters[index].data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(s['name'][0])),
                    title: Text(s['name']),
                    subtitle: Text("Roll: ${s['rollNumber']} | Mobile: ${s['mobile'] ?? 'N/A'}"),
                    trailing: const Text("UNPAID", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
