// lib/screens/admin/admin_buses.dart
import 'package:flutter/material.dart';
import 'package:tickiting/models/bus.dart';
import 'package:tickiting/utils/theme.dart';
import 'package:tickiting/utils/database_helper.dart';

class AdminBuses extends StatefulWidget {
  const AdminBuses({super.key});

  @override
  AdminBusesState createState() => AdminBusesState();
}

class AdminBusesState extends State<AdminBuses> {
  List<Bus> buses = [];
  List<String> locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Check and fix database schema
    _checkDatabaseSchema();
    _loadLocations();
    _loadBuses();
  }

  Future<void> _checkDatabaseSchema() async {
    try {
      await DatabaseHelper().ensureRouteColumnsExist();
    } catch (e) {
      print("Error checking database schema: $e");
    }
  }

  // Load locations from database
  Future<void> _loadLocations() async {
    try {
      final loadedLocations = await DatabaseHelper().getAllUniqueLocations();
      setState(() {
        locations = loadedLocations;
      });
    } catch (e) {
      print('Error loading locations: $e');
      // Use default locations if there's an error
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
          'Huye',
          'Musanze',
        ];
      });
    }
  }

  // Load buses from database
  Future<void> _loadBuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final loadedBuses = await DatabaseHelper().getAllBuses();
      setState(() {
        buses = loadedBuses;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading buses: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and manage locations button
            // Replace the title and manage locations button row with this code
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Bus Management',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10), // Add a small space between
                ElevatedButton.icon(
                  onPressed: () {
                    _showManageLocationsDialog(context);
                  },
                  icon: const Icon(Icons.location_on, size: 18),
                  label: const Text('Locations'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Search and filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search buses...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    // Show filter options
                  },
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Filter'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Bus list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : buses.isEmpty
                      ? const Center(child: Text('No buses found'))
                      : RefreshIndicator(
                        onRefresh: _loadBuses,
                        child: ListView.builder(
                          itemCount: buses.length,
                          itemBuilder: (context, index) {
                            final bus = buses[index];
                            return _buildBusCard(bus, index);
                          },
                        ),
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddEditBusDialog(context);
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBusCard(Bus bus, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bus.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'ID: ${bus.id}',
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
            const SizedBox(height: 15),
            // Display route information
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.directions, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Route: ${bus.fromLocation} to ${bus.toLocation}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Departure',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        bus.departureTime,
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
                        'Arrival',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        bus.arrivalTime,
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
                        'Duration',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        _calculateDuration(bus.departureTime, bus.arrivalTime),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
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
                      const Text('Price', style: TextStyle(color: Colors.grey)),
                      Text(
                        '${bus.price.toStringAsFixed(0)} RWF',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Seats',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '${bus.availableSeats}',
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
                        'Features',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        bus.features.join(', '),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
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
                    _showAddEditBusDialog(context, bus: bus, index: index);
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    _showDeleteConfirmDialog(context, index);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditBusDialog(BuildContext context, {Bus? bus, int? index}) {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController(text: bus?.id ?? '');
    final nameController = TextEditingController(text: bus?.name ?? '');
    final departureTimeController = TextEditingController(
      text: bus?.departureTime ?? '08:00 AM',
    );
    final arrivalTimeController = TextEditingController(
      text: bus?.arrivalTime ?? '10:30 AM',
    );
    final priceController = TextEditingController(
      text: bus?.price.toString() ?? '2000',
    );
    final seatsController = TextEditingController(
      text: bus?.availableSeats.toString() ?? '30',
    );
    final newLocationController = TextEditingController();

    // Create mutable copies of all values that will be modified in the dialog
    String busType = bus?.busType ?? 'Standard';
    String fromLocation = bus?.fromLocation ?? 'Kigali';
    String toLocation = bus?.toLocation ?? 'Butare';

    // Using separate boolean variables for each feature
    bool hasAC = bus?.features.contains('AC') ?? true;
    bool hasWiFi = bus?.features.contains('WiFi') ?? false;
    bool hasUSB = bus?.features.contains('USB Charging') ?? false;
    bool hasRefreshments = bus?.features.contains('Refreshments') ?? false;
    bool hasTV = bus?.features.contains('TV') ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(bus == null ? 'Add New Bus' : 'Edit Bus'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.8,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: idController,
                          decoration: const InputDecoration(
                            labelText: 'Bus ID',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter bus ID';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Bus Name',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter bus name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: busType,
                          decoration: const InputDecoration(
                            labelText: 'Bus Type',
                          ),
                          items:
                              ['Economy', 'Standard', 'Premium'].map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                busType = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 15),

                        // Route Information
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Route Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: fromLocation,
                                decoration: const InputDecoration(
                                  labelText: 'From',
                                ),
                                isExpanded: true,
                                items:
                                    locations.map((location) {
                                      return DropdownMenuItem<String>(
                                        value: location,
                                        child: Text(location),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setStateDialog(() {
                                      fromLocation = value;
                                    });
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select origin';
                                  }
                                  if (value == toLocation) {
                                    return 'Origin and destination must be different';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 5),

                              // Add new location row
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: newLocationController,
                                      decoration: const InputDecoration(
                                        labelText: 'Add New Location',
                                        hintText: 'e.g., Nyanza',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle,
                                      color: AppTheme.primaryColor,
                                    ),
                                    onPressed: () {
                                      final newLocation =
                                          newLocationController.text.trim();
                                      if (newLocation.isNotEmpty) {
                                        if (!locations.contains(newLocation)) {
                                          // Save the location to the database
                                          DatabaseHelper()
                                              .saveLocation(newLocation)
                                              .then((result) {
                                                if (result > 0) {
                                                  setStateDialog(() {
                                                    locations.add(newLocation);
                                                    locations.sort();
                                                    newLocationController
                                                        .clear();
                                                  });
                                                }
                                              });
                                        } else {
                                          // Show a snackbar that the location already exists
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Location "$newLocation" already exists',
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                value: toLocation,
                                decoration: const InputDecoration(
                                  labelText: 'To',
                                ),
                                isExpanded: true,
                                items:
                                    locations.map((location) {
                                      return DropdownMenuItem<String>(
                                        value: location,
                                        child: Text(location),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setStateDialog(() {
                                      toLocation = value;
                                    });
                                  }
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select destination';
                                  }
                                  if (value == fromLocation) {
                                    return 'Origin and destination must be different';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 15),

                              // Helper text
                              Text(
                                'Newly added locations will be available in the user booking screen',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),

                        TextFormField(
                          controller: departureTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Departure Time (e.g., 08:00 AM)',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter departure time';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: arrivalTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Arrival Time (e.g., 10:30 AM)',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter arrival time';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Price (RWF)',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter price';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: seatsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Available Seats',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter available seats';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),

                        // Features section with individual checkboxes
                        const Text(
                          'Features',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('AC'),
                                value: hasAC,
                                onChanged: (bool? value) {
                                  setStateDialog(() {
                                    hasAC = value ?? false;
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('WiFi'),
                                value: hasWiFi,
                                onChanged: (bool? value) {
                                  setStateDialog(() {
                                    hasWiFi = value ?? false;
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('USB Charging'),
                                value: hasUSB,
                                onChanged: (bool? value) {
                                  setStateDialog(() {
                                    hasUSB = value ?? false;
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('Refreshments'),
                                value: hasRefreshments,
                                onChanged: (bool? value) {
                                  setStateDialog(() {
                                    hasRefreshments = value ?? false;
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: CheckboxListTile(
                                title: const Text('TV'),
                                value: hasTV,
                                onChanged: (bool? value) {
                                  setStateDialog(() {
                                    hasTV = value ?? false;
                                  });
                                },
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
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
                    if (formKey.currentState!.validate()) {
                      try {
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) {
                            return AlertDialog(
                              content: Row(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(width: 20),
                                  Text("Saving..."),
                                ],
                              ),
                            );
                          },
                        );

                        // Create features list from individual checkboxes
                        List<String> features = [];
                        if (hasAC) features.add('AC');
                        if (hasWiFi) features.add('WiFi');
                        if (hasUSB) features.add('USB Charging');
                        if (hasRefreshments) features.add('Refreshments');
                        if (hasTV) features.add('TV');

                        // Calculate duration
                        String duration = _calculateDuration(
                          departureTimeController.text,
                          arrivalTimeController.text,
                        );

                        // Update locations list in the parent widget too
                        setState(() {
                          // Ensure both locations are in our main list
                          if (!locations.contains(fromLocation)) {
                            locations.add(fromLocation);
                          }
                          if (!locations.contains(toLocation)) {
                            locations.add(toLocation);
                          }
                          // Sort locations alphabetically
                          locations.sort();
                        });

                        final newBus = Bus(
                          id: idController.text,
                          name: nameController.text,
                          departureTime: departureTimeController.text,
                          arrivalTime: arrivalTimeController.text,
                          duration: duration,
                          price: double.parse(priceController.text),
                          availableSeats: int.parse(seatsController.text),
                          busType: busType,
                          features: features,
                          fromLocation: fromLocation,
                          toLocation: toLocation,
                        );

                        // Ensure database has correct schema
                        await DatabaseHelper().ensureRouteColumnsExist();

                        if (bus == null) {
                          // Add new bus
                          await DatabaseHelper().insertBus(newBus);
                        } else {
                          // Update existing bus
                          await DatabaseHelper().updateBus(newBus);
                        }

                        // Dismiss loading dialog
                        Navigator.pop(context);

                        // Dismiss edit dialog
                        Navigator.pop(context);

                        // Refresh bus list
                        _loadBuses();

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              bus == null
                                  ? 'Bus added successfully'
                                  : 'Bus updated successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        // Dismiss loading dialog if open
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }

                        // Show error message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(bus == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, int index) {
    final bus = buses[index];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Bus'),
            content: const Text(
              'Are you sure you want to delete this bus? This action cannot be undone.',
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
                  try {
                    // Delete bus from database
                    await DatabaseHelper().deleteBus(bus.id);

                    // Reload buses from database
                    _loadBuses();

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bus deleted successfully'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  // Helper method to calculate duration based on departure and arrival times
  String _calculateDuration(String departureTime, String arrivalTime) {
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
      print("Error calculating duration: $e");
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
      print("Error parsing time string: $e");
      // Return current time as fallback
      return DateTime.now();
    }
  }

  // Method to show location management dialog
  void _showManageLocationsDialog(BuildContext context) {
    final TextEditingController newLocationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Manage Locations'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    // Add new location
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newLocationController,
                            decoration: const InputDecoration(
                              labelText: 'New Location',
                              hintText: 'Enter location name',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_circle,
                            color: AppTheme.primaryColor,
                          ),
                          onPressed: () {
                            final newLocation =
                                newLocationController.text.trim();
                            if (newLocation.isNotEmpty) {
                              if (!locations.contains(newLocation)) {
                                // Save the location to the database
                                DatabaseHelper().saveLocation(newLocation).then((
                                  result,
                                ) {
                                  if (result > 0) {
                                    setStateDialog(() {
                                      locations.add(newLocation);
                                      locations.sort();
                                      newLocationController.clear();

                                      // Also update the parent state
                                      setState(() {});
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Location "$newLocation" added successfully',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Location "$newLocation" already exists',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                newLocationController.clear();
                              }
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      'Current Locations',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    // List of current locations
                    Expanded(
                      child: ListView.builder(
                        itemCount: locations.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            title: Text(locations[index]),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () {
                                // Check if location is used by any bus
                                bool isUsed = buses.any(
                                  (bus) =>
                                      bus.fromLocation == locations[index] ||
                                      bus.toLocation == locations[index],
                                );

                                if (isUsed) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Cannot delete "${locations[index]}" as it is used by existing buses',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                // Delete the location from the database
                                DatabaseHelper()
                                    .deleteLocation(locations[index])
                                    .then((_) {
                                      setStateDialog(() {
                                        locations.removeAt(index);
                                        // Also update the parent state
                                        setState(() {});
                                      });

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Location deleted successfully',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    });
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
