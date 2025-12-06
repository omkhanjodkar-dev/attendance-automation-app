class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();

  factory AttendanceService() {
    return _instance;
  }

  AttendanceService._internal();

  String? activeFacultyHotspotBSSID;
  String? activeClassName;
}
