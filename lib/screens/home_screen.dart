// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:tickiting/screens/available_buses_screen.dart';
import 'package:tickiting/screens/profile_screen.dart';
import 'package:tickiting/screens/ticket_screen.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart'; // Import DatabaseHelper

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> locations =
      []; // Empty list that will be populated from database
  bool _isLoading = true; // Track loading state

  String? _from;
  String? _to;
  DateTime _selectedDate = DateTime.now();
  int _numberOfPassengers = 1;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadLocations(); // Load locations when the screen initializes
  }

  // Load locations from database
  Future<void> _loadLocations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final loadedLocations = await DatabaseHelper().getAllUniqueLocations();
      setState(() {
        locations = loadedLocations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading locations: $e');
      // Load default locations if there's an error
      setState(() {
        locations = [
          'Kigali',
          'Butare',
          'Gisenyi',
          'Ruhengeri',
          'Cyangugu',
          'Kibungo',
          'Gitarama',
          'Byumba',
          'Musanze',
          'Nyagatare',
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _searchBuses() {
    if (_from == null || _to == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select both departure and destination locations',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_from == _to) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departure and destination cannot be the same'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AvailableBusesScreen(
              from: _from!,
              to: _to!,
              date: _selectedDate,
              passengers: _numberOfPassengers,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rwanda Bus Booking'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body:
          _currentIndex == 0
              ? _buildHomeContent()
              : _currentIndex == 1
              ? const TicketScreen()
              : const ProfileScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number),
            label: 'My Tickets',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://via.placeholder.com/400x200?text=Rwanda+Bus+Services',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // Search form
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Book Your Bus Ticket',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // From dropdown
                    DropdownButtonFormField<String>(
                      value: _from,
                      decoration: const InputDecoration(
                        labelText: 'From',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items:
                          locations
                              .map(
                                (location) => DropdownMenuItem(
                                  value: location,
                                  child: Text(location),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _from = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // To dropdown
                    DropdownButtonFormField<String>(
                      value: _to,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      items:
                          locations
                              .map(
                                (location) => DropdownMenuItem(
                                  value: location,
                                  child: Text(location),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          _to = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    // Date picker
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Travel Date',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Number of passengers
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Number of Passengers',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed:
                              _numberOfPassengers > 1
                                  ? () {
                                    setState(() {
                                      _numberOfPassengers--;
                                    });
                                  }
                                  : null,
                        ),
                        Text(
                          '$_numberOfPassengers',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed:
                              _numberOfPassengers < 10
                                  ? () {
                                    setState(() {
                                      _numberOfPassengers++;
                                    });
                                  }
                                  : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    // Search button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _searchBuses,
                        child: const Text('Search Buse'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Popular routes
              const Text(
                'Popular Routes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildPopularRouteCard('Kigali', 'Butare', '5,000 RWF'),
                    _buildPopularRouteCard('Kigali', 'Gisenyi', '6,500 RWF'),
                    _buildPopularRouteCard('Kigali', 'Cyangugu', '7,200 RWF'),
                    _buildPopularRouteCard('Butare', 'Gisenyi', '8,000 RWF'),
                  ],
                ),
              ),
            ],
          ),
        );
  }

  Widget _buildPopularRouteCard(String from, String to, String price) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$from to $to',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}
