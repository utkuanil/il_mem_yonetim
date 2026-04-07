import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserSession extends ChangeNotifier {
  String? uid;
  String? email;
  String? role;
  bool isActive = false;

  bool loading = true;

  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;
  bool get isAdmin => role == 'admin';

  Future<void> load() async {
    loading = true;
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      uid = null;
      email = null;
      role = null;
      isActive = false;
      loading = false;
      notifyListeners();
      return;
    }

    uid = user.uid;
    email = user.email;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    role = data?['role']?.toString();
    isActive = data?['isActive'] == true;

    loading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    uid = null;
    email = null;
    role = null;
    isActive = false;
    loading = false;
    notifyListeners();
  }
}
