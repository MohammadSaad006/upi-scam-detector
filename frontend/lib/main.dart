import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

// ─── Color System ─────────────────────────────────────────────────────────────
const Color kBg           = Color(0xFFF0F2F5);   // cool light gray base
const Color kSurface      = Color(0xFFFFFFFF);
const Color kSurfaceAlt   = Color(0xFFF7F9FC);
const Color kBorder       = Color(0xFFE4E8EF);
const Color kBorderSubtle = Color(0xFFEEF1F6);

// Brand — deep blue (trust, security)
const Color kBlue         = Color(0xFF1D4ED8);
const Color kBlueMid      = Color(0xFF2563EB);
const Color kBlueSoft     = Color(0xFF3B82F6);
const Color kBlueTint     = Color(0xFFEFF6FF);
const Color kBlueBorder   = Color(0xFFBFDBFE);

// Status
const Color kRed          = Color(0xFFDC2626);
const Color kRedTint      = Color(0xFFFEF2F2);
const Color kRedBorder    = Color(0xFFFECACA);
const Color kAmber        = Color(0xFFD97706);
const Color kAmberTint    = Color(0xFFFFFBEB);
const Color kAmberBorder  = Color(0xFFFDE68A);
const Color kGreen        = Color(0xFF059669);
const Color kGreenTint    = Color(0xFFECFDF5);
const Color kGreenBorder  = Color(0xFFA7F3D0);
const Color kViolet       = Color(0xFF7C3AED);

// Text
const Color kInk          = Color(0xFF0F172A);
const Color kInkMid       = Color(0xFF475569);
const Color kInkLight     = Color(0xFF94A3B8);

const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x08000000), blurRadius: 1, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0A000000), blurRadius: 8,  offset: Offset(0, 4)),
  BoxShadow(color: Color(0x06000000), blurRadius: 20, offset: Offset(0, 12)),
];

const List<BoxShadow> kLiftedShadow = [
  BoxShadow(color: Color(0x0D1D4ED8), blurRadius: 2,  offset: Offset(0, 1)),
  BoxShadow(color: Color(0x141D4ED8), blurRadius: 12, offset: Offset(0, 6)),
  BoxShadow(color: Color(0x0A1D4ED8), blurRadius: 30, offset: Offset(0, 16)),
];

// ─── App ─────────────────────────────────────────────────────────────────────
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
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.light(primary: kBlueMid),
      ),
      home: const Dashboard(),
    );
  }
}

// ─── Dashboard ───────────────────────────────────────────────────────────────
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _error = '';

  Future<void> _analyze() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _result = null; _error = ''; });
    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/analyze'),
        body: {'text': _ctrl.text.trim()},
      );
      if (res.statusCode == 200) {
        setState(() => _result = json.decode(res.body));
      } else {
        setState(() => _error = 'Server returned ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Cannot reach backend — is uvicorn running?');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _analyzeQR() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;
    setState(() { _loading = true; _result = null; _error = ''; });
    try {
      final req = http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:8000/api/analyze/qr'));
      if (kIsWeb) {
        final b = await img.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes('file', b, filename: img.name));
      } else {
        req.files.add(await http.MultipartFile.fromPath('file', img.path));
      }
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) {
        final d = json.decode(res.body);
        setState(() => _result = d);
        if (d['metrics']?['qr_data_extracted'] != null) _ctrl.text = d['metrics']['qr_data_extracted'];
      } else {
        setState(() => _error = 'Server returned ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Failed to decode QR payload.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _Navbar(),
          _StatsRow(),
          const Divider(color: kBorder, height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Input Panel
                Container(
                  width: 340,
                  color: kSurface,
                  child: _InputPanel(
                    ctrl: _ctrl,
                    loading: _loading,
                    onAnalyze: _analyze,
                    onQR: _analyzeQR,
                  ),
                ),
                Container(width: 1, color: kBorder),
                // Right Results Area
                Expanded(
                  child: _loading
                      ? _LoadingView()
                      : _error.isNotEmpty
                          ? _ErrorView(message: _error)
                          : _result != null
                              ? _ReportView(data: _result!)
                              : _IdleView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Navbar ──────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          // Logo
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), kBlueSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: const [BoxShadow(color: Color(0x301D4ED8), blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: const Icon(Icons.security_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text('TrustGuard', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(width: 8),
          _Chip(label: 'Intelligence v4.2', color: kBlueTint, textColor: kBlue, borderColor: kBlueBorder),
          const Spacer(),
          _Chip(label: '● Engine Online', color: kGreenTint, textColor: kGreen, borderColor: kGreenBorder),
          const SizedBox(width: 16),
          _Chip(label: '14,092 threats analyzed', color: kSurfaceAlt, textColor: kInkMid, borderColor: kBorder),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, textColor, borderColor;
  const _Chip({required this.label, required this.color, required this.textColor, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Stats Row ───────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          _StatItem(label: 'NLP Engine', value: 'Active', icon: Icons.psychology_outlined, color: kGreen),
          _StatDivider(),
          _StatItem(label: 'Vision Engine', value: 'Standby', icon: Icons.visibility_outlined, color: kAmber),
          _StatDivider(),
          _StatItem(label: 'DNS Resolver', value: 'Online', icon: Icons.dns_outlined, color: kGreen),
          _StatDivider(),
          _StatItem(label: 'Entropy Checker', value: 'Online', icon: Icons.analytics_outlined, color: kGreen),
          _StatDivider(),
          _StatItem(label: 'Threats Detected', value: '1,482', icon: Icons.gpp_bad_outlined, color: kRed),
          _StatDivider(),
          _StatItem(label: 'Avg. Analysis Time', value: '~320ms', icon: Icons.timer_outlined, color: kBlueMid),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: kBorder, margin: const EdgeInsets.symmetric(horizontal: 24));
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: kInkLight, fontSize: 11, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

// ─── Input Panel ─────────────────────────────────────────────────────────────
class _InputPanel extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onAnalyze, onQR;

  const _InputPanel({required this.ctrl, required this.loading, required this.onAnalyze, required this.onQR});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payload Input', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Text, URL, or optical QR code', style: TextStyle(color: kInkLight, fontSize: 12)),
          const SizedBox(height: 20),

          // Textarea
          Container(
            decoration: BoxDecoration(
              color: kSurfaceAlt,
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: ctrl,
              maxLines: 11,
              style: const TextStyle(color: kInk, fontSize: 13.5, height: 1.65),
              decoration: const InputDecoration(
                hintText: 'Paste suspicious text, SMS, or URL here…',
                hintStyle: TextStyle(color: kInkLight, fontSize: 13.5),
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _PrimaryBtn(label: 'Analyze Payload', icon: Icons.radar_rounded, loading: loading, onTap: onAnalyze),
          const SizedBox(height: 10),
          _SecondaryBtn(label: 'Scan QR Code', icon: Icons.qr_code_scanner, onTap: onQR),

          const Spacer(),

          // How it works section
          const Text('Detection Modules', style: TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _ModuleRow(icon: Icons.psychology_rounded, label: 'Semantic NLP', desc: 'Urgency & phishing keywords', color: kViolet),
          const SizedBox(height: 8),
          _ModuleRow(icon: Icons.dns_rounded, label: 'DNS Intelligence', desc: 'A-record resolution & IP check', color: kBlueMid),
          const SizedBox(height: 8),
          _ModuleRow(icon: Icons.analytics_rounded, label: 'Shannon Entropy', desc: 'DGA & domain obfuscation', color: kAmber),
          const SizedBox(height: 8),
          _ModuleRow(icon: Icons.link_rounded, label: 'Redirect Tracing', desc: 'Unshorten & trace URLs', color: kGreen),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final IconData icon;
  final String label, desc;
  final Color color;
  const _ModuleRow({required this.icon, required this.label, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w600)),
            Text(desc, style: const TextStyle(color: kInkLight, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

// ─── Idle View ───────────────────────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analysis Canvas', style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Results and forensic reports will appear here after analysis.', style: TextStyle(color: kInkLight, fontSize: 13)),
          const SizedBox(height: 32),
          // Info cards grid
          Row(
            children: [
              _InfoCard(
                icon: Icons.gpp_bad_rounded,
                iconColor: kRed,
                bgColor: kRedTint,
                title: 'Phishing Detection',
                body: 'Identifies social engineering messages designed to steal credentials, OTPs, and financial data.',
              ),
              const SizedBox(width: 16),
              _InfoCard(
                icon: Icons.hub_rounded,
                iconColor: kBlueMid,
                bgColor: kBlueTint,
                title: 'Network Forensics',
                body: 'Resolves DNS records, traces redirects, and scores domain entropy to detect DGA-generated URLs.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoCard(
                icon: Icons.psychology_rounded,
                iconColor: kViolet,
                bgColor: const Color(0xFFF5F3FF),
                title: 'Semantic NLP',
                body: 'Detects urgency triggers (KYC, block, expire) and financial manipulation phrases in messages.',
              ),
              const SizedBox(width: 16),
              _InfoCard(
                icon: Icons.qr_code_rounded,
                iconColor: kAmber,
                bgColor: kAmberTint,
                title: 'QR Payload Decoder',
                body: 'Uses OpenCV to extract embedded URLs and data from QR codes, then runs full forensic analysis.',
              ),
            ],
          ),
          const Spacer(),
          // Sample threat tags
          const Text('Common Threat Indicators', style: TextStyle(color: kInkMid, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              'urgently', 'KYC expire', 'claim refund', 'verify PAN',
              'bit.ly redirect', '.xyz domain', 'direct IP link', 'HDFC spoof',
            ].map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(t, style: const TextStyle(color: kInkMid, fontSize: 12, fontWeight: FontWeight.w500)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String title, body;
  const _InfoCard({required this.icon, required this.iconColor, required this.bgColor, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: kInkMid, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Loading View ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E40AF), kBlueSoft],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: kLiftedShadow,
            ),
            child: const Center(
              child: SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Analyzing payload…', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Running NLP, DNS & entropy analysis', style: TextStyle(color: kInkLight, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: kRedTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kRedBorder),
            boxShadow: kCardShadow,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.error_outline_rounded, color: kRed, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Connection Error', style: TextStyle(color: kRed, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(message, style: const TextStyle(color: kRed, fontSize: 13, height: 1.5)),
                ],
              )),
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
    final networkLogs    = (data['forensic_report']?['network_analysis']   as List?) ?? [];
    final linguisticLogs = (data['forensic_report']?['linguistic_analysis'] as List?) ?? [];
    final highlights     = (data['highlights'] as List?) ?? [];

    Color sColor, tint, border;
    switch (status) {
      case 'High Risk':
        sColor = kRed;    tint = kRedTint;    border = kRedBorder;    break;
      case 'Suspicious':
        sColor = kAmber;  tint = kAmberTint;  border = kAmberBorder;  break;
      default:
        sColor = kGreen;  tint = kGreenTint;  border = kGreenBorder;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Hero Status Card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border.withOpacity(0.6), width: 1.5),
              boxShadow: kCardShadow,
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                    border: Border.all(color: border, width: 2),
                  ),
                  child: Icon(
                    status == 'High Risk' ? Icons.gpp_bad_rounded : status == 'Suspicious' ? Icons.gpp_maybe_rounded : Icons.verified_rounded,
                    color: sColor, size: 28,
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
                            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
                            child: Text(status, style: TextStyle(color: sColor, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 10),
                          Text('Risk Score: $score / 100', style: const TextStyle(color: kInkLight, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(data['summary'] ?? '', style: const TextStyle(color: kInkMid, fontSize: 13.5, height: 1.55)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Big Score
                Column(
                  children: [
                    Text('$score', style: TextStyle(color: sColor, fontSize: 40, fontWeight: FontWeight.w900, height: 1.0)),
                    Text('/100', style: TextStyle(color: sColor.withOpacity(0.45), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Metric Cards ──────────────────────────────────────────────────
          Row(
            children: [
              _MetricCard(label: 'Urgency Indicators', value: data['metrics']?['urgency']  ?? 0, max: 5, color: kAmber,   icon: Icons.bolt_rounded),
              const SizedBox(width: 14),
              _MetricCard(label: 'Financial Triggers',  value: data['metrics']?['financial'] ?? 0, max: 5, color: kViolet, icon: Icons.account_balance_rounded),
              const SizedBox(width: 14),
              _MetricCard(label: 'Network Anomalies',   value: data['metrics']?['url_risk']  ?? 0, max: 3, color: kRed,    icon: Icons.wifi_tethering_error_rounded),
            ],
          ),

          // ── IOCs ──────────────────────────────────────────────────────────
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel(label: 'Indicators of Compromise (IOCs)'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: highlights.map((h) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kRedTint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kRedBorder),
                ),
                child: Text(h.toString(), style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Courier New')),
              )).toList(),
            ),
          ],

          // ── Forensic Logs ─────────────────────────────────────────────────
          if (networkLogs.isNotEmpty || linguisticLogs.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel(label: 'Deep Forensic Report'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorder),
                boxShadow: kCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (networkLogs.isNotEmpty) ...[
                    _LogBlock(title: 'Network & DNS Intelligence', color: kGreen, logs: networkLogs),
                  ],
                  if (networkLogs.isNotEmpty && linguisticLogs.isNotEmpty)
                    const Divider(color: kBorderSubtle, height: 32),
                  if (linguisticLogs.isNotEmpty)
                    _LogBlock(title: 'Semantic Manipulation Vectors', color: kViolet, logs: linguisticLogs),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
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
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.max, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: kCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: const TextStyle(color: kInkMid, fontSize: 12, fontWeight: FontWeight.w500))),
                Text('$value', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max > 0 ? value / max : 0,
                backgroundColor: kBorderSubtle,
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

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 15, decoration: BoxDecoration(color: kBlueMid, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _LogBlock extends StatelessWidget {
  final String title;
  final Color color;
  final List logs;
  const _LogBlock({required this.title, required this.color, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 4, backgroundColor: color),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ],
        ),
        const SizedBox(height: 14),
        ...logs.map((log) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: CircleAvatar(radius: 2.5, backgroundColor: kInkLight),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(log.toString(), style: const TextStyle(color: kInkMid, fontSize: 13, height: 1.55))),
            ],
          ),
        )).toList(),
      ],
    );
  }
}

// ─── Buttons ─────────────────────────────────────────────────────────────────
class _PrimaryBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.icon, required this.loading, required this.onTap});

  @override
  State<_PrimaryBtn> createState() => _PrimaryBtnState();
}

class _PrimaryBtnState extends State<_PrimaryBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: double.infinity, height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _h ? [const Color(0xFF1E3A8A), kBlue] : [kBlue, kBlueMid],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _h ? kLiftedShadow : [const BoxShadow(color: Color(0x281D4ED8), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 17),
                      const SizedBox(width: 8),
                      Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.1)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryBtn({required this.label, required this.icon, required this.onTap});

  @override
  State<_SecondaryBtn> createState() => _SecondaryBtnState();
}

class _SecondaryBtnState extends State<_SecondaryBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          width: double.infinity, height: 46,
          decoration: BoxDecoration(
            color: _h ? kBlueTint : kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _h ? kBlueBorder : kBorder),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: _h ? kBlueMid : kInkMid, size: 17),
                const SizedBox(width: 8),
                Text(widget.label, style: TextStyle(color: _h ? kBlueMid : kInkMid, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
