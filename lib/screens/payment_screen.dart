// lib/screens/payment_screen.dart - USERNAME DISPLAY FIX WITH TYPE FIXES
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tickiting/models/booking.dart';
import 'package:tickiting/models/bus.dart';
import 'package:tickiting/models/user.dart';
import 'package:tickiting/screens/ticket_screen.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart';
import 'package:tickiting/services/notification_service.dart';
import 'dart:math';
import 'package:tickiting/services/auth_service.dart';

class PaymentScreen extends StatefulWidget {
  final Bus bus;
  final String from;
  final String to;
  final DateTime date;
  final int passengers;

  const PaymentScreen({
    super.key,
    required this.bus,
    required this.from,
    required this.to,
    required this.date,
    required this.passengers,
  });

  @override
  PaymentScreenState createState() => PaymentScreenState();
}

class PaymentScreenState extends State<PaymentScreen> {
  String _paymentMethod = 'MTN Mobile Money';
  final _phoneController = TextEditingController();
  bool _isProcessing = false;
  bool _loadingUser = true;
  User? _currentUser;

  // Services
  final _databaseHelper = DatabaseHelper();
  final _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    // Fix for the username display issue
    _getRealUserDirectly();
  }

  // Direct database lookup approach to get the real username
  Future<void> _getRealUserDirectly() async {
    debugPrint('🔍 Starting user lookup');

    try {
      // Use AuthService to get the current user
      final authService = AuthService();
      final user = await authService.getCurrentUser();

      if (user != null) {
        debugPrint('✅ Found authenticated user: ${user.name} (ID: ${user.id})');
        setState(() {
          _currentUser = user;
          _loadingUser = false;
        });
        return;
      }

      setState(() {
        _currentUser = null;
        _loadingUser = false;
      });

    } catch (e) {
      debugPrint('❌ Error in user lookup: $e');
      setState(() {
        _loadingUser = false;
      });
    }
  }

  // Generate random seat numbers
  List<String> _generateSeatNumbers(int count) {
    final seats = <String>[];
    final random = Random();
    final letters = ['A', 'B', 'C', 'D'];

    for (int i = 0; i < count; i++) {
      final letter = letters[random.nextInt(letters.length)];
      final number = random.nextInt(10) + 1;
      seats.add('$letter$number');
    }

    return seats;
  }

  // Generate booking ID
  String _generateBookingId() {
    final random = Random();
    return 'BKG${DateTime.now().millisecondsSinceEpoch}${random.nextInt(1000)}';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _processPayment() async {
    // Check if phone number is entered
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Force get current user if not already set
    if (_currentUser == null) {
      await _getRealUserDirectly();

      // If STILL null after lookup, create a temporary user
      if (_currentUser == null) {
        debugPrint('⚠️ Creating temporary user for payment');

        _currentUser = User(
          id: 999999,
          name: "Guest User",
          email: "guest@example.com",
          password: "guestpass",
          phone: _phoneController.text,
          gender: "Unknown",
        );
      }
    }

    setState(() {
      _isProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    // Show payment confirmation dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirm Payment'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are about to pay ${widget.bus.price * widget.passengers} RWF to Rwanda Bus Services using $_paymentMethod.',
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'A prompt will be sent to your phone. Please enter your PIN to authorize payment.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _isProcessing = false;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _completePayment();
                  },
                  child: const Text('Approve'),
                ),
              ],
            ),
      );
    }
  }

  void _completePayment() async {
    try {
      // Force refresh current user
      await _getRealUserDirectly();
      
      // Check if we have a valid non-admin user
      if (_currentUser == null || await _databaseHelper.isDefaultAdmin(_currentUser!.id!)) {
        throw Exception('Invalid user session. Please log in again.');
      }

      debugPrint('✅ Creating booking for user: ${_currentUser!.name} (ID: ${_currentUser!.id})');

      final bookingId = _generateBookingId();
      final seatNumbers = _generateSeatNumbers(widget.passengers);
      final totalAmount = widget.bus.price * widget.passengers;

      // Create booking record with current user's ID
      final booking = Booking(
        id: bookingId,
        userId: _currentUser!.id!,
        busId: widget.bus.id,
        fromLocation: widget.from,
        toLocation: widget.to,
        travelDate: '${widget.date.day}/${widget.date.month}/${widget.date.year}',
        passengers: widget.passengers,
        seatNumbers: seatNumbers.join(','),
        totalAmount: totalAmount,
        paymentMethod: _paymentMethod,
        paymentStatus: 'Pending',
        bookingStatus: 'Pending',
        notificationSent: false,
        createdAt: DateTime.now().toIso8601String(),
      );

      // Save booking to database
      await _databaseHelper.insertBooking(booking);

      // Create notification with real user info
      await _notificationService.createBookingNotificationForAdmin(
        userId: _currentUser!.id!.toString(),
        userName: _currentUser!.name,
        origin: widget.from,
        destination: widget.to,
      );

      // Update bus available seats
      final updatedBus = Bus(
        id: widget.bus.id,
        name: widget.bus.name,
        departureTime: widget.bus.departureTime,
        arrivalTime: widget.bus.arrivalTime,
        duration: widget.bus.duration,
        price: widget.bus.price,
        availableSeats: widget.bus.availableSeats - widget.passengers,
        busType: widget.bus.busType,
        features: widget.bus.features,
        fromLocation: widget.bus.fromLocation,
        toLocation: widget.bus.toLocation,
      );

      await _databaseHelper.updateBus(updatedBus);

      // Update state
      setState(() {
        _isProcessing = false;
      });

      // Navigate to ticket screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (context) => TicketScreen(
                  isNewTicket: true,
                  bus: updatedBus,
                  from: widget.from,
                  to: widget.to,
                  date: widget.date,
                  passengers: widget.passengers,
                  seatNumbers: seatNumbers,
                  bookingId: bookingId,
                ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error completing payment: $e');

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = widget.bus.price * widget.passengers;

    // Show loading indicator while loading user
    if (_loadingUser) {
      // Force complete loading after 1 second if it takes too long
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _loadingUser) {
          setState(() {
            _loadingUser = false;
          });
        }
      });

      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh login',
            onPressed: () {
              setState(() {
                _loadingUser = true;
              });
              _getRealUserDirectly();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing user information...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info section
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Logged in as: ${_currentUser?.name ?? "Current User"}',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Payment info alert
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your ticket will be pending until payment is confirmed by an administrator. You will be notified once your ticket is confirmed.',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            // Trip summary
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Trip Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildSummaryRow('Bus', widget.bus.name),
                  _buildSummaryRow('Route', '${widget.from} to ${widget.to}'),
                  _buildSummaryRow(
                    'Date',
                    '${widget.date.day}/${widget.date.month}/${widget.date.year}',
                  ),
                  _buildSummaryRow('Time', widget.bus.departureTime),
                  _buildSummaryRow('Passengers', '${widget.passengers}'),
                  _buildSummaryRow(
                    'Price per ticket',
                    '${widget.bus.price} RWF',
                  ),
                  const Divider(),
                  _buildSummaryRow(
                    'Total Amount',
                    '$totalAmount RWF',
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Payment method
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.yellow,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Center(
                            child: Text(
                              'MTN',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('MTN Mobile Money'),
                      ],
                    ),
                    value: 'MTN Mobile Money',
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _paymentMethod = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Center(
                            child: Text(
                              'AIRTEL',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Airtel Money'),
                      ],
                    ),
                    value: 'Airtel Money',
                    groupValue: _paymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _paymentMethod = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Phone number
            const Text(
              'Phone Number',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: 'Enter your phone number',
                prefixIcon: Icon(Icons.phone),
                prefixText: '+250 ',
              ),
            ),
            const SizedBox(height: 40),
            // Pay button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  disabledBackgroundColor: Colors.grey,
                ),
                child:
                    _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          'Pay $totalAmount RWF',
                          style: const TextStyle(fontSize: 18),
                        ),
              ),
            ),
            const SizedBox(height: 20),
            // Security note
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Colors.grey),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Your payment information is secure. We use industry standard encryption to protect your data.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 16,
              color: isBold ? AppTheme.primaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
