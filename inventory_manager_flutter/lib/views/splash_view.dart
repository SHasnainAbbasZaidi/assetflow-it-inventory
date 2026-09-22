import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_manager_flutter/services/database_service.dart';
import 'dart:convert';
import 'login_view.dart';

class ElegantSplashView extends StatefulWidget {
  const ElegantSplashView({super.key});

  @override
  State<ElegantSplashView> createState() => _ElegantSplashViewState();
}

class _ElegantSplashViewState extends State<ElegantSplashView> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();

    // Hold the beautiful animation for 3.5 seconds, then transition to Dashboard
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginView()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final provider = Provider.of<InventoryProvider>(context);

    Widget logoWidget;
    if (provider.companyLogo.isNotEmpty) {
      try {
        final cleanStr = provider.companyLogo.contains(',') 
            ? provider.companyLogo.split(',')[1] 
            : provider.companyLogo;
        logoWidget = Image.memory(base64Decode(cleanStr), width: 56, height: 56, fit: BoxFit.contain);
      } catch (e) {
        logoWidget = Image.asset('assets/images/default_logo.png', width: 56, height: 56, fit: BoxFit.contain);
      }
    } else {
      logoWidget = Image.asset('assets/images/default_logo.png', width: 56, height: 56, fit: BoxFit.contain);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Perfect match with original app background
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Ambient background glow
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.08),
                      blurRadius: 120,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
            
            // Core Branding
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05), width: 1), // Fixed: Border.all used here
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.12),
                          blurRadius: 32,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: logoWidget,
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'AssetFlow',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      fontFamily: 'Inter',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'IT INVENTORY MANAGEMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3.5,
                      fontFamily: 'Inter',
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            
            // Thin Linear Progress Loader
            Positioned(
              bottom: 80,
              left: 40,
              right: 40,
              child: Column(
                children: [
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        backgroundColor: Colors.white.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        minHeight: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accessing inventory boxes...',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Inter',
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}