import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:handzy/pages/login_signup_page.dart';
import 'package:handzy/pages/workers/job_details_screen.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({Key? key}) : super(key: key);

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isAvailable = false;
  late Position _currentPosition;
  bool _locationFetched = false;
  Timer? _statusRefreshTimer;
  bool _isSyncingStatus = false;

  @override
  void initState() {
    super.initState();
    _initializeWorker();
    _checkLocationStatus();
    _fetchCurrentAvailability(showLoading: true);

    // Set up periodic status refresh
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      // Only refresh if not already refreshing
      if (!_isSyncingStatus) {
        _fetchCurrentAvailability(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    // Cancel timer when widget is disposed
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force refresh when app comes to foreground
      _fetchCurrentAvailability(showLoading: true);
    }
  }

  Future<void> _checkLocationStatus() async {
    // Check if location permission is already granted
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      setState(() {
        _locationFetched = true;
      });

      // Also fetch the current availability status from your backend/storage
      await _fetchCurrentAvailability();
    }
  }

  Future<void> _fetchCurrentAvailability({bool showLoading = false}) async {
    if (_isSyncingStatus) return; // Prevent multiple simultaneous fetches

    setState(() {
      _isSyncingStatus = true;
      if (showLoading) {
        // Show loading indicator if needed
      }
    });

    try {
      // Instead of SharedPreferences, directly check Firebase for the current status
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final uid = user.uid;
        final workerSnapshot =
            await FirebaseDatabase.instance.ref('workers/$uid').get();

        if (workerSnapshot.exists) {
          final workerData = workerSnapshot.value as Map<dynamic, dynamic>;
          // Check the availability value in Firebase
          final serverAvailability = workerData['availability'] == 'available';

          // Only update UI if the status is different from current UI state
          if (_isAvailable != serverAvailability) {
            setState(() {
              _isAvailable = serverAvailability;
            });
          }
        }
      }
    } catch (error) {
      // Don't update UI state if fetch fails
      print('Error fetching availability: $error');
    } finally {
      setState(() {
        _isSyncingStatus = false;
      });
    }
  }

  void _toggleAvailability() async {
    // Store the current state before changing
    final previousState = _isAvailable;

    // Optimistically update UI
    setState(() {
      _isAvailable = !_isAvailable;
    });

    try {
      // Show loading indicator in button
      setState(() {
        _isSyncingStatus = true;
      });

      // Get current location before updating status
      Position currentPosition = await _getCurrentLocation();

      // Update backend
      await _updateAvailability(currentPosition);

      // Verify the update was successful by fetching latest status
      await _fetchCurrentAvailability(showLoading: false);
    } catch (error) {
      // If update fails, revert the UI state to previous state
      setState(() {
        _isAvailable = previousState;
      });
    } finally {
      setState(() {
        _isSyncingStatus = false;
      });
    }
  }

  Future<Position> _getCurrentLocation() async {
    // Request location permission if not granted
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled || permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions are permanently denied.");
    }

    // Get current position (latitude, longitude)
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return position;
  }

  // Initialize worker logic, including setting up job notification listener
  Future<void> _initializeWorker() async {
    final user = _auth.currentUser;
    if (user != null) {
      final workerId = user.uid;
      _listenForJobNotifications(workerId);
    }
  }

  // Listener for job notifications
  void _listenForJobNotifications(String workerId) {
    final workerRef =
        FirebaseDatabase.instance.ref('workers/$workerId/jobNotification');

    workerRef.onValue.listen((event) {
      if (event.snapshot.exists) {
        final notificationData = event.snapshot.value as Map;
        final jobId = notificationData['jobId'];
        final status = notificationData['status'];

        if (status == 'pending') {
          _showJobDialog(jobId, workerId);
        }
      }
    });
  }

  // Request location permission and get the current position
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are denied.')),
      );
      return;
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _locationFetched = true;
    });
  }

  // Update availability in Firebase
  Future<void> _updateAvailability(Position currentPosition) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final uid = user.uid;
    final DatabaseReference workerRef =
        FirebaseDatabase.instance.ref('workers/$uid');

    // Update both availability and location fields
    await workerRef.update({
      'availability': _isAvailable ? 'available' : 'not available',
      'workerLocation': {
        'latitude': currentPosition.latitude,
        'longitude': currentPosition.longitude,
      },
    });
  }

  // Play sound notification
  void _playNotificationSound() async {
  final player = AudioPlayer();
  player.onPlayerComplete.listen((event) {
    print('Audio has finished playing');
  });
  
  try {
    await player.play(AssetSource('assets/notification.mp3'));
    print('Sound played successfully');
  } catch (e) {
    print('Error playing sound: $e');
  }
}
  void _showJobDialog(String jobId, String workerId) {
    _playNotificationSound();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Job Assigned'),
          content: const Text(
              'You have been assigned a new job. Do you want to accept it?'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _respondToJob(jobId, workerId, 'declined');
              },
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _respondToJob(jobId, workerId, 'accepted');
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _respondToJob(
      String jobId, String workerId, String response) async {
    final workerRef = FirebaseDatabase.instance.ref('workers/$workerId');
    final jobRef = FirebaseDatabase.instance.ref('jobs/$jobId');

    if (response == 'accepted') {
      await workerRef.update({'availability': 'not available'});
      await jobRef.update({'status': 'accepted', 'worker_id': workerId});

      final jobSnapshot = await jobRef.get();
      if (jobSnapshot.exists) {
        final jobDetails = Map<String, dynamic>.from(jobSnapshot.value as Map);

        // Navigate to JobDetailsPage after accepting the job
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JobDetailsPage(
              jobDetails: jobDetails,
              jobId: jobId,
            ),
          ),
        );
      }
    } else if (response == 'declined') {
      await workerRef.child('jobNotification').remove();
      await jobRef.update({'status': 'pending'});
    }
  }

  Widget _buildStatusCard() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Current Status',
                    style: TextStyle(color: Colors.black54)),
                if (_isSyncingStatus)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _isAvailable ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isAvailable ? 'Available' : 'Not Available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSyncingStatus ? null : _toggleAvailability,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                  ),
                  child: _isSyncingStatus
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black54),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Updating...'),
                          ],
                        )
                      : const Text('Change Status'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _openMap(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Update Location'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobCard(Map<String, dynamic> jobDetails, String jobId) {
    return Card(
      color: Colors.black,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ACTIVE JOB',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(jobDetails['jobType'] ?? 'Emergency Electrical Repair',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(
                jobDetails['joblocation']['address'] ??
                    '123 Park Street, Sector 4',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 16),
            _buildProgressIndicator(jobDetails['status']),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _navigateToJobDetails(jobDetails, jobId),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white54),
                    child: const Text('Navigate'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _contactCustomer(jobDetails['userPhone']),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.white54),
                    child: const Text('Contact Customer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(String status) {
    const stages = ['accepted', 'en route', 'working', 'completed'];
    int currentIndex = stages.indexOf(status);
    if (currentIndex == -1)
      currentIndex = 0; // Default to accepted if not found

    return Row(
      children: List.generate(stages.length, (index) {
        bool isActive = index <= currentIndex;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.white54,
                  shape: BoxShape.circle,
                ),
              ),
              if (index < stages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isActive && index < currentIndex
                        ? Colors.green
                        : Colors.white54,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildServiceInfoCard(String serviceName, double rating) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Service',
                style: TextStyle(color: Colors.black54, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(serviceName,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Text('Rating: ${rating.toStringAsFixed(1)} ',
                        style: TextStyle(fontSize: 14)),
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white, // Set Scaffold background color to white
      drawer: _buildDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: const Text(
          'HANDZY',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.white, // Set AppBar background color to white
        centerTitle: true,
        elevation:
            0, // Optional: remove shadow to match a clean white background
      ),
      body: StreamBuilder(
        stream: FirebaseDatabase.instance
            .ref(
                'workers/${FirebaseAuth.instance.currentUser!.uid}/jobNotification')
            .onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          // Outer StreamBuilder for job notifications
          return StreamBuilder<DocumentSnapshot>(
            // Inner StreamBuilder for worker service details
            stream: FirebaseFirestore.instance
                .collection('worker_logins')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .snapshots(),
            builder: (context, workerSnapshot) {
              String serviceName = 'Electrician'; // Default
              double rating = 4.8; // Default

              if (workerSnapshot.hasData && workerSnapshot.data != null) {
                var data = workerSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null) {
                  serviceName = data['service'] ?? 'Electrician';
                  rating = (data['rating'] ?? 4.8).toDouble();
                }
              }

              // Check for active job
              Widget? activeJobCard;
              if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                Map<dynamic, dynamic> notification =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                String jobId = notification['jobId'];

                // Use FutureBuilder to get job details
                return FutureBuilder(
                  future: FirebaseDatabase.instance.ref('jobs/$jobId').get(),
                  builder: (context, AsyncSnapshot<DataSnapshot> jobSnapshot) {
                    if (jobSnapshot.hasData && jobSnapshot.data!.exists) {
                      Map<String, dynamic> jobDetails =
                          Map<String, dynamic>.from(
                              jobSnapshot.data!.value as Map);

                      activeJobCard = _buildActiveJobCard(jobDetails, jobId);
                    }

                    return SingleChildScrollView(
                      child: Container(
                        color: Colors
                            .white, // Ensure the body background color is white
                        child: Column(
                          children: [
                            _buildStatusCard(),
                            if (activeJobCard != null) activeJobCard!,
                            _buildServiceInfoCard(serviceName, rating),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }

              return SingleChildScrollView(
                child: Container(
                  color:
                      Colors.white, // Ensure the body background color is white
                  child: Column(
                    children: [
                      _buildStatusCard(),
                      _buildServiceInfoCard(serviceName, rating),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor:
            Colors.white, // Set BottomNavigationBar background color to white
        currentIndex: 0,
        onTap: (index) {
          switch (index) {
            case 0:
              // Navigate to Home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WorkerHomeScreen()),
              );
              break;
            case 1:
              // Navigate to Activity
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ActivityPage(
                        workerId: FirebaseAuth.instance.currentUser!.uid)),
              );
              break;
            case 2:
              // Navigate to Profile
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MyProfilePage()),
              );
              break;
            case 3:
              // Navigate to Settings
              ///Navigator.pushReplacement(
              ////context,
              ///   MaterialPageRoute(builder: (context) => SettingsPage()),
              /// );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home, color: Colors.black),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt, color: Colors.black54),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, color: Colors.black54),
            label: 'Account',
          ),
        ],
      ),
    );
  }

  void _navigateToJobDetails(Map<String, dynamic> jobDetails, String jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsPage(
          jobDetails: jobDetails,
          jobId: jobId,
        ),
      ),
    );
  }

  void _contactCustomer(String? phone) {
    if (phone != null) {
      launchUrl(Uri.parse('tel:$phone'));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
    }
  }

  void _openMap() {
    if (_locationFetched) {
      final url =
          'https://www.google.com/maps/search/?api=1&query=${_currentPosition.latitude},${_currentPosition.longitude}';
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      _requestLocationPermission();
    }
  }
}

Widget _buildDrawer() {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('worker_logins')
        .doc(uid)
        .snapshots(),
    builder: (context, workerSnapshot) {
      String workerName = 'Loading...';
      String service = 'Loading...';
      bool isAvailable = false;

      if (workerSnapshot.hasData && workerSnapshot.data != null) {
        final data = workerSnapshot.data!.data() as Map<String, dynamic>?;
        if (data != null) {
          workerName = data['name'] ?? 'Worker';
          service = data['service'] ?? 'Service Provider';
        }
      }

      return StreamBuilder(
        stream: FirebaseDatabase.instance.ref('workers/$uid').onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> availabilitySnapshot) {
          if (availabilitySnapshot.hasData &&
              availabilitySnapshot.data!.snapshot.value != null) {
            final data = Map<String, dynamic>.from(
                availabilitySnapshot.data!.snapshot.value as Map);
            isAvailable = data['availability'] == 'available';
          }

          return Container(
              width: MediaQuery.of(context).size.width * 0.65,
              child: Align(
                alignment: Alignment.centerRight,
                child: Drawer(
                  backgroundColor: Colors.white,
                  width: MediaQuery.of(context).size.width * 0.65,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                        color: Colors.black,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                FutureBuilder<String>(
                                  future: _getProfilePictureUrl(uid),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.grey[300],
                                        child: CircularProgressIndicator(),
                                      );
                                    } else if (snapshot.hasData &&
                                        snapshot.data != null &&
                                        snapshot.data!.isNotEmpty) {
                                      return CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage:
                                            NetworkImage(snapshot.data!),
                                      );
                                    } else {
                                      return CircleAvatar(
                                        radius: 40,
                                        backgroundColor: Colors.grey[300],
                                        child: Icon(Icons.person_outline,
                                            size: 70, color: Colors.grey[600]),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        workerName.toUpperCase(),
                                        style: GoogleFonts.spectral(
                                          textStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        service,
                                        style: const TextStyle(
                                          color: Color.fromARGB(
                                              255, 117, 117, 117),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isAvailable)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Available',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      _drawerItem(Icons.dashboard_outlined, 'Dashboard', () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => WorkerHomeScreen()),
                        );
                      }),
                      _drawerItem(Icons.work_outline, 'My Activity', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActivityPage(
                              workerId: uid,
                            ),
                          ),
                        );
                      }),
                      _drawerItem(
                        Icons.account_balance_wallet_outlined,
                        'Wallet',
                        () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  EarningsWalletScreen(uid: uid),
                            ),
                          );
                        },
                      ),
                      _drawerItem(
                          Icons.star_outline, 'Ratings & Reviews', () {}),
                      _drawerItem(Icons.settings_outlined, 'Settings', () {}),
                      _drawerItem(Icons.help_outline, 'Help & Support', () {}),
                      const Spacer(),
                      const Divider(height: 1),
                      _drawerItem(
                        Icons.logout,
                        'Logout',
                        () async {
                          final prefs = await SharedPreferences.getInstance();
                          await FirebaseAuth.instance.signOut();
                          await prefs.setBool('isWorkerLoggedIn', false);
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => LoginSignupPage()),
                            (route) => false,
                          );
                        },
                        textColor: Colors.red,
                        iconColor: Colors.red,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Version 2.4.1',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ));
        },
      );
    },
  );
}

// Helper function to get the profile picture URL from Supabase
Future<String> _getProfilePictureUrl(String uid) async {
  try {
    // You're using both Firebase and Supabase, so depending on where your image is stored:

    // If stored in Supabase:
    final String url =
        'https://dsjeyaorfibuvddayxxw.supabase.co/storage/v1/object/public/documents/workers/$uid/profile-picture.jpg';

    // Validate URL exists (optional)
    final response = await http.head(Uri.parse(url));
    if (response.statusCode == 200) {
      return url;
    }

    return ''; // Return empty if not found
  } catch (e) {
    print('Error fetching profile picture: $e');
    return ''; // Return empty on error
  }
}

Widget _drawerItem(IconData icon, String title, VoidCallback onTap,
    {Color textColor = Colors.black87, Color iconColor = Colors.black54}) {
  return ListTile(
    leading: Icon(
      icon,
      color: iconColor,
      size: 24,
    ),
    title: Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
    ),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    visualDensity: const VisualDensity(horizontal: -4, vertical: -2),
  );
}

class ActivityPage extends StatefulWidget {
  final String workerId;

  const ActivityPage({Key? key, required this.workerId}) : super(key: key);

  @override
  _ActivityPageState createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  late DatabaseReference _pastJobsRef;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late StreamSubscription<DatabaseEvent> _jobSubscription;
  List<Map<String, dynamic>> _todayJobs = [];
  List<Map<String, dynamic>> _pastJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  @override
  void dispose() {
    _jobSubscription.cancel();
    super.dispose();
  }

  String _getFormattedDateTime() {
    return DateTime.now().toIso8601String();
  }

  void _fetchJobs() {
    _pastJobsRef = FirebaseDatabase.instance.ref('PastJobs');

    _jobSubscription = _pastJobsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        final List<Map<String, dynamic>> today = [];
        final List<Map<String, dynamic>> past = [];

        data.forEach((key, value) {
          if (value is Map) {
            final jobData = Map<String, dynamic>.from(value);
            if (jobData['worker_id'] == widget.workerId) {
              final job = {
                'id': key,
                'job': jobData['job']?.toString() ?? 'Untitled Job',
                'status': jobData['status']?.toString() ?? 'pending',
                'joblocation':
                    jobData['joblocation']?.toString() ?? 'No location',
                'userName': jobData['userName']?.toString() ?? 'N/A',
                'userPhone': jobData['userPhone']?.toString() ?? 'N/A',
                'timestamp':
                    jobData['timestamp']?.toString() ?? _getFormattedDateTime(),
              };

              try {
                final jobDate = DateTime.parse(job['timestamp']);
                final now = DateTime.now();

                if (jobDate.day == now.day &&
                    jobDate.month == now.month &&
                    jobDate.year == now.year) {
                  today.add(job);
                } else {
                  past.add(job);
                }
              } catch (e) {
                // If date parsing fails, add to past jobs
                past.add(job);
              }
            }
          }
        });

        // Sort by timestamp with error handling
        today.sort((a, b) {
          try {
            return DateTime.parse(b['timestamp'])
                .compareTo(DateTime.parse(a['timestamp']));
          } catch (e) {
            return 0;
          }
        });

        past.sort((a, b) {
          try {
            return DateTime.parse(b['timestamp'])
                .compareTo(DateTime.parse(a['timestamp']));
          } catch (e) {
            return 0;
          }
        });

        setState(() {
          _todayJobs = today;
          _pastJobs = past;
          _isLoading = false;
        });
      } else {
        setState(() {
          _todayJobs = [];
          _pastJobs = [];
          _isLoading = false;
        });
      }
    });
  }

  String _formatTimeDisplay(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();

      if (date.day == now.day &&
          date.month == now.month &&
          date.year == now.year) {
        return 'Today ${DateFormat('h:mm a').format(date)}';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return 'Date unavailable';
    }
  }

  Widget _buildJobCard(Map<String, dynamic> job, bool isToday) {
    Color statusColor =
        job['status'] == 'workdone' ? Colors.green : Colors.blue;
    String timeText = _formatTimeDisplay(job['timestamp']);

    return Card(
      color: Colors.white,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PastJobDetailsPage(jobDetails: job),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        job['status'] == 'workdone'
                            ? Icons.check
                            : Icons.pending,
                        size: 16,
                        color: statusColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      job['job'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.only(left: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      job['joblocation'],
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Customer: ${job['userName']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : (_todayJobs.isEmpty && _pastJobs.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No jobs completed yet!',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(top: 16),
                  children: [
                    if (_todayJobs.isNotEmpty) ...[
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'TODAY',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ..._todayJobs.map((job) => _buildJobCard(job, true)),
                    ],
                    if (_pastJobs.isNotEmpty) ...[
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'PAST JOBS',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ..._pastJobs.map((job) => _buildJobCard(job, false)),
                    ],
                  ],
                ),
    );
  }
}

class PastJobDetailsPage extends StatelessWidget {
  final Map<String, dynamic> jobDetails;

  const PastJobDetailsPage({Key? key, required this.jobDetails})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    print(jobDetails[
        'joblocation']); // This is where you print the joblocation map

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Job Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jobDetails['job'] ?? 'Untitled Job',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow(Icons.schedule, 'Status',
                        jobDetails['status'] ?? 'N/A'),
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      jobDetails['joblocation'] != null &&
                              jobDetails['joblocation'] is Map
                          ? jobDetails['joblocation']['address'] ?? 'N/A'
                          : 'N/A',
                    ),
                    _buildDetailRow(Icons.person, 'Customer',
                        jobDetails['userName'] ?? 'N/A'),
                    _buildDetailRow(
                        Icons.phone, 'Phone', jobDetails['userPhone'] ?? 'N/A'),
                    if (jobDetails['timestamp'] != null)
                      _buildDetailRow(
                        Icons.calendar_today,
                        'Date',
                        DateFormat('MMM d, y h:mm a')
                            .format(DateTime.parse(jobDetails['timestamp'])),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({Key? key}) : super(key: key);

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final supabase = Supabase.instance.client;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;

  String? _profilePictureUrl;
  bool _isEditing = false;
  bool _isAvailable = true;
  late double _rating;
  String _serviceType = "";

  // Variables to track expansion state
  bool _personalDetailsExpanded = false;
  bool _serviceHistoryExpanded = false;
  bool _paymentsExpanded = false;
  bool _settingsExpanded = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: "");
    emailController = TextEditingController(text: "");
    phoneController = TextEditingController(text: "");
    _loadProfileData();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Fetch user details from Firestore
      final doc =
          await _firestore.collection('worker_logins').doc(user.uid).get();
      final data = doc.data();

      _database
          .child('workers/${user.uid}/availability')
          .onValue
          .listen((event) {
        final availability = event.snapshot.value as String?;
        setState(() {
          _isAvailable = availability == 'available';
        });
      });

      // Fetch profile picture from Supabase Storage
      final profilePicturePath = 'profile_pictures/${user.uid}.jpg';
      final response =
          supabase.storage.from('avatars').getPublicUrl(profilePicturePath);

      // Fetch rating and availability from Realtime Database
      final realtimeSnapshot =
          await _database.child('workers/${user.uid}').get();
      if (realtimeSnapshot.exists) {
        final realtimeData = realtimeSnapshot.value as Map<dynamic, dynamic>?;
        setState(() {
          _rating = realtimeData?['rating']?.toDouble() ?? 0.0;
          _isAvailable = realtimeData?['availability'] == 'available';
        });
      }

      setState(() {
        nameController =
            TextEditingController(text: data?['name'] ?? 'Your Name');
        emailController = TextEditingController(text: data?['email'] ?? '');
        phoneController = TextEditingController(text: data?['phone'] ?? '');
        _profilePictureUrl = response;
        _serviceType = data?['service'] ?? 'Service Provider';
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final user = _auth.currentUser;
      if (user != null) {
        final profilePicturePath = 'profile_pictures/${user.uid}.jpg';
        final file = File(image.path);

        // Upload the new profile picture to Supabase Storage
        await supabase.storage.from('avatars').upload(profilePicturePath, file);

        // Fetch the public URL of the uploaded profile picture
        final publicUrl =
            supabase.storage.from('avatars').getPublicUrl(profilePicturePath);

        // Update the Firestore document with the new URL
        await _firestore
            .collection('worker_logins')
            .doc(user.uid)
            .update({'profilePicture': publicUrl});

        setState(() {
          _profilePictureUrl = publicUrl;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to '/workerhome' when the back button is clicked
            Navigator.pushReplacementNamed(context, '/workerhome');
          },
        ),
      ),
      body: _profilePictureUrl == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Profile picture and availability status
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _changeProfilePicture,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                                image: _profilePictureUrl != null &&
                                        _profilePictureUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image:
                                            NetworkImage(_profilePictureUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profilePictureUrl == null ||
                                      _profilePictureUrl!.isEmpty
                                  ? const Icon(Icons.person,
                                      size: 60, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.add,
                                    color: Colors.white, size: 20),
                                onPressed: _changeProfilePicture,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name and Occupation
                    Text(
                      nameController.text.toUpperCase(),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$_serviceType • $_rating ★',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),

                    // Availability Toggle
                    GestureDetector(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isAvailable
                              ? Colors.green[50]
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isAvailable ? 'Available' : 'Unavailable',
                          style: TextStyle(
                            color: _isAvailable
                                ? Colors.green[700]
                                : Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Collapsible Sections
                    _buildExpandableSection(
                      title: 'Personal Details',
                      isExpanded: _personalDetailsExpanded,
                      onTap: () => setState(() =>
                          _personalDetailsExpanded = !_personalDetailsExpanded),
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'Name'),
                          readOnly: !_isEditing,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(labelText: 'Phone'),
                          readOnly: !_isEditing,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(text: _serviceType),
                          decoration:
                              const InputDecoration(labelText: 'Service'),
                          readOnly: true,
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<DocumentSnapshot>(
                          future: _firestore
                              .collection('worker_logins')
                              .doc(_auth.currentUser?.uid)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError ||
                                !snapshot.hasData ||
                                !snapshot.data!.exists) {
                              return const Text('Error loading bank details');
                            }

                            final data =
                                snapshot.data!.data() as Map<String, dynamic>;
                            final accountHolderName =
                                data['accountHolderName'] ?? 'Not set';
                            final accountNumber = data['accountNumber'] ?? '';
                            final maskedAccountNumber = accountNumber.length > 4
                                ? '****${accountNumber.substring(accountNumber.length - 4)}'
                                : accountNumber;
                            final ifscCode = data['ifscCode'] ?? 'Not set';

                            return Column(
                              children: [
                                TextField(
                                  controller: TextEditingController(
                                      text: accountHolderName),
                                  decoration: const InputDecoration(
                                      labelText: 'Account Holder Name'),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: TextEditingController(
                                      text: maskedAccountNumber),
                                  decoration: const InputDecoration(
                                      labelText: 'Account Number'),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller:
                                      TextEditingController(text: ifscCode),
                                  decoration: const InputDecoration(
                                      labelText: 'IFSC Code'),
                                  readOnly: true,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                    _buildExpandableSection(
                      title: 'Service History',
                      isExpanded: _serviceHistoryExpanded,
                      onTap: () => setState(() =>
                          _serviceHistoryExpanded = !_serviceHistoryExpanded),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No service history available',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      ],
                    ),

                    _buildExpandableSection(
                      title: 'Payments',
                      isExpanded: _paymentsExpanded,
                      onTap: () => setState(
                          () => _paymentsExpanded = !_paymentsExpanded),
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No payment history available',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ),
                        ),
                      ],
                    ),

                    _buildExpandableSection(
                      title: 'Settings',
                      isExpanded: _settingsExpanded,
                      onTap: () => setState(
                          () => _settingsExpanded = !_settingsExpanded),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Notification Settings'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to notification settings
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.language_outlined),
                          title: const Text('Language Settings'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to language settings
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Privacy Settings'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to privacy settings
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.help_outline),
                          title: const Text('Help & Support'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            // Navigate to help & support
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Logout',
                              style: TextStyle(color: Colors.red)),
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await FirebaseAuth.instance.signOut();
                            // Remove worker login status (set to false)
                            await prefs.setBool('isWorkerLoggedIn', false);
                            await _auth.signOut();
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2, // Profile tab selected
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Activity',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/workerhome');
          } else if (index == 1) {
            // Navigate to services page
          }
          // No need to handle index 2 (Profile) as we're already there
        },
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool isExpanded,
    required VoidCallback onTap,
    required List<Widget> children,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(children: children),
          ),
        Divider(height: 1, color: Colors.grey[300]),
      ],
    );
  }
}

class EarningsWalletScreen extends StatefulWidget {
  final String uid;
  const EarningsWalletScreen({Key? key, required this.uid}) : super(key: key);

  @override
  State<EarningsWalletScreen> createState() => _EarningsWalletScreenState();
}

class _EarningsWalletScreenState extends State<EarningsWalletScreen> {
  bool autoWithdrawal = true;
  Map<String, dynamic>? userData;
  bool _isProcessingWithdrawal = false;
  bool isLoading = true;
  int? selectedDay;
  List<Map<String, dynamic>> transactions = [];
  double totalEscrowAmount = 0.0;
  double totalEarningsToday = 0.0;
  double totalEarningsThisWeek = 0.0;

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchTransactions();
    _fetchEscrowAmount();
    _fetchTodaysEarnings();
    _fetchWeeklyEarnings();
  }

  Future<void> _fetchWeeklyEarnings() async {
    final workerTransactionsRef = FirebaseFirestore.instance
        .collection('worker_wallet_transactions')
        .doc(widget.uid)
        .collection('transactions');

    try {
      // Get today's date to calculate the start and end of the week
      DateTime now = DateTime.now();
      // Calculate the start of the week (Monday)
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      // Calculate the end of the week (Sunday)
      DateTime endOfWeek = startOfWeek.add(Duration(days: 6));

      // Query Firestore for transactions that are 'earning' type
      final querySnapshot =
          await workerTransactionsRef.where('type', isEqualTo: 'earning').get();

      double totalEarnings = 0.0;

      // Loop through the documents and sum the earnings for this week's transactions
      for (var doc in querySnapshot.docs) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final transactionDate = DateTime.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch);

          // Compare only the date (ignoring the time)
          if (transactionDate.isAfter(startOfWeek) &&
              transactionDate.isBefore(endOfWeek.add(Duration(days: 1)))) {
            final amount = doc['amount'] as num?;
            if (amount != null) {
              totalEarnings += amount.toDouble();
            }
          }
        }
      }

      // Update the UI with the total earnings for the week
      setState(() {
        totalEarningsThisWeek = totalEarnings;
      });
    } catch (e) {
      print('Error fetching weekly earnings: $e');
    }
  }

  Future<void> _fetchTodaysEarnings() async {
    final workerTransactionsRef = FirebaseFirestore.instance
        .collection('worker_wallet_transactions')
        .doc(widget.uid)
        .collection('transactions');

    try {
      // Get today's date (ignoring time)
      DateTime now = DateTime.now();
      DateTime startOfToday = DateTime(now.year, now.month, now.day);

      // Query Firestore for transactions that are 'earning' type and have a timestamp that matches today's date
      final querySnapshot =
          await workerTransactionsRef.where('type', isEqualTo: 'earning').get();

      double totalEarnings = 0.0;

      // Loop through the documents and sum the earnings for today's transactions
      for (var doc in querySnapshot.docs) {
        final timestamp = doc['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final transactionDate = DateTime.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch);

          // Compare only the date (ignoring the time)
          if (transactionDate.year == startOfToday.year &&
              transactionDate.month == startOfToday.month &&
              transactionDate.day == startOfToday.day) {
            final amount = doc['amount'] as num?;
            if (amount != null) {
              totalEarnings += amount.toDouble();
            }
          }
        }
      }

      setState(() {
        totalEarningsToday = totalEarnings;
      });
    } catch (e) {
      print('Error fetching earnings: $e');
    }
  }

  Future<void> _fetchEscrowAmount() async {
    final workerTransactionsRef = FirebaseFirestore.instance
        .collection('worker_wallet_transactions')
        .doc(widget.uid)
        .collection('transactions');

    try {
      final querySnapshot = await workerTransactionsRef
          .where('status', isEqualTo: 'in_escrow')
          .get();

      double totalAmount = 0.0;

      for (var doc in querySnapshot.docs) {
        final amount = doc['amount'] as double;
        totalAmount += amount;
      }

      setState(() {
        totalEscrowAmount = totalAmount;
      });
    } catch (e) {
      print('Error fetching escrow data: $e');
    }
  }

  void _processEmergencyWithdrawal() async {
    // Check if user has bank account details
    if (userData == null ||
        userData!['accountNumber'] == null ||
        userData!['ifscCode'] == null ||
        userData!['accountHolderName'] == null) {
      _showErrorDialog('Please add your bank account details first');
      return;
    }

    // Check if user has sufficient balance
    final walletBalance = userData?['walletBalance'] ?? 0;
    if (walletBalance <= 0) {
      _showErrorDialog('Insufficient balance for withdrawal');
      return;
    }

    // Calculate fee and final amount
    final fee = (walletBalance * 0.02).ceil(); // 2% fee
    final withdrawalAmount = walletBalance - fee;

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Emergency Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Withdrawal Amount: ₹$withdrawalAmount'),
            Text('Fee (2%): ₹$fee'),
            Text('Total Deduction: ₹$walletBalance'),
            const SizedBox(height: 16),
            const Text(
                'The amount will be transferred to your registered bank account.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateRazorpayPayout(withdrawalAmount);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdrawal Failed'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String payoutId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdrawal Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Your emergency withdrawal has been processed successfully.'),
            const SizedBox(height: 8),
            Text('Transaction ID: $payoutId'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateRazorpayPayout(int amount) async {
    setState(() {
      _isProcessingWithdrawal = true;
    });

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing your withdrawal...'),
          ],
        ),
      ),
    );

    try {
      // You should get these values securely from your backend
      final apiKey = 'rzp_test_Tln9ghzQ7Fr4yb';
      final apiSecret = 'oTy7CoJ2jJ7h7ClH9IxBZVVk';

      // Create unique reference ID
      final referenceId =
          'EW-${DateTime.now().millisecondsSinceEpoch}-${widget.uid.substring(0, 5)}';

      // API endpoint for Razorpay Fund Transfer API
      final url = Uri.parse('https://api.razorpay.com/v1/payouts');

      // Request body for fund transfer
      final payload = {
        'account_number': '4111111111111111', // Your Razorpay account number
        'amount': amount * 100, // Amount in paise
        'currency': 'INR',
        'mode': 'IMPS', // Or NEFT/RTGS based on your preference
        'purpose': 'payout',
        'queue_if_low_balance': true,
        'reference_id': referenceId,
        'narration': 'Emergency Withdrawal',
        'fund_account': {
          'account_type': 'bank_account',
          'bank_account': {
            'name': 'random',
            'ifsc': 'barb0jawfar',
            'account_number': '4111111111111111',
          },
        },
      };

      // Authorization header using Basic Auth
      final authString = base64Encode(utf8.encode('$apiKey:$apiSecret'));

      // Make API request
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $authString',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      // Close loading dialog
      Navigator.pop(context);

      // Process response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final payoutId = responseData['id'] as String;

        // Update wallet balance
        await _updateWalletBalance();

        // Record transaction
        await _recordEmergencyWithdrawal(payoutId);

        // Refresh transactions
        await fetchTransactions();

        // Show success dialog
        _showSuccessDialog(payoutId);
      } else {
        final errorData = jsonDecode(response.body);
        final errorDescription = errorData['error']['description'] as String? ??
            'Unknown error occurred';

        _showErrorDialog('Failed to process withdrawal: $errorDescription');
      }
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      _showErrorDialog('Failed to process withdrawal: $e');
    } finally {
      setState(() {
        _isProcessingWithdrawal = false;
      });
    }
  }

  Future<void> _updateWalletBalance() async {
    try {
      await FirebaseFirestore.instance
          .collection('worker_logins')
          .doc(widget.uid)
          .update({
        'walletBalance': 0, // Set to zero after full withdrawal
      });

      // Update local state
      setState(() {
        if (userData != null) {
          userData!['walletBalance'] = 0;
        }
      });
    } catch (e) {
      print('Error updating wallet balance: $e');
      throw e; // Re-throw to handle in calling function
    }
  }

  Future<void> _recordEmergencyWithdrawal(String payoutId) async {
    try {
      final walletBalance = userData?['walletBalance'] ?? 0;
      final fee = (walletBalance * 0.02).ceil(); // 2% fee
      final withdrawalAmount = walletBalance - fee;

      await FirebaseFirestore.instance
          .collection('worker_wallet_transactions')
          .doc(widget.uid)
          .collection('transactions')
          .add({
        'amount': withdrawalAmount,
        'fee': fee,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'withdrawal',
        'method': 'emergency',
        'status': 'completed',
        'payoutId': payoutId,
        'service': 'Emergency Withdrawal',
      });
    } catch (e) {
      print('Error recording transaction: $e');
      throw e; // Re-throw to handle in calling function
    }
  }

  Future<void> fetchTransactions() async {
    try {
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('worker_wallet_transactions')
          .doc(widget.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      setState(() {
        transactions = transactionsSnapshot.docs
            .map((doc) => {
                  ...doc.data(),
                  'id': doc.id,
                })
            .toList();
      });
    } catch (e) {
      print('Error fetching transactions: $e');
    }
  }

  // Add this to your fetchUserData method right after setting userData
  Future<void> fetchUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('worker_logins')
          .doc(widget.uid)
          .get();
      setState(() {
        userData = doc.data();
        // Set selectedDay from Firestore if it exists
        if (userData != null && userData!.containsKey('withdrawal_day')) {
          selectedDay = userData!['withdrawal_day'];
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return '***${accountNumber.substring(accountNumber.length - 4)}';
  }

  void _showBankDetails() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Material(
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bank Account Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Account Holder: ${userData?['accountHolderName'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Account Number: ${userData?['accountNumber'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'IFSC Code: ${userData?['ifscCode'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ));
      },
    );
  }

  Future<void> _selectWithdrawalDay(BuildContext context) async {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Withdrawal Day',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose the day of the month for automatic transfers',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Days grid
                      Container(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            childAspectRatio: 1,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: 31,
                          itemBuilder: (context, index) {
                            final day = index + 1;
                            final isSelected = selectedDay == day;

                            return GestureDetector(
                              onTap: () async {
                                setState(() {
                                  selectedDay = day;
                                });

                                // Save to Firestore after selecting the withdrawal day
                                await _saveWithdrawalDayToFirestore(day);

                                Navigator.pop(context);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    day.toString(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontSize: 18,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (selectedDay != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.calendar_today,
                                    color: Colors.blue[700], size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Withdrawal day: $selectedDay',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
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
        );
      },
    );
  }

// Function to save the selected withdrawal day to Firestore
  Future<void> _saveWithdrawalDayToFirestore(int day) async {
    try {
      // Get the current user
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Access the Firestore instance
        FirebaseFirestore firestore = FirebaseFirestore.instance;

        // Reference to the user's document in 'worker_logins' collection
        DocumentReference userDocRef =
            firestore.collection('worker_logins').doc(user.uid);

        // Update the withdrawal day
        await userDocRef.update({
          'withdrawal_day': day,
        });

        print("Withdrawal day saved successfully!");
      } else {
        print("User not logged in");
      }
    } catch (e) {
      print("Error saving withdrawal day: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final walletBalance = userData?['walletBalance'] ?? 0;
    final maskedAccountNumber =
        maskAccountNumber(userData?['accountNumber'] ?? '');

    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Earnings & Wallet',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          color: Colors.white, // Set the background color to white
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  // Main Balance Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Available Balance',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹$walletBalance',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Today's earnings and Escrow
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Today\'s Earnings',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${totalEarningsToday.toStringAsFixed(2)}', // Display today's total earnings
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors
                                    .white, // Set background color to white
                                border: Border.all(color: Colors.black12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'In Escrow (2 days)',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${totalEscrowAmount.toStringAsFixed(2)}', // Display the calculated total
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Emergency Withdrawal Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessingWithdrawal
                          ? null
                          : _processEmergencyWithdrawal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isProcessingWithdrawal
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Emergency Withdrawal (2% fee)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Withdraw and Bank Details Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Withdraw',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                maskedAccountNumber,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _showBankDetails,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.black12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Column(
                            children: const [
                              Text(
                                'Bank Details',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Manage Account',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Auto Withdrawal Day Selection
                  InkWell(
                    onTap: () => _selectWithdrawalDay(context),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Monthly Withdrawal Day',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedDay != null
                                    ? 'Funds will be transferred on day $selectedDay'
                                    : 'Tap to select withdrawal day',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Recent Transactions
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTransactionsList(),
                  const SizedBox(height: 24),

                  // Weekly Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This Week\'s Summary',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Total Earnings: ₹${totalEarningsThisWeek.toStringAsFixed(2)}', // Display total earnings
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Text(
                              'Average Rating: ',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '4.8',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildTransactionItem({
    required String title,
    required String date,
    required String amount,
    required String status,
    required bool isCredit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No recent transactions',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Container(
      color: Colors.white, // Set background color to white
      child: Column(
        children: transactions.map((transaction) {
          final timestamp = transaction['timestamp'] as Timestamp?;
          final date = timestamp != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  timestamp.millisecondsSinceEpoch,
                )
              : DateTime.now();

          final isEarning = transaction['type'] == 'earning';
          final amount = transaction['amount'] as num?;
          final service = transaction['service'] as String?;
          final status = transaction['status'] as String?;

          return Column(
            children: [
              _buildTransactionItem(
                title: service ?? 'Service',
                date: _formatDate(date),
                amount: '${isEarning ? '+' : '-'}₹${amount?.toString() ?? '0'}',
                status: _formatStatus(status ?? ''),
                isCredit: isEarning,
              ),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      return 'Yesterday';
    }
    return '${date.day} ${_getMonth(date.month)}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMonth(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  String _formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'in_escrow':
        return 'In Escrow';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }
}
