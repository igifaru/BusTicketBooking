// lib/services/notification_service.dart
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:tickiting/utils/database_helper.dart';
// import 'package:tickiting/models/booking.dart';
// import 'package:tickiting/models/user.dart';

// Notification model class
class NotificationModel {
  final int id;
  final String title;
  String message; // Changed from final to allow updating
  final DateTime time;
  bool isRead;
  final String type; // 'booking', 'payment', 'user', etc.
  final String recipient; // 'admin', 'user'
  final int? userId; // Optional: ID of the user if recipient is 'user'

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
    required this.type,
    required this.recipient,
    this.userId,
  });

  // Convert notification to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'time': time.toIso8601String(),
      'isRead': isRead ? 1 : 0,
      'type': type,
      'recipient': recipient,
      'userId': userId,
    };
  }

  // Create a notification from a map (from database)
  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] ?? 0,
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      time: map['time'] != null ? DateTime.parse(map['time']) : DateTime.now(),
      isRead: map['isRead'] == 1,
      type: map['type'] ?? '',
      recipient: map['recipient'] ?? '',
      userId: map['userId'],
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _notificationController = StreamController<NotificationModel>.broadcast();

  // Stream to listen for new notifications
  Stream<NotificationModel> get notificationStream =>
      _notificationController.stream;

  // Timer for checking new bookings
  Timer? _notificationTimer;

  // Settings
  bool _enableNotifications = true;
  bool _enableBookingConfirmation = true;
  bool _enablePaymentReminders = true;

  // Private constructor
  NotificationService._internal();

  // Factory constructor to return the same instance
  factory NotificationService() {
    return _instance;
  }

  // Initialize the service
  Future<void> initialize() async {
    debugPrint('NotificationService initialized');
  }

  Future<List<NotificationModel>> getNotifications({
    String? recipient,
    int? userId,
  }) async {
    // Sanitize message to prevent "Admin User" from appearing
    message = await _sanitizeNotificationMessage(message, userId);

    final notification = NotificationModel(
      id: 0, // This will be auto-incremented by the database
      title: title,
      message: message,
      time: DateTime.now(),
      isRead: false,
      type: type,
      recipient: recipient,
      userId: userId,
    );

    // Prepare notification data for database
    final notificationMap = {
      'title': notification.title,
      'message': notification.message,
      'time': notification.time.toIso8601String(),
      'isRead': notification.isRead ? 1 : 0,
      'type': notification.type,
      'recipient': notification.recipient,
      'userId': notification.userId,
    };

    // Insert into database
    final id = await _databaseHelper.insertNotification(notificationMap);

    // Create a new notification with the generated ID
    final createdNotification = NotificationModel(
      id: id,
      title: notification.title,
      message: notification.message,
      time: notification.time,
      isRead: notification.isRead,
      type: notification.type,
      recipient: notification.recipient,
      userId: notification.userId,
    );

    // Broadcast the new notification
    _notificationController.add(createdNotification);

    return createdNotification;
  }

  // Get all notifications for a specific recipient
  Future<List<NotificationModel>> getNotifications({
    required String recipient,
    int? userId,
  }) async {
    final List<Map<String, dynamic>> maps = await _databaseHelper
        .getNotifications(recipient: recipient, userId: userId);

    final notifications = List.generate(maps.length, (i) {
      return NotificationModel.fromMap(maps[i]);
    });

    // Process notifications to fix any "Admin User" references on the fly
    for (var notification in notifications) {
      if (notification.message.contains('Admin User')) {
        // Try to get the actual user name if the notification has a userId
        if (notification.userId != null) {
          try {
            final user = await _databaseHelper.getUserById(
              notification.userId!,
            );
            if (user != null &&
                user.name.isNotEmpty &&
                user.name != "Admin User") {
              final updatedMessage = notification.message.replaceAll(
                'Admin User',
                user.name,
              );

              // Update the notification in the database
              await updateNotificationMessage(notification.id, updatedMessage);

              // Update the in-memory notification object
              notification.message = updatedMessage;
            } else {
              // Fallback to a generic name
              final updatedMessage = notification.message.replaceAll(
                'Admin User',
                'User #${notification.userId}',
              );

              await updateNotificationMessage(notification.id, updatedMessage);
              notification.message = updatedMessage;
            }
          } catch (e) {
            debugPrint(
              'Error fixing Admin User in notification during retrieval: $e',
            );
          }
        } else {
          // If no userId, replace with "Customer"
          final updatedMessage = notification.message.replaceAll(
            'Admin User',
            'Customer',
          );

          await updateNotificationMessage(notification.id, updatedMessage);
          notification.message = updatedMessage;
        }
      }
    }

    return notifications;
  }

  // Get unread notifications count
  Future<int> getUnreadCount({required String recipient, int? userId}) async {
    return await _databaseHelper.getUnreadNotificationsCount(
      recipient: recipient,
      userId: userId,
    );
  }

  // Mark a notification as read
  Future<void> markAsRead(int id) async {
    await _databaseHelper.markNotificationAsRead(id);
  }

  // Mark all notifications as read
  Future<void> markAllAsRead({required String recipient, int? userId}) async {
    await _databaseHelper.markAllNotificationsAsRead(
      recipient: recipient,
      userId: userId,
    );
  }

  // Delete a notification
  Future<void> deleteNotification(int id) async {
    await _databaseHelper.deleteNotification(id);
  }

  // Delete all notifications for a recipient
  Future<void> deleteAllNotifications({
    required String recipient,
    int? userId,
  }) async {
    String? whereClause;
    List<dynamic>? whereArgs;

    if (userId != null) {
      whereClause = 'recipient = ? AND userId = ?';
      whereArgs = [recipient, userId];
    } else {
      whereClause = 'recipient = ?';
      whereArgs = [recipient];
    }

    final db = await _databaseHelper.database;
    await db.delete('notifications', where: whereClause, whereArgs: whereArgs);
  }

  // Create a booking notification for admin
  Future<NotificationModel> createBookingNotificationForAdmin({
    required int userId,
    required String userName,
    required String origin,
    required String destination,
  }) async {
    if (!_enableNotifications || !_enableBookingConfirmation) {
      return Future.error('Notifications disabled');
    }

    // IMPORTANT: Always get the actual user name from the database
    String displayName;
    try {
      final user = await _databaseHelper.getUserById(userId);
      if (user != null && user.name.isNotEmpty && user.name != "Admin User") {
        displayName = user.name;
      } else {
        displayName = userName != 'Admin User' ? userName : 'User #$userId';
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
      displayName = userName != 'Admin User' ? userName : 'User #$userId';
    }

    final title = 'New Booking';
    final message = '$displayName booked a ticket from $origin to $destination';

    return createNotification(
      title: title,
      message: message,
      type: 'booking',
      recipient: 'admin',
    );
  }

  // Create a payment notification for admin
  Future<NotificationModel> createPaymentNotificationForAdmin({
    required int userId,
    required String userName,
    required double amount,
    String currency = 'RWF',
  }) async {
    if (!_enableNotifications || !_enablePaymentReminders) {
      return Future.error('Notifications disabled');
    }

    // Get the actual user name for payment notifications too
    String displayName;
    try {
      final user = await _databaseHelper.getUserById(userId);
      if (user != null && user.name.isNotEmpty && user.name != "Admin User") {
        displayName = user.name;
      } else {
        displayName = userName != 'Admin User' ? userName : 'User #$userId';
      }
    } catch (e) {
      debugPrint('Error fetching user name: $e');
      displayName = userName != 'Admin User' ? userName : 'User #$userId';
    }

    final title = 'Payment Received';
    final message = 'Payment of $amount $currency received from $displayName';

    return createNotification(
      title: title,
      message: message,
      type: 'payment',
      recipient: 'admin',
    );
  }

  // Create a booking confirmation notification for user
  Future<NotificationModel> createBookingConfirmationForUser({
    required int userId,
    required String userName,
    required String origin,
    required String destination,
    required DateTime travelDate,
  }) async {
    if (!_enableNotifications || !_enableBookingConfirmation) {
      return Future.error('Notifications disabled');
    }

    final title = 'Booking Confirmed';
    final message =
        'Your ticket from $origin to $destination on ${_formatDate(travelDate)} has been confirmed.';

    return createNotification(
      title: title,
      message: message,
      type: 'booking_confirmation',
      recipient: 'user',
      userId: userId,
    );
  }

  // Create a payment confirmation notification for user
  Future<NotificationModel> createPaymentConfirmationForUser({
    required int userId,
    required String userName,
    required double amount,
    String currency = 'RWF',
  }) async {
    if (!_enableNotifications || !_enablePaymentReminders) {
      return Future.error('Notifications disabled');
    }

    final title = 'Payment Confirmed';
    final message =
        'Your payment of $amount $currency has been received. Thank you!';

    return createNotification(
      title: title,
      message: message,
      type: 'payment_confirmation',
      recipient: 'user',
      userId: userId,
    );
  }

  // Create booking status update notification for user
  Future<NotificationModel> createBookingStatusUpdateForUser({
    required int userId,
    required String bookingId,
    required String status,
    required String origin,
    required String destination,
  }) async {
    if (!_enableNotifications) return Future.error('Notifications disabled');

    String title, message;

    switch (status.toLowerCase()) {
      case 'confirmed':
        title = 'Booking Confirmed';
        message =
            'Your booking from $origin to $destination has been confirmed.';
        break;
      case 'cancelled':
        title = 'Booking Cancelled';
        message =
            'Your booking from $origin to $destination has been cancelled.';
        break;
      case 'completed':
        title = 'Trip Completed';
        message =
            'Your trip from $origin to $destination has been completed. Thank you for traveling with us!';
        break;
      default:
        title = 'Booking Update';
        message =
            'Your booking from $origin to $destination has been updated to $status.';
    }

    return createNotification(
      title: title,
      message: message,
      type: 'booking_status',
      recipient: 'user',
      userId: userId,
    );
  }

  // Format date helper function
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Update notification message
  Future<void> updateNotificationMessage(
    int notificationId,
    String newMessage,
  ) async {
    final db = await _databaseHelper.database;
    await db.update(
      'notifications',
      {'message': newMessage},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  // Fix existing notifications
  Future<void> fixExistingNotifications() async {
    try {
      final db = await _databaseHelper.database;

      // Get all users except Admin User to have a list of real names
      final users = await _databaseHelper.getAllUsers();
      final realUsers =
          users.where((user) => user.name != 'Admin User').toList();

      if (realUsers.isEmpty) {
        debugPrint('No real users found to fix notifications');
        // Still attempt to replace "Admin User" with "System Administrator"
        await db.rawUpdate(
          "UPDATE notifications SET message = REPLACE(message, 'Admin User', 'System Administrator')",
        );
        return;
      }

      // Default to the first real user if we can't determine the actual user
      final defaultRealUser = realUsers.first;

      // Get all notifications with "Admin User" in the message
      final List<Map<String, dynamic>> notifications = await db.query(
        'notifications',
        where: 'message LIKE ?',
        whereArgs: ['%Admin User%'],
      );

      debugPrint(
        'Found ${notifications.length} notifications with "Admin User" to fix',
      );

      // Process each notification that needs fixing
      for (var notification in notifications) {
        final int id = notification['id'];
        final String message = notification['message'];
        final int? userId = notification['userId'];
        String updatedMessage = message;

        // Try several approaches to find the correct user

        // APPROACH 1: If notification has userId, use it directly
        if (userId != null) {
          try {
            final user = await _databaseHelper.getUserById(userId);
            if (user != null &&
                user.name.isNotEmpty &&
                user.name != 'Admin User') {
              updatedMessage = message.replaceAll('Admin User', user.name);
            }
          } catch (e) {
            debugPrint('Error getting user by ID for notification #$id: $e');
          }
        }

        // APPROACH 2: If message is a booking notification, try to extract location info
        if (message.contains('booked a ticket from') &&
            updatedMessage == message) {
          try {
            final regex = RegExp(
              r'Admin User booked a ticket from (\w+) to (\w+)',
            );
            final match = regex.firstMatch(message);

            if (match != null) {
              final fromLocation = match.group(1);
              final toLocation = match.group(2);

              // Find bookings with matching locations
              final bookings = await _databaseHelper.getAllBookings();
              final matchingBookings =
                  bookings
                      .where(
                        (booking) =>
                            booking.fromLocation == fromLocation &&
                            booking.toLocation == toLocation,
                      )
                      .toList();

              if (matchingBookings.isNotEmpty) {
                // Use most recent matching booking
                final booking = matchingBookings.first;
                final user = await _databaseHelper.getUserById(booking.userId);

                if (user != null &&
                    user.name.isNotEmpty &&
                    user.name != 'Admin User') {
                  updatedMessage = message.replaceAll('Admin User', user.name);
                }
              }
            }
          } catch (e) {
            debugPrint(
              'Error matching booking locations for notification #$id: $e',
            );
          }
        }

        // APPROACH 3: If still using Admin User, use default real user
        if (updatedMessage.contains('Admin User')) {
          updatedMessage = message.replaceAll(
            'Admin User',
            defaultRealUser.name,
          );
        }

        // Only update if we actually changed something
        if (updatedMessage != message) {
          try {
            await db.update(
              'notifications',
              {'message': updatedMessage},
              where: 'id = ?',
              whereArgs: [id],
            );
            debugPrint(
              'Fixed notification #$id: "$message" -> "$updatedMessage"',
            );
          } catch (e) {
            debugPrint('Error updating notification #$id: $e');
          }
        }
      }

      debugPrint('Completed fixing existing notifications');
    } catch (e) {
      debugPrint('Error in fixExistingNotifications: $e');
    }
  }
}
