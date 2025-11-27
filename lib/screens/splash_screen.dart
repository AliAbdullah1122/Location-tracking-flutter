import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:prismatic_app/screens/nav_bar.dart';
import 'package:prismatic_app/screens/sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/repo/auth_repository.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final controller = Get.find<AuthRepository>();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final sp = await SharedPreferences.getInstance();
    
    // CRITICAL: Check if this is a fresh install FIRST
    // When app is uninstalled, ALL SharedPreferences are cleared by Android
    // So if installation ID is missing, it means app was uninstalled and reinstalled
    const String installationIdKey = 'app_installation_id';
    String? storedInstallationId = sp.getString(installationIdKey);
    
    // If no installation ID exists = FRESH INSTALL after uninstall
    // MUST clear all login data and go to login screen
    if (storedInstallationId == null) {
      print("🆕 FRESH INSTALL DETECTED - App was uninstalled and reinstalled");
      print("🆕 Clearing ALL login data and forcing login screen");
      
      // Clear ALL possible login-related keys
      await sp.remove('access_token');
      await sp.remove('user_id');
      await sp.remove('flutter.access_token');
      await sp.remove('flutter.user_id');
      await sp.remove('flutter.App Is Login');
      await sp.remove('App Is Login'); // Clear SharedPref user data
      
      // Set installation ID to mark this as a valid install session
      String newInstallationId = DateTime.now().millisecondsSinceEpoch.toString();
      await sp.setString(installationIdKey, newInstallationId);
      
      print("🔒 Fresh install - MUST go to SignIn screen");
      await Future.delayed(const Duration(seconds: 2));
      Get.offAll(() => const SignIn());
      return; // CRITICAL: Exit early, don't check for tokens
    }
    
    // Installation ID exists = Normal app session (not fresh install)
    // Now check for saved login tokens
    final savedToken = sp.getString('access_token');
    final userId = sp.getString('user_id');

    print("🧠 Installation ID exists - checking for saved login");
    print("🧠 Saved token: $savedToken");
    print("🧠 Saved user_id: $userId");
    print("🧠 Controller status: ${controller.status}");

    // Add a short splash delay
    await Future.delayed(const Duration(seconds: 2));

    // ✅ Check for valid saved login
    if (savedToken != null && savedToken.isNotEmpty && userId != null) {
      print("✅ Token found — restoring AuthRepository state and navigating to Home");
      
      // Restore AuthRepository state when token is found
      controller.token(savedToken);
      controller.userId(int.tryParse(userId) ?? 0);
      controller.updateStatus(Status.Authenticated);
      
      print("✅ AuthRepository state restored - navigating to Home");
      Get.offAll(() => const HomeNavigation());
    } else {
      print("🔒 No valid login found — navigating to SignIn");
      Get.offAll(() => const SignIn());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/logo.png',
          height: 120,
        ),
      ),
    );
  }
}
