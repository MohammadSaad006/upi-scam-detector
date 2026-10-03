import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

// ─── Premium Design Tokens ───────────────────────────────────────────────────
class C {
  // Brand Palette — Deep Indigo + Warm Slate
  static const indigo900 = Color(0xFF312E81);
  static const indigo700 = Color(0xFF4338CA);
  static const indigo600 = Color(0xFF4F46E5);
  static const indigo500 = Color(0xFF6366F1);
  static const indigo100 = Color(0xFFE0E7FF);
  static const indigo50  = Color(0xFFEEF2FF);

  // Backgrounds — Warm Ivory (not pure white)
  static const bg        = Color(0xFFF5F4F0); // warm ivory base
  static const surface   = Color(0xFFFBFAF8); // slightly warm white
  static const surfaceEl = Color(0xFFFFFFFF); // elevated pure white

  // Borders
  static const border    = Color(0xFFE8E6E0); // warm gray
  static const borderSub = Color(0xFFF0EEE9);

  // Text
  static const ink       = Color(0xFF1C1917); // warm near-black
  static const inkMid    = Color(0xFF57534E); // warm medium gray
  static const inkLight  = Color(0xFF78716C); // warm light gray

  // Status — refined, not generic
  static const red       = Color(0xFFDC2626);
  static const redLight  = Color(0xFFFEF2F2);
  static const redBorder = Color(0xFFFECACA);

  static const amber     = Color(0xFFB45309);
  static const amberLight= Color(0xFFFEF3C7);
  static const amberBorder=Color(0xFFFDE68A);

  static const emerald   = Color(0xFF059669);
  static const emeraldLight=Color(0xFFECFDF5);
  static const emeraldBorder=Color(0xFFA7F3D0);
}

List<BoxShadow> elevatedShadow = [
  BoxShadow(color: const Color(0xFF1C1917).withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
  BoxShadow(color: const Color(0xFF1C1917).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 8)),
];

List<BoxShadow> subtleShadow = [
  BoxShadow(color: const Color(0xFF1C1917).withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
];

List<BoxShadow> indigoGlow = [
  BoxShadow(color: C.indigo600.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
];

// ─── App Root ────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrustGuard · Threat Intelligence',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.light(primary: C.indigo600),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
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
      setState(() { _error = 'Cannot reach backend — is uvicorn running?'; });
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
    return Scaffold(
      backgroundColor: C.bg,
      body: Column(
        children: [
          _TopBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InputPanel(
                  ctrl: _ctrl,
                  loading: _loading,
                  onAnalyze: _analyze,
                  onQR: _analyzeQR,
                ),
                Container(width: 1, color: C.border),
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
      ),
    );
  }
}

// ─── Top Bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: C.surfaceEl,
        border: Border(bottom: BorderSide(color: C.border)),
        boxShadow: subtleShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [C.indigo700, C.indigo500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [BoxShadow(color: C.indigo600.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('TrustGuard',
              style: TextStyle(
                  color: C.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: C.indigo50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: C.indigo100),
            ),
            child: const Text('v4.2', style: TextStyle(color: C.indigo600, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: C.emeraldLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: C.emeraldBorder),
            ),
            child: Row(
              children: const [
                CircleAvatar(radius: 4, backgroundColor: C.emerald),
                SizedBox(width: 6),
                Text('Engine Online',
                    style: TextStyle(color: C.emerald, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Input Panel ─────────────────────────────────────────────────────────────
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
      color: C.surface,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: C.indigo50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.indigo100),
                ),
                child: const Icon(Icons.manage_search_rounded, color: C.indigo600, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Payload Input', style: TextStyle(color: C.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('Text, URL, or QR', style: TextStyle(color: C.inkLight, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Textarea
          Container(
            decoration: BoxDecoration(
              color: C.surfaceEl,
              border: Border.all(color: C.border),
              borderRadius: BorderRadius.circular(12),
              boxShadow: subtleShadow,
            ),
            child: TextField(
              controller: ctrl,
              maxLines: 10,
              style: const TextStyle(color: C.ink, fontSize: 13.5, height: 1.6),
              decoration: const InputDecoration(
                hintText: 'Paste suspicious text, SMS, or URL here…',
                hintStyle: TextStyle(color: C.inkLight),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 16),

          _PrimaryButton(
            label: 'Analyze Payload',
            icon: Icons.radar_rounded,
            loading: loading,
            onTap: onAnalyze,
          ),
          const SizedBox(height: 10),
          _SecondaryButton(
            label: 'Scan QR Code',
            icon: Icons.qr_code_scanner,
            onTap: onQR,
          ),

          const Spacer(),

          // Info note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.indigo50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.indigo100),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.lock_outline_rounded, size: 15, color: C.indigo600),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All analysis runs locally. No data leaves your machine.',
                    style: TextStyle(color: C.indigo700, fontSize: 12, height: 1.5),
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

// ─── Results Panel ───────────────────────────────────────────────────────────
class _ResultsPanel extends StatelessWidget {
  final bool loading;
  final String error;
  final Map<String, dynamic>? result;

  const _ResultsPanel({required this.loading, required this.error, required this.result});

  @override
  Widget build(BuildContext context) {
    if (loading) return _buildLoading();
    if (error.isNotEmpty) return _buildError(error);
    if (result == null) return _buildIdle();
    return _ReportView(data: result!);
  }

  Widget _buildIdle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [C.indigo50, C.bg],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: C.border, width: 1.5),
            ),
            child: const Icon(Icons.shield_outlined, size: 36, color: C.indigo500),
          ),
          const SizedBox(height: 20),
          const Text('Awaiting payload',
              style: TextStyle(color: C.ink, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Paste a message on the left and press Analyze',
              style: TextStyle(color: C.inkLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: C.indigo50,
              shape: BoxShape.circle,
              border: Border.all(color: C.indigo100, width: 1.5),
            ),
            child: const SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(color: C.indigo600, strokeWidth: 2.5),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Analyzing payload…',
              style: TextStyle(color: C.ink, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Running NLP, DNS & entropy checks',
              style: TextStyle(color: C.inkLight, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: C.redLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.redBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: C.red, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(msg, style: const TextStyle(color: C.red, fontSize: 14, height: 1.5))),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Report View ─────────────────────────────────────────────────────────────
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
        statusColor = C.red;    bgColor = C.redLight;    borderColor = C.redBorder;    break;
      case 'Suspicious':
        statusColor = C.amber;  bgColor = C.amberLight;  borderColor = C.amberBorder;  break;
      default:
        statusColor = C.emerald; bgColor = C.emeraldLight; borderColor = C.emeraldBorder;
    }

    final networkLogs    = (data['forensic_report']?['network_analysis']   as List?) ?? [];
    final linguisticLogs = (data['forensic_report']?['linguistic_analysis'] as List?) ?? [];
    final highlights     = (data['highlights'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Hero Card ──
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: C.surfaceEl,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.border),
              boxShadow: elevatedShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Colored left accent bar
                Container(
                  width: 4, height: 56,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 4, backgroundColor: statusColor),
                                const SizedBox(width: 6),
                                Text(status,
                                    style: TextStyle(
                                        color: statusColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(data['summary'] ?? '',
                          style: const TextStyle(color: C.inkMid, fontSize: 13.5, height: 1.55)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Score circle
                Container(
                  width: 76, height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor,
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$score',
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              height: 1.0)),
                      Text('/100',
                          style: TextStyle(
                              color: statusColor.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Heuristic Metric Cards ──
          Row(
            children: [
              _MetricCard(label: 'Urgency Indicators', value: data['metrics']?['urgency']  ?? 0, max: 5, color: C.amber),
              const SizedBox(width: 12),
              _MetricCard(label: 'Financial Triggers',  value: data['metrics']?['financial'] ?? 0, max: 5, color: C.indigo600),
              const SizedBox(width: 12),
              _MetricCard(label: 'Network Anomalies',   value: data['metrics']?['url_risk']  ?? 0, max: 3, color: C.red),
            ],
          ),

          // ── IOCs ──
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(label: 'Indicators of Compromise'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: highlights.map((h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: C.redLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: C.redBorder),
                ),
                child: Text(h.toString(),
                    style: const TextStyle(
                        color: C.red, fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Courier New')),
              )).toList(),
            ),
          ],

          // ── Forensic Log ──
          if (networkLogs.isNotEmpty || linguisticLogs.isNotEmpty) ...[
            const SizedBox(height: 28),
            _SectionHeader(label: 'Deep Forensic Analysis'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: C.surfaceEl,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.border),
                boxShadow: subtleShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (networkLogs.isNotEmpty) ...[
                    _LogSection(title: 'Network & DNS Intelligence', color: C.emerald, logs: networkLogs),
                  ],
                  if (networkLogs.isNotEmpty && linguisticLogs.isNotEmpty)
                    Divider(color: C.border, height: 32),
                  if (linguisticLogs.isNotEmpty) ...[
                    _LogSection(title: 'Semantic Manipulation Vectors', color: C.indigo600, logs: linguisticLogs),
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

// ─── Metric Card ─────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final int value, max;
  final Color color;

  const _MetricCard({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: C.surfaceEl,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
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
                      style: const TextStyle(color: C.inkMid, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                Text('$value/$max',
                    style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max > 0 ? value / max : 0,
                backgroundColor: C.borderSub,
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

// ─── Section Header ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: C.indigo600, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: C.ink, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ─── Log Section ─────────────────────────────────────────────────────────────
class _LogSection extends StatelessWidget {
  final String title;
  final Color color;
  final List logs;

  const _LogSection({required this.title, required this.color, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 3, backgroundColor: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 14),
        ...logs.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: CircleAvatar(radius: 2.5, backgroundColor: C.inkLight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(log.toString(),
                    style: const TextStyle(color: C.inkMid, fontSize: 13, height: 1.55)),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }
}

// ─── Primary Button ──────────────────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.icon, required this.loading, required this.onTap});

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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hover
                  ? [C.indigo700, C.indigo600]
                  : [C.indigo600, C.indigo500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hover ? indigoGlow : [
              BoxShadow(color: C.indigo600.withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 17),
                      const SizedBox(width: 8),
                      Text(widget.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Secondary Button ────────────────────────────────────────────────────────
class _SecondaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.icon, required this.onTap});

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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: _hover ? C.indigo50 : C.surfaceEl,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hover ? C.indigo100 : C.border),
            boxShadow: subtleShadow,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: _hover ? C.indigo600 : C.inkMid, size: 17),
                const SizedBox(width: 8),
                Text(widget.label,
                    style: TextStyle(
                        color: _hover ? C.indigo600 : C.inkMid,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
