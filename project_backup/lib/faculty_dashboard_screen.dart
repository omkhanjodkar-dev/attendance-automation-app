import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import 'attendance_service.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({super.key});

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  final List<String> _classes = [
    "Computer Science 101",
    "Mathematics 203",
    "Physics 301",
    "History 110",
  ];

  final AttendanceService _attendanceService = AttendanceService();
  bool _isScanning = false;
  StreamSubscription<List<WiFiAccessPoint>>? _scanSubscription;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startAttendance(String className) async {
    // 1. Prompt user to turn on hotspot
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Attendance?'),
        content: const SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text("Please turn on your device's Wi-Fi hotspot."),
              SizedBox(height: 10),
              Text(
                  "Your hotspot's MAC address (BSSID) will be used to verify student attendance."),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Continue'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // 2. Scan for networks
    setState(() => _isScanning = true);
    await [Permission.location].request();
    final canScan = await WiFiScan.instance.canStartScan(askPermissions: true);

    if (canScan != CanStartScan.yes) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cannot start scan. Please grant location permissions.")));
      }
      return;
    }

    final isScanning = await WiFiScan.instance.startScan();
    if (!isScanning) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Failed to start scan.")));
      }
      return;
    }

    // Listen for scan results
    _scanSubscription =
        WiFiScan.instance.onScannedResultsAvailable.listen((networks) {
      _scanSubscription?.cancel(); // We only need the first result set
      setState(() => _isScanning = false);
      _showHotspotSelectionDialog(networks, className);
    });
  }

  Future<void> _showHotspotSelectionDialog(
      List<WiFiAccessPoint> networks, String className) async {
    if (!mounted) return;

    final selectedNetwork = await showDialog<WiFiAccessPoint>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Your Hotspot"),
        content: SizedBox(
          width: double.maxFinite,
          child: networks.isEmpty
              ? const Text(
                  "No networks found. Please make sure your hotspot is on and try again.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: networks.length,
                  itemBuilder: (context, index) {
                    final network = networks[index];
                    return ListTile(
                      title: Text(network.ssid.isNotEmpty
                          ? network.ssid
                          : "Hidden Network"),
                      subtitle: Text(network.bssid),
                      onTap: () => Navigator.of(context).pop(network),
                    );
                  },
                ),
        ),
      ),
    );

    if (selectedNetwork != null) {
      setState(() {
        _attendanceService.activeFacultyHotspotBSSID = selectedNetwork.bssid;
        _attendanceService.activeClassName = className;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Attendance Started"),
            content: Text(
                "Attendance for $className has started.\nBSSID: ${selectedNetwork.bssid}"),
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
  }

  void _stopAttendance() {
    setState(() {
      _attendanceService.activeFacultyHotspotBSSID = null;
      _attendanceService.activeClassName = null;
    });
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

  @override
  Widget build(BuildContext context) {
    final activeClassName = _attendanceService.activeClassName;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Faculty Dashboard"),
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text("Scanning for hotspots..."),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final className = _classes[index];
                final isThisClassActive = activeClassName == className;
                final isAnyClassActive = activeClassName != null;

                if (isThisClassActive) {
                  return ListTile(
                    title: Text(className),
                    subtitle: Text(
                        "BSSID: ${_attendanceService.activeFacultyHotspotBSSID ?? 'N/A'}"),
                    trailing: ElevatedButton(
                      onPressed: _stopAttendance,
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Stop Attendance"),
                    ),
                  );
                } else {
                  return ListTile(
                    title: Text(className),
                    trailing: ElevatedButton(
                      onPressed: isAnyClassActive
                          ? null
                          : () => _startAttendance(className),
                      child: const Text("Start Attendance"),
                    ),
                  );
                }
              },
            ),
    );
  }
}
