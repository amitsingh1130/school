import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageHolidaysScreen extends StatefulWidget {
  const ManageHolidaysScreen({super.key});

  @override
  State<ManageHolidaysScreen> createState() => _ManageHolidaysScreenState();
}

class _ManageHolidaysScreenState extends State<ManageHolidaysScreen> {
  final TextEditingController _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _targetType = "All School"; // "All School", "Students Only", "Specific Class"
  String? _selectedClass;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addHoliday() async {
    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter holiday reason")));
      return;
    }
    if (_targetType == "Specific Class" && _selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a class")));
      return;
    }

    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    String reason = _reasonController.text.trim();
    String formattedDate = DateFormat('dd MMM').format(_selectedDate);

    // 1. Save Holiday Record
    // Note: If it's class specific, we store target info
    await FirebaseFirestore.instance.collection('holidays').doc(dateStr).set({
      'date': dateStr,
      'reason': reason,
      'target': _targetType,
      'targetClass': _selectedClass,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Targeted Notifications
    if (_targetType == "All School") {
      // Notify Students
      await _sendNote("student", null, "School Holiday Alert! 🎊", "School will remain closed on $formattedDate ($reason).");
      // Notify Teachers
      await _sendNote("teacher", null, "Holiday Notice for Staff 📋", "Dear Teachers, school is closed on $formattedDate ($reason).");
    } 
    else if (_targetType == "Students Only") {
      // Notify Students only
      await _sendNote("student", null, "Student Holiday Alert! 🎊", "School is closed for students on $formattedDate ($reason). Teachers to attend.");
    } 
    else if (_targetType == "Specific Class") {
      // Notify specific class students and their teacher
      await _sendNote("student", _selectedClass, "Class Holiday Alert! 🎊", "Class $_selectedClass has a holiday on $formattedDate ($reason).");
      await _sendNote("teacher", _selectedClass, "Class Holiday Notice 📋", "Your Class ($_selectedClass) has a holiday on $formattedDate ($reason).");
    }

    _reasonController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Holiday Added & Notified!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _sendNote(String role, String? classId, String title, String msg) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'title': title,
      'message': msg,
      'toRole': role,
      'toClassId': classId,
      'type': 'holiday',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage School Holidays")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Add New Holiday", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text("Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}"),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      const Text("Holiday Target:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        value: _targetType,
                        isExpanded: true,
                        items: ["All School", "Students Only", "Specific Class"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) => setState(() {
                          _targetType = v!;
                          if (v != "Specific Class") _selectedClass = null;
                        }),
                      ),
                      if (_targetType == "Specific Class") ...[
                        const SizedBox(height: 10),
                        const Text("Select Class:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('students').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const LinearProgressIndicator();
                            Set<String> classes = {};
                            for (var d in snapshot.data!.docs) { classes.add(d['classId']); }
                            return DropdownButton<String>(
                              value: _selectedClass,
                              isExpanded: true,
                              hint: const Text("Choose Class"),
                              items: classes.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                              onChanged: (v) => setState(() => _selectedClass = v),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reasonController,
                        decoration: const InputDecoration(labelText: "Reason (e.g. Diwali, Govt Order)", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: _addHoliday,
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black),
                        child: const Text("SAVE & NOTIFY ALL", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            const Text("Upcoming Holidays", style: TextStyle(fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('holidays').orderBy('date').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Text("No holidays added yet."));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    String target = data['target'] ?? "All School";
                    if (data['targetClass'] != null) target = "Class ${data['targetClass']}";
                    
                    return ListTile(
                      leading: const Icon(Icons.celebration, color: Colors.pink),
                      title: Text("${data['reason']} ($target)"),
                      subtitle: Text(data['date']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => FirebaseFirestore.instance.collection('holidays').doc(docs[index].id).delete(),
                      ),
                    );
                  },
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
