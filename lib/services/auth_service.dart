// lib/services/auth_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:tickiting/models/user.dart';
import 'package:tickiting/utils/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';


// This is a true singleton implementation to ensure the same instance is used everywhere
class AuthService {
  // Private static instance - the only instance of AuthService
  static final AuthService _instance = AuthService._internal();

  // Factory constructor that returns the singleton instance
  factory AuthService() {
    return _instance;
  }

  // Private constructor
  AuthService._internal() {
    debugPrint('AuthService singleton created');
    // Initialize by loading the user session immediately
    _initializeService();
  }

  // Database helper
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Current user cache
  User? _currentUser;

  // Stream controller for auth state changes - allows components to listen for changes
  final _authStateController = StreamController<User?>.broadcast();

  // Auth state stream that components can listen to
  Stream<User?> get authStateChanges => _authStateController.stream;

  // Cached user for better performance
  User? get currentUser => _currentUser;

  // Initialize the service
  Future<void> _initializeService() async {
    debugPrint('Initializing AuthService...');
    await loadUserSession();
  }

  // Log in user and store session
  Future<User?> login(String email, String password) async {
    try {
      debugPrint('🔐 Attempting login for email: $email');
      final user = await _databaseHelper.getUser(email, password);

      if (user != null) {
        // Don't allow login as default admin
        if (await _databaseHelper.isDefaultAdmin(user.id!)) {
          debugPrint('❌ Blocked attempt to login as default admin');
          return null;
        }

        // Save to shared prefs for persistence
        await _saveUserSession(user.id.toString());

        // Update current user and notify listeners
        _currentUser = user;
        _authStateController.add(user);

        debugPrint('✅ Login successful: ${user.name} (ID: ${user.id})');
        return user;
      }

      debugPrint('❌ Login failed: Invalid credentials');
      return null;
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return null;
    }
  }

  // Load user session on app start with improved direct query approach
  Future<void> loadUserSession() async {
    try {
      debugPrint('🔄 Loading user session...');
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId != null && userId.isNotEmpty) {
        debugPrint('🔍 Found saved user session for ID: $userId');

        try {
          // Attempt to load user directly from database
          final user = await _databaseHelper.getUserById(int.parse(userId));

          if (user != null) {
            debugPrint(
              '✅ Successfully loaded user: ${user.name} (ID: ${user.id})',
            );
            _currentUser = user;
            _authStateController.add(user);
          } else {
            debugPrint(
              '⚠️ User ID $userId exists in prefs but not found in database',
            );
            // Clear invalid session
            await prefs.remove('userId');
            _currentUser = null;
            _authStateController.add(null);
          }
        } catch (e) {
          debugPrint('❌ Error loading user by ID: $e');
          _currentUser = null;
          _authStateController.add(null);
        }
      } else {
        debugPrint('ℹ️ No saved user session found');
        _currentUser = null;
        _authStateController.add(null);
      }
    } catch (e) {
      debugPrint('❌ Error loading user session: $e');
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  // Register new user
  Future<bool> register(User user) async {
    try {
      debugPrint('🔄 Registering new user: ${user.name}');
      final userId = await _databaseHelper.insertUser(user);

      if (userId > 0) {
        // Get the complete user object with the assigned ID
        user = User(
          id: userId,
          name: user.name,
          email: user.email,
          password: user.password,
          phone: user.phone,
          gender: user.gender,
        );

        // Save session
        await _saveUserSession(userId.toString());

        // Update current user and notify listeners
        _currentUser = user;
        _authStateController.add(user);

        debugPrint('✅ Registration successful: ${user.name} (ID: $userId)');
        return true;
      }

      debugPrint('❌ Registration failed');
      return false;
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      return false;
    }
  }

  // Log out user and clear session
  Future<bool> logout() async {
    try {
      debugPrint('🔄 Logging out user: ${_currentUser?.name}');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userId');

      // Update current user and notify listeners
      _currentUser = null;
      _authStateController.add(null);

      debugPrint('✅ Logout successful');
      return true;
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      return false;
    }
  }

  // Get current logged in user with direct database approach
  Future<User?> getCurrentUser() async {
    debugPrint('🔍 Getting current user...');

    if (_currentUser != null) {
      // Don't return if it's the default admin
      if (_currentUser!.isDefaultAdmin) {
        debugPrint('⚠️ Preventing return of default admin user');
        return null;
      }
      debugPrint('✅ Returning cached user: ${_currentUser!.name} (ID: ${_currentUser!.id})');
      return _currentUser;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId != null) {
        final user = await _databaseHelper.getUserById(int.parse(userId));
        if (user != null && !user.isDefaultAdmin) {
          _currentUser = user;
          debugPrint('✅ Loaded user from storage: ${user.name} (ID: ${user.id})');
          return user;
        }
      }
      debugPrint('ℹ️ No valid user found');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      return null;
    }
  }

  // Direct database lookup for a user by ID - bypasses cache
  Future<User?> getUserDirectly(String userId) async {
    try {
      debugPrint('🔍 Directly looking up user with ID: $userId');
      final user = await _databaseHelper.getUserById(int.parse(userId));

      if (user != null) {
        debugPrint('✅ Found user directly: ${user.name} (ID: ${user.id})');
        return user;
      } else {
        debugPrint('⚠️ No user found with ID: $userId');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error in direct user lookup: $e');
      return null;
    }
  }

  // Save user session to shared preferences
  Future<void> _saveUserSession(String userId) async {
    try {
      debugPrint('💾 Saving user session for ID: $userId');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);

      // Verify the save worked
      final savedId = prefs.getString('userId');
      if (savedId == userId) {
        debugPrint('✅ User session saved successfully (verified)');
      } else {
        debugPrint(
          '⚠️ Session verification failed. Expected: $userId, Got: $savedId',
        );
      }
    } catch (e) {
      debugPrint('❌ Save session error: $e');
      throw Exception('Failed to save user session: $e');
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    try {
      // First check the cache
      if (_currentUser != null) {
        debugPrint('✅ User is logged in (cached): ${_currentUser!.name}');
        return true;
      }

      // Then try to load the user
      await loadUserSession();

      final isLoggedIn = _currentUser != null;
      debugPrint('ℹ️ User is logged in: $isLoggedIn');

      return isLoggedIn;
    } catch (e) {
      debugPrint('❌ Check login status error: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile(User user) async {
    try {
      debugPrint('🔄 Updating profile for user: ${user.name} (ID: ${user.id})');
      final result = await _databaseHelper.updateUser(user);

      if (result > 0) {
        // Update current user and notify listeners
        _currentUser = user;
        _authStateController.add(user);

        debugPrint('✅ Profile updated successfully');
        return true;
      }

      debugPrint('❌ Profile update failed');
      return false;
    } catch (e) {
      debugPrint('❌ Update profile error: $e');
      return false;
    }
  }

  // Force refresh the current user from database
  Future<User?> forceRefreshUser() async {
    try {
      debugPrint('🔄 Force refreshing current user');

      // Clear cache first
      _currentUser = null;

      // Reload from storage
      await loadUserSession();

      if (_currentUser != null) {
        debugPrint(
          '✅ Force refreshed user: ${_currentUser!.name} (ID: ${_currentUser!.id})',
        );
      } else {
        debugPrint('⚠️ No user found after force refresh');
      }

      return _currentUser;
    } catch (e) {
      debugPrint('❌ Force refresh user error: $e');
      return null;
    }
  }

  // Manual session repair
  Future<bool> repairSession(String userId) async {
    try {
      debugPrint('🔧 Attempting to repair session for user ID: $userId');

      // First validate user exists
      final user = await getUserDirectly(userId);

      if (user != null) {
        // Save valid session
        await _saveUserSession(userId);

        // Update current user and notify listeners
        _currentUser = user;
        _authStateController.add(user);

        debugPrint('✅ Session repaired for user: ${user.name} (ID: $userId)');
        return true;
      }

      debugPrint('❌ Cannot repair session: User not found for ID: $userId');
      return false;
    } catch (e) {
      debugPrint('❌ Session repair error: $e');
      return false;
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    _authStateController.close();
  }
}
