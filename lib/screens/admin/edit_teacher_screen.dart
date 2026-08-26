import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../services/pref_service.dart';

class EditTeacherScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const EditTeacherScreen({super.key, required this.docId, required this.currentData});

  @override
  State<EditTeacherScreen> createState() => _EditTeacherScreenState();
}

class _EditTeacherScreenState extends State<EditTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _userIdController;
  late TextEditingController _passwordController;
  late TextEditingController _classController;
  late TextEditingController _fatherController;
  late TextEditingController _motherController;
  late TextEditingController _dobController;
  late TextEditingController _mobileController;
  late TextEditingController _aadhaarController;
  late TextEditingController _addressController; // NEW
  late TextEditingController _subjectController;
  late TextEditingController _joiningDateController;
  String? _selectedDesignation;
  final List<String> _designations = ["Teacher", "Principal", "Vice Principal"];
  String? _selectedGender; // NEW
  bool _isLoading = false;
  bool _canEditCredentials = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
    var d = widget.currentData;
    _nameController = TextEditingController(text: d['name']);
    _userIdController = TextEditingController(text: d['userId']);
    _passwordController = TextEditingController(text: d['password']);
    _classController = TextEditingController(text: d['classId']);
    _fatherController = TextEditingController(text: d['fatherName']);
    _motherController = TextEditingController(text: d['motherName']);
    _dobController = TextEditingController(text: d['dob']);
    _mobileController = TextEditingController(text: d['mobile']);
    _aadhaarController = TextEditingController(text: d['aadhaar']);
    _addressController = TextEditingController(text: d['address']); // NEW
    _subjectController = TextEditingController(text: d['subject']);
    _joiningDateController = TextEditingController(text: d['joiningDate']);
    _selectedDesignation = d['designation'];
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

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.now();
    try { initial = DateFormat('dd-MM-yyyy').parse(controller.text); } catch (e) {}
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('dd-MM-yyyy').format(picked));
    }
  }

  void _updateData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        String role = 'teacher';
        if (_selectedDesignation == 'Principal') role = 'principal';
        if (_selectedDesignation == 'Vice Principal') role = 'vice_principal';

        await FirebaseFirestore.instance.collection('users').doc(widget.docId).update({
          'name': _nameController.text.trim(),
          'userId': _userIdController.text.trim(),
          'password': _passwordController.text.trim(),
          'classId': _classController.text.trim().toUpperCase(),
          'role': role,
          'fatherName': _fatherController.text.trim(),
          'motherName': _motherController.text.trim(),
          'dob': _dobController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'aadhaar': _aadhaarController.text.trim(),
          'address': _addressController.text.trim(), // NEW
          'gender': _selectedGender, // NEW
          'subject': _subjectController.text.trim(),
          'joiningDate': _joiningDateController.text.trim(),
          'designation': _selectedDesignation,
        });
        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teacher Updated Successfully!")));
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
      appBar: AppBar(title: const Text("Edit Teacher Details")),
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

              _buildField(_userIdController, "User ID", isReadOnly: !_canEditCredentials),
              _buildField(_passwordController, "Password", isReadOnly: !_canEditCredentials),
              _buildField(_classController, "Class Teacher of"),
              _buildField(_subjectController, "Subject"),
              
              // --- DESIGNATION DROPDOWN ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedDesignation,
                  decoration: const InputDecoration(labelText: "Designation", border: OutlineInputBorder()),
                  items: _designations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) => setState(() => _selectedDesignation = val),
                  validator: (val) => val == null ? 'Required' : null,
                ),
              ),

              _buildDateField(_joiningDateController, "Joining Date", () => _selectDate(_joiningDateController)),
              _buildField(_fatherController, "Father's Name"),
              _buildField(_motherController, "Mother's Name"),
              _buildDateField(_dobController, "Date of Birth", () => _selectDate(_dobController)),
              _buildField(_mobileController, "Mobile Number"),
              _buildField(_aadhaarController, "Aadhaar Number"),
              _buildField(_addressController, "Address"), // NEW
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _updateData,
                      child: const Text('UPDATE TEACHER DETAILS'),
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
        keyboardType: (label.contains("Mobile") || label.contains("Aadhaar")) ? TextInputType.number : TextInputType.text,
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
