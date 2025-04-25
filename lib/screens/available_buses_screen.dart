// lib/screens/available_buses_screen.dart
import 'package:flutter/material.dart';
import 'package:tickiting/models/bus.dart';
import 'package:tickiting/screens/payment_screen.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart';

class AvailableBusesScreen extends StatefulWidget {
  final String from;
  final String to;
  final DateTime date;
  final int passengers;

  const AvailableBusesScreen({
    super.key,
    required this.from,
    required this.to,
    required this.date,
    required this.passengers,
  });

  @override
  _AvailableBusesScreenState createState() => _AvailableBusesScreenState();
}

class _AvailableBusesScreenState extends State<AvailableBusesScreen> {
  List<Bus> _allBuses = [];
  List<Bus> _displayedBuses = [];
  bool _isLoading = true;
  String _sortBy = 'Departure Time'; // Default sort

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load buses that match the requested route - using positional parameters
      List<Bus> buses = await DatabaseHelper().getBusesByRoute(
        widget.from,
        widget.to,
      );

      if (buses.isEmpty) {
        // If no exact matches, show all buses as a fallback
        buses = await DatabaseHelper().getAllBuses();

        // Show a message to the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No buses found for ${widget.from} to ${widget.to}. Showing all available buses.',
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      setState(() {
        _allBuses = buses;
        _applySorting(); // Apply initial sorting
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading buses: $e');
      setState(() {
        _isLoading = false;
        _allBuses = [];
        _displayedBuses = [];
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading buses: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Calculate actual duration based on departure and arrival times
  String calculateDuration(String departureTime, String arrivalTime) {
    try {
      // Parse the times
      DateTime departure = _parseTimeString(departureTime);
      DateTime arrival = _parseTimeString(arrivalTime);

      // If arrival appears to be before departure, assume it's the next day
      if (arrival.isBefore(departure)) {
        arrival = arrival.add(const Duration(days: 1));
      }

      // Calculate the difference
      Duration difference = arrival.difference(departure);

      // Format as "Xh Ym"
      int hours = difference.inHours;
      int minutes = difference.inMinutes.remainder(60);

      if (hours > 0 && minutes > 0) {
        return "${hours}h ${minutes}m";
      } else if (hours > 0) {
        return "${hours}h";
      } else {
        return "${minutes}m";
      }
    } catch (e) {
      debugPrint('Error calculating duration: $e');
      return "Unknown";
    }
  }

  // Helper method to parse time strings
  DateTime _parseTimeString(String timeStr) {
    try {
      // Parse format like "08:00 AM" or "12:00 PM"
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);

      // Convert to 24-hour format
      if (parts.length > 1) {
        if (parts[1] == 'PM' && hour != 12) {
          hour += 12;
        } else if (parts[1] == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      return DateTime(2023, 1, 1, hour, minute);
    } catch (e) {
      debugPrint('Error parsing time string: $e');
      return DateTime.now(); // Return current time as fallback
    }
  }

  // Apply sorting based on selected criteria
  void _applySorting() {
    // Create a copy of the original list to avoid modifying the source
    _displayedBuses = List.from(_allBuses);

    // Apply sorting based on selected option
    switch (_sortBy) {
      case 'Departure Time':
        _displayedBuses.sort((a, b) {
          return _compareTime(a.departureTime, b.departureTime);
        });
        break;

      case 'Price':
        _displayedBuses.sort((a, b) => a.price.compareTo(b.price));
        break;

      case 'Duration':
        _displayedBuses.sort((a, b) {
          // Compare calculated durations instead of stored ones
          String durationA = calculateDuration(a.departureTime, a.arrivalTime);
          String durationB = calculateDuration(b.departureTime, b.arrivalTime);
          return _compareDuration(durationA, durationB);
        });
        break;

      case 'Available Seats':
        _displayedBuses.sort(
          (a, b) => b.availableSeats.compareTo(a.availableSeats),
        );
        break;
    }

    // Force UI update
    setState(() {});
  }

  // Helper method to compare time strings (e.g., "08:00 AM" vs "09:30 AM")
  int _compareTime(String time1, String time2) {
    try {
      DateTime t1 = _parseTimeString(time1);
      DateTime t2 = _parseTimeString(time2);
      return t1.compareTo(t2);
    } catch (e) {
      debugPrint('Error comparing times: $e');
      return 0; // Return equal if comparison fails
    }
  }

  // Helper method to compare duration strings (e.g., "2h 30m")
  int _compareDuration(String duration1, String duration2) {
    try {
      // Extract hours and minutes
      int hours1 = 0, minutes1 = 0, hours2 = 0, minutes2 = 0;

      // Parse first duration
      if (duration1.contains('h')) {
        hours1 = int.parse(duration1.split('h')[0].trim());
        if (duration1.contains('m')) {
          minutes1 = int.parse(duration1.split('h')[1].split('m')[0].trim());
        }
      } else if (duration1.contains('m')) {
        minutes1 = int.parse(duration1.split('m')[0].trim());
      }

      // Parse second duration
      if (duration2.contains('h')) {
        hours2 = int.parse(duration2.split('h')[0].trim());
        if (duration2.contains('m')) {
          minutes2 = int.parse(duration2.split('h')[1].split('m')[0].trim());
        }
      } else if (duration2.contains('m')) {
        minutes2 = int.parse(duration2.split('m')[0].trim());
      }

      // Convert to total minutes and compare
      int totalMinutes1 = hours1 * 60 + minutes1;
      int totalMinutes2 = hours2 * 60 + minutes2;

      return totalMinutes1.compareTo(totalMinutes2);
    } catch (e) {
      debugPrint('Error comparing durations: $e');
      return 0; // Return equal if comparison fails
    }
  }

  void _handleSortChange(String sortOption) {
    if (_sortBy != sortOption) {
      setState(() {
        _sortBy = sortOption;
        _applySorting();
      });

      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorted by $sortOption'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () => _handleSortChange(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Chip(
          label: Text(label),
          backgroundColor:
              isSelected ? AppTheme.primaryColor : Colors.grey[200],
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildBusCard(BuildContext context, Bus bus) {
    // Calculate actual duration instead of using the stored one
    String actualDuration = calculateDuration(
      bus.departureTime,
      bus.arrivalTime,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            // Bus name and type
            Row(
              children: [
                Expanded(
                  child: Text(
                    bus.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        bus.busType == 'Premium'
                            ? Colors.amber[100]
                            : bus.busType == 'Standard'
                            ? Colors.blue[100]
                            : Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bus.busType,
                    style: TextStyle(
                      color:
                          bus.busType == 'Premium'
                              ? Colors.amber[800]
                              : bus.busType == 'Standard'
                              ? Colors.blue[800]
                              : Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Show route information
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route, size: 16, color: Colors.blue[800]),
                  const SizedBox(width: 5),
                  Text(
                    '${bus.fromLocation} to ${bus.toLocation}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            // Time and duration
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.departureTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        bus.fromLocation,
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        actualDuration, // Use calculated duration instead of bus.duration
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 5),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(height: 2, color: Colors.grey[300]),
                          const Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bus.arrivalTime,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        bus.toLocation,
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            // Features
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    bus.features
                        .map(
                          (feature) => Chip(
                            label: Text(feature),
                            backgroundColor: Colors.grey[200],
                            labelStyle: const TextStyle(fontSize: 12),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 15),
            // Price and book button
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price per person',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      '${bus.price.toStringAsFixed(0)} RWF',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${bus.availableSeats} ${bus.availableSeats == 1 ? 'seat' : 'seats'} left',
                  style: TextStyle(
                    color:
                        bus.availableSeats < 5 ? Colors.red : Colors.grey[600],
                    fontWeight:
                        bus.availableSeats < 5
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed:
                      bus.availableSeats >= widget.passengers
                          ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => PaymentScreen(
                                      bus: bus,
                                      from: widget.from,
                                      to: widget.to,
                                      date: widget.date,
                                      passengers: widget.passengers,
                                    ),
                              ),
                            );
                          }
                          : null, // Disable button if not enough seats
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text('Book Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Buses'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Column(
        children: [
          // Trip details summary
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.from} to ${widget.to}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${widget.date.day}/${widget.date.month}/${widget.date.year} • ${widget.passengers} ${widget.passengers > 1 ? 'Passengers' : 'Passenger'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Modify'),
                ),
              ],
            ),
          ),
          // Filter options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                const Text('Sort by:'),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'Departure Time',
                          _sortBy == 'Departure Time',
                        ),
                        _buildFilterChip('Price', _sortBy == 'Price'),
                        _buildFilterChip('Duration', _sortBy == 'Duration'),
                        _buildFilterChip(
                          'Available Seats',
                          _sortBy == 'Available Seats',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bus list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _displayedBuses.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_bus_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No buses available for this route',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadBuses,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadBuses,
                      child: ListView.builder(
                        itemCount: _displayedBuses.length,
                        itemBuilder: (context, index) {
                          final bus = _displayedBuses[index];
                          return _buildBusCard(context, bus);
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
