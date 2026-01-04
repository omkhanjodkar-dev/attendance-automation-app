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
  String _attendanceStatus = "Ready to mark attendance";
  String? _receivedOTP;
  bool _isVerifying = false;
  
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
          _attendanceStatus = "✓ Verification complete";
        });
        // Auto-mark attendance when OTP is received
        Future.delayed(Duration(milliseconds: 500), () {
          if (mounted && _receivedOTP != null) {
            _markAttendance();
          }
        });
      }
    };
    
    _nearbyService.onEndpointDiscovered = (endpointId, endpointName) {
      if (mounted) {
        setState(() {
          _attendanceStatus = "Verifying location...";
        });
      }
    };
    
    _nearbyService.onConnectionUpdate = (message) {
      if (mounted) {
        setState(() {
          _attendanceStatus = "Verifying location...";
        });
      }
    };
    
    _nearbyService.onError = (error) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _attendanceStatus = "Verification failed";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to verify location. Please try again."), backgroundColor: Colors.red),
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
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Error getting location: $e");
    }
  }

  Future<void> _startAttendanceFlow() async {
    setState(() {
      _isVerifying = true;
      _attendanceStatus = "Verifying your location...";
      _receivedOTP = null;
    });

    final username = _username ?? "Student";
    bool started = await _nearbyService.startDiscovery(studentName: username);

    if (!started) {
      setState(() {
        _isVerifying = false;
        _attendanceStatus = "Verification failed. Please check permissions.";
      });
    }
  }

  Future<void> _stopAttendanceFlow() async {
    await _nearbyService.stopDiscovery();
    setState(() {
      _isVerifying = false;
      _attendanceStatus = "Cancelled";
      _receivedOTP = null;
    });
  }

  Future<void> _markAttendance() async {
    if (_receivedOTP == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _attendanceStatus = "Submitting attendance...";
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
        _isVerifying = false;
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
                    _stopAttendanceFlow(); // Stop after successful attendance
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
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unable to mark attendance. Please try again."), backgroundColor: Colors.red),
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
            
            // Attendance Status Card
            Card(
              elevation: 4,
              color: _isVerifying ? Colors.blue.shade50 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _receivedOTP != null ? Icons.check_circle : 
                          _isVerifying ? Icons.access_time : Icons.location_on,
                          color: _receivedOTP != null ? Colors.green : 
                                 _isVerifying ? Colors.blue : Colors.grey,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _attendanceStatus,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Mark Attendance Button
            if (!_isVerifying && !_isLoading)
              ElevatedButton(
                onPressed: _startAttendanceFlow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.all(20),
                ),
                child: const Text(
                  "MARK ATTENDANCE",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
            else if (_isVerifying || _isLoading)
              OutlinedButton(
                onPressed: _stopAttendanceFlow,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            "SUBMITTING...",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "CANCEL",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            

          ],
        ),
      ),
    );
  }
}