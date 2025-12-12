import 'package:codemapv1/screens/welcome_page.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MyApp()); // Run the app
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodeMap',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WelcomePage(), // Set SplashScreen as the starting screen
      debugShowCheckedModeBanner: false, // Disable the debug banner
    );
  }
}
