class Ticket {
  final String id;
  final String busName;
  final String from;
  final String to;
  final DateTime date;
  final String departureTime;
  final int passengers;
  final List<String> seatNumbers;
  final String status;
  final String qrCode;
  final String userName;
  final String userEmail;
  final String userPhone;
  final int userId; // Add this property

  Ticket({
    required this.id,
    required this.busName,
    required this.from,
    required this.to,
    required this.date,
    required this.departureTime,
    required this.passengers,
    required this.seatNumbers,
    required this.status,
    required this.qrCode,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.userId, // Initialize this property
  });
}
