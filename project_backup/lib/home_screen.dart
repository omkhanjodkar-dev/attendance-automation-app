import 'dart:async'; // Import for StreamSubscription
import 'dart:io';
import 'package:attendance_automation/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wifi_scan/wifi_scan.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _wifiName = "Scanning...";
  String _locationTxt = "Waiting...";
  String _deviceId = "Unknown";
  String _macAddress = "Unknown";
  List<WiFiAccessPoint> _availableNetworks = [];
  bool _isLoading = false;
  StreamSubscription<List<WiFiAccessPoint>>? _subscription;
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initSensors() async {
    await [
      Permission.location,
      Permission.locationWhenInUse,
    ].request();

    final deviceInfo = DeviceInfoPlugin();
    String id = "Unknown";
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      id = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      id = iosInfo.identifierForVendor ?? "Unknown IOS";
    }

    setState(() {
      _deviceId = id;
    });

    _refreshSensors();
  }

  Future<void> _getScannedNetworks() async {
    final accessPoints = await WiFiScan.instance.getScannedResults();
    setState(() {
      _availableNetworks = accessPoints;
    });
  }

  Future<void> _refreshSensors() async {
    setState(() => _isLoading = true);

    try {
      Position pos = await Geolocator.getCurrentPosition();
      final info = NetworkInfo();
      String? wifi = await info.getWifiName();
      String? bssid = await info.getWifiBSSID();

      final canScan = await WiFiScan.instance.canStartScan(askPermissions: true);
      if (canScan == CanStartScan.yes) {
        final isScanning = await WiFiScan.instance.startScan();
        if (isScanning) {
          _subscription?.cancel();
          _subscription = WiFiScan.instance.onScannedResultsAvailable.listen((event) {
            _getScannedNetworks();
          });
        }
      }

      setState(() {
        _locationTxt = "Lat: ${pos.latitude.toStringAsFixed(4)}\nLng: ${pos.longitude.toStringAsFixed(4)}";
        _wifiName = wifi ?? "Mobile Data / Not Connected";
        _macAddress = bssid ?? "Unknown";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _locationTxt = "Error getting location";
        _wifiName = "Error getting Wi-Fi";
        _macAddress = "Error getting MAC address";
        _isLoading = false;
      });
    }
  }

  Future<void> _markAttendance() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          title: Text("Attendance Marked for ${_attendanceService.activeClassName}!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Device: $_deviceId"),
              const SizedBox(height: 5),
              Text("Wi-Fi: $_wifiName"),
              const SizedBox(height: 5),
              Text("BSSID: $_macAddress"),
              const SizedBox(height: 5),
              const Text("Status: Verified ✅"),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    final facultySSID = _attendanceService.activeFacultySSID;
    final activeClass = _attendanceService.activeClassName;

    // Check if any scanned network matches the faculty SSID (Case insensitive)
    bool isFacultyHotspotAvailable = facultySSID != null &&
        _availableNetworks.any((ap) => ap.ssid.toLowerCase() == facultySSID.toLowerCase());

    bool canMarkAttendance = !_isLoading && isFacultyHotspotAvailable;

    return Scaffold(
      appBar: AppBar(title: const Text("Student Dashboard")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (activeClass != null)
                Card(
                  color: Colors.blue[50],
                  child: ListTile(
                    leading: const Icon(Icons.info, color: Colors.blue),
                    title: Text("Attendance for '$activeClass' is active."),
                    subtitle: Text(
                        "Connect to the faculty's hotspot '$facultySSID' to mark your attendance."),
                  ),
                ),
              const SizedBox(height: 10),
              Card(
                elevation: 4,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.perm_device_information, color: Colors.blue),
                        title: const Text("Device ID"),
                        subtitle: Text(_deviceId, style: const TextStyle(fontSize: 12)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(Icons.wifi, color: _wifiName.contains("Scanning") ? Colors.orange : Colors.green),
                        title: const Text("Wi-Fi Network"),
                        subtitle: Text(_wifiName),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.network_check),
                        title: const Text("Connected AP MAC Address"),
                        subtitle: Text(_macAddress),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.redAccent),
                        title: const Text("GPS Location"),
                        subtitle: Text(_locationTxt),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _refreshSensors,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh Sensors"),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: canMarkAttendance ? _markAttendance : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("MARK PRESENT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              if (facultySSID != null && !isFacultyHotspotAvailable)
                Text(
                  "Faculty hotspot '$facultySSID' not detected. Make sure you are in range.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                )
              else if (facultySSID == null)
                const Text(
                  "No active attendance session. Please wait for the faculty to start one.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 20),
              const Text("Available Wi-Fi Networks:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 200,
                child: _availableNetworks.isEmpty
                    ? const Center(child: Text("Scanning for networks..."))
                    : ListView.builder(
                        itemCount: _availableNetworks.length,
                        itemBuilder: (context, index) {
                          final network = _availableNetworks[index];
                          final isFacultyHotspot = facultySSID != null && network.ssid.toLowerCase() == facultySSID.toLowerCase();
                          return ListTile(
                            leading: Icon(isFacultyHotspot ? Icons.star : Icons.wifi, color: isFacultyHotspot ? Colors.green : null),
                            title: Text(network.ssid),
                            subtitle: Text("BSSID: ${network.bssid}"),
                            trailing: Text("${network.level} dBm"),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}