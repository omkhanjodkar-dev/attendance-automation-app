import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

class NearbyService {
  static final NearbyService _instance = NearbyService._internal();

  factory NearbyService() {
    return _instance;
  }

  NearbyService._internal();

  final Strategy _strategy = Strategy.P2P_STAR;

  // --- Permissions ---
  Future<bool> checkPermissions() async {
    // Android 12+ requires specific bluetooth permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });
    
    return allGranted;
  }

  // --- Faculty: Advertising ---
  Future<bool> startAdvertisingForFaculty(String uniqueToken) async {
    try {
      // "ProximityToken:1234"
      String nickName = uniqueToken; 
      
      bool advertising = await Nearby().startAdvertising(
        nickName,
        _strategy,
        onConnectionInitiated: (String id, ConnectionInfo info) {
          // Verify authentication token here if needed
          // For this attendance use case, we might not even need to accept the connection.
          // The student just needs to see the "Found" device with the token.
          // However, to be robust, we can accept.
          // Nearby().acceptConnection(id, onPayLoadRecieved: (endpointId, payload) {});
        },
        onConnectionResult: (String id, Status status) {
          // Handled
        },
        onDisconnected: (String id) {
          // Handled
        },
        serviceId: "com.college.attendance", // Must match Manifest (if we added it there, mostly for discovery)
      );
      return advertising;
    } catch (e) {
      print("Error advertising: $e");
      return false;
    }
  }

  Future<void> stopAdvertising() async {
    await Nearby().stopAdvertising();
  }

  // --- Student: Discovery ---
  // Callback for when a device is found
  // Returns the Discovered Endpoint ID and Info
  Future<bool> startDiscoveryForStudent(
    Function(String endpointId, String endpointName) onDeviceFound,
    Function(String? endpointId) onDeviceLost,
  ) async {
    try {
      bool discovering = await Nearby().startDiscovery(
        "Student", // UserNickName 
        _strategy,
        onEndpointFound: (String id, String userName, String serviceId) {
            // Check if this is our app's service
            if (serviceId == "com.college.attendance") {
                onDeviceFound(id, userName);
            }
        },
        onEndpointLost: (String? id) {
            onDeviceLost(id);
        },
        serviceId: "com.college.attendance",
      );
      return discovering;
    } catch (e) {
      print("Error discovering: $e");
      return false;
    }
  }

  Future<void> stopDiscovery() async {
    await Nearby().stopDiscovery();
  }
  
  // Clean up everyone
  Future<void> stopAllEndpoints() async {
    await Nearby().stopAllEndpoints();
  }
}
