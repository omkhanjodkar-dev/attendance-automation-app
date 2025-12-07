import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FacultySettingsScreen extends StatefulWidget {
  const FacultySettingsScreen({super.key});

  @override
  State<FacultySettingsScreen> createState() => _FacultySettingsScreenState();
}

class _FacultySettingsScreenState extends State<FacultySettingsScreen> {
  final TextEditingController _ssidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSSID();
  }

  Future<void> _loadSSID() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ssidController.text = prefs.getString('faculty_ssid') ?? '';
    });
  }

  Future<void> _saveSSID() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('faculty_ssid', _ssidController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotspot Name (SSID) saved successfully')),
      );
      Navigator.pop(context, true); // Return true to indicate changes
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
                onPressed: _saveSSID,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
