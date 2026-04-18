import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

/// Global offline/online banner.
///
/// Previously had a bug where going offline→online hid the banner
/// immediately (setState set `_showBanner = !online`), so the "Back
/// online" confirmation never rendered. Now we keep the banner up
/// briefly after reconnect and animate it in/out.
class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOnline = true;
  bool _showBanner = false;
  Timer? _hideTimer;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _connect() {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online == _isOnline) return;
      _applyState(online);
    });
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final online = results.any((r) => r != ConnectivityResult.none);
    _isOnline = online;
    // Only show initial banner if we start offline — no "Back online" flash
    // on cold start.
    setState(() => _showBanner = !online);
  }

  void _applyState(bool online) {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isOnline = online;
      _showBanner = true; // always show on transition so "Back online" flashes
    });
    if (online) {
      _hideTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showBanner = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: _showBanner ? Offset.zero : const Offset(0, -1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _showBanner ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: _isOnline ? AppColors.success : AppColors.error,
                elevation: 4,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                          color: Colors.white, size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isOnline
                                ? 'Back online'
                                : 'No internet connection — some features may not work',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
