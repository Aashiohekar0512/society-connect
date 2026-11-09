import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class SubscriptionPricing {
  final int minFlats;
  final int maxFlats;
  final int monthlyPrice;
  final int yearlyPrice;

  const SubscriptionPricing({
    required this.minFlats,
    required this.maxFlats,
    required this.monthlyPrice,
    required this.yearlyPrice,
  });
}

SubscriptionPricing? getSubscriptionPricing(int flats) {
  if (flats <= 0) return null;

  if (flats <= 30) {
    return const SubscriptionPricing(
      minFlats: 1, maxFlats: 30,
      monthlyPrice: 499, yearlyPrice: 4999,
    );
  }
  if (flats <= 50) {
    return const SubscriptionPricing(
      minFlats: 31, maxFlats: 50,
      monthlyPrice: 699, yearlyPrice: 6999,
    );
  }
  if (flats <= 100) {
    return const SubscriptionPricing(
      minFlats: 51, maxFlats: 100,
      monthlyPrice: 999, yearlyPrice: 9999,
    );
  }
  if (flats <= 150) {
    return const SubscriptionPricing(
      minFlats: 101, maxFlats: 150,
      monthlyPrice: 1499, yearlyPrice: 14999,
    );
  }
  if (flats <= 200) {
    return const SubscriptionPricing(
      minFlats: 151, maxFlats: 200,
      monthlyPrice: 1999, yearlyPrice: 19999,
    );
  }

  final tiers = (flats - 200 + 49) ~/ 50;
  return SubscriptionPricing(
    minFlats: 201 + (tiers - 1) * 50,
    maxFlats: 200 + tiers * 50,
    monthlyPrice: 1999 + tiers * 500,
    yearlyPrice: 19999 + tiers * 5000,
  );
}

class SubscriptionPricingScreen extends StatefulWidget {
  final String societyId;

  const SubscriptionPricingScreen({
    super.key,
    required this.societyId,
  });

  @override
  State<SubscriptionPricingScreen> createState() =>
      _SubscriptionPricingScreenState();
}

class _SubscriptionPricingScreenState
    extends State<SubscriptionPricingScreen> {
  String planType = 'monthly';
  bool loading = false;
  Razorpay? _razorpay;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay!.on(
      Razorpay.EVENT_PAYMENT_SUCCESS,
      _handlePaymentSuccess,
    );
    _razorpay!.on(
      Razorpay.EVENT_PAYMENT_ERROR,
      _handlePaymentError,
    );
    _razorpay!.on(
      Razorpay.EVENT_EXTERNAL_WALLET,
      _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> startPayment() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('createRazorpayOrder');

      final result = await callable.call({
        'societyId': widget.societyId,
        'planType': planType,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final orderId = data['orderId'] as String;
      _currentOrderId = orderId;

      final options = <String, dynamic>{
        'key': data['keyId'],
        'amount': data['amount'],
        'currency': data['currency'],
        'name': 'Society Connect',
        'description': '$planType subscription',
        'order_id': orderId,
        'theme': {'color': '#176B5B'},
      };

      _razorpay?.open(options);
    } on FirebaseFunctionsException catch (e) {
      _showMessage(e.message ?? 'Order तयार झाली नाही.');
    } catch (e) {
      _showMessage('पेमेंट सुरू करता आले नाही. पुन्हा प्रयत्न कर.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _handlePaymentSuccess(
      PaymentSuccessResponse response,
      ) async {
    final paymentId = response.paymentId;
    final signature = response.signature;
    final orderId = response.orderId ?? _currentOrderId;

    if (paymentId == null || signature == null || orderId == null) {
      _showMessage('पेमेंटची माहिती अपूर्ण आहे. Support शी संपर्क करा.');
      return;
    }

    setState(() => loading = true);

    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('verifyRazorpayPayment');

      final result = await callable.call({
        'societyId': widget.societyId,
        'orderId': orderId,
        'paymentId': paymentId,
        'signature': signature,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] == true) {
        _showMessage('पेमेंट Verify झाले. Subscription सक्रिय झाले.');
      } else {
        _showMessage('पेमेंट Verify झाले नाही. Support शी संपर्क करा.');
      }
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        'पेमेंटची पडताळणी पूर्ण झाली नाही: '
            '${e.message ?? 'कृपया Support शी संपर्क करा.'}',
      );
    } catch (_) {
      _showMessage('पेमेंटचा निकाल तपासता आला नाही. पुन्हा तपासा.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showMessage(
      'पेमेंट पूर्ण झाले नाही: '
          '${response.message ?? 'पुन्हा प्रयत्न करा.'}',
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showMessage(
      'External wallet निवडले: '
          '${response.walletName ?? 'Wallet'}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Plans'),
        backgroundColor: const Color(0xFF176B5B),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Choose Your Plan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          RadioListTile<String>(
            title: const Text('Monthly Plan'),
            subtitle: const Text('किंमत फ्लॅटच्या संख्येनुसार ठरेल'),
            value: 'monthly',
            groupValue: planType,
            onChanged: loading
                ? null
                : (value) => setState(() => planType = value!),
          ),
          RadioListTile<String>(
            title: const Text('Yearly Plan'),
            subtitle: const Text('वार्षिक सबस्क्रिप्शन'),
            value: 'yearly',
            groupValue: planType,
            onChanged: loading
                ? null
                : (value) => setState(() => planType = value!),
          ),
          const SizedBox(height: 16),
          const Text(
            '7-day free trial',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : startPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF176B5B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            child: Text(
              loading ? 'Please wait...' : 'Continue to Payment',
            ),
          ),
        ],
      ),
    );
  }
}