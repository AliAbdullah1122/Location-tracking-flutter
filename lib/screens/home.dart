// ignore_for_file: use_key_in_widget_constructors, avoid_print

import 'package:auto_size_text/auto_size_text.dart';
import 'package:background_location/background_location.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:prismatic_app/services/repo/timestamp_repository.dart';
import '../services/repo/auth_repository.dart';

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final controller = Get.find<AuthRepository>();
  final timeController = Get.find<TimeStampRepository>();
  String deviceState = "Foreground";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    BackgroundLocation.stopLocationService();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) return;
    final isBackground = state == AppLifecycleState.paused;

    if (isBackground) {
      deviceState = "Background";
      print('Device State: $deviceState');
    } else {
      deviceState = "Foreground";
      print('Device State: $deviceState');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[900],
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            Container(
              height: MediaQuery.of(context).size.height / 4,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.grey.withOpacity(0.2), width: 10)),
              child: Center(
                  child: AutoSizeText(
                controller.user!.ratio.toString() + '%',
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 50,
                    fontWeight: FontWeight.bold),
                maxLines: 1,
              )),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.15,
            ),
            const Text(
              'Overall attendance by Percentage %',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.05,
            ),
            Obx(() {
              return InkWell(
                onTap: () async {
                  print(
                      'Latitude: ${controller.lat}, Longitude: ${controller.long}');
                  print('Player Id: ${controller.playerId}');
                  print('User Id: ${controller.user!.user.toString()}');

                  timeController.checkIn(
                      controller.lat.toDouble(),
                      controller.long.toDouble(),
                      controller.user!.user.toString(),
                      controller.playerId.value);
                },
                child: Container(
                    height: 55,
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.height * 0.03),
                    decoration: BoxDecoration(
                        color: Colors.green[900],
                        borderRadius: BorderRadius.circular(10)),
                    child:
                        (timeController.checkInStatus == CheckInStatus.Loading)
                            ? const SizedBox(
                                height: 30,
                                width: 30,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Center(
                                child: Text(
                                  'Check In',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontFamily: 'PoppinsRegular',
                                      fontWeight: FontWeight.bold),
                                ),
                              )),
              );
            }),
            const SizedBox(height: 20),
            Obx(() {
              return InkWell(
                onTap: () {
                  print(
                      'Latitude: ${controller.lat}, Longitude: ${controller.long}');
                  print('Player Id: ${controller.playerId}');
                  print('User Id: ${controller.user!.user.toString()}');

                  timeController.checkOut(
                      controller.lat.toDouble(),
                      controller.long.toDouble(),
                      controller.user!.user.toString(),
                      controller.playerId.value);
                },
                child: Container(
                    height: 55,
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.height * 0.03),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10)),
                    child: (timeController.checkOutStatus ==
                            CheckOutStatus.Loading)
                        ? const SizedBox(
                            height: 30,
                            width: 30,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Check Out',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'PoppinsRegular',
                                  fontWeight: FontWeight.bold),
                            ),
                          )),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget locationData(String data) {
    return Text(
      data,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
      textAlign: TextAlign.center,
    );
  }

  void getCurrentLocation() {
    BackgroundLocation().getCurrentLocation().then((location) {
      print('This is current Location ${location.toMap().toString()}');
    });
  }
}

class BuildService extends StatelessWidget {
  final VoidCallback? onTap;
  final String? title;
  const BuildService({
    Key? key,
    this.onTap,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        width: 80,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.blue, borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(title!)),
      ),
    );
  }
}
