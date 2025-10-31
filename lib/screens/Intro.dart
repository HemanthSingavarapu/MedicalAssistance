import 'dart:async';
import 'package:flutter/material.dart';
import 'Home.dart';
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _dotsCount = 0;

  @override
  void initState() {
    super.initState();

    // Heartbeat animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Dot loading animation
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _dotsCount = (_dotsCount + 1) % 4;
        });
      }
    });

    // Navigation timer
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get loadingText {
    return 'Loading please wait a moment${'.' * _dotsCount}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _animation,
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.medical_services,
                        size: 60,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Health Companion',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your personal health assistant',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Heartbeat line animation
                  CustomPaint(
                    painter: HeartbeatPainter(_controller),
                    size: const Size(150, 40),
                  ),
                  const SizedBox(height: 20),
                  // Dynamic loading text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      loadingText,
                      key: ValueKey<String>(loadingText),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HeartbeatPainter extends CustomPainter {
  final Animation<double> animation;

  HeartbeatPainter(AnimationController controller)
      : animation = Tween(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
    ),
  ),
        super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final width = size.width;
    final height = size.height / 2;

    // Create heartbeat path
    path.moveTo(0, height);
    path.lineTo(width * 0.2, height);
    path.lineTo(width * 0.25, height - height * 0.8 * animation.value);
    path.lineTo(width * 0.3, height);
    path.lineTo(width * 0.35, height - height * 0.6 * animation.value);
    path.lineTo(width * 0.4, height);
    path.lineTo(width * 0.6, height);
    path.lineTo(width * 0.65, height - height * 0.8 * animation.value);
    path.lineTo(width * 0.7, height);
    path.lineTo(width, height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(HeartbeatPainter oldDelegate) => true;
}