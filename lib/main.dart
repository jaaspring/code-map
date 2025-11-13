import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';
import 'screens/educational_background_test/educational_background_screen.dart';

bool isBackendReady = false;

Future<void> main() async {
  // load environment variables before the app starts
  await dotenv.load(fileName: 'assets/.env');

  // pre-warm backend
  await _preWarmBackend();

  runApp(const MyApp());
}

Future<void> _preWarmBackend() async {
  try {
    print("Checking backend health at: ${ApiService.baseUrl}/health");
    final response = await http
        .get(Uri.parse("${ApiService.baseUrl}/health"))
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      isBackendReady = true;
      print("Backend is ready! Response: ${response.body}");
    } else {
      print("Backend responded but with status code: ${response.statusCode}");
    }
  } catch (e) {
    print("Backend not ready yet: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'CodeMap: Navigate Your IT Future',
      home: EducationalBackgroundTestScreen(),
    );
  }
}
