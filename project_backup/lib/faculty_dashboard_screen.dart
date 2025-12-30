import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    // Check if we even have a token first
    final token = await _attendanceService.getToken();
    if (token == null) {
      // No token - user needs to re-login
      return;
    }

    try {
      // 1. Check for Active Session
      String? currentSubject = await _attendanceService.getActiveSession("A");
      
      // 2. Check for Stored SSID
      String? storedSSID = await _attendanceService.getClassSSID("A");

      // Only update state if BOTH are successfully retrieved
      if (currentSubject != null && storedSSID != null) {
        if (mounted) {
          setState(() {
            _attendanceService.activeClassName = currentSubject;
            _attendanceService.activeFacultySSID = storedSSID;
          });
        }
      }
    } catch (e) {
      // API failed - don't set any state
      print("Failed to check active session: $e");
    }
  }

  Future<void> _startAttendance(String className) async {
    // 1. Check Permissions for Nearby Connections
    bool hasPermissions = await NearbyService().checkPermissions();
    if (!hasPermissions) {
        if (mounted) {
            showDialog(
                context: context,
                builder: (context) => AlertDialog(
                    title: const Text('Permissions Required'),
                    content: const Text('Bluetooth and Location permissions are required to broadcast the class beacon.'),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                        )
                    ],
                )
            );
        }
        return;
    }

    // 2. Confirm Start
    if (mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Attendance?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text("This will start broadcasting the class beacon."),
                const SizedBox(height: 10),
                Text(
                    "Students nearby will be able to mark their attendance for $className."),
              ],
            ),
          ),
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
        // Start Session API Call
        // Returns OTP string if successful, null otherwise
        String? otp = await _attendanceService.startSession("A", className);

        if (otp != null) {
          // Start Advertising Beacon with OTP
          // Format: Class_<ClassName>_<OTP>
          await NearbyService().startAdvertisingForFaculty("Class_${className}_$otp");

          setState(() {
            _attendanceService.activeFacultySSID = "Beacon Active (OTP: $otp)"; 
            _attendanceService.activeClassName = className;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Attendance started for $className (OTP: $otp)")),
            );
          }
        } else {
             if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Failed to start session. Server Error."), backgroundColor: Colors.red),
                );
             }
        }
      }
    }
  }

  Future<void> _stopAttendance() async {
    // Stop Beacon
    await NearbyService().stopAdvertising();
    
    // API Call to stop session
    await _attendanceService.stopSession("A");

    setState(() {
      _attendanceService.activeFacultySSID = null;
      _attendanceService.activeClassName = null;
    });

    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Attendance Stopped"),
          content: const Text("Attendance has been stopped."),
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
      body: ListView.builder(
        itemCount: _classes.length,
        itemBuilder: (context, index) {
          final className = _classes[index];
          final isThisClassActive = activeClassName == className;
          final isAnyClassActive = activeClassName != null;

          if (isThisClassActive) {
            return ListTile(
              title: Text(className),
              subtitle: Text(
                  "SSID: ${_attendanceService.activeFacultySSID ?? 'N/A'} - ACTIVE"),
              tileColor: Colors.green.withOpacity(0.1),
              trailing: ElevatedButton(
                onPressed: _stopAttendance,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Stop Attendance"),
              ),
            );
          } else {
            return ListTile(
              title: Text(className),
              trailing: ElevatedButton(
                onPressed: isAnyClassActive ? null : () => _startAttendance(className),
                child: const Text("Start Attendance"),
              ),
            );
          }
        },
      ),
    );
  }
}
