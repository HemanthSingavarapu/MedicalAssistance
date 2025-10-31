import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF4361EE);
    const Color secondaryColor = Color(0xFF3F37C9);
    const Color accentColor = Color(0xFF4CC9F0);
    const Color backgroundColor = Color(0xFFF8F9FA);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Health Companion',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Animate(
            delay: 300.ms,
            effects: [FadeEffect(), SlideEffect(begin: Offset(0.2, 0))],
            child: IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundColor, Colors.white],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  _buildAnimatedHeader(context, primaryColor),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            _buildSliverSection(
              title: "Daily Health Tips",
              icon: Icons.health_and_safety,
              child: _buildHealthTips(),
              delay: 200,
            ),
            _buildSliverSection(
              title: "Emergency Contacts (India)",
              icon: Icons.emergency,
              child: _buildEmergencyContacts(),
              delay: 400,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(BuildContext context, Color primaryColor) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Column(
      children: [
        Animate(
          effects: [
            FadeEffect(duration: 600.ms),
            ScaleEffect(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack)
          ],
          child: Container(
            height: screenHeight * 0.25,
            width: MediaQuery.of(context).size.width * 0.85,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 3,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Lottie.asset(
                'assets/images/medi.json',
                width: MediaQuery.of(context).size.width * 0.7,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Animate(
                effects: [
                  FadeEffect(duration: 800.ms),
                  SlideEffect(begin: const Offset(0, -10), curve: Curves.easeOutCubic),
                ],
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade800,
                      height: 1.6,
                    ),
                    children: const [
                      TextSpan(
                        text: "Your Personal ",
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                      TextSpan(
                        text: "Health Assistant\n",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4361EE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Animate(
                effects: [
                  FadeEffect(duration: 800.ms),
                  SlideEffect(begin: const Offset(0, 10), curve: Curves.easeOutCubic),
                ],
                child: const Text(
                  "AI-powered health guidance at your fingertips",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  SliverToBoxAdapter _buildSliverSection({
    required String title,
    required IconData icon,
    required Widget child,
    required int delay,
  }) {
    return SliverToBoxAdapter(
      child: Animate(
        delay: delay.ms,
        effects: [FadeEffect(), SlideEffect(begin: const Offset(0, 0.1))],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4361EE).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: const Color(0xFF4361EE), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4361EE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTips() {
    final tips = [
      {
        'tip': 'Drink 2-3 liters of water daily',
        'icon': Icons.water_drop,
        'color': const Color(0xFF4CC9F0)
      },
      {
        'tip': '7-8 hours of quality sleep',
        'icon': Icons.nightlight_round,
        'color': const Color(0xFF7209B7)
      },
      {
        'tip': '30 mins daily exercise',
        'icon': Icons.directions_run,
        'color': const Color(0xFFF72585)
      },
      {
        'tip': 'Balanced diet with fruits',
        'icon': Icons.food_bank,
        'color': const Color(0xFF4895EF)
      },
      {
        'tip': 'Practice stress-relief',
        'icon': Icons.self_improvement,
        'color': const Color(0xFF3A0CA3)
      },
    ];

    return Column(
      children: tips
          .map(
            (tip) => Animate(
          delay: Duration(milliseconds: tips.indexOf(tip) * 100),
          effects: [FadeEffect(), SlideEffect(begin: const Offset(0.2, 0))],
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (tip['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(tip['icon'] as IconData,
                          color: tip['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        tip['tip'] as String,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (tip['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: tip['color'] as Color,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  Widget _buildEmergencyContacts() {
    final contacts = [
      {
        'name': 'National Emergency',
        'number': '112',
        'color': const Color(0xFFEF233C),
        'icon': Icons.security
      },
      {
        'name': 'Police',
        'number': '100',
        'color': const Color(0xFF4361EE),
        'icon': Icons.local_police
      },
      {
        'name': 'Ambulance',
        'number': '108',
        'color': const Color(0xFF06D6A0),
        'icon': Icons.medical_services
      },
      {
        'name': 'Disaster Management',
        'number': '1078',
        'color': const Color(0xFFFF9E00),
        'icon': Icons.warning
      },
      {
        'name': 'Women Helpline',
        'number': '1091',
        'color': const Color(0xFF7209B7),
        'icon': Icons.female
      },
    ];

    return Column(
      children: contacts
          .map(
            (contact) => Animate(
          delay: Duration(milliseconds: contacts.indexOf(contact) * 100 + 200),
          effects: [FadeEffect(), SlideEffect(begin: const Offset(0.2, 0))],
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _makeEmergencyCall(contact['number'] as String),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (contact['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(contact['icon'] as IconData,
                          color: contact['color'] as Color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact['name'] as String,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact['number'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (contact['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.call,
                        color: contact['color'] as Color,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  Future<void> _makeEmergencyCall(String number) async {
    final url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
