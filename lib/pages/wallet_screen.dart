import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Razorpay _razorpay;
  String? userEmail; // Change to nullable String
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Add FirebaseAuth instance
  Stream<double>? _balanceStream;
  List<Map<String, dynamic>> paymentMethods = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRazorpay();
    _fetchUserEmailAndSetup(); // Fetch email and setup streams
  }

  Future<void> _logRazorpayInteraction({
    required String status,
    required String type,
    required Map<String, dynamic> details,
    double? amount, // New parameter
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Get the last serial number
        QuerySnapshot lastTransactionQuery = await _firestore
            .collection('user_wallet_interactions')
            .doc(user.uid)
            .collection('transactions')
            .orderBy('serialNumber', descending: true)
            .limit(1)
            .get();

        int nextSerialNumber = 1; // Start with 1 if no transactions exist
        if (lastTransactionQuery.docs.isNotEmpty) {
          nextSerialNumber = (lastTransactionQuery.docs.first.data()
                  as Map<String, dynamic>)['serialNumber'] +
              1;
        }

        // Generate transaction ID
        String transactionId = DateTime.now().millisecondsSinceEpoch.toString();

        // Ensure order_id is not null
        if (details.containsKey('order_id') && details['order_id'] == null) {
          details['order_id'] = 'order_$transactionId';
        }

        // Log the interaction
        await _firestore
            .collection('user_wallet_interactions')
            .doc(user.uid)
            .collection('transactions')
            .doc(transactionId)
            .set({
          'serialNumber': nextSerialNumber,
          'amount': amount,
          'status': status,
          'type': type,
          'details': details,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error logging Razorpay interaction: $e');
    }
  }

  Future<void> _fetchUserEmailAndSetup() async {
    try {
      // Get current user
      User? user = _auth.currentUser;
      if (user != null) {
        // Fetch user document from Firestore using UID
        DocumentSnapshot userDoc =
            await _firestore.collection('user_logins').doc(user.uid).get();
        if (userDoc.exists) {
          setState(() {
            userEmail = userDoc['email']; // Extract email from Firestore
          });
          _setupBalanceStream(); // Setup balance stream after email is fetched
          _fetchPaymentMethods(); // Fetch payment methods after email is fetched
        }
      }
    } catch (e) {
      print('Error fetching user email: $e');
    }
  }

  void _setupBalanceStream() {
    if (userEmail == null) return; // Ensure email is not null

    _balanceStream = _firestore
        .collection('user_logins')
        .where('email', isEqualTo: userEmail)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();
        return (data['wallet_balance'] ?? 0).toDouble();
      }
      return 0.0;
    });
  }

  Future<void> _fetchPaymentMethods() async {
    if (userEmail == null) return; // Ensure email is not null

    setState(() => isLoading = true);
    try {
      // Get user document
      QuerySnapshot userQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        var userData = userQuery.docs.first.data() as Map<String, dynamic>;
        List<dynamic> methods = userData['payment_methods'] ?? [];

        setState(() {
          paymentMethods =
              List<Map<String, dynamic>>.from(methods.map((method) {
            String id = '';
            if (method['type'] == 'card') {
              id = method['razorpayToken'] ?? DateTime.now().toString();
            } else if (method['type'] == 'upi') {
              id = method['upiId'] ?? DateTime.now().toString();
            }

            return {
              'id': id,
              'type': method['type'],
              'lastFour': method['lastFour'],
              'upiId': method['upiId'],
            };
          }));
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print('Error fetching payment methods: $e');
      setState(() => isLoading = false);
    }
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _deletePaymentMethod(String methodId) async {
    try {
      // Get user document
      QuerySnapshot userQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String userId = userQuery.docs.first.id;
        var userData = userQuery.docs.first.data() as Map<String, dynamic>;
        List<dynamic> methods = userData['payment_methods'] ?? [];

        // Find and remove the payment method
        methods.removeWhere((method) =>
            (method['type'] == 'card' && method['razorpayToken'] == methodId) ||
            (method['type'] == 'upi' && method['upiId'] == methodId));

        // Update user document
        await _firestore
            .collection('user_logins')
            .doc(userId)
            .update({'payment_methods': methods});

        // Refresh the list
        _fetchPaymentMethods();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment method removed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing payment method: $e')),
      );
    }
  }

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddPaymentMethodSheet(
        userEmail: userEmail ?? '',
        onSuccess: () {
          _fetchPaymentMethods();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text("Wallet",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            SizedBox(height: 20),
            _buildQuickActions(),
            Divider(height: 40),
            _buildPaymentMethodsSection(),
            Divider(height: 40),
            _buildPromotionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return StreamBuilder<double>(
      stream: _balanceStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        double currentBalance = snapshot.data ?? 0.0;

        return Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Available Balance",
                  style: TextStyle(color: Colors.white70)),
              SizedBox(height: 8),
              Text("₹${currentBalance.toStringAsFixed(2)}",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _openCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text("Add Money",
                        style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed:
                        _showTransferDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ), // Changed this line to call our new method
                    child: Text(
                      "Send",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Payment Methods",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        if (isLoading)
          Center(child: CircularProgressIndicator())
        else if (paymentMethods.isEmpty)
          Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(Icons.credit_card, color: Colors.grey),
              title: Text("Add card for your next payment"),
              subtitle: Text("No payment methods added yet"),
            ),
          )
        else
          ...paymentMethods.map((method) => _buildPaymentMethodCard(method)),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(Icons.add, color: Colors.grey),
            title: Text("Add Payment Method"),
            onTap: _addPaymentMethod,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    IconData icon;
    String title;

    switch (method['type']) {
      case 'card':
        icon = Icons.credit_card;
        title = "•••• ${method['lastFour'] ?? '****'}";
        break;
      case 'upi':
        icon = Icons.account_balance;
        title = "${method['upiId']}";
        break;
      default:
        icon = Icons.payment;
        title = "Payment Method";
    }

    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline),
          onPressed: () => _deletePaymentMethod(method['id']),
        ),
      ),
    );
  }

  // Add these methods inside the _WalletScreenState class

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // Define the amount being added
      double amountToAdd = 500.0;

      // Log the successful payment interaction with amount
      await _logRazorpayInteraction(
        status: 'success',
        type: 'payment',
        amount: amountToAdd,
        details: {
          'payment_id': response.paymentId,
          'order_id': response.orderId ??
              'order_${DateTime.now().millisecondsSinceEpoch}',
          'signature': response.signature ?? 'signature_not_provided',
        },
      );

      // Get current user data
      QuerySnapshot userQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String userId = userQuery.docs.first.id;

        // Get the current balance
        var userData = userQuery.docs.first.data() as Map<String, dynamic>;
        double currentBalance = 0.0;

        if (userData['wallet_balance'] is int) {
          currentBalance = (userData['wallet_balance'] as int).toDouble();
        } else if (userData['wallet_balance'] is double) {
          currentBalance = userData['wallet_balance'] as double;
        }

        // Calculate new balance
        double newBalance = currentBalance + amountToAdd;

        // Update with explicit double type
        await _firestore
            .collection('user_logins')
            .doc(userId)
            .update({'wallet_balance': newBalance});
      }

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment successful: ${response.paymentId}")));
    } catch (e) {
      print('Payment success error: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error updating balance: $e")));
    }
  }

  Future<void> transferWalletFunds({
    required String recipientEmail,
    required double amount,
    String? description,
  }) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null || userEmail == null) {
        throw Exception('User not authenticated');
      }

      // Transaction ID
      String transactionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Get sender's data
      QuerySnapshot senderQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: userEmail)
          .get();

      if (senderQuery.docs.isEmpty) {
        throw Exception('Sender account not found');
      }

      // Get recipient's data
      QuerySnapshot recipientQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: recipientEmail)
          .get();

      if (recipientQuery.docs.isEmpty) {
        throw Exception('Recipient account not found');
      }

      String senderId = senderQuery.docs.first.id;
      String recipientId = recipientQuery.docs.first.id;

      // Check sender's balance
      var senderData = senderQuery.docs.first.data() as Map<String, dynamic>;
      double senderBalance = 0.0;

      if (senderData['wallet_balance'] is int) {
        senderBalance = (senderData['wallet_balance'] as int).toDouble();
      } else if (senderData['wallet_balance'] is double) {
        senderBalance = senderData['wallet_balance'] as double;
      }

      if (senderBalance < amount) {
        throw Exception('Insufficient balance');
      }

      // Get recipient's balance
      var recipientData =
          recipientQuery.docs.first.data() as Map<String, dynamic>;
      double recipientBalance = 0.0;

      if (recipientData['wallet_balance'] is int) {
        recipientBalance = (recipientData['wallet_balance'] as int).toDouble();
      } else if (recipientData['wallet_balance'] is double) {
        recipientBalance = recipientData['wallet_balance'] as double;
      }

      // Use a batch to ensure both operations succeed or fail together
      WriteBatch batch = _firestore.batch();

      // Update sender's balance
      batch.update(_firestore.collection('user_logins').doc(senderId),
          {'wallet_balance': senderBalance - amount});

      // Update recipient's balance
      batch.update(_firestore.collection('user_logins').doc(recipientId),
          {'wallet_balance': recipientBalance + amount});

      // Commit the batch
      await batch.commit();

      // Log transaction for sender (outgoing)
      await _logRazorpayInteraction(
        status: 'success',
        type: 'wallet_transfer_out',
        amount: amount,
        details: {
          'order_id': 'transfer_$transactionId',
          'payment_id': 'transfer_${transactionId}_out',
          'recipient_email': recipientEmail,
          'description': description ?? 'Wallet transfer',
        },
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Transfer successful!")));
      return;
    } catch (e) {
      print('Transfer error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Transfer failed: ${e.toString()}")));
      rethrow;
    }
  }

// Add this method to show a transfer dialog
  void _showTransferDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Send Money'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Recipient Email',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                double? amount = double.tryParse(amountController.text);
                if (amount != null && emailController.text.isNotEmpty) {
                  transferWalletFunds(
                    recipientEmail: emailController.text,
                    amount: amount,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invalid input')),
                  );
                }
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) async {
    // Log the failed payment interaction
    await _logRazorpayInteraction(
      status: 'error',
      type: 'payment',
      details: {
        'code': response.code,
        'message': response.message,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: ${response.message}")));
  }

  void _handleExternalWallet(ExternalWalletResponse response) async {
    // Log the external wallet interaction
    await _logRazorpayInteraction(
      status: 'external_wallet',
      type: 'payment',
      details: {
        'wallet_name': response.walletName,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("External wallet selected: ${response.walletName}")));
  }

  void _openCheckout() {
    var options = {
      'key': 'rzp_test_Tln9ghzQ7Fr4yb',
      'amount': 50000, // Amount in paise
      'name': 'Service Booking App',
      'description': 'Add Money to Wallet',
      'prefill': {'contact': '1234567890', 'email': userEmail},
      'external': {
        'wallets': ['paytm']
      }
    };
    _razorpay.open(options);
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(children: [
          Icon(Icons.credit_card, color: Colors.blue),
          Text("Cards")
        ]),
        Column(children: [
          Icon(Icons.card_giftcard, color: Colors.orange),
          Text("Rewards")
        ]),
        Column(children: [
          Icon(Icons.qr_code_scanner, color: Colors.green),
          Text("Scan Pay")
        ]),
        Column(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserTransactionHistoryScreen(),
                  ),
                );
              },
              child: Column(
                children: [
                  Icon(Icons.history, color: Colors.purple),
                  Text("History")
                ],
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPromotionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Promotions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(Icons.local_offer, color: Colors.blue),
            title: Text("Enter Promo Code"),
            onTap: () {
              // Handle promo code tap
            },
          ),
        ),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(Icons.people, color: Colors.green),
            title: Text("Invite Friends"),
            subtitle: Text("Share and earn rewards"),
            onTap: () {
              // Handle invite friends tap
            },
          ),
        ),
      ],
    );
  }
}

class AddPaymentMethodSheet extends StatefulWidget {
  final String userEmail;
  final VoidCallback onSuccess;

  const AddPaymentMethodSheet({super.key, 
    required this.userEmail,
    required this.onSuccess,
  });

  @override
  _AddPaymentMethodSheetState createState() => _AddPaymentMethodSheetState();
}

// ... (previous code remains the same until AddPaymentMethodSheet class)
class UserTransactionHistoryScreen extends StatefulWidget {
  const UserTransactionHistoryScreen({super.key});

  @override
  _UserTransactionHistoryScreenState createState() =>
      _UserTransactionHistoryScreenState();
}

class _UserTransactionHistoryScreenState
    extends State<UserTransactionHistoryScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> transactions = [];

  @override
  void initState() {
    super.initState();
    fetchTransactions();
  }

  Future<void> fetchTransactions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('user_wallet_transactions')
          .doc(user.uid)
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
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching transactions: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: Container(
        color: Colors
            .white, // This will set the background color of the body to white
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : transactions.isEmpty
                ? Center(
                    child: Text(
                      'No recent transactions',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
  padding: const EdgeInsets.all(16),
  itemCount: transactions.length,
  itemBuilder: (context, index) {
    final transaction = transactions[index];
    final timestamp = transaction['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch,
          )
        : DateTime.now();
    final isPayment = transaction['type'] == 'payment';
    final amount = transaction['amount'] as num?;
    final service = transaction['service'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          isPayment ? Icons.payment : Icons.credit_card,
          color: const Color.fromARGB(255, 0, 0, 0),
        ),
        title: Text(service ?? 'Service'),
        subtitle: Text(_formatDate(date)),
        trailing: Text(
          '${isPayment ? '-' : '+'}₹${amount?.toString() ?? '0'}',
          style: TextStyle(
            color: isPayment ? Colors.red : Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        onTap: () {
          // Handle tap if needed
        },
      ),
    );
  },
),
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
}

class _AddPaymentMethodSheetState extends State<AddPaymentMethodSheet> {
  String _selectedType = 'card';
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();
  bool _isLoading = false;
  late Razorpay _razorpay;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors
            .white, // Set the background color to white for the entire screen
        child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Container(
              color: Colors.white, // Set the background color to white
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Add Payment Method',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'card',
                        label: Text('Card'),
                        icon: Icon(
                          Icons.credit_card,
                          color: Colors.black,
                        ),
                      ),
                      ButtonSegment(
                        value: 'upi',
                        label: Text('UPI'),
                        icon: Icon(Icons.account_balance, color: Colors.black),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() {
                        _selectedType = selected.first;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: _selectedType == 'card'
                        ? _buildCardForm()
                        : _buildUPIForm(),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Add Payment Method',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ],
              ),
            )));
  }

  Widget _buildCardForm() {
    return Column(
      children: [
        TextFormField(
          controller: _cardNumberController,
          decoration: InputDecoration(
            labelText: 'Card Number',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter card number';
            }
            return null;
          },
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                decoration: InputDecoration(
                  labelText: 'MM/YY',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                decoration: InputDecoration(
                  labelText: 'CVV',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Cardholder Name',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter cardholder name';
            }
            return null;
          },
        ),
      ],
    );
  }

  void _saveCardDirectly() {
    try {
      // Parse expiry date properly
      String expiry = _expiryController.text.trim();
      List<String> expiryParts;

      if (expiry.contains('/')) {
        expiryParts = expiry.split('/');
      } else if (expiry.length == 4) {
        // If user entered expiry as "1028"
        expiryParts = [expiry.substring(0, 2), expiry.substring(2, 4)];
      } else {
        throw Exception('Invalid expiry date format');
      }

      String expiryMonth = expiryParts[0].padLeft(2, '0');
      String expiryYear =
          expiryParts[1].length == 2 ? '20${expiryParts[1]}' : expiryParts[1];

      // Create Razorpay options for card tokenization
      var options = {
        'key': 'rzp_test_Tln9ghzQ7Fr4yb',
        'amount': 100, // Minimum amount for tokenization (will be refunded)
        'name': 'Card Verification',
        'description': 'Save card for future payments',
        'prefill': {'email': widget.userEmail},
        'method': {
          'netbanking': false,
          'card': true,
          'upi': false,
          'wallet': false,
        },
        'card[number]': _cardNumberController.text.replaceAll(' ', ''),
        'card[expiry_month]': expiryMonth,
        'card[expiry_year]': expiryYear,
        'card[cvv]': _cvvController.text,
        'card[name]': _nameController.text,
        'save': true,
      };

      _razorpay.open(options);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error with card details: $e')),
      );
    }
  }

  Widget _buildUPIForm() {
    return TextFormField(
      controller: _upiController,
      decoration: InputDecoration(
        labelText: 'UPI ID',
        border: OutlineInputBorder(),
        hintText: 'example@upi',
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter UPI ID';
        }
        if (!value.contains('@')) {
          return 'Please enter a valid UPI ID';
        }
        return null;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleTokenSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleTokenError);
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleCardSaveSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleCardSaveError);
  }

  Future<void> _logRazorpayInteraction({
    required String status,
    required String type,
    required Map<String, dynamic> details,
  }) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String transactionId = DateTime.now().millisecondsSinceEpoch.toString();
        await FirebaseFirestore.instance
            .collection('user_wallet_interactions')
            .doc(user.uid)
            .collection('transactions')
            .doc(transactionId)
            .set({
          'status': status,
          'type': type,
          'details': details,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error logging Razorpay interaction: $e');
    }
  }

  void _handleCardSaveSuccess(PaymentSuccessResponse response) async {
    try {
      // Log the successful card save interaction
      await _logRazorpayInteraction(
        status: 'success',
        type: 'card_save',
        details: {
          'payment_id': response.paymentId,
          'card_last_four': _cardNumberController.text
              .substring(_cardNumberController.text.length - 4),
        },
      );

      // Extract last four digits safely with null checks
      String cardNumber = _cardNumberController.text;
      String lastFour = cardNumber.length >= 4
          ? cardNumber.substring(cardNumber.length - 4)
          : 'XXXX';

      // First get the user document
      QuerySnapshot userQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String userId = userQuery.docs.first.id;

        // Get current payment methods or create empty array
        var userData = userQuery.docs.first.data() as Map<String, dynamic>;
        List<dynamic> paymentMethods =
            (userData['payment_methods'] ?? []).cast<dynamic>();

        // Add new payment method
        paymentMethods.add({
          'type': 'card',
          'lastFour': lastFour,
          'cardholderName': _nameController.text,
          'razorpayToken': response.paymentId,
          'addedAt': DateTime.now().toString(),
        });

        // Update user document with payment methods
        await _firestore
            .collection('user_logins')
            .doc(userId)
            .update({'payment_methods': paymentMethods});

        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Card added successfully')),
        );
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving card details: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUPIDirectly() async {
    try {
      // First get the user document
      QuerySnapshot userQuery = await _firestore
          .collection('user_logins')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userQuery.docs.isNotEmpty) {
        String userId = userQuery.docs.first.id;

        // Get current payment methods or create empty array
        var userData = userQuery.docs.first.data() as Map<String, dynamic>;
        List<dynamic> paymentMethods =
            (userData['payment_methods'] ?? []).cast<dynamic>();

        // Add new payment method - using string timestamp
        paymentMethods.add({
          'type': 'upi',
          'upiId': _upiController.text,
          'addedAt': DateTime.now().toString(), // Use string timestamp instead
        });

        // Update user document with payment methods
        await _firestore
            .collection('user_logins')
            .doc(userId)
            .update({'payment_methods': paymentMethods});

        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UPI ID added successfully')),
        );
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving UPI ID: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handleCardSaveError(PaymentFailureResponse response) async {
    // Log the failed card save interaction
    await _logRazorpayInteraction(
      status: 'error',
      type: 'card_save',
      details: {
        'code': response.code,
        'message': response.message,
      },
    );

    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to save card: ${response.message}')),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedType == 'card') {
        _saveCardDirectly();
      } else {
        _saveUPIDirectly();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _handleTokenSuccess(PaymentSuccessResponse response) async {
    // Log the successful tokenization interaction
    await _logRazorpayInteraction(
      status: 'success',
      type: 'tokenization',
      details: {
        'token_id': response.paymentId,
      },
    );

    // Store the token ID in your database
    _storeCardToken(response.paymentId!);
  }

  void _handleTokenError(PaymentFailureResponse response) async {
    // Log the failed tokenization interaction
    await _logRazorpayInteraction(
      status: 'error',
      type: 'tokenization',
      details: {
        'code': response.code,
        'message': response.message,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Card tokenization failed: ${response.message}")),
    );
  }

  Future<void> _storeCardToken(String tokenId) async {
    await _firestore.collection('user_payment_methods').add({
      'userEmail': widget.userEmail,
      'type': 'card',
      'lastFour': _cardNumberController.text
          .substring(_cardNumberController.text.length - 4),
      'tokenId': tokenId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _upiController.dispose();
    super.dispose();
  }
}
