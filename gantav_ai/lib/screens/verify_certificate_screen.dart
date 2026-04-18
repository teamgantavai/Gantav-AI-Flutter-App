import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/certificate.dart';
import '../services/certificate_service.dart';
import '../theme/app_theme.dart';

/// Public-facing certificate verifier.
///
/// Accepts a `GANTAV-...` ID, looks it up in Firestore (or local fallback),
/// and either shows the holder + course + date or a "Not found" state.
class VerifyCertificateScreen extends StatefulWidget {
  const VerifyCertificateScreen({super.key});

  @override
  State<VerifyCertificateScreen> createState() =>
      _VerifyCertificateScreenState();
}

class _VerifyCertificateScreenState extends State<VerifyCertificateScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;
  _VerifyResult? _result;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final id = _ctrl.text.trim();
    if (id.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _result = null;
    });
    final cert = await CertificateService.verifyById(id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = _VerifyResult(queriedId: id, cert: cert);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Verify certificate',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter a Gantav AI certificate ID to verify it against our records.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: isDark ? Colors.white70 : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                LengthLimitingTextInputFormatter(64),
              ],
              style: GoogleFonts.dmMono(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Certificate ID',
                hintText: 'GANTAV-XXXXXX-XXXXXXXX-YYYYMM-XXXX',
                hintStyle: GoogleFonts.dmMono(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.workspace_premium_rounded),
              ),
              onSubmitted: (_) => _verify(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _verify,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search_rounded),
                label: Text(
                  _loading ? 'Verifying…' : 'Verify',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.violet,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _VerifyResult {
  final String queriedId;
  final Certificate? cert;
  const _VerifyResult({required this.queriedId, required this.cert});
}

class _ResultCard extends StatelessWidget {
  final _VerifyResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cert = result.cert;

    if (cert == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not found',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No Gantav AI certificate matches\n"${result.queriedId}".',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final dateStr = DateFormat('MMMM d, y').format(cert.issuedAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                'Verified',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row(context, 'Holder', cert.userName),
          _row(context, 'Course', cert.courseTitle),
          _row(context, 'Category', cert.courseCategory),
          _row(context, 'Issued on', dateStr),
          _row(context, 'Lessons', '${cert.totalLessons}'),
          const SizedBox(height: 8),
          Text(
            cert.id,
            style: GoogleFonts.dmMono(
              fontSize: 11,
              color: isDark ? Colors.white60 : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: isDark ? Colors.white54 : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF2A2235),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
