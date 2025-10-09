// ignore_for_file: avoid_print, unnecessary_null_comparison

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:prismatic_app/model/timestamp_model.dart';
import 'package:prismatic_app/model/user_model.dart';
import 'package:prismatic_app/services/repo/auth_repository.dart';

enum GetTimeStatus { Loading, Success, Error, Empty }
enum CheckInStatus { Loading, Success, Error, Empty }
enum CheckOutStatus { Loading, Success, Error, Empty }

class TimeStampRepository extends GetxController {
  User? user;

  final controller = Get.find<AuthRepository>();
  final _timestamp = Rx(Timestamps());
  final _getTimeStatus = GetTimeStatus.Empty.obs;
  final _checkInStatus = CheckInStatus.Empty.obs;
  final _checkOutStatus = CheckOutStatus.Empty.obs;

  GetTimeStatus get getTimeStatus => _getTimeStatus.value;
  CheckInStatus get checkInStatus => _checkInStatus.value;
  CheckOutStatus get checkOutStatus => _checkOutStatus.value;
  Timestamps get timestamp => _timestamp.value;

  @override
  void onInit() {
    print('Loading timestamps');
    getTimeStamps();
    super.onInit();
  }

  Future getTimeStamps() async {
    try {
      print('getting timestamps...');
      _getTimeStatus(GetTimeStatus.Loading);
      var response = await http.get(
          Uri.parse('http://124.29.208.60:8541/api/v1/user/setups'),
          headers: {
            "Content-Type": "application/json",
          });

      print("timestamp result ${response.body}");
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var times = Timestamps.fromJson(json);

        _timestamp(times);
        times != null
            ? _getTimeStatus(GetTimeStatus.Success)
            : _getTimeStatus(GetTimeStatus.Empty);

        print(times.timeIn);
      } else {
        _getTimeStatus(GetTimeStatus.Error);
        print("timestamp retrieval failed");
      }
    } catch (error) {
      print(error.toString());
      _getTimeStatus(GetTimeStatus.Error);
    }
  }

  Future checkIn(
      double? longitude, double? latitude, String user, String playerId) async {
    try {
      print('checking in...');
      _checkInStatus(CheckInStatus.Loading);
      final response = await http
          .post(Uri.parse("http://softwareworkmanservices.com.pk/api/check-out"),
              body: jsonEncode({
                "lat": latitude!,
                "long": longitude!,
                "user_id": user,
                "player_id": playerId,
                "status": "active",
                "app_state": 'foreground',
                "check_in": true,
                "check_out": false,
                "time": DateTime.now().toString(),
                "timestamp": DateTime.now().toString()
              }),
              headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer ${controller.token}'
          });
      print("response user: ${response.body}");
      if (response.statusCode == 200) {
        _checkInStatus(CheckInStatus.Success);
        print("user location sent successfully");
        Get.snackbar("Success", "Checked In Successfully ${response.body}",
            icon: const Icon(
              Icons.info,
              color: Colors.green,
            ));
      } else {
        print("Error sending user location ${response.body}");
        Get.snackbar("Error", "Error checking out, try again!",
            icon: const Icon(
              Icons.info,
              color: Colors.red,
            ));
        _checkInStatus(CheckInStatus.Error);
        print("unable to send user location");
      }
    } catch (error) {
      _checkInStatus(CheckInStatus.Error);
      print(error.toString());
    }
  }

  Future checkOut(
      double? longitude, double? latitude, String user, String playerId) async {
    try {
      print('checking out...');
      _checkOutStatus(CheckOutStatus.Loading);
      final response = await http
          .post(Uri.parse("http://softwareworkmanservices.com.pk/api/check-out"),
              body: jsonEncode({
                "lat": latitude!,
                "long": longitude!,
                "user_id": user,
                "player_id": playerId,
                "status": "active",
                "app_state": 'foreground',
                "check_in": false,
                "check_out": true,
                "time": DateTime.now().toString(),
                "timestamp": DateTime.now().toString()
              }),
              headers: {
            "Content-Type": "application/json",
            'Authorization': 'Bearer ${controller.token}'
          });
      print("response user: ${response.body}");
      if (response.statusCode == 200) {
        _checkOutStatus(CheckOutStatus.Success);
        print("user location sent successfully");
        Get.snackbar("Success", "Checked Out Successfully ${response.body}",
            icon: const Icon(
              Icons.info,
              color: Colors.green,
            ));
      } else {
        print("Error checking out, try again!");
        Get.snackbar("Error", "Error checking out, try again!",
            icon: const Icon(
              Icons.info,
              color: Colors.red,
            ));
        _checkOutStatus(CheckOutStatus.Error);
        print("unable to send user location");
      }
    } catch (error) {
      _checkOutStatus(CheckOutStatus.Error);
      print(error.toString());
    }
  }
}
