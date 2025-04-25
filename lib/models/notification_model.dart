class NotificationModel {
  final int id;
  final String title;
  final String message;
  final DateTime time;
  bool isRead;
  final String type;
  final String recipient;
  final int? userId;
  final String? created_at;
  
  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
    required this.type,
    required this.recipient,
    this.userId,
    this.created_at,
  });
  
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
      'created_at': created_at ?? DateTime.now().toIso8601String(),
    };
  }
  
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
      created_at: map['created_at'],
    );
  }
} 