import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';

class ApplyLeaveScreen extends StatefulWidget {
  final UserModel user;
  final bool isTab;
  const ApplyLeaveScreen({super.key, required this.user, this.isTab = false});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _leaveType = "Full Day"; 
  String _halfDaySession = "First Half"; // Morning
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) _endDate = _startDate;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitLeave() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String leaveId = FirebaseFirestore.instance.collection('leaves').doc().id;
        
        await FirebaseFirestore.instance.collection('leaves').doc(leaveId).set({
          'leaveId': leaveId,
          'userId': widget.user.userId,
          'name': widget.user.name,
          'role': widget.user.role,
          'classId': widget.user.classId,
          'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
          'endDate': _leaveType == "Half Day" ? DateFormat('yyyy-MM-dd').format(_startDate) : DateFormat('yyyy-MM-dd').format(_endDate),
          'leaveType': _leaveType,
          'halfDaySession': _leaveType == "Half Day" ? _halfDaySession : "",
          'reason': _reasonController.text.trim(),
          'status': 'pending',
          'appliedAt': FieldValue.serverTimestamp(),
        });

        await _sendNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave Request Submitted!"), backgroundColor: Colors.green));
          _reasonController.clear();
          if (!widget.isTab) Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendNotifications() async {
    // Notify Management (Admin, Principal, Vice Principal)
    List<String> managementRoles = ['admin', 'principal', 'vice_principal'];
    for (String role in managementRoles) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toRole': role,
        'title': "New Leave Request",
        'message': "${widget.user.name} (${widget.user.role}) applied for ${_leaveType}.",
        'type': 'leave',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // If student applies, also notify Class Teacher
    if (widget.user.role == 'student' && widget.user.classId != null) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'toClassId': widget.user.classId,
        'toRole': 'teacher',
        'title': "Student Leave Applied",
        'message': "${widget.user.name} (Roll: ${widget.user.rollNumber}) applied for ${_leaveType}.",
        'type': 'leave',
        'createdAt': FieldValue.serverTimestamp(),
      });
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
            const Text("Leave Type", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Radio(value: "Full Day", groupValue: _leaveType, onChanged: (v) => setState(() => _leaveType = v as String)),
                const Text("Full Day"),
                const SizedBox(width: 20),
                Radio(value: "Half Day", groupValue: _leaveType, onChanged: (v) => setState(() => _leaveType = v as String)),
                const Text("Half Day"),
              ],
            ),
            const Divider(),

            if (_leaveType == "Half Day") ...[
              const Text("Select Session", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _halfDaySession,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: "First Half", child: Text("First Half (Morning)")),
                  DropdownMenuItem(value: "Second Half", child: Text("Second Half (Afternoon)")),
                ],
                onChanged: (v) => setState(() => _halfDaySession = v!),
              ),
              const SizedBox(height: 15),
            ],

            ListTile(
              title: Text(_leaveType == "Half Day" ? "Select Date" : "Start Date"),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context, true),
            ),
            if (_leaveType == "Full Day")
              ListTile(
                title: const Text("End Date"),
                subtitle: Text(DateFormat('dd MMM yyyy').format(_endDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
            
            const SizedBox(height: 20),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Reason for Leave", border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? "Please enter a reason" : null,
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submitLeave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("SUBMIT REQUEST"),
                  ),
          ],
        ),
      ),
    );

    if (widget.isTab) return content;

    return Scaffold(
      appBar: AppBar(title: const Text("Apply for Leave")),
      body: content,
    );
  }
}
