import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:handzy/pages/accounts_screen.dart';
import 'package:handzy/pages/services_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Service Model
class Service {
  final String title;
  final String imagePath;
  final Widget page;
  final double rating;

  Service({
    required this.title,
    required this.imagePath,
    required this.page,
    required this.rating,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: [
          HomeScreen(),
          ServicesPage(),
          AccountsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: const Color.fromARGB(255, 0, 0, 0),
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Services',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _hoveredIndex = -1;
  String _currentAddress = "Fetching location...";
  final TextEditingController _searchController = TextEditingController();
  List<Service> _allServices = [];
  List<Service> _filteredServices = [];
  final PageController _carouselController = PageController(
    viewportFraction: 0.8,
    initialPage: 0,
  );
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _initializeServices() {
    _allServices = [
      Service(
        title: 'Electrician',
        imagePath: 'lib/assets/images/electrician.png',
        page: const ElectricianPage(),
        rating: 4.8,
      ),
      Service(
        title: 'Plumber',
        imagePath: 'lib/assets/images/plumber.png',
        page: const PlumberPage(),
        rating: 4.7,
      ),
      Service(
        title: 'AC Repair',
        imagePath: 'lib/assets/images/ac_repair.png',
        page: const AcRepairPage(),
        rating: 4.9,
      ),
      Service(
        title: 'Fridge Repair',
        imagePath: 'lib/assets/images/fridge_repair.png',
        page: const FridgeRepairPage(),
        rating: 4.6,
      ),
      Service(
        title: 'Towing',
        imagePath: 'lib/assets/images/towing.png',
        page: const TowingPage(),
        rating: 4.8,
      ),
      Service(
        title: 'RO Service',
        imagePath: 'lib/assets/images/ro_service.png',
        page: const RoServicePage(),
        rating: 4.7,
      ),
    ];
    _filteredServices = List.from(_allServices);
  }

  Future<void> _callEmergencyServices() async {
    const emergencyNumber = 'tel:911';
    if (await canLaunch(emergencyNumber)) {
      await launch(emergencyNumber);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not initiate emergency call.')),
      );
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Location services are disabled. Please enable them.')));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location permissions are permanently denied')));
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _currentAddress = "Fetching location...";
    });

    final hasPermission = await _handleLocationPermission();

    if (!hasPermission) {
      setState(() {
        _currentAddress = "Location access denied";
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        setState(() {
          _currentAddress = place.locality ??
              place.subLocality ??
              place.subAdministrativeArea ??
              place.administrativeArea ??
              "Unknown location";
        });
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      setState(() {
        _currentAddress = "Error getting location";
      });
    }
  }

  void _filterServices(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredServices = List.from(_allServices);
      } else {
        _filteredServices = _allServices
            .where((service) =>
                service.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Widget _buildCarouselServiceCard(Service service, int index) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hoveredIndex = index;
        });
      },
      onExit: (_) {
        setState(() {
          _hoveredIndex = -1;
        });
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => service.page),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          transform: Matrix4.identity()
            ..scale(_hoveredIndex == index ? 1.1 : 1.0)
            ..rotateX(_hoveredIndex == index ? 0.05 : 0)
            ..rotateY(_hoveredIndex == index ? 0.05 : 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _hoveredIndex == index
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: _hoveredIndex == index ? 12 : 6,
                offset: Offset(0, _hoveredIndex == index ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: _hoveredIndex == index ? 100.0 : 90.0,
                height: _hoveredIndex == index ? 100.0 : 90.0,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(service.imagePath),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                service.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    service.rating.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
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
        backgroundColor: Colors.white, // Set the background color to white
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HANDZY',
                        style: GoogleFonts.libreBaskerville(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Find services that suit you!',
                        style: GoogleFonts.darumadropOne(
                          fontSize: 22,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filterServices,
                    decoration: InputDecoration(
                      hintText: 'Search for services...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterServices('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Location Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current Location: $_currentAddress',
                            style: TextStyle(color: Colors.blue[700]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_currentAddress == "Location access denied" ||
                            _currentAddress == "Error getting location")
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _getCurrentLocation,
                            color: Colors.blue[700],
                          ),
                      ],
                    ),
                  ),
                ),

                // Services Carousel
                _filteredServices.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'No services found matching "${_searchController.text}"',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 250,
                            child: PageView.builder(
                              controller: _carouselController,
                              itemCount: _filteredServices.length,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              itemBuilder: (context, index) {
                                return _buildCarouselServiceCard(
                                  _filteredServices[index],
                                  index,
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Page Indicator
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _filteredServices.length,
                              (index) => Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentPage == index
                                      ? Colors.blue
                                      : Colors.grey[300],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                // Emergency Services Banner
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: _callEmergencyServices,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emergency,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                '24/7 Emergency Services',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Get immediate assistance',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Coming Soon Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Coming Soon!',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
