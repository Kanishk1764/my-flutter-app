//worker_payment_request_page.dart
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRequestPage extends StatefulWidget {
  final Map<String, dynamic> jobDetails;
  final String jobId;

  const PaymentRequestPage({
    super.key,
    required this.jobDetails,
    required this.jobId,
  });

  @override
  _PaymentRequestPageState createState() => _PaymentRequestPageState();
}

class _PaymentRequestPageState extends State<PaymentRequestPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _submitPaymentRequest() async {
  try {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Validate input
    if (_amountController.text.isEmpty) {
      throw Exception('Please enter an amount');
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      throw Exception('Please enter a valid amount');
    }

    // Get current worker
    final worker = FirebaseAuth.instance.currentUser;
    if (worker == null) {
      throw Exception('Worker not logged in');
    }

    // Get reference to the database
    final databaseRef = FirebaseDatabase.instance.ref();
    final jobRef = databaseRef.child('jobs').child(widget.jobId);

    // Create payment details
    final paymentDetails = {
      'payment': {
        'amount': amount,
        'description': _descriptionController.text.trim(),
        'requestedAt': ServerValue.timestamp,
        'status': 'pending',
        'workerId': worker.uid,
      },
      'status': 'payment_requested',
      'lastUpdated': ServerValue.timestamp,
    };

    // Update job with payment details
    await jobRef.update(paymentDetails);

    final userId = widget.jobDetails['user_id'];
    if (userId == null) {
      throw Exception('User ID is missing from job details');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentRequestSuccessScreen(
            jobId: widget.jobId,
            amount: amount,
            userId: userId,
          ),
        ),
      );
    }
  } catch (e) {
    print('Error in _submitPaymentRequest: $e');
    if (mounted) {
      setState(() {
        _errorMessage = 'Failed to submit payment request: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text(
          'Request Payment',
          style: TextStyle(
            fontFamily: 'SF Pro Display',
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job Details Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section with completed badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5FBF7),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'COMPLETED',
                              style: TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00C853),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 1, thickness: 1, color: Color(0xFFF2F2F2)),
                    // Job details content
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.jobDetails['job'] ?? 'Not specified',
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontFamily: 'SF Pro Display',
                                fontSize: 15,
                                color: Color(0xFF1A1A1A),
                              ),
                              children: [
                                const TextSpan(text: 'Customer: '),
                                TextSpan(
                                  text: widget.jobDetails['userName'] ??
                                      'Not specified',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
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

              const SizedBox(height: 24),
              const Text(
                'Payment Details',
                style: TextStyle(
                  fontFamily: 'SF Pro Display',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),

              // Amount Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          '₹',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            style: const TextStyle(
                              fontFamily: 'SF Pro Display',
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: Color(0xFFBBBBBB),
                                fontWeight: FontWeight.w600,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,2}')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Description Field
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      style: const TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            'e.g., Fixed leak, replaced parts, 2 hours labor',
                        hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      maxLines: 5,
                      minLines: 3,
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPaymentRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3366FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFF3366FF).withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Request Payment',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Customer will be notified immediately',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 13,
                    color: Color(0xFF6B7280),
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

class PaymentRequestSuccessScreen extends StatefulWidget {
  final String jobId;
  final double amount;
  final String userId;

  const PaymentRequestSuccessScreen({
    super.key,
    required this.jobId,
    required this.amount,
    required this.userId,
  });

  @override
  _PaymentRequestSuccessScreenState createState() => _PaymentRequestSuccessScreenState();
}

class _PaymentRequestSuccessScreenState extends State<PaymentRequestSuccessScreen> {
  bool _showedRatingDialog = false;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _videoPath;

 @override
  void initState() {
    super.initState();
    // Show video review dialog after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showVideoReviewDialog();
    });
  }
  void _showVideoReviewDialog() {
    if (!_showedRatingDialog) {
      setState(() {
        _showedRatingDialog = true;
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => VideoReviewDialog(
          onVideoRecorded: (videoPath) async {
            setState(() {
              _videoPath = videoPath;
              _isUploading = true;
            });

            // Upload the video to Supabase
            await _uploadVideoToSupabase(videoPath);

            setState(() {
              _isUploading = false;
            });

            // Show the rating dialog after video upload
            _showRatingDialog();
          },
        ),
      );
    }
  }Future<void> _uploadVideoToSupabase(String videoPath) async {
    final file = File(videoPath);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final bucket = Supabase.instance.client.storage.from('documents');

    try {
      await bucket.upload('user_reviews/$fileName', file);
      print('Video uploaded to Supabase: $fileName');
    } catch (e) {
      print('Error uploading video to Supabase: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload video: $e')),
      );
    }
  }
void _showRatingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserRatingDialog(
        userId: widget.userId,
        onRatingDone: () {
          Navigator.pop(context);
        },
      ),
    );
  }
 @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success animation container
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F9FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3366FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Payment Request Sent',
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You have requested ₹${widget.amount.toStringAsFixed(2)}', // Fixed: Using `widget.amount`
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 16,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "You'll be notified when payment is received",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro Display',
                    fontSize: 15,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/workerhome', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3366FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFF3366FF).withOpacity(0.3),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        fontFamily: 'SF Pro Display',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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


class UserRatingDialog extends StatefulWidget {
  final String userId;
  final VoidCallback onRatingDone;

  const UserRatingDialog({
    super.key,
    required this.userId,
    required this.onRatingDone,
  });

  @override
  _UserRatingDialogState createState() => _UserRatingDialogState();
}

class _UserRatingDialogState extends State<UserRatingDialog> {
  int _selectedRating = 0;
  bool _isLoading = false;

  void _submitRating() async {
    if (_selectedRating == 0) {
      // Ensure the user selects a rating
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get the user rating from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('user_logins')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final int ratingTimes = userData['ratingTimes'] ?? 0;
        final double rating = userData['user_rating']?.toDouble() ?? 5.0; // Default to 5 if no rating exists

        double updatedRating;

        // First rating (if ratingTimes == 0, meaning the first rating)
        if (ratingTimes == 0) {
          updatedRating = (_selectedRating + 5) / 2;
        } else {
          // Subsequent ratings: Use the formula (previousRating * ratingTimes + newRating) / (ratingTimes + 1)
          updatedRating = (rating * ratingTimes + _selectedRating) / (ratingTimes + 1);
        }

        // Update the user's rating and increment ratingTimes
        await FirebaseFirestore.instance
            .collection('user_logins')
            .doc(widget.userId)
            .update({
          'user_rating': updatedRating,
          'ratingTimes': ratingTimes + 1,
        });
      }
    } catch (e) {
      print('Error submitting rating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      widget.onRatingDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate the Customer'),
      backgroundColor: Colors.white,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : _submitRating,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
class VideoReviewDialog extends StatefulWidget {
  final Function(String) onVideoRecorded;

  const VideoReviewDialog({
    super.key,
    required this.onVideoRecorded,
  });

  @override
  _VideoReviewDialogState createState() => _VideoReviewDialogState();
}

class _VideoReviewDialogState extends State<VideoReviewDialog> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      await _initializeControllerFuture;
      setState(() {
        _isRecording = true;
      });

      final videoPath = '${DateTime.now().millisecondsSinceEpoch}.mp4';
      await _cameraController.startVideoRecording();

      // Stop recording after 15 seconds
      await Future.delayed(Duration(seconds: 15));

      final file = await _cameraController.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _videoPath = file.path;
      });

      // Notify the parent widget about the recorded video
      widget.onVideoRecorded(file.path);
    } catch (e) {
      print('Error recording video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to record video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record a 15-Second Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return AspectRatio(
                  aspectRatio: _cameraController.value.aspectRatio,
                  child: CameraPreview(_cameraController),
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            },
          ),
          const SizedBox(height: 16),
          if (_isRecording)
            const Text(
              'Recording... (15 seconds)',
              style: TextStyle(color: Colors.red),
            ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRecording || _isUploading ? null : _startRecording,
          child: const Text('Start Recording'),
        ),
      ],
    );
  }
}