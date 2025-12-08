import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();

  factory AttendanceService() {
    return _instance;
  }

  AttendanceService._internal();

  // Variables to hold state during the app session
  String? activeFacultySSID;
  String? activeClassName;
  
  // The Base URL for the Render Backend
  final String _baseUrl = "https://attendance-automation-app.onrender.com";

  // 1. Student Login
  Future<bool> login(String username, String password) async {
    final url = Uri.parse("$_baseUrl/check_student_login?username=$username&password=$password");
    
    try {
      final response = await http.post(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Login Error: $e");
    }
    return false;
  }

  // 1.5 Faculty Login
  Future<bool> facultyLogin(String username, String password) async {
    final url = Uri.parse("$_baseUrl/check_faculty_login?username=$username&password=$password");
    
    try {
      final response = await http.post(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Faculty Login Error: $e");
    }
    return false;
  }

  // 2. Check for Active Session (Returns Subject Name or null)
  Future<String?> getActiveSession(String section) async {
    final url = Uri.parse("$_baseUrl/get_current_class?section=$section");
    
    try {
      final response = await http.get(url);
      
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
    final url = Uri.parse("$_baseUrl/get_class_ssid?section=$section");
    
    try {
      final response = await http.get(url);
      
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
    final url = Uri.parse("$_baseUrl/update_class_ssid");
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"section": section, "ssid": ssid}),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Update SSID Error: $e");
    }
    return false;
  }

  // 3.6 Start Attendance Session
  Future<bool> startSession(String section, String subject) async {
    final url = Uri.parse("$_baseUrl/start_attendance_session?section=$section&subject=$subject");
    
    try {
      final response = await http.post(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Start Session Error: $e");
    }
    return false;
  }

  // 3.7 Stop Attendance Session
  Future<bool> stopSession(String section) async {
    final url = Uri.parse("$_baseUrl/stop_attendance_session?section=$section");
    
    try {
      final response = await http.post(url);
      
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
    // Note: Our backend expects query params for this MVP endpoint 
    // based on how we wrote main.py:
    // async def add_attendance(section, username, ...) 
    
    // Construct URL with Query Parameters
    final queryParams = Uri(queryParameters: {
      "section": section,
      "username": username,
      "subject": subject,
      "date": date,
      "time": time,
    }).query;

    final url = Uri.parse("$_baseUrl/add_attendance?$queryParams");

    try {
      final response = await http.post(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == true;
      }
    } catch (e) {
      print("Marking Error: $e");
    }
    return false;
  }
}
