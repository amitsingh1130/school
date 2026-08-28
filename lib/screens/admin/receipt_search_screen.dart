import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/fee_report_service.dart';

class ReceiptSearchScreen extends StatefulWidget {
  const ReceiptSearchScreen({super.key});

  @override
  State<ReceiptSearchScreen> createState() => _ReceiptSearchScreenState();
}

class _ReceiptSearchScreenState extends State<ReceiptSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundReceipt;
  String? _error;

  void _searchReceipt() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundReceipt = null;
      _error = null;
    });

    try {
      // 1. Query all fee records with this receipt number
      var snapshot = await FirebaseFirestore.instance
          .collection('fees')
          .where('receiptNo', isEqualTo: query)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _error = "No receipt found with number: $query";
          _isLoading = false;
        });
        return;
      }

      // 2. Aggregate data (since one receipt can have multiple items/docs)
      double totalAmount = 0;
      List<String> titles = [];
      var firstDoc = snapshot.docs.first.data();
      
      for (var doc in snapshot.docs) {
        var data = doc.data();
        totalAmount += double.tryParse(data['amount'].toString()) ?? 0;
        titles.add(data['feeTitle'] ?? 'Fee');
      }

      // 3. Get Student Details (Father Name, Mother Name, Reg No)
      String classId = firstDoc['classId'] ?? 'N/A';
      String fatherName = 'N/A';
      String motherName = 'N/A';
      String regNo = 'N/A';

      var studentDoc = await FirebaseFirestore.instance.collection('users').doc(firstDoc['studentId']).get();
      if (studentDoc.exists) {
        var sData = studentDoc.data()!;
        classId = sData['classId'] ?? classId;
        fatherName = sData['fatherName'] ?? 'N/A';
        motherName = sData['motherName'] ?? 'N/A';
        regNo = sData['regNo'] ?? 'N/A';
      }

      setState(() {
        _foundReceipt = {
          'receiptNo': query,
          'studentName': firstDoc['studentName'],
          'classId': classId,
          'fatherName': fatherName,
          'motherName': motherName,
          'regNo': regNo,
          'amount': totalAmount.toString(),
          'feeTitle': titles.join(", "),
          'academicSession': firstDoc['academicSession'],
          'date': firstDoc['date'],
          'collectedBy': firstDoc['collectedByName'] != null 
              ? "${firstDoc['collectedByName']} (${firstDoc['collectedByRole']})"
              : null,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Search & Re-print Receipt")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: "Enter Receipt No (e.g. REC1234)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.receipt),
                    ),
                    onSubmitted: (_) => _searchReceipt(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _searchReceipt,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(60, 55)),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (_isLoading) const CircularProgressIndicator(),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_foundReceipt != null) _buildReceiptCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Receipt Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                Text(_foundReceipt!['date'] ?? '', style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 25),
            _infoRow("Receipt No:", _foundReceipt!['receiptNo']),
            _infoRow("Student:", _foundReceipt!['studentName']),
            _infoRow("Class:", _foundReceipt!['classId']),
            _infoRow("Session:", _foundReceipt!['academicSession']),
            _infoRow("Paid For:", _foundReceipt!['feeTitle']),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Amount:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("₹${_foundReceipt!['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  FeeReportService.generateReceipt(
                    studentName: _foundReceipt!['studentName'],
                    classId: _foundReceipt!['classId'],
                    amount: _foundReceipt!['amount'],
                    receiptNo: _foundReceipt!['receiptNo'],
                    feeTitle: _foundReceipt!['feeTitle'],
                    academicSession: _foundReceipt!['academicSession'],
                    regNo: _foundReceipt!['regNo'],
                    fatherName: _foundReceipt!['fatherName'],
                    motherName: _foundReceipt!['motherName'],
                    collectedBy: _foundReceipt!['collectedBy'],
                  );
                },
                icon: const Icon(Icons.print),
                label: const Text("RE-PRINT RECEIPT"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
