import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

// ─── Design Tokens ───────────────────────────────────────────────────────────
class T {
  // Backgrounds
  static const bg       = Color(0xFFF9FAFB);
  static const surface  = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF3F4F6);

  // Text
  static const textPrimary   = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted     = Color(0xFF9CA3AF);

  // Borders
  static const border = Color(0xFFE5E7EB);
  static const borderSubtle = Color(0xFFF3F4F6);

  // Accent — Indigo (sophisticated, used sparingly)
  static const accent      = Color(0xFF4F46E5);
  static const accentLight = Color(0xFFEEF2FF);

  // Status
  static const danger      = Color(0xFFDC2626);
  static const dangerLight = Color(0xFFFEF2F2);
  static const dangerBorder = Color(0xFFFECACA);

  static const warn      = Color(0xFFD97706);
  static const warnLight = Color(0xFFFFFBEB);
  static const warnBorder = Color(0xFFFDE68A);

  static const safe      = Color(0xFF059669);
  static const safeLight = Color(0xFFECFDF5);
  static const safeBorder = Color(0xFFA7F3D0);

  // Typography
  static const fontBody  = TextStyle(fontFamily: 'Inter', color: textPrimary);
}

// ─── Shadows ─────────────────────────────────────────────────────────────────
List<BoxShadow> softShadow = [
  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 1)),
  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
];

List<BoxShadow> subtleShadow = [
  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
];

// ─── App Root ─────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrustGuard · Security Intelligence',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: T.bg,
        colorScheme: const ColorScheme.light(primary: T.accent),
      ),
      home: const AppShell(),
    );
  }
}

// ─── App Shell ────────────────────────────────────────────────────────────────
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: HomePage());
  }
}

// ─── Home Page ────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _error = '';

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _result = null; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/analyze'),
        body: {'text': text},
      );
      if (res.statusCode == 200) {
        setState(() { _result = json.decode(res.body); });
      } else {
        setState(() { _error = 'Server returned ${res.statusCode}'; });
      }
    } catch (_) {
      setState(() { _error = 'Cannot reach backend — make sure uvicorn is running.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _analyzeQR() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() { _loading = true; _result = null; _error = ''; });
    try {
      final uri = Uri.parse('http://127.0.0.1:8000/api/analyze/qr');
      final req = http.MultipartRequest('POST', uri);
      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: img.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath('file', img.path));
      }
      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() { _result = data; });
        if (data['metrics']?['qr_data_extracted'] != null) {
          _ctrl.text = data['metrics']['qr_data_extracted'];
        }
      } else {
        setState(() { _error = 'Server returned ${res.statusCode}'; });
      }
    } catch (_) {
      setState(() { _error = 'Failed to decode QR payload.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left Input Panel ──────────────────────────────────────
              _InputPanel(
                ctrl: _ctrl,
                loading: _loading,
                onAnalyze: _analyze,
                onQR: _analyzeQR,
              ),
              // Divider
              Container(width: 1, color: T.border),
              // ── Right Results Panel ───────────────────────────────────
              Expanded(
                child: _ResultsPanel(
                  loading: _loading,
                  error: _error,
                  result: _result,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: T.surface,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: T.border)),
      ),
      child: Row(
        children: [
          // Logo mark
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: T.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.shield, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('TrustGuard',
              style: TextStyle(
                  color: T.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: T.safeLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: T.safeBorder),
            ),
            child: Row(
              children: const [
                CircleAvatar(radius: 4, backgroundColor: T.safe),
                SizedBox(width: 6),
                Text('Engine Online',
                    style: TextStyle(
                        color: T.safe,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input Panel ──────────────────────────────────────────────────────────────
class _InputPanel extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onAnalyze;
  final VoidCallback onQR;

  const _InputPanel({
    required this.ctrl,
    required this.loading,
    required this.onAnalyze,
    required this.onQR,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      color: T.surface,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payload Input',
              style: TextStyle(
                  color: T.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Paste a message, URL, or scan a QR code to begin threat analysis.',
            style: TextStyle(color: T.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Text field
          Container(
            decoration: BoxDecoration(
              color: T.bg,
              border: Border.all(color: T.border),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: ctrl,
              maxLines: 10,
              style: const TextStyle(
                  color: T.textPrimary, fontSize: 13, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Paste suspicious text, SMS, or URL here…',
                hintStyle: TextStyle(color: T.textMuted),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Primary CTA
          _PrimaryButton(
            label: 'Analyze Payload',
            icon: Icons.radar_rounded,
            loading: loading,
            onTap: onAnalyze,
          ),
          const SizedBox(height: 10),

          // Secondary CTA
          _SecondaryButton(
            label: 'Scan QR Code',
            icon: Icons.qr_code_scanner,
            onTap: onQR,
          ),

          const Spacer(),

          // Footer hint
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: T.accentLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: T.accent.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, size: 16, color: T.accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All analysis runs locally. No data leaves your machine.',
                    style: TextStyle(
                        color: T.accent, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Results Panel ────────────────────────────────────────────────────────────
class _ResultsPanel extends StatelessWidget {
  final bool loading;
  final String error;
  final Map<String, dynamic>? result;

  const _ResultsPanel({
    required this.loading,
    required this.error,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _EmptyState(state: _EmptyStateType.loading);
    if (error.isNotEmpty) return _ErrorState(message: error);
    if (result == null) return const _EmptyState(state: _EmptyStateType.idle);
    return _ReportView(data: result!);
  }
}

// ─── Empty / Loading State ────────────────────────────────────────────────────
enum _EmptyStateType { idle, loading }

class _EmptyState extends StatelessWidget {
  final _EmptyStateType state;
  const _EmptyState({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: T.surface,
              shape: BoxShape.circle,
              boxShadow: subtleShadow,
            ),
            child: state == _EmptyStateType.loading
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        color: T.accent, strokeWidth: 2.5))
                : const Icon(Icons.shield_outlined, size: 32, color: T.textMuted),
          ),
          const SizedBox(height: 20),
          Text(
            state == _EmptyStateType.loading
                ? 'Analyzing payload…'
                : 'Awaiting payload',
            style: const TextStyle(
                color: T.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            state == _EmptyStateType.loading
                ? 'Running NLP, DNS & entropy checks'
                : 'Paste a message on the left and press Analyze',
            style: const TextStyle(color: T.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: T.dangerLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: T.dangerBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: T.danger, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: T.danger, fontSize: 14, height: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Report View ──────────────────────────────────────────────────────────────
class _ReportView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportView({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String;
    final score  = data['score']  as int;

    Color statusColor, bgColor, borderColor;
    switch (status) {
      case 'High Risk':
        statusColor  = T.danger; bgColor = T.dangerLight; borderColor = T.dangerBorder;
        break;
      case 'Suspicious':
        statusColor  = T.warn; bgColor = T.warnLight; borderColor = T.warnBorder;
        break;
      default:
        statusColor  = T.safe; bgColor = T.safeLight; borderColor = T.safeBorder;
    }

    final networkLogs    = (data['forensic_report']?['network_analysis']  as List?) ?? [];
    final linguisticLogs = (data['forensic_report']?['linguistic_analysis'] as List?) ?? [];
    final highlights     = (data['highlights'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Hero ──
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: T.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: T.border),
              boxShadow: softShadow,
            ),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 5, backgroundColor: statusColor),
                      const SizedBox(width: 8),
                      Text(status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Threat Verdict',
                          style: TextStyle(
                              color: T.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(data['summary'] ?? '',
                          style: const TextStyle(
                              color: T.textPrimary,
                              fontSize: 13,
                              height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Score ring
                Column(
                  children: [
                    const Text('Score',
                        style: TextStyle(
                            color: T.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text('$score',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    Text('/100',
                        style: TextStyle(
                            color: statusColor.withOpacity(0.5),
                            fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Metric Cards ──
          Row(
            children: [
              _MetricCard(
                label: 'Urgency Indicators',
                value: data['metrics']?['urgency'] ?? 0,
                max: 5,
                color: T.warn,
              ),
              const SizedBox(width: 16),
              _MetricCard(
                label: 'Financial Triggers',
                value: data['metrics']?['financial'] ?? 0,
                max: 5,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(width: 16),
              _MetricCard(
                label: 'Network Anomalies',
                value: data['metrics']?['url_risk'] ?? 0,
                max: 3,
                color: T.danger,
              ),
            ],
          ),

          // ── IOCs ──
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionLabel(label: 'Indicators of Compromise'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: highlights.map((h) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: T.dangerLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: T.dangerBorder),
                  ),
                  child: Text(h.toString(),
                      style: const TextStyle(
                          color: T.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Courier New')),
                );
              }).toList(),
            ),
          ],

          // ── Forensic Logs ──
          if (networkLogs.isNotEmpty || linguisticLogs.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionLabel(label: 'Deep Forensic Analysis'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: T.border),
                boxShadow: subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (networkLogs.isNotEmpty) ...[
                    _LogSection(
                      title: 'Network & DNS Intelligence',
                      color: T.safe,
                      logs: networkLogs,
                    ),
                  ],
                  if (networkLogs.isNotEmpty && linguisticLogs.isNotEmpty)
                    const Divider(color: T.border, height: 32),
                  if (linguisticLogs.isNotEmpty) ...[
                    _LogSection(
                      title: 'Semantic Manipulation',
                      color: Color(0xFF7C3AED),
                      logs: linguisticLogs,
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: T.border),
          boxShadow: subtleShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: T.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
                Text('$value/$max',
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max > 0 ? value / max : 0,
                backgroundColor: T.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            color: T.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600));
  }
}

// ─── Log Section ──────────────────────────────────────────────────────────────
class _LogSection extends StatelessWidget {
  final String title;
  final Color color;
  final List logs;

  const _LogSection({
    required this.title,
    required this.color,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
        const SizedBox(height: 14),
        ...logs.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: CircleAvatar(radius: 3, backgroundColor: T.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(log.toString(),
                    style: const TextStyle(
                        color: T.textSecondary,
                        fontSize: 13,
                        height: 1.55)),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
}

// ─── Buttons ──────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF4338CA) : T.accent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: T.accent.withOpacity(_hover ? 0.35 : 0.22),
                  blurRadius: _hover ? 16 : 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 17),
                      const SizedBox(width: 8),
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<_SecondaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: _hover ? T.surfaceAlt : T.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hover ? T.accent.withOpacity(0.3) : T.border),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon,
                    color: _hover ? T.accent : T.textSecondary, size: 17),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: TextStyle(
                        color: _hover ? T.accent : T.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
