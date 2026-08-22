import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- AUTH / USER VERIFICATION ---
  Future<UserModel?> verifyLogin(String userId, String password) async {
    try {
      var doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        var data = doc.data()!;
        if (data['password'] == password) {
          return UserModel.fromMap(data);
        }
      }

      var query = await _db.collection('users')
          .where('userId', isEqualTo: userId)
          .where('password', isEqualTo: password)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data());
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // --- SMART AUTO-INCREMENT ID LOGIC (AUTO-RECOVERY ON DELETE) ---
  Future<Map<String, dynamic>> getNextScsData() async {
    try {
      var query = await _db.collection('students')
          .orderBy('admissionNumber', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;
      if (query.docs.isNotEmpty) {
        int lastNumber = query.docs.first.get('admissionNumber') ?? 0;
        nextNumber = lastNumber + 1;
      }

      return {
        'id': "scs$nextNumber",
        'number': nextNumber,
      };
    } catch (e) {
      print("ID Generation Error: $e");
      return {'id': "scs_err", 'number': 0};
    }
  }

  // --- MASTER RESET SYNC: Purani saari counting mistakes theek karega ---
  Future<void> autoSyncExistingStudents() async {
    try {
      DocumentSnapshot syncDoc = await _db.collection('settings').doc('sync_status').get();
      // Check for master sync flag specifically
      if (syncDoc.exists && (syncDoc.data() as Map<String, dynamic>)['master_sync_done'] == true) {
        return; 
      }

      var studentsQuery = await _db.collection('students').get();
      var docs = studentsQuery.docs;

      // Bacchon ko Admission Date ke hisaab se line mein lagayein (Sort)
      docs.sort((a, b) {
        var da = a.data().containsKey('admissionDate') ? a.get('admissionDate') as Timestamp? : null;
        var db = b.data().containsKey('admissionDate') ? b.get('admissionDate') as Timestamp? : null;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });

      var batch = _db.batch();
      int currentTotal = 0;

      // Sabko line se naya aur sahi number (scs1, scs2...) allot karein
      for (int i = 0; i < docs.length; i++) {
        currentTotal++;
        batch.update(docs[i].reference, {
          'admissionId': 'scs$currentTotal',
          'admissionNumber': currentTotal,
        });
      }

      // Global counter aur Flag update karein
      batch.set(_db.collection('counters').doc('students'), {'currentCount': currentTotal});
      batch.set(_db.collection('settings').doc('sync_status'), {'master_sync_done': true}, SetOptions(merge: true));
      
      await batch.commit();
    } catch (e) {
      print("Master Sync Error: $e");
    }
  }

  // --- ADMIN FUNCTIONS ---
  Future<void> createUser(UserModel user) async {
    try {
      await _db.collection('users').doc(user.userId).set(user.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addStudent(StudentModel student) async {
    try {
      await _db.collection('students').doc(student.userId).set(student.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // --- TEACHER FUNCTIONS ---
  Stream<List<StudentModel>> getStudentsByClass(String classId) {
    return _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StudentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<QuerySnapshot> getTimetable(String classId, String day) {
    return _db
        .collection('timetable')
        .where('classId', isEqualTo: classId)
        .where('day', isEqualTo: day)
        .snapshots();
  }
}
