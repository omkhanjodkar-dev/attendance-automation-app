import 'package:attendance_automation/attendance_service.dart';
import 'package:attendance_automation/student_settings_screen.dart';
import 'package:attendance_automation/nearby_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _statusTxt = "Initializing...";
  String _locationTxt = "Waiting...";
  String _deviceId = "Unknown";
  
  // List of discovered faculty devices
  final Set<String> _foundClasses = {};
  final Map<String, String> _lastSeenOtp = {};
  
  bool _isLoading = false;
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
    NearbyService().stopDiscovery();
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
    // Check Permissions
    bool hasPerms = await NearbyService().checkPermissions();
    if (!hasPerms) {
        setState(() => _statusTxt = "Permissions Missing");
        return;
    }

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

    _startScanning();
  }

  Future<void> _startScanning() async {
    setState(() => _statusTxt = "Scanning for Class...");
    
    // Get Location for UI (Optional, but good for verification)
    try {
        Position pos = await Geolocator.getCurrentPosition();
        if (mounted) setState(() => _locationTxt = "Lat: ${pos.latitude.toStringAsFixed(4)}\nLng: ${pos.longitude.toStringAsFixed(4)}");
    } catch (e) {
        // Ignore location errors for now, not critical for Nearby
    }

    // Start Nearby Discovery
    await NearbyService().startDiscoveryForStudent(
        (endpointId, endpointName) {
            // Found a device
            print("Found Encrypted Beacon: $endpointName");
            if (endpointName.startsWith("Class_")) {
                // Expected format: Class_<Subject>_<OTP>
                final parts = endpointName.split("_");
                if (parts.length >= 3) {
                    String className = parts[1];
                    String otp = parts[2];
                    
                    if (mounted) {
                        setState(() {
                            _foundClasses.add(className);
                            // Store the OTP for this class (using a Map would be better, but for MVP we can use a separate Map or just assuming one class active)
                            _lastSeenOtp[className] = otp; 
                            _statusTxt = "Found Class: $className";
                        });
                    }
                }
            }
        },
        (endpointId) {
            // Lost a device
        }
    );
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
    
    String? otp = _lastSeenOtp[_activeSubject];
    if (otp == null) {
        // Should not happen if validation passed, but safety check
        setState(() => _isLoading = false);
        return;
    }

    bool success = await _attendanceService.markAttendance(
        section: "A", // Hardcoded for MVP
        username: _username!, 
        subject: _activeSubject!, 
        date: dateStr, 
        time: timeStr,
        otp: otp
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
    // 1. Check if the active subject is in the found classes list
    bool isClassaconFound = false;
    if (_activeSubject != null) {
        isClassaconFound = _foundClasses.contains(_activeSubject);
    }

    bool canMarkAttendance = !_isLoading && isClassaconFound && _activeSubject != null;

    return Scaffold(
      appBar: AppBar(
          title: const Text("Student Dashboard"),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadUserAndSensors,
            ),
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
                      : Text(canMarkAttendance ? "MARK PRESENT" : "ATTENDANCE DISABLED...", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              
              // Status Messages
              if (_activeSubject != null && !isClassaconFound)
                Text(
                  "Ensure that you are in the classroom.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                

            ],
          ),
        ),
      ),
    );
  }
}