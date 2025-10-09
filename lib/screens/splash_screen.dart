import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/repo/auth_repository.dart';
import 'nav_bar.dart';
import 'sign_in.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  _save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'access_token';
    final value = token;
    prefs.setString(key, value);
  }

  Timer? timer;
  final controller = Get.find<AuthRepository>();
  @override
  void initState() {
    timer = Timer(const Duration(milliseconds: 2000), () {
      if (controller.status == Status.IsFirstTime) {
        Get.off(() => const SignIn());
      } else if (controller.status == Status.Authenticated) {
        Get.off(() => const HomeNavigation());
      } else {
        _save('0');
        Get.off(() => const SignIn());
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/logo.png',
          height: 100,
        ),
      ),
    );
  }
}
