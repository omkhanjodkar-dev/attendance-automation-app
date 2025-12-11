import 'package:flutter/material.dart';
import 'package:attendance_automation/attendance_service.dart';
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
    // 1. Check for stored SSID via API
    // Hardcoded section 'A' for MVP
    final String? ssid = await _attendanceService.getClassSSID("A");

    if (ssid == null || ssid.isEmpty) {
      // 2. If no SSID, prompt to go to settings
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Setup Required'),
            content: const Text(
                'You must configure your Hotspot Name (SSID) in Settings before starting attendance.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openSettings();
                },
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // 3. If SSID exists, confirm and start
    if (mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start Attendance?'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text("Please turn on your device's Wi-Fi hotspot."),
                const SizedBox(height: 10),
                Text(
                    "Your hostpot name ($ssid) will be used to verify student attendance."),
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
        bool success = await _attendanceService.startSession("A", className);

        if (success) {
          setState(() {
            _attendanceService.activeFacultySSID = ssid;
            _attendanceService.activeClassName = className;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Attendance started for $className")),
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
