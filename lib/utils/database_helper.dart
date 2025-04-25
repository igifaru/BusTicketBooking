// lib/utils/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tickiting/models/user.dart';
import 'package:tickiting/models/bus.dart';
import 'package:tickiting/models/booking.dart';
import 'package:tickiting/models/ticket.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Get the application documents directory
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'rwanda_bus.db');

    return await openDatabase(
      path,
      version: 4, // Increased version for schema change
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create users table with is_admin field
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        phone TEXT NOT NULL,
        gender TEXT NOT NULL,
        is_admin INTEGER DEFAULT 0,
        is_default_admin INTEGER DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute('''
    CREATE TABLE reset_tokens(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      email TEXT NOT NULL,
      phone TEXT NOT NULL,
      token TEXT NOT NULL,
      verification_method TEXT NOT NULL,
      expiry_time TIMESTAMP NOT NULL,
      is_used INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY(user_id) REFERENCES users(id)
    )
  ''');

    // Create buses table with route information
    await db.execute('''
      CREATE TABLE buses(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        departure_time TEXT NOT NULL,
        arrival_time TEXT NOT NULL,
        duration TEXT NOT NULL,
        price REAL NOT NULL,
        available_seats INTEGER NOT NULL,
        bus_type TEXT NOT NULL,
        features TEXT NOT NULL,
        from_location TEXT NOT NULL,
        to_location TEXT NOT NULL
      )
    ''');

    // Create bookings table
    await db.execute('''
      CREATE TABLE bookings(
        id TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        bus_id TEXT NOT NULL,
        from_location TEXT NOT NULL,
        to_location TEXT NOT NULL,
        travel_date TEXT NOT NULL,
        passengers INTEGER NOT NULL,
        seat_numbers TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        booking_status TEXT NOT NULL,
        notification_sent INTEGER NOT NULL DEFAULT 0,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(user_id) REFERENCES users(id),
        FOREIGN KEY(bus_id) REFERENCES buses(id)
      )
    ''');

    // Create notifications table
    await db.execute('''
      CREATE TABLE notifications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        time TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        recipient TEXT NOT NULL,
        userId INTEGER,
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Insert some initial data
    await _insertInitialData(db);
  }

  Future<int> createBooking(Ticket ticket) async {
    final db = await database;

    return await db.insert('bookings', {
      'bus_id': ticket.busName,
      'from_location': ticket.from,
      'to_location': ticket.to,
      'travel_date': ticket.date.toIso8601String(),
      'passengers': ticket.passengers,
      'seat_numbers': ticket.seatNumbers.join(','),
      'booking_status': ticket.status,
      'user_id': ticket.userId, // Pass the userId explicitly from the Ticket object
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add notifications table if upgrading from version 1
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          time TEXT NOT NULL,
          isRead INTEGER NOT NULL DEFAULT 0,
          type TEXT NOT NULL,
          recipient TEXT NOT NULL,
          userId INTEGER,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
      ''');

      // Add notification_sent column to bookings table if it doesn't exist
      await addNotificationSentColumnToBookings(db);
    }

    if (oldVersion < 3) {
      // Add route information columns to buses table if upgrading to version 3
      try {
        await db.execute(
          "ALTER TABLE buses ADD COLUMN from_location TEXT DEFAULT 'Kigali'",
        );
        await db.execute(
          "ALTER TABLE buses ADD COLUMN to_location TEXT DEFAULT 'Butare'",
        );

        // Update existing bus records with default route values
        await db.update('buses', {
          'from_location': 'Kigali',
          'to_location': 'Butare',
        });

        debugPrint("Added route information columns to buses table");
      } catch (e) {
        debugPrint("Error adding route information columns: $e");
      }
    }
    if (oldVersion < 4) {
      // Add reset_tokens table if upgrading to version 4
      try {
        await db.execute('''
        CREATE TABLE IF NOT EXISTS reset_tokens(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          email TEXT NOT NULL,
          phone TEXT NOT NULL, 
          token TEXT NOT NULL,
          verification_method TEXT NOT NULL,
          expiry_time TIMESTAMP NOT NULL,
          is_used INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          FOREIGN KEY(user_id) REFERENCES users(id)
        )
      ''');
        debugPrint("Added reset_tokens table");
      } catch (e) {
        debugPrint("Error adding reset_tokens table: $e");
      }
    }
  }

  Future<void> addNotificationSentColumnToBookings(Database db) async {
    try {
      await db.execute(
        "ALTER TABLE bookings ADD COLUMN notification_sent INTEGER DEFAULT 0",
      );
    } catch (e) {
      // Column might already exist
      debugPrint("Error adding notification_sent column: $e");
    }
  }

  Future<void> ensureRouteColumnsExistV2() async {
    final db = await database;

    try {
      // Check if columns already exist
      var tableInfo = await db.rawQuery("PRAGMA table_info(buses)");
      bool hasFromColumn = tableInfo.any(
        (column) => column['name'] == 'from_location',
      );
      bool hasToColumn = tableInfo.any(
        (column) => column['name'] == 'to_location',
      );

      if (!hasFromColumn || !hasToColumn) {
        debugPrint("Route columns missing - adding them now");

        if (!hasFromColumn) {
          await db.execute(
            "ALTER TABLE buses ADD COLUMN from_location TEXT DEFAULT 'Kigali'",
          );
          debugPrint("Added from_location column to buses table");
        }

        if (!hasToColumn) {
          await db.execute(
            "ALTER TABLE buses ADD COLUMN to_location TEXT DEFAULT 'Butare'",
          );
          debugPrint("Added to_location column to buses table");
        }

        // Update existing buses with default values
        await db.update('buses', {
          'from_location': 'Kigali',
          'to_location': 'Butare',
        }, where: "from_location IS NULL OR to_location IS NULL");

        debugPrint("Updated existing bus records with default route values");
      }
    } catch (e) {
      debugPrint("Error ensuring route columns: $e");
      // Try recreating the table if altering fails
      try {
        // Get current buses
        List<Map<String, dynamic>> busMaps = await db.query('buses');

        // Create new buses table with all columns
        await db.execute("DROP TABLE IF EXISTS buses_new");
        await db.execute('''
        CREATE TABLE buses_new(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          departure_time TEXT NOT NULL,
          arrival_time TEXT NOT NULL,
          duration TEXT NOT NULL,
          price REAL NOT NULL,
          available_seats INTEGER NOT NULL,
          bus_type TEXT NOT NULL,
          features TEXT NOT NULL,
          from_location TEXT NOT NULL DEFAULT 'Kigali',
          to_location TEXT NOT NULL DEFAULT 'Butare'
        )
      ''');

        // Copy data to new table
        for (var busMap in busMaps) {
          // Make sure all required columns are present
          Map<String, dynamic> newBusMap = {
            'id': busMap['id'],
            'name': busMap['name'],
            'departure_time': busMap['departure_time'],
            'arrival_time': busMap['arrival_time'],
            'duration': busMap['duration'],
            'price': busMap['price'],
            'available_seats': busMap['available_seats'],
            'bus_type': busMap['bus_type'],
            'features': busMap['features'],
            'from_location': 'Kigali',
            'to_location': 'Butare',
          };

          await db.insert('buses_new', newBusMap);
        }

        // Replace old table with new one
        await db.execute("DROP TABLE buses");
        await db.execute("ALTER TABLE buses_new RENAME TO buses");

        debugPrint("Recreated buses table with route columns");
      } catch (e) {
        debugPrint("Error recreating buses table: $e");
        // Last resort: force database recreation
        try {
          debugPrint(
            "Attempting to force database version update to trigger recreation",
          );
          await db.rawQuery("PRAGMA user_version = 3");
        } catch (e) {
          debugPrint("Failed to update database version: $e");
        }
      }
    }
  }

  Future<void> ensureRouteColumnsExist() async {
    final db = await database;

    try {
      // Check if columns already exist
      var tableInfo = await db.rawQuery("PRAGMA table_info(buses)");
      bool hasFromColumn = tableInfo.any(
        (column) => column['name'] == 'from_location',
      );
      bool hasToColumn = tableInfo.any(
        (column) => column['name'] == 'to_location',
      );

      if (!hasFromColumn || !hasToColumn) {
        debugPrint("Route columns missing - adding them now");

        if (!hasFromColumn) {
          await db.execute(
            "ALTER TABLE buses ADD COLUMN from_location TEXT DEFAULT 'Kigali'",
          );
          debugPrint("Added from_location column to buses table");
        }

        if (!hasToColumn) {
          await db.execute(
            "ALTER TABLE buses ADD COLUMN to_location TEXT DEFAULT 'Butare'",
          );
          debugPrint("Added to_location column to buses table");
        }

        // Update existing buses with default values
        await db.update('buses', {
          'from_location': 'Kigali',
          'to_location': 'Butare',
        }, where: "from_location IS NULL OR to_location IS NULL");

        debugPrint("Updated existing bus records with default route values");
      }
    } catch (e) {
      debugPrint("Error ensuring route columns: $e");
      // Try recreating the table if altering fails
      try {
        // Get current buses
        List<Map<String, dynamic>> busMaps = await db.query('buses');

        // Create new buses table with all columns
        await db.execute("DROP TABLE IF EXISTS buses_new");
        await db.execute('''
        CREATE TABLE buses_new(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          departure_time TEXT NOT NULL,
          arrival_time TEXT NOT NULL,
          duration TEXT NOT NULL,
          price REAL NOT NULL,
          available_seats INTEGER NOT NULL,
          bus_type TEXT NOT NULL,
          features TEXT NOT NULL,
          from_location TEXT NOT NULL DEFAULT 'Kigali',
          to_location TEXT NOT NULL DEFAULT 'Butare'
        )
      ''');

        // Copy data to new table
        for (var busMap in busMaps) {
          // Make sure all required columns are present
          Map<String, dynamic> newBusMap = {
            'id': busMap['id'],
            'name': busMap['name'],
            'departure_time': busMap['departure_time'],
            'arrival_time': busMap['arrival_time'],
            'duration': busMap['duration'],
            'price': busMap['price'],
            'available_seats': busMap['available_seats'],
            'bus_type': busMap['bus_type'],
            'features': busMap['features'],
            'from_location': 'Kigali',
            'to_location': 'Butare',
          };

          await db.insert('buses_new', newBusMap);
        }

        // Replace old table with new one
        await db.execute("DROP TABLE buses");
        await db.execute("ALTER TABLE buses_new RENAME TO buses");

        debugPrint("Recreated buses table with route columns");
      } catch (e) {
        debugPrint("Error recreating buses table: $e");
        // Last resort: force database recreation
        try {
          debugPrint(
            "Attempting to force database version update to trigger recreation",
          );
          await db.rawQuery("PRAGMA user_version = 3");
        } catch (e) {
          debugPrint("Failed to update database version: $e");
        }
      }
    }
  }

  Future<void> _insertInitialData(Database db) async {
    // Check if admin user already exists
    final adminExists = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: ['admin@rwandabus.com'],
    );

    if (adminExists.isEmpty) {
      // Only insert if admin doesn't exist, and mark as admin
      await db.insert('users', {
        'name': 'System Administrator',
        'email': 'admin@rwandabus.com',
        'password': 'admin123',
        'phone': '+250 789 123 456',
        'gender': 'Male',
        'is_admin': 1, // Mark as admin
        'is_default_admin': 1, // Mark as default admin
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    
    // Insert some sample buses with route information
    await db.insert('buses', {
      'id': 'BUS001',
      'name': 'Rwanda Express',
      'departure_time': '08:00 AM',
      'arrival_time': '10:30 AM',
      'duration': '2h 30m',
      'price': 5000,
      'available_seats': 32,
      'bus_type': 'Standard',
      'features': 'AC,WiFi,USB Charging',
      'from_location': 'Kigali',
      'to_location': 'Ruhengeri',
    });

    await db.insert('buses', {
      'id': 'BUS002',
      'name': 'Kigali Travels',
      'departure_time': '09:30 AM',
      'arrival_time': '12:00 PM',
      'duration': '2h 30m',
      'price': 5500,
      'available_seats': 28,
      'bus_type': 'Premium',
      'features': 'AC,WiFi,USB Charging,Refreshments',
      'from_location': 'Kigali',
      'to_location': 'Butare',
    });

    await db.insert('buses', {
      'id': 'BUS003',
      'name': 'Rwanda Shuttle',
      'departure_time': '11:00 AM',
      'arrival_time': '01:30 PM',
      'duration': '2h 30m',
      'price': 4800,
      'available_seats': 35,
      'bus_type': 'Economy',
      'features': 'AC',
      'from_location': 'Kigali',
      'to_location': 'Gisenyi',
    });

    // Add some buses for return journeys
    await db.insert('buses', {
      'id': 'BUS004',
      'name': 'Ruhengeri Express',
      'departure_time': '02:00 PM',
      'arrival_time': '04:30 PM',
      'duration': '2h 30m',
      'price': 5000,
      'available_seats': 30,
      'bus_type': 'Standard',
      'features': 'AC,WiFi,USB Charging',
      'from_location': 'Ruhengeri',
      'to_location': 'Kigali',
    });

    await db.insert('buses', {
      'id': 'BUS005',
      'name': 'Huye Traveler',
      'departure_time': '01:30 PM',
      'arrival_time': '04:00 PM',
      'duration': '2h 30m',
      'price': 5500,
      'available_seats': 26,
      'bus_type': 'Premium',
      'features': 'AC,WiFi,USB Charging,Refreshments',
      'from_location': 'Butare',
      'to_location': 'Kigali',
    });
  }

  // Method to replace "Admin User" in all notifications
  Future<void> replaceAdminUserInAllNotifications() async {
    final db = await database;

    // First get a list of all users
    final users = await getAllUsers();
    final realUsers = users.where((user) => user.name != 'Admin User').toList();

    // If no real users, we need to at least fix the admin user name
    if (realUsers.isEmpty) {
      debugPrint("No real users found to replace 'Admin User'");

      // Update admin user name to prevent future issues
      await db.update(
        'users',
        {'name': 'System Administrator'},
        where: 'name = ? AND email = ?',
        whereArgs: ['Admin User', 'admin@rwandabus.com'],
      );

      // Use the updated name in notifications
      final count = await db.rawUpdate(
        "UPDATE notifications SET message = REPLACE(message, 'Admin User', 'System Administrator')",
      );

      debugPrint(
        "Updated $count notifications to use 'System Administrator' instead of 'Admin User'",
      );
      return;
    }

    // Get a valid user name to use for replacements
    final replacementName = realUsers.first.name;

    // Replace ALL instances of "Admin User" with the real name
    try {
      final count = await db.rawUpdate(
        "UPDATE notifications SET message = REPLACE(message, 'Admin User', ?)",
        [replacementName],
      );

      debugPrint(
        "Updated $count notifications to use '$replacementName' instead of 'Admin User'",
      );
    } catch (e) {
      debugPrint("Error replacing Admin User in notifications: $e");
    }

    // Also update the admin user's name to prevent future occurrences
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

  // Method to update notification message
  Future<int> updateNotificationMessage(int notificationId, String newMessage) async {
    final db = await database;
    return await db.update(
      'notifications',
      {'message': newMessage},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  // Method to clear notifications containing "Admin User"
  Future<int> clearAdminUserNotifications() async {
    final db = await database;
    return await db.delete(
      'notifications',
      where: 'message LIKE ?',
      whereArgs: ['%Admin User%'],
    );
  }

  // User CRUD operations
  Future<int> insertUser(User user) async {
    Database db = await database;

    // Create a map from the user data
    Map<String, dynamic> userMap = user.toMap();

    if (userMap['created_at'] == null) {
      userMap['created_at'] = DateTime.now().toIso8601String();
    }

    return await db.insert('users', userMap);
  }

  Future<User?> getUser(String email, String password) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUserStatus(int userId, bool isActive) async {
    await _ensureUserStatusColumn();
    final db = await database;
    
    return await db.update(
      'users',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // Get booking details by ID
  Future<Map<String, dynamic>?> getBookingById(String bookingId) async {
    final db = await database;
    
    const query = '''
      SELECT 
        b.*,
        CASE 
          WHEN u.is_default_admin = 1 THEN 'Customer'
          ELSE u.name
        END as user_name,
        CASE 
          WHEN u.is_default_admin = 1 THEN 'customer@example.com'
          ELSE u.email
        END as user_email,
        CASE 
          WHEN u.is_default_admin = 1 THEN '+250 XXX XXX XXX'
          ELSE u.phone
        END as user_phone
      FROM bookings b
      LEFT JOIN users u ON b.user_id = u.id
      WHERE b.id = ?
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query, [bookingId]);
    
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Admin functions to approve a booking
  Future<int> approveBooking(String bookingId) async {
    // Update both booking and payment status
    Database db = await database;
    
    // First update the booking status
    final bookingResult = await db.update(
      'bookings',
      {'booking_status': 'Confirmed'},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
    
    // Then update the payment status
    final paymentResult = await db.update(
      'bookings',
      {'payment_status': 'Confirmed'},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
    
    // Create a notification for the user
    if (bookingResult > 0) {
      // Get the booking to find the user
      final booking = await getBookingById(bookingId);
      if (booking != null) {
        // Get route information for the notification
        final notificationData = {
          'title': 'Booking Confirmed',
          'message': 'Your booking from ${booking['from_location']} to ${booking['to_location']} has been confirmed.',
          'time': DateTime.now().toIso8601String(),
          'isRead': 0,
          'type': 'booking_confirmation',
          'recipient': 'user',
          'userId': booking['user_id'],
        };
        
        await db.insert('notifications', notificationData);
      }
    }
    
    return bookingResult;
  }

  // Admin function to reject a booking
  Future<int> rejectBooking(String bookingId, String reason) async {
    Database db = await database;
    
    // Update both booking and payment status
    final bookingResult = await db.update(
      'bookings',
      {'booking_status': 'Cancelled'},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
    
    await db.update(
      'bookings',
      {'payment_status': 'Refunded'},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
    
    // Create a notification for the user
    if (bookingResult > 0) {
      // Get the booking to find the user
      final booking = await getBookingById(bookingId);
      if (booking != null) {
        // Get route information for the notification
        final notificationData = {
          'title': 'Booking Cancelled',
          'message': 'Your booking from ${booking['from_location']} to ${booking['to_location']} has been cancelled. ${reason.isNotEmpty ? "Reason: $reason" : ""}',
          'time': DateTime.now().toIso8601String(),
          'isRead': 0,
          'type': 'booking_cancellation',
          'recipient': 'user',
          'userId': booking['user_id'],
        };
        
        await db.insert('notifications', notificationData);
      }
    }
    
    return bookingResult;
  }

  // Get the list of pending bookings for admin
  Future<List<Booking>> getPendingBookings() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'booking_status = ?',
      whereArgs: ['Pending'],
      orderBy: 'created_at DESC',
    );
    
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  // Get bookings with user details for admin
  Future<List<Map<String, dynamic>>> getBookingsWithUserDetails() async {
    Database db = await database;
    
    // Use a JOIN query to get booking and user information together
    const query = '''
      SELECT b.*, u.name as user_name, u.email as user_email, u.phone as user_phone
      FROM bookings b
      LEFT JOIN users u ON b.user_id = u.id
      ORDER BY b.created_at DESC
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query);
    return results;
  }

  // Get bookings with user and bus details for admin
  Future<List<Map<String, dynamic>>> getCompleteBookingDetails() async {
    Database db = await database;
    
    // Use a JOIN query to get booking, user, and bus information together
    const query = '''
      SELECT 
        b.*, 
        u.name as user_name, 
        u.email as user_email, 
        u.phone as user_phone,
        bs.name as bus_name,
        bs.departure_time,
        bs.arrival_time
      FROM bookings b
      LEFT JOIN users u ON b.user_id = u.id
      LEFT JOIN buses bs ON b.bus_id = bs.id
      ORDER BY b.created_at DESC
    ''';
    
    final List<Map<String, dynamic>> results = await db.rawQuery(query);
    return results;
  }

  Future<List<Map<String, dynamic>>> getAllUsersWithStatus() async {
    await _ensureUserStatusColumn();
    final db = await database;
    
    return await db.query('users');
  }

  Future<User?> getUserByEmail(String email) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateUser(User user) async {
    final db = await database;
    try {
      await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
      debugPrint('Updated user ${user.name} (ID: ${user.id})');
    } catch (e) {
      debugPrint('Error updating user: $e');
      throw e;
    }
  }

  Future<void> _ensureUserStatusColumn() async {
    final db = await database;
    
    try {
      // Check if the is_active column exists in users table
      var tableInfo = await db.rawQuery("PRAGMA table_info(users)");
      bool hasColumn = tableInfo.any(
        (column) => column['name'] == 'is_active',
      );

      if (!hasColumn) {
        // Add the is_active column with default value 1 (true/active)
        await db.execute("ALTER TABLE users ADD COLUMN is_active INTEGER DEFAULT 1");
        debugPrint("Added is_active column to users table");
      }
    } catch (e) {
      debugPrint("Error ensuring user status column: $e");
    }
  }

  Future<List<User>> getAllUsers() async {
    await _ensureUserStatusColumn();
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('users');
    
    return List.generate(maps.length, (i) {
      User user = User.fromMap(maps[i]);
      // You could add the status to the User model if needed
      return user;
    });
  }

  // Bus CRUD operations with route information
  Future<int> insertBus(Bus bus) async {
    Database db = await database;
    return await db.insert('buses', {
      'id': bus.id,
      'name': bus.name,
      'departure_time': bus.departureTime,
      'arrival_time': bus.arrivalTime,
      'duration': bus.duration,
      'price': bus.price,
      'available_seats': bus.availableSeats,
      'bus_type': bus.busType,
      'features': bus.features.join(','),
      'from_location': bus.fromLocation,
      'to_location': bus.toLocation,
    });
  }

  Future<int> updateBus(Bus bus) async {
    Database db = await database;
    return await db.update(
      'buses',
      {
        'name': bus.name,
        'departure_time': bus.departureTime,
        'arrival_time': bus.arrivalTime,
        'duration': bus.duration,
        'price': bus.price,
        'available_seats': bus.availableSeats,
        'bus_type': bus.busType,
        'features': bus.features.join(','),
        'from_location': bus.fromLocation,
        'to_location': bus.toLocation,
      },
      where: 'id = ?',
      whereArgs: [bus.id],
    );
  }

  Future<int> deleteBus(String id) async {
    Database db = await database;
    return await db.delete('buses', where: 'id = ?', whereArgs: [id]);
  }

  Future<Bus?> getBus(String id) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'buses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Bus(
        id: maps.first['id'],
        name: maps.first['name'],
        departureTime: maps.first['departure_time'],
        arrivalTime: maps.first['arrival_time'],
        duration: maps.first['duration'],
        price: maps.first['price'],
        availableSeats: maps.first['available_seats'],
        busType: maps.first['bus_type'],
        features: maps.first['features'].split(','),
        fromLocation: maps.first['from_location'] ?? 'Kigali',
        toLocation: maps.first['to_location'] ?? 'Butare',
      );
    }
    return null;
  }

  Future<List<Bus>> getAllBuses() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('buses');
    return List.generate(maps.length, (i) {
      return Bus(
        id: maps[i]['id'],
        name: maps[i]['name'],
        departureTime: maps[i]['departure_time'],
        arrivalTime: maps[i]['arrival_time'],
        duration: maps[i]['duration'],
        price: maps[i]['price'],
        availableSeats: maps[i]['available_seats'],
        busType: maps[i]['bus_type'],
        features: maps[i]['features'].split(','),
        fromLocation: maps[i]['from_location'] ?? 'Kigali',
        toLocation: maps[i]['to_location'] ?? 'Butare',
      );
    });
  }

  // New method to get buses by route
  Future<List<Bus>> getBusesByRoute(String from, String to) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'buses',
      where: 'from_location = ? AND to_location = ?',
      whereArgs: [from, to],
    );
    return List.generate(maps.length, (i) {
      return Bus(
        id: maps[i]['id'],
        name: maps[i]['name'],
        departureTime: maps[i]['departure_time'],
        arrivalTime: maps[i]['arrival_time'],
        duration: maps[i]['duration'],
        price: maps[i]['price'],
        availableSeats: maps[i]['available_seats'],
        busType: maps[i]['bus_type'],
        features: maps[i]['features'].split(','),
        fromLocation: maps[i]['from_location'] ?? from,
        toLocation: maps[i]['to_location'] ?? to,
      );
    });
  }

  // Booking CRUD operations
  Future<int> insertBooking(Booking booking) async {
    Database db = await database;

    // Create a map from the booking data
    Map<String, dynamic> bookingMap = booking.toMap();

    // Make sure created_at is set
    if (bookingMap['created_at'] == null) {
      bookingMap['created_at'] = DateTime.now().toIso8601String();
    }

    return await db.insert('bookings', bookingMap);
  }

  Future<User?> getUserById(int userId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (maps.isNotEmpty) {
        debugPrint('Found user with ID $userId: ${maps.first['name']}');
        return User.fromMap(maps.first);
      }
      debugPrint('No user found with ID $userId');
      return null;
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  Future<int> updateBookingStatus(String id, String status) async {
    Database db = await database;
    return await db.update(
      'bookings',
      {'booking_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updatePaymentStatus(String id, String status) async {
    Database db = await database;
    return await db.update(
      'bookings',
      {'payment_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Booking>> getUserBookings(int userId) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  Future<List<Booking>> getAllBookings() async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query('bookings');
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  // Get bookings for a specific route
  Future<List<Booking>> getBookingsByRoute(String from, String to) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'from_location = ? AND to_location = ?',
      whereArgs: [from, to],
    );
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  // Notification operations
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    return await db.insert('notifications', notification);
  }

  Future<List<Map<String, dynamic>>> getNotifications(String recipient) async {
    final db = await database;
    return await db.query(
      'notifications',
      where: 'recipient = ?',
      whereArgs: [recipient],
      orderBy: 'time DESC',
    );
  }

  Future<int> getUnreadNotificationsCount(String recipient) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE recipient = ? AND isRead = 0',
      [recipient],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsAsRead(String recipient) async {
    final db = await database;
    await db.update(
      'notifications',
      {'isRead': 1},
      where: 'recipient = ?',
      whereArgs: [recipient],
    );
  }

  Future<void> deleteNotification(int notificationId) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  // Additional utility methods

  // Get booking count by status
  Future<int> getBookingCountByStatus(String status) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM bookings WHERE booking_status = ?',
      [status],
    );
    return result.first['count'];
  }

  // Get total revenue
  Future<double> getTotalRevenue() async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM bookings WHERE payment_status = ?',
      ['Confirmed'],
    );
    return result.first['total'] ?? 0.0;
  }

  // Get revenue by date range
  Future<double> getRevenueByDateRange(String startDate, String endDate) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM bookings WHERE payment_status = ? AND created_at BETWEEN ? AND ?',
      ['Confirmed', startDate, endDate],
    );
    return result.first['total'] ?? 0.0;
  }

  // Get revenue by route
  Future<double> getRevenueByRoute(String from, String to) async {
    Database db = await database;
    List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT SUM(total_amount) as total FROM bookings WHERE payment_status = ? AND from_location = ? AND to_location = ?',
      ['Confirmed', from, to],
    );
    return result.first['total'] ?? 0.0;
  }

  // Get bookings by date
  Future<List<Booking>> getBookingsByDate(String date) async {
    Database db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'bookings',
      where: 'travel_date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) {
      return Booking.fromMap(maps[i]);
    });
  }

  // Get available routes (distinct from-to combinations)
  Future<List<Map<String, String>>> getAvailableRoutes() async {
    Database db = await database;
    List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT DISTINCT from_location, to_location FROM buses',
    );

    return results
        .map(
          (map) => {
            'from': map['from_location'] as String,
            'to': map['to_location'] as String,
          },
        )
        .toList();
  }

  // Delete all data (for testing purposes)
  Future<void> deleteAllData() async {
    Database db = await database;
    await db.delete('bookings');
    await db.delete('buses');
    await db.delete('notifications');
    await db.delete('users');
  }

  // Create locations table if it doesn't exist
  Future<void> _createLocationsTableIfNeeded() async {
    final db = await database;

    try {
      // Check if the locations table exists
      var tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='locations'",
      );
      if (tables.isEmpty) {
        // Create the locations table
        await db.execute('''
          CREATE TABLE locations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        debugPrint("Created locations table");

        // Insert default locations
        List<String> defaultLocations = [
          'Kigali',
          'Butare',
          'Gisenyi',
          'Ruhengeri',
          'Cyangugu',
          'Kibungo',
          'Gitarama',
          'Byumba',
          'Huye',
          'Musanze',
        ];

        for (var location in defaultLocations) {
          await db.insert('locations', {'name': location});
        }

        debugPrint("Inserted default locations");
      }
    } catch (e) {
      debugPrint("Error creating locations table: $e");
    }
  }

  // Save a new location to the database
  Future<int> saveLocation(String locationName) async {
    await _createLocationsTableIfNeeded();
    final db = await database;

    try {
      return await db.insert(
        'locations',
        {'name': locationName},
        conflictAlgorithm:
            ConflictAlgorithm.ignore, // Skip if location already exists
      );
    } catch (e) {
      debugPrint("Error saving location: $e");
      return -1;
    }
  }

  // Delete a location from the database
  Future<int> deleteLocation(String locationName) async {
    await _createLocationsTableIfNeeded();
    final db = await database;

    try {
      return await db.delete(
        'locations',
        where: 'name = ?',
        whereArgs: [locationName],
      );
    } catch (e) {
      debugPrint("Error deleting location: $e");
      return -1;
    }
  }

  // Get all unique locations from both the locations table and buses table
  Future<List<String>> getAllUniqueLocations() async {
    await _createLocationsTableIfNeeded();
    Database db = await database;

    // Get locations from the locations table
    List<Map<String, dynamic>> locationResults = await db.query('locations');
    Set<String> uniqueLocations =
        locationResults.map((map) => map['name'] as String).toSet();

    // Also get locations from buses table to ensure we don't miss any
    // Query distinct from_location values
    List<Map<String, dynamic>> fromResults = await db.rawQuery(
      'SELECT DISTINCT from_location FROM buses WHERE from_location IS NOT NULL',
    );

    // Query distinct to_location values
    List<Map<String, dynamic>> toResults = await db.rawQuery(
      'SELECT DISTINCT to_location FROM buses WHERE to_location IS NOT NULL',
    );

    // Add bus locations to our set
    for (var result in fromResults) {
      final location = result['from_location'] as String;
      if (location.isNotEmpty) {
        uniqueLocations.add(location);
      }
    }

    for (var result in toResults) {
      final location = result['to_location'] as String;
      if (location.isNotEmpty) {
        uniqueLocations.add(location);
      }
    }

    // Convert to list and sort alphabetically
    List<String> locationList = uniqueLocations.toList()..sort();

    // If list is empty, return default locations
    if (locationList.isEmpty) {
      return [
        'Kigali',
        'Butare',
        'Gisenyi',
        'Ruhengeri',
        'Cyangugu',
        'Kibungo',
        'Gitarama',
        'Byumba',
        'Huye',
        'Musanze',
      ];
    }

    return locationList;
  }

  // Add method to check if user is admin
  Future<bool> isAdminUser(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ? AND is_admin = 1',
      whereArgs: [userId],
    );
    return result.isNotEmpty;
  }

  // Add method to check if user is the default admin
  Future<bool> isDefaultAdmin(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      where: 'id = ? AND is_default_admin = 1',
      whereArgs: [userId],
    );
    return result.isNotEmpty;
  }
}
