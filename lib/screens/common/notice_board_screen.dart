import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NoticeBoardScreen extends StatelessWidget {
  final String userRole;
  const NoticeBoardScreen({super.key, required this.userRole});

  void _addNotice(BuildContext context) {
    final TextEditingController noticeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Post New Notice"),
        content: TextField(controller: noticeController, maxLines: 3, decoration: const InputDecoration(hintText: "Enter notice text...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (noticeController.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('notices').add({
                  'text': noticeController.text.trim(),
                  'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Post"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notice Board")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('notices').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var notices = snapshot.data!.docs;

          // Sort in memory to avoid index requirement
          notices.sort((a, b) {
            var ta = a['createdAt'] as Timestamp?;
            var tb = b['createdAt'] as Timestamp?;
            if (ta == null || tb == null) return 0;
            return tb.compareTo(ta);
          });

          if (notices.isEmpty) return const Center(child: Text("No notices yet."));

          return ListView.builder(
            itemCount: notices.length,
            itemBuilder: (context, index) {
              var data = notices[index];
              return Card(
                margin: const EdgeInsets.all(10),
                color: Colors.yellow.shade50,
                child: ListTile(
                  leading: const Icon(Icons.campaign, color: Colors.orange, size: 30),
                  title: Text(data['text'], style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(data['date'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: userRole == 'admin' 
        ? FloatingActionButton(onPressed: () => _addNotice(context), backgroundColor: const Color(0xFFFFD700), child: const Icon(Icons.add, color: Colors.black))
        : null,
    );
  }
}
