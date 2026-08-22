import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String userId; 
  final String? admissionId; // e.g., scs1, scs2...
  final int? admissionNumber; // Numeric for sorting (1, 2, 3...)
  final dynamic admissionDate; 
  final String name;
  final String rollNumber;
  final String fatherName;
  final String motherName;
  final String dob;
  final String mobile;
  final String aadhaar;
  final String? address; // NEW
  final String? gender;  // NEW
  final String birthCertNo;
  final String regNo;
  final String classId;

  StudentModel({
    required this.id,
    required this.userId,
    this.admissionId,
    this.admissionNumber,
    this.admissionDate,
    required this.name,
    required this.rollNumber,
    required this.fatherName,
    required this.motherName,
    required this.dob,
    required this.mobile,
    required this.aadhaar,
    this.address,
    this.gender,
    required this.birthCertNo,
    required this.regNo,
    required this.classId,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'admissionId': admissionId,
      'admissionNumber': admissionNumber,
      'admissionDate': admissionDate ?? FieldValue.serverTimestamp(),
      'name': name,
      'rollNumber': rollNumber,
      'fatherName': fatherName,
      'motherName': motherName,
      'dob': dob,
      'mobile': mobile,
      'aadhaar': aadhaar,
      'address': address,
      'gender': gender,
      'birthCertNo': birthCertNo,
      'regNo': regNo,
      'classId': classId,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StudentModel(
      id: documentId,
      userId: map['userId'] ?? '',
      admissionId: map['admissionId'],
      admissionNumber: map['admissionNumber'],
      admissionDate: map['admissionDate'],
      name: map['name'] ?? '',
      rollNumber: map['rollNumber'] ?? '',
      fatherName: map['fatherName'] ?? '',
      motherName: map['motherName'] ?? '',
      dob: map['dob'] ?? '',
      mobile: map['mobile'] ?? '',
      aadhaar: map['aadhaar'] ?? '',
      address: map['address'],
      gender: map['gender'],
      birthCertNo: map['birthCertNo'] ?? '',
      regNo: map['regNo'] ?? '',
      classId: map['classId'] ?? '',
    );
  }
}
