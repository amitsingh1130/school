import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(title: Text("School Reports ($session)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("General Statistics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                _reportCard(context, "Total Students", "students", Icons.people, Colors.blue),
                const SizedBox(width: 10),
                _reportCard(context, "Total Teachers", "users", Icons.school, Colors.purple, filter: 'teacher'),
              ],
            ),
            const SizedBox(height: 25),
            const Text("Financial Insights", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _feeReportCard(session),
            const SizedBox(height: 25),
            const Text("Activity Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _activityCard("Homeworks Today", "homework", Icons.book, Colors.orange, session: session, todayOnly: true),
            _activityCard("Total Homeworks", "homework", Icons.book, Colors.brown, session: session),
            _activityCard("Leave Requests", "leaves", Icons.exit_to_app, Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(BuildContext context, String title, String collection, IconData icon, Color color, {String? filter}) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: filter != null 
            ? FirebaseFirestore.instance.collection(collection).where('role', isEqualTo: filter).snapshots()
            : FirebaseFirestore.instance.collection(collection).snapshots(),
        builder: (context, snapshot) {
          int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                  Text("$count", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _feeReportCard(String session) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fees').where('academicSession', isEqualTo: session).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }

        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              if (data.containsKey('amount')) {
                total += double.tryParse(data['amount'].toString()) ?? 0.0;
              }
            } catch (e) { /* ignore */ }
          }
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 35),
              const SizedBox(height: 10),
              const Text("Total Fee Collection", style: TextStyle(color: Colors.white70)),
              Text("₹${total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }

  Widget _activityCard(String title, String coll, IconData icon, Color color, {String? session, bool todayOnly = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(coll).snapshots(),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          var docs = snapshot.data!.docs;
          if (coll == 'homework' && session != null) {
            String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
            count = docs.where((d) {
              try {
                var data = d.data() as Map<String, dynamic>;
                bool sMatch = data['academicSession'] == session;
                bool tMatch = data['date'] != null && data['date'].toString().contains(today);
                return todayOnly ? (sMatch && tMatch) : sMatch;
              } catch (e) { return false; }
            }).length;
          } else {
            count = docs.length;
          }
        }
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(icon, color: color),
            title: Text(title, style: const TextStyle(fontSize: 14)),
            trailing: Text("$count", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
