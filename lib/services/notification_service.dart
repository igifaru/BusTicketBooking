// lib/utils/database_helper.dart

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:tickiting/utils/database_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:tickiting/models/notification_model.dart';
import 'package:tickiting/services/notification_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper.internal();
  factory DatabaseHelper() => _instance;

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  DatabaseHelper.internal();

  initDb() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'ticketing.db');

    var db = await openDatabase(path, version: 1, onCreate: _onCreate);
    await _insertInitialData(db);
    return db;
  }

  void _onCreate(Database db, int newVersion) async {
    await db.execute('CREATE TABLE users('
        'id INTEGER PRIMARY KEY,'
        'name TEXT,'
        'email TEXT,'
        'password TEXT,'
        'phone TEXT,'
        'gender TEXT,'
        'is_admin INTEGER,'
        'created_at TEXT'
        ')');
  }

  Future<void> _insertInitialData(Database db) async {
    // Check if admin user already exists
    final adminExists = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: ['admin@rwandabus.com'],
    );

    if (adminExists.isEmpty) {
      // Only insert if admin doesn't exist
      await db.insert('users', {
        'name': 'System Administrator',
        'email': 'admin@rwandabus.com',
        'password': 'admin123',
        'phone': '+250 789 123 456',
        'gender': 'Male',
      });
    }
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
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _notificationController = StreamController<NotificationModel>.broadcast();

  NotificationService._internal();

  Stream<NotificationModel> get notificationStream => _notificationController.stream;

  Future<void> initialize() async {
    debugPrint('NotificationService initialized');
  }

  Future<List<NotificationModel>> getNotifications({
    String? recipient,
    int? userId,
  }) async {
    final notifications = await _databaseHelper.getNotifications(
      recipient: recipient,
      userId: userId,
    );

    return notifications.map((map) => NotificationModel(
      id: map['id'],
      title: map['title'],
      message: map['message'],
      time: DateTime.parse(map['time']),
      isRead: map['isRead'] == 1,
      type: map['type'],
      recipient: map['recipient'],
      userId: map['userId'],
      created_at: map['created_at'],
    )).toList();
  }

  Future<int> getUnreadCount({String? recipient, int? userId}) async {
    return await _databaseHelper.getUnreadNotificationsCount(
      recipient: recipient,
      userId: userId,
    );
  }

  Future<void> markAsRead(int notificationId) async {
    await _databaseHelper.markNotificationAsRead(notificationId);
  }

  Future<void> markAllAsRead({String? recipient, int? userId}) async {
    await _databaseHelper.markAllNotificationsAsRead(
      recipient: recipient,
      userId: userId,
    );
  }

  Future<void> deleteNotification(int notificationId) async {
    await _databaseHelper.deleteNotification(notificationId);
  }

  Future<void> updateNotificationMessage(
    int notificationId,
    String newMessage,
  ) async {
    await _databaseHelper.updateNotificationMessage(notificationId, newMessage);
  }

  void dispose() {
    _notificationController.close();
  }

  Future<void> createBookingNotificationForAdmin(
    String userId,
    String userName,
    String origin,
    String destination,
  ) async {
    try {
      final notification = await _databaseHelper.insertNotification({
        'title': 'New Booking',
        'message': '$userName booked a ticket from $origin to $destination',
    'time': DateTime.now().toIso8601String(),
    'isRead': 0,
        'type': 'booking',
        'recipient': 'admin',
    'userId': userId,
      });

      if (notification > 0) {
        _notificationController.add(NotificationModel(
          id: notification,
          title: 'New Booking',
          message: '$userName booked a ticket from $origin to $destination',
    time: DateTime.now(),
      type: 'booking',
      recipient: 'admin',
          userId: int.parse(userId),
        ));
      }
  } catch (e) {
    debugPrint('Error creating admin notification: $e');
    }
  }
}
