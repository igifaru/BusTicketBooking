// lib/screens/admin/admin_users.dart
import 'package:flutter/material.dart';
import 'package:tickiting/models/user.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart';

class AdminUsers extends StatefulWidget {
  const AdminUsers({super.key});

  @override
  _AdminUsersState createState() => _AdminUsersState();
}

class _AdminUsersState extends State<AdminUsers> {
  List<User> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filterStatus = 'All';

  // Add a map to track active status
  Map<int, bool> _userActiveStatus = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all users from database
      final users = await DatabaseHelper().getAllUsers();

      // Initialize the active status map - by default all users are active
      Map<int, bool> userActiveStatus = {};
      for (var user in users) {
        if (user.id != null) {
          // Check if we already have a status for this user
          if (_userActiveStatus.containsKey(user.id)) {
            userActiveStatus[user.id!] = _userActiveStatus[user.id]!;
          } else {
            // Default to active for new users
            userActiveStatus[user.id!] = true;
          }
        }
      }

      setState(() {
        _users = users;
        _userActiveStatus = userActiveStatus;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to deactivate a user
  Future<void> _deactivateUser(User user) async {
    if (user.id == null) return;

    try {
      // In a real app, you would update a field in the database
      // For now, we'll just update our local state map
      setState(() {
        _userActiveStatus[user.id!] = false;
      });

      // Simulate database update - in a real app, update the user status in DB
      // Example: await DatabaseHelper().updateUserStatus(user.id!, false);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User deactivated successfully'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error deactivating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deactivating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method to activate a user
  Future<void> _activateUser(User user) async {
    if (user.id == null) return;

    try {
      // Update our local state
      setState(() {
        _userActiveStatus[user.id!] = true;
      });

      // Simulate database update - in a real app, update the user status in DB
      // Example: await DatabaseHelper().updateUserStatus(user.id!, true);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User activated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error activating user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error activating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter and search users based on active status and search query
    List<User> filteredUsers =
        _users
            .where((user) {
              // First check if user has an ID (valid user)
              if (user.id == null) return false;

              // Then filter by active status
              bool isActive = _userActiveStatus[user.id!] ?? true;

              return (_filterStatus == 'All') ||
                  (_filterStatus == 'Active' && isActive) ||
                  (_filterStatus == 'Inactive' && !isActive);
            })
            .where(
              (user) =>
                  user.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  user.email.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  user.phone.contains(_searchQuery),
            )
            .toList();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'User Management',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Search and filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _filterStatus,
                  onChanged: (value) {
                    setState(() {
                      _filterStatus = value!;
                    });
                  },
                  items:
                      ['All', 'Active', 'Inactive'].map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Users count
            Text(
              'Showing ${filteredUsers.length} users',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            // Users list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredUsers.isEmpty
                      ? const Center(child: Text('No users found'))
                      : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    // Get active status from our map
    bool isActive = _userActiveStatus[user.id!] ?? true;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(
                    user.name.toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Phone', style: TextStyle(color: Colors.grey)),
                      Text(
                        user.phone,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gender',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        user.gender,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Joined On',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        user.createdAt ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    // View user details
                    _showUserDetailsDialog(user);
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View'),
                ),
                const SizedBox(width: 10),
                isActive
                    ? OutlinedButton.icon(
                      onPressed: () {
                        // Deactivate user with confirmation dialog
                        _showDeactivateDialog(user);
                      },
                      icon: const Icon(Icons.block, color: Colors.red),
                      label: const Text(
                        'Deactivate',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                    )
                    : OutlinedButton.icon(
                      onPressed: () {
                        // Activate user with confirmation dialog
                        _showActivateDialog(user);
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      label: const Text(
                        'Activate',
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUserDetailsDialog(User user) {
    bool isActive = _userActiveStatus[user.id!] ?? true;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(user.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  'ID',
                  user.id != null ? '#${user.id}' : 'Not assigned',
                ),
                _buildDetailRow('Email', user.email),
                _buildDetailRow('Phone', user.phone),
                _buildDetailRow('Gender', user.gender),
                _buildDetailRow('Status', isActive ? 'Active' : 'Inactive'),
                _buildDetailRow('Joined On', user.createdAt ?? 'Unknown'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showDeactivateDialog(User user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Deactivate User'),
            content: Text(
              'Are you sure you want to deactivate ${user.name}? They will not be able to log in or book tickets.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Close the dialog
                  Navigator.pop(context);

                  // Perform the actual deactivation
                  await _deactivateUser(user);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Deactivate'),
              ),
            ],
          ),
    );
  }

  void _showActivateDialog(User user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Activate User'),
            content: Text('Are you sure you want to activate ${user.name}?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Close the dialog
                  Navigator.pop(context);

                  // Perform the actual activation
                  await _activateUser(user);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Activate'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
