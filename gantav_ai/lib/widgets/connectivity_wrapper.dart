import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _isOnline = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online != _isOnline) {
        if (mounted) {
          setState(() {
            _isOnline = online;
            _showBanner = !online;
          });
        }
        if (online) {
          // Hide banner after 2 seconds when back online
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showBanner = false);
          });
        }
      }
    });

    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = results.any((r) => r != ConnectivityResult.none);
        _showBanner = !_isOnline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Material(
              color: _isOnline ? AppColors.success : AppColors.error,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off,
                        color: Colors.white, size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOnline ? 'Back online' : 'No internet connection',
                        style: GoogleFonts.dmSans(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
