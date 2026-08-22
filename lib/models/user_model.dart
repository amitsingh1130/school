class UserModel {
  final String userId;
  final String password;
  final String name;
  final String role;
  final String? classId;
  
  // Extra Details for Teacher/Student Profiles
  final String? rollNumber;
  final String? fatherName;
  final String? motherName;
  final String? dob;
  final String? mobile;
  final String? aadhaar;
  final String? address; // NEW
  final String? gender;  // NEW
  final String? subject;
  final String? joiningDate;
  final String? designation;
  final String? regNo;
  final String? birthCertNo;
  final String? fcmToken; 

  UserModel({
    required this.userId,
    required this.password,
    required this.name,
    required this.role,
    this.classId,
    this.rollNumber,
    this.fatherName,
    this.motherName,
    this.dob,
    this.mobile,
    this.aadhaar,
    this.address,
    this.gender,
    this.subject,
    this.joiningDate,
    this.designation,
    this.regNo,
    this.birthCertNo,
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'password': password,
      'name': name,
      'role': role,
      'classId': classId,
      'rollNumber': rollNumber,
      'fatherName': fatherName,
      'motherName': motherName,
      'dob': dob,
      'mobile': mobile,
      'aadhaar': aadhaar,
      'address': address,
      'gender': gender,
      'subject': subject,
      'joiningDate': joiningDate,
      'designation': designation,
      'regNo': regNo,
      'birthCertNo': birthCertNo,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      password: map['password'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? '',
      classId: map['classId'],
      rollNumber: map['rollNumber'],
      fatherName: map['fatherName'],
      motherName: map['motherName'],
      dob: map['dob'],
      mobile: map['mobile'],
      aadhaar: map['aadhaar'],
      address: map['address'],
      gender: map['gender'],
      subject: map['subject'],
      joiningDate: map['joiningDate'],
      designation: map['designation'],
      regNo: map['regNo'],
      birthCertNo: map['birthCertNo'],
      fcmToken: map['fcmToken'],
    );
  }
}
