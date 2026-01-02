import 'dart:async';
import 'package:flutter/services.dart';
import 'package:nearby_connections/nearby_connections.dart';

class NearbyConnectionsService {
  final Nearby _nearby = Nearby();
  
  // Service ID for matching advertisers and discoverers
  static const String SERVICE_ID = "com.attendance.gnc";
  static const Strategy STRATEGY = Strategy.P2P_CLUSTER;
  
  // Connection state tracking
  final Map<String, String> _connectedEndpoints = {};
  String? _currentOTP;
  
  // Callbacks
  Function(String otp)? onOtpReceived;
  Function(String endpointId, String endpointName)? onEndpointDiscovered;
  Function(String message)? onConnectionUpdate;
  Function(String errorMessage)? onError;
  
  // --- Faculty Methods (Advertiser) ---
  
  /// Start advertising as faculty with OTP
  Future<bool> startAdvertising({
    required String facultyName,
    required String otp,
  }) async {
    try {
      _currentOTP = otp;
      
      bool permissionGranted = await _nearby.checkBluetoothPermissions();
      if (!permissionGranted) {
        onError?.call("Bluetooth permissions not granted");
        return false;
      }
      
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
      return true;
    } catch (e) {
      onError?.call("Failed to start advertising: $e");
      return false;
    }
  }
  
  /// Stop advertising
  Future<void> stopAdvertising() async {
    try {
      await _nearby.stopAdvertising();
      await _disconnectAll();
      _currentOTP = null;
      onConnectionUpdate?.call("Advertising stopped");
    } catch (e) {
      onError?.call("Failed to stop advertising: $e");
    }
  }
  
  // --- Student Methods (Discoverer) ---
  
  /// Start discovering nearby faculty devices
  Future<bool> startDiscovery({
    required String studentName,
  }) async {
    try {
      bool permissionGranted = await _nearby.checkBluetoothPermissions();
      if (!permissionGranted) {
        onError?.call("Bluetooth permissions not granted");
        return false;
      }
      
      await _nearby.startDiscovery(
        studentName,
        STRATEGY,
        onEndpointFound: (String endpointId, String endpointName, String serviceId) {
          onEndpointDiscovered?.call(endpointId, endpointName);
          // Auto-connect to discovered faculty
          _requestConnection(endpointId, studentName);
        },
        onEndpointLost: (String? endpointId) {
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
      onError?.call("Failed to request connection: $e");
    }
  }
  
  void _onConnectionInitiated(String endpointId, ConnectionInfo info) async {
    try {
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
    }
  }
  
  void _onConnectionResult(String endpointId, Status status) {
    if (status == Status.CONNECTED) {
      _connectedEndpoints[endpointId] = endpointId;
      onConnectionUpdate?.call("Connected to $endpointId");
      
      // If faculty, send OTP to student
      if (_currentOTP != null) {
        _sendOTP(endpointId, _currentOTP!);
      }
    } else {
      onConnectionUpdate?.call("Connection failed with $endpointId");
    }
  }
  
  void _onDisconnected(String endpointId) {
    _connectedEndpoints.remove(endpointId);
    onConnectionUpdate?.call("Disconnected from $endpointId");
  }
  
  void _onPayloadReceived(String endpointId, Payload payload) {
    if (payload.type == PayloadType.BYTES) {
      String receivedData = String.fromCharCodes(payload.bytes!);
      
      // Parse OTP from received data
      if (receivedData.startsWith("OTP:")) {
        String otp = receivedData.substring(4);
        onOtpReceived?.call(otp);
        onConnectionUpdate?.call("Received OTP: $otp");
      }
    }
  }
  
  void _sendOTP(String endpointId, String otp) async {
    try {
      String data = "OTP:$otp";
      await _nearby.sendBytesPayload(endpointId, Uint8List.fromList(data.codeUnits));
      onConnectionUpdate?.call("Sent OTP to $endpointId");
    } catch (e) {
      onError?.call("Failed to send OTP: $e");
    }
  }
  
  Future<void> _disconnectAll() async {
    for (String endpointId in _connectedEndpoints.keys) {
      try {
        await _nearby.disconnectFromEndpoint(endpointId);
      } catch (e) {
        // Ignore errors during mass disconnect
      }
    }
    _connectedEndpoints.clear();
  }
  
  // Getters
  int get connectedCount => _connectedEndpoints.length;
  bool get isConnected => _connectedEndpoints.isNotEmpty;
  
  // Cleanup
  void dispose() {
    stopAdvertising();
    stopDiscovery();
  }
}
