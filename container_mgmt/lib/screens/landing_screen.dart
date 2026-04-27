import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;

  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;
  late Animation<double> _floatAnim;
  late Animation<double> _shimmerAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _shimmerAnim = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // ── Rich gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF062808),
                  Color(0xFF0A3D0C),
                  Color(0xFF0B560D),
                  Color(0xFF093A0B),
                  Color(0xFF051D06),
                ],
                stops: [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
            ),
          ),

          // ── Grid + dot background ─────────────────────────────────────────
          Positioned.fill(child: CustomPaint(painter: _BackgroundPainter())),

          // ── Top-right decorative glow ─────────────────────────────────────
          Positioned(
            top: -size.height * 0.18,
            right: -size.width * 0.22,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.yellow.withOpacity(0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom-left decorative glow ───────────────────────────────────
          Positioned(
            bottom: -size.height * 0.12,
            left: -size.width * 0.18,
            child: Container(
              width: size.width * 0.55,
              height: size.width * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.yellow.withOpacity(0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                animation: _slideAnim,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Floating logo
                        AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (ctx, child) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: child,
                          ),
                          child: _buildLogo(),
                        ),

                        const SizedBox(height: 30),

                        // Brand name
                        const Text(
                          'GOTHONG SOUTHERN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.yellow,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                            letterSpacing: 4,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Subtitle badge
                        _buildBadge('Container Management System'),

                        const SizedBox(height: 14),

                        // Description
                        Text(
                          'Streamline port operations with real-time\ncontainer tracking and yard management.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13.5,
                            height: 1.65,
                            letterSpacing: 0.3,
                          ),
                        ),

                        const SizedBox(height: 44),

                        // CTA button
                        _buildGetStartedButton(context),

                        const SizedBox(height: 20),

                        // Footer
                        Text(
                          '© 2026 Gothong Southern  ·  All rights reserved',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.28),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outermost ring
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (ctx, child) =>
              Transform.scale(scale: _pulseAnim.value, child: child),
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.yellow.withOpacity(0.10),
                width: 1,
              ),
            ),
          ),
        ),
        // Middle ring
        Container(
          width: 124,
          height: 124,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.yellow.withOpacity(0.22),
              width: 1.5,
            ),
          ),
        ),
        // Logo circle
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.yellow,
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withOpacity(0.45),
                blurRadius: 36,
                spreadRadius: 6,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/gothong_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.directions_boat_filled,
                  size: 48,
                  color: AppColors.green,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.yellow.withOpacity(0.18),
            AppColors.yellow.withOpacity(0.07),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.yellow.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.yellow,
          fontSize: 12.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildGetStartedButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (ctx, child) {
        return Container(
          width: 240,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _shimmerAnim.value, 0),
              end: Alignment(1.5 + _shimmerAnim.value, 0),
              colors: const [
                Color(0xFFCC9900),
                Color(0xFFFFD300),
                Color(0xFFFFF176),
                Color(0xFFFFD300),
                Color(0xFFCC9900),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.yellow.withOpacity(0.55),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => const LoginScreen(),
                  transitionsBuilder: (_, anim, _, child) =>
                      FadeTransition(opacity: anim, child: child),
                  transitionDuration: const Duration(milliseconds: 400),
                ),
              ),
              splashColor: Colors.white.withOpacity(0.2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'GET STARTED',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 2.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.green,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Background painter ────────────────────────────────────────────────────────

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;

    const step = 52.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Subtle dots at intersections
    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.4, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
