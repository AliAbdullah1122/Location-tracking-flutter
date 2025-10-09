// ignore_for_file: avoid_print, non_constant_identifier_names

import 'dart:convert';
import 'package:prismatic_app/model/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPref {
  static String isLogin = "App Is Login";
  static String firstTimeAppOpen = " First Time App Open";
  
  
  SharedPreferences? _preferences;

  SharePref() {
    init();
  }

  Future init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  void setUser(User user) {
    _preferences!.setString(isLogin, user.toUserUserJson());
  }

  void logout() {
    _preferences!.setString(isLogin, "");
  }

  String read() {
    const key = 'access_token';
    String value = _preferences!.getString(key)!;
    // print('read: $value');
    return value;
  }

  saveToken(String value) {
    _preferences!.setString("access_token", value);
  }

  User? getUser() {
    var user = _preferences!.getString(isLogin);
    print("user value $user");
    if (user != null && user.isNotEmpty) {
      var json = jsonDecode(user);
      User uservalue = User.fromJson(json);
      return uservalue;
    } else {
      return null;
    }
  }

  void setFirstTimeOpen(bool value) {
    _preferences!.setBool(firstTimeAppOpen, value);
  }

  bool getFirstTimeOpen() {
    var value = _preferences!.getBool(firstTimeAppOpen);
    print("Am I a new User?  $value");
    return value ?? true;
  }
}
