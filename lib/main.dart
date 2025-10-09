import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:get/get.dart';
import 'package:background_location/background_location.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:prismatic_app/screens/splash_screen.dart';
import 'package:prismatic_app/services/app_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request all permissions before starting the app
  await _requestAllPermissions();
  
  // Start native Android service for kill state tracking
  await _startNativeAndroidServiceFromMain();
  
  initializeService();
  runApp(const MyApp());
}

Future<void> _requestAllPermissions() async {
  print('APP: Requesting all permissions...');
  
  // List of all permissions needed
  List<Permission> permissions = [
    // Location permissions (most important)
    Permission.location,
    Permission.locationAlways,
    Permission.locationWhenInUse,
    
    // Notification permissions
    Permission.notification,
    
    // Camera and storage permissions
    Permission.camera,
    Permission.storage,
    Permission.manageExternalStorage,
    
    // Phone and contacts permissions
    Permission.phone,
    Permission.contacts,
    
    // Microphone permission
    Permission.microphone,
    
    // Calendar permissions
    Permission.calendar,
    
    // SMS permissions
    Permission.sms,
    
    // System alert window
    Permission.systemAlertWindow,
    
    // Ignore battery optimization
    Permission.ignoreBatteryOptimizations,
  ];

  // Request permissions one by one with delays
  for (Permission permission in permissions) {
    try {
      print('APP: Requesting permission: ${permission.toString()}');
      
      PermissionStatus status = await permission.status;
      print('APP: Current status for ${permission.toString()}: $status');
      
      if (status.isDenied || status.isRestricted) {
        status = await permission.request();
        print('APP: Requested ${permission.toString()}: $status');
      }
      
      if (status.isGranted) {
        print('APP: ✅ ${permission.toString()} granted');
      } else if (status.isPermanentlyDenied) {
        print('APP: ❌ ${permission.toString()} permanently denied - user needs to enable manually');
        // Open app settings for permanently denied permissions
        await openAppSettings();
      } else {
        print('APP: ⚠️ ${permission.toString()} not granted: $status');
      }
      
      // Small delay between permission requests
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('APP: Error requesting ${permission.toString()}: $e');
    }
  }
  
  // Special handling for location permissions
  await _requestLocationPermissionsSpecially();
  
  print('APP: All permissions requested!');
}

Future<void> _startNativeAndroidServiceFromMain() async {
  print('APP: Starting native Android service from main...');
  
  try {
    const platform = MethodChannel('com.example.prismatic_app/location_service');
    await platform.invokeMethod('startLocationService');
    print('APP: Native Android service started successfully from main');
  } catch (e) {
    print('APP: Error starting native Android service from main: $e');
  }
}

Future<void> _requestLocationPermissionsSpecially() async {
  print('APP: Special location permission handling...');
  
  try {
    // Request location permission with high accuracy
    PermissionStatus locationStatus = await Permission.location.request();
    print('APP: Location permission: $locationStatus');
    
    // Request background location permission
    PermissionStatus backgroundStatus = await Permission.locationAlways.request();
    print('APP: Background location permission: $backgroundStatus');
    
    // If location permission is granted, request high accuracy
    if (locationStatus.isGranted) {
      print('APP: Location permission granted, requesting high accuracy...');
      // You can add additional location accuracy requests here if needed
    }
    
    // If background permission is permanently denied, guide user to settings
    if (backgroundStatus.isPermanentlyDenied) {
      print('APP: Background location permanently denied - opening settings...');
      await openAppSettings();
    }
  } catch (e) {
    print('APP: Error in special location permission handling: $e');
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will executed when app is in foreground in separated isolate
      onForeground: onStart,

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

void onStart(ServiceInstance service) async {
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

  // Location tracking is handled by AuthRepository and Native Android Service
  print('BACKGROUND SERVICE: Location tracking handled by AuthRepository and Native Service');

  // bring to foreground and show notification
  Timer.periodic(const Duration(seconds: 1), (timer) async {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "App is Running",
        content: "Native service running - ${DateTime.now()}",
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

Future<void> _startLocationTracking(ServiceInstance service) async {
  print('Starting location tracking in background service...');
  
  try {
    // Check and request permissions first
    await _requestLocationPermissions();
    
    // Wait a bit for permissions to be granted
    await Future.delayed(const Duration(seconds: 2));
    
    // Set up Android notification for background location
    await BackgroundLocation.setAndroidNotification(
      title: 'Background location service',
      message: 'App is Running',
      icon: '@mipmap/ic_launcher',
    );

    // Start location service
    await BackgroundLocation.startLocationService();
    
    // Get current location first to test if location service is working
    try {
      final currentLocation = await BackgroundLocation().getCurrentLocation();
      print('BACKGROUND SERVICE: Current location - Lat: ${currentLocation.latitude}, Lng: ${currentLocation.longitude}');
      
      if (currentLocation.latitude != null && currentLocation.longitude != null) {
        _sendLocationToServer(currentLocation.latitude!, currentLocation.longitude!, service);
      }
    } catch (e) {
      print('BACKGROUND SERVICE: Error getting current location: $e');
    }
    
    // Get location updates
    BackgroundLocation.getLocationUpdates((location) {
      print('BACKGROUND SERVICE LOCATION: Lat: ${location.latitude}, Lng: ${location.longitude}');
      print('BACKGROUND SERVICE: Location accuracy: ${location.accuracy}');
      print('BACKGROUND SERVICE: Location time: ${location.time}');
      
      // Check if location coordinates are valid and not 0,0
      if (location.latitude != null && location.longitude != null && 
          location.latitude != 0.0 && location.longitude != 0.0) {
        print('BACKGROUND SERVICE: Valid location received, sending to server');
        _sendLocationToServer(location.latitude!, location.longitude!, service);
      } else {
        print('BACKGROUND SERVICE: Invalid location coordinates received (0,0 or null)');
        print('BACKGROUND SERVICE: This might be due to permission issues or location services being disabled');
      }
    });
    
    print('Location tracking started successfully in background service');
  } catch (e) {
    print('Error starting location tracking in background service: $e');
  }
}

Future<void> _requestLocationPermissions() async {
  print('BACKGROUND SERVICE: Requesting location permissions...');
  
  try {
    // Request location permissions
    var locationStatus = await Permission.location.status;
    var locationAlwaysStatus = await Permission.locationAlways.status;
    
    print('BACKGROUND SERVICE: Location permission status: $locationStatus');
    print('BACKGROUND SERVICE: Location always permission status: $locationAlwaysStatus');
    
    if (locationStatus.isDenied) {
      locationStatus = await Permission.location.request();
      print('BACKGROUND SERVICE: Location permission requested: $locationStatus');
    }
    
    if (locationAlwaysStatus.isDenied) {
      locationAlwaysStatus = await Permission.locationAlways.request();
      print('BACKGROUND SERVICE: Location always permission requested: $locationAlwaysStatus');
    }
    
    // Wait for permissions to be granted
    if (locationStatus.isGranted || locationAlwaysStatus.isGranted) {
      print('BACKGROUND SERVICE: Location permissions granted');
    } else {
      print('BACKGROUND SERVICE: Location permissions denied - this will cause 0,0 coordinates');
    }
  } catch (e) {
    print('BACKGROUND SERVICE: Error requesting permissions: $e');
  }
}

Future<void> _startNativeAndroidService() async {
  print('BACKGROUND SERVICE: Starting native Android location service...');
  
  try {
    const platform = MethodChannel('com.example.prismatic_app/location_service');
    await platform.invokeMethod('startLocationService');
    print('BACKGROUND SERVICE: Native Android service started successfully');
  } catch (e) {
    print('BACKGROUND SERVICE: Error starting native Android service: $e');
  }
}

Future<void> _sendLocationToServer(double latitude, double longitude, ServiceInstance service) async {
  try {
    print('Sending location from background service: $latitude, $longitude');
    
    // Send location to your API server
    final response = await http.post(
      Uri.parse("http://softwareworkmanservices.com.pk/api/check-out"),
      body: jsonEncode({
        "lat": latitude,
        "long": longitude,
        "user_id": "background_service_user", // You can modify this
        "player_id": "background_service_player", // You can modify this
        "status": "kill_state",
        "app_state": "kill_state",
        "check_in": false,
        "check_out": false,
        "time": DateTime.now().toString(),
        "timestamp": DateTime.now().toString()
      }),
      headers: {
        "Content-Type": "application/json",
      }
    );
    
    if (response.statusCode == 200) {
      print('Background service: Location sent successfully to server');
    } else {
      print('Background service: Failed to send location to server: ${response.statusCode}');
    }
    
    // Also invoke the service for logging
    service.invoke(
      'location_update',
      {
        "latitude": latitude,
        "longitude": longitude,
        "timestamp": DateTime.now().toIso8601String(),
        "api_response": response.statusCode,
      },
    );
  } catch (e) {
    print('Error sending location from background service: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      initialBinding: AppBinding(),
      title: 'Prismatic App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Permission Management Widget
class PermissionManager extends StatefulWidget {
  const PermissionManager({Key? key}) : super(key: key);

  @override
  State<PermissionManager> createState() => _PermissionManagerState();
}

class _PermissionManagerState extends State<PermissionManager> {
  Map<Permission, PermissionStatus> permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    List<Permission> permissions = [
      Permission.location,
      Permission.locationAlways,
      Permission.notification,
      Permission.camera,
      Permission.storage,
      Permission.phone,
      Permission.contacts,
      Permission.microphone,
      Permission.sms,
      Permission.ignoreBatteryOptimizations,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (Permission permission in permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      permissionStatuses = statuses;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    setState(() {
      permissionStatuses[permission] = status;
    });

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  Future<void> _requestAllPermissions() async {
    for (Permission permission in permissionStatuses.keys) {
      await _requestPermission(permission);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  Color _getStatusColor(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return Colors.green;
      case PermissionStatus.denied:
        return Colors.orange;
      case PermissionStatus.permanentlyDenied:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Permissions'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Grant all permissions for the app to work properly',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _requestAllPermissions,
              style: ElevatedButton.styleFrom(
                primary: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Grant All Permissions',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: permissionStatuses.length,
                itemBuilder: (context, index) {
                  final permission = permissionStatuses.keys.elementAt(index);
                  final status = permissionStatuses[permission]!;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(_getPermissionName(permission)),
                      subtitle: Text(_getStatusText(status)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _requestPermission(permission),
                            style: ElevatedButton.styleFrom(
                              primary: _getStatusColor(status),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            ),
                            child: const Text(
                              'Request',
                              style: TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPermissionName(Permission permission) {
    if (permission == Permission.location) {
      return 'Location (When in Use)';
    } else if (permission == Permission.locationAlways) {
      return 'Location (Always)';
    } else if (permission == Permission.notification) {
      return 'Notifications';
    } else if (permission == Permission.camera) {
      return 'Camera';
    } else if (permission == Permission.storage) {
      return 'Storage';
    } else if (permission == Permission.phone) {
      return 'Phone';
    } else if (permission == Permission.contacts) {
      return 'Contacts';
    } else if (permission == Permission.microphone) {
      return 'Microphone';
    } else if (permission == Permission.sms) {
      return 'SMS';
    } else if (permission == Permission.ignoreBatteryOptimizations) {
      return 'Ignore Battery Optimization';
    } else {
      return permission.toString();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
