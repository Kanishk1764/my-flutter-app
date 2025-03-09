import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:handzy/pages/wallet_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  _AccountsPageState createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _profileImageUrl;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;

    if (user != null) {
      try {
        final doc =
            await _firestore.collection('user_logins').doc(user.uid).get();
        setState(() {
          _userData = doc.data();
          _profileImageUrl = _userData?['profileImageUrl'];
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error fetching user data: $e"),
        ));
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("No user logged in."),
      ));
    }
  }

  void _navigateToPage(String page) {
    // Navigate to respective pages (for now, just show a simple route)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(page)),
          body: Center(child: Text("Welcome to $page page!")),
        ),
      ),
    );
  }

  Future<void> _pickImageAndUpload() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // Pick an image using image_picker
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        setState(() {
          _isUploading = false;
        });
        return; // User canceled the image picking
      }

      // Upload the picked image
      await _uploadProfilePicture(File(pickedFile.path));

      setState(() {
        // After successful upload, the profile image URL should be updated
        _profileImageUrl =
            _getProfileImageUrl(); // This will return the correct public URL
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to pick and upload image: ${e.toString()}')),
      );
    }
  }

// Function to upload the picked image to Supabase storage
  Future<void> _uploadProfilePicture(File imageFile) async {
    try {
      final fileExtension = path.extension(imageFile.path);
      final fileName = 'profile-picture$fileExtension';
      final filePath =
          'users/${_auth.currentUser?.uid}/$fileName'; // Path for the worker's profile picture

      // Upload the profile picture to Supabase storage
      final response =
          await _supabase.storage.from('documents').upload(filePath, imageFile);

      setState(() {
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
    }
  }

// Function to get the public URL for the uploaded image
  String _getProfileImageUrl() {
    final filePath =
        'users/${_auth.currentUser?.uid}/profile-picture.jpg'; // Path to the profile picture
    final baseUrl =
        'https://dsjeyaorfibuvddayxxw.supabase.co'; // Replace with your Supabase URL
    final publicUrl = '$baseUrl/storage/v1/object/public/documents/$filePath';

    return publicUrl;
  }

  void _initiateLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isUserLoggedIn', false);
    await prefs.setBool('isWorkerLoggedIn', false);
    Navigator.pushNamed(context, '/loginSignup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Pure white background
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _userData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "There's some problem with showing data. Please log in again.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initiateLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // Black background
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 50,
                            vertical: 15,
                          ),
                        ),
                        child: Text(
                          "Initiate Login",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section with Username and Profile Picture
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Username in proper styling
                            Text(
                              (_userData?['name'] ?? "User Name").toUpperCase(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF222222),
                                letterSpacing: -0.5,
                              ),
                            ),
                            // Profile picture/camera button
                            GestureDetector(
                              onTap: _isUploading
                                  ? null
                                  : _pickImageAndUpload, // Call function to pick and upload image
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Color(0xFFE8E8E8),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                  image: _profileImageUrl != null
                                      ? DecorationImage(
                                          image:
                                              NetworkImage(_profileImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _profileImageUrl == null
                                    ? Icon(
                                        Icons.camera_alt,
                                        size: 24,
                                        color: Color(0xFF555555),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Subtitle text
                      Text(
                        "Manage your account",
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF777777),
                          fontWeight: FontWeight.normal,
                        ),
                      ),

                      SizedBox(height: 24),

                      // Main Navigation Cards
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _mainNavCard(
                              "HELP", Icons.help_outline, Color(0xFFE6F0F9)),
                          _mainNavCard(
                            "WALLET",
                            Icons.account_balance_wallet,
                            Color(0xFFE8F5E9),
                            onTap: () {
                              // Correct onTap function
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => WalletScreen()),
                              );
                            },
                          ),
                          _mainNavCard(
                              "ACTIVITY", Icons.access_time, Color(0xFFF0E7F5)),
                        ],
                      ),

                      SizedBox(height: 24),

                      // Divider
                      Container(
                        height: 1,
                        color: Color(0xFFE0E0E0),
                        margin: EdgeInsets.symmetric(vertical: 24),
                      ),

                      // Settings Menu Items
                      _menuItem(
                        "SETTINGS",
                        Icons.settings,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => SettingsPage()),
                          );
                        },
                      ),

                      SizedBox(height: 16),

                      _menuItem(
                        "MY ACCOUNT",
                        Icons.account_circle,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MyAccountPage()),
                          );
                        },
                      ),

                      SizedBox(height: 16),

                      _menuItem(
                        "LEGAL",
                        Icons.gavel,
                        onTap: () => _navigateToPage('Legal'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _mainNavCard(String title, IconData icon, Color bgColor,
      {VoidCallback? onTap}) {
    return GestureDetector(
      // Keep GestureDetector for other taps
      onTap: onTap, // Use the provided onTap function
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: Color(0xFF222222).withOpacity(0.6),
            ),
            SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(String title, IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: Color(0xFF777777),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Color(0xFF222222),
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}

///SETTINGS PAGE
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _name;
  String? _email;
  String? _phoneNumber;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('user_logins')
            .doc(user.uid)
            .get();
        final data = doc.data();

        // Get profile image URL from Supabase
        final fileName =
            'profile-picture.jpg'; // Static name for profile picture
        final imageUrl = Supabase.instance.client.storage
            .from('documents')
            .getPublicUrl('users/${user.uid}/$fileName');

        setState(() {
          _name = data?['name'] ?? 'N/A';
          _email = data?['email'] ?? 'N/A';
          _phoneNumber = data?['phone'] ?? 'N/A';
          _profileImageUrl = imageUrl; // Update the URL
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();

      // Remove user login status (set to false)
      await prefs.setBool('isUserLoggedIn', false);

      // Optionally, remove any other saved data if needed
      // await prefs.remove('otherKey'); // If you have other keys to remove
      Navigator.pushNamedAndRemoveUntil(
          context, '/loginSignup', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error signing out: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Settings"),
        backgroundColor: Colors.yellow[700],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Info Section
          Row(
            children: [
              _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  ? CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(_profileImageUrl!),
                    )
                  : CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.grey[300],
                      child:
                          Icon(Icons.person, size: 40, color: Colors.grey[600]),
                    ),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_name ?? "Loading...").toUpperCase(),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _phoneNumber ?? "Loading...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _email ?? "Loading...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          // Email Verification Warning
          if (_email != null &&
              !FirebaseAuth.instance.currentUser!.emailVerified)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Verify your email for added security",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16),
          // Settings Options
          _buildSettingsTile(Icons.home, "Add Home", () {}),
          _buildSettingsTile(Icons.work, "Add Work", () {}),
          _buildSettingsTile(Icons.shortcut, "Shortcuts", () {}),
          _buildSettingsTile(Icons.lock, "Privacy", () {}),
          _buildSettingsTile(Icons.palette, "Appearance", () {}),
          _buildSettingsTile(Icons.receipt, "Invoice Information", () {}),
          _buildSettingsTile(Icons.notifications, "Communication", () {}),
          SizedBox(height: 24),
          // Sign Out Button
          Center(
            child: GestureDetector(
              onTap: () => _signOut(context),
              child: Text(
                "Sign Out",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.black),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  _MyAccountPageState createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  List<Map<String, dynamic>> _paymentMethods = [];
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _auth.currentUser;

    if (user != null) {
      try {
        final doc =
            await _firestore.collection('user_logins').doc(user.uid).get();
        final data = doc.data();

        List<Map<String, dynamic>> paymentMethods = [];
        if (data != null && data.containsKey('payment_methods')) {
          final methods = data['payment_methods'] as List<dynamic>;
          paymentMethods = methods
              .map((method) => Map<String, dynamic>.from(method))
              .toList();
        }

        // Get profile image URL from Supabase
        final fileName = '${user.uid}-profile-picture.jpg';
        final imageUrl = Supabase.instance.client.storage
            .from('users')
            .getPublicUrl('${user.uid}/profile-picture/$fileName');

        setState(() {
          _userData = data;
          _paymentMethods = paymentMethods;
          _profileImageUrl = imageUrl;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching user data: $e")),
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No user logged in.")),
      );
    }
  }

  String _formatSignupDate(String? dateString) {
    if (dateString == null) return "N/A";
    try {
      final dateTime = DateTime.parse(dateString);
      return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatCardInfo(Map<String, dynamic> method) {
    if (method['type'] == 'card') {
      return "•••• ${method['lastFour'] ?? '****'} | ${method['cardholderName'] ?? 'Card Holder'}";
    } else if (method['type'] == 'upi') {
      return "${method['upiId'] ?? 'UPI ID'}";
    }
    return "Unknown payment method";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            "My Account",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
          iconTheme: IconThemeData(
            color: Colors.white, // Change the color of the back button to white
          ),
        ),
        body: Container(
          color: Colors.white,
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _userData == null
                  ? Center(
                      child: Text("No user data available."),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Profile Header
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (_userData?['name'] ?? "User")
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (_userData?['name'] ?? "User Name")
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _userData?['email'] ?? "Email",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _userData?['phone'] ?? "Phone",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Account Info Section
                          _sectionHeader("Account Information"),
                          _infoTile(
                            "Member Since",
                            _formatSignupDate(_userData?['signup_date']),
                            Icons.calendar_today,
                          ),
                          _infoTile(
                            "Wallet Balance",
                            "₹${_userData?['wallet_balance'] ?? '0'}",
                            Icons.account_balance_wallet,
                          ),

                          SizedBox(height: 24),

                          // Payment Methods
                          _sectionHeader("Payment Methods"),
                          if (_paymentMethods.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                "No payment methods added yet",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
                              itemCount: _paymentMethods.length,
                              itemBuilder: (context, index) {
                                final method = _paymentMethods[index];
                                return _paymentMethodTile(method);
                              },
                            ),

                          SizedBox(height: 16),
                        ],
                      ),
                    ),
        ));
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodTile(Map<String, dynamic> method) {
    final bool isCard = method['type'] == 'card';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isCard ? Icons.credit_card : Icons.account_balance,
              color: Colors.grey[600],
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCard ? "Credit/Debit Card" : "UPI",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatCardInfo(method),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () {
                // TODO: Implement delete payment method
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Remove payment method")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
