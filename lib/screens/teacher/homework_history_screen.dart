import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import 'package:intl/intl.dart';

class HomeworkHistoryScreen extends StatelessWidget {
  final String? classId;
  final String? teacherId;
  final bool isTab;
  const HomeworkHistoryScreen({super.key, this.classId, this.teacherId, this.isTab = false});

  void _editHomework(BuildContext context, String docId, String currentSubject, String currentDesc) {
    final TextEditingController subjectController = TextEditingController(text: currentSubject);
    final TextEditingController descController = TextEditingController(text: currentDesc);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Homework"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: "Subject"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('homework').doc(docId).update({
                'subject': subjectController.text.trim(),
                'description': descController.text.trim(),
              });
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  void _deleteHomework(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Homework?"),
        content: const Text("Are you sure you want to remove this homework?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('homework').doc(docId).delete();
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    Query query = FirebaseFirestore.instance.collection('homework')
        .where('academicSession', isEqualTo: session);
    
    if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    } else if (classId != null) {
      query = query.where('classId', isEqualTo: classId);
    }

    Widget body = StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No homework history found."));
        
        var docs = snapshot.data!.docs;

        docs.sort((a, b) {
          var ta = a['createdAt'] as Timestamp?;
          var tb = b['createdAt'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            DateTime? dt = (data['createdAt'] as Timestamp?)?.toDate();
            String dateStr = dt != null ? DateFormat('dd MMM yyyy').format(dt) : 'No Date';
            String timeStr = dt != null ? DateFormat('hh:mm a').format(dt) : '--:--';
            String targetClass = data['classId'] ?? 'N/A';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(data['subject'] ?? 'No Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['description'] ?? ''),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("For Class: $targetClass", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                        const SizedBox(width: 10), // Added space
                        Expanded(
                          child: Text(
                            "$dateStr | $timeStr", 
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () => _editHomework(context, doc.id, data['subject'] ?? '', data['description'] ?? ''),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _deleteHomework(context, doc.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (isTab) return body;

    return Scaffold(
      appBar: AppBar(title: Text("Homework History ($session)")),
      body: body,
    );
  }
}
