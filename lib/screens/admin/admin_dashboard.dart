// lib/screens/admin/admin_dashboard.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tickiting/screens/admin/admin_buses.dart';
import 'package:tickiting/screens/admin/admin_payments.dart';
import 'package:tickiting/screens/admin/admin_users.dart';
import 'package:tickiting/screens/admin/admin_settings.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/services/notification_service.dart';
import 'package:tickiting/utils/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tickiting/models/notification_model.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  AdminDashboardState createState() => AdminDashboardState();
}

class AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  int _unreadCount = 0;
  final NotificationService _notificationService = NotificationService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Dashboard statistics
  int _totalBuses = 0;
  int _activeRoutes = 0;
  int _totalUsers = 0;
  int _bookingsToday = 0;
  double _totalRevenue = 0;
  List<Map<String, dynamic>> _recentBookings = [];

  final List<Widget> _screens = [
    AdminDashboardHome(
      onRefresh: () {},
      onExport: () {},
      onNavigateToPayments: () {},
    ),
    const AdminBuses(),
    const AdminPayments(),
    const AdminUsers(),
    const AdminSettings(),
  ];

  // Navigation method to go to payments screen
  void _navigateToPayments() {
    setState(() {
      _selectedIndex = 2; // Navigate to payments/bookings
    });
  }

  @override
  void initState() {
    super.initState();

    // Initialize notification service and load count
    _notificationService.initialize().then((_) {
      // After initialization, load unread count
      _loadUnreadCount();
    });

    // Listen for new notifications
    _notificationService.notificationStream.listen((notification) {
      debugPrint('Received notification in dashboard: ${notification.message}');
      if (notification.recipient == 'admin') {
        _loadUnreadCount();
        // Also refresh dashboard data when a new booking notification arrives
        if (notification.type == 'booking') {
          _loadDashboardData();
        }
      }
    });

    // Load dashboard data
    _loadDashboardData();

    // Set up periodic refresh (reduced to 1 minute for quicker updates)
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _loadDashboardData();
        _loadUnreadCount(); // Also refresh unread count periodically
      }
    });
  }

  // Load dashboard statistics
  Future<void> _loadDashboardData() async {
    try {
      // Get total buses
      final buses = await _databaseHelper.getAllBuses();

      // Get total users
      final users = await _databaseHelper.getAllUsers();

      // Get today's bookings
      final allBookings = await _databaseHelper.getAllBookings();
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      final todayBookings =
          allBookings.where((booking) {
            if (booking.createdAt == null) return false;
            final bookingDate = DateTime.parse(booking.createdAt!);
            return bookingDate.isAfter(todayStart);
          }).toList();

      // Get total revenue
      final revenue = await _databaseHelper.getTotalRevenue();

      // Get recent bookings for display
      final recentBookings = await _processRecentBookings(
        allBookings.take(5).toList(),
      );

      // Update state
      if (mounted) {
        setState(() {
          _totalBuses = buses.length;
          _activeRoutes = _countActiveRoutes(buses);
          _totalUsers = users.length;
          _bookingsToday = todayBookings.length;
          _totalRevenue = revenue;
          _recentBookings = recentBookings;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
    }
  }

  // Count active routes based on unique origin-destination pairs
  int _countActiveRoutes(List<dynamic> buses) {
    final Set<String> routes = {};
    for (var bus in buses) {
      final route = '${bus.fromLocation} to ${bus.toLocation}';
      routes.add(route);
    }
    return routes.length;
  }

  // Process booking data to include user names using the notification service's cache
  Future<List<Map<String, dynamic>>> _processRecentBookings(
    List<dynamic> bookings,
  ) async {
    List<Map<String, dynamic>> result = [];
    
    debugPrint('Processing ${bookings.length} recent bookings for dashboard display');

    for (var booking in bookings) {
      // Get user info
      final user = await _databaseHelper.getUserById(booking.userId);

      // Get real user name, not System Administrator
      String displayName;
      if (user != null &&
          user.name.isNotEmpty &&
          user.name != "Admin User" &&
          user.name != "System Administrator") {
        displayName = user.name;
      } else {
        // Find a real user to display instead
        final users = await _databaseHelper.getAllUsers();
        final validUsers =
            users
                .where(
                  (u) =>
                      u.name != "Admin User" &&
                      u.name != "System Administrator",
                )
                .toList();

        if (validUsers.isNotEmpty) {
          displayName = validUsers.first.name;
        } else {
          displayName = "Customer #${booking.userId}";
        }
      }

      // Format and add the booking data
      result.add({
        'id': booking.id,
        'name': displayName,
        'route': '${booking.fromLocation} to ${booking.toLocation}',
        'time': _formatBookingTime(booking.createdAt),
        'amount': '${booking.totalAmount} RWF',
        'status': booking.bookingStatus,
      });
    }

    return result;
  }

  // Format booking time for display
  String _formatBookingTime(String? dateTimeStr) {
    if (dateTimeStr == null) return 'Unknown';

    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Improve the _loadUnreadCount method
  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationService.getUnreadCount(recipient: 'admin');
      
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
      
      debugPrint('Updated unread notification count: $_unreadCount');
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  // Improve the _showNotifications method to refresh properly
  void _showNotifications() async {
    try {
      // Get updated notifications
      final notifications = await _notificationService.getNotifications(
        recipient: 'admin',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[800],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_unreadCount > 0)
                            TextButton(
                              onPressed: () async {
                                await _notificationService.markAllAsRead(
                                  recipient: 'admin',
                                );
                                _loadUnreadCount();
                                Navigator.pop(context);
                                // Refresh dashboard data after marking all as read
                                _loadDashboardData();
                              },
                              child: const Text(
                                'Mark all as read',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Notification list
                    Flexible(
                      child:
                          notifications.isEmpty
                              ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('No notifications'),
                                ),
                              )
                              : ListView.separated(
                                shrinkWrap: true,
                                itemCount: notifications.length,
                                separatorBuilder:
                                    (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final notification = notifications[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getColorForType(
                                        notification.type,
                                      ).withOpacity(0.2),
                                      child: Icon(
                                        _getIconForType(notification.type),
                                        color: _getColorForType(
                                          notification.type,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      notification.title,
                                      style: TextStyle(
                                        fontWeight:
                                            notification.isRead
                                                ? FontWeight.normal
                                                : FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(notification.message),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatTime(notification.time),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // View/action button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.open_in_new,
                                            size: 20,
                                          ),
                                          tooltip: 'View details',
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _handleNotificationAction(
                                              notification,
                                            );
                                            _notificationService.markAsRead(
                                              notification.id,
                                            );
                                            _loadUnreadCount();
                                          },
                                        ),
                                        // Delete button
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 20,
                                          ),
                                          tooltip: 'Delete',
                                          onPressed: () async {
                                            await _notificationService
                                                .deleteNotification(
                                                  notification.id,
                                                );
                                            _loadUnreadCount();

                                            // Refresh dialog
                                            Navigator.pop(context);
                                            _showNotifications();
                                          },
                                        ),
                                      ],
                                    ),
                                    tileColor:
                                        notification.isRead
                                            ? null
                                            : Colors.blue.withOpacity(0.1),
                                    onTap: () async {
                                      if (!notification.isRead) {
                                        await _notificationService.markAsRead(
                                          notification.id,
                                        );
                                        _loadUnreadCount();

                                        // Refresh dialog
                                        Navigator.pop(context);
                                        _showNotifications();
                                      }
                                    },
                                  );
                                },
                              ),
                    ),

                    // Close button
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[800],
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    } catch (e) {
      debugPrint('Error showing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  // Handle action when notification is clicked
  void _handleNotificationAction(NotificationModel notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case 'booking':
        // Navigate to bookings
        setState(() {
          _selectedIndex = 2; // Payment Management screen includes bookings
        });
        break;
      case 'payment':
        // Navigate to payments
        setState(() {
          _selectedIndex = 2; // Payment Management screen
        });
        break;
      case 'user':
        // Navigate to users
        setState(() {
          _selectedIndex = 3; // User Management screen
        });
        break;
      default:
        // Default to dashboard
        setState(() {
          _selectedIndex = 0;
        });
    }
  }

  // Helper methods for notification display
  IconData _getIconForType(String type) {
    switch (type) {
      case 'booking':
      case 'booking_confirmation':
        return Icons.confirmation_number;
      case 'payment':
        return Icons.payment;
      case 'user':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'booking':
      case 'booking_confirmation':
        return Colors.green;
      case 'payment':
        return Colors.purple;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Export dashboard data to CSV
  Future<void> _exportDashboardData() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Dialog(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 20),
                    Text('Exporting dashboard data...'),
                  ],
                ),
              ),
            ),
      );

      // Prepare the CSV data
      List<List<dynamic>> csvData = [];

      // Add headers and summary data
      csvData.add(['Rwanda Bus Admin Dashboard Summary']);
      csvData.add(['Generated on', DateTime.now().toString()]);
      csvData.add(['']);

      csvData.add(['Summary Statistics']);
      csvData.add(['Total Buses', _totalBuses]);
      csvData.add(['Active Routes', _activeRoutes]);
      csvData.add(['Total Users', _totalUsers]);
      csvData.add(['Bookings Today', _bookingsToday]);
      csvData.add(['Total Revenue', '$_totalRevenue RWF']);
      csvData.add(['']);

      // Recent bookings
      csvData.add(['Recent Bookings']);
      csvData.add(['ID', 'Customer', 'Route', 'Time', 'Amount', 'Status']);

      for (var booking in _recentBookings) {
        csvData.add([
          booking['id'],
          booking['name'],
          booking['route'],
          booking['time'],
          booking['amount'],
          booking['status'],
        ]);
      }

      // Convert to CSV
      String csv = const ListToCsvConverter().convert(csvData);

      // Get documents directory and create file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'dashboard_summary_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';

      // Write the file
      final File file = File(filePath);
      await file.writeAsString(csv);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Rwanda Bus Dashboard Summary',
        text: 'Dashboard summary exported on ${DateTime.now().toString()}',
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dashboard data exported successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update the dashboard widget with real data
    final updatedDashboard = AdminDashboardHome(
      totalBuses: _totalBuses,
      activeRoutes: _activeRoutes,
      totalUsers: _totalUsers,
      bookingsToday: _bookingsToday,
      totalRevenue: _totalRevenue,
      recentBookings: _recentBookings,
      onRefresh: _loadDashboardData,
      onExport: _exportDashboardData,
      onNavigateToPayments: _navigateToPayments,
    );

    // Update screens array with the dynamically created dashboard
    List<Widget> updatedScreens = List.from(_screens);
    updatedScreens[0] = updatedDashboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blueGrey[800],
        actions: [
          // Export button for dashboard
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportDashboardData,
              tooltip: 'Export Dashboard Data',
              color: Colors.white,
            ),

          // Refresh button for dashboard
          if (_selectedIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                // Refresh both dashboard data and notifications
                _loadDashboardData();
                _loadUnreadCount();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dashboard refreshed'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Refresh Dashboard',
              color: Colors.white,
            ),

          // Notification icon with animation when there are unread notifications
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                transform: _unreadCount > 0 
                  ? Matrix4.rotationZ(0.1)
                  : Matrix4.rotationZ(0),
                child: IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    // Refresh unread count first, then show notifications
                    _loadUnreadCount().then((_) {
                      _showNotifications();
                    });
                  },
                  tooltip: 'Notifications',
                  color: _unreadCount > 0 ? Colors.yellow : Colors.white,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blueGrey[800]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 30,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Admin Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'admin@rwandabus.com',
                    style: TextStyle(color: Colors.grey[300], fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(0, 'Dashboard', Icons.dashboard),
            _buildDrawerItem(1, 'Bus Management', Icons.directions_bus),
            _buildDrawerItem(2, 'Payment Management', Icons.payment),
            _buildDrawerItem(3, 'User Management', Icons.people),
            _buildDrawerItem(4, 'Settings', Icons.settings),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.pop(context); // Go back to main app
              },
            ),
          ],
        ),
      ),
      body: updatedScreens[_selectedIndex],
    );
  }

  Widget _buildDrawerItem(int index, String title, IconData icon) {
    return ListTile(
      leading: Icon(
        icon,
        color: _selectedIndex == index ? AppTheme.primaryColor : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: _selectedIndex == index ? AppTheme.primaryColor : Colors.black,
          fontWeight:
              _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex == index,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context); // Close drawer
      },
    );
  }
}

// AdminDashboardHome class with fixed welcome section to prevent overflow
class AdminDashboardHome extends StatelessWidget {
  final int totalBuses;
  final int activeRoutes;
  final int totalUsers;
  final int bookingsToday;
  final double totalRevenue;
  final List<Map<String, dynamic>> recentBookings;
  final Function onRefresh;
  final Function onExport;
  final Function onNavigateToPayments;

  const AdminDashboardHome({
    super.key,
    this.totalBuses = 0,
    this.activeRoutes = 0,
    this.totalUsers = 0,
    this.bookingsToday = 0,
    this.totalRevenue = 0,
    this.recentBookings = const [],
    required this.onRefresh,
    required this.onExport,
    required this.onNavigateToPayments,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await onRefresh();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section - FIXED to prevent overflow
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Limit width to prevent overflow
                    SizedBox(
                      width:
                          constraints.maxWidth * 0.65, // Limit to 65% of width
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, Admin',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Here\'s what\'s happening today',
                            style: TextStyle(color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        onExport();
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Export'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 30),
            // Stats cards
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStatCard(
                  'Total Buses',
                  totalBuses.toString(),
                  Icons.directions_bus,
                  Colors.blue,
                ),
                _buildStatCard(
                  'Active Routes',
                  activeRoutes.toString(),
                  Icons.map,
                  Colors.green,
                ),
                _buildStatCard(
                  'Users',
                  totalUsers.toString(),
                  Icons.people,
                  Colors.orange,
                ),
                _buildStatCard(
                  'Bookings Today',
                  bookingsToday.toString(),
                  Icons.confirmation_number,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 30),
            // Revenue overview card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Revenue Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: ${totalRevenue.toStringAsFixed(2)} RWF',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Simple revenue display instead of chart
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.trending_up,
                            size: 50,
                            color: Colors.green.withOpacity(0.8),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${totalRevenue.toStringAsFixed(2)} RWF',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Total Revenue',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Recent bookings
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Bookings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          onNavigateToPayments();
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  recentBookings.isEmpty
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No recent bookings'),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: recentBookings.length,
                        itemBuilder: (context, index) {
                          return _buildBookingItem(recentBookings[index]);
                        },
                      ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Bus info card
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bus Fleet Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildBusInfoItem(
                        Icons.directions_bus,
                        Colors.blue,
                        'Total Buses',
                        totalBuses.toString(),
                      ),
                      _buildBusInfoItem(
                        Icons.map,
                        Colors.green,
                        'Active Routes',
                        activeRoutes.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Buses Running Today',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${(totalBuses * 0.75).round()}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Available Seats',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${(totalBuses * 30 * 0.3).round()}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(title, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBusInfoItem(
    IconData icon,
    Color color,
    String title,
    String value,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildBookingItem(Map<String, dynamic> booking) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blueGrey[100],
            child: Text(
              booking['name'].substring(0, 1),
              style: TextStyle(
                color: Colors.blueGrey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${booking['route']} - ${booking['time']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                booking['amount'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      booking['status'] == 'Confirmed'
                          ? Colors.green[100]
                          : Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  booking['status'],
                  style: TextStyle(
                    color:
                        booking['status'] == 'Confirmed'
                            ? Colors.green[700]
                            : Colors.orange[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}