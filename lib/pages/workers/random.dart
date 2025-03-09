import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HandzyAccountPage extends StatefulWidget {
  const HandzyAccountPage({super.key});

  @override
  _HandzyAccountPageState createState() => _HandzyAccountPageState();
}

class _HandzyAccountPageState extends State<HandzyAccountPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserName;
  String? _profileImageUrl;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user_logins')
            .doc(user.uid)
            .get();

        setState(() {
          _userData = userDoc.data();
          _currentUserName = _userData?['name'];
          _profileImageUrl = _userData?['profileImageUrl'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          'Handzy Account',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          indicatorColor: Colors.black,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Account Info'),
            Tab(text: 'Security'),
            Tab(text: 'Privacy & Data'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(
                  currentUserName: _currentUserName,
                  profileImageUrl: _profileImageUrl,
                ),
                AccountInfoTab(),
                SecurityTab(),
                PrivacyDataTab(),
              ],
            ),
    );
  }
}

class OverviewTab extends StatelessWidget {
  final String? currentUserName;
  final String? profileImageUrl;

  const OverviewTab({super.key, this.currentUserName, this.profileImageUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                backgroundImage: profileImageUrl != null
                    ? NetworkImage(profileImageUrl!)
                    : null,
                child: profileImageUrl == null
                    ? Icon(Icons.person, size: 40, color: Colors.grey[700])
                    : null,
              ),
              SizedBox(width: 16),
              Text(
                'Welcome, ${currentUserName ?? "Guest"}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 16),
          Text(
            'Manage your info, security, and data to make Handzy work better for you.',
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          ),
          SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle, color: Colors.blue, size: 40),
                      SizedBox(width: 8),
                      Text(
                        'Complete your account checkup',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete your account checkup to make Handzy work better for you and keep you secure.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Handle checkup button action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Begin checkup',
                      style: TextStyle(color: Colors.white),
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
}

class AccountInfoTab extends StatefulWidget {
  const AccountInfoTab({super.key});

  @override
  _AccountInfoTabState createState() => _AccountInfoTabState();
}

class _AccountInfoTabState extends State<AccountInfoTab> {
  String? _name;
  String? _phoneNumber;
  String? _email;

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
  }

  Future<void> _fetchAccountInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('user_logins')
            .doc(user.uid)
            .get();

        final data = doc.data();
        setState(() {
          _name = data?['name'];
          _phoneNumber = data?['phone'];
          _email = data?['email'];
        });
      }
    } catch (e) {
      print("Error fetching account info: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Account Info",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow("Name", _name ?? "Loading..."),
                  Divider(),
                  _buildInfoRow(
                    "Phone number",
                    _phoneNumber ?? "Loading...",
                    icon: Icons.verified,
                    iconColor: Colors.green,
                  ),
                  Divider(),
                  _buildInfoRow(
                    "Email",
                    _email ?? "Loading...",
                    icon: Icons.warning,
                    iconColor: Colors.amber,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value,
      {IconData? icon, Color? iconColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 16, color: Colors.black),
              ),
            ],
          ),
        ),
        if (icon != null)
          Icon(
            icon,
            color: iconColor,
          ),
      ],
    );
  }
}

class PrivacyDataTab extends StatefulWidget {
  const PrivacyDataTab({super.key});

  @override
  _PrivacyDataTabState createState() => _PrivacyDataTabState();
}

class _PrivacyDataTabState extends State<PrivacyDataTab> {
  String? _privacyNote;

  @override
  void initState() {
    super.initState();
    _fetchPrivacyNote();
  }

  Future<void> _fetchPrivacyNote() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_info')
          .doc('privacy')
          .get();
      setState(() {
        _privacyNote = doc.data()?['note'] ?? "No privacy note found.";
      });
    } catch (e) {
      print("Error fetching privacy note: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _privacyNote ?? "Loading privacy data...",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class SecurityTab extends StatelessWidget {
  const SecurityTab({super.key});

  void _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error during logout: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Security",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Do you want to logout of this device?",
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _logout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
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
}
