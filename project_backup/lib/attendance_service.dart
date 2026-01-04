import 'dart:convert';
import 'dart:io';  // VULN-019: For connectivity check
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();

  factory AttendanceService() {
    return _instance;
  }

  AttendanceService._internal();

  // Secure storage for JWT tokens
  final _storage = const FlutterSecureStorage();

  // Variables to hold state during the app session
  String? activeFacultySSID;
  String? activeClassName;
  
  // Server URLs
  final String _authBaseUrl = "https://attendance-automation-app-auth.onrender.com";
  final String _resourceBaseUrl = "https://attendance-automation-app.onrender.com";

  // ========== JWT Token Management ==========

  // Save both access and refresh tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  // Legacy method for backward compatibility
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<void> saveUsername(String username) async {
    await _storage.write(key: 'username', value: username);
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  Future<void> saveRole(String role) async {
    await _storage.write(key: 'user_role', value: role);
  }

  Future<String?> getRole() async {
    return await _storage.read(key: 'user_role');
  }

  Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null) return false;
    
    // Make a lightweight API call to verify token validity
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse("$_resourceBaseUrl/get_current_class?section=A"),
        headers: headers
      );
      // Token is valid if we don't get a 403 (forbidden) response
      return response.statusCode != 403;
    } catch (e) {
      print("Token validation error: $e");
      return false;
    }
  }

  // Refresh access token using refresh token
  Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;
    
    try {
      final response = await http.post(
        Uri.parse("$_authBaseUrl/refresh"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh_token": refreshToken}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
    } catch (e) {
      print("Refresh token error: $e");
    }
    
    return false;
  }

  Future<void> logout() async {
    // Revoke refresh token on server
    final refreshToken = await getRefreshToken();
    if (refreshToken != null) {
      try {
        await http.post(
          Uri.parse("$_authBaseUrl/logout"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"refresh_token": refreshToken}),
        );
      } catch (e) {
        print("Logout error: $e");
      }
    }
    
    // Clear local storage
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'user_role');
    activeFacultySSID = null;
    activeClassName = null;
  }

  // ========== Authentication (Auth Server) ==========

  // 1. Student Login
  Future<bool> login(String username, String password) async {
    final url = Uri.parse("$_authBaseUrl/check_student_login?username=$username&password=$password");
    
    try {
      final response = await http.post(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // New API returns both tokens
        await saveTokens(data['access_token'], data['refresh_token']);
        await saveUsername(username);
        return true;
      }
    } catch (e) {
      print("Login Error: $e");
    }
    return false;
  }

  // 1.5 Faculty Login
  Future<bool> facultyLogin(String username, String password) async {
    final url = Uri.parse("$_authBaseUrl/check_faculty_login?username=$username&password=$password");
    
    try {
      final response = await http.post(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // New API returns both tokens
        await saveTokens(data['access_token'], data['refresh_token']);
        await saveUsername(username);
        return true;
      }
    } catch (e) {
      print("Faculty Login Error: $e");
    }
    return false;
  }

  // ========== Resource API Calls (With JWT) ==========

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getToken();
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
    };
  }
  
  // VULN-019: Check network connectivity
  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        Duration(seconds: 3),
        onTimeout: () => [],
      );
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      // Access token expired - try to refresh
      print("Access token expired - attempting refresh");
      bool refreshed = await refreshAccessToken();
      
      if (refreshed) {
        print("Token refreshed successfully");
        return false; // Token refreshed, caller should retry the request
      } else {
        // Refresh failed - logout
        print("Token refresh failed - logging out");
        await logout();
        return true; // Logout happened
      }
    }
    return false; // No logout needed
  }

  // 2. Check for Active Session (Returns Subject Name or null)
  Future<String?> getActiveSession(String section) async {
    final url = Uri.parse("$_resourceBaseUrl/get_current_class?section=$section");
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.get(url, headers: headers);
      
      if (await _handleUnauthorized(response)) return null;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          activeClassName = data['subject'];
          return data['subject'];
        }
      }
    } catch (e) {
      print("Session Check Error: $e");
    }
    activeClassName = null;
    return null;
  }

  // 3. Get Target SSID (Security Check)
  Future<String?> getClassSSID(String section) async {
    final url = Uri.parse("$_resourceBaseUrl/get_class_ssid?section=$section");
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.get(url, headers: headers);
      
      if (await _handleUnauthorized(response)) return null;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        activeFacultySSID = data['ssid'];
        return data['ssid'];
      }
    } catch (e) {
      print("SSID Check Error: $e");
    }
    activeFacultySSID = null;
    return null;
  }

  // 3.5 Update Class SSID
  Future<bool> updateClassSSID(String section, String ssid) async {
    final url = Uri.parse("$_resourceBaseUrl/update_class_ssid");
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({"section": section, "ssid": ssid}),
      );
      
      if (await _handleUnauthorized(response)) return false;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Update SSID Error: $e");
    }
    return false;
  }

  // 3.6 Start Attendance Session (Returns OTP)
  Future<Map<String, dynamic>?> startSession(String section, String subject) async {
    final url = Uri.parse("$_resourceBaseUrl/start_attendance_session?section=$section&subject=$subject");
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.post(url, headers: headers);
      
      if (await _handleUnauthorized(response)) return null;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return {
            'status': true,
            'otp': data['otp'],
            'expires_at': data['expires_at'],
          };
        }
      }
    } catch (e) {
      print("Start Session Error: $e");
    }
    return null;
  }

  // 3.7 Stop Attendance Session
  Future<bool> stopSession(String section) async {
    final url = Uri.parse("$_resourceBaseUrl/stop_attendance_session?section=$section");
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.post(url, headers: headers);
      
      if (await _handleUnauthorized(response)) return false;
      
      if (response.statusCode == 200) {
        // The API returns status: False when stopped (session is no longer active)
        // So we just check if the request was successful
        return true; 
      }
    } catch (e) {
      print("Stop Session Error: $e");
    }
    return false;
  }

  // 4. Mark Attendance
  Future<bool> markAttendance({
    required String section,
    required String username, 
    required String subject,
    required String date,
    required String time
  }) async {
    // Construct URL with Query Parameters
    final queryParams = Uri(queryParameters: {
      "section": section,
      "username": username,
      "subject": subject,
      "date": date,
      "time": time,
    }).query;

    final url = Uri.parse("$_resourceBaseUrl/add_attendance?$queryParams");
    final headers = await _getAuthHeaders();

    try {
      final response = await http.post(url, headers: headers);
      
      if (await _handleUnauthorized(response)) return false;
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Marking Error: $e");
    }
    return false;
  }

  // 5. Verify OTP and Mark Attendance (New for Nearby Connections)
  Future<Map<String, dynamic>> verifyOTPAndMarkAttendance({
    required String section,
    required String username,
    required String otp,
    required String date,
    required String time,
  }) async {
    // VULN-019: Check connectivity first
    if (!await _checkConnectivity()) {
      return {
        'status': false,
        'message': '📡 No internet connection. Please check your network and try again.',
      };
    }
    
    final url = Uri.parse("$_resourceBaseUrl/verify_otp");
    final headers = await _getAuthHeaders();
    
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          "section": section,
          "username": username,
          "otp": otp,
          "date": date,
          "time": time,
        }),
      );
      
      if (await _handleUnauthorized(response)) {
        return {'status': false, 'message': 'Unauthorized - please login again'};
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': data['status'],
          'subject': data['subject'],
          'message': data['message'] ?? 'Success',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'status': false,
          'message': error['detail'] ?? 'Failed to verify OTP',
        };
      }
    } catch (e) {
      print("OTP Verification Error: $e");
      return {'status': false, 'message': 'Network error: $e'};
    }
  }
}
