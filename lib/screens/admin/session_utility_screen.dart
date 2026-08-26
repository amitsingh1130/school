import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SessionUtilityScreen extends StatefulWidget {
  const SessionUtilityScreen({super.key});

  @override
  State<SessionUtilityScreen> createState() => _SessionUtilityScreenState();
}

class _SessionUtilityScreenState extends State<SessionUtilityScreen> {
  String? _sourceClass;
  String? _targetClass;
  bool _isProcessing = false;

  void _bulkPromote() async {
    if (_sourceClass == null || _targetClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select source and target classes")));
      return;
    }

    if (_sourceClass == _targetClass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Source and Target class cannot be same")));
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Promotion?"),
        content: Text("All students of Class $_sourceClass will be moved to Class $_targetClass. This action is permanent."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("YES, PROMOTE")),
        ],
      ),
    );

    if (!confirm) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Get Students from 'students' collection
      var studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('classId', isEqualTo: _sourceClass)
          .get();

      // 2. Get Students from 'users' collection (for login consistency)
      var usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: _sourceClass)
          .get();

      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var doc in studentsSnap.docs) {
        batch.update(doc.reference, {'classId': _targetClass});
      }
      for (var doc in usersSnap.docs) {
        batch.update(doc.reference, {'classId': _targetClass});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Class $_sourceClass successfully promoted to $_targetClass!"), backgroundColor: Colors.green));
        setState(() {
          _sourceClass = null;
          _targetClass = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Session Utility Tool")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Card(
              color: Color(0xFFE3F2FD),
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(child: Text("Use this tool at the start of a new session to promote students to next classes.", style: TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("Bulk Promote Students", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('students').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                Set<String> classes = {};
                for (var d in snapshot.data!.docs) { classes.add(d['classId']); }
                var sortedClasses = classes.toList()..sort();

                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _sourceClass,
                      decoration: const InputDecoration(labelText: "Current Class (Source)", border: OutlineInputBorder()),
                      items: sortedClasses.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                      onChanged: (v) => setState(() => _sourceClass = v),
                    ),
                    const SizedBox(height: 15),
                    const Icon(Icons.arrow_downward, color: Colors.grey),
                    const SizedBox(height: 15),
                    TextField(
                      onChanged: (v) => _targetClass = v.toUpperCase(),
                      decoration: const InputDecoration(labelText: "New Class (Target)", border: OutlineInputBorder(), hintText: "e.g. 10-B"),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 30),
            _isProcessing 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  onPressed: _bulkPromote, 
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text("EXECUTE BULK PROMOTION"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55)
                  ),
                ),
            
            const Divider(height: 50),
            const Text("Quick Class Teacher Switch", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildTeacherList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var teachers = snapshot.data!.docs;
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: teachers.length,
          itemBuilder: (context, index) {
            var t = teachers[index].data() as Map<String, dynamic>;
            return ListTile(
              title: Text(t['name']),
              subtitle: Text("Current Class: ${t['classId'] ?? 'None'}"),
              trailing: ElevatedButton(
                onPressed: () => _showUpdateTeacherClassDialog(teachers[index].id, t['name'], t['classId']),
                child: const Text("Change"),
              ),
            );
          },
        );
      },
    );
  }

  void _showUpdateTeacherClassDialog(String docId, String name, String? currentClass) {
    final TextEditingController classController = TextEditingController(text: currentClass);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Assign Class: $name"),
        content: TextField(
          controller: classController,
          decoration: const InputDecoration(labelText: "New Class ID", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('users').doc(docId).update({
                'classId': classController.text.trim().toUpperCase()
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}
