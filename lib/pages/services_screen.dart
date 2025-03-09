import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:geolocator/geolocator.dart';
import 'package:handzy/pages/user_job_payment_page.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:handzy/pages/razorpay_handler.dart';
import 'dart:math' as math;

import 'package:url_launcher/url_launcher.dart';

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the screen size to make layout responsive
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Services',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 32 : 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'What do you need help with?',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      isSmallScreen ? 0.8 : 0.9, // Adjusted aspect ratio
                ),
                delegate: SliverChildListDelegate([
                  _buildServiceCard(
                    context,
                    'Electrician',
                    'lib/assets/images/electrician.png',
                    const ElectricianPage(),
                    isAvailable: true,
                    status: 'Available Now',
                    color: Colors.blue,
                  ),
                  _buildServiceCard(
                    context,
                    'Plumber',
                    'lib/assets/images/plumber.png',
                    const PlumberPage(),
                    rating: '4.9 ★',
                    color: Colors.green,
                  ),
                  _buildServiceCard(
                    context,
                    'AC Repair',
                    'lib/assets/images/ac_repair.png',
                    const AcRepairPage(),
                    status: '30min ETA',
                    color: Colors.orange,
                  ),
                  _buildServiceCard(
                    context,
                    'Fridge Repair',
                    'lib/assets/images/fridge_repair.png',
                    const FridgeRepairPage(),
                    isAvailable: true,
                    color: Colors.purple,
                  ),
                  _buildServiceCard(
                    context,
                    'Towing',
                    'lib/assets/images/towing.png',
                    const TowingPage(),
                    status: '30min ETA',
                    color: Colors.red,
                  ),
                  _buildServiceCard(
                    context,
                    'RO Service',
                    'lib/assets/images/ro_service.png',
                    const RoServicePage(),
                    rating: '4.8 ★',
                    color: Colors.teal,
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    String imagePath,
    Widget page, {
    String? status,
    String? rating,
    bool isAvailable = false,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallCard = constraints.maxWidth < 160;
        // Calculate reduced padding and spacing for smaller cards
        final padding = isSmallCard ? 6.0 : 12.0;
        final iconSize = isSmallCard ? 50.0 : 70.0;
        final titleFontSize = isSmallCard ? 14.0 : 18.0;
        final statusFontSize = isSmallCard ? 11.0 : 13.0;
        final verticalSpacing = isSmallCard ? 4.0 : 8.0;

        return GestureDetector(
          onTap: () {
            if (FirebaseAuth.instance.currentUser != null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => page),
              );
            } else {
              Navigator.pushNamed(context, '/userLogin');
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(padding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon container with fixed size
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      imagePath,
                      width: iconSize * 0.5,
                      height: iconSize * 0.5,
                      color: color,
                    ),
                  ),
                ),
                SizedBox(height: verticalSpacing),
                // Title with constrained height
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Optional status/rating with conditional rendering
                if (status != null || rating != null) ...[
                  SizedBox(height: verticalSpacing * 0.5),
                  if (status != null)
                    Text(
                      status,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: statusFontSize,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (rating != null)
                    Text(
                      rating,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: statusFontSize,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
                const Spacer(), // This pushes the "Book" text to the bottom
                // Book button
                Text(
                  'Book →',
                  style: TextStyle(
                    color: color,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ElectricianPage extends StatefulWidget {
  const ElectricianPage({super.key});

  @override
  State<ElectricianPage> createState() => _ElectricianPageState();
}

class _ElectricianPageState extends State<ElectricianPage> {
  DatabaseReference? _jobRef;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  final MapController _mapController = MapController();
  LatLng _center = LatLng(20.5937, 78.9629); // India's center
  List<Marker> _markers = [];
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _jobRef = FirebaseDatabase.instance.ref('jobs');
    _getCurrentLocation();
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _markers = [
          Marker(
            point: _center,
            width: 80,
            height: 80,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      });
      _mapController.move(_center, 13);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions =
              data.map((item) => item['display_name'] as String).toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      setState(() => _suggestions = []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = "https://nominatim.openstreetmap.org/reverse?format=json" "&lat=${position.latitude}&lon=${position.longitude}";

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _locationController.text = data['display_name'];
            _center = LatLng(position.latitude, position.longitude);
            _selectedLocation = _center; // Store the coordinates
            _markers = [
              Marker(
                point: _center,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ];
          });
          _mapController.move(_center, 13);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } else if (permission == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (permission == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text =
              data['display_name']; // Update location text
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: $e')),
      );
    }
  }

  Future<void> _postJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final name = userData?['name'] ?? 'Unknown';
      final phone = userData?['phone'] ?? 'Unknown';
      final email = userData?['email'] ?? 'Unknown'; // Get email if available
      final location = _locationController.text;
      final houseAddress = _houseAddressController.text;

      if (location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location.')),
        );
        return;
      }
      if (houseAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a House Address.')),
        );
        return;
      }

      // Instead of immediately posting the job, open the payment flow
      // with user information pre-filled
      _initiatePayment(
          context, user.uid, name, phone, email, location, houseAddress);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

// Add this new method to handle payment initiation
  Future<void> _initiatePayment(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String userEmail,
      String location,
      String houseAddress) async {
    // Create a payment handler
    final paymentHandler = RazorpayHandler(
      onPaymentSuccess: (String paymentId, String orderId) {
        // After successful payment, proceed with job posting
        _completeJobPosting(context, userId, userName, userPhone, location,
            houseAddress, paymentId);
      },
      onPaymentError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $errorMessage')),
        );
      },
    );

    // Initiate payment with ₹20 fixed amount
    paymentHandler.initiatePayment(
      amount: 2000, // ₹20 in paise
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
    );
  }

// Add this method to complete job posting after successful payment
  Future<void> _completeJobPosting(
    BuildContext context,
    String userId,
    String userName,
    String userPhone,
    String location,
    String houseAddress,
    String paymentId,
  ) async {
    try {
      // Use the stored coordinates instead of parsing from the text
      final jobLat = _selectedLocation?.latitude ?? _center.latitude;
      final jobLng = _selectedLocation?.longitude ?? _center.longitude;

      final newJobRef = _jobRef?.push();
      final jobId = newJobRef?.key;

      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create job.')),
        );
        return;
      }

      String timestamp = DateTime.now().toIso8601String();
      await newJobRef?.set({
        'user_id': userId,
        'userName': userName,
        'userPhone': userPhone,
        'joblocation': {
          'latitude': jobLat,
          'longitude': jobLng,
          'address':
              "$houseAddress,$location", // Store the display address as well
        },
        'job': 'Electric Repair',
        'status': 'pending',
        'worker_id': null,
        'workerName': null,
        'timestamp': timestamp,
        'fee_id': paymentId,
        'fee_amount': 20, // ₹20 fixed amount
        'fee_status': 'completed',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful! Job posted.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(jobId: jobId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40), // Add some spacing

                  // Service Info Row - Made scrollable to prevent overflow
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 4),
                        const Text('24/7 Service'),
                        const SizedBox(width: 16),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const Text('4.9 Rating'),
                        const SizedBox(width: 16),
                        const Icon(Icons.bolt, size: 16),
                        const Text('30min Response'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title and Description
                  const Text(
                    'Electrician Services',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We provide top-notch electrician services across India, ensuring quick and reliable assistance for all your electrical needs.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),

                  // Location Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(38),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _locationController,
                      onChanged: _fetchSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Enter your location',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getLocation,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(38),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8), // Add some spacing

                  // House Address Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(38),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _houseAddressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your house address',
                        prefixIcon: const Icon(Icons.home,
                            color: Colors.grey), // Added prefix icon
                        border: OutlineInputBorder(
                          // Use OutlineInputBorder
                          borderRadius: BorderRadius.circular(38),
                          borderSide: BorderSide.none,
                        ),
                        filled: true, // Enable filling
                        fillColor: Colors.grey[100], // Set fill color
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map Section
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(38),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(38),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    minZoom: 13.0,
                    onTap: (_, point) async {
                      setState(() {
                        _center = point;
                        _selectedLocation = point; // Store the coordinates
                        _markers = [
                          Marker(
                            point: point,
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ];
                      });

                      // Geocode the tapped location to get the address
                      await _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),

            // Status Section - Fixed the overflow issue here
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First row with availability info
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Available Now'),
                      const SizedBox(width: 16),
                      const Text('Instant Booking'),
                    ],
                  ),
                  const SizedBox(height: 8), // Add spacing between rows
                  // Second row with ETA info
                  Row(
                    children: const [
                      Icon(Icons.access_time, size: 16),
                      SizedBox(width: 4),
                      Text('30min ETA'),
                      SizedBox(width: 8),
                      Text('Quick Response'),
                    ],
                  ),
                ],
              ),
            ),

            // Post Job Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _postJob(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(38),
                  ),
                ),
                child: const Text(
                  'Post the Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatistic('10k+', 'Jobs Done'),
                  _buildStatistic('4.9', 'Rating'),
                  _buildStatistic('30min', 'Avg. Response'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class JobDetailsPage extends StatefulWidget {
  final String jobId;

  const JobDetailsPage({super.key, required this.jobId});

  @override
  _JobDetailsPageState createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage>
    with SingleTickerProviderStateMixin {
  late DatabaseReference _jobRef;
  String _workerAddress = 'Fetching address...';
  LatLng _workerLocation = LatLng(0, 0);
  final String _pin = "1234"; // Define the _pin variable
  late StreamSubscription _jobSubscription;
  Map<String, dynamic> _jobDetails = {};
  Map<String, dynamic> _workerDetails = {};
  late AnimationController _progressController;
  List<LatLng> _workerPositions = [];
  bool _isWorkerAssigned = false;
  List<LatLng> _route = []; // Store the route for the map
  String _distance = "Calculating...";
  String _eta = "1";
  Timer? _locationUpdateTimer;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _fetchWorkerLiveLocation();
    _jobRef = FirebaseDatabase.instance.ref('jobs/${widget.jobId}');
    listenToJobUpdates(widget.jobId);
    _mapController = MapController();

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();

    _generateWorkerPositions();

    _jobSubscription = _jobRef.onValue.listen((event) {
      final jobData = event.snapshot.value as Map?;
      if (jobData != null) {
        setState(() {
          _jobDetails = jobData.cast<String, dynamic>();
          _isWorkerAssigned = _jobDetails['worker_id'] != null;
          if (_isWorkerAssigned) {
            _fetchWorkerDetails(_jobDetails['worker_id']);
            _progressController.stop();

            // Start periodic updates for worker location and ETA
            _startLocationUpdates();
          } else {
            _progressController.repeat();
            _stopLocationUpdates();
          }

          if (_jobDetails['status'] == 'accepted') {
            _fetchRoute(); // Fetch the route when job is accepted
          } else {
            _route.clear(); // Clear the route when job is pending
          }
        });
      }
    });
  }

  Future<void> _fetchWorkerLiveLocation() async {
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

          // Geocode the worker's location
          _geocodeWorkerLocation(latitude, longitude);
        }
      }
    }
  }

  Future<void> _geocodeWorkerLocation(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final response = await http.get(url, headers: {
        'User-Agent': 'YourAppName', // Replace with your app name
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['display_name'] as String?;

        if (address != null) {
          setState(() {
            _workerAddress = address; // Update the worker's address
          });
          print('Geocoded Address: $_workerAddress'); // Debugging
        } else {
          setState(() {
            _workerAddress = 'Address not found';
          });
        }
      } else {
        setState(() {
          _workerAddress = 'Failed to fetch address';
        });
        print('Failed to geocode: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _workerAddress = 'Error fetching address';
      });
      print('Error geocoding: $e');
    }
  }

  void _centerMapOnWorker() {
    if (_isWorkerAssigned &&
        _jobDetails['workerLocation'] != null &&
        _jobDetails['workerLocation']['latitude'] != null &&
        _jobDetails['workerLocation']['longitude'] != null) {
      _mapController.move(
        LatLng(_jobDetails['workerLocation']['latitude'],
            _jobDetails['workerLocation']['longitude']),
        13.0, // Zoom level
      );
    }
  }

  void _callEmergencyServices() async {
    final Uri uri = Uri.parse('tel:911');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not initiate emergency call')),
      );
    }
  }

  Future<List<LatLng>> fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final route = data['routes'][0]['geometry']['coordinates'] as List;

      return route.map<LatLng>((point) => LatLng(point[1], point[0])).toList();
    } else {
      throw Exception('Failed to load route');
    }
  }

  Future<void> _fetchRoute() async {
    try {
      final workerId = _jobDetails['worker_id'];

      if (workerId != null) {
        // Fetch worker's location from the workers directory in Firebase
        final workerRef = FirebaseDatabase.instance.ref('workers/$workerId');
        final workerSnapshot = await workerRef.get();

        if (workerSnapshot.exists) {
          final workerData = workerSnapshot.value as Map;
          final workerLat = workerData['workerLocation']?['latitude'];
          final workerLng = workerData['workerLocation']?['longitude'];

          // Fetch the job's location
          final jobLat = _jobDetails['joblocation']?['latitude'];
          final jobLng = _jobDetails['joblocation']?['longitude'];

          // Check if both the worker and job locations are available
          if (workerLat != null &&
              workerLng != null &&
              jobLat != null &&
              jobLng != null) {
            List<LatLng> route = await fetchRoute(
                LatLng(workerLat, workerLng), LatLng(jobLat, jobLng));

            setState(() {
              _route = route; // Update the route
            });
          } else {
            print('Error: Missing location data for worker or job');
          }
        }
      }
    } catch (e) {
      print('Error fetching route: $e');
    }
  }

  Future<void> _fetchWorkerDetails(String workerId) async {
    try {
      // Fetch worker profile from Firestore
      final workerDoc = await FirebaseFirestore.instance
          .collection('worker_logins')
          .doc(workerId)
          .get();

      if (workerDoc.exists) {
        setState(() {
          _workerDetails = workerDoc.data() ?? {};
        });

        // Also fetch worker location and rating from Realtime Database
        _fetchWorkerLocation(workerId);
        _fetchWorkerRating(workerId);
      }
    } catch (e) {
      {}
    }
  }

  Future<void> _fetchWorkerRating(String workerId) async {
    try {
      // Reference to the worker in Firebase Realtime Database
      final workerRef = FirebaseDatabase.instance.ref('workers/$workerId');

      // Fetch the snapshot of worker data
      final snapshot = await workerRef.get();

      if (snapshot.exists) {
        final workerData = snapshot.value as Map?;

        if (workerData != null && workerData['rating'] != null) {
          setState(() {
            // Update the _workerDetails map with the worker's rating
            _workerDetails['rating'] = workerData['rating'];
          });
        }
      }
    } catch (e) {
      print('Error fetching worker rating: $e');
    }
  }

  void _startLocationUpdates() {
    // Cancel existing timer if any
    _stopLocationUpdates();

    // Update location every 3 seconds instead of 10
    _locationUpdateTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (_isWorkerAssigned) {
        _fetchWorkerLocation(_jobDetails['worker_id']);
        _updateDistanceAndEta();
        _fetchRoute();
      } else {
        _stopLocationUpdates();
      }
    });

    // Initial update
    _fetchWorkerLocation(_jobDetails['worker_id']);
    _updateDistanceAndEta();
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _fetchWorkerLocation(String workerId) async {
    try {
      // Reference to the worker's location in Firebase Realtime Database
      final workerLocationRef =
          FirebaseDatabase.instance.ref('workers/$workerId/workerLocation');

      // Fetch the snapshot of worker location
      final snapshot = await workerLocationRef.get();

      if (snapshot.exists) {
        final locationData = snapshot.value as Map?;

        if (locationData != null) {
          // Check if 'latitude' and 'longitude' keys exist in the location data
          final latitude = locationData['latitude'];
          final longitude = locationData['longitude'];

          if (latitude != null && longitude != null) {
            setState(() {
              // Update the _workerDetails map with the worker's location
              _workerDetails['workerLocation'] = locationData;

              // Also update the job details with the worker's current location
              // This ensures the map marker uses the latest position
              if (_jobDetails['workerLocation'] == null) {
                _jobDetails['workerLocation'] = {};
              }
              _jobDetails['workerLocation']['latitude'] = latitude;
              _jobDetails['workerLocation']['longitude'] = longitude;
            });

            // Call a method to geocode the location (optional, if needed for further processing)
            _geocodeWorkerLocation(latitude, longitude);
          } else {
            print("Latitude or Longitude is missing in worker location data.");
          }
        } else {
          print("Worker location data is null.");
        }
      } else {
        print("Worker location does not exist in the database.");
      }
    } catch (e) {
      print('Error fetching worker location: $e');
    }
  }

  void _updateDistanceAndEta() {
    try {
      final workerLat = _workerDetails['workerLocation']?['latitude'];
      final workerLng = _workerDetails['workerLocation']?['longitude'];
      final jobLat = _jobDetails['joblocation']?['latitude'];
      final jobLng = _jobDetails['joblocation']?['longitude'];

      if (workerLat != null &&
          workerLng != null &&
          jobLat != null &&
          jobLng != null) {
        // Calculate distance using Haversine formula
        const earthRadius = 6371000; // in meters
        final dLat = (jobLat - workerLat) * (pi / 180);
        final dLng = (jobLng - workerLng) * (pi / 180);

        final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(workerLat * (pi / 180)) *
                cos(jobLat * (pi / 180)) *
                sin(dLng / 2) *
                sin(dLng / 2);
        final c = 2 * atan2(sqrt(a), sqrt(1 - a));
        final distance = earthRadius * c; // distance in meters

        // Format distance
        String formattedDistance;
        if (distance >= 1000) {
          formattedDistance = '${(distance / 1000).toStringAsFixed(1)} km';
        } else {
          formattedDistance = '${distance.round()} m';
        }

        // Calculate ETA (assuming 30 km/h average speed)
        final timeInHours = distance / (30 * 1000);
        final timeInMinutes = (timeInHours * 60).round();
        final eta = max(1, timeInMinutes); // Minimum ETA of 1 minute

        setState(() {
          _distance = formattedDistance;
          _eta = eta.toString();
        });
      }
    } catch (e) {
      print('Error calculating distance and ETA: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  // Show trip details bottom sheet
  void _showTripDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),

                  // Location details heading
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Location Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Job location
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _jobDetails['joblocation']?['name'] ??
                                    'Booking Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _jobDetails['joblocation']?['address'] ??
                                    'Job Address',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.favorite_border),
                        SizedBox(width: 16),
                        Icon(Icons.edit),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Worker location
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_jobDetails['job'] ?? 'Professional'} Location',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _workerDetails['address'] ?? 'Worker Address',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.favorite_border),
                        SizedBox(width: 16),
                        Icon(Icons.edit),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),
                  Divider(),

                  // Payment method
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.money, color: Colors.grey),
                            SizedBox(width: 8),
                            Text(
                              'Paying via cash',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Change',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cancel button
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red[700]!),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TextButton(
                        onPressed: () => _showCancellationOptions(),
                        child: Text(
                          'Cancel Service',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.red[700],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Close button
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCancellationOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Job'),
        content: Text('Are you sure you want to cancel or reassign?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelJob();
            },
            child: Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reassignJob();
            },
            child: Text('Cancel & Reassign',
                style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _reassignJob() async {
    try {
      if (_jobDetails['worker_id'] != null) {
        String workerId = _jobDetails['worker_id'];
        DatabaseReference workerRef =
            FirebaseDatabase.instance.ref('workers/$workerId');
        await workerRef.update({
          'availability':
              'available', // Assuming 'availability' is a field in the worker's data
        });
        await _jobRef.update({
          'status': 'pending',
          'worker_id': null,
          'workerName': null,
        });
      }

      setState(() {
        _isWorkerAssigned = false;
        _workerDetails = {};
        _progressController.repeat();
      });
    } catch (e) {
      print('Error reassigning job: $e');
    }
  }

  void _generateWorkerPositions() {
    // Generate 6 random worker positions around the job location
    final random = math.Random();
    final jobLat = _jobDetails['joblocation']?['latitude'] ?? 29.7062;
    final jobLng = _jobDetails['joblocation']?['longitude'] ?? 76.9911;

    _workerPositions = List.generate(6, (index) {
      final lat = jobLat + (random.nextDouble() - 0.5) * 0.02;
      final lng = jobLng + (random.nextDouble() - 0.5) * 0.02;
      return LatLng(lat, lng);
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _jobSubscription.cancel();
    super.dispose();
  }

  void listenToJobUpdates(String jobId) {
    final databaseRef = FirebaseDatabase.instance.ref();

    databaseRef.child('jobs/$jobId').onValue.listen((event) {
      if (!event.snapshot.exists) {
        Navigator.pushReplacementNamed(context, '/home');
        return;
      }

      final jobData = event.snapshot.value as Map;
      final status = jobData['status'];

      // Add this condition to handle payment_pending status
      if (status == 'payment_requested') {
        // Show payment bottom sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => PaymentBottomSheet(
            jobId: jobId,
            jobDetails: jobData.cast<String, dynamic>(),
            workerDetails: _workerDetails,
            onPaymentComplete: () {
              // Handle payment completion
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
        );
      } else if (status == 'workdone') {
        final workerId = jobData['worker_id'];
        if (workerId != null) {
          showRatingDialog(workerId, jobId);
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    });
  }

  void showRatingDialog(String workerId, String jobId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int selectedRating = 0;

        return AlertDialog(
          title: const Text("Rate the Worker"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      Icons.star,
                      color:
                          index < selectedRating ? Colors.yellow : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedRating =
                            index + 1; // Set rating (1-based index)
                      });
                    },
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (selectedRating > 0) {
                  // Update worker's rating in the database
                  await updateWorkerRating(workerId, selectedRating, jobId);
                }

                // Remove the job from the 'jobs' directory
                await FirebaseDatabase.instance
                    .ref()
                    .child('jobs/$jobId')
                    .remove();

                // Close the dialog and navigate to the home page
                Navigator.pop(context); // Close the dialog
                Navigator.pushReplacementNamed(
                    context, '/home'); // Go to home page
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateWorkerRating(
      String workerId, int selectedRating, String jobId) async {
    final workerRef =
        FirebaseDatabase.instance.ref().child('workers/$workerId');
    final workerSnapshot = await workerRef.get();

    if (workerSnapshot.exists) {
      final workerData = workerSnapshot.value as Map;

      double currentRating = (workerData['rating'] as num?)?.toDouble() ?? 0.0;
      int ratingTimes = (workerData['ratingtimes'] as num?)?.toInt() ?? 0;

      // Calculate the new rating
      double latestRating = selectedRating.toDouble();
      double updatedRating =
          (ratingTimes * currentRating + latestRating) / (ratingTimes + 1);

      // Update the worker's data in the database
      await workerRef.update({
        'rating': updatedRating,
        'ratingtimes': ratingTimes + 1,
      });
    }
    // Remove the job from the jobs directory
    final jobRef = FirebaseDatabase.instance.ref().child('jobs/$jobId');
    await jobRef.remove();
  }

  // Function to delete job and redirect to home
  void _cancelJob() async {
    try {
      String workerId = _jobDetails['worker_id'];
      if (_jobDetails['worker_id'] != null) {
        DatabaseReference workerRef =
            FirebaseDatabase.instance.ref('workers/$workerId');
        await workerRef.update({
          'availability': 'available',
          'jobNotification': null,
        });
      }

      await _jobRef.remove(); // Delete job from Firebase
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home'); // Redirect to home
      }
    } catch (e) {
      print("Error deleting job: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobLat = _jobDetails['joblocation']?['latitude'] ?? 29.7062;
    final jobLng = _jobDetails['joblocation']?['longitude'] ?? 76.9911;

    return Scaffold(
      body: Stack(
        children: [
          // Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(_jobDetails['workerLocation']['latitude'],
                  _jobDetails['workerLocation']['longitude']),
              minZoom: 5,
              maxZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: [
                  // Job location marker (stays fixed)
                  Marker(
                    point: LatLng(jobLat, jobLng),
                    child: Icon(
                      Icons.location_on,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  if (_isWorkerAssigned &&
                      _jobDetails['workerLocation'] != null &&
                      _jobDetails['workerLocation']['latitude'] != null &&
                      _jobDetails['workerLocation']['longitude'] != null)
                    Marker(
                      point: LatLng(_jobDetails['workerLocation']['latitude'],
                          _jobDetails['workerLocation']['longitude']),
                      child: Icon(
                        Icons.handyman,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                ],
              ),
              if (_route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
            ],
          ),

          // Safety button on the map
          Positioned(
            top: 50,
            right: 20,
            child: GestureDetector(
              onTap: _callEmergencyServices,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield, color: Colors.red),
                    SizedBox(width: 5),
                    Text(
                      'Safety',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Verified Badge Icon on the map
          Positioned(
            top: 100,
            right: 20,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    _showVerificationDrawer(context);
                  },
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.verified,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
  top: 160,
  right: 20, // Adjust the position as needed
  child: FloatingActionButton(
    onPressed: () => _scanQrCode(context),
    backgroundColor: Colors.white,
    child: Icon(Icons.qr_code_scanner, color: Colors.blue),
  ),
),

          // Bottom sheet styled like the ride-sharing app - now with fixed height and scrollable content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5, // 50% of screen height
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle for the bottom sheet
                  Center(
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                
                  // "Professional on the way" section - fixed at the top
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isWorkerAssigned
                                  ? '${_jobDetails['job'] ?? "Professional"} on the way'
                                  : 'Finding a professional...',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            if (_isWorkerAssigned)
                              Text(
                                '$_distance away',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54,
                                ),
                              ),
                          ],
                        ),
                        if (_isWorkerAssigned)
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Color(0xFF1a5f9c),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Text(
                              '$_eta min',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.2)),

                  // PIN section - fixed part
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Start your booking with PIN',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        Row(
                          children: _pin.split('').map((digit) {
                            return Container(
                              width: 35,
                              height: 35,
                              margin: EdgeInsets.only(left: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  digit,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Make the rest of the content scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Worker details section
                          if (_isWorkerAssigned)
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Worker avatar
                                        CircleAvatar(
                                          radius: 25,
                                          backgroundColor: Colors.blue.withOpacity(0.1),
                                          backgroundImage: _jobDetails['worker_id'] != null
                                              ? NetworkImage(
                                                  'https://dsjeyaorfibuvddayxxw.supabase.co/storage/v1/object/public/documents/workers/${_jobDetails['worker_id']}/profile-picture.jpg')
                                              : null,
                                          child: _jobDetails['worker_id'] == null
                                              ? Icon(
                                                  Icons.person,
                                                  color: Colors.blue,
                                                  size: 30,
                                                )
                                              : null,
                                          onBackgroundImageError: (_, __) {
                                            setState(() {
                                              _jobDetails['worker_id'] = null;
                                            });
                                          },
                                        ),
                                        SizedBox(width: 16),

                                        // Worker details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _workerDetails['name'] ?? 'Professional',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                _jobDetails['job'] ?? 'Service Professional',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Rating
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.star, color: Colors.amber, size: 18),
                                              SizedBox(width: 4),
                                              Text(
                                                '${_workerDetails['rating']?.toStringAsFixed(1) ?? '4.8'}',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber[800],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Worker address
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.location_on, color: Colors.red, size: 16),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _workerAddress,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Call and message buttons
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        // Call button
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: Icon(Icons.call, color: Colors.black87),
                                            onPressed: () =>
                                                _makePhoneCall(_workerDetails['phone'] ?? ''),
                                          ),
                                        ),
                                        SizedBox(width: 12),

                                        // Message button
                                        Expanded(
                                          child: Container(
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(25),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.message, color: Colors.grey),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Message ${_workerDetails['name']?.split(' ')[0] ?? 'Professional'}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Share details button
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                                    child: GestureDetector(
                                      onTap: () {
                                        // Add your share details functionality here
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(25),
                                          border: Border.all(color: Colors.blue, width: 1),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Share details',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(width: 5),
                                            Icon(Icons.share, color: Colors.blue),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                    
                                  // Booking location
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Booking from',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _jobDetails['joblocation']?['address'] ?? 'Job Location',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Issue with Booking & Booking details
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.help_outline, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text(
                                              'Issue with Booking?',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ],
                                        ),
                                        GestureDetector(
                                          onTap: () => _showTripDetails(),
                                          child: Row(
                                            children: [
                                              Text(
                                                'Booking Details',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Icon(Icons.chevron_right, color: Colors.blue),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _scanQrCode(BuildContext context) async {
  print('Starting QR scan...');
  final workerId = _jobDetails['worker_id'];
  if (workerId == null) {
    print('Worker ID is null');
    return;
  }

  // Navigate to the QR scanning page
  final scannedData = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => QrScanPage(),
    ),
  );

  if (scannedData != null) {
    print('Scanned Data: $scannedData');
    // Fetch the verificationQrData from Firestore
    final workerDoc = await FirebaseFirestore.instance
        .collection('worker_logins')
        .doc(workerId)
        .get();

    final verificationQrData = workerDoc.data()?['verificationQrData'];
    print('Verification QR Data: $verificationQrData');

    if (scannedData == verificationQrData) {
      print('Verified!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verified!')),
      );
    } else {
      print('Not Verified!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Not Verified!')),
      );
    }
  } else {
    print('No data scanned');
  }
}
  void _showVerificationDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: EdgeInsets.only(top: 50),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.verified_user, color: Colors.blue),
                title: Text(
                  'Access Aadhar Card to Verify',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  _navigateToAadharVerificationPage(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

// Add this method to navigate to the Aadhar verification page
  void _navigateToAadharVerificationPage(BuildContext context) {
    final workerUid = _jobDetails['worker_id'];
    if (workerUid == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AadharVerificationPage(workerUid: workerUid),
      ),
    );
  }
}

class QrScanPage extends StatefulWidget {
  @override
  _QrScanPageState createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scan QR Code'),
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            Navigator.pop(context, barcode.rawValue);
          }
        },
      ),
    );
  }
}

class AadharVerificationPage extends StatelessWidget {
  final String workerUid;

  const AadharVerificationPage({super.key, required this.workerUid});

  @override
  Widget build(BuildContext context) {
    final baseUrl =
        'https://dsjeyaorfibuvddayxxw.supabase.co/storage/v1/object/public/documents/workers/$workerUid/aadhar';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: FutureBuilder(
          future: _getValidDocumentUrl(baseUrl),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            } else if (snapshot.hasError || !snapshot.hasData) {
              return Text('Failed to load Aadhar document.');
            } else {
              final documentUrl = snapshot.data!;
              if (documentUrl.endsWith('.pdf')) {
                // Use flutter_pdfview for PDF files
                return PDFView(
                  filePath: documentUrl,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: false,
                  onError: (error) {
                    print('PDF Error: $error');
                  },
                  onPageError: (page, error) {
                    print('PDF Page Error: $page, $error');
                  },
                  onPageChanged: (page, total) {
                    print('Page changed: $page/$total');
                  },
                );
              } else {
                // Display image for .jpg, .jpeg, .png
                return Image.network(documentUrl);
              }
            }
          },
        ),
      ),
    );
  }

  Future<String?> _getValidDocumentUrl(String baseUrl) async {
    final supportedExtensions = ['.jpg', '.jpeg', '.png', '.pdf'];

    for (final extension in supportedExtensions) {
      final url = '$baseUrl$extension';
      if (await _checkFileExists(url)) {
        return url;
      }
    }

    return null;
  }

  Future<bool> _checkFileExists(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class RatingDialog extends StatefulWidget {
  final String workerId;
  final VoidCallback onRatingDone;

  const RatingDialog({
    super.key,
    required this.workerId,
    required this.onRatingDone,
  });

  @override
  _RatingDialogState createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedRating = 0;

  void _submitRating() async {
    if (_selectedRating == 0) {
      // Ensure the user selects a rating
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }

    final workerRef =
        FirebaseDatabase.instance.ref('workers/${widget.workerId}');
    final snapshot = await workerRef.get();

    if (snapshot.exists) {
      final workerData = snapshot.value as Map;
      final int ratingTimes = workerData['ratingTimes'] ?? 0;
      final double rating = workerData['rating']?.toDouble() ??
          5.0; // Default to 5 if no rating exists

      double updatedRating;

      // First rating (if ratingTimes == 0, meaning the first rating)
      if (ratingTimes == 0) {
        updatedRating = (_selectedRating + 5) / 2;
      } else {
        // Subsequent ratings: Use the formula (previousRating * ratingTimes + newRating) / (ratingTimes + 1)
        updatedRating =
            (rating * ratingTimes + _selectedRating) / (ratingTimes + 1);
      }

      // Update the worker's rating and increment ratingTimes
      await workerRef.update({
        'rating': updatedRating,
        'ratingTimes': ratingTimes + 1,
      });
    }

    widget.onRatingDone();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate the Worker'),
      backgroundColor: Colors.white,
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          return IconButton(
            onPressed: () {
              setState(() {
                _selectedRating = index + 1;
              });
            },
            icon: Icon(
              Icons.star,
              color: index < _selectedRating ? Colors.yellow : Colors.grey,
              size: 40,
            ),
          );
        }),
      ),
      actions: [
        TextButton(
          onPressed: _submitRating,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}

class PlumberPage extends StatefulWidget {
  const PlumberPage({super.key});

  @override
  State<PlumberPage> createState() => _PlumberPageState();
}

class _PlumberPageState extends State<PlumberPage> {
  DatabaseReference? _jobRef;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  final MapController _mapController = MapController();
  LatLng _center = LatLng(20.5937, 78.9629); // India's center
  List<Marker> _markers = [];
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _jobRef = FirebaseDatabase.instance.ref('jobs');
    _getCurrentLocation();
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _selectedLocation = _center;
        _markers = [
          Marker(
            point: _center,
            width: 80,
            height: 80,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      });
      _mapController.move(_center, 13);
      _reverseGeocode(position.latitude, position.longitude);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions =
              data.map((item) => item['display_name'] as String).toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      setState(() => _suggestions = []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        _reverseGeocode(position.latitude, position.longitude);

        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _selectedLocation = _center;
          _markers = [
            Marker(
              point: _center,
              width: 80,
              height: 80,
              child: Icon(
                Icons.location_on,
                color: Colors.blue,
                size: 40,
              ),
            ),
          ];
        });
        _mapController.move(_center, 13);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } else if (permission == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (permission == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      final url =
          "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text = data['display_name'];
        });
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
  }

  // For your PlumbingPage class, add these methods:

// Modify the existing _postJob method or create it if it doesn't exist:
  Future<void> _postJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final name = userData?['name'] ?? 'Unknown';
      final phone = userData?['phone'] ?? 'Unknown';
      final email = userData?['email'] ?? 'Unknown'; // Get email if available
      final location = _locationController.text;
      final houseAddress = _houseAddressController.text;

      if (location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location.')),
        );
        return;
      }
      if (houseAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a house address.')),
        );
        return;
      }

      // Instead of immediately posting the job, open the payment flow
      // with user information pre-filled
      _initiatePayment(
          context, user.uid, name, phone, email, location, houseAddress);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

// Add this method to handle payment initiation for plumbing jobs
  Future<void> _initiatePayment(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String userEmail,
      String location,
      String houseAddress) async {
    // Create a payment handler
    final paymentHandler = RazorpayHandler(
      onPaymentSuccess: (String paymentId, String orderId) {
        // After successful payment, proceed with job posting
        _completeJobPosting(context, userId, userName, userPhone, location,
            houseAddress, paymentId);
      },
      onPaymentError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $errorMessage')),
        );
      },
    );

    // Initiate payment with ₹20 fixed amount
    paymentHandler.initiatePayment(
      amount: 2000, // ₹20 in paise
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
    );
  }

// Add this method to complete job posting after successful payment
  Future<void> _completeJobPosting(
    BuildContext context,
    String userId,
    String userName,
    String userPhone,
    String location,
    String houseAddress,
    String paymentId,
  ) async {
    try {
      // Use the stored coordinates instead of parsing from the text
      final jobLat = _selectedLocation?.latitude ?? _center.latitude;
      final jobLng = _selectedLocation?.longitude ?? _center.longitude;

      final newJobRef = _jobRef?.push();
      final jobId = newJobRef?.key;

      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create job.')),
        );
        return;
      }

      String timestamp = DateTime.now().toIso8601String();
      await newJobRef?.set({
        'user_id': userId,
        'userName': userName,
        'userPhone': userPhone,
        'joblocation': {
          'latitude': jobLat,
          'longitude': jobLng,
          'address':
              "$houseAddress,$location", // Store the display address as well
        },
        'job': 'Plumbing Services', // Changed to plumbing service
        'status': 'pending',
        'worker_id': null,
        'workerName': null,
        'timestamp': timestamp,
        'fee_id': paymentId,
        'fee_amount': 20, // ₹20 fixed amount
        'fee_status': 'paid',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment successful! Plumbing job posted.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(jobId: jobId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Service 
              //Info Row
              SizedBox(height: 40), 
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(Icons.access_time, size: 16),
                  const SizedBox(width: 4),
                  const Text('24/7 Service'),
                  const SizedBox(width: 16),
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const Text('4.9 Rating'),
                  const SizedBox(width: 16),
                  const Icon(Icons.bolt, size: 16),
                  const Text('30min Response'),
                ],
              ),
              const SizedBox(height: 20),

              // Title and Description
              const Text(
                'Plumbing Services',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We provide expert plumbing services across India, ensuring prompt and reliable assistance for all your plumbing needs.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 20),

              // Location Search
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _locationController,
                  onChanged: _fetchSuggestions,
                  decoration: InputDecoration(
                    hintText: 'Enter your location',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.my_location),
                            onPressed: _getLocation,
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(38),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(height: 8), // Add some spacing

              // House Address Text Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(38),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _houseAddressController,
                  decoration: InputDecoration(
                    hintText: 'Enter your house address',
                    prefixIcon: const Icon(Icons.home,
                        color: Colors.grey), // Added prefix icon
                    border: OutlineInputBorder(
                      // Use OutlineInputBorder
                      borderRadius: BorderRadius.circular(38),
                      borderSide: BorderSide.none,
                    ),
                    filled: true, // Enable filling
                    fillColor: Colors.grey[100], // Set fill color
                  ),
                ),
              ),

              // Suggestions List
              if (_suggestions.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_suggestions[index]),
                        onTap: () async {
                          final url =
                              "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(_suggestions[index])}&format=json&limit=1";
                          final response = await http.get(Uri.parse(url));

                          if (response.statusCode == 200) {
                            final data = jsonDecode(response.body);
                            if (data.isNotEmpty) {
                              final lat = double.parse(data[0]['lat']);
                              final lon = double.parse(data[0]['lon']);
                              setState(() {
                                _locationController.text = _suggestions[index];
                                _suggestions = [];
                                _center = LatLng(lat, lon);
                                _selectedLocation = _center;
                                _markers = [
                                  Marker(
                                    point: _center,
                                    width: 80,
                                    height: 80,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 40,
                                    ),
                                  ),
                                ];
                              });
                              _mapController.move(_center, 13);
                            }
                          }
                        },
                      );
                    },
                  ),
                ),

              // Map
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 13.0,
                      onTap: (_, point) {
                        setState(() {
                          _center = point;
                          _selectedLocation = point;
                          _markers = [
                            Marker(
                              point: point,
                              width: 80,
                              height: 80,
                              child: Icon(
                                Icons.location_on,
                                color: Colors.blue,
                                size: 40,
                              ),
                            ),
                          ];
                        });
                        _reverseGeocode(point.latitude, point.longitude);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),
              ),

              // Status Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Available Now'),
                        const SizedBox(width: 8),
                        const Text('Instant Booking'),
                      ],
                    ),
                    Row(
                      children: const [
                        Icon(Icons.access_time, size: 16),
                        SizedBox(width: 4),
                        Text('30min ETA'),
                        SizedBox(width: 8),
                        Text('Quick Response'),
                      ],
                    ),
                  ],
                ),
              ),

              // Post Job Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _postJob(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Post the Job',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Statistics Section
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatistic('10k+', 'Jobs Done'),
                    _buildStatistic('4.9', 'Rating'),
                    _buildStatistic('30min', 'Avg. Response'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class AcRepairPage extends StatefulWidget {
  const AcRepairPage({super.key});

  @override
  State<AcRepairPage> createState() => _AcRepairPageState();
}

class _AcRepairPageState extends State<AcRepairPage> {
  DatabaseReference? _jobRef;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  final MapController _mapController = MapController();
  LatLng _center = LatLng(20.5937, 78.9629); // India's center
  List<Marker> _markers = [];
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _jobRef = FirebaseDatabase.instance.ref('jobs');
    _getCurrentLocation();
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _markers = [
          Marker(
            point: _center,
            width: 80,
            height: 80,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      });
      _mapController.move(_center, 13);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions =
              data.map((item) => item['display_name'] as String).toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      setState(() => _suggestions = []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = "https://nominatim.openstreetmap.org/reverse?format=json" "&lat=${position.latitude}&lon=${position.longitude}";

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _locationController.text = data['display_name'];
            _center = LatLng(position.latitude, position.longitude);
            _selectedLocation = _center;
            _markers = [
              Marker(
                point: _center,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ];
          });
          _mapController.move(_center, 13);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } else if (permission == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (permission == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text = data['display_name'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: $e')),
      );
    }
  }

  Future<void> _postJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final name = userData?['name'] ?? 'Unknown';
      final phone = userData?['phone'] ?? 'Unknown';
      final email = userData?['email'] ?? 'Unknown';
      final location = _locationController.text;
      final houseAddress = _houseAddressController.text;

      if (location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location.')),
        );
        return;
      }
      if (houseAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a house address.')),
        );
        return;
      }

      _initiatePayment(
          context, user.uid, name, phone, email, location, houseAddress);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _initiatePayment(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String userEmail,
      String location,
      String houseAddress) async {
    final paymentHandler = RazorpayHandler(
      onPaymentSuccess: (String paymentId, String orderId) {
        _completeJobPosting(context, userId, userName, userPhone, location,
            paymentId, houseAddress);
      },
      onPaymentError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $errorMessage')),
        );
      },
    );

    paymentHandler.initiatePayment(
      amount: 2000,
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
    );
  }

  Future<void> _completeJobPosting(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String location,
      String paymentId,
      String houseAddress) async {
    try {
      final jobLat = _selectedLocation?.latitude ?? _center.latitude;
      final jobLng = _selectedLocation?.longitude ?? _center.longitude;

      final newJobRef = _jobRef?.push();
      final jobId = newJobRef?.key;

      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create job.')),
        );
        return;
      }

      String timestamp = DateTime.now().toIso8601String();
      await newJobRef?.set({
        'user_id': userId,
        'userName': userName,
        'userPhone': userPhone,
        'joblocation': {
          'latitude': jobLat,
          'longitude': jobLng,
          'address': "$houseAddress,$location",
        },
        'job': 'AC Repair',
        'status': 'pending',
        'worker_id': null,
        'workerName': null,
        'timestamp': timestamp,
        'fee_id': paymentId,
        'fee_amount': 20,
        'fee_status': 'completed',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment successful! AC repair job posted.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(jobId: jobId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
    }
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      const Text('24/7 Service'),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const Text('4.8 Rating'),
                      const SizedBox(width: 16),
                      const Icon(Icons.bolt, size: 16),
                      const Text('45min Response'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'AC Repair Services',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Professional AC repair services at your doorstep. Our expert technicians ensure quick and reliable solutions for all your AC problems.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _locationController,
                      onChanged: _fetchSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Enter your location',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getLocation,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8), // Add some spacing

                  // House Address Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _houseAddressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your house address',
                        prefixIcon: const Icon(Icons.home,
                            color: Colors.grey), // Added prefix icon
                        border: OutlineInputBorder(
                          // Use OutlineInputBorder
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true, // Enable filling
                        fillColor: Colors.grey[100], // Set fill color
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Location suggestions list
            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index]),
                      onTap: () async {
                        final url =
                            "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(_suggestions[index])}&format=json&limit=1";
                        try {
                          final response = await http.get(Uri.parse(url));
                          if (response.statusCode == 200) {
                            final data = jsonDecode(response.body) as List;
                            if (data.isNotEmpty) {
                              final lat = double.parse(data[0]['lat']);
                              final lon = double.parse(data[0]['lon']);
                              setState(() {
                                _locationController.text = _suggestions[index];
                                _center = LatLng(lat, lon);
                                _selectedLocation = _center;
                                _markers = [
                                  Marker(
                                    point: _center,
                                    width: 80,
                                    height: 80,
                                    child: Icon(
                                      Icons.location_on,
                                      color: Colors.blue,
                                      size: 40,
                                    ),
                                  ),
                                ];
                                _suggestions = [];
                              });
                              _mapController.move(_center, 13);
                            }
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error updating location: $e')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),

            // Map section
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    minZoom: 13.0,
                    onTap: (_, point) async {
                      setState(() {
                        _center = point;
                        _selectedLocation = point;
                        _markers = [
                          Marker(
                            point: point,
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ];
                      });
                      await _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),

            // Status section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Available Now'),
                      const SizedBox(width: 8),
                      const Text('Instant Booking'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.access_time, size: 16),
                      SizedBox(width: 4),
                      Text('45min ETA'),
                      SizedBox(width: 8),
                      Text('Quick Response'),
                    ],
                  ),
                ],
              ),
            ),

            // Post Job Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _postJob(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Post the Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatistic('8k+', 'Jobs Done'),
                  _buildStatistic('4.8', 'Rating'),
                  _buildStatistic('45min', 'Avg. Response'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FridgeRepairPage extends StatefulWidget {
  const FridgeRepairPage({super.key});

  @override
  State<FridgeRepairPage> createState() => _FridgeRepairPageState();
}

class _FridgeRepairPageState extends State<FridgeRepairPage> {
  DatabaseReference? _jobRef;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  final MapController _mapController = MapController();
  LatLng _center = LatLng(20.5937, 78.9629); // India's center
  List<Marker> _markers = [];
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _jobRef = FirebaseDatabase.instance.ref('jobs');
    _getCurrentLocation();
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _markers = [
          Marker(
            point: _center,
            width: 80,
            height: 80,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      });
      _mapController.move(_center, 13);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions =
              data.map((item) => item['display_name'] as String).toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      setState(() => _suggestions = []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = "https://nominatim.openstreetmap.org/reverse?format=json" "&lat=${position.latitude}&lon=${position.longitude}";

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _locationController.text = data['display_name'];
            _center = LatLng(position.latitude, position.longitude);
            _selectedLocation = _center; // Store the coordinates
            _markers = [
              Marker(
                point: _center,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ];
          });
          _mapController.move(_center, 13);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } else if (permission == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (permission == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text =
              data['display_name']; // Update location text
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: $e')),
      );
    }
  }

  Future<void> _postJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final name = userData?['name'] ?? 'Unknown';
      final phone = userData?['phone'] ?? 'Unknown';
      final email = userData?['email'] ?? 'Unknown'; // Get email if available
      final location = _locationController.text;
      final houseAddress = _houseAddressController.text;

      if (location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location.')),
        );
        return;
      }
      if (houseAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a house address.')),
        );
        return;
      }
      // Instead of immediately posting the job, open the payment flow
      // with user information pre-filled
      _initiatePayment(
          context, user.uid, name, phone, email, location, houseAddress);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _initiatePayment(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String userEmail,
      String location,
      String houseAddress) async {
    // Create a payment handler
    final paymentHandler = RazorpayHandler(
      onPaymentSuccess: (String paymentId, String orderId) {
        // After successful payment, proceed with job posting
        _completeJobPosting(context, userId, userName, userPhone, location,
            paymentId, houseAddress);
      },
      onPaymentError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $errorMessage')),
        );
      },
    );

    // Initiate payment with ₹20 fixed amount
    paymentHandler.initiatePayment(
      amount: 2000, // ₹20 in paise
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
    );
  }

  Future<void> _completeJobPosting(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String location,
      String paymentId,
      String houseAddress) async {
    try {
      // Use the stored coordinates instead of parsing from the text
      final jobLat = _selectedLocation?.latitude ?? _center.latitude;
      final jobLng = _selectedLocation?.longitude ?? _center.longitude;

      final newJobRef = _jobRef?.push();
      final jobId = newJobRef?.key;

      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create job.')),
        );
        return;
      }

      String timestamp = DateTime.now().toIso8601String();
      await newJobRef?.set({
        'user_id': userId,
        'userName': userName,
        'userPhone': userPhone,
        'joblocation': {
          'latitude': jobLat,
          'longitude': jobLng,
          'address':
              "$houseAddress,$location", // Store the display address as well
        },
        'job': 'Fridge Repair',
        'status': 'pending',
        'worker_id': null,
        'workerName': null,
        'timestamp': timestamp,
        'fee_id': paymentId,
        'fee_amount': 20, // ₹20 fixed amount
        'fee_status': 'completed',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful! Job posted.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(jobId: jobId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      const Text('24/7 Service'),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const Text('4.9 Rating'),
                      const SizedBox(width: 16),
                      const Icon(Icons.bolt, size: 16),
                      const Text('30min Response'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title and Description
                  const Text(
                    'Fridge Repair Services',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We provide top-notch fridge repair services across India, ensuring quick and reliable assistance for all your fridge needs.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),

                  // Location Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _locationController,
                      onChanged: _fetchSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Enter your location',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getLocation,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8), // Add some spacing

                  // House Address Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _houseAddressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your house address',
                        prefixIcon: const Icon(Icons.home,
                            color: Colors.grey), // Added prefix icon
                        border: OutlineInputBorder(
                          // Use OutlineInputBorder
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true, // Enable filling
                        fillColor: Colors.grey[100], // Set fill color
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map Section
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    minZoom: 13.0,
                    onTap: (_, point) async {
                      setState(() {
                        _center = point;
                        _selectedLocation = point; // Store the coordinates
                        _markers = [
                          Marker(
                            point: point,
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ];
                      });

                      // Geocode the tapped location to get the address
                      await _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),

            // Status Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Available Now'),
                      const SizedBox(width: 8),
                      const Text('Instant Booking'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.access_time, size: 16),
                      SizedBox(width: 4),
                      Text('30min ETA'),
                      SizedBox(width: 8),
                      Text('Quick Response'),
                    ],
                  ),
                ],
              ),
            ),

            // Post Job Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _postJob(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Post the Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatistic('10k+', 'Jobs Done'),
                  _buildStatistic('4.9', 'Rating'),
                  _buildStatistic('30min', 'Avg. Response'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class TowingPage extends StatefulWidget {
  const TowingPage({super.key});

  @override
  State<TowingPage> createState() => _TowingPageState();
}

class _TowingPageState extends State<TowingPage> {
  DatabaseReference? _jobRef;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  final MapController _mapController = MapController();
  LatLng _center = LatLng(20.5937, 78.9629); // India's center
  List<Marker> _markers = [];
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _jobRef = FirebaseDatabase.instance.ref('jobs');
    _getCurrentLocation();
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _markers = [
          Marker(
            point: _center,
            width: 80,
            height: 80,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      });
      _mapController.move(_center, 13);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions =
              data.map((item) => item['display_name'] as String).toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      setState(() => _suggestions = []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = "https://nominatim.openstreetmap.org/reverse?format=json" "&lat=${position.latitude}&lon=${position.longitude}";

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _locationController.text = data['display_name'];
            _center = LatLng(position.latitude, position.longitude);
            _selectedLocation = _center; // Store the coordinates
            _markers = [
              Marker(
                point: _center,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ];
          });
          _mapController.move(_center, 13);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } else if (permission == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (permission == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text =
              data['display_name']; // Update location text
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: $e')),
      );
    }
  }

  Future<void> _postJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final name = userData?['name'] ?? 'Unknown';
      final phone = userData?['phone'] ?? 'Unknown';
      final email = userData?['email'] ?? 'Unknown'; // Get email if available
      final location = _locationController.text;
      final houseAddress = _houseAddressController.text;

      if (location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location.')),
        );
        return;
      }
      if (houseAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a house address.')),
        );
        return;
      }

      // Instead of immediately posting the job, open the payment flow
      // with user information pre-filled
      _initiatePayment(
          context, user.uid, name, phone, email, location, houseAddress);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _initiatePayment(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String userEmail,
      String location,
      String houseAddress) async {
    // Create a payment handler
    final paymentHandler = RazorpayHandler(
      onPaymentSuccess: (String paymentId, String orderId) {
        // After successful payment, proceed with job posting
        _completeJobPosting(context, userId, userName, userPhone, location,
            paymentId, houseAddress);
      },
      onPaymentError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $errorMessage')),
        );
      },
    );

    // Initiate payment with ₹20 fixed amount
    paymentHandler.initiatePayment(
      amount: 2000, // ₹20 in paise
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
    );
  }

  Future<void> _completeJobPosting(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String location,
      String paymentId,
      String houseAddress) async {
    try {
      // Use the stored coordinates instead of parsing from the text
      final jobLat = _selectedLocation?.latitude ?? _center.latitude;
      final jobLng = _selectedLocation?.longitude ?? _center.longitude;

      final newJobRef = _jobRef?.push();
      final jobId = newJobRef?.key;

      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create job.')),
        );
        return;
      }

      String timestamp = DateTime.now().toIso8601String();
      await newJobRef?.set({
        'user_id': userId,
        'userName': userName,
        'userPhone': userPhone,
        'joblocation': {
          'latitude': jobLat,
          'longitude': jobLng,
          'address':
              "$houseAddress,$location", // Store the display address as well
        },
        'job': 'Towing',
        'status': 'pending',
        'worker_id': null,
        'workerName': null,
        'timestamp': timestamp,
        'fee_id': paymentId,
        'fee_amount': 20, // ₹20 fixed amount
        'fee_status': 'completed',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful! Job posted.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(jobId: jobId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Info Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      const Text('24/7 Service'),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const Text('4.9 Rating'),
                      const SizedBox(width: 16),
                      const Icon(Icons.bolt, size: 16),
                      const Text('30min Response'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title and Description
                  const Text(
                    'Towing Services',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We provide top-notch towing services across India, ensuring quick and reliable assistance for all your vehicle needs.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),

                  // Location Search
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _locationController,
                      onChanged: _fetchSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Enter your location',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getLocation,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8), // Add some spacing

                  // House Address Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _houseAddressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your house address',
                        prefixIcon: const Icon(Icons.home,
                            color: Colors.grey), // Added prefix icon
                        border: OutlineInputBorder(
                          // Use OutlineInputBorder
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true, // Enable filling
                        fillColor: Colors.grey[100], // Set fill color
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Map Section
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    minZoom: 13.0,
                    onTap: (_, point) async {
                      setState(() {
                        _center = point;
                        _selectedLocation = point; // Store the coordinates
                        _markers = [
                          Marker(
                            point: point,
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ];
                      });

                      // Geocode the tapped location to get the address
                      await _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),

            // Status Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Available Now'),
                      const SizedBox(width: 8),
                      const Text('Instant Booking'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.access_time, size: 16),
                      SizedBox(width: 4),
                      Text('30min ETA'),
                      SizedBox(width: 8),
                      Text('Quick Response'),
                    ],
                  ),
                ],
              ),
            ),

            // Post Job Button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _postJob(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Post the Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatistic('10k+', 'Jobs Done'),
                  _buildStatistic('4.9', 'Rating'),
                  _buildStatistic('30min', 'Avg. Response'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

class RoServicePage extends StatefulWidget {
  const RoServicePage({super.key});

  @override
  State<RoServicePage> createState() => _RoServicePageState();
}

class _RoServicePageState extends State<RoServicePage> {
  DatabaseReference? _jobRef;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _houseAddressController = TextEditingController();
  List<String> _suggestions = [];
  bool _isLoading = false;
  final MapController _mapController = MapController();
  LatLng _center = LatLng(20.5937, 78.9629); // India's center
  List<Marker> _markers = [];
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _jobRef = FirebaseDatabase.instance.ref('jobs');
    _getCurrentLocation();
    _markers.add(
      Marker(
        point: _center,
        width: 80,
        height: 80,
        child: Icon(
          Icons.location_on,
          color: Colors.blue,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
        _markers = [
          Marker(
            point: _center,
            width: 80,
            height: 80,
            child: Icon(
              Icons.location_on,
              color: Colors.blue,
              size: 40,
            ),
          ),
        ];
      });
      _mapController.move(_center, 13);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    setState(() => _isLoading = true);

    final url =
        "https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          _suggestions =
              data.map((item) => item['display_name'] as String).toList();
        });
      } else {
        setState(() => _suggestions = []);
      }
    } catch (e) {
      setState(() => _suggestions = []);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _getLocation() async {
    PermissionStatus permission = await Permission.location.request();

    if (permission == PermissionStatus.granted) {
      try {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final url = "https://nominatim.openstreetmap.org/reverse?format=json" "&lat=${position.latitude}&lon=${position.longitude}";

        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _locationController.text = data['display_name'];
            _center = LatLng(position.latitude, position.longitude);
            _selectedLocation = _center;
            _markers = [
              Marker(
                point: _center,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_on,
                  color: Colors.blue,
                  size: 40,
                ),
              ),
            ];
          });
          _mapController.move(_center, 13);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching location: $e')),
        );
      }
    } else if (permission == PermissionStatus.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    } else if (permission == PermissionStatus.permanentlyDenied) {
      openAppSettings();
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    final url =
        "https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationController.text = data['display_name'];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: $e')),
      );
    }
  }

  Future<void> _postJob(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user logged in.')),
      );
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details not found.')),
        );
        return;
      }

      final userData = userDoc.data();
      final name = userData?['name'] ?? 'Unknown';
      final phone = userData?['phone'] ?? 'Unknown';
      final email = userData?['email'] ?? 'Unknown';
      final location = _locationController.text;
      final houseAddress = _houseAddressController.text;

      if (location.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a location.')),
        );
        return;
      }
      if (houseAddress.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a house address.')),
        );
        return;
      }

      _initiatePayment(
          context, user.uid, name, phone, email, location, houseAddress);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _initiatePayment(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String userEmail,
      String location,
      String houseAddress) async {
    final paymentHandler = RazorpayHandler(
      onPaymentSuccess: (String paymentId, String orderId) {
        _completeJobPosting(context, userId, userName, userPhone, location,
            paymentId, houseAddress);
      },
      onPaymentError: (String errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $errorMessage')),
        );
      },
    );

    paymentHandler.initiatePayment(
      amount: 2000,
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
    );
  }

  Future<void> _completeJobPosting(
      BuildContext context,
      String userId,
      String userName,
      String userPhone,
      String location,
      String paymentId,
      String houseAddress) async {
    try {
      final jobLat = _selectedLocation?.latitude ?? _center.latitude;
      final jobLng = _selectedLocation?.longitude ?? _center.longitude;

      final newJobRef = _jobRef?.push();
      final jobId = newJobRef?.key;

      if (jobId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create job.')),
        );
        return;
      }

      String timestamp = DateTime.now().toIso8601String();
      await newJobRef?.set({
        'user_id': userId,
        'userName': userName,
        'userPhone': userPhone,
        'joblocation': {
          'latitude': jobLat,
          'longitude': jobLng,
          'address': "$houseAddress,$location",
        },
        'job': 'RO Service',
        'status': 'pending',
        'worker_id': null,
        'workerName': null,
        'timestamp': timestamp,
        'fee_id': paymentId,
        'fee_amount': 20,
        'fee_status': 'completed',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Payment successful! RO service job posted.')),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => JobDetailsPage(jobId: jobId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error completing job: $e')),
      );
    }
  }

  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.access_time, size: 16),
                      const SizedBox(width: 4),
                      const Text('24/7 Service'),
                      const SizedBox(width: 16),
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const Text('4.8 Rating'),
                      const SizedBox(width: 16),
                      const Icon(Icons.bolt, size: 16),
                      const Text('45min Response'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'RO Service & Repair',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Expert RO system service, maintenance, and repair across India. Get professional solutions for clean and safe drinking water.',
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _locationController,
                      onChanged: _fetchSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Enter your location',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getLocation,
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8), // Add some spacing

                  // House Address Text Field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _houseAddressController,
                      decoration: InputDecoration(
                        hintText: 'Enter your house address',
                        prefixIcon: const Icon(Icons.home,
                            color: Colors.grey), // Added prefix icon
                        border: OutlineInputBorder(
                          // Use OutlineInputBorder
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true, // Enable filling
                        fillColor: Colors.grey[100], // Set fill color
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    minZoom: 13.0,
                    onTap: (_, point) async {
                      setState(() {
                        _center = point;
                        _selectedLocation = point;
                        _markers = [
                          Marker(
                            point: point,
                            width: 80,
                            height: 80,
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 40,
                            ),
                          ),
                        ];
                      });
                      await _reverseGeocode(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Available Now'),
                      const SizedBox(width: 8),
                      const Text('Instant Booking'),
                    ],
                  ),
                  Row(
                    children: const [
                      Icon(Icons.access_time, size: 16),
                      SizedBox(width: 4),
                      Text('45min ETA'),
                      SizedBox(width: 8),
                      Text('Expert Service'),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => _postJob(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Post the Job',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Statistics Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatistic('5k+', 'Jobs Done'),
                  _buildStatistic('4.8', 'Rating'),
                  _buildStatistic('45min', 'Avg. Response'),
                ],
              ),
            ),

            if (_suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index]),
                      onTap: () {
                        setState(() {
                          _locationController.text = _suggestions[index];
                          _suggestions = [];
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
