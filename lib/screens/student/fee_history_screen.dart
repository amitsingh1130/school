import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../models/user_model.dart';
import '../../services/fee_report_service.dart';

class FeeHistoryScreen extends StatelessWidget {
  final UserModel user;
  const FeeHistoryScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Fee Card"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('class_fees')
            .where('classId', isEqualTo: user.classId)
            .where('academicSession', isEqualTo: session)
            .snapshots(),
        builder: (context, structureSnap) {
          if (!structureSnap.hasData) return const Center(child: CircularProgressIndicator());
          
          var structureDocs = structureSnap.data!.docs;
          if (structureDocs.isEmpty) return const Center(child: Text("No fee structure found for your class."));

          // Flatten into all installments (Admission -> Months -> Exams)
          List<Map<String, dynamic>> allInstallments = [];
          
          // 1. Add Admission Fee first if exists
          for (var doc in structureDocs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['feeCategory'] == 'Admission Fee') {
              allInstallments.add({
                'feeTitle': data['feeTitle'] ?? data['feeCategory'],
                'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
                'dueDate': data['dueDate'],
              });
            }
          }

          // 2. Add Monthly Fees
          for (var doc in structureDocs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['feeCategory'] == 'Monthly Fee') {
              List<String> months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];
              for (var m in months) {
                allInstallments.add({
                  'feeTitle': "Monthly Fee - $m",
                  'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
                  'dueDay': data['dueDay'],
                  'month': m,
                });
              }
            }
          }

          // 3. Add Examination & Other Fees
          for (var doc in structureDocs) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['feeCategory'] != 'Admission Fee' && data['feeCategory'] != 'Monthly Fee') {
              allInstallments.add({
                'feeTitle': data['feeTitle'] ?? data['feeCategory'],
                'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
                'dueDate': data['dueDate'],
              });
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fees')
                .where('studentId', isEqualTo: user.userId)
                .where('academicSession', isEqualTo: session)
                .snapshots(),
            builder: (context, paymentSnap) {
              if (!paymentSnap.hasData) return const Center(child: CircularProgressIndicator());

              // Map payments by Title for easy lookup
              Map<String, Map<String, dynamic>> paymentsMap = {};
              for (var doc in paymentSnap.data!.docs) {
                var d = doc.data() as Map<String, dynamic>;
                String title = d['feeTitle'];
                double amt = double.tryParse(d['amount'].toString()) ?? 0.0;
                
                if (paymentsMap.containsKey(title)) {
                  paymentsMap[title]!['amount'] += amt;
                } else {
                  paymentsMap[title] = {
                    'amount': amt,
                    'date': d['date'],
                    'receiptNo': d['receiptNo'],
                  };
                }
              }

              // Update isPaid status in map
              for (var inst in allInstallments) {
                String title = inst['feeTitle'];
                double required = inst['amount'];
                double paid = paymentsMap[title]?['amount'] ?? 0.0;
                paymentsMap[title] ??= {};
                paymentsMap[title]!['isPaid'] = paid >= required;
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: allInstallments.length,
                      itemBuilder: (context, index) {
                        var inst = allInstallments[index];
                        var payInfo = paymentsMap[inst['feeTitle']];
                        bool isPaid = payInfo?['isPaid'] ?? false;

                        String subtitleText = "";
                        if (isPaid) {
                          subtitleText = "Paid ₹${payInfo!['amount'].toInt()} on ${payInfo['date']}";
                        } else {
                          String due = "";
                          if (inst['dueDate'] != null) {
                            due = "Due: ${inst['dueDate']}";
                          } else if (inst['dueDay'] != null) {
                            due = "Due: ${inst['dueDay']}th ${inst['month']}";
                          }
                          subtitleText = "${due.isNotEmpty ? '$due | ' : ''}Pending: ₹${inst['amount'].toInt()}";
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: Icon(isPaid ? Icons.check_circle : Icons.pending_actions, 
                                          color: isPaid ? Colors.green : Colors.orange),
                            title: Text(inst['feeTitle'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(subtitleText),
                            trailing: isPaid 
                                ? Text("PAID", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12))
                                : const Text("UNPAID", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        FeeReportService.generateFeeCard(
                          studentName: user.name,
                          classId: user.classId ?? 'N/A',
                          academicSession: session,
                          installments: allInstallments,
                          payments: paymentsMap,
                          regNo: user.regNo,
                          fatherName: user.fatherName,
                          motherName: user.motherName,
                        );
                      },
                      icon: const Icon(Icons.print),
                      label: const Text("PRINT FULL FEE CARD"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
