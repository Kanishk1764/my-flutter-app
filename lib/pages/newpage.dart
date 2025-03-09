import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  _PhoneInputPageState createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyPhone() async {
    if (_phoneController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter phone number");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Format phone number properly - ensure it has +91 prefix
      final phoneNumber = _phoneController.text.trim().startsWith('+91') 
          ? _phoneController.text.trim()
          : "+91${_phoneController.text.trim()}";
      
      // Make a direct HTTP call to your Express server
      final http.Response response = await http.post(
        Uri.parse('http://192.168.1.16:3003/send-otp'),
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
      
      // Check if the user exists in Firestore to maintain that part of the original logic
      final userQuery = await FirebaseFirestore.instance
          .collection('user_logins')
          .where('phone', isEqualTo: _phoneController.text)
          .get();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OTPVerificationPage(
            phone: _phoneController.text,
            isExistingUser: userQuery.docs.isNotEmpty,
            userData: userQuery.docs.isNotEmpty
                ? userQuery.docs.first.data()
                : null,
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
                controller: _phoneController,
                keyboardType: TextInputType.phone,
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
                  onPressed: _isLoading ? null : _verifyPhone,
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

class OTPVerificationPage extends StatefulWidget {
  final String phone;
  final bool isExistingUser;
  final Map<String, dynamic>? userData;

  const OTPVerificationPage({
    super.key, 
    required this.phone,
    required this.isExistingUser,
    this.userData,
  });

  @override
  OTPVerificationPageState createState() => OTPVerificationPageState();
}

class OTPVerificationPageState extends State<OTPVerificationPage> {
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
      
      // Create request body based on whether user exists or not
      Map<String, dynamic> requestBody = {
        'phone': phoneNumber,
        'code': otp,
      };
      
      // Direct HTTP call to verify OTP
      final http.Response response = await http.post(
        Uri.parse('http://192.168.1.16:3003/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      
      final responseData = json.decode(response.body);
      
      if (response.statusCode != 200 || responseData['success'] != true) {
        throw 'Verification failed: ${responseData['message'] ?? "Unknown error"}';
      }

      // Store login data in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isUserLoggedIn', true);
      
      if (responseData['user'] != null) {
        prefs.setString('userId', responseData['user']['id'] ?? '');
        prefs.setString('userPhone', widget.phone);
      }
      
      if (responseData['session'] != null) {
        prefs.setString('authToken', responseData['session']['access_token'] ?? '');
      }

      // Navigate based on user existence
      if (widget.isExistingUser) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PasswordVerificationPage(
              phone: widget.phone,
              userData: widget.userData!,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => EmailInputPage(phone: widget.phone),
          ),
        );
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Invalid OTP or verification error: ${e.toString()}");
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
        Uri.parse('http://192.168.1.16:3003/send-otp'),
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

class EmailInputPage extends StatefulWidget {
  final String phone;

  const EmailInputPage({super.key, required this.phone});

  @override
  _EmailInputPageState createState() => _EmailInputPageState();
}

class _EmailInputPageState extends State<EmailInputPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<void> _signUp() async {
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please fill all fields");
      return;
    }

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      await _firestore
          .collection('user_logins')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text,
        'phone': widget.phone,
        'email': _emailController.text,
        'password': _passwordController.text,
        'signup_date': DateTime.now().toString(),
        'wallet_balance': 0, // Add wallet_balance field
      });
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isUserLoggedIn', true);
      prefs.setString('userId', userCredential.user!.uid);
      prefs.setString('userEmail', _emailController.text);
      prefs.setString('userName', _nameController.text);
      prefs.setString('userPhone', widget.phone);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed background to white
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading:
            BackButton(color: Colors.black), // Changed back button to black
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Changed text color to black
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _nameController,
                style: TextStyle(
                    color: Colors.black), // Changed text color to black
                decoration: InputDecoration(
                  hintText: 'Full Name',
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
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                style: TextStyle(color: Colors.black),
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
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
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: Colors.black),
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
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
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.black, // Changed button background to white
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Sign Up',
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

class PasswordVerificationPage extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> userData;

  const PasswordVerificationPage({super.key, required this.phone, required this.userData});

  @override
  _PasswordVerificationPageState createState() =>
      _PasswordVerificationPageState();
}

class _PasswordVerificationPageState extends State<PasswordVerificationPage> {
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter password");
      return;
    }

    try {
      if (_passwordController.text != widget.userData['password']) {
        Fluttertoast.showToast(msg: "Incorrect password");
        return;
      }

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: widget.userData['email'],
        password: _passwordController.text,
      );

      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isUserLoggedIn', true);
      prefs.setString('userId', userCredential.user!.uid);
      prefs.setString('userEmail', widget.userData['email']);
      prefs.setString('userName', widget.userData['name']);
      prefs.setString('userPhone', widget.phone);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Changed background to white
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading:
            BackButton(color: Colors.black), // Changed back button to black
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
                  color: Colors.black, // Changed text color to black
                ),
              ),
              Text(
                'Sign in to continue',
                style: TextStyle(
                  color: Colors.black54, // Changed text color to black
                ),
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
              TextButton(
                onPressed: () {
                  // Implement forgot password functionality
                },
                child: Text(
                  'Forgot password?',
                  style: TextStyle(
                      color: Colors.black), // Changed text color to black
                ),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _verifyPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.black, // Changed button background to white
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Sign In',
                    style: TextStyle(
                        color: Colors.white), // Changed text color to black
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



