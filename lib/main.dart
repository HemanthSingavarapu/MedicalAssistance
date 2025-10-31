import 'package:flutter/material.dart';
import 'package:doctor/screens/intro.dart';

void main() {
  runApp(const MedicalAssistantApp());
}

class MedicalAssistantApp extends StatelessWidget {
  const MedicalAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const IntroScreen(),
    );
  }
}