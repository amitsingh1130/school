import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import 'edit_teacher_screen.dart';
import 'teacher_details_screen.dart';
import 'package:intl/intl.dart';

class TeacherManagementScreen extends StatelessWidget {
  const TeacherManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Management"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var teachers = snapshot.data!.docs;
          if (teachers.isEmpty) return const Center(child: Text("No teachers added yet."));

          return ListView.builder(
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              var doc = teachers[index];
              var data = doc.data() as Map<String, dynamic>;
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF9C4),
                  child: Icon(Icons.person, color: Color(0xFFFFD700)),
                ),
                title: Text(data['name']),
                subtitle: Text("User ID: ${data['userId']} | Class: ${data['classId'] ?? 'None'}"),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherDetailsScreen(docId: doc.id, teacherData: data)));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTeacherFormScreen()));
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        label: const Text("Add Teacher"),
        icon: const Icon(Icons.group_add),
      ),
    );
  }
}

class AddTeacherFormScreen extends StatefulWidget {
  const AddTeacherFormScreen({super.key});

  @override
  State<AddTeacherFormScreen> createState() => _AddTeacherFormScreenState();
}

class _AddTeacherFormScreenState extends State<AddTeacherFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _fatherController = TextEditingController();
  final TextEditingController _motherController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _addressController = TextEditingController(); // NEW
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _classController = TextEditingController();
  final TextEditingController _joiningDateController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  String? _selectedGender; // NEW

  bool _isLoading = false;

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => controller.text = DateFormat('dd-MM-yyyy').format(picked));
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
       if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select gender")));
        return;
      }
      setState(() => _isLoading = true);
      try {
        UserModel teacher = UserModel(
          userId: _userIdController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          role: 'teacher',
          classId: _classController.text.trim().toUpperCase(),
          fatherName: _fatherController.text.trim(),
          motherName: _motherController.text.trim(),
          dob: _dobController.text.trim(),
          mobile: _mobileController.text.trim(),
          aadhaar: _aadhaarController.text.trim(),
          address: _addressController.text.trim(), // NEW
          gender: _selectedGender, // NEW
          subject: _subjectController.text.trim(),
          joiningDate: _joiningDateController.text.trim(),
          designation: _designationController.text.trim(),
        );

        await _db.createUser(teacher);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Teacher Registered Successfully!")));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Teacher")),
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

              _buildField(_fatherController, "Father's Name"),
              _buildField(_motherController, "Mother's Name"),
              _buildDateField(_dobController, "Date of Birth", () => _selectDate(_dobController)),
              _buildField(_mobileController, "Mobile Number"),
              _buildField(_aadhaarController, "Aadhaar Number"),
              _buildField(_addressController, "Address"), // NEW
              _buildField(_subjectController, "Main Subject"),
              _buildField(_designationController, "Designation"),
              _buildDateField(_joiningDateController, "Joining Date", () => _selectDate(_joiningDateController)),
              _buildField(_classController, "Assign Class Teacher of (e.g. 10-A)"),
              const Divider(height: 30),
              _buildField(_userIdController, "Create User ID"),
              _buildField(_passwordController, "Assign Password"),
              const SizedBox(height: 30),
              _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : ElevatedButton(
                    onPressed: _submit, 
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black, padding: const EdgeInsets.all(15)),
                    child: const Text("SAVE TEACHER & CREATE LOGIN")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isRequired = true}) {
    int? maxLength;
    if (label.contains("Mobile")) maxLength = 10;
    if (label.contains("Aadhaar")) maxLength = 12;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: label == "Address" ? 3 : 1,
        keyboardType: (label.contains("Mobile") || label.contains("Aadhaar")) ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), counterText: ""),
        validator: (val) {
          if (isRequired && (val == null || val.isEmpty)) return "Required";
          if (val != null && val.isNotEmpty) {
            if (label.contains("Mobile") && val.length != 10) return "Mobile must be 10 digits";
            if (label.contains("Aadhaar") && val.length != 12) return "Aadhaar must be 12 digits";
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
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        validator: (val) => val!.isEmpty ? 'Field required' : null,
      ),
    );
  }
}
