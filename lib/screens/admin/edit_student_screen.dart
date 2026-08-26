import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';

class EditStudentScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const EditStudentScreen({super.key, required this.docId, required this.currentData});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rollController;
  late TextEditingController _fatherController;
  late TextEditingController _motherController;
  late TextEditingController _dobController;
  late TextEditingController _mobileController;
  late TextEditingController _aadhaarController;
  late TextEditingController _addressController; // NEW
  late TextEditingController _birthCertController;
  late TextEditingController _regNoController;
  late TextEditingController _classController;
  late TextEditingController _userIdController;
  late TextEditingController _passwordController;
  String? _selectedGender; // NEW
  bool _isLoading = false;
  bool _canEditCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    var d = widget.currentData;
    _nameController = TextEditingController(text: d['name']);
    _rollController = TextEditingController(text: d['rollNumber']);
    _fatherController = TextEditingController(text: d['fatherName']);
    _motherController = TextEditingController(text: d['motherName']);
    _dobController = TextEditingController(text: d['dob']);
    _mobileController = TextEditingController(text: d['mobile']);
    _aadhaarController = TextEditingController(text: d['aadhaar']);
    _addressController = TextEditingController(text: d['address']); // NEW
    _birthCertController = TextEditingController(text: d['birthCertNo']);
    _regNoController = TextEditingController(text: d['regNo']);
    _classController = TextEditingController(text: d['classId']);
    _userIdController = TextEditingController(text: d['userId']);
    _passwordController = TextEditingController(text: d['password']);
    _selectedGender = d['gender']; // NEW
  }

  void _checkPermission() async {
    UserModel? user = await PrefService().getUser();
    if (mounted) {
      setState(() {
        _canEditCredentials = user?.role == 'admin' || user?.role == 'principal' || user?.role == 'vice_principal';
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime initial = DateTime.now().subtract(const Duration(days: 913));
    try { initial = DateFormat('dd-MM-yyyy').parse(_dobController.text); } catch (e) {}
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now().subtract(const Duration(days: 913))) 
          ? DateTime.now().subtract(const Duration(days: 913)) 
          : initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      final int ageInDays = DateTime.now().difference(picked).inDays;
      if (ageInDays < 913) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Bacche ki umar kam se kam 2.5 saal honi chahiye."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      setState(() => _dobController.text = DateFormat('dd-MM-yyyy').format(picked));
    }
  }

  void _updateData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        await FirebaseFirestore.instance.collection('students').doc(widget.docId).update({
          'name': _nameController.text.trim(),
          'rollNumber': _rollController.text.trim(),
          'fatherName': _fatherController.text.trim(),
          'motherName': _motherController.text.trim(),
          'dob': _dobController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'aadhaar': _aadhaarController.text.trim(),
          'address': _addressController.text.trim(), // NEW
          'gender': _selectedGender, // NEW
          'birthCertNo': _birthCertController.text.trim(),
          'regNo': _regNoController.text.trim(),
          'classId': _classController.text.trim().toUpperCase(),
          'userId': _userIdController.text.trim(),
          'password': _passwordController.text.trim(),
        });

        // Also update the matching User document if exists
        var userQuery = widget.currentData['userId'] != null
            ? await FirebaseFirestore.instance
                .collection('users')
                .where('userId', isEqualTo: widget.currentData['userId'])
                .get()
            : await FirebaseFirestore.instance
                .collection('users')
                .where('rollNumber', isEqualTo: widget.currentData['rollNumber'])
                .where('classId', isEqualTo: widget.currentData['classId'])
                .get();
        for (var doc in userQuery.docs) {
          await doc.reference.update({
            'name': _nameController.text.trim(),
            'classId': _classController.text.trim().toUpperCase(),
            'rollNumber': _rollController.text.trim(),
            'address': _addressController.text.trim(), // NEW
            'gender': _selectedGender, // NEW
            'userId': _userIdController.text.trim(),
            'password': _passwordController.text.trim(),
          });
        }

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student Updated Successfully!")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Student Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_nameController, "Full Name"),
              
              // --- GENDER DROPDOWN ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                  items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _selectedGender = val),
                  validator: (val) => val == null ? 'Required' : null,
                ),
              ),

              _buildField(_rollController, "Roll Number"),
              _buildField(_classController, "Class"),
              _buildField(_userIdController, "User ID", isReadOnly: !_canEditCredentials),
              _buildField(_passwordController, "Password", isReadOnly: !_canEditCredentials),
              _buildField(_fatherController, "Father's Name"),
              _buildField(_motherController, "Mother's Name"),
              _buildDateField(_dobController, "Date of Birth", () => _selectDate(context)),
              _buildField(_mobileController, "Mobile Number"),
              _buildField(_aadhaarController, "Aadhaar Number", isRequired: false),
              _buildField(_addressController, "Address"), // NEW
              _buildField(_birthCertController, "Birth Certificate No.", isRequired: false),
              _buildField(_regNoController, "Registration No."),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updateData,
                      child: const Text('UPDATE STUDENT DETAILS'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isRequired = true, bool isReadOnly = false}) {
    int? maxLength;
    if (label.contains("Mobile")) maxLength = 10;
    if (label.contains("Aadhaar")) maxLength = 12;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        readOnly: isReadOnly,
        maxLines: label == "Address" ? 3 : 1,
        keyboardType: (label.contains("Mobile") || label.contains("Aadhaar") || label.contains("Roll")) ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label, 
          border: const OutlineInputBorder(), 
          counterText: "",
          filled: isReadOnly,
          fillColor: isReadOnly ? Colors.grey.shade100 : null,
        ),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) return 'Field required';
          if (val != null && val.isNotEmpty) {
            if (label.contains("Mobile") && val.length != 10) return 'Mobile must be 10 digits';
            if (label.contains("Aadhaar") && val.length != 12) return 'Aadhaar must be 12 digits';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today)),
      ),
    );
  }
}
