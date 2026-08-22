import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  String? _selectedClassForIndividual;

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _dueDateController.text = DateFormat('dd-MM-yyyy').format(picked));
    }
  }

  void _setClassFee() async {
    if (_classController.text.isEmpty || _amountController.text.isEmpty) return;
    
    final session = Provider.of<SessionProvider>(context, listen: false).currentSession;
    String cls = _classController.text.trim().toUpperCase();
    
    await FirebaseFirestore.instance.collection('class_fees').doc("${cls}_$session").set({
      'classId': cls,
      'academicSession': session,
      'amount': _amountController.text.trim(),
      'dueDate': _dueDateController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Notify ALL Students of this class directly from 'users' collection
    var usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: cls)
        .get();

    for (var doc in usersQuery.docs) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toUserId': doc['userId'], // Use the Login ID
        'title': "Fee Assigned: Class $cls",
        'message': "School fee of ₹${_amountController.text} has been assigned for session $session. Due: ${_dueDateController.text}.",
        'type': 'fee',
        'academicSession': session,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fees Assigned & All Students Notified!"), backgroundColor: Colors.green));
      _amountController.clear(); _classController.clear(); _dueDateController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Fee Management"),
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.black,
            tabs: [Tab(text: "Set Class Fee"), Tab(text: "Collect Individual")],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  const Text("Define Fee for a Whole Class", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: _classController, decoration: const InputDecoration(labelText: "Class (e.g. 10)", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Fee Amount", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _dueDateController,
                    readOnly: true,
                    onTap: () => _selectDueDate(context),
                    decoration: const InputDecoration(labelText: "Select Due Date", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _setClassFee, child: const Text("APPLY TO ALL STUDENTS")),
                ],
              ),
            ),
            _buildIndividualTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualTab() {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            Set<String> classes = {};
            for (var doc in snapshot.data!.docs) {
              classes.add(doc['classId'] ?? 'Unassigned');
            }
            List<String> sortedClasses = classes.toList()..sort();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedClassForIndividual,
                decoration: const InputDecoration(labelText: "Select Class", border: OutlineInputBorder()),
                items: sortedClasses.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                onChanged: (val) => setState(() => _selectedClassForIndividual = val),
              ),
            );
          },
        ),
        Expanded(
          child: _selectedClassForIndividual == null
              ? const Center(child: Text("Select a class to view student payments"))
              : _buildStudentListForClass(_selectedClassForIndividual!),
        ),
      ],
    );
  }

  Widget _buildStudentListForClass(String classId) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('classId', isEqualTo: classId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var students = snapshot.data!.docs;

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            var student = students[index];
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('fees').where('studentId', isEqualTo: student['userId']).where('academicSession', isEqualTo: session).snapshots(),
              builder: (context, feeSnapshot) {
                bool isPaid = feeSnapshot.hasData && feeSnapshot.data!.docs.isNotEmpty;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(student['name']),
                    subtitle: Text(isPaid ? "Paid" : "Pending"),
                    trailing: isPaid
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(onPressed: () => _markPaid(student['userId'], student['name'], session), child: const Text("Pay")),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _markPaid(String sId, String name, String session) async {
    var classFeeDoc = await FirebaseFirestore.instance.collection('class_fees').where('classId', isEqualTo: _selectedClassForIndividual).where('academicSession', isEqualTo: session).get();
    String amount = classFeeDoc.docs.isNotEmpty ? classFeeDoc.docs.first['amount'] : "0";

    String rec = "REC${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";
    await FirebaseFirestore.instance.collection('fees').add({
      'studentId': sId,
      'studentName': name,
      'amount': amount,
      'status': 'Paid',
      'receiptNo': rec,
      'academicSession': session,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Successful!")));
  }
}
