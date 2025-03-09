//user_job-payment_page.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentBottomSheet extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobDetails;
  final Map<String, dynamic> workerDetails;
  final Function onPaymentComplete;

  const PaymentBottomSheet({
    super.key,
    required this.jobId,
    required this.jobDetails,
    required this.workerDetails,
    required this.onPaymentComplete,
  });

  @override
  _PaymentBottomSheetState createState() => _PaymentBottomSheetState();
}

class _PaymentBottomSheetState extends State<PaymentBottomSheet> {
  bool _isLoading = true;
  double? _walletBalance;
  late Razorpay _razorpay;
  late StreamSubscription<DatabaseEvent> _jobStatusSubscription;
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'UPI';
  final List<String> _availablePaymentMethods = ['UPI', 'Card', 'Net Banking'];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePaymentAndData();
    _setupJobStatusListener();
  }

  Future<void> _initializePaymentAndData() async {
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing payment: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to initialize payment. Please try again.';
        });
      }
    }
  }

  Future<void> _processPayment() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No user logged in');

      // Create order options for Razorpay
      var options = {
        'key':
            'rzp_test_Tln9ghzQ7Fr4yb', // Replace with your actual Razorpay key
        'amount': (widget.jobDetails['payment']['amount'] * 100)
            .toInt(), // Amount in smallest currency unit (paise)
        'name': 'Handzy Services',
        'description':
            'Payment for ${widget.jobDetails['service'] ?? 'Service'}',
        'prefill': {
          'contact': user.phoneNumber ?? '',
          'name': user.displayName ?? ''
        },
        'external': {
          'wallets': ['paytm']
        }
      };

      // Update job status to processing
      await _updateJobStatus('payment_processing');

      // Open Razorpay payment
      _razorpay.open(options);
    } catch (e) {
      _showError('Failed to process payment: ${e.toString()}');
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      if (response.paymentId == null) {
        throw Exception('Invalid payment response: Missing payment ID');
      }

      // Create transaction records
      await _createTransactionRecords(
        amount: widget.jobDetails['payment']['amount'] is int
            ? (widget.jobDetails['payment']['amount'] as int).toDouble()
            : widget.jobDetails['payment']['amount'],
        paymentMethod: _selectedPaymentMethod,
        orderId: response.orderId ??
            'ORDER_${DateTime.now().millisecondsSinceEpoch}', // Fallback order ID
        paymentId: response.paymentId!,
      );

      // Update job status
      await _updateJobStatus('workdone');
      await Future.delayed(Duration(seconds: 20));
      // Call completion callback
      widget.onPaymentComplete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Error completing payment: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showError('Payment failed: ${response.message ?? 'Unknown error'}');
    setState(() => _isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('External wallet selected: ${response.walletName}')),
    );
  }

  void _setupJobStatusListener() {
    final databaseRef =
        FirebaseDatabase.instance.ref().child('jobs').child(widget.jobId);

    _jobStatusSubscription = databaseRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>);
        final status = data['status'] as String?;

        if (status == 'payment_completed') {
          // Show success message and close bottom sheet
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payment completed successfully!')),
            );
            Navigator.pop(context);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _jobStatusSubscription.cancel();
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _updateJobStatus(String status) async {
    final databaseRef =
        FirebaseDatabase.instance.ref().child('jobs').child(widget.jobId);
    await databaseRef.update({'status': status});
  }

  Future<void> _createTransactionRecords({
    required double amount,
    required String paymentMethod,
    required String orderId,
    required String paymentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    final firestore = FirebaseFirestore.instance;
    final transactionId = orderId;

    // User transaction record
    await firestore
        .collection('user_wallet_transactions')
        .doc(user.uid)
        .collection('transactions')
        .doc(transactionId)
        .set({
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'payment',
      'paymentMethod': paymentMethod,
      'jobId': widget.jobId,
      'service': 'Job Payment',
      'status': 'completed',
      'orderId': orderId,
      'paymentId': paymentId,
      'workerId': widget.workerDetails['uid'],
      'workerName': widget.workerDetails['name'] ?? 'Not specified'
    });

    // Worker transaction record (in escrow)
    await firestore
        .collection('worker_wallet_transactions')
        .doc(widget.workerDetails['uid'])
        .collection('transactions')
        .doc(transactionId)
        .set({
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'earning',
      'paymentMethod': paymentMethod,
      'jobId': widget.jobId,
      'service': 'Job Payment',
      'status': 'in_escrow',
      'orderId': orderId,
      'paymentId': paymentId,
      'userId': user.uid,
      'escrowReleaseDate':
          Timestamp.fromDate(DateTime.now().add(const Duration(days: 2)))
    });
  }

// Show error message
  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _isProcessing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color:Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Worker details card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Provider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(widget.workerDetails['name'] ?? 'Not specified'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount to Pay',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '₹${widget.jobDetails['payment']['amount']}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF3366FF),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Wallet balance (if available)
          if (_walletBalance != null) ...[
            Text(
              'Wallet Balance: ₹${_walletBalance?.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],

          // Payment method selection
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Payment Method',
              border: OutlineInputBorder(),
            ),
            value: _selectedPaymentMethod,
            items: _availablePaymentMethods.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(method),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedPaymentMethod = value ?? '');
            },
          ),
          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          // Pay button
          ElevatedButton(
            onPressed: _isProcessing ? null : _processPayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF3366FF),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Pay ₹${widget.jobDetails['payment']['amount']}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
