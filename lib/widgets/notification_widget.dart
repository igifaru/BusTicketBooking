// lib/widgets/notification_widget.dart
import 'package:flutter/material.dart';
import 'package:tickiting/services/notification_service.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart';

class NotificationIcon extends StatefulWidget {
  final String recipient;
  final int? userId;

  const NotificationIcon({super.key, required this.recipient, this.userId});

  @override
  NotificationIconState createState() => NotificationIconState();
}

class NotificationIconState extends State<NotificationIcon> {
  final NotificationService _notificationService = NotificationService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();

    // Initialize notification service
    _notificationService.initialize();

    // Listen for new notifications
    _notificationService.notificationStream.listen((notification) {
      if (notification.recipient == widget.recipient &&
          (widget.userId == null || notification.userId == widget.userId)) {
        _loadUnreadCount();
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount(
      recipient: widget.recipient,
      userId: widget.userId,
    );

    setState(() {
      _unreadCount = count;
    });
  }

  void _showNotificationsDialog() async {
    final notifications = await _notificationService.getNotifications(
      recipient: widget.recipient,
      userId: widget.userId,
    );

    if (!mounted) return;

    // Process notifications to fix any remaining "Admin User" text
    await _updateNotificationsWithAdminUser(notifications);

    // Continue with showing the dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            const Text('Notifications'),
            const Spacer(),
            if (_unreadCount > 0)
              TextButton(
                onPressed: () async {
                  await _notificationService.markAllAsRead(
                    recipient: widget.recipient,
                    userId: widget.userId,
                  );
                  _loadUnreadCount();
                  Navigator.pop(context);
                },
                child: const Text('Mark all as read'),
              ),
            // Add a button to clear all Admin User notifications if needed
            TextButton(
              onPressed: () async {
                // First try to fix any remaining Admin User notifications
                await _databaseHelper.replaceAdminUserInAllNotifications();
                // If any still remain, clear them
                await _databaseHelper.clearAdminUserNotifications();
                _loadUnreadCount();
                Navigator.pop(context);
              },
              child: const Text('Fix & Clear Invalid'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: notifications.isEmpty
            ? const Center(child: Text('No notifications'))
            : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  // Use the potentially updated message here
                  return Card(
                    color: notification.isRead ? null : Colors.blue[50],
                    child: ListTile(
                      leading: Icon(
                        _getIconForType(notification.type),
                        color: _getColorForType(notification.type),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(notification.message),
                          Text(
                            _formatTime(notification.time),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Add an edit button to manually fix notifications if needed
                          if (notification.message.contains("Admin User"))
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.orange,
                              ),
                              onPressed: () async {
                                // Show dialog to manually fix the notification
                                _showEditNotificationDialog(
                                  context,
                                  notification,
                                );
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              await _notificationService
                                  .deleteNotification(notification.id);
                              _loadUnreadCount();
                              // Reload the list
                              if (mounted) {
                                Navigator.pop(context);
                                _showNotificationsDialog();
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (!notification.isRead) {
                          await _notificationService.markAsRead(
                            notification.id,
                          );
                          _loadUnreadCount();
                          // Reload the list
                          if (mounted) {
                            Navigator.pop(context);
                            _showNotificationsDialog();
                          }
                        }
                      },
                    ),
                  );
                },
              ),
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

  // New method to check and update "Admin User" before displaying
  Future<void> _updateNotificationsWithAdminUser(List<NotificationModel> notifications) async {
    bool needsRefresh = false;
    
    for (var notification in notifications) {
      if (notification.message.contains("Admin User")) {
        // Try to get user information
        if (notification.userId != null) {
          try {
            final user = await _databaseHelper.getUserById(notification.userId!);
            if (user != null && user.name.isNotEmpty && user.name != "Admin User") {
              final updatedMessage = notification.message.replaceAll(
                "Admin User",
                user.name,
              );
              
              // Update in database
              await _notificationService.updateNotificationMessage(
                notification.id,
                updatedMessage,
              );
              
              // Update in memory
              notification.message = updatedMessage;
              needsRefresh = true;
            } 
            else {
              // Fallback to User #ID
              final updatedMessage = notification.message.replaceAll(
                "Admin User",
                "User #${notification.userId}",
              );
              
              await _notificationService.updateNotificationMessage(
                notification.id,
                updatedMessage,
              );
              
              notification.message = updatedMessage;
              needsRefresh = true;
            }
          } catch (e) {
            debugPrint("Error updating notification in widget: $e");
          }
        } 
        else {
          // If no user ID, use generic "Customer"
          final updatedMessage = notification.message.replaceAll(
            "Admin User",
            "Customer",
          );
          
          await _notificationService.updateNotificationMessage(
            notification.id,
            updatedMessage,
          );
          
          notification.message = updatedMessage;
          needsRefresh = true;
        }
      }
    }
    
    // Force UI refresh if needed
    if (needsRefresh && mounted) {
      setState(() {});
    }
  }

  void _showEditNotificationDialog(
    BuildContext context,
    NotificationModel notification,
  ) {
    final TextEditingController controller = TextEditingController(
      text: notification.message,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notification'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Edit notification message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Update the notification
              await _notificationService.updateNotificationMessage(
                notification.id,
                controller.text,
              );

              // Close both dialogs
              Navigator.pop(context);
              Navigator.pop(context);

              // Reopen the notifications dialog with updated content
              _showNotificationsDialog();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'booking':
      case 'booking_confirmation':
      case 'booking_status':
        return Icons.confirmation_number;
      case 'payment':
      case 'payment_confirmation':
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
      case 'payment_confirmation':
        return Colors.purple;
      case 'user':
        return Colors.blue;
      case 'booking_status':
        return Colors.orange;
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: _showNotificationsDialog,
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
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}