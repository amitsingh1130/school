import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/session_provider.dart';

class AddTimetableScreen extends StatefulWidget {
  final String? timetableDocId;
  final Map<String, dynamic>? currentData;
  final String? initialClass;
  final String? initialSlot;
  final String? initialDay;

  const AddTimetableScreen({
    super.key, 
    this.timetableDocId, 
    this.currentData,
    this.initialClass,
    this.initialSlot,
    this.initialDay,
  });

  @override
  State<AddTimetableScreen> createState() => _AddTimetableScreenState();
}

class _AddTimetableScreenState extends State<AddTimetableScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedTeacherId;
  String? selectedDay;
  String? selectedPeriod;
  String? startTime; 
  String? endTime;

  final TextEditingController _classController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  bool _isLoading = false;

  final List<String> days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  final List<String> periods = [
    "PRAYER",
    "1st Subject",
    "2nd Subject",
    "3rd Subject",
    "4th Subject",
    "LUNCH",
    "5th Subject",
    "6th Subject",
    "7th Subject",
  ];

  @override
  void initState() {
    super.initState();
    if (widget.currentData != null) {
      var d = widget.currentData!;
      selectedTeacherId = d['teacherId'];
      selectedDay = d['day'];
      selectedPeriod = d['period'];
      
      String fullTime = d['time'] ?? '';
      if (fullTime.contains(" - ")) {
        startTime = fullTime.split(" - ")[0];
        endTime = fullTime.split(" - ")[1];
      } else {
        startTime = fullTime;
      }
      
      _startTimeController.text = startTime ?? '';
      _endTimeController.text = endTime ?? '';
      _classController.text = d['classId'] ?? '';
      _subjectController.text = d['subject'] ?? '';
    } else {
      selectedDay = widget.initialDay ?? "Monday";
      selectedPeriod = widget.initialSlot;
      _classController.text = widget.initialClass ?? '';
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked.format(context);
          _startTimeController.text = startTime!;
        } else {
          endTime = picked.format(context);
          _endTimeController.text = endTime!;
        }
      });
    }
  }

  void _saveTimetable() async {
    bool isSpecial = selectedPeriod == "PRAYER" || selectedPeriod == "LUNCH";
    
    // Custom validation logic
    bool isTeacherValid = isSpecial || selectedTeacherId != null;
    bool isSubjectValid = isSpecial || _subjectController.text.trim().isNotEmpty;
    bool isTimeValid = startTime != null && endTime != null;

    if (_formKey.currentState!.validate() && isTeacherValid && isSubjectValid && isTimeValid) {
      setState(() => _isLoading = true);
      try {
        final session = Provider.of<SessionProvider>(context, listen: false).currentSession;
        Map<String, dynamic> data = {
          'teacherId': isSpecial ? 'SCHOOL' : selectedTeacherId,
          'day': selectedDay,
          'period': selectedPeriod,
          'time': "$startTime - $endTime", 
          'classId': isSpecial ? 'ALL' : _classController.text.trim().toUpperCase(),
          'subject': isSpecial ? selectedPeriod : _subjectController.text.trim(),
          'academicSession': session,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (widget.timetableDocId != null) {
          await FirebaseFirestore.instance.collection('timetable').doc(widget.timetableDocId).update(data);
        } else {
          data['createdAt'] = FieldValue.serverTimestamp();
          await FirebaseFirestore.instance.collection('timetable').add(data);
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Timetable Saved Successfully!")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
    }
  }

  void _deleteTimetable() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: const Text("Are you sure you want to remove this period from the timetable?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isLoading = true);
              await FirebaseFirestore.instance.collection('timetable').doc(widget.timetableDocId).delete();
              if (mounted) {
                Navigator.pop(ctx); 
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entry Deleted")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSpecial = selectedPeriod == "PRAYER" || selectedPeriod == "LUNCH";

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.timetableDocId == null ? "Add Schedule" : "Edit Schedule"),
        actions: [
          if (widget.timetableDocId != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteTimetable,
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (!isSpecial) ...[
                const Text("Class ID:", style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(controller: _classController, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "e.g. 10-A")),
                const SizedBox(height: 20),
              ],
              
              if (!isSpecial) ...[
                const Text("Select Teacher:", style: TextStyle(fontWeight: FontWeight.bold)),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'teacher').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    var teachers = snapshot.data!.docs;
                    return DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedTeacherId,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      hint: const Text("Choose Teacher"),
                      items: teachers.map((t) => DropdownMenuItem(value: t['userId'].toString(), child: Text(t['name']))).toList(),
                      onChanged: (val) => setState(() => selectedTeacherId = val),
                      validator: (val) => (!isSpecial && val == null) ? "Required" : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
              
              const Text("Select Day:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: selectedDay,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (val) => setState(() => selectedDay = val),
              ),
              const SizedBox(height: 20),

              const Text("Select Period Slot:", style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButtonFormField<String>(
                value: selectedPeriod,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text("Choose Period Name"),
                items: periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) {
                  setState(() {
                    selectedPeriod = val;
                    if (isSpecial) {
                      selectedTeacherId = null;
                      _subjectController.clear();
                      _classController.clear();
                    }
                  });
                },
                validator: (val) => val == null ? "Required" : null,
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Start Time:", style: TextStyle(fontWeight: FontWeight.bold)),
                        TextFormField(
                          controller: _startTimeController,
                          readOnly: true,
                          onTap: () => _pickTime(true),
                          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Start"),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("End Time:", style: TextStyle(fontWeight: FontWeight.bold)),
                        TextFormField(
                          controller: _endTimeController,
                          readOnly: true,
                          onTap: () => _pickTime(false),
                          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "End"),
                          validator: (v) => v!.isEmpty ? "Required" : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!isSpecial) ...[
                const Text("Subject:", style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _subjectController, 
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "e.g. Mathematics"), 
                  validator: (v) => (!isSpecial && v!.isEmpty) ? "Required" : null
                ),
              ],
              
              const SizedBox(height: 30),
              _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveTimetable, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    child: const Text("SAVE TO SCHEDULE", style: TextStyle(fontWeight: FontWeight.bold))
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
