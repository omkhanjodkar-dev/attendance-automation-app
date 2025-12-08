import 'dart:async'; // Import for StreamSubscription
import 'dart:io';
import 'package:attendance_automation/attendance_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  // State variables for Class Session
  String? _activeSubject;
  String? _targetSSID;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUserAndSensors();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserAndSensors() async {
     setState(() => _isLoading = true);
     
     // 1. Get Username
     final prefs = await SharedPreferences.getInstance();
     _username = prefs.getString('user_email') ?? "Unknown Student";

     // 2. Initialize Sensors (GPS, Device ID)
     await _initSensors();

     // 3. Check for Active Class (Hardcoded Section 'Div-A' for MVP)
     // In a real app, you would get this from the Student's profile
     print("Checking for active session...");
     String? subject = await _attendanceService.getActiveSession("A");
     
     if (subject != null) {
        print("Active session found: $subject. Fetching SSID...");
        // 4. Fetch the target SSID for this class
        String? ssid = await _attendanceService.getClassSSID("A");
        if (mounted) {
            setState(() {
                _activeSubject = subject;
                _targetSSID = ssid;
            });
        }
     } else {
        print("No active session.");
        if (mounted) setState(() { _activeSubject = null; _targetSSID = null; });
     }

     setState(() => _isLoading = false);
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

    if (mounted) {
        setState(() {
            _deviceId = id;
        });
    }

    _refreshSensors();
  }

  Future<void> _getScannedNetworks() async {
    final accessPoints = await WiFiScan.instance.getScannedResults();
    if (mounted) {
        setState(() {
            _availableNetworks = accessPoints;
        });
    }
  }

  Future<void> _refreshSensors() async {
    // Only set loading if not already loading (to avoid flicker)
    // setState(() => _isLoading = true);

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

      if (mounted) {
          setState(() {
            _locationTxt = "Lat: ${pos.latitude.toStringAsFixed(4)}\nLng: ${pos.longitude.toStringAsFixed(4)}";
            _wifiName = wifi ?? "Mobile Data / Not Connected";
            _macAddress = bssid ?? "Unknown";
            // _isLoading = false;
          });
      }
    } catch (e) {
      if (mounted) {
          setState(() {
            _locationTxt = "Error getting location";
            _wifiName = "Error getting Wi-Fi";
            _macAddress = "Error getting MAC address";
            // _isLoading = false;
          });
      }
    }
  }

  Future<void> _markAttendance() async {
    if (_activeSubject == null) return;
    
    setState(() => _isLoading = true);
    
    // Prepare Data
    final now = DateTime.now();
    final dateStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";
    final timeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";
    
    // Call API
    print("Marking attendance for $_username in $_activeSubject...");
    bool success = await _attendanceService.markAttendance(
        section: "A", // Hardcoded for MVP
        username: _username!, 
        subject: _activeSubject!, 
        date: dateStr, 
        time: timeStr
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
              title: Text("Attendance Marked for $_activeSubject!"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Student: $_username"),
                  const SizedBox(height: 5),
                  Text("Device: $_deviceId"),
                  const SizedBox(height: 5),
                  const Text("Status: Verified & Saved to Cloud ✅"),
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
      } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to mark attendance. Server Error."), backgroundColor: Colors.red),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    
    // Validation Logic
    // 1. Must implement scanning logic locally
    bool isFacultyHotspotAvailable = false;
    if (_targetSSID != null) {
        // Check if TARGET SSID is in the scanned list
        isFacultyHotspotAvailable = _availableNetworks.any((ap) => ap.ssid.toLowerCase() == _targetSSID!.toLowerCase());
    }

    bool canMarkAttendance = !_isLoading && isFacultyHotspotAvailable && _activeSubject != null;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Student Dashboard"),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUserAndSensors,
            )
          ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              if (_activeSubject != null)
                Card(
                  color: Colors.blue[50],
                  child: ListTile(
                    leading: const Icon(Icons.class_, color: Colors.blue),
                    title: Text("Class in Progress: $_activeSubject"),
                    subtitle: Text(
                        "Required Hotspot: '$_targetSSID'"),
                  ),
                )
             else 
                Card(
                  color: Colors.orange[50],
                  child: ListTile(
                    leading: const Icon(Icons.timer_off, color: Colors.orange),
                    title: const Text("No Active Class"),
                    subtitle: const Text("Waiting for faculty to start a session..."),
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
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: const Text("Logged in as"),
                        subtitle: Text(_username ?? "Loading...", style: const TextStyle(fontSize: 14)),
                      ),
                      const Divider(),
                      ListTile(
                        leading: Icon(Icons.wifi, color: _wifiName.contains("Scanning") ? Colors.orange : Colors.green),
                        title: const Text("Your Wi-Fi"),
                        subtitle: Text(_wifiName),
                      ),
                      const Divider(),
                       ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.redAccent),
                        title: const Text("GPS Location"),
                        subtitle: Text(_locationTxt),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _loadUserAndSensors,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh Sensors & Session"),
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
                      : Text(canMarkAttendance ? "MARK PRESENT" : "SCANNING / NOT IN RANGE", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              
              // Status Messages
              if (_activeSubject != null && !isFacultyHotspotAvailable)
                Text(
                  "Faculty hotspot '$_targetSSID' NOT detected.\nEnsure you are in the classroom.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                
              const SizedBox(height: 20),
              const Text("Nearby Networks:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(
                height: 200,
                child: _availableNetworks.isEmpty
                    ? const Center(child: Text("Scanning for networks..."))
                    : ListView.builder(
                        itemCount: _availableNetworks.length,
                        itemBuilder: (context, index) {
                          final network = _availableNetworks[index];
                          final isTarget = _targetSSID != null && network.ssid.toLowerCase() == _targetSSID!.toLowerCase();
                          return ListTile(
                            leading: Icon(isTarget ? Icons.check_circle : Icons.wifi, color: isTarget ? Colors.green : null),
                            title: Text(network.ssid),
                            subtitle: Text("${network.level} dBm"),
                            tileColor: isTarget ? Colors.green[50] : null,
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