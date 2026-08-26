import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../models/user_model.dart';

class UploadHomeworkScreen extends StatefulWidget {
  final UserModel teacher;
  final bool isTab;
  const UploadHomeworkScreen({super.key, required this.teacher, this.isTab = false});

  @override
  State<UploadHomeworkScreen> createState() => _UploadHomeworkScreenState();
}

class _UploadHomeworkScreenState extends State<UploadHomeworkScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String? selectedClass;
  bool _isLoading = false;

  void _postHomework() async {
    if (_formKey.currentState!.validate() && selectedClass != null) {
      setState(() => _isLoading = true);
      try {
        final session = Provider.of<SessionProvider>(context, listen: false).currentSession;
        
        await FirebaseFirestore.instance.collection('homework').add({
          'classId': selectedClass,
          'academicSession': session,
          'subject': _subjectController.text.trim(),
          'description': _descController.text.trim(),
          'teacherId': widget.teacher.userId,
          'teacherName': widget.teacher.name,
          'teacherGender': widget.teacher.gender,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Format name for notification
        String honorific = "";
        if (widget.teacher.gender == "Male") honorific = " Sir";
        if (widget.teacher.gender == "Female") honorific = " Ma'am";
        String firstName = widget.teacher.name.split(" ").first;
        String formattedName = "$firstName$honorific";

        // Send Notification to selected class
        await FirebaseFirestore.instance.collection('notifications').add({
          'toClassId': selectedClass,
          'title': "New Homework: ${_subjectController.text.trim()}",
          'message': "Homework assigned by $formattedName. Please check the homework tab.",
          'type': 'homework',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Homework uploaded and notification sent!"), backgroundColor: Colors.green));
          _subjectController.clear();
          _descController.clear();
          setState(() { selectedClass = null; });
          if (!widget.isTab) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a class first")));
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text("Assign Homework To:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            
            // --- CLASS SELECTION DROPDOWN ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                
                Set<String> classes = {};
                for (var doc in snapshot.data!.docs) {
                  classes.add(doc['classId'] ?? 'Unassigned');
                }
                List<String> sortedClasses = classes.toList()..sort();

                return DropdownButtonFormField<String>(
                  value: selectedClass,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Select Class"),
                  items: sortedClasses.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                  onChanged: (val) => setState(() => selectedClass = val),
                  validator: (val) => val == null ? "Required" : null,
                );
              },
            ),

            const SizedBox(height: 20),
            TextFormField(
              controller: _subjectController, 
              decoration: const InputDecoration(labelText: "Subject (e.g. English)", border: OutlineInputBorder()), 
              validator: (v) => v!.isEmpty ? "Enter Subject" : null
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _descController, 
              maxLines: 5, 
              decoration: const InputDecoration(labelText: "Homework Description", border: OutlineInputBorder()), 
              validator: (v) => v!.isEmpty ? "Enter details" : null
            ),
            const SizedBox(height: 20),
            _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: _postHomework, 
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  child: const Text("SEND HOMEWORK")
                ),
          ],
        ),
      ),
    );

    if (widget.isTab) return content;

    return Scaffold(
      appBar: AppBar(title: const Text("Post Homework")),
      body: content,
    );
  }
}
