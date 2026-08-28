import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/student_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import 'package:intl/intl.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(); // NEW
  final TextEditingController _birthCertController = TextEditingController();
  final TextEditingController _regNoController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedGender; // NEW

  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime initialDate = DateTime.now().subtract(const Duration(days: 913));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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

  void _submitData() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select gender")));
        return;
      }
      setState(() => _isLoading = true);
      try {
        String cls = _classController.text.trim().toUpperCase();
        String uId = _userIdController.text.trim();
        
        var scsData = await _dbService.getNextScsData();
        String autoId = scsData['id'];
        int autoNum = scsData['number'];
        var now = FieldValue.serverTimestamp();

        UserModel newUser = UserModel(
          userId: uId,
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          role: 'student',
          classId: cls,
          rollNumber: _rollController.text.trim(),
          fatherName: _fatherController.text.trim(),
          motherName: _motherController.text.trim(),
          dob: _dobController.text.trim(),
          mobile: _mobileController.text.trim(),
          aadhaar: _aadhaarController.text.trim(),
          address: _addressController.text.trim(), // NEW
          gender: _selectedGender, // NEW
          regNo: _regNoController.text.trim(),
          birthCertNo: _birthCertController.text.trim(),
          admissionId: autoId,
          admissionDate: now,
        );

        StudentModel newStudent = StudentModel(
          id: uId,
          userId: uId,
          admissionId: autoId,
          admissionNumber: autoNum,
          admissionDate: now,
          name: _nameController.text.trim(),
          rollNumber: _rollController.text.trim(),
          fatherName: _fatherController.text.trim(),
          motherName: _motherController.text.trim(),
          dob: _dobController.text.trim(),
          mobile: _mobileController.text.trim(),
          aadhaar: _aadhaarController.text.trim(),
          address: _addressController.text.trim(), // NEW
          gender: _selectedGender, // NEW
          birthCertNo: _birthCertController.text.trim(),
          regNo: _regNoController.text.trim(),
          classId: cls,
        );

        await _dbService.createUser(newUser);
        await _dbService.addStudent(newStudent);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Admission Success! ID: $autoId'), backgroundColor: Colors.green)
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Student')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(_nameController, "Student Full Name", required: true),
              
              // --- GENDER DROPDOWN ---
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
                  items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setState(() => _selectedGender = val),
                  validator: (val) => val == null ? 'Please select gender' : null,
                ),
              ),

              _buildField(_rollController, "Roll Number", required: true),
              _buildField(_classController, "Class (e.g. 10-A)", required: true),
              _buildField(_fatherController, "Father's Name", required: true),
              _buildField(_motherController, "Mother's Name", required: true),
              _buildDateField(_dobController, "Date of Birth", () => _selectDate(context)),
              _buildField(_mobileController, "Mobile Number", required: true),
              _buildField(_aadhaarController, "Aadhaar Number", required: false),
              _buildField(_addressController, "Address", required: true), // NEW
              _buildField(_birthCertController, "Birth Certificate No.", required: false),
              _buildField(_regNoController, "Registration No.", required: true),
              const Divider(height: 30),
              _buildField(_userIdController, "Create User ID", required: true),
              _buildField(_passwordController, "Assign Password", required: true),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitData, 
                      style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
                      child: const Text('SAVE & REGISTER')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool required = true}) {
    int? maxLength;
    if (label.contains("Mobile")) maxLength = 10;
    if (label.contains("Aadhaar")) maxLength = 12;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: label == "Address" ? 3 : 1, // Multi-line for address
        keyboardType: (label.contains("Mobile") || label.contains("Aadhaar") || label.contains("Roll")) ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), counterText: ""),
        validator: (val) {
          if (required && (val == null || val.isEmpty)) return 'Field required';
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
        validator: (val) => val!.isEmpty ? 'Field required' : null,
      ),
    );
  }
}
