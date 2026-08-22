import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FeeHistoryScreen extends StatelessWidget {
  final String studentId;
  const FeeHistoryScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Fee History")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fees').where('studentId', isEqualTo: studentId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var history = snapshot.data!.docs;
          if (history.isEmpty) return const Center(child: Text("No payment history found."));

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              var data = history[index].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.receipt, color: Colors.green),
                  title: Text("Amount: ₹${data['amount']}"),
                  subtitle: Text("Date: ${data['date'].toString().substring(0, 10)}\nReceipt: ${data['receiptNo']}"),
                  trailing: const Chip(label: Text("PAID", style: TextStyle(fontSize: 10)), backgroundColor: Colors.greenAccent),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
