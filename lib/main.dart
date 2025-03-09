import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:handzy/firebase_options.dart';
import 'package:handzy/pages/home_screen.dart';
import 'package:handzy/pages/login_signup_page.dart';
import 'package:handzy/pages/newpage.dart';
import 'package:handzy/pages/user_login_page.dart';
import 'package:handzy/pages/wallet_screen.dart';
import 'package:handzy/pages/workers/random.dart';
import 'package:handzy/pages/workers/worker_homepage.dart';
import 'package:handzy/pages/workers/workers_signup_page.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Add shared_preferences package
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://dsjeyaorfibuvddayxxw.supabase.co/',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRzamV5YW9yZmlidXZkZGF5eHh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA3NDE1NTAsImV4cCI6MjA1NjMxNzU1MH0.4rUMp7h18bE0_Sd4pIxi8lB8f6RQrRdXu-JAmgKvRvw',
  );

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseDatabase.instance.databaseURL =
      'https://handzy-c04d2-default-rtdb.firebaseio.com';

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Handzy',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/', // Set the initial route
      routes: {
        '/': (context) => SplashScreen(),
        '/abc': (context) => HandzyAccountPage(),
        '/abcd': (context) => PhoneInputPage(),
        '/userwallet': (context) => WalletScreen(),
        '/loginSignup': (context) => LoginSignupPage(),
        '/home': (context) => HomePage(),
        '/workerhome': (context) => WorkerHomeScreen(),
        '/workersignup': (context) => WorkerSignupPage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _moveAnimation;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkLoginStatus();
  }

  // Initialize the animations for the splash screen
  void _initializeAnimations() {
    _controller = AnimationController(
      duration:
          const Duration(seconds: 2), // Faster animation duration (2 seconds)
      vsync: this,
    );

    // H grows and moves off the screen (faster speed)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _moveAnimation =
        Tween<Offset>(begin: Offset(0, 0), end: Offset(0, -2)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Fade in Handzy text
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.forward(); // Start the animation
  }

  // Check if the user or worker is logged in and navigate accordingly
  Future<void> _checkLoginStatus() async {
    // Wait for animation to finish
    await Future.delayed(Duration(seconds: 2)); // Match animation duration

    final prefs = await SharedPreferences.getInstance();
    final isUserLoggedIn = prefs.getBool('isUserLoggedIn') ?? false;
    final isWorkerLoggedIn = prefs.getBool('isWorkerLoggedIn') ?? false;

    // Navigate to the appropriate screen after animation
    if (isUserLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (isWorkerLoggedIn) {
      Navigator.pushReplacementNamed(context, '/workerhome');
    } else {
      Navigator.pushReplacementNamed(context, '/loginSignup');
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Black background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animating the 'H' letter to grow and move off the screen
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.translate(
                    offset: _moveAnimation.value,
                    child: _controller.isCompleted
                        ? SizedBox() // Remove 'H' once the animation is complete
                        : Text(
                            'H', // First letter of "Handzy"
                            style: TextStyle(
                              fontSize: 80, // Starting size
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                );
              },
            ),
            SizedBox(height: 50),
            // Handzy text fades in after the "H" animation
            FadeTransition(
              opacity: _fadeInAnimation,
              child: Text(
                'Handzy', // App name
                style: TextStyle(
                  fontSize: 30.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // White text color
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}