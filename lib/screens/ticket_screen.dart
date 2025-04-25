// lib/screens/ticket_screen.dart - User Information Fix
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tickiting/models/bus.dart';
import 'package:tickiting/models/ticket.dart' as ModelsTicket;
import 'package:tickiting/models/booking.dart';
import 'package:tickiting/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tickiting/services/notification_service.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart';
import 'package:tickiting/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tickiting/screens/home_screen.dart';
import 'package:tickiting/models/notification_model.dart';

class TicketScreen extends StatefulWidget {
  final bool isNewTicket;
  final Bus? bus;
  final String? from;
  final String? to;
  final DateTime? date;
  final int? passengers;
  final List<String>? seatNumbers;
  final String? bookingId;

  const TicketScreen({
    super.key,
    this.isNewTicket = false,
    this.bus,
    this.from,
    this.to,
    this.date,
    this.passengers,
    this.seatNumbers,
    this.bookingId,
  });

  @override
  _TicketScreenState createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  User? _currentUser;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  // Removed unused AuthService instance
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();

  @override
  void initState() {
    super.initState();
    _directUserLookup(); // Use the direct approach for more reliable auth

    // Set up periodic refresh timer to check for ticket status updates
  }

  @override
  void dispose() {
    _notificationController.close();
    super.dispose();
    super.dispose();
  }

  // Enhanced user lookup to ensure correct user information
  Future<void> _directUserLookup() async {
    try {
      debugPrint('🔍 Starting direct user lookup in TicketScreen');

      // Get the active user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId != null && userId.isNotEmpty) {
        debugPrint('🔍 Found userId in SharedPreferences: $userId');

        // Direct database query for the user
        final db = await _databaseHelper.database;
        final List<Map<String, dynamic>> maps = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [int.parse(userId)],
        );

        if (maps.isNotEmpty) {
          final userData = maps.first;
          final user = User(
            id: userData['id'] as int,
            name: userData['name']?.toString() ?? 'Unknown User',
            email: userData['email']?.toString() ?? '',
            password: userData['password']?.toString() ?? '',
            phone: userData['phone']?.toString() ?? '',
            gender: userData['gender']?.toString() ?? '',
          );

          debugPrint(
            '✅ User for ticket display: ${user.name} (ID: ${user.id})',
          );

          setState(() {
            _currentUser = user;
          });

          // Load bookings after setting the user
          _loadBookings();
          return;
        } else {
          debugPrint('❌ No user found in the database for userId: $userId');
        }
      } else {
        debugPrint('❌ No userId found in SharedPreferences');
      }
    } catch (e) {
      debugPrint('❌ Error in direct user lookup: $e');
    }

    // Fallback if user lookup fails
    setState(() {
      _currentUser = User(
        id: 0,
        name: 'Guest',
        email: '',
        password: '',
        phone: '',
        gender: '',
      );
    });
  }

  /* Future<String> _getActualUserNameWithCache(int userId) async {
    try {
      final db = await _databaseHelper.database;
      final user = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (user.isNotEmpty) {
        return user.first['name']?.toString() ?? 'Unknown User';
      }
    } catch (e) {
      debugPrint('Error fetching user name from cache: $e');
    }
    return 'Unknown User';
  }
*/
  Future<NotificationModel> createNotification({
    required String title,
    required String message,
    required String type,
    required String recipient,
    int? userId,
  }) async {
    // Fetch the real user name if userId is provided
    if (userId != null) {
      try {
        final user = await _databaseHelper.getUserById(userId);
        if (user != null && user.name.isNotEmpty) {
          message = message.replaceAll('Customer', user.name);
          message = message.replaceAll('Admin User', user.name);
          message = message.replaceAll('mucyo', user.name);
          debugPrint('Updated notification message with real user name: $message');
        }
      } catch (e) {
        debugPrint('Error fetching user name for notification: $e');
      }
    }

    // Insert notification into the database
    final db = await _databaseHelper.database;
    final notificationData = {
      'title': title,
      'message': message,
      'time': DateTime.now().toIso8601String(),
      'isRead': 0,
      'type': type,
      'recipient': recipient,
      'userId': userId,
    };

    final id = await db.insert('notifications', notificationData);
    debugPrint('Created notification #$id: "$message"');

    final notification = NotificationModel(
      id: id,
      title: title,
      message: message,
      time: DateTime.now(),
      isRead: false,
      type: type,
      recipient: recipient,
      userId: userId,
    );

    _notificationController.add(notification);
    return notification;
  }

  Future<void> bookTicket(Ticket ticket) async {
    try {
      await _databaseHelper.createBooking(
        ModelsTicket.Ticket(
          id: ticket.id,
          busName: ticket.busName,
          from: ticket.from,
          to: ticket.to,
          date: ticket.date,
          departureTime: ticket.departureTime,
          passengers: ticket.passengers,
          seatNumbers: ticket.seatNumbers,
          status: ticket.status,
          qrCode: ticket.qrCode,
          userName: ticket.userName,
          userEmail: ticket.userEmail,
          userPhone: ticket.userPhone,
          userId: _currentUser?.id ?? 0, // Add userId argument
        ),
      );

      // Create a notification for the admin
      await createNotification(
        title: 'New Booking',
        message:
            '${_currentUser?.name ?? "Unknown User"} booked a ticket from ${ticket.from} to ${ticket.to}',
        type: 'booking',
        recipient: 'admin',
        userId: _currentUser?.id,
      );

      debugPrint('✅ Ticket booked successfully: ${ticket.id}');
    } catch (e) {
      debugPrint('❌ Error booking ticket: $e');
    }
  }

  Future<void> _loadBookings() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
        _bookings = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint(
        '🔍 Loading bookings for user: ${_currentUser!.name} (ID: ${_currentUser!.id})',
      );

      // Load all bookings for the current user using their actual ID
      final bookings = await _databaseHelper.getUserBookings(_currentUser!.id!);

      // Get bus details for each booking
      List<Booking> enrichedBookings = [];
      for (var booking in bookings) {
        // Try to get the actual bus name
        final bus = await _databaseHelper.getBus(booking.busId);
        if (bus != null) {
          // Create a new booking with the bus name
          enrichedBookings.add(booking);
        } else {
          enrichedBookings.add(booking);
        }
      }

      setState(() {
        _bookings = enrichedBookings;
        _isLoading = false;
      });

      debugPrint(
        '✅ Loaded ${_bookings.length} bookings for user ${_currentUser!.name}',
      );
    } catch (e) {
      debugPrint('❌ Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareTicket(Ticket ticket) {
    try {
      // Create ticket text
      String ticketDetails =
          "Rwanda Bus Ticket\n\n"
          "Ticket ID: ${ticket.id}\n"
          "Bus: ${ticket.busName}\n"
          "Route: ${ticket.from} to ${ticket.to}\n"
          "Date: ${ticket.date.day}/${ticket.date.month}/${ticket.date.year}\n"
          "Time: ${ticket.departureTime}\n"
          "Seats: ${ticket.seatNumbers.join(', ')}\n"
          "Passengers: ${ticket.passengers}\n\n"
          "Please present this ticket at the bus station.";

      // Show a dialog with copy option
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Share Ticket'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your ticket details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(ticketDetails),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Close the dialog
                    Navigator.pop(dialogContext);

                    // Copy to clipboard
                    await Clipboard.setData(ClipboardData(text: ticketDetails));

                    // Show confirmation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ticket copied to clipboard'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );

                    // Force navigation directly to HomeScreen
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                      (route) => false, // This removes all previous routes
                    );
                  },
                  child: const Text('Copy & Return Home'),
                ),
              ],
            ),
      );
    } catch (e) {
      debugPrint("❌ Error in share dialog: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isNewTicket &&
        widget.bus != null &&
        widget.from != null &&
        widget.to != null &&
        widget.date != null &&
        widget.passengers != null &&
        widget.seatNumbers != null &&
        widget.bookingId != null) {
      // Use the current logged-in user's name
      String realUserName = _currentUser?.name ?? "Unknown User";

      final ticket = Ticket(
        id: widget.bookingId!,
        busName: widget.bus!.name,
        from: widget.from!,
        to: widget.to!,
        date: widget.date!,
        departureTime: widget.bus!.departureTime,
        passengers: widget.passengers!,
        seatNumbers: widget.seatNumbers!,
        status: 'Pending',
        qrCode: widget.bookingId!,
        userName: realUserName,
        userEmail: _currentUser?.email ?? "guest@example.com",
        userPhone: _currentUser?.phone ?? "+250 000 000 000",
      );

      return _buildTicketDetailsScreen(context, ticket);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tickets'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _directUserLookup();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing tickets...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Refresh Tickets',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentUser == null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Please log in to view your tickets',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _directUserLookup();
                      },
                      child: const Text('Refresh Login Status'),
                    ),
                  ],
                ),
              )
              : _bookings.isEmpty
              ? const Center(
                child: Text(
                  'No tickets found. Book a trip to get started!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadBookings,
                child: ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    return FutureBuilder<Ticket>(
                      future: _convertBookingToTicket(booking),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        } else if (snapshot.hasError) {
                          return const Center(
                            child: Text('Error loading ticket'),
                          );
                        } else if (snapshot.hasData) {
                          return _buildTicketCard(context, snapshot.data!);
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                    );
                  },
                ),
              ),
    );
  }

  Future<Ticket> _convertBookingToTicket(Booking booking) async {
    final dateParts = booking.travelDate.split('/');
    final date = DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[1]),
      int.parse(dateParts[0]),
    );

    String busName = booking.busId;
    String departureTime = "Check schedule";

    try {
      final bus = await _databaseHelper.getBus(booking.busId);
      if (bus != null) {
        busName = bus.name;
        departureTime = bus.departureTime;
      }
    } catch (e) {
      debugPrint('Error fetching bus details: $e');
    }

    String userName = "Unknown User";
    String userEmail = "";
    String userPhone = "";

    try {
      final user = await _databaseHelper.getUserById(booking.userId);
      if (user != null) {
        userName = user.name;
        userEmail = user.email;
        userPhone = user.phone;
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
    }

    return Ticket(
      id: booking.id,
      busName: busName,
      from: booking.fromLocation,
      to: booking.toLocation,
      date: date,
      departureTime: departureTime,
      passengers: booking.passengers,
      seatNumbers: booking.seatNumbers.split(','),
      status: booking.bookingStatus,
      qrCode: booking.id,
      userName: userName,
      userEmail: userEmail,
      userPhone: userPhone,
    );
  }

  Widget _buildTicketCard(BuildContext context, Ticket ticket) {
    final bool isUpcoming =
        ticket.date.isAfter(DateTime.now()) ||
        (ticket.date.day == DateTime.now().day &&
            ticket.date.month == DateTime.now().month &&
            ticket.date.year == DateTime.now().year);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _buildTicketDetailsScreen(context, ticket),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              decoration: BoxDecoration(
                color: isUpcoming ? AppTheme.primaryColor : Colors.grey,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    isUpcoming ? 'Upcoming Trip' : 'Past Trip',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(ticket.status),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      ticket.status,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            // Ticket content
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  // Bus info and date
                  Row(
                    children: [
                      const Icon(
                        Icons.directions_bus,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.busName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${ticket.date.day}/${ticket.date.month}/${ticket.date.year} • ${ticket.departureTime}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Route
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ticket.from,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'From',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ticket.to,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'To',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Passengers and seat info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${ticket.passengers} ${ticket.passengers > 1 ? 'Passengers' : 'Passenger'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'Seats: ${ticket.seatNumbers.join(', ')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey[600]!;
    }
  }

  Widget _buildTicketDetailsScreen(BuildContext context, Ticket ticket) {
    final bool isUpcoming =
        ticket.date.isAfter(DateTime.now()) ||
        (ticket.date.day == DateTime.now().day &&
            ticket.date.month == DateTime.now().month &&
            ticket.date.year == DateTime.now().year);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket Details'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // User info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ticket for: ${ticket.userName}',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Ticket status
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _getStatusColor(ticket.status),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ticket.status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Ticket card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Company logo and name
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            Icons.directions_bus,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Rwanda Bus Services',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Ticket details
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        _buildDetailRow('Bus', ticket.busName),
                        const Divider(),
                        _buildDetailRow('From', ticket.from),
                        _buildDetailRow('To', ticket.to),
                        const Divider(),
                        _buildDetailRow(
                          'Date',
                          '${ticket.date.day}/${ticket.date.month}/${ticket.date.year}',
                        ),
                        _buildDetailRow('Departure Time', ticket.departureTime),
                        const Divider(),
                        _buildDetailRow('Passengers', '${ticket.passengers}'),
                        _buildDetailRow('Seats', ticket.seatNumbers.join(', ')),
                        const Divider(),
                        _buildDetailRow('Ticket ID', ticket.id),
                        _buildDetailRow('Status', ticket.status),
                      ],
                    ),
                  ),
                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Scan this QR code at the bus station',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(10),
                          child: QrImageView(
                            data: ticket.id, // Use ticket ID as QR code data
                            version: QrVersions.auto,
                            size: 150,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Additional options
            if (isUpcoming) ...[
              // Share ticket button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    _shareTicket(ticket);
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share Ticket'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // Cancel ticket button - only show for non-cancelled tickets
              if (ticket.status != 'Cancelled')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Cancel Ticket'),
                              content: const Text(
                                'Are you sure you want to cancel this ticket? Cancellation fees may apply.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('No'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(context);

                                    // Actually cancel the ticket in the database
                                    try {
                                      await _databaseHelper.updateBookingStatus(
                                        ticket.id,
                                        'Cancelled',
                                      );

                                      // Reload bookings to show updated status
                                      _loadBookings();

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Ticket cancelled successfully',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );

                                      // Go back to tickets list
                                      Navigator.pop(context);
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error cancelling ticket: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Yes, Cancel'),
                                ),
                              ],
                            ),
                      );
                    },
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text(
                      'Cancel Ticket',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// Updated Ticket UI model with additional user information fields
class Ticket {
  final String id;
  final String busName;
  final String from;
  final String to;
  final DateTime date;
  final String departureTime;
  final int passengers;
  final List<String> seatNumbers;
  final String status;
  final String qrCode;
  final String userName;
  final String userEmail;
  final String userPhone;

  Ticket({
    required this.id,
    required this.busName,
    required this.from,
    required this.to,
    required this.date,
    required this.departureTime,
    required this.passengers,
    required this.seatNumbers,
    required this.status,
    required this.qrCode,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });
}
