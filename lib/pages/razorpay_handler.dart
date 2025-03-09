// Define this as a separate file: razorpay_handler.dart
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayHandler {
  final Function(String paymentId, String orderId) onPaymentSuccess;
  final Function(String errorMessage) onPaymentError;
  late Razorpay _razorpay;

  RazorpayHandler({
    required this.onPaymentSuccess,
    required this.onPaymentError,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    onPaymentSuccess(response.paymentId ?? 'unknown', response.orderId ?? 'unknown');
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onPaymentError(response.message ?? 'Payment failed');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet if needed
  }

  void initiatePayment({
    required int amount,
    required String userName,
    required String userPhone,
    required String userEmail,
  }) {
    var options = {
      'key': 'rzp_test_Tln9ghzQ7Fr4yb',
      'amount': amount, // Amount in paise
      'name': 'Electrician Service',
      'description': 'Booking Fee',
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'external': {
        'wallets': ['paytm']
      },
      'theme': {
        'color': '#0000FF', // Match your app's primary color
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      onPaymentError('Error: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}