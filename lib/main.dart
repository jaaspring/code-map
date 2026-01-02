import 'screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';

bool isBackendReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load environment variables
  await dotenv.load(fileName: 'assets/.env');

  // initialize Firebase
  await Firebase.initializeApp();

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
    return MaterialApp(
      title: 'CodeMap: Navigate Your IT Future',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SplashScreen(), // set SplashScreen as the starting screen
      debugShowCheckedModeBanner: false, // disable the debug banner
    );
  }
}
