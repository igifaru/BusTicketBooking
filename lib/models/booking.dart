// lib/models/booking.dart
class Booking {
  final String id;
  final int userId;
  final int busId;
  final String fromLocation;
  final String toLocation;
  final String travelDate;
  final int passengers;
  final String seatNumbers;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String bookingStatus;
  final bool notificationSent;
  final String createdAt;

  Booking({
    required this.id,
    required this.userId,
    required this.busId,
    required this.fromLocation,
    required this.toLocation,
    required this.travelDate,
    required this.passengers,
    required this.seatNumbers,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.notificationSent,
    required this.createdAt,
  });

  // Factory constructor to create a Booking from a Map
  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: map['id'] as String,
      userId: map['user_id'] as int,
      busId: map['bus_id'] as int,
      fromLocation: map['from_location'] as String,
      toLocation: map['to_location'] as String,
      travelDate: map['travel_date'] as String,
      passengers: map['passengers'] as int,
      seatNumbers: map['seat_numbers'] as String,
      totalAmount: map['total_amount'] as double,
      paymentMethod: map['payment_method'] as String,
      paymentStatus: map['payment_status'] as String,
      bookingStatus: map['booking_status'] as String,
      notificationSent: (map['notification_sent'] as int) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  // Convert a Booking to a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'bus_id': busId,
      'from_location': fromLocation,
      'to_location': toLocation,
      'travel_date': travelDate,
      'passengers': passengers,
      'seat_numbers': seatNumbers,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'booking_status': bookingStatus,
      'notification_sent': notificationSent ? 1 : 0,
      'created_at': createdAt,
    };
  }
}