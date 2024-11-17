import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Test App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TestAppScreen(),
    );
  }
}

class TestAppScreen extends StatefulWidget {
  @override
  _TestAppScreenState createState() => _TestAppScreenState();
}

class _TestAppScreenState extends State<TestAppScreen> {
  final Location _location = Location();
  FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<LocationData>? _locationSubscription;
  String _locationData = "Location not available";
  bool _isLocationUpdating = false;
  int _requestCount = 0;
  Timer? _notificationTimer;
  LocationData? _currentLocation;
  List<String> _notificationDetails = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings =
        InitializationSettings(android: androidInitSettings);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      _showSnackBar('Location permission granted');
    } else if (status.isDenied) {
      _showSnackBar('Location permission denied');
    } else if (status.isPermanentlyDenied) {
      _showSnackBar(
          'Location permission permanently denied. Please enable it from settings.');
    }
  }

  Future<void> _requestNotificationPermission() async {
    var status = await Permission.notification.request();
    if (status.isGranted) {
      _showSnackBar('Notification permission granted');
    } else if (status.isDenied) {
      _showSnackBar('Notification permission denied');
    } else if (status.isPermanentlyDenied) {
      _showSnackBar(
          'Notification permission permanently denied. Please enable it from settings.');
      openAppSettings();
    }
  }

  void _startLocationUpdate() {
    if (!_isLocationUpdating) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Start Location Updates?"),
            content: Text("Do you want to start receiving location updates?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("No"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _startLocationService();
                },
                child: Text("Yes"),
              ),
            ],
          );
        },
      );
    } else {
      _showSnackBar('Location updates already running');
    }
  }

  void _startLocationService() {
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLocation = currentLocation;
        _locationData = '''
Location Info:
Lat: ${currentLocation.latitude?.toStringAsFixed(3)}
Lng: ${currentLocation.longitude?.toStringAsFixed(3)}
Speed: ${_formatSpeed(_convertMpsToKmh(currentLocation.speed))}m
''';
      });

      setState(() {
        _requestCount++;
      });

      String requestDetail = '''
Lat: ${currentLocation.latitude?.toStringAsFixed(3)}
Lng: ${currentLocation.longitude?.toStringAsFixed(3)}
Speed: ${_formatSpeed(_convertMpsToKmh(currentLocation.speed))} km/h
''';

      _notificationDetails.add(requestDetail);
      _storeLocationData(currentLocation);
      _showNotification("Request $_requestCount: Location update received");
    });

    setState(() {
      _isLocationUpdating = true;
    });

    _showSnackBar('Location updates started');
    _startNotificationTimer();
  }

  void _stopLocationUpdate() {
    if (_isLocationUpdating) {
      _locationSubscription?.cancel();
      _stopNotificationTimer();
      setState(() {
        _isLocationUpdating = false;
        _locationData = "Location tracking stopped";
      });
      _showNotification("Location tracking stopped");
      _showSnackBar('Location updates stopped');
    } else {
      _showSnackBar('No active location updates to stop');
    }
  }

  void _startNotificationTimer() {
    _notificationTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_currentLocation != null) {
        String message =
            "Request $_requestCount: Location update at ${DateTime.now()}\n"
            "Lat: ${_currentLocation!.latitude?.toStringAsFixed(3)}\n"
            "Lng: ${_currentLocation!.longitude?.toStringAsFixed(3)}\n"
            "Speed: ${_formatSpeed(_convertMpsToKmh(_currentLocation!.speed))} km/h";

        _showNotification(message);
      }
    });
  }

  void _stopNotificationTimer() {
    if (_notificationTimer != null) {
      _notificationTimer!.cancel();
      _notificationTimer = null;
    }
  }

  double _convertMpsToKmh(double? speedInMps) {
    if (speedInMps == null) return 0.0;
    return speedInMps * 3.6;
  }

  String _formatSpeed(double speed) {
    return speed.round().toString(); // Round speed to nearest integer
  }

  Future<void> _storeLocationData(LocationData currentLocation) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('latitude', currentLocation.latitude ?? 0.0);
    await prefs.setDouble('longitude', currentLocation.longitude ?? 0.0);
    await prefs.setDouble('speed', _convertMpsToKmh(currentLocation.speed));
  }

  Future<void> _showNotification(String message) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      channelDescription: 'Description of the channel',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      _requestCount,
      'Location Update',
      message,
      notificationDetails,
    );
  }

  String _extractValue(String detail, String label) {
    final regex = RegExp('$label: ([\\d\\.]+)');
    final match = regex.firstMatch(detail);
    return match != null ? match.group(1)! : 'N/A';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Test App',
          style: TextStyle(
            color: Colors.white, // Text color is white
            fontWeight: FontWeight.bold, // Font weight is bold
          ),
        ),
        backgroundColor: Colors.black, // Background color is black
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Container(
                color: Colors
                    .black, // Set the background color of the container to black
                padding: const EdgeInsets.all(16.0), // Add padding if needed
               
                     // Make the container take the full width
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;

                    return GridView.builder(
                      physics: NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 7,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        final buttonData = [
                          {
                            "title": 'Request Location Permission',
                            "color": Colors.blue,
                            "onPressed": _requestLocationPermission,
                          },
                          {
                            "title": 'Request Notification Permission',
                            "color": Colors.amber,
                            "onPressed": _requestNotificationPermission,
                          },
                          {
                            "title": 'Start Location Update',
                            "color": Colors.green,
                            "onPressed": _startLocationUpdate,
                          },
                          {
                            "title": 'Stop Location Update',
                            "color": Colors.red,
                            "onPressed": _stopLocationUpdate,
                          },
                        ];

                        return _buildButton(
                          buttonData[index]['title'] as String,
                          buttonData[index]['onPressed'] as VoidCallback,
                          buttonData[index]['color'] as Color,
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              _notificationDetails.isNotEmpty
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        // Check the screen width
                        bool isTabletOrLarger = constraints.maxWidth >
                            600; // You can adjust this width

                        return Column(
                          children:
                              _notificationDetails.asMap().entries.map((entry) {
                            return isTabletOrLarger
                                ? // Tablet or larger screens, two cards per row
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Card(
                                          elevation: 4,
                                          margin: EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 4),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Request ${entry.key + 1}',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Lat: ${_extractValue(entry.value, "Lat")}',
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                    Text(
                                                      'Lng: ${_extractValue(entry.value, "Lng")}',
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                    Text(
                                                      'Speed: ${_extractValue(entry.value, "Speed")}',
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Card(
                                          elevation: 4,
                                          margin: EdgeInsets.symmetric(
                                              vertical: 8, horizontal: 4),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Request ${entry.key + 2}', // Adjust index for the second card
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Lat: ${_extractValue(entry.value, "Lat")}',
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                    Text(
                                                      'Lng: ${_extractValue(entry.value, "Lng")}',
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                    Text(
                                                      'Speed: ${_extractValue(entry.value, "Speed")}',
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : // Mobile screens, one card per row
                                Card(
                                    elevation: 4,
                                    margin: EdgeInsets.symmetric(vertical: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Request ${entry.key + 1}',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Lat: ${_extractValue(entry.value, "Lat")}',
                                                style: TextStyle(fontSize: 14,),
                                              ),
                                              Text(
                                                'Lng: ${_extractValue(entry.value, "Lng")}',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                              Text(
                                                'Speed: ${_extractValue(entry.value, "Speed")}m',
                                                style: TextStyle(fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                          }).toList(),
                        );
                      },
                    )
                  : Container(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String title, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }
}
