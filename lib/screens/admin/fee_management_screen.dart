import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';
import '../../services/fee_report_service.dart';
import 'fee_defaulters_screen.dart';
import 'receipt_search_screen.dart'; // Import the new screen

class FeeManagementScreen extends StatefulWidget {
  const FeeManagementScreen({super.key});

  @override
  State<FeeManagementScreen> createState() => _FeeManagementScreenState();
}

class _FeeManagementScreenState extends State<FeeManagementScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _dueDayController = TextEditingController(text: "10"); 
  final TextEditingController _remarkController = TextEditingController(); // NEW: For specific exam name
  String? _selectedCategory; 
  final List<String> _categories = ["Admission Fee", "Monthly Fee", "Examination Fee", "Other"];
  String? _selectedClassForIndividual;

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  void _setClassFee() async {
    if (_classController.text.isEmpty || _amountController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (_selectedCategory != "Monthly Fee" && _dueDateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Due Date")));
      return;
    }
    
    final session = Provider.of<SessionProvider>(context, listen: false).currentSession;
    String cls = _classController.text.trim().toUpperCase();
    String remark = _remarkController.text.trim();
    String title = remark.isEmpty ? _selectedCategory! : "${_selectedCategory!} ($remark)";
    
    // Unique ID: Monthly is one per class, others can be multiple based on date/remark
    String feeId = _selectedCategory == "Monthly Fee" 
        ? "${cls}_Monthly_Fee_$session"
        : "${cls}_${_selectedCategory!.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}_$session";

    Map<String, dynamic> feeData = {
      'feeId': feeId,
      'classId': cls,
      'feeCategory': _selectedCategory,
      'feeTitle': title, // Full title for notification and tracking
      'academicSession': session,
      'amount': _amountController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (_selectedCategory == "Monthly Fee") {
      // Use the custom due day entered by admin
      feeData['dueDay'] = _dueDayController.text.trim(); 
    } else {
      feeData['dueDate'] = _dueDateController.text.trim();
    }

    await FirebaseFirestore.instance.collection('class_fees').doc(feeId).set(feeData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fee Category Saved Successfully!"), backgroundColor: Colors.green));
      _amountController.clear(); _dueDateController.clear(); _remarkController.clear();
      setState(() => _selectedCategory = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Fee Management"),
          actions: [
            IconButton(
              icon: const Icon(Icons.receipt, color: Colors.black),
              tooltip: "Search Receipt",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptSearchScreen())),
            ),
            IconButton(
              icon: const Icon(Icons.person_search, color: Colors.black),
              tooltip: "Defaulters List",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FeeDefaultersScreen())),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Colors.black,
            tabs: [Tab(text: "Set Fee Structure"), Tab(text: "Collect Individual")],
          ),
        ),
        body: TabBarView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  const Text("Define Fee Category for Class", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(controller: _classController, decoration: const InputDecoration(labelText: "Class (e.g. 10)", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: "Fee Category", border: OutlineInputBorder()),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v),
                  ),
                  const SizedBox(height: 10),

                  TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount", border: OutlineInputBorder())),
                  const SizedBox(height: 10),

                  if (_selectedCategory != "Monthly Fee") ...[
                    TextField(
                      controller: _remarkController,
                      decoration: const InputDecoration(labelText: "Remark/Exam Name (e.g. Term 1, Annual)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _dueDateController,
                      readOnly: true,
                      onTap: () => _selectDueDate(context),
                      decoration: const InputDecoration(labelText: "Due Date", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                    ),
                  ],
                  
                  if (_selectedCategory == "Monthly Fee")
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _dueDayController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Due Day of Month (e.g. 5, 10, 15)",
                              border: OutlineInputBorder(),
                              helperText: "Notification will be sent on this day every month",
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),
                  ElevatedButton(onPressed: _setClassFee, child: const Text("SAVE TO STRUCTURE")),
                  const Divider(height: 40),
                  const Text("Current Structure", style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildCurrentStructureList(),
                ],
              ),
            ),
            _buildIndividualTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStructureList() {
    final session = Provider.of<SessionProvider>(context).currentSession;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('class_fees').where('academicSession', isEqualTo: session).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
        
        var docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Center(child: Text("No fee structure found for session $session", style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String displayTitle = data['feeTitle'] ?? data['feeCategory'] ?? "Fee";
            String dueInfo = data['feeCategory'] == "Monthly Fee" ? "Every ${data['dueDay'] ?? '10'}th" : (data['dueDate'] ?? "N/A");
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text("$displayTitle (Class ${data['classId']})", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("₹${data['amount']} | Due: $dueInfo"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => FirebaseFirestore.instance.collection('class_fees').doc(docs[index].id).delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentListForClass(String classId) {
    final session = Provider.of<SessionProvider>(context).currentSession;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').where('classId', isEqualTo: classId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var students = snapshot.data!.docs;

        // SORT BY ROLL NUMBER
        students.sort((a, b) {
          int r1 = int.tryParse(a['rollNumber']?.toString() ?? '999') ?? 999;
          int r2 = int.tryParse(b['rollNumber']?.toString() ?? '999') ?? 999;
          return r1.compareTo(r2);
        });

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            var student = students[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(student['name']),
                subtitle: const Text("Tap to manage payments"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showInstallmentsDialog(student.data() as Map<String, dynamic>, classId, session),
              ),
            );
          },
        );
      },
    );
  }

  void _showInstallmentsDialog(Map<String, dynamic> studentData, String classId, String session) {
    String sId = studentData['userId'];
    String name = studentData['name'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: DraggableScrollableSheet(
          initialChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print, color: Colors.green),
                          tooltip: "Print Fee Card",
                          onPressed: () => _printStudentFeeCard(studentData, classId, session),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _payCustomAmountDialog(studentData, classId, session),
                          icon: const Icon(Icons.add_card, size: 16),
                          label: const Text("Pay Custom"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: Colors.blue,
                indicatorColor: Colors.blue,
                tabs: [Tab(text: "Installments"), Tab(text: "Payment History")],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildInstallmentsList(sId, classId, session, scrollController),
                    _buildPaymentHistoryList(sId, session, scrollController),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallmentsList(String sId, String classId, String session, ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('class_fees').where('classId', isEqualTo: classId).where('academicSession', isEqualTo: session).snapshots(),
      builder: (context, structureSnap) {
        if (structureSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        var structureDocs = structureSnap.data?.docs ?? [];
        if (structureDocs.isEmpty) return const Center(child: Text("No fee structure defined for this class."));

        List<Map<String, dynamic>> allDueFees = [];
        for (var doc in structureDocs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['feeCategory'] == 'Monthly Fee') {
            List<String> months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];
            for (var m in months) {
              allDueFees.add({
                'feeCategory': 'Monthly Fee',
                'feeTitle': "Monthly Fee - $m",
                'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
                'dueDay': data['dueDay'],
                'month': m,
              });
            }
          } else {
            allDueFees.add({
              'feeCategory': data['feeCategory'],
              'feeTitle': data['feeTitle'],
              'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
              'dueDate': data['dueDate'],
            });
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('fees').where('studentId', isEqualTo: sId).where('academicSession', isEqualTo: session).snapshots(),
          builder: (context, paymentSnap) {
            Map<String, double> paidMap = {};
            if (paymentSnap.hasData) {
              for (var doc in paymentSnap.data!.docs) {
                String title = doc['feeTitle'];
                double amt = double.tryParse(doc['amount'].toString()) ?? 0.0;
                paidMap[title] = (paidMap[title] ?? 0) + amt;
              }
            }

            return ListView.builder(
              controller: scrollController,
              itemCount: allDueFees.length,
              itemBuilder: (context, index) {
                var f = allDueFees[index];
                double balance = f['amount'] - (paidMap[f['feeTitle']] ?? 0.0);
                bool isPaid = balance <= 0;

                String due = "";
                if (f['dueDate'] != null) {
                  due = "Due: ${f['dueDate']}";
                } else if (f['dueDay'] != null) {
                  due = "Due: ${f['dueDay']}th ${f['month']}";
                }

                return ListTile(
                  title: Text(f['feeTitle']),
                  subtitle: Text("₹${f['amount'].toInt()}${due.isNotEmpty ? ' | $due' : ''}"),
                  trailing: isPaid ? const Icon(Icons.check_circle, color: Colors.green) : Text("₹${balance.toInt()} pending", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentHistoryList(String sId, String session, ScrollController scrollController) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('fees')
          .where('studentId', isEqualTo: sId)
          .where('academicSession', isEqualTo: session)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        var docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No payment history found."));

        // Sort in memory to avoid needing a composite index
        docs.sort((a, b) {
          var ta = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          var tb = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        return ListView.builder(
          controller: scrollController,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.receipt_long, color: Colors.white, size: 20)),
                title: Text(data['feeTitle']),
                subtitle: Text("Date: ${data['date']} | Receipt: ${data['receiptNo']}"),
                trailing: Text("₹${data['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          },
        );
      },
    );
  }

  void _payCustomAmountDialog(Map<String, dynamic> studentData, String classId, String session) {
    final TextEditingController customAmountController = TextEditingController();
    String? selectedCategory = "Monthly Fee"; // Default to Monthly

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Receive Payment"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(labelText: "Select Fee Category", border: OutlineInputBorder()),
                items: ["Admission Fee", "Monthly Fee", "Examination Fee"].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDialogState(() => selectedCategory = v),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: customAmountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount Received (₹)", border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                double amt = double.tryParse(customAmountController.text) ?? 0;
                if (amt <= 0) return;
                Navigator.pop(ctx);
                _processSmartPayment(studentData, classId, session, amt, selectedCategory ?? "Monthly Fee");
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  void _processSmartPayment(Map<String, dynamic> studentData, String classId, String session, double receivedAmount, String initialCategory) async {
    String sId = studentData['userId'];
    String name = studentData['name'];
    // 1. Get Fee Structure
    var structureSnap = await FirebaseFirestore.instance.collection('class_fees')
        .where('classId', isEqualTo: classId)
        .where('academicSession', isEqualTo: session)
        .get();

    // 2. Build Ordered List based on priority
    List<Map<String, dynamic>> allDueFees = [];

    // Priority 1: The Selected Category
    for (var doc in structureSnap.docs) {
      var data = doc.data();
      if (data['feeCategory'] == initialCategory) {
        if (initialCategory == 'Monthly Fee') {
          List<String> months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];
          for (var m in months) {
            allDueFees.add({'feeTitle': "Monthly Fee - $m", 'amount': double.tryParse(data['amount'].toString()) ?? 0.0});
          }
        } else {
          allDueFees.add({'feeTitle': data['feeTitle'] ?? data['feeCategory'], 'amount': double.tryParse(data['amount'].toString()) ?? 0.0});
        }
      }
    }

    // Priority 2: Monthly Fee (if not already prioritized)
    if (initialCategory != 'Monthly Fee') {
      for (var doc in structureSnap.docs) {
        var data = doc.data();
        if (data['feeCategory'] == 'Monthly Fee') {
          List<String> months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];
          for (var m in months) {
            allDueFees.add({'feeTitle': "Monthly Fee - $m", 'amount': double.tryParse(data['amount'].toString()) ?? 0.0});
          }
        }
      }
    }

    // Priority 3: Everything else
    for (var doc in structureSnap.docs) {
      var data = doc.data();
      String cat = data['feeCategory'];
      if (cat != initialCategory && cat != 'Monthly Fee') {
        allDueFees.add({'feeTitle': data['feeTitle'] ?? data['feeCategory'], 'amount': double.tryParse(data['amount'].toString()) ?? 0.0});
      }
    }
    
    // Add special case for Admission Fee if not handled yet (e.g. if Exams prioritized)
    if (initialCategory != 'Admission Fee' && initialCategory != 'Monthly Fee') {
       for (var doc in structureSnap.docs) {
          var data = doc.data();
          if (data['feeCategory'] == 'Admission Fee') {
            // Check if already in list to avoid duplicates
            if (!allDueFees.any((f) => f['feeTitle'] == (data['feeTitle'] ?? data['feeCategory']))) {
               allDueFees.insert(0, {'feeTitle': data['feeTitle'] ?? data['feeCategory'], 'amount': double.tryParse(data['amount'].toString()) ?? 0.0});
            }
          }
       }
    }

    // 3. Get existing payments to find current balance for each
    var paymentSnap = await FirebaseFirestore.instance.collection('fees')
        .where('studentId', isEqualTo: sId)
        .where('academicSession', isEqualTo: session)
        .get();

    Map<String, double> paidMap = {};
    for (var doc in paymentSnap.docs) {
      String title = doc['feeTitle'];
      double amt = double.tryParse(doc['amount'].toString()) ?? 0.0;
      paidMap[title] = (paidMap[title] ?? 0) + amt;
    }

    // 4. Distribute received amount
    double remainingAmount = receivedAmount;
    String receiptNo = "REC${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";
    String itemsPaid = "";

    for (var fee in allDueFees) {
      if (remainingAmount <= 0) break;

      double required = fee['amount'];
      double alreadyPaid = paidMap[fee['feeTitle']] ?? 0.0;
      double balanceNeeded = required - alreadyPaid;

      if (balanceNeeded > 0) {
        double paymentForThisFee = remainingAmount >= balanceNeeded ? balanceNeeded : remainingAmount;
        
        await FirebaseFirestore.instance.collection('fees').add({
          'studentId': sId,
          'studentName': name,
          'classId': classId, // Added for receipt search/reprint
          'feeTitle': fee['feeTitle'],
          'amount': paymentForThisFee.toString(),
          'receiptNo': receiptNo,
          'academicSession': session,
          'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
        });

        itemsPaid += (itemsPaid.isEmpty ? "" : ", ") + fee['feeTitle'];
        remainingAmount -= paymentForThisFee;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully adjusted ₹$receivedAmount for $name"), backgroundColor: Colors.green));
      
      // Show Receipt Option
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Payment Successful"),
          content: Text("₹$receivedAmount has been received and adjusted for: $itemsPaid"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                FeeReportService.generateReceipt(
                  studentName: name,
                  classId: classId,
                  amount: receivedAmount.toString(),
                  receiptNo: receiptNo,
                  feeTitle: itemsPaid,
                  academicSession: session,
                  regNo: studentData['regNo'],
                  fatherName: studentData['fatherName'],
                  motherName: studentData['motherName'],
                );
              },
              icon: const Icon(Icons.print),
              label: const Text("PRINT RECEIPT"),
            ),
          ],
        ),
      );
    }
  }

  void _markPaid(String sId, String name, String classId, String title, String amount, String session, {String? regNo, String? fatherName, String? motherName}) async {
    String rec = "REC${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}";
    await FirebaseFirestore.instance.collection('fees').add({
      'studentId': sId,
      'studentName': name,
      'classId': classId,
      'feeTitle': title,
      'amount': amount,
      'status': 'Paid',
      'receiptNo': rec,
      'academicSession': session,
      'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Successful for $title!")));
  }

  void _printStudentFeeCard(Map<String, dynamic> studentData, String classId, String session) async {
    String sId = studentData['userId'];
    String name = studentData['name'];
    // 1. Get Structure
    var structureSnap = await FirebaseFirestore.instance.collection('class_fees')
        .where('classId', isEqualTo: classId)
        .where('academicSession', isEqualTo: session)
        .get();

    List<Map<String, dynamic>> installments = [];
    for (var doc in structureSnap.docs) {
      var data = doc.data();
      if (data['feeCategory'] == 'Monthly Fee') {
        List<String> months = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];
        for (var m in months) {
          installments.add({
            'feeTitle': "Monthly Fee - $m",
            'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
            'dueDay': data['dueDay'],
            'month': m,
          });
        }
      } else {
        installments.add({
          'feeTitle': data['feeTitle'] ?? data['feeCategory'],
          'amount': double.tryParse(data['amount'].toString()) ?? 0.0,
          'dueDate': data['dueDate'],
        });
      }
    }

    // 2. Get Payments
    var paymentSnap = await FirebaseFirestore.instance.collection('fees')
        .where('studentId', isEqualTo: sId)
        .where('academicSession', isEqualTo: session)
        .get();

    Map<String, Map<String, dynamic>> paymentsMap = {};
    for (var doc in paymentSnap.docs) {
      var d = doc.data();
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

    for (var inst in installments) {
      String title = inst['feeTitle'];
      double required = inst['amount'];
      double paid = paymentsMap[title]?['amount'] ?? 0.0;
      paymentsMap[title] ??= {};
      paymentsMap[title]!['isPaid'] = paid >= required;
    }

    // 3. Generate PDF
    await FeeReportService.generateFeeCard(
      studentName: name,
      classId: classId,
      academicSession: session,
      installments: installments,
      payments: paymentsMap,
      regNo: studentData['regNo'],
      fatherName: studentData['fatherName'],
      motherName: studentData['motherName'],
    );
  }

  Widget _buildIndividualTab() {
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'student').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const LinearProgressIndicator();
            Set<String> classes = {};
            for (var doc in snapshot.data!.docs) {
              classes.add(doc['classId'] ?? 'Unassigned');
            }
            List<String> sortedClasses = classes.toList()..sort();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedClassForIndividual,
                decoration: const InputDecoration(labelText: "Select Class", border: OutlineInputBorder()),
                items: sortedClasses.map((c) => DropdownMenuItem(value: c, child: Text("Class $c"))).toList(),
                onChanged: (val) => setState(() => _selectedClassForIndividual = val),
              ),
            );
          },
        ),
        Expanded(
          child: _selectedClassForIndividual == null
              ? const Center(child: Text("Select a class to view student payments"))
              : _buildStudentListForClass(_selectedClassForIndividual!),
        ),
      ],
    );
  }
}
