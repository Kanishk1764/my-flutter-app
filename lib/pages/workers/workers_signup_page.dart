import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class WorkerSignupPage extends StatefulWidget {
  @override
  _WorkerSignupPageState createState() => _WorkerSignupPageState();
}

class _WorkerSignupPageState extends State<WorkerSignupPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<String> _services = [
    'Electric Repair',
    'Plumbing Services',
    'AC Repair',
    'Fridge Repair',
    'Towing',
    'RO Service',
  ];
  String? _selectedService;

  void _proceedToPhoneInput() {
    if (_nameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkerPhoneInputPage(
          name: _nameController.text,
          password: _passwordController.text,
          phone: _phoneController.text,
          service: _selectedService!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button and HANDZY title
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          '←',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'HANDZY',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24), // Balance for the back button
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // Name field
                const Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xDDDDDDDD)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Password field
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xDDDDDDDD)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Phone field
                const Text(
                  'Phone Number',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xDDDDDDDD)),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Service dropdown
                const Text(
                  'Service to Provide',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Color(0xDDDDDDDD)),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.black),
                      ),
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedService,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF666666),
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    items: _services
                        .map((service) => DropdownMenuItem<String>(
                              value: service,
                              child: Text(
                                service,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedService = value),
                  ),
                ),

                const SizedBox(height: 60),

                // Proceed button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _proceedToPhoneInput,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(27),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Proceed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Worker Phone Input Page
class WorkerPhoneInputPage extends StatefulWidget {
  final String name;
  final String password;
  final String phone;
  final String service;

  const WorkerPhoneInputPage({
    Key? key,
    required this.name,
    required this.password,
    required this.phone,
    required this.service,
  }) : super(key: key);

  @override
  _WorkerPhoneInputPageState createState() => _WorkerPhoneInputPageState();
}

class _WorkerPhoneInputPageState extends State<WorkerPhoneInputPage> {
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (widget.phone.isEmpty) {
      Fluttertoast.showToast(msg: "Phone number is required");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Format phone number properly - ensure it has +91 prefix
      final phoneNumber = widget.phone.trim().startsWith('+91') 
          ? widget.phone.trim()
          : "+91${widget.phone.trim()}";
      
      // Make a direct HTTP call to your Express server
      final http.Response response = await http.post(
        Uri.parse('http://192.168.1.16:3003/worker/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phoneNumber,
          'channel': 'sms'
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw 'Failed to send OTP: ${responseData['message']}';
      }
      
      // Navigate to OTP Verification Page with all worker details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerOtpVerificationPage(
            name: widget.name,
            password: widget.password,
            phone: widget.phone,
            service: widget.service,
          ),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your mobile number',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              TextField(
                enabled: false, // Phone number is pre-filled and cannot be edited
                controller: TextEditingController(text: widget.phone),
                style: TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  prefixText: '+91 ',
                  prefixStyle: TextStyle(color: Colors.black),
                  hintText: 'Phone number',
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'By proceeding, you are consenting to receive calls or SMS messages.',
                style: TextStyle(color: Colors.black54),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Next',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Worker Password Verification Page
class WorkerPasswordVerificationPage extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> workerData;

  WorkerPasswordVerificationPage(
      {required this.phone, required this.workerData});

  @override
  _WorkerPasswordVerificationPageState createState() =>
      _WorkerPasswordVerificationPageState();
}

class _WorkerPasswordVerificationPageState
    extends State<WorkerPasswordVerificationPage> {
  final _passwordController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _verifyPassword() async {
    print("Sign In button pressed"); // Debugging statement

    if (_passwordController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      print("Verifying password..."); // Debugging statement

      // Fetch worker data from Firestore using phone number
      final workerQuery = await _firestore
          .collection('worker_logins')
          .where('phone', isEqualTo: widget.phone)
          .get();

      if (workerQuery.docs.isEmpty) {
        Fluttertoast.showToast(msg: "Worker not found");
        return;
      }

      final workerData = workerQuery.docs.first.data();

      // Verify password
      if (_passwordController.text != workerData['password']) {
        Fluttertoast.showToast(msg: "Incorrect password");
        return;
      }

      print("Worker signed in successfully"); // Debugging statement

      // Save worker data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isWorkerLoggedIn', true);
      prefs.setString('workerId', workerData['uid']);
      prefs.setString('workerEmail', workerData['email'] ?? '');
      prefs.setString('workerName', workerData['name']);
      prefs.setString('workerPhone', widget.phone);

      print("Navigating to home page..."); // Debugging statement
      Navigator.pushReplacementNamed(context, '/workerhome');
    } catch (e) {
      print("Error during sign-in: $e"); // Debugging statement
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              Text(
                'Sign in to continue',
                style: TextStyle(color: Colors.black54),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: Colors.black),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: TextStyle(color: Colors.black54),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Implement forgot password functionality
                },
                child: Text('Forgot password?',
                    style: TextStyle(color: Colors.black)),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyPassword,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('Sign In', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// OTP verification page remains unchanged
class WorkerOtpVerificationPage extends StatefulWidget {
  final String name;
  final String password;
  final String phone;
  final String service;

  const WorkerOtpVerificationPage({
    Key? key,
    required this.name,
    required this.password,
    required this.phone,
    required this.service,
  }) : super(key: key);

  @override
  _WorkerOtpVerificationPageState createState() => _WorkerOtpVerificationPageState();
}

class _WorkerOtpVerificationPageState extends State<WorkerOtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getOTP() {
    return _controllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    if (otp.length != 6) {
      Fluttertoast.showToast(msg: "Please enter complete OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Format phone number properly
      final phoneNumber = widget.phone.trim().startsWith('+91') 
          ? widget.phone.trim()
          : "+91${widget.phone.trim()}";
      
      // Direct HTTP call to verify OTP
      final http.Response response = await http.post(
        Uri.parse('http://192.168.1.16:3003/worker/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phoneNumber,
          'code': otp,
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw 'Verification failed: ${responseData['message'] ?? "Unknown error"}';
      }

      // Create Firebase user
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: "${widget.password}@gmail.com", // Use phone number as email
        password: widget.password,
      );

      final String uid = userCredential.user!.uid;

      // Save worker details to Firestore
      await FirebaseFirestore.instance.collection('worker_logins').doc(uid).set({
        'uid': uid,
        'name': widget.name,
        'password': widget.password,
        'phone': widget.phone,
        'service': widget.service,
        'createdAt': FieldValue.serverTimestamp(),
        'walletBalance': 0.0,
        'pendingAmount': 0.0,
      });
      await FirebaseDatabase.instance.ref('workers/$uid').set({
        'rating': 5.0,
        'ratingTimes':0,
      });


      // Navigate to Bank Details Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BankDetailsPage(uid: uid),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Invalid OTP or verification error: ${e.toString()}");
      print("Invalid otp or verification error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOTP() async {
    setState(() => _isResending = true);

    try {
      // Format phone number properly
      final phoneNumber = widget.phone.trim().startsWith('+91') 
          ? widget.phone.trim()
          : "+91${widget.phone.trim()}";
      
      // Make a direct HTTP call to your Express server
      final http.Response response = await http.post(
        Uri.parse('http://192.168.1.16:3003/worker/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phoneNumber,
          'channel': 'sms'
        }),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw 'Failed to resend OTP: ${responseData['message']}';
      }
      
      Fluttertoast.showToast(msg: "OTP resent successfully");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    } finally {
      setState(() => _isResending = false);
    }
  }

  Widget _buildOTPBox(int index) {
    return Container(
      width: 40,
      height: 40,
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.black,
            width: 1,
          ),
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number, 
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
        ),
        decoration: InputDecoration(
          counterText: "",
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        title: Text(
          'Verify OTP',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              Text(
                'Enter the 6-digit OTP sent to',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '+91 ${widget.phone}',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (index) => _buildOTPBox(index),
                ),
              ),
              SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Confirm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 16),
              TextButton(
                onPressed: _isResending ? null : _resendOTP,
                child: _isResending 
                  ? SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      )
                    )
                  : Text(
                      "Resend OTP",
                      style: TextStyle(color: Colors.black),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BankDetailsPage extends StatefulWidget {
  final String uid;

  const BankDetailsPage({
    Key? key,
    required this.uid,
  }) : super(key: key);

  @override
  _BankDetailsPageState createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscCodeController = TextEditingController();
  final TextEditingController _accountHolderNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveBankDetails() async {
    if (_accountNumberController.text.isEmpty ||
        _ifscCodeController.text.isEmpty ||
        _accountHolderNameController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill in all fields!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save bank details to Firestore
      await FirebaseFirestore.instance
          .collection('worker_logins')
          .doc(widget.uid)
          .update({
        'accountNumber': _accountNumberController.text,
        'ifscCode': _ifscCodeController.text.toUpperCase(),
        'accountHolderName': _accountHolderNameController.text,
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerDocumentUploads(uid: widget.uid),
        ),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Error saving bank details: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.black),
        title: Text(
          'Bank Details',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              Text(
                'Account Holder Name',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _accountHolderNameController,
                decoration: InputDecoration(
                  hintText: 'Enter account holder name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Account Number',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter account number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'IFSC Code',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _ifscCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Enter IFSC code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBankDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save Bank Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorkerDocumentUploads extends StatefulWidget {
  final String uid;

  const WorkerDocumentUploads({Key? key, required this.uid}) : super(key: key);

  @override
  _WorkerDocumentUploadsState createState() => _WorkerDocumentUploadsState();
}

class _WorkerDocumentUploadsState extends State<WorkerDocumentUploads> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  File? _aadharFile;
  File? _licenseFile;
  File? _panFile;
  bool _isUploading = false;
  bool _isProcessingAadhaar = false;
  String _extractedAadhaarNumber = 'Not extracted yet';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.storage,
    ].request();
  }

  Future<void> _pickDocument(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      
      setState(() {
        if (type == 'aadhar') {
          _aadharFile = file;
          if (_aadharFile != null) {
            _processAadhaarDocument(_aadharFile!);
          }
        } else if (type == 'license') {
          _licenseFile = file;
        } else if (type == 'pan') {
          _panFile = file;
        }
      });
    }
  }

  Future<void> _processAadhaarDocument(File file) async {
    setState(() {
      _isProcessingAadhaar = true;
      _extractedAadhaarNumber = 'Processing...';
    });

    try {
      final fileExtension = path.extension(file.path).toLowerCase();
      
      if (fileExtension == '.jpg' || fileExtension == '.jpeg' || fileExtension == '.png') {
        // Process image file
        await _extractAadhaarNumber(XFile(file.path));
      } else {
        setState(() {
          _extractedAadhaarNumber = 'Unsupported file format. Please upload an image file.';
          _isProcessingAadhaar = false;
        });
      }
    } catch (e) {
      setState(() {
        _extractedAadhaarNumber = 'Error processing document: $e';
        _isProcessingAadhaar = false;
      });
    }
  }

  Future<void> _extractAadhaarNumber(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textDetector = GoogleMlKit.vision.textRecognizer();
      final RecognizedText recognizedText = await textDetector.processImage(inputImage);
      
      String allText = '';
      String? aadhaarNumber;
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final lineText = line.text;
          allText += '$lineText\n';
          
          // Pattern matching for Aadhaar number
          // Look for 12 digits, possibly with spaces
          final cleanText = lineText.replaceAll(RegExp(r'[^\d]'), '');
          
          // Check for 12-digit number pattern
          if (cleanText.length >= 12) {
            for (int i = 0; i <= cleanText.length - 12; i++) {
              final potentialAadhaar = cleanText.substring(i, i + 12);
              // Validate with Aadhaar number format logic
              if (_isValidAadhaarFormat(potentialAadhaar)) {
                aadhaarNumber = _formatAadhaarNumber(potentialAadhaar);
                break;
              }
            }
          }
          
          // Also look for text that mentions 'Aadhaar' near numbers
          if (lineText.toLowerCase().contains('aadhar') || 
              lineText.toLowerCase().contains('aadhaar') ||
              lineText.toLowerCase().contains('आधार')) {
            // Extract nearby digits
            final digits = RegExp(r'\d+').allMatches(lineText).map((m) => m.group(0)!).join('');
            if (digits.length >= 12) {
              final potentialAadhaar = digits.substring(0, 12);
              if (_isValidAadhaarFormat(potentialAadhaar)) {
                aadhaarNumber = _formatAadhaarNumber(potentialAadhaar);
              }
            }
          }
        }
      }
      
      await textDetector.close();
      
      setState(() {
        _extractedAadhaarNumber = aadhaarNumber ?? 'No Aadhaar number detected';
        _isProcessingAadhaar = false;
      });
    } catch (e) {
      setState(() {
        _extractedAadhaarNumber = 'Error extracting text: $e';
        _isProcessingAadhaar = false;
      });
    }
  }
  
  // Simple Aadhaar format validation
  bool _isValidAadhaarFormat(String number) {
    // Basic check: 12 digits
    if (number.length != 12) return false;
    
    // Check that it's not a repeated digit like 111111111111
    if (RegExp(r'^(\d)\1+$').hasMatch(number)) return false;
    
    // Check that it doesn't start with 0 or 1 (Aadhaar starts with 2-9)
    if (number.startsWith('0') || number.startsWith('1')) return false;
    
    return true;
  }
  
  // Format Aadhaar as XXXX XXXX XXXX
  String _formatAadhaarNumber(String number) {
    if (number.length != 12) return number;
    return '${number.substring(0, 4)} ${number.substring(4, 8)} ${number.substring(8)}';
  }

  Future<void> _uploadDocuments() async {
    if (_aadharFile == null || _licenseFile == null || _panFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload all documents!')),
      );
      return;
    }

    if (_extractedAadhaarNumber == 'No Aadhaar number detected' || 
        _extractedAadhaarNumber == 'Processing...' ||
        _extractedAadhaarNumber.startsWith('Error') ||
        _extractedAadhaarNumber.startsWith('Unsupported')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract a valid Aadhaar number. Please try a clearer image.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Upload files to Supabase
      final aadharExtension = path.extension(_aadharFile!.path);
      final licenseExtension = path.extension(_licenseFile!.path);
      final panExtension = path.extension(_panFile!.path);

      final aadharFileName = 'aadhar$aadharExtension';
      final licenseFileName = 'license$licenseExtension';
      final panFileName = 'pan$panExtension';

      // Creating paths in the worker's folder in Supabase storage
      final aadharFilePath = 'workers/${widget.uid}/$aadharFileName';
      final licenseFilePath = 'workers/${widget.uid}/$licenseFileName';
      final panFilePath = 'workers/${widget.uid}/$panFileName';

      // Upload files to Supabase storage under the worker's folder
      await _supabase.storage
          .from('documents')
          .upload(aadharFilePath, _aadharFile!);
      await _supabase.storage
          .from('documents')
          .upload(licenseFilePath, _licenseFile!);
      await _supabase.storage.from('documents').upload(panFilePath, _panFile!);

      // Store the extracted Aadhaar number in Firestore
      final cleanAadhaarNumber = _extractedAadhaarNumber.replaceAll(' ', '');
      await _firestore.collection('worker_logins').doc(widget.uid).set({
        'aadhar_number': cleanAadhaarNumber,
        'documents_uploaded': true,
        'documents_uploaded_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documents uploaded and Aadhaar number saved!')),
      );

      // Navigate to the next screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkerProfilePictureCapture(uid: widget.uid),
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      '←',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Upload Documents',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24), // Balance for the back button
                ],
              ),
            ),

            const SizedBox(height: 40),
            // Aadhar Upload with OCR information
            Column(
              children: [
                Text(
                  'Aadhar Card (Image only)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _pickDocument('aadhar'),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[400]!,
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 30,
                          color: Colors.grey[600],
                        ),
                        SizedBox(height: 8),
                        Text(
                          _aadharFile != null ? path.basename(_aadharFile!.path) : 'Tap to upload JPG/PNG',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isProcessingAadhaar ? Colors.grey[100] : 
                           _extractedAadhaarNumber.startsWith('No') || 
                           _extractedAadhaarNumber.startsWith('Error') || 
                           _extractedAadhaarNumber.startsWith('Unsupported') ? 
                           Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isProcessingAadhaar ? 
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Extracting Aadhaar number...'),
                      ],
                    ) :
                    Row(
                      children: [
                        Icon(
                          _extractedAadhaarNumber.startsWith('No') || 
                          _extractedAadhaarNumber.startsWith('Error') || 
                          _extractedAadhaarNumber.startsWith('Unsupported') ? 
                          Icons.error_outline : Icons.check_circle_outline,
                          color: _extractedAadhaarNumber.startsWith('No') || 
                                 _extractedAadhaarNumber.startsWith('Error') || 
                                 _extractedAadhaarNumber.startsWith('Unsupported') ? 
                                 Colors.red : Colors.green,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Aadhaar: $_extractedAadhaarNumber',
                            style: TextStyle(
                              fontSize: 14,
                              color: _extractedAadhaarNumber.startsWith('No') || 
                                     _extractedAadhaarNumber.startsWith('Error') || 
                                     _extractedAadhaarNumber.startsWith('Unsupported') ? 
                                     Colors.red[800] : Colors.green[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            // License Upload
            _buildUploadSection(
                'License', _licenseFile, () => _pickDocument('license')),
            SizedBox(height: 24),
            // PAN Card Upload
            _buildUploadSection(
                'PAN Card', _panFile, () => _pickDocument('pan')),
            Spacer(),
            // Confirm Button
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: (_isUploading || _isProcessingAadhaar) ? null : _uploadDocuments,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(36),
                  ),
                ),
                child: _isUploading
                    ? SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Confirm', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection(String label, File? file, VoidCallback onTap) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 100,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[400]!,
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 30,
                  color: Colors.grey[600],
                ),
                SizedBox(height: 8),
                Text(
                  file != null ? path.basename(file.path) : 'Tap to upload',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class WorkerProfilePictureCapture extends StatefulWidget {
  final String uid;

  const WorkerProfilePictureCapture({Key? key, required this.uid}) : super(key: key);

  @override
  State<WorkerProfilePictureCapture> createState() => _WorkerProfilePictureCaptureState();
}

class _WorkerProfilePictureCaptureState extends State<WorkerProfilePictureCapture> {
  CameraController? _cameraController;
  List<CameraDescription> cameras = [];
  bool _isInitialized = false;
  bool _isUploading = false;
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No camera found')),
        );
        return;
      }

      // Use front camera if available
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize camera: ${e.toString()}')),
      );
    }
  }

  Future<void> _takePicture() async {
    if (!_isInitialized || _cameraController == null) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final XFile image = await _cameraController!.takePicture();
      
      // Upload the picture to Supabase
      await _uploadProfilePicture(File(image.path));
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take picture: ${e.toString()}')),
      );
    }
  }

  Future<void> _uploadProfilePicture(File imageFile) async {
  try {
    final fileExtension = path.extension(imageFile.path);
    final fileName = 'profile-picture$fileExtension';
    final filePath = 'workers/${widget.uid}/$fileName';

    // Upload profile picture to Supabase storage
    await _supabase.storage
        .from('documents')
        .upload(filePath, imageFile);

    // Get the public URL of the uploaded profile picture
    final String imageUrl = _supabase.storage
        .from('documents')
        .getPublicUrl(filePath);

    // Update Firestore with the profile picture URL
    await FirebaseFirestore.instance
        .collection('worker_logins')
        .doc(widget.uid)
        .update({
      'profilePictureUrl': imageUrl,
    });

    // Fetch worker data from Firestore
    final DocumentSnapshot workerDoc = await FirebaseFirestore.instance
        .collection('worker_logins')
        .doc(widget.uid)
        .get();

    final Map<String, dynamic> workerData = workerDoc.data() as Map<String, dynamic>;

    // Save worker details in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isWorkerLoggedIn', true);
    prefs.setString('workerId', workerData['uid']);
    prefs.setString('workerEmail', workerData['email'] ?? '');
    prefs.setString('workerName', workerData['name']);
    prefs.setString('workerPhone', workerData['phone']);

    setState(() {
      _isUploading = false;
    });

    // Navigate to worker home page
    Navigator.pushNamed(context, '/workerhome');
  } catch (e) {
    setState(() {
      _isUploading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: ${e.toString()}')),
    );
  }
}

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: CameraPreview(_cameraController!),
            ),
          ),
          
          // Overlay with circular mask for preview
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              color: Colors.black54,
              child: Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
          
          // Back button
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          
          // Camera button and text
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Curved arrow and text
                    Positioned(
                      right: MediaQuery.of(context).size.width * 0.3,
                      bottom: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(100, 60),
                            painter: CurvedArrowPainter(),
                          ),
                          Positioned(
                            bottom: 30,
                            right: 5,
                            child: Text(
                              'Click for picture',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Script',
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Camera button
                    GestureDetector(
                      onTap: _isUploading ? null : _takePicture,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: _isUploading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : Center(
                                child: Container(
                                  height: 65,
                                  width: 65,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for the curved arrow
class CurvedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    // Starting point
    path.moveTo(size.width * 0.8, size.height * 0.2);
    // Curved path
    path.quadraticBezierTo(
      size.width * 0.2, size.height * 0.1,
      0, size.height * 0.8,
    );

    // Arrow head
    path.moveTo(0, size.height * 0.8);
    path.lineTo(10, size.height * 0.6);
    path.moveTo(0, size.height * 0.8);
    path.lineTo(15, size.height * 0.85);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}