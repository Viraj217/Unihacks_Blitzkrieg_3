import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../routes/app_routes.dart';
import '../../utils/app_colors.dart';

class BemeLandingAnimationPage extends StatefulWidget {
  const BemeLandingAnimationPage({super.key});

  @override
  State<BemeLandingAnimationPage> createState() =>
      _BemeLandingAnimationPageState();
}

class _BemeLandingAnimationPageState extends State<BemeLandingAnimationPage>
    with TickerProviderStateMixin {
  late AnimationController _bemeController;
  late Animation<double> _bemeOpacity;
  late Animation<double> _bemeScale;
  late Animation<double> _bemeGlow;

  late AnimationController _uiController;
  late Animation<double> _uiOpacity;
  late Animation<Offset> _uiSlide;

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Video
    _videoController =
        VideoPlayerController.asset('assets/animation/animation_video.mp4')
          ..initialize()
              .then((_) {
                _videoController.setLooping(true);
                _videoController.play();
                if (mounted) {
                  setState(() {
                    _isVideoInitialized = true;
                  });
                }
              })
              .catchError((error) {
                debugPrint("Video initialization failed: $error");
              });

    // 2. Initialize Beme Animation with enhanced effects
    _bemeController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _bemeOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _bemeController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );

    _bemeScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _bemeController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _bemeGlow = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(
        parent: _bemeController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    // 3. Initialize UI (Buttons) Animation with slide effect
    _uiController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _uiOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _uiController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _uiSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _uiController,
            curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
          ),
        );

    // 4. Start Animation Sequence
    _bemeController.forward().then((_) {
      // Hold the "Beme" text for a moment
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          // Fade out Beme smoothly
          _bemeController.reverse(from: 1.0).then((_) {
            // Show UI after Beme fades out
            if (mounted) {
              _uiController.forward();
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _bemeController.dispose();
    _uiController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Video with smooth fade-in
          AnimatedOpacity(
            opacity: _isVideoInitialized ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 800),
            child: _isVideoInitialized
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // 2. Multi-layer Gradient Overlay for depth
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.9),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // 3. Enhanced Beme Text Animation with glow effect
          Center(
            child: AnimatedBuilder(
              animation: _bemeController,
              builder: (context, child) {
                return Opacity(
                  opacity: _bemeOpacity.value,
                  child: Transform.scale(
                    scale: _bemeScale.value,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.white.withOpacity(0.9),
                          AppTheme.primaryPurple.withOpacity(0.3),
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'Beme',
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4.0,
                          shadows: [
                            Shadow(
                              blurRadius: _bemeGlow.value,
                              color: AppTheme.primaryPurple.withOpacity(0.6),
                            ),
                            Shadow(
                              blurRadius: _bemeGlow.value * 2,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 4. Bottom UI with glassmorphism and staggered animations
          AnimatedBuilder(
            animation: _uiController,
            builder: (context, child) {
              return Opacity(
                opacity: _uiOpacity.value,
                child: IgnorePointer(
                  ignoring: _uiOpacity.value < 0.5,
                  child: SlideTransition(
                    position: _uiSlide,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32.0,
                          vertical: 56.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Welcome text with glassmorphism container
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Welcome to Beme',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                          shadows: [
                                            Shadow(
                                              blurRadius: 8,
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Connect, share moments, and be real',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white.withOpacity(0.85),
                                          letterSpacing: 0.3,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Login Button - Primary
                            _buildGlassButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.login);
                              },
                              text: 'Log In',
                              isPrimary: true,
                            ),

                            const SizedBox(height: 16),

                            // Sign Up Button - Secondary
                            _buildGlassButton(
                              onPressed: () {
                                Navigator.pushNamed(context, AppRoutes.signup);
                              },
                              text: 'Sign Up',
                              isPrimary: false,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required VoidCallback onPressed,
    required String text,
    required bool isPrimary,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            gradient: isPrimary
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.95),
                      Colors.white.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppTheme.primaryPurple.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(30),
              splashColor: isPrimary
                  ? AppTheme.primaryPurple.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isPrimary ? AppTheme.primaryPurple : Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
