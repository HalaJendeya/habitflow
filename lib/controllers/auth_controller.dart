import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final isLoading = false.obs;

  @override
  void onReady() {
    super.onReady();

    checkUser();
  }

  Future<void> checkUser() async {
    // keep the splash screen visible for a moment
    await Future.delayed(const Duration(milliseconds: 1500));

    final user = _auth.currentUser;

    if (user != null) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> register(String email, String password) async {
    try {
      isLoading.value = true;

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      Get.offAllNamed(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Register Error', e.message ?? 'Something went wrong');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> login(String email, String password) async {
    try {
      isLoading.value = true;

      await _auth.signInWithEmailAndPassword(email: email, password: password);

      Get.offAllNamed(AppRoutes.home);
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login Error', e.message ?? 'Something went wrong');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();

    Get.offAllNamed(AppRoutes.login);
  }
}
