import 'package:flutter/material.dart';
import 'package:attendance_automation/attendance_service.dart';

class FacultySettingsScreen extends StatefulWidget {
  const FacultySettingsScreen({super.key});

  @override
  State<FacultySettingsScreen> createState() => _FacultySettingsScreenState();
}

class _FacultySettingsScreenState extends State<FacultySettingsScreen> {
  final TextEditingController _ssidController = TextEditingController();

  bool _isLoading = false;
  final AttendanceService _attendanceService = AttendanceService();

  @override
  void initState() {
    super.initState();
    _loadSSID();
  }

  Future<void> _loadSSID() async {
    setState(() => _isLoading = true);
    // Hardcoded section 'A' for MVP
    String? ssid = await _attendanceService.getClassSSID("A");
    setState(() {
      _ssidController.text = ssid ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSSID() async {
    setState(() => _isLoading = true);
    // Hardcoded section 'A' for MVP
    bool success = await _attendanceService.updateClassSSID("A", _ssidController.text.trim());
    
    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotspot Name (SSID) saved to cloud successfully')),
        );
        Navigator.pop(context, true); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save SSID. Network Error.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Enter your device\'s Hotspot Name (SSID) to be used for attendance verification.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'Hotspot Name (SSID)',
                border: OutlineInputBorder(),
                hintText: 'e.g. MyClassRoom',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSSID,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save to Cloud'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
