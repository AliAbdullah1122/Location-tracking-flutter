// ignore_for_file: constant_identifier_names, avoid_print, unused_local_variable, annotate_overrides, unnecessary_null_comparison

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:background_location/background_location.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:prismatic_app/model/user_model.dart';
import 'package:prismatic_app/screens/nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/sign_in.dart';
import '../api_link.dart';
import '../shared_pref.dart';

enum LocationStatus { Loading, Success, Error, Empty }
enum UpdateProfileStatus { Loading, Success, Error, Empty }

enum Status {
  Loading,
  Authenticated,
  UnAuthenticated,
  Error,
  Unknown_Error,
  Empty,
  IsFirstTime
}

class AuthRepository extends GetxController with WidgetsBindingObserver {
  final passwordController = TextEditingController();
  final emailController = TextEditingController();

  final _locationStatus = LocationStatus.Empty.obs;
  final _updateProfileStatus = UpdateProfileStatus.Empty.obs;
  final _status = Status.Empty.obs;

  RxBool serviceEnabled = false.obs;
  final token = "".obs;
  final playerId = "".obs;
  final _errorMessage = "".obs;
  final _deviceState = "".obs;
  final _email = "".obs;
  final _password = "".obs;

  LocationStatus get locationStatus => _locationStatus.value;
  UpdateProfileStatus get updateProfileStatus => _updateProfileStatus.value;
  Status get status => _status.value;
  String get errorMessage => _errorMessage.value;
  String get email => _email.value;
  String get password => _password.value;
  SharedPref? pref;

  User? user;
  Rx<User> liveUser = Rx(User());
  User get userData => liveUser.value;

  final long = 0.0.obs;
  final lat = 0.0.obs;
  final userId = 0.obs;

  @override
  void onInit() async {
    pref = SharedPref();
    await pref!.init();

    if (pref!.getUser() != null) {
      user = pref!.getUser()!;
      token(pref!.read());
      print("token is ${token.value}");
      liveUser(user);
      initOneSignal();
      
      // Start location service immediately
      await startService();
      
      // Start continuous location sending
      _startContinuousLocationSending();

      _status(Status.Authenticated);
    } else {
      _status(Status.UnAuthenticated);
    }
    super.onInit();
    WidgetsBinding.instance!.addObserver(this);
  }

  void _startContinuousLocationSending() {
    // Send location every 1 second continuously for all states
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (lat.value != 0.0 && long.value != 0.0) {
        print('AuthRepository: Sending location every second - Lat: ${lat.value}, Lng: ${long.value}');
        await sendLocation(long.value, lat.value);
      } else {
        print('AuthRepository: No valid location available, trying to get current location');
        // Try to get current location
        final location = await getCurrentLocation();
        if (location['latitude'] != 0.0 && location['longitude'] != 0.0) {
          print('AuthRepository: Got current location, sending - Lat: ${location['latitude']}, Lng: ${location['longitude']}');
          await sendLocation(location['longitude']!, location['latitude']!);
        } else {
          print('AuthRepository: Still no valid location available - NOT sending 0,0 coordinates');
          // Don't send 0,0 coordinates - wait for valid location
        }
      }
    });
  }

  @override
  void onClose() {
    WidgetsBinding.instance!.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    String deviceState = "foreground";
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) return;
    final isBackground = state == AppLifecycleState.paused;

    if (isBackground) {
      deviceState = "background";
      _deviceState(deviceState);
      print('Device State: $deviceState');
    } else {
      deviceState = "foreground";
      _deviceState(deviceState);
      print('Device State: $deviceState');
    }
  }

Future<dynamic> login(String email, String password) async {
  _status(Status.Loading);
  try {
    _email(email);
    _password(password);
    initOneSignal();

    final sp = await SharedPreferences.getInstance();
    // ✅ Clear only login-related keys, NOT all SharedPreferences (preserve installation_id)
    await sp.remove('access_token');
    await sp.remove('user_id');
    await sp.remove('flutter.access_token');
    await sp.remove('flutter.user_id');
    await sp.remove('flutter.App Is Login');
    await sp.remove('App Is Login');

    var response = await http.post(
      Uri.parse(ApiLink.login),
      body: {
        "username": email,
        "password": password,
        "client_id": '7',
        "grant_type": "password",
        "client_secret": "9jfIyHZJzV9usVZXtvzd8702IGvwh4fcllyCWXx1",
        "device_id": "0000",
        "onesignal_player_id": "111s"
      },
    );

    var json = jsonDecode(response.body);
    print("🔹 login response $json");

    // ✅ Step 1: Handle server or HTTP-level errors
    if (response.statusCode != 200) {
      _status(Status.Error);
      _errorMessage("Server error: ${response.statusCode}");
      print("❌ Server responded with error code ${response.statusCode}");
      return;
    }

    // ✅ Step 2: Detect invalid credentials or failed login
    if (json['message'] != null &&
        json['message'].toString().toLowerCase().contains('invalid')) {
      _status(Status.Error);
      _errorMessage(json['message']);
      // Clear only login-related keys, NOT all SharedPreferences (preserve installation_id)
      await sp.remove('access_token');
      await sp.remove('user_id');
      await sp.remove('flutter.access_token');
      await sp.remove('flutter.user_id');
      await sp.remove('flutter.App Is Login');
      await sp.remove('App Is Login');
      print("❌ Invalid credentials detected — stopping login flow");
      return; // ❗ stop here, no navigation
    }

    // ✅ Step 3: Ensure a valid token and user data exists
    if (json["access_token"] == null ||
        json["user_id"] == null ||
        json["access_token"].toString().isEmpty) {
      _status(Status.Error);
      _errorMessage('Login failed: token or user data missing.');
      // Clear only login-related keys, NOT all SharedPreferences (preserve installation_id)
      await sp.remove('access_token');
      await sp.remove('user_id');
      await sp.remove('flutter.access_token');
      await sp.remove('flutter.user_id');
      await sp.remove('flutter.App Is Login');
      await sp.remove('App Is Login');
      print("❌ Missing token or user_id — stopping login flow");
      return; // ❗ stop here
    }

    // ✅ Step 4: Proceed with success
    print("✅ Login success, saving user and navigating...");
    var userModel = User.fromJson(json);
    user = userModel;
    token(json["access_token"]);
    _save(token.value);

    liveUser(userModel);
    userId(userModel.user);

    _status(Status.Authenticated);
    pref!.setUser(userModel);

    sp.setString("access_token", json["access_token"]);
    sp.setString("user_id", json["user_id"].toString());

    startService();

    // ✅ Navigate only after confirmed successful login
    Get.offAll(() => const HomeNavigation());
  } catch (ex) {
    print("❌ Login exception: $ex");
    _status(Status.Error);
    _errorMessage(ex.toString());
  }
}

  Future<dynamic> getUserData(String email, String password) async {
    _status(Status.Loading);
    try {
      var response = await http.post(
        Uri.parse(ApiLink.login),
        // body: {
        //   "email": email,
        //   "password": password,
        // },
         body: {
          "username": email,
          // "email": email,
          "password": password,
          "client_id":'7',
          "grant_type":"password",
          "client_secret":"9jfIyHZJzV9usVZXtvzd8702IGvwh4fcllyCWXx1",
          "device_id":"0000",
          "onesignal_player_id":"111s"
        },
      );
      var json = jsonDecode(response.body);
      print("login response $json");
      if (json['errors'] != null) {
        throw (json['errors'][0]['message']);
      }

      print("result is $json");

      var userModel = User.fromJson(json);
      if (userModel != null) {
        user = userModel;
        token(json["access_token"]);
        _save(token.value);

        print("User Value ${userModel.toUserJson()}");

        liveUser(userModel);
        userId(userModel.user);
        _status(Status.Authenticated);
        pref!.setUser(userModel);
      }
      return response.body;
    } catch (ex) {
      _status(Status.Unknown_Error);
      _errorMessage(ex.toString());
      print(ex.toString());
    }
  }

  Future<void> initOneSignal() async {
    print('trying to get player id');
    await OneSignal.shared.setAppId("36953ca9-3d84-4c9f-a804-4f347695969a");

    final status = await OneSignal.shared.getDeviceState();
    final String? osUserID = status?.userId;
    playerId(osUserID);
    print('Player Id: $osUserID');

    await OneSignal.shared.promptUserForPushNotificationPermission(
      fallbackToSettings: true,
    );

    /// Calls when foreground notification arrives.
    // OneSignal.shared.setNotificationWillShowInForegroundHandler(
    //   handleForegroundNotifications,
    // );

    /// Calls when the notification opens the app.
    // OneSignal.shared.setNotificationOpenedHandler(handleBackgroundNotification);
  }

  Future sendLocation(double? longitude, double? latitude) async {
    print('User Id: ${user!.user}');
    try {
      print('trying to send location details to server');
      _locationStatus(LocationStatus.Loading);

      final response = await http.post(
          Uri.parse("http://softwareworkmanservices.com.pk/api/check-out"),
          body: jsonEncode({
            "lat": latitude!,
            "long": longitude!,
            "user_id": user!.user!,
            "player_id": playerId.value,
            "status": "app",
            "app_state": 'foreground',
            "check_in": false,
            "check_out": false,
            "time": DateTime.now().toString(),
            "timestamp": DateTime.now().toString()
          }),
          headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer $token'
          });
      print("response user: ${response.body}");
      if (response.statusCode == 200) {
        _locationStatus(LocationStatus.Success);
        print("user location sent successfully");
      } else {
        _locationStatus(LocationStatus.Error);
        print("unable to send user location");
      }
    } catch (error) {
      _locationStatus(LocationStatus.Error);
      print(error.toString());
    }
  }

  Future updateUserProfile(String? fName, String? lName, String image) async {
    try {
      _updateProfileStatus(UpdateProfileStatus.Loading);
      print('updating user profile');
      print(image);
      var headers = {
        "Content-Type": "application/json",
        'Authorization': 'Bearer $token'
      };
      var request =
          http.MultipartRequest('POST', Uri.parse(ApiLink.updateProfile));
      request.fields.addAll({
        "f_name": fName!,
        "l_name": lName!,
        "phone": user!.phone!,
        "email": email
      });
      request.files.add(await http.MultipartFile.fromPath('file', image));
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      if (response.statusCode == 200) {
        _updateProfileStatus(UpdateProfileStatus.Success);
        print('Profile updated success!');
        print(await response.stream.bytesToString());
      } else {
        _updateProfileStatus(UpdateProfileStatus.Error);
        print('Error updating profile!');
        print(response.reasonPhrase);
      }
    } catch (error) {
      _updateProfileStatus(UpdateProfileStatus.Error);
      print('Error updating profile!');
      print(error.toString());
    }
  }

  Future updateProfile(String? fName, String? lName) async {
    try {
      print('trying to update profile');
      print(emailController.text);
      _updateProfileStatus(UpdateProfileStatus.Loading);

      final response = await http.post(Uri.parse(ApiLink.updateProfile),
          body: jsonEncode({
            "image": user!.image!,
            "f_name": fName!,
            "l_name": lName!,
            "phone": user!.phone!,
            "email": emailController.text
          }),
          headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer $token'
          });
      print("response update user: ${response.body}");
      if (response.statusCode == 200) {
        _updateProfileStatus(UpdateProfileStatus.Success);
        getUserData(email, password);
        print("user data updated successfully");
        Get.snackbar("Success", "Profile updated successfully",
            icon: const Icon(
              Icons.info,
              color: Colors.green,
            ));
      } else {
        print("Error updating profile ${response.body}");
        Get.snackbar("Error", "Error updating profile",
            icon: const Icon(
              Icons.info,
              color: Colors.red,
            ));
        _updateProfileStatus(UpdateProfileStatus.Error);
      }
    } catch (error) {
      _updateProfileStatus(UpdateProfileStatus.Error);
      print(error.toString());
    }
  }

  Future resetPassword() async {
    try {
      print('trying to send verification profile');
      _updateProfileStatus(UpdateProfileStatus.Loading);
      final response = await http.post(Uri.parse(ApiLink.forgotPassword),
          body: jsonEncode({"email": emailController.text}),
          headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer $token'
          });
      print("response update user: ${response.body}");
      if (response.statusCode == 200) {
        _updateProfileStatus(UpdateProfileStatus.Success);
        print("verification sent to email successfully");
        Get.snackbar("Success", response.body,
            icon: const Icon(
              Icons.info,
              color: Colors.green,
            ));
      } else {
        print("Error sending mail ${response.body}");
        Get.snackbar("Error", "Error updating profile",
            icon: const Icon(
              Icons.info,
              color: Colors.red,
            ));
        _updateProfileStatus(UpdateProfileStatus.Error);
      }
    } catch (error) {
      _updateProfileStatus(UpdateProfileStatus.Error);
      print(error.toString());
    }
  }

  Future startService() async {
    print('AuthRepository: Starting location service...');
    
    try {
      await BackgroundLocation.setAndroidNotification(
        title: 'App is Running',
        message: 'App is Running',
        icon: '@mipmap/ic_launcher',
      );

      await BackgroundLocation.startLocationService();
      
      // Get current location first to test
      try {
        final currentLocation = await BackgroundLocation().getCurrentLocation();
        print('AuthRepository: Current location - Lat: ${currentLocation.latitude}, Lng: ${currentLocation.longitude}');
        
        if (currentLocation.latitude != null && currentLocation.longitude != null && 
            currentLocation.latitude != 0.0 && currentLocation.longitude != 0.0) {
          lat(currentLocation.latitude!);
          long(currentLocation.longitude!);
          sendLocation(currentLocation.longitude!, currentLocation.latitude!);
        }
      } catch (e) {
        print('AuthRepository: Error getting current location: $e');
      }
      
      BackgroundLocation.getLocationUpdates((location) {
        print('AuthRepository LOCATION UPDATE: Lat: ${location.latitude}, Lng: ${location.longitude}');
        print('AuthRepository: Accuracy: ${location.accuracy}, Time: ${location.time}');
        
        if (location.latitude != null && location.longitude != null && 
            location.latitude != 0.0 && location.longitude != 0.0) {
          lat(location.latitude!);
          long(location.longitude!);
          print('AuthRepository: Valid location received, sending to server immediately');
          // Send location immediately when new location is received
          sendLocation(location.longitude!, location.latitude!);
        } else {
          print('AuthRepository: Invalid location received (0,0 or null)');
        }
      });
      
      print('AuthRepository: Location service started successfully');
    } catch (e) {
      print('AuthRepository: Error starting location service: $e');
    }
  }

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will executed when app is in foreground or background in separated isolate
        onStart: onStartBackgroundService,

        // auto start service
        autoStart: true,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        // auto start service
        autoStart: true,

        // this will executed when app is in foreground in separated isolate
        onForeground: onStartBackgroundService,

        // you have to enable background fetch capability on xcode project
        onBackground: onIosBackground,
      ),
    );
    service.startService();
  }

// to ensure this executed
// run app from xcode, then from xcode menu, select Simulate Background Fetch
  bool onIosBackground(ServiceInstance service) {
    WidgetsFlutterBinding.ensureInitialized();
    print('FLUTTER BACKGROUND FETCH');

    return true;
  }

  void onStartBackgroundService(ServiceInstance service) {
    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // bring to foreground
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: "My App Service",
          content: "Updated at ${DateTime.now()}",
        );
      }

      /// you can see this log in logcat
      print('FLUTTER BACKGROUND SERVICE: ${DateTime.now()}');

      // test using external plugin

      service.invoke(
        'update',
        {
          "current_date": DateTime.now().toIso8601String(),
        },
      );
    });
  }

  _save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'access_token';
    final value = token;
    prefs.setString(key, value);
  }

  read() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'access_token';
    final value = prefs.get(key) ?? 0;
  }

  void updateStatus(Status status) {
    _status(status);
  }

  void logout() {
    BackgroundLocation.stopLocationService();
    _status(Status.UnAuthenticated);
    pref!.logout();
    Get.offAll((const SignIn()));
  }

  Future<Map<String, double>> getCurrentLocation() async {
    try {
      print('AuthRepository: Getting current location for check-in...');
      final location = await BackgroundLocation().getCurrentLocation();
      print('AuthRepository: Current location for check-in: ${location.toMap()}');
      
      if (location.latitude != null && location.longitude != null) {
        // Update the reactive variables
        lat(location.latitude!);
        long(location.longitude!);
        
        return {
          'latitude': location.latitude!,
          'longitude': location.longitude!,
        };
      } else {
        print('AuthRepository: Invalid location for check-in');
        return {'latitude': 0.0, 'longitude': 0.0};
      }
    } catch (e) {
      print('AuthRepository: Error getting current location for check-in: $e');
      return {'latitude': 0.0, 'longitude': 0.0};
    }
  }

  @override
  void dispose() {
    BackgroundLocation.stopLocationService();
    super.dispose();
  }
}
