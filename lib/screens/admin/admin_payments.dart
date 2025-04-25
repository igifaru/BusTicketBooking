// lib/screens/admin/admin_payments.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tickiting/models/booking.dart';
import 'package:tickiting/utils/database_helper.dart';

class AdminPayments extends StatefulWidget {
  const AdminPayments({super.key});

  @override
  State<AdminPayments> createState() => _AdminPaymentsState();
}

class _AdminPaymentsState extends State<AdminPayments> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Booking> _pendingBookings = [];
  List<Booking> _confirmedBookings = [];
  List<Booking> _cancelledBookings = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBookings();
    
    // Set up timer to refresh data periodically
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadBookings();
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Load all bookings with user details
  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all bookings
      final bookings = await _databaseHelper.getAllBookings();
      
      // Separate bookings by status
      final pending = bookings.where((b) => b.bookingStatus == 'Pending').toList();
      final confirmed = bookings.where((b) => b.bookingStatus == 'Confirmed').toList();
      final cancelled = bookings.where((b) => b.bookingStatus == 'Cancelled').toList();
      
      setState(() {
        _pendingBookings = pending;
        _confirmedBookings = confirmed;
        _cancelledBookings = cancelled;
        _isLoading = false;
      });
      
      debugPrint('Loaded ${bookings.length} bookings (${pending.length} pending, ${confirmed.length} confirmed, ${cancelled.length} cancelled)');
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Confirm a booking
  Future<void> _confirmBooking(String bookingId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _databaseHelper.updateBookingStatus(bookingId, 'Confirmed');
      await _databaseHelper.updatePaymentStatus(bookingId, 'Confirmed');
      
      if (result > 0) {
        // Get the booking to find the user
        final booking = await _databaseHelper.getBookingById(bookingId);
        if (booking != null) {
          // Create notification for the user
          await _databaseHelper.insertNotification({
            'title': 'Booking Confirmed',
            'message': 'Your booking from ${booking.fromLocation} to ${booking.toLocation} has been confirmed.',
            'time': DateTime.now().toIso8601String(),
            'isRead': 0,
            'type': 'booking_confirmation',
            'recipient': 'user',
            'userId': booking.userId,
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking confirmed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to confirm booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // Reload bookings to update UI
      await _loadBookings();
    } catch (e) {
      debugPrint('Error confirming booking: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Cancel a booking
  Future<void> _cancelBooking(String bookingId) async {
    final reasonController = TextEditingController();
    
    // Show dialog to get cancellation reason
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for cancellation:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              setState(() {
                _isLoading = true;
              });
              
              try {
                final result = await _databaseHelper.updateBookingStatus(bookingId, 'Cancelled');
                
                if (result > 0) {
                  // Create notification for user
                  final booking = await _databaseHelper.getBookingById(bookingId);
                  if (booking != null) {
                    await _databaseHelper.insertNotification({
                      'title': 'Booking Cancelled',
                      'message': 'Your booking from ${booking.fromLocation} to ${booking.toLocation} has been cancelled. ${reasonController.text.isNotEmpty ? "Reason: ${reasonController.text}" : ""}',
                      'time': DateTime.now().toIso8601String(),
                      'isRead': 0,
                      'type': 'booking',
                      'recipient': 'user',
                      'userId': booking.userId,
                    });
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Booking cancelled successfully'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to cancel booking'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                
                // Reload bookings to update UI
                await _loadBookings();
              } catch (e) {
                debugPrint('Error cancelling booking: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {
                  _isLoading = false;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  // View booking details
  void _viewBookingDetails(Booking booking) async {
    // Get user and bus information
    final user = await _databaseHelper.getUserById(booking.userId);
    final bus = await _databaseHelper.getBus(booking.busId);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Booking info
              _buildDetailSection('Booking Information', [
                {'Booking ID': booking.id},
                {'Status': booking.bookingStatus},
                {'Date': booking.travelDate},
                {'Created': _formatDateTime(booking.createdAt)},
              ]),
              
              const Divider(),
              
              // Customer info
              _buildDetailSection('Customer Information', [
                {'Name': user?.name ?? 'Unknown'},
                {'Email': user?.email ?? 'Unknown'},
                {'Phone': user?.phone ?? 'Unknown'},
              ]),
              
              const Divider(),
              
              // Bus info
              _buildDetailSection('Bus Information', [
                {'Bus': bus?.name ?? booking.busId},
                {'Route': '${booking.fromLocation} to ${booking.toLocation}'},
                {'Departure': bus?.departureTime ?? 'Unknown'},
                {'Seats': booking.seatNumbers},
                {'Passengers': booking.passengers.toString()},
              ]),
              
              const Divider(),
              
              // Payment info
              _buildDetailSection('Payment Information', [
                {'Amount': '${booking.totalAmount} RWF'},
                {'Method': booking.paymentMethod},
                {'Status': booking.paymentStatus},
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          // Show action buttons based on current status
          if (booking.bookingStatus == 'Pending') ...[
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmBooking(booking.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Approve'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _cancelBooking(booking.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Reject'),
            ),
          ],
        ],
      ),
    );
  }

  // Helper to build detail sections in the booking details dialog
  Widget _buildDetailSection(String title, List<Map<String, String>> details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        ...details.map((detail) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Text(
                '${detail.keys.first}: ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Text(
                  detail.values.first,
                  style: const TextStyle(
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 10),
      ],
    );
  }

  // Format date time for display
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';
    
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 50),
        child: AppBar(
          title: const Text('Payment Management'),
          backgroundColor: Colors.blueGrey[800],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                text: 'Pending (${_pendingBookings.length})',
              ),
              Tab(
                text: 'Confirmed (${_confirmedBookings.length})',
              ),
              Tab(
                text: 'Cancelled (${_cancelledBookings.length})',
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBookings,
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Pending bookings
                _buildBookingList(_pendingBookings),
                
                // Confirmed bookings
                _buildBookingList(_confirmedBookings),
                
                // Cancelled bookings
                _buildBookingList(_cancelledBookings),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadBookings,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBookingList(List<Booking> bookings) {
    return bookings.isEmpty
        ? const Center(
            child: Text(
              'No bookings found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          )
        : ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return FutureBuilder<String>(
                future: _getUserName(booking.userId),
                builder: (context, snapshot) {
                  final userName = snapshot.data ?? 'Loading...';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    elevation: 2,
                    child: ListTile(
                      title: Text(
                        'Booking #${booking.id}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text('Customer: $userName'),
                          Text('Route: ${booking.fromLocation} to ${booking.toLocation}'),
                          Text('Date: ${booking.travelDate}'),
                          Text('Amount: ${booking.totalAmount} RWF'),
                          Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(booking.bookingStatus),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  booking.bookingStatus,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(booking.paymentStatus),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  booking.paymentStatus,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            tooltip: 'View Details',
                            onPressed: () => _viewBookingDetails(booking),
                          ),
                          if (booking.bookingStatus == 'Pending') ...[
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                              tooltip: 'Approve',
                              onPressed: () => _confirmBooking(booking.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                              tooltip: 'Reject',
                              onPressed: () => _cancelBooking(booking.id),
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () => _viewBookingDetails(booking),
                    ),
                  );
                }
              );
            },
          );
  }
  
  // Helper method to get user name
  Future<String> _getUserName(int userId) async {
    try {
      final user = await _databaseHelper.getUserById(userId);
      return user?.name ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Confirmed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Cancelled':
        return Colors.red;
      case 'Refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}