// lib/main.dart (updated)
import 'package:flutter/material.dart';
import 'package:tickiting/screens/welcome_screen.dart';
import 'package:tickiting/services/auth_service.dart';
import 'package:tickiting/utils/database_helper.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  final databaseHelper = DatabaseHelper();
  await databaseHelper.database;

  // Aggressively fix existing notifications
  await _fixExistingNotifications();

  // Also use the database helper's method for comprehensive fix
  await databaseHelper.replaceAdminUserInAllNotifications();

  // Initialize the notification service which will also run its own fixExistingNotifications
  final notificationService = NotificationService();
  await notificationService.initialize();

    try {
    final currentUser = await AuthService().getCurrentUser();
    if (currentUser != null) {
      debugPrint('===== STARTUP: Current user is ${currentUser.name} (ID: ${currentUser.id}) =====');
    } else {
      debugPrint('===== STARTUP: No user is currently logged in =====');
    }
  } catch (e) {
    debugPrint('===== STARTUP: Error checking current user: $e =====');
  }

  runApp(const MyApp());
}

Future<void> _fixExistingNotifications() async {
  final databaseHelper = DatabaseHelper();
  final db = await databaseHelper.database;

  debugPrint("Starting to fix Admin User notifications...");

  // First, get all available users to find a suitable replacement
  final users = await databaseHelper.getAllUsers();
  final realUsers = users.where((user) => user.name != 'Admin User').toList();

  // Default replacement name if no match is found
  String defaultName = "Real User";
  if (realUsers.isNotEmpty) {
    defaultName = realUsers.first.name;
  }

  // Get all notifications with "Admin User" in the message
  final notifications = await db.query(
    'notifications',
    where: 'message LIKE ?',
    whereArgs: ['%Admin User%'],
  );

  debugPrint("Found ${notifications.length} notifications to fix");

  for (var notification in notifications) {
    final int id = notification['id'] as int;
    final String message = notification['message'] as String;
    final int? userId = notification['userId'] as int?;
    String updatedMessage = message;
    bool wasFixed = false;

    // STRATEGY 1: Try to extract user info using the booking information
    if (message.contains("booked a ticket from")) {
      final pattern = RegExp(r'Admin User booked a ticket from (\w+) to (\w+)');
      final match = pattern.firstMatch(message);

      if (match != null) {
        final fromLocation = match.group(1);
        final toLocation = match.group(2);

        // Try to find a matching booking
        final bookings = await databaseHelper.getAllBookings();
        final matchingBooking =
            bookings
                .where(
                  (b) =>
                      b.fromLocation == fromLocation &&
                      b.toLocation == toLocation,
                )
                .toList();

        if (matchingBooking.isNotEmpty) {
          // Use the user ID from the booking
          final bookingUserId = matchingBooking.first.userId;
          final user = await databaseHelper.getUserById(bookingUserId);

          if (user != null && user.name != "Admin User") {
            updatedMessage = message.replaceAll("Admin User", user.name);
            wasFixed = true;

            await db.update(
              'notifications',
              {'message': updatedMessage},
              where: 'id = ?',
              whereArgs: [id],
            );

            debugPrint(
              "Fixed notification #$id: '$message' -> '$updatedMessage'",
            );
          }
        }
      }
    }

    // STRATEGY 2: For other notification types, try using the userId if available
    if (!wasFixed && userId != null) {
      final user = await databaseHelper.getUserById(userId);

      if (user != null && user.name != "Admin User") {
        updatedMessage = message.replaceAll("Admin User", user.name);
        wasFixed = true;

        await db.update(
          'notifications',
          {'message': updatedMessage},
          where: 'id = ?',
          whereArgs: [id],
        );

        debugPrint(
          "Fixed notification #$id using userId: '$message' -> '$updatedMessage'",
        );
      }
    }

    // STRATEGY 3: If still not fixed, use the default name
    if (!wasFixed) {
      if (userId != null) {
        // If we have a userId but couldn't get a name, use "User #ID"
        updatedMessage = message.replaceAll("Admin User", "User #$userId");
      } else {
        // Otherwise use the default real user name
        updatedMessage = message.replaceAll("Admin User", defaultName);
      }

      await db.update(
        'notifications',
        {'message': updatedMessage},
        where: 'id = ?',
        whereArgs: [id],
      );

      debugPrint(
        "Fixed notification #$id using default approach: '$message' -> '$updatedMessage'",
      );
    }
  }

  debugPrint("Completed fixing Admin User notifications");

  // Finally, update the Admin User name in the users table
  try {
    await db.update(
      'users',
      {'name': 'System Administrator'},
      where: 'name = ? AND email = ?',
      whereArgs: ['Admin User', 'admin@rwandabus.com'],
    );
    debugPrint("Updated admin user name to 'System Administrator'");
  } catch (e) {
    debugPrint("Error updating admin user name: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rwanda Bus Booking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
