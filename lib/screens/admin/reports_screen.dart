import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionProvider>(context).currentSession;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

    return FutureBuilder<UserModel?>(
      future: PrefService().getUser(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final user = userSnap.data;
        Color themeColor = const Color(0xFFFFD700); // Default Admin Yellow
        if (user?.role == 'principal') themeColor = Colors.deepPurple;
        if (user?.role == 'vice_principal') themeColor = Colors.indigo;

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text("School Reports ($session)"),
            backgroundColor: themeColor,
            foregroundColor: user?.role == 'admin' ? Colors.black : Colors.white,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SECTION 1: GENERAL STATISTICS ---
                _sectionHeader("General Statistics"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _attendanceStatCard(
                      "Total Student Attendance Today", 
                      today, 
                      FirebaseFirestore.instance.collection('attendance').where('date', isEqualTo: today).snapshots(),
                      FirebaseFirestore.instance.collection('students').snapshots(),
                      Colors.blue,
                      isStudent: true
                    ),
                    const SizedBox(width: 10),
                    _attendanceStatCard(
                      "Total Teacher Attendance Today", 
                      today,
                      FirebaseFirestore.instance.collection('teacher_attendance').where('date', isEqualTo: today).snapshots(),
                      FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
                      Colors.purple,
                      isStudent: false
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),

                // --- SECTION 2: FINANCIAL INSIGHTS ---
                _sectionHeader("Financial Insights"),
                const SizedBox(height: 10),
                _buildFinancialSummary(session),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _feeStatCard("Today Total Fee Collection", today, themeColor == const Color(0xFFFFD700) ? Colors.green : themeColor),
                    const SizedBox(width: 10),
                    _feeStatCard("Monthly Total Fee Collection", currentMonth, themeColor == const Color(0xFFFFD700) ? Colors.teal : themeColor.withValues(alpha: 0.8)),
                  ],
                ),
                const SizedBox(height: 10),
                _feeStatCard("Year Total Fee Collection ($session)", session, themeColor == const Color(0xFFFFD700) ? Colors.indigo : themeColor, isFullWidth: true),

                const SizedBox(height: 30),

                // --- SECTION 3: ACTIVITY OVERVIEW ---
                _sectionHeader("Activity Overview"),
                const SizedBox(height: 10),
                _activityCard("Homeworks Today", today, Icons.book, Colors.orange),
                const SizedBox(height: 10),
                _leaveCard("Total Pending Leaves", Colors.redAccent),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title, 
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)
    );
  }

  Widget _attendanceStatCard(String title, String date, Stream<QuerySnapshot> attStream, Stream<QuerySnapshot> totalStream, Color color, {required bool isStudent}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, spreadRadius: 1)],
        ),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: totalStream,
              builder: (context, totalSnapshot) {
                int total = totalSnapshot.hasData ? totalSnapshot.data!.docs.length : 0;
                return StreamBuilder<QuerySnapshot>(
                  stream: attStream,
                  builder: (context, attSnapshot) {
                    int present = 0;
                    if (attSnapshot.hasData) {
                      if (isStudent) {
                        for (var doc in attSnapshot.data!.docs) {
                          Map<String, dynamic> records = doc['records'] ?? {};
                          present += records.values.where((v) => 
                            v == 'PRESENT' || v == 'HALF DAY' || v == 'ON LEAVE' || v == 'P' || v == true
                          ).length;
                        }
                      } else {
                        // Filter strictly for PRESENT status for teachers
                        for (var doc in attSnapshot.data!.docs) {
                          String status = (doc['status'] ?? '').toString().toLowerCase();
                          if (status == 'present' || status == 'p') {
                            present++;
                          }
                        }
                      }
                    }
                    return Text(
                      "$present / $total", 
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeStatCard(String title, String filter, Color color, {bool isFullWidth = false}) {
    Widget card = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fees').snapshots(),
      builder: (context, snapshot) {
        double total = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String date = data['date'] ?? '';
            String session = data['academicSession'] ?? '';
            
            // Filter logic: date, current month (yyyy-MM), or session
            if (date == filter || date.contains(filter) || session == filter) {
              total += double.tryParse(data['amount'].toString()) ?? 0;
            }
          }
        }
        return Container(
          padding: const EdgeInsets.all(15),
          width: isFullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: isFullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                "₹${total.toInt()}", 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)
              ),
            ],
          ),
        );
      },
    );

    return isFullWidth ? card : Expanded(child: card);
  }

  Widget _activityCard(String title, String date, IconData icon, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('homework').where('date', isEqualTo: date).snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
              Text("$count", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      },
    );
  }

  Widget _leaveCard(String title, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('leaves').where('status', isEqualTo: 'pending').snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("$count", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialSummary(String session) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('class_fees').where('academicSession', isEqualTo: session).snapshots(),
      builder: (context, structureSnap) {
        if (!structureSnap.hasData) return const LinearProgressIndicator();

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('students').snapshots(),
          builder: (context, studentSnap) {
            if (!studentSnap.hasData) return const SizedBox.shrink();

            // Calculate Expected Total
            double expectedTotal = 0;
            Map<String, int> classCounts = {};
            for (var doc in studentSnap.data!.docs) {
              String cls = doc['classId'] ?? '';
              classCounts[cls] = (classCounts[cls] ?? 0) + 1;
            }

            for (var doc in structureSnap.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              double amt = double.tryParse(data['amount'].toString()) ?? 0;
              int count = classCounts[data['classId']] ?? 0;
              
              if (data['feeCategory'] == 'Monthly Fee') {
                expectedTotal += (amt * count * 12); // Assume 12 months for year summary
              } else {
                expectedTotal += (amt * count);
              }
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('fees').where('academicSession', isEqualTo: session).snapshots(),
              builder: (context, paymentSnap) {
                double collectedTotal = 0;
                if (paymentSnap.hasData) {
                  for (var doc in paymentSnap.data!.docs) {
                    collectedTotal += double.tryParse(doc['amount'].toString()) ?? 0;
                  }
                }

                double balance = expectedTotal - collectedTotal;

                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      _summaryRow("Expected Total (Annual)", expectedTotal, Colors.blue),
                      const Divider(),
                      _summaryRow("Total Collected", collectedTotal, Colors.green),
                      const Divider(),
                      _summaryRow("Balance Pending", balance, Colors.red),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _summaryRow(String label, double value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        Text("₹${value.toInt()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }
}
