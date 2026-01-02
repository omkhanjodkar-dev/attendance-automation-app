import 'dart:async';
import 'package:attendance_automation/attendance_service.dart';
import 'package:attendance_automation/nearby_service.dart';
import 'package:attendance_automation/student_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _username;
  Position? _currentPosition;
  bool _isLoading = false;
  String _discoveryStatus = "Tap 'Search' to find faculty";
  String? _receivedOTP;
  String? _discoveredFaculty;
  bool _isDiscovering = false;
  
  final AttendanceService _attendanceService = AttendanceService();
  final NearbyConnectionsService _nearbyService = NearbyConnectionsService();

  @override
  void initState() {
    super.initState();
    _loadUserAndSensors();
    _setupNearbyService();
  }

  @override
  void dispose() {
    _nearbyService.dispose();
    super.dispose();
  }

  void _setupNearbyService() {
    _nearbyService.onOtpReceived = (otp) {
      if (mounted) {
        setState(() {
          _receivedOTP = otp;
          _discoveryStatus = "✅ OTP Received!";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP Received: $otp"), backgroundColor: Colors.green),
        );
      }
    };
    
    _nearbyService.onEndpointDiscovered = (endpointId, endpointName) {
      if (mounted) {
        setState(() {
          _discoveredFaculty = endpointName;
          _discoveryStatus = "Connecting to $endpointName...";
        });
      }
    };
    
    _nearbyService.onConnectionUpdate = (message) {
      if (mounted) {
        setState(() {
          _discoveryStatus = message;
        });
      }
    };
    
    _nearbyService.onError = (error) {
      if (mounted) {
        setState(() {
          _discoveryStatus = "Error: $error";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error"), backgroundColor Colors.red),
        );
      }
    };
  }

  Future<void> _loadUserAndSensors() async {
    final username = await _attendanceService.getUsername();
    setState(() {
      _username = username;
    });
    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services disabled");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print("Location permission denied");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _discoveryStatus = "Searching for nearby faculty...";
      _receivedOTP = null;
      _discoveredFaculty = null;
    });

    final username = _username ?? "Student";
    bool started = await _nearbyService.startDiscovery(studentName: username);

    if (!started) {
      setState(() {
        _isDiscovering = false;
        _discoveryStatus = "Failed to start discovery. Check permissions.";
      });
    }
  }

  Future<void> _stopDiscovery() async {
    await _nearbyService.stopDiscovery();
    setState(() {
      _isDiscovering = false;
      _discoveryStatus = "Discovery stopped";
      _receivedOTP = null;
      _discoveredFaculty = null;
    });
  }

  Future<void> _markAttendance() async {
    if (_receivedOTP == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No OTP received yet"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    try {
      final result = await _attendanceService.verifyOTPAndMarkAttendance(
        section: "A",
        username: _username!,
        otp: _receivedOTP!,
        date: dateStr,
        time: timeStr,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['status'] == true) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("✅ Success!", style: TextStyle(color: Colors.green)),
              content: Text(
                "Attendance marked for ${result['subject']}\n\n${result['message']}",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _stopDiscovery(); // Stop discovery after successful attendance
                  },
                  child: const Text("OK"),
                )
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("❌ Failed", style: TextStyle(color: Colors.red)),
              content: Text(result['message'] ?? "Failed to mark attendance"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Home"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StudentSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, $_username",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_currentPosition != null)
                      Text(
                        "📍 Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Discovery Card
            Card(
              elevation: 4,
              color: _isDiscovering ? Colors.blue.shade50 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isDiscovering ? Icons.radar : Icons.search,
                          color: _isDiscovering ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isDiscovering ? "Discovering..." : "Faculty Discovery",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _discoveryStatus,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    if (_discoveredFaculty != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _discoveredFaculty!,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_receivedOTP != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Received OTP",
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _receivedOTP!,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: Colors.green.shade700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_isDiscovering)
                      ElevatedButton.icon(
                        onPressed: _startDiscovery,
                        icon: const Icon(Icons.radar),
                        label: const Text("Start Discovery"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _stopDiscovery,
                        icon: const Icon(Icons.stop),
                        label: const Text("Stop Discovery"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Mark Attendance Button
            ElevatedButton(
              onPressed: _receivedOTP != null && !_isLoading ? _markAttendance : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.all(20),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _receivedOTP != null ? "MARK PRESENT" : "WAITING FOR OTP...",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _receivedOTP != null ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "How it works",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "1. Tap 'Start Discovery' to search for your faculty\n"
                      "2. Connect to the faculty device via Bluetooth/WiFi Direct\n"
                      "3. OTP will be received automatically\n"
                      "4. Tap 'Mark Present' to submit attendance",
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}