import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/certificate.dart';
import '../theme/app_theme.dart';

/// Full-screen certificate viewer with share/download actions.
///
/// Uses a [RepaintBoundary] + [ui.Image] pipeline to export the certificate
/// as a PNG — no new platform plugins required.
class CertificateScreen extends StatefulWidget {
  final Certificate certificate;

  const CertificateScreen({super.key, required this.certificate});

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final GlobalKey _certificateKey = GlobalKey();
  bool _exporting = false;

  Future<Uint8List?> _capturePng() async {
    try {
      final ctx = _certificateKey.currentContext;
      if (ctx == null) return null;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[Certificate] capture error: $e');
      return null;
    }
  }

  Future<void> _share() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not export certificate')),
        );
        return;
      }
      final dir = await getTemporaryDirectory();
      final filename =
          'gantav_ai_certificate_${widget.certificate.verificationCode}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text:
              'I just completed "${widget.certificate.courseTitle}" on Gantav AI! 🎉\nVerification: ${widget.certificate.verificationCode}',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Share failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not export certificate')),
        );
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final filename =
          'gantav_ai_certificate_${widget.certificate.verificationCode}.png';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      messenger.showSnackBar(
        SnackBar(content: Text('Saved: ${file.path}')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1625),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Your Certificate',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RepaintBoundary(
                  key: _certificateKey,
                  child: _CertificateCard(certificate: widget.certificate),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exporting ? null : _saveToDevice,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Save'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exporting ? null : _share,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.violet,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Certificate visual — intentionally compact so it renders crisp on 3x export

class _CertificateCard extends StatelessWidget {
  final Certificate certificate;
  const _CertificateCard({required this.certificate});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, y').format(certificate.issuedAt);

    return AspectRatio(
      aspectRatio: 1.414, // A4 landscape
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF0), Color(0xFFF5EBD3)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC9A74A), width: 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFC9A74A).withValues(alpha: 0.4),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipOval(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.auto_awesome,
                              color: Color(0xFFC9A74A),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'GANTAV AI',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: const Color(0xFF2A2235),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFC9A74A),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CERTIFICATE OF COMPLETION',
                      style: GoogleFonts.dmSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: const Color(0xFF2A2235),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 60,
                      height: 2,
                      color: const Color(0xFFC9A74A),
                    ),
                  ],
                ),
                // Body
                Column(
                  children: [
                    Text(
                      'This certifies that',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF5B5470),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      certificate.userName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF4C3BB0),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'has successfully completed the course',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF5B5470),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      certificate.courseTitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2A2235),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${certificate.totalLessons} lessons • ${certificate.courseCategory}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: const Color(0xFF7E7890),
                      ),
                    ),
                  ],
                ),
                // Footer
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _FooterBlock(
                      label: 'ISSUED ON',
                      value: dateStr,
                    ),
                    Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9A74A).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFC9A74A),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFFC9A74A),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'VERIFIED',
                          style: GoogleFonts.dmSans(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: const Color(0xFFC9A74A),
                          ),
                        ),
                      ],
                    ),
                    _FooterBlock(
                      label: 'CERTIFICATE ID',
                      value: certificate.id,
                      width: 180,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterBlock extends StatelessWidget {
  final String label;
  final String value;
  final double width;
  const _FooterBlock({required this.label, required this.value, this.width = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(0xFF7E7890),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: width,
            height: 1,
            color: const Color(0xFF2A2235),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.dmMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A2235),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
