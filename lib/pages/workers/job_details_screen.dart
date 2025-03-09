import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handzy/pages/workers/payment_request_page.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class JobDetailsPage extends StatefulWidget {
  final Map<String, dynamic> jobDetails;
  final String jobId;

  const JobDetailsPage({
    super.key,
    required this.jobDetails,
    required this.jobId,
  });

  @override
  _JobDetailsPageState createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  late StreamSubscription _jobSubscription;
  final DatabaseReference _workerLocationRef = FirebaseDatabase.instance.ref();
  late Map<String, dynamic> jobDetails;
  late LatLng _userLocation;
  late LatLng _workerLocation;
  final MapController _mapController = MapController();
  Timer? _locationUpdateTimer;
  List<LatLng> _route = []; // List of LatLng points for the route
  bool _isLoadingRoute = false; // To show loading state
  String _routeError = ''; // To display any route errors

  @override
  void initState() {
    super.initState();
    jobDetails = widget.jobDetails; // Initialize with the passed details
    _userLocation = LatLng(
      jobDetails['joblocation']['latitude'],
      jobDetails['joblocation']['longitude'],
    );
    // For demo, we'll set worker location slightly offset from user
    // In a real app, you'd get this from the worker's current location
    _workerLocation = LatLng(
      _userLocation.latitude - 0.005,
      _userLocation.longitude - 0.003,
    );
    _listenToJobUpdates();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _jobSubscription.cancel();
    _stopLocationUpdates();
    super.dispose();
  }

  void _startLocationUpdates() {
    // Update location every 5 seconds
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      final position = await _getCurrentLocation();
      if (position != null) {
        _updateWorkerLocation(position);
      }
      _fetchRoute();
    });
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  void _updateWorkerLocation(Position position) {
    final workerId = FirebaseAuth.instance.currentUser?.uid;
    final locationData = {
      'latitude': position.latitude,
      'longitude': position.longitude,
    };

    // Update worker's location in Firebase
    _workerLocationRef
        .child('workers/$workerId/workerLocation')
        .set(locationData)
        .then((_) {
      print('Worker location updated: $locationData');
    }).catchError((error) {
      print('Failed to update worker location: $error');
    });
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return null;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        return null;
      }

      // Fetch the current location
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error fetching location: $e');
      return null;
    }
  }

  Future<void> _fetchRoute() async {
    setState(() {
      _isLoadingRoute = true; // Show loading indicator
      _routeError = ''; // Clear previous errors
    });

    try {
      final start = _workerLocation; // Worker's current location
      final end = _userLocation; // Job location

      // Fetch the route using OSRM API
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
      );

      print('Fetching route from OSRM: $url'); // Debugging: Print the URL

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('OSRM Response: $data'); // Debugging: Print the API response

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0]['geometry']['coordinates'] as List;

          // Convert the route coordinates to LatLng points
          final routePoints =
              route.map<LatLng>((point) => LatLng(point[1], point[0])).toList();

          setState(() {
            _route = routePoints; // Update the route points
            _isLoadingRoute = false; // Hide loading indicator
          });
          print('Route Updated: $_route'); // Debugging
        } else {
          setState(() {
            _routeError = 'No route found between the locations.';
            _isLoadingRoute = false; // Hide loading indicator
          });
          print('No route found in OSRM response');
        }
      } else {
        setState(() {
          _routeError = 'Failed to fetch route: ${response.statusCode}';
          _isLoadingRoute = false; // Hide loading indicator
        });
        print('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _routeError = 'Error fetching route: $e';
        _isLoadingRoute = false; // Hide loading indicator
      });
      print('Error fetching route: $e');
    }
  }

  Future<void> _fetchWorkerLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final workerId = user.uid;
    final workerLocationRef =
        FirebaseDatabase.instance.ref('workers/$workerId/workerLocation');

    final snapshot = await workerLocationRef.get();
    if (snapshot.exists) {
      final locationData = snapshot.value as Map?;
      if (locationData != null) {
        final latitude = locationData['latitude'];
        final longitude = locationData['longitude'];
        if (latitude != null && longitude != null) {
          setState(() {
            _workerLocation =
                LatLng(latitude, longitude); // Update worker location
          });
          print('Worker Location Updated: $_workerLocation'); // Debugging
        }
      }
    }
  }

  void _listenToJobUpdates() {
    final databaseRef = FirebaseDatabase.instance.ref();

    _jobSubscription =
        databaseRef.child('jobs/${widget.jobId}').onValue.listen((event) {
      if (!event.snapshot.exists) {
        // Job has been moved or deleted
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job has been completed or moved.')),
        );
        Navigator.pop(context); // Redirect back to the previous page
        return;
      }

      // Update the jobDetails with new data
      setState(() {
        jobDetails = Map<String, dynamic>.from(event.snapshot.value as Map);
        _userLocation = LatLng(
          jobDetails['joblocation']['latitude'],
          jobDetails['joblocation']['longitude'],
        );
      });

      // Handle status update if needed
      if (jobDetails['status'] == 'work done') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job has been marked as completed.')),
        );
        Navigator.pop(context); // Redirect back to the previous page
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: Colors.black),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Map background
          _buildMap(),

          // Bottom sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLocation,
        minZoom: 5.0,
        maxZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: ['a', 'b', 'c'],
        ),
        if (_route.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _route, // Use the fetched route points
                strokeWidth: 4.0,
                color: Colors.blue,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            // Worker marker (blue)
            Marker(
              width: 40.0,
              height: 40.0,
              point: _workerLocation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            // User marker (green)
            Marker(
              width: 40.0,
              height: 40.0,
              point: _userLocation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  Icons.handyman,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job Details Title
          Text(
            'Job Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),

          // User Card with Name and Phone
          // User Card with Name and Message text field
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                // User avatar
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey[600]),
                ),
                SizedBox(width: 12),
                // User details and message field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        jobDetails['userName'] ?? 'User Name',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(height: 4),
                      // Message text field
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText:
                                'Message ${jobDetails['userName'] ?? 'User'}',
                            hintStyle: TextStyle(
                                fontSize: 16, color: Colors.grey[500]),
                            prefixIcon: Icon(Icons.message,
                                size: 20, color: Colors.grey[600]),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                // Call button - keep this as is
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.blue),
                  onPressed: () => _callUser(jobDetails['userPhone']),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Job Location
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.location_on, color: Colors.white),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${jobDetails['joblocation']['address']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Navigation and End Job buttons
          Row(
            children: [
              // Navigate button
              Expanded(
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(180, 60),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(38),
                      ),
                    ),
                    onPressed: () {
                      final lat = jobDetails['joblocation']['latitude'];
                      final lng = jobDetails['joblocation']['longitude'];
                      _openNavigation(context, lat, lng);
                    },
                    icon: Icon(Icons.navigation, size: 18),
                    label: Text(
                      'Navigate',
                      style: TextStyle(fontSize: 18),
                    )),
              ),
              SizedBox(width: 12),

              // End Job button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green,
                    minimumSize: Size(180, 60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(38),
                    ),
                  ),
                  onPressed: () => _endJob(context),
                  label: Text(
                    'End Job',
                    style: TextStyle(
                      fontSize: 18, // Increase the font size here
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _callUser(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available.')),
      );
      return;
    }

    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone call.')),
      );
    }
  }

  void _openNavigation(
      BuildContext context, double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation.')),
      );
    }
  }

  void _endJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    // Get the worker's UID
    final workerId = user.uid;

    // Reference to the worker's data in the Realtime Database
    final databaseRef = FirebaseDatabase.instance.ref();
    final workerRef = databaseRef.child('workers/$workerId');

    try {
      // Update the worker's availability to "available"
      await workerRef.update({
        'availability': 'available',
      });

      // Navigate to the PaymentRequestPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentRequestPage(
            jobDetails: jobDetails,
            jobId: widget.jobId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update worker status: $e')),
      );
    }
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:camera/camera.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:handzy/pages/workers/payment_request_page.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';

// class JobDetailsPage extends StatefulWidget {
//   final Map<String, dynamic> jobDetails;
//   final String jobId;

//   const JobDetailsPage({
//     super.key,
//     required this.jobDetails,
//     required this.jobId,
//   });

//   @override
//   _JobDetailsPageState createState() => _JobDetailsPageState();
// }

// class _JobDetailsPageState extends State<JobDetailsPage> {
//   Timer? _imagePromptTimer;
//   bool _isImagePromptActive = false;
//   String _qrData = '';
// bool _isLoadingQr = false;

//    void _startImagePromptTimer() {
//     _imagePromptTimer = Timer.periodic(Duration(minutes: 30), (timer) async {
//       if (widget.jobDetails['status'] != 'workdone') {
//         setState(() {
//           _isImagePromptActive = true;
//         });
//         _showImagePrompt();
//       } else {
//         _imagePromptTimer?.cancel();
//       }
//     });
//   }
//   void _showImagePrompt() async {
//     // Play a sound (you can use any sound package like `audioplayers`)
//     // Example: AudioPlayer().play(AssetSource('sound.mp3'));

//     // Show a dialog that cannot be dismissed
//     await showDialog(
//       context: context,
//       barrierDismissible: false, // Prevent closing the dialog
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Time to Capture Progress!'),
//           content: Text('Please take a picture of the work you have done.'),
//           actions: [
//             TextButton(
//               onPressed: () async {
//                 // Navigate to the camera page
//                 final imagePath = await Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => CameraPage(),
//                   ),
//                 );

//                 if (imagePath != null) {
//                   // Upload the image to Supabase
//                   await _uploadImageToSupabase(imagePath);
//                   setState(() {
//                     _isImagePromptActive = false;
//                   });
//                   Navigator.of(context).pop(); // Close the dialog
//                 }
//               },
//               child: Text('Open Camera'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//   Future<void> _uploadImageToSupabase(String imagePath) async {
//     final file = File(imagePath);
//     final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
//     final bucket = Supabase.instance.client.storage.from('documents');

//     try {
//       await bucket.upload(fileName, file);
//       print('Image uploaded to Supabase: $fileName');
//     } catch (e) {
//       print('Error uploading image to Supabase: $e');
//     }
//   }

// Future<void> _loadQrData() async {
//   setState(() {
//     _isLoadingQr = true;
//   });
  
//   try {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;
    
//     final workerId = user.uid;
    
//     // Get createAt from Firestore
//     final workerDoc = await FirebaseFirestore.instance
//         .collection('worker_logins')
//         .doc(workerId)
//         .get();
    
//     final createdAt = workerDoc.data()?['createdAt'] ?? '';
    
//     // Get timestamp and userPhone from Realtime Database
//     final jobSnapshot = await FirebaseDatabase.instance
//         .ref('jobs/${widget.jobId}')
//         .get();
    
//     if (jobSnapshot.exists) {
//       final jobData = Map<String, dynamic>.from(jobSnapshot.value as Map);
//       final timestamp = jobData['timestamp'] ?? '';
//       final userPhone = jobData['userPhone'] ?? '';
      
//       // Combine data in required format
//       setState(() {
//         _qrData = '$createdAt$timestamp$userPhone';
//       });
      
//       // Save to worker_logins for verification
//       await FirebaseFirestore.instance
//           .collection('worker_logins')
//           .doc(workerId)
//           .update({
//         'verificationQrData': _qrData,
//       });
//     }
//   } catch (e) {
//     print('Error loading QR data: $e');
//   } finally {
//     setState(() {
//       _isLoadingQr = false;
//     });
//   }
// }
//   late StreamSubscription _jobSubscription;
//   final DatabaseReference _workerLocationRef = FirebaseDatabase.instance.ref();
//   late Map<String, dynamic> jobDetails;
//   late LatLng _userLocation;
//   late LatLng _workerLocation;
//   final MapController _mapController = MapController();
//   Timer? _locationUpdateTimer;
//   List<LatLng> _route = []; // List of LatLng points for the route
//   bool _isLoadingRoute = false; // To show loading state
//   String _routeError = ''; // To display any route errors

//   @override
// void initState() {
//   super.initState();
//   _startImagePromptTimer();
//   jobDetails = widget.jobDetails; // Initialize with the passed details
//   _userLocation = LatLng(
//     jobDetails['joblocation']['latitude'],
//     jobDetails['joblocation']['longitude'],
//   );
//   // For demo, we'll set worker location slightly offset from user
//   // In a real app, you'd get this from the worker's current location
//  _workerLocation = _userLocation; // Default to user location initially

//   // Fetch the worker's current location
//   _fetchWorkerLocation();

//   _listenToJobUpdates();
//   _startLocationUpdates();
//   _loadQrData(); // Add this line
// }
//   @override
//   void dispose() {
//     _jobSubscription.cancel();
//     _imagePromptTimer?.cancel();
//     _stopLocationUpdates();
//     super.dispose();
//   }

//   void _startLocationUpdates() {
//     // Update location every 5 seconds
//     _locationUpdateTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
//       final position = await _getCurrentLocation();
//       if (position != null) {
//         _updateWorkerLocation(position);
//       }
//       _fetchRoute();
//     });
//   }

//   void _stopLocationUpdates() {
//     _locationUpdateTimer?.cancel();
//     _locationUpdateTimer = null;
//   }

//   void _updateWorkerLocation(Position position) {
//     final workerId = FirebaseAuth.instance.currentUser?.uid;
//     final locationData = {
//       'latitude': position.latitude,
//       'longitude': position.longitude,
//     };

//     // Update worker's location in Firebase
//     _workerLocationRef
//         .child('workers/$workerId/workerLocation')
//         .set(locationData)
//         .then((_) {
//       print('Worker location updated: $locationData');
//     }).catchError((error) {
//       print('Failed to update worker location: $error');
//     });
//   }

//   Future<Position?> _getCurrentLocation() async {
//     try {
//       // Check if location services are enabled
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//       if (!serviceEnabled) {
//         print('Location services are disabled.');
//         return null;
//       }

//       // Check location permissions
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//         if (permission == LocationPermission.denied) {
//           print('Location permissions are denied.');
//           return null;
//         }
//       }

//       if (permission == LocationPermission.deniedForever) {
//         print('Location permissions are permanently denied.');
//         return null;
//       }

//       // Fetch the current location
//       return await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//     } catch (e) {
//       print('Error fetching location: $e');
//       return null;
//     }
//   }

//   Future<void> _fetchRoute() async {
//     setState(() {
//       _isLoadingRoute = true; // Show loading indicator
//       _routeError = ''; // Clear previous errors
//     });

//     try {
//       final start = _workerLocation; // Worker's current location
//       final end = _userLocation; // Job location

//       // Fetch the route using OSRM API
//       final url = Uri.parse(
//         'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
//       );

//       print('Fetching route from OSRM: $url'); // Debugging: Print the URL

//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         print('OSRM Response: $data'); // Debugging: Print the API response

//         if (data['routes'] != null && data['routes'].isNotEmpty) {
//           final route = data['routes'][0]['geometry']['coordinates'] as List;

//           // Convert the route coordinates to LatLng points
//           final routePoints =
//               route.map<LatLng>((point) => LatLng(point[1], point[0])).toList();

//           setState(() {
//             _route = routePoints; // Update the route points
//             _isLoadingRoute = false; // Hide loading indicator
//           });
//           print('Route Updated: $_route'); // Debugging
//         } else {
//           setState(() {
//             _routeError = 'No route found between the locations.';
//             _isLoadingRoute = false; // Hide loading indicator
//           });
//           print('No route found in OSRM response');
//         }
//       } else {
//         setState(() {
//           _routeError = 'Failed to fetch route: ${response.statusCode}';
//           _isLoadingRoute = false; // Hide loading indicator
//         });
//         print('Failed to fetch route: ${response.statusCode}');
//       }
//     } catch (e) {
//       setState(() {
//         _routeError = 'Error fetching route: $e';
//         _isLoadingRoute = false; // Hide loading indicator
//       });
//       print('Error fetching route: $e');
//     }
//   }

//   Future<void> _fetchWorkerLocation() async {
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null) return;

//   final workerId = user.uid;
//   final workerLocationRef =
//       FirebaseDatabase.instance.ref('workers/$workerId/workerLocation');

//   final snapshot = await workerLocationRef.get();
//   if (snapshot.exists) {
//     final locationData = snapshot.value as Map?;
//     if (locationData != null) {
//       final latitude = locationData['latitude'];
//       final longitude = locationData['longitude'];
//       if (latitude != null && longitude != null) {
//         setState(() {
//           _workerLocation = LatLng(latitude, longitude); // Update worker location
//         });
//         print('Worker Location Updated: $_workerLocation'); // Debugging
//       }
//     }
//   }
// }

//   void _listenToJobUpdates() {
//     final databaseRef = FirebaseDatabase.instance.ref();

//     _jobSubscription =
//         databaseRef.child('jobs/${widget.jobId}').onValue.listen((event) {
//       if (!event.snapshot.exists) {
//         // Job has been moved or deleted
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Job has been completed or moved.')),
//         );
//         Navigator.pop(context); // Redirect back to the previous page
//         return;
//       }

//       // Update the jobDetails with new data
//       setState(() {
//         jobDetails = Map<String, dynamic>.from(event.snapshot.value as Map);
//         _userLocation = LatLng(
//           jobDetails['joblocation']['latitude'],
//           jobDetails['joblocation']['longitude'],
//         );
//       });

//       // Handle status update if needed
//       if (jobDetails['status'] == 'work done') {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Job has been marked as completed.')),
//         );
//         Navigator.pop(context); // Redirect back to the previous page
//       }
//     });
//   }

//   @override
// Widget build(BuildContext context) {
//   return Scaffold(
//     appBar: AppBar(
//       backgroundColor: Colors.transparent,
//       elevation: 0,
//       leading: IconButton(
//         icon: Container(
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             shape: BoxShape.circle,
//           ),
//           child: Icon(Icons.arrow_back, color: Colors.black),
//         ),
//         onPressed: () => Navigator.pop(context),
//       ),
//     ),
//     extendBodyBehindAppBar: true,
//     body: Stack(
//       children: [
//         // Map background
//         _buildMap(),

//         // Bottom sheet
//         Align(
//           alignment: Alignment.bottomCenter,
//           child: _buildBottomSheet(context),
//         ),
        
//         // QR Code Floating Action Button
//         Positioned(
//           right: 16,
//           bottom: 360, // Position above the bottom sheet
//           child: FloatingActionButton(
//             onPressed: () => _showQrCode(context),
//             backgroundColor: Colors.white,
//             child: Icon(Icons.qr_code, color: Colors.blue),
//           ),
//         ),
//       ],
//     ),
//   );
// }
//   void _showQrCode(BuildContext context) {
//   print('QR Code Icon Pressed'); // Debugging
//   if (_qrData.isEmpty) {
//     print('QR Data is empty'); // Debugging
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('QR Data is empty. Please try again.')),
//     );
//     return;
//   }
//   showDialog(
//     context: context,
//     builder: (BuildContext context) {
//       return AlertDialog(
//         title: Text('Verification QR Code'),
//         content: Container(
//           constraints: BoxConstraints(maxHeight: 300), // Set max height
//           child: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min, // Use min to fit content
//               children: [
//                 SizedBox(
//                   width: 200, // Constrain QR code size
//                   height: 200,
//                   child: QrImageView(
//                     data: _qrData,
//                     version: QrVersions.auto,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Close'),
//           ),
//         ],
//       );
//     },
//   );
// }
//   Widget _buildMap() {
//     return FlutterMap(
//       mapController: _mapController,
//       options: MapOptions(
//         initialCenter: _userLocation,
//         minZoom: 5.0,
//         maxZoom: 15.0,
//       ),
//       children: [
//         TileLayer(
//           urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//           subdomains: ['a', 'b', 'c'],
//         ),
//         if (_route.isNotEmpty)
//           PolylineLayer(
//             polylines: [
//               Polyline(
//                 points: _route, // Use the fetched route points
//                 strokeWidth: 4.0,
//                 color: Colors.blue,
//               ),
//             ],
//           ),
//         MarkerLayer(
//           markers: [
//             // User marker (blue)
//             Marker(
//               width: 40.0,
//               height: 40.0,
//               point: _userLocation,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.blue,
//                   shape: BoxShape.circle,
//                   border: Border.all(color: Colors.white, width: 2),
//                 ),
//                 child: Icon(
//                   Icons.person,
//                   color: Colors.white,
//                   size: 20,
//                 ),
//               ),
//             ),
//             // Worker marker (green)
//             Marker(
//               width: 40.0,
//               height: 40.0,
//               point: _workerLocation,
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.green,
//                   shape: BoxShape.circle,
//                   border: Border.all(color: Colors.white, width: 2),
//                 ),
//                 child: Icon(
//                   Icons.handyman,
//                   color: Colors.white,
//                   size: 20,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildBottomSheet(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20.0),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black12,
//             blurRadius: 10,
//             offset: Offset(0, -2),
//           ),
//         ],
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Job Details Title
//           Text(
//             'Job Details',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           SizedBox(height: 16),

//           // User Card with Name and Phone
//           // User Card with Name and Message text field
//           Container(
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Row(
//               children: [
//                 // User avatar
//                 CircleAvatar(
//                   radius: 20,
//                   backgroundColor: Colors.grey[300],
//                   child: Icon(Icons.person, color: Colors.grey[600]),
//                 ),
//                 SizedBox(width: 12),
//                 // User details and message field
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         jobDetails['userName'] ?? 'User Name',
//                         style: TextStyle(
//                             fontSize: 16, fontWeight: FontWeight.w500),
//                       ),
//                       SizedBox(height: 4),
//                       // Message text field
//                       Container(
//                         height: 36,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(18),
//                           border: Border.all(color: Colors.grey[300]!),
//                         ),
//                         child: TextField(
//                           decoration: InputDecoration(
//                             hintText:
//                                 'Message ${jobDetails['userName'] ?? 'User'}',
//                             hintStyle: TextStyle(
//                                 fontSize: 16, color: Colors.grey[500]),
//                             prefixIcon: Icon(Icons.message,
//                                 size: 20, color: Colors.grey[600]),
//                             border: InputBorder.none,
//                             isDense: true,
//                           ),
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//                 // Call button - keep this as is
//                 IconButton(
//                   icon: Icon(Icons.phone, color: Colors.blue),
//                   onPressed: () => _callUser(jobDetails['userPhone']),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(height: 16),

//           // Job Location
//           Container(
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Row(
//   children: [
//     CircleAvatar(
//       radius: 20,
//       backgroundColor: Colors.blue,
//       child: Icon(Icons.location_on, color: Colors.white),
//     ),
//     SizedBox(width: 12),
//     Expanded( // Use Expanded to take up remaining space
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Job Location',
//             style: TextStyle(
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           SizedBox(height: 4),
//           Text(
//             '${jobDetails['joblocation']['address']}',
//             style: TextStyle(fontSize: 14, color: Colors.grey[600]),
//             maxLines: 2, // Allow text to wrap to a maximum of 2 lines
//             overflow: TextOverflow.ellipsis, // Add ellipsis if text overflows
//           ),
//         ],
//       ),
//     ),
//   ],
// ),
//           ),  
//           SizedBox(height: 20),

//           // Navigation and End Job buttons
//           Row(
//             children: [
//               // Navigate button
//               Expanded(
//                 child: OutlinedButton.icon(
//                     style: OutlinedButton.styleFrom(
//                       minimumSize: Size(180, 60),
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                       side: BorderSide(color: Colors.blue),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(38),
//                       ),
//                     ),
//                     onPressed: () {
//                       final lat = jobDetails['joblocation']['latitude'];
//                       final lng = jobDetails['joblocation']['longitude'];
//                       _openNavigation(context, lat, lng);
//                     },
//                     icon: Icon(Icons.navigation, size: 18),
//                     label: Text(
//                       'Navigate',
//                       style: TextStyle(fontSize: 18),
//                     )),
//               ),
//               SizedBox(width: 12),

//               // End Job button
//               Expanded(
//                 child: ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 12),
//                     backgroundColor: Colors.green,
//                     minimumSize: Size(180, 60),
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(38),
//                     ),
//                   ),
//                   onPressed: () => _endJob(context),
//                   label: Text(
//                     'End Job',
//                     style: TextStyle(
//                       fontSize: 18, // Increase the font size here
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   void _callUser(String? phoneNumber) async {
//     if (phoneNumber == null || phoneNumber.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No phone number available.')),
//       );
//       return;
//     }

//     final url = 'tel:$phoneNumber';
//     if (await canLaunchUrl(Uri.parse(url))) {
//       await launchUrl(Uri.parse(url));
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Could not launch phone call.')),
//       );
//     }
//   }

//   void _openNavigation(
//       BuildContext context, double latitude, double longitude) async {
//     final url =
//         'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude';
//     if (await canLaunchUrl(Uri.parse(url))) {
//       await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Could not open navigation.')),
//       );
//     }
//   }

//   void _endJob(BuildContext context) async {
//     final user = FirebaseAuth.instance.currentUser;

//     if (user == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No user logged in.')),
//       );
//       return;
//     }

//     // Get the worker's UID
//     final workerId = user.uid;

//     // Reference to the worker's data in the Realtime Database
//     final databaseRef = FirebaseDatabase.instance.ref();
//     final workerRef = databaseRef.child('workers/$workerId');

//     try {
//       // Update the worker's availability to "available"
//       await workerRef.update({
//         'availability': 'available',
//       });

//       // Navigate to the PaymentRequestPage
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (context) => PaymentRequestPage(
//             jobDetails: jobDetails,
//             jobId: widget.jobId,
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Failed to update worker status: $e')),
//       );
//     }
//   }
// }

// class CameraPage extends StatefulWidget {
//   @override
//   _CameraPageState createState() => _CameraPageState();
// }

// class _CameraPageState extends State<CameraPage> {
//   late CameraController _cameraController;
//   late Future<void> _initializeControllerFuture;

//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }

//   Future<void> _initializeCamera() async {
//     final cameras = await availableCameras();
//     _cameraController = CameraController(
//       cameras.first,
//       ResolutionPreset.medium,
//     );
//     _initializeControllerFuture = _cameraController.initialize();
//   }

//   @override
//   void dispose() {
//     _cameraController.dispose();
//     super.dispose();
//   }

//   Future<String?> _takePicture() async {
//     try {
//       await _initializeControllerFuture;
//       final image = await _cameraController.takePicture();
//       return image.path;
//     } catch (e) {
//       print('Error taking picture: $e');
//       return null;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Capture Work Progress'),
//         automaticallyImplyLeading: false, // Prevent going back
//       ),
//       body: FutureBuilder<void>(
//         future: _initializeControllerFuture,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.done) {
//             return CameraPreview(_cameraController);
//           } else {
//             return Center(child: CircularProgressIndicator());
//           }
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () async {
//           final imagePath = await _takePicture();
//           if (imagePath != null) {
//             Navigator.of(context).pop(imagePath); // Return the image path
//           }
//         },
//         child: Icon(Icons.camera),
//       ),
//     );
//   }
// }