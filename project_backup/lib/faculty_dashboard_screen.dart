import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:attendance_automation/attendance_service.dart';
import 'package:attendance_automation/nearby_service.dart';
import 'faculty_settings_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({super.key});

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  final List<String> _classes = [
    "CPPS",
    "LAUC",
    "ECH",
    "DECO",
  ];
  
  final AttendanceService _attendanceService = AttendanceService();
  final NearbyConnectionsService _nearbyService = NearbyConnectionsService();
  
  String? _currentOTP;
  String? _expiresAt;
  int _connectedStudents = 0;
  String _connectionStatus = "";

  @override
  void initState() {
    super.initState();
    _setupNearbyService();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _nearbyService.dispose();
    super.dispose();
  }

  void _setupNearbyService() {
    _nearbyService.onConnectionUpdate = (message) {
      if (mounted) {
        setState(() {
          _connectionStatus = message;
        });
      }
    };
    
    _nearbyService.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nearby Error: $error"), backgroundColor: Colors.red),
        );
      }
    };
  }

  Future<void> _checkActiveSession() async {
    final token = await _attendanceService.getToken();
    if (token == null) {
      return;
    }

    try {
      String? currentSubject = await _attendanceService.getActiveSession("A");
      
      if (currentSubject != null) {
        if (mounted) {
          setState(() {
            _attendanceService.activeClassName = currentSubject;
          });
        }
      }
    } catch (e) {
      print("Failed to check active session: $e");
    }
  }

  Future<void> _startAttendance(String className) async {
    final username = await _attendanceService.getUsername() ?? "Faculty";
    
    if (mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Attendance?'),
          content: Text(
              "You will start broadcasting via Bluetooth/WiFi Direct for $className attendance."),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Start Session'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );

      if (proceed == true) {
        // Start Session API Call (gets OTP)
        final result = await _attendanceService.startSession("A", className);

        if (result != null && result['status'] == true) {
          final otp = result['otp'];
          final expiresAt = result['expires_at'];
          
          // Start Nearby Connections advertising
          bool advertisingStarted = await _nearbyService.startAdvertising(
            facultyName: username,
            otp: otp,
          );
          
          if (advertisingStarted) {
            setState(() {
              _attendanceService.activeClassName = className;
              _currentOTP = otp;
              _expiresAt = expiresAt;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Broadcasting for $className. OTP: $otp")),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Failed to start Nearby Connections advertising"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to start session. Server Error."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _stopAttendance() async {
    // Stop advertising
    await _nearbyService.stopAdvertising();
    
    // API Call to stop session
    await _attendanceService.stopSession("A");

    setState(() {
      _attendanceService.activeClassName = null;
      _currentOTP = null;
      _expiresAt = null;
      _connectedStudents = 0;
      _connectionStatus = "";
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Attendance Stopped"),
          content: const Text("Attendance session has been stopped and broadcasting ended."),
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

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FacultySettingsScreen()),
    );
  }

  void _copyOTP() {
    if (_currentOTP != null) {
      Clipboard.setData(ClipboardData(text: _currentOTP!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("OTP copied to clipboard")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeClassName = _attendanceService.activeClassName;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Faculty Dashboard"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
            tooltip: 'Settings',
          )
        ],
      ),
      body: Column(
        children: [
          // OTP Display Card (shown when session is active)
          if (activeClassName != null && _currentOTP != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "📡 BROADCASTING",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activeClassName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Session OTP",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _copyOTP,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentOTP!,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: Colors.green.shade700,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.copy, color: Colors.green.shade700, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_expiresAt != null)
                    Text(
                      "Expires: $_expiresAt",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  if (_connectionStatus.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _connectionStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          
          // Class List
          Expanded(
            child: ListView.builder(
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final className = _classes[index];
                final isThisClassActive = activeClassName == className;
                final isAnyClassActive = activeClassName != null;

                if (isThisClassActive) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.green.shade50,
                    child: ListTile(
                      title: Text(
                        className,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text("ACTIVE SESSION"),
                      trailing: ElevatedButton(
                        onPressed: _stopAttendance,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text("Stop"),
                      ),
                    ),
                  );
                } else {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(className),
                      trailing: ElevatedButton(
                        onPressed: isAnyClassActive ? null : () => _startAttendance(className),
                        child: const Text("Start Attendance"),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
