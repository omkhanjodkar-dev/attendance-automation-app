import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class NearbyConnectionsService {
  final Nearby _nearby = Nearby();
  
  // Service ID for matching advertisers and discoverers
  static const String SERVICE_ID = "com.attendance.gnc";
  static const Strategy STRATEGY = Strategy.P2P_CLUSTER;
  
  // Connection state tracking
  final Map<String, String> _connectedEndpoints = {};
  final Set<String> _discoveredEndpoints = {};  // Track discovered to prevent duplicates
  final Set<String> _pendingConnections = {};   // Track pending connection requests
  int _maxConcurrentConnections = 1;  // Students connect to 1 faculty at a time
  int _maxFacultyConnections = 8;     // Faculty device connection limit
  String? _currentOTP;
  DateTime? _otpExpiresAt;  // VULN-007/016: Track OTP expiry
  Timer? _sessionValidationTimer;  // VULN-020: Periodic session validation
  
  // Callbacks
  Function(String otp)? onOtpReceived;
  Function(String endpointId, String endpointName)? onEndpointDiscovered;
  Function(String message)? onConnectionUpdate;
  Function(String errorMessage)? onError;
  
  // --- Faculty Methods (Advertiser) ---
  
  Future<bool> startAdvertising({
    required String facultyName,
    required String otp,
  }) async {
    try {
      _currentOTP = otp;
      
      // In v4.3.0, permission handling is built into startAdvertising
      // No need for separate permission checks
      
      await _nearby.startAdvertising(
        facultyName,
        STRATEGY,
        onConnectionInitiated: (String endpointId, ConnectionInfo info) {
          _onConnectionInitiated(endpointId, info);
        },
        onConnectionResult: (String endpointId, Status status) {
          _onConnectionResult(endpointId, status);
        },
        onDisconnected: (String endpointId) {
          _onDisconnected(endpointId);
        },
        serviceId: SERVICE_ID,
      );
      
      onConnectionUpdate?.call("Advertising started for $facultyName");
      
      // VULN-016: Schedule notification when OTP expires (10 minutes)
      _otpExpiresAt = DateTime.now().add(Duration(minutes: 10));
      _sessionValidationTimer = Timer(Duration(minutes: 10), () {
        onError?.call("⚠ OTP expired! Please restart the session.");
        stopAdvertising();
      });
      
      return true;
    } catch (e) {
      onError?.call("Failed to start advertising: $e");
      return false;
    }
  }
  
  /// Stop advertising
  Future<void> stopAdvertising() async {
    try {
      _sessionValidationTimer?.cancel();
      await _nearby.stopAdvertising();
      await _disconnectAll();
      _currentOTP = null;
      _otpExpiresAt = null;
      onConnectionUpdate?.call("Advertising stopped");
    } catch (e) {
      onError?.call(" Failed to stop advertising: $e");
    }
  }
  
  // --- Student Methods (Discoverer) ---
  
  /// Request all necessary permissions for Nearby Connections
  Future<bool> _requestPermissions() async {
    try {
      // For Android 13+ (API 33+), we need NEARBY_WIFI_DEVICES and Bluetooth permissions
      // For older versions, we need location permissions
      
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
        Permission.locationWhenInUse,
      ].request();
      
      // Check if all permissions are granted
      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (!allGranted) {
        // Find which permissions were denied
        List<String> deniedPermissions = [];
        statuses.forEach((permission, status) {
          if (!status.isGranted) {
            deniedPermissions.add(permission.toString().split('.').last);
          }
        });
        
        onError?.call("Permissions denied: ${deniedPermissions.join(', ')}");
        return false;
      }
      
      return true;
    } catch (e) {
      onError?.call("Permission request failed: $e");
      return false;
    }
  }
  
  /// Start discovering nearby faculty devices
  Future<bool> startDiscovery({
    required String studentName,
  }) async {
    try {
      // Request permissions first
      bool permissionsGranted = await _requestPermissions();
      if (!permissionsGranted) {
        onError?.call("Required permissions not granted. Please enable Bluetooth, WiFi, and Location permissions in Settings.");
        return false;
      }
      
      await _nearby.startDiscovery(
        studentName,
        STRATEGY,
        onEndpointFound: (String endpointId, String endpointName, String serviceId) {
          // VULN-022: Deduplicate endpoints (can be discovered multiple times)
          if (_discoveredEndpoints.contains(endpointId)) {
            return;  // Already discovered, ignore
          }
          _discoveredEndpoints.add(endpointId);
          
          onEndpointDiscovered?.call(endpointId, endpointName);
          
          // VULN-004 & VULN-018: Throttle connections (only 1 at a time for students)
          if (!_connectedEndpoints.containsKey(endpointId) && 
              !_pendingConnections.contains(endpointId) &&
              _connectedEndpoints.length < _maxConcurrentConnections) {
            _pendingConnections.add(endpointId);
            _requestConnection(endpointId, studentName);
          } else {
            onConnectionUpdate?.call("Already connected/connecting to a faculty");
          }
        },
        onEndpointLost: (String? endpointId) {
          if (endpointId != null) {
            _discoveredEndpoints.remove(endpointId);
            _pendingConnections.remove(endpointId);
          }
          onConnectionUpdate?.call("Lost connection with endpoint: $endpointId");
        },
        serviceId: SERVICE_ID,
      );
      
      onConnectionUpdate?.call("Discovering nearby faculty...");
      return true;
    } catch (e) {
      onError?.call("Failed to start discovery: $e");
      return false;
    }
  }
  
  /// Stop discovering
  Future<void> stopDiscovery() async {
    try {
      await _nearby.stopDiscovery();
      await _disconnectAll();
      _discoveredEndpoints.clear();
      _pendingConnections.clear();
      onConnectionUpdate?.call("Discovery stopped");
    } catch (e) {
      onError?.call("Failed to stop discovery: $e");
    }
  }
  
  // --- Connection Management ---
  
  void _requestConnection(String endpointId, String userName) async {
    try {
      await _nearby.requestConnection(
        userName,
        endpointId,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          _onConnectionInitiated(id, info);
        },
        onConnectionResult: (String id, Status status) {
          _onConnectionResult(id, status);
        },
        onDisconnected: (String id) {
          _onDisconnected(id);
        },
      );
    } catch (e) {
      // VULN-011: Handle connection errors properly
      _pendingConnections.remove(endpointId);
      
      // Provide actionable error messages
      String errorMsg = "Connection failed";
      if (e.toString().toLowerCase().contains("bluetooth")) {
        errorMsg = "Bluetooth connection failed. Please check Bluetooth is enabled.";
      } else if (e.toString().toLowerCase().contains("wifi")) {
        errorMsg = "WiFi Direct failed. Try moving closer to faculty.";
      } else {
        errorMsg = "Connection failed. Please try again.";
      }
      onError?.call(errorMsg);
    }
  }
  
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    try {
      // VULN-018: Faculty connection limit check
      if (_currentOTP != null && _connectedEndpoints.length >= _maxFacultyConnections) {
        // Faculty mode: reject if at limit
        await _nearby.rejectConnection(endpointId);
        onConnectionUpdate?.call("Connection limit reached. Student will retry.");
        return;
      }
      
      // Auto-accept connections
      await _nearby.acceptConnection(
        endpointId,
        onPayLoadRecieved: (endpointId, payload) {
          _onPayloadReceived(endpointId, payload);
        },
      );
      onConnectionUpdate?.call("Connection initiated with ${info.endpointName}");
    } catch (e) {
      onError?.call("Failed to accept connection: $e");
      _pendingConnections.remove(endpointId);
    }
  }
  
  void _onConnectionResult(String endpointId, Status status) async {
    _pendingConnections.remove(endpointId);  // Clear pending state
    
    if (status == Status.CONNECTED) {
      _connectedEndpoints[endpointId] = endpointId;
      onConnectionUpdate?.call("Connected to $endpointId");
      
      // If faculty, send OTP to student
      if (_currentOTP != null) {
        // VULN-007: Validate OTP hasn't expired before sending
        if (_otpExpiresAt != null && DateTime.now().isAfter(_otpExpiresAt!)) {
          onError?.call("Session expired. Please restart the session.");
          await stopAdvertising();
          return;
        }
        
        try {
          _sendOTP(endpointId, _currentOTP!);  // Now synchronous
          onConnectionUpdate?.call("OTP sent successfully to $endpointId");
          
          // VULN-018: Faculty can disconnect after sending OTP to free slot
          // Uncomment this line to disconnect immediately after OTP sent:
          // Timer(Duration(seconds: 2), () => _nearby.disconnectFromEndpoint(endpointId));
        } catch (e) {
          onError?.call("Failed to send OTP after connection: $e");
        }
      }
    } else {
      onConnectionUpdate?.call("Connection failed with $endpointId");
    }
  }
  
  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    _pendingConnections.remove(endpointId);
    onConnectionUpdate?.call("Disconnected from $endpointId");
  }
  
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES && payload.bytes != null) {
      try {
        String receivedData = String.fromCharCodes(payload.bytes!);
        
        // Try new JSON protocol first
        try {
          final data = jsonDecode(receivedData) as Map<String, dynamic>;
          
          if (data['type'] == 'OTP' && data['otp'] != null) {
            String otp = data['otp'].toString();
            
            // Validate OTP format (6 alphanumeric characters)
            if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(otp)) {
              // Verify checksum if present
              if (data['checksum'] != null) {
                String expectedChecksum = _calculateChecksum(otp);
                if (data['checksum'] != expectedChecksum) {
                  onError?.call("OTP checksum verification failed");
                  return;
                }
              }
              
              onOtpReceived?.call(otp);
              onConnectionUpdate?.call("Received OTP: $otp");
            } else {
              onError?.call("Received invalid OTP format: $otp");
            }
          }
        } catch (e) {
          // Fallback to legacy "OTP:" format for backward compatibility
          if (receivedData.startsWith("OTP:") && receivedData.length > 4) {
            String otp = receivedData.substring(4).trim();
            
            if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(otp)) {
              onOtpReceived?.call(otp);
              onConnectionUpdate?.call("Received OTP: $otp");
            } else {
              onError?.call("Received invalid OTP format");
            }
          } else {
            print("Received non-OTP payload: $receivedData");
          }
        }
      } catch (e) {
        onError?.call("Failed to process received data: $e");
      }
    } else if (payload.type != PayloadType.BYTES) {
      print("Ignoring non-BYTES payload type: ${payload.type}");
    }
  }
  
  void _sendOTP(String endpointId, String otp) {
    try {
      // Enhanced protocol with JSON structure
      final message = jsonEncode({
        'type': 'OTP',
        'version': '1.0',
        'otp': otp,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'checksum': _calculateChecksum(otp),
      });
      
      // In v4.3.0, sendBytesPayload is synchronous (void)
      _nearby.sendBytesPayload(endpointId, Uint8List.fromList(message.codeUnits));
      onConnectionUpdate?.call("Sent OTP to $endpointId");
    } catch (e) {
      onError?.call("Failed to send OTP: $e");
    }
  }
  
  String _calculateChecksum(String data) {
    // Simple checksum: sum of character codes modulo 1000
    int sum = 0;
    for (int i = 0; i < data.length; i++) {
      sum += data.codeUnitAt(i);
    }
    return (sum % 1000).toString().padLeft(3, '0');
  }
  
  Future<void> _disconnectAll() async {
    List<String> failedDisconnects = [];
    
    for (String endpointId in _connectedEndpoints.keys) {
      try {
        await _nearby.disconnectFromEndpoint(endpointId);
      } catch (e) {
        // VULN-012: Log disconnect failures instead of silently ignoring
        failedDisconnects.add(endpointId);
        print("Failed to disconnect $endpointId: $e");
      }
    }
    _connectedEndpoints.clear();
    
    if (failedDisconnects.isNotEmpty && onError != null) {
      onError!("Warning: ${failedDisconnects.length} connection(s) may still be active");
    }
  }
  
  // Getters
  int get connectedCount => _connectedEndpoints.length;
  bool get isConnected => _connectedEndpoints.isNotEmpty;
  
  // Cleanup
  Future<void> dispose() async {
    _sessionValidationTimer?.cancel();
    await stopAdvertising();
    await stopDiscovery();
  }
}
