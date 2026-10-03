import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() => runApp(const TrustGuardApp());

// ─── Design Tokens ────────────────────────────────────────────────────────────
const kBg          = Color(0xFFF0F4F8);
const kSurface     = Color(0xFFFFFFFF);
const kAlt         = Color(0xFFF7F9FC);
const kBorder      = Color(0xFFE2E8F0);
const kInk         = Color(0xFF0F172A);
const kInkMid      = Color(0xFF475569);
const kInkLight    = Color(0xFF94A3B8);
const kBlue        = Color(0xFF2563EB);
const kBlueTint    = Color(0xFFEFF6FF);
const kBlueBorder  = Color(0xFFBFDBFE);
const kGreen       = Color(0xFF059669);
const kGreenTint   = Color(0xFFECFDF5);
const kGreenBorder = Color(0xFFA7F3D0);
const kAmber       = Color(0xFFD97706);
const kAmberTint   = Color(0xFFFFFBEB);
const kAmberBorder = Color(0xFFFDE68A);
const kRed         = Color(0xFFDC2626);
const kRedTint     = Color(0xFFFEF2F2);
const kRedBorder   = Color(0xFFFECACA);
const kViolet      = Color(0xFF7C3AED);

const kCardShadow = [
  BoxShadow(color: Color(0x06000000), blurRadius: 1, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x08000000), blurRadius: 8,  offset: Offset(0, 4)),
  BoxShadow(color: Color(0x05000000), blurRadius: 20, offset: Offset(0, 10)),
];

// ─── App Root ─────────────────────────────────────────────────────────────────
class TrustGuardApp extends StatelessWidget {
  const TrustGuardApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrustGuard — UPI Threat Intelligence',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.light(primary: kBlue),
      ),
      home: const _Shell(),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell();
  @override
  Widget build(BuildContext context) => const Scaffold(body: _HomePage());
}

// ─── Home Page ────────────────────────────────────────────────────────────────
class _HomePage extends StatefulWidget {
  const _HomePage();
  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _error = '';
  List<dynamic> _history = [];
  int _selectedTab = 0; // 0=Analyze, 1=History

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
        setState(() => _result = json.decode(res.body));
        _fetchHistory();
      } else {
        setState(() => _error = 'Server returned ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Cannot reach backend — make sure uvicorn is running.');
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
        _fetchHistory();
      } else {
        setState(() => _error = 'Server returned ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Failed to decode QR payload.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8000/api/history'));
      if (res.statusCode == 200) setState(() => _history = json.decode(res.body));
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Navbar(selectedTab: _selectedTab, onTabChanged: (i) {
        setState(() => _selectedTab = i);
        if (i == 1) _fetchHistory();
      }),
      const Divider(color: kBorder, height: 1),
      Expanded(child: _selectedTab == 0 ? _buildAnalyzeView() : _buildHistoryView()),
    ]);
  }

  Widget _buildAnalyzeView() {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _InputPanel(ctrl: _ctrl, loading: _loading, onAnalyze: _analyze, onQR: _analyzeQR),
      Container(width: 1, color: kBorder),
      Expanded(child: _loading
        ? const _LoadingView()
        : _error.isNotEmpty
          ? _ErrorView(message: _error)
          : _result != null
            ? _ReportView(data: _result!)
            : const _IdleView()),
    ]);
  }

  Widget _buildHistoryView() {
    if (_history.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.history, size: 48, color: kInkLight),
        SizedBox(height: 16),
        Text('No scans yet in this session.', style: TextStyle(color: kInkLight, fontSize: 15)),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(32),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = _history[i];
        final status = item['status'] as String;
        Color dot = status == 'High Risk' ? kRed : status == 'Suspicious' ? kAmber : kGreen;
        Color bg  = status == 'High Risk' ? kRedTint : status == 'Suspicious' ? kAmberTint : kGreenTint;
        Color bd  = status == 'High Risk' ? kRedBorder : status == 'Suspicious' ? kAmberBorder : kGreenBorder;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder), boxShadow: kCardShadow),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: bd)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                CircleAvatar(radius: 4, backgroundColor: dot),
                const SizedBox(width: 6),
                Text(status, style: TextStyle(color: dot, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['preview'] ?? '', style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('${item['scam_category']} · Score: ${item['score']}/100 · ${item['scan_id']}',
                style: const TextStyle(color: kInkLight, fontSize: 11)),
            ])),
            Text('${item['score']}', style: TextStyle(color: dot, fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Courier New')),
          ]),
        );
      },
    );
  }
}

// ─── Navbar ───────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  final int selectedTab;
  final void Function(int) onTabChanged;
  const _Navbar({required this.selectedTab, required this.onTabChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: kSurface,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF1E40AF), kBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Color(0x301D4ED8), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: const Icon(Icons.security_rounded, size: 17, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text('TrustGuard', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        const SizedBox(width: 6),
        _Chip(label: 'v4.2 · Forensic Engine', color: kBlueTint, textColor: kBlue, borderColor: kBlueBorder),
        const SizedBox(width: 20),
        _TabBtn(label: 'Analyze', icon: Icons.radar_rounded, active: selectedTab == 0, onTap: () => onTabChanged(0)),
        const SizedBox(width: 4),
        _TabBtn(label: 'Scan History', icon: Icons.history_rounded, active: selectedTab == 1, onTap: () => onTabChanged(1)),
        const Spacer(),
        _Chip(label: '● Engine Online', color: kGreenTint, textColor: kGreen, borderColor: kGreenBorder),
      ]),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kBlueTint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(icon, size: 15, color: active ? kBlue : kInkLight),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? kBlue : kInkLight, fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500)),
        ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Input Panel ──────────────────────────────────────────────────────────────
class _InputPanel extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final VoidCallback onAnalyze, onQR;
  const _InputPanel({required this.ctrl, required this.loading, required this.onAnalyze, required this.onQR});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      color: kSurface,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payload Input', style: TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Text, URL, SMS, or QR code', style: TextStyle(color: kInkLight, fontSize: 12)),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(color: kAlt, border: Border.all(color: kBorder), borderRadius: BorderRadius.circular(10)),
          child: TextField(
            controller: ctrl,
            maxLines: 11,
            style: const TextStyle(color: kInk, fontSize: 13, height: 1.65),
            decoration: const InputDecoration(
              hintText: 'Paste suspicious text, SMS, or URL here…',
              hintStyle: TextStyle(color: kInkLight),
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _PrimaryBtn(label: 'Analyze Payload', icon: Icons.radar_rounded, loading: loading, onTap: onAnalyze),
        const SizedBox(height: 10),
        _SecondaryBtn(label: 'Scan QR Code', icon: Icons.qr_code_scanner, onTap: onQR),
        const Spacer(),
        const Text('Detection Modules', style: TextStyle(color: kInk, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _ModuleRow(Icons.psychology_rounded,       'Semantic NLP',           'Urgency, financial, impersonation',    kViolet),
        const SizedBox(height: 8),
        _ModuleRow(Icons.dns_rounded,              'DNS Intelligence',        'A-record resolution & IP check',      kBlue),
        const SizedBox(height: 8),
        _ModuleRow(Icons.analytics_rounded,        'Shannon Entropy (DGA)',   'Detects algorithmically-gen domains',  kAmber),
        const SizedBox(height: 8),
        _ModuleRow(Icons.link_rounded,             'Redirect Tracer',         'Unshorten & trace URL chains',         kGreen),
        const SizedBox(height: 8),
        _ModuleRow(Icons.content_copy_rounded,     'Brand Spoofing Detector', 'Typosquatting & impersonation',        kRed),
      ]),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final IconData icon;
  final String label, desc;
  final Color color;
  const _ModuleRow(this.icon, this.label, this.desc, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: color, size: 13)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kInk, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(desc, style: const TextStyle(color: kInkLight, fontSize: 10)),
      ])),
    ]);
  }
}

// ─── Idle View ────────────────────────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  const _IdleView();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Forensic Analysis Canvas', style: TextStyle(color: kInk, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Analysis results and explainability reports will appear here.', style: TextStyle(color: kInkLight, fontSize: 13)),
        const SizedBox(height: 32),
        Row(children: [
          _InfoCard(Icons.gpp_bad_rounded, kRed, kRedTint, 'Phishing Detection', 'Social engineering, urgency tactics, impersonation of RBI/banks.'),
          const SizedBox(width: 16),
          _InfoCard(Icons.hub_rounded, kBlue, kBlueTint, 'Network Forensics', 'Live DNS resolution, redirect tracing, Shannon entropy for DGA detection.'),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _InfoCard(Icons.psychology_rounded, kViolet, const Color(0xFFF5F3FF), 'Semantic NLP', 'Multi-vector keyword engine: urgency, financial, authority impersonation.'),
          const SizedBox(width: 16),
          _InfoCard(Icons.lightbulb_rounded, kAmber, kAmberTint, 'Explainability', 'Every finding includes module, evidence, and CERT-In cited justification.'),
        ]),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String title, body;
  const _InfoCard(this.icon, this.iconColor, this.bgColor, this.title, this.body, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), boxShadow: kCardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 20)),
        const SizedBox(height: 14),
        Text(title, style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(color: kInkMid, fontSize: 12, height: 1.5)),
      ]),
    ));
  }
}

// ─── Loading View ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 60, height: 60,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF1E40AF), kBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        child: const Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))),
      ),
      const SizedBox(height: 20),
      const Text('Analyzing payload…', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Running NLP · DNS · Entropy · Spoofing modules', style: TextStyle(color: kInkLight, fontSize: 13)),
    ]));
  }
}

// ─── Error View ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(60),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: kRedTint, borderRadius: BorderRadius.circular(14), border: Border.all(color: kRedBorder), boxShadow: kCardShadow),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.error_outline_rounded, color: kRed, size: 22)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Connection Error', style: TextStyle(color: kRed, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(message, style: const TextStyle(color: kRed, fontSize: 13, height: 1.5)),
          ])),
        ]),
      ),
    ));
  }
}

// ─── Report View ──────────────────────────────────────────────────────────────
class _ReportView extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportView({required this.data});

  @override
  Widget build(BuildContext context) {
    final status   = data['status'] as String;
    final score    = data['score']  as int;
    final category = data['scam_category'] as String? ?? 'Unknown';
    final confidence = data['confidence'] as String? ?? '—';
    final networkLogs    = (data['forensic_report']?['network_analysis']   as List?) ?? [];
    final linguisticLogs = (data['forensic_report']?['linguistic_analysis'] as List?) ?? [];
    final highlights     = (data['highlights'] as List?) ?? [];
    final explainability = (data['explainability'] as List?) ?? [];

    Color sColor, tint, border;
    switch (status) {
      case 'High Risk':
        sColor = kRed;   tint = kRedTint;   border = kRedBorder;   break;
      case 'Suspicious':
        sColor = kAmber; tint = kAmberTint; border = kAmberBorder; break;
      default:
        sColor = kGreen; tint = kGreenTint; border = kGreenBorder;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Status Hero ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border.withOpacity(0.5), width: 1.5), boxShadow: kCardShadow),
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: tint, shape: BoxShape.circle, border: Border.all(color: border, width: 2)),
              child: Icon(status == 'High Risk' ? Icons.gpp_bad_rounded : status == 'Suspicious' ? Icons.gpp_maybe_rounded : Icons.verified_rounded, color: sColor, size: 26)),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
                  child: Text(status, style: TextStyle(color: sColor, fontSize: 12, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFDDD6FE))),
                  child: Text('⚑ $category', style: const TextStyle(color: kViolet, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Text(data['summary'] ?? '', style: const TextStyle(color: kInkMid, fontSize: 13, height: 1.5)),
            ])),
            const SizedBox(width: 20),
            Column(children: [
              Text('$score', style: TextStyle(color: sColor, fontSize: 40, fontWeight: FontWeight.w900, height: 1.0, fontFamily: 'Courier New')),
              Text('/100', style: TextStyle(color: sColor.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 8),
              Text('Confidence', style: const TextStyle(color: kInkLight, fontSize: 10, fontWeight: FontWeight.w500)),
              Text(confidence, style: const TextStyle(color: kInk, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Metric Cards ─────────────────────────────────────────────────────
        Row(children: [
          _MetricCard(label: 'Urgency Triggers',      value: data['metrics']?['urgency']       ?? 0, max: 5, color: kAmber,  icon: Icons.bolt_rounded),
          const SizedBox(width: 12),
          _MetricCard(label: 'Financial Keywords',    value: data['metrics']?['financial']     ?? 0, max: 5, color: kViolet, icon: Icons.account_balance_rounded),
          const SizedBox(width: 12),
          _MetricCard(label: 'Network Anomalies',     value: data['metrics']?['url_risk']      ?? 0, max: 3, color: kRed,    icon: Icons.wifi_tethering_error_rounded),
          const SizedBox(width: 12),
          _MetricCard(label: 'Impersonations',        value: data['metrics']?['impersonation'] ?? 0, max: 3, color: kBlue,   icon: Icons.person_off_rounded),
        ]),

        // ── IOCs ─────────────────────────────────────────────────────────────
        if (highlights.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Indicators of Compromise (IOCs)'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: highlights.map((h) =>
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: kRedTint, borderRadius: BorderRadius.circular(6), border: Border.all(color: kRedBorder)),
              child: Text(h.toString(), style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Courier New'))
            )
          ).toList()),
        ],

        // ── Explainability ───────────────────────────────────────────────────
        if (explainability.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Explainability Report (Why was this flagged?)'),
          const SizedBox(height: 12),
          ...explainability.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder), boxShadow: kCardShadow),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kBlueTint, borderRadius: BorderRadius.circular(6), border: Border.all(color: kBlueBorder)),
                  child: Text(e['module'] ?? '', style: const TextStyle(color: kBlue, fontSize: 11, fontWeight: FontWeight.w700))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e['finding'] ?? '', style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(e['evidence'] ?? '', style: const TextStyle(color: kInkMid, fontSize: 12, height: 1.5)),
                ])),
                const SizedBox(width: 14),
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: kRedTint, borderRadius: BorderRadius.circular(6)),
                  child: Text('+${e['weight']}', style: const TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w800))),
              ]),
            ),
          )).toList(),
        ],

        // ── Forensic Logs ─────────────────────────────────────────────────────
        if (networkLogs.isNotEmpty || linguisticLogs.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel('Deep Forensic Log'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), boxShadow: kCardShadow),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (networkLogs.isNotEmpty) ...[
                _LogBlock(title: 'Network & DNS Intelligence', color: kGreen, logs: networkLogs),
              ],
              if (networkLogs.isNotEmpty && linguisticLogs.isNotEmpty)
                const Divider(color: kBorder, height: 32),
              if (linguisticLogs.isNotEmpty)
                _LogBlock(title: 'Semantic Manipulation Vectors', color: kViolet, logs: linguisticLogs),
            ]),
          ),
        ],

        const SizedBox(height: 32),
      ]),
    );
  }
}

// ─── Metric Card ──────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final int value, max;
  final Color color;
  final IconData icon;
  const _MetricCard({required this.label, required this.value, required this.max, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder), boxShadow: kCardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)), child: Icon(icon, color: color, size: 14)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: kInkMid, fontSize: 11, fontWeight: FontWeight.w500))),
          Text('$value', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'Courier New')),
        ]),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
          value: max > 0 ? value / max : 0,
          backgroundColor: const Color(0xFFEEF2FF),
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 5,
        )),
      ]),
    ));
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: kBlue, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _LogBlock extends StatelessWidget {
  final String title;
  final Color color;
  final List logs;
  const _LogBlock({required this.title, required this.color, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      ...logs.map((log) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 5), child: CircleAvatar(radius: 2.5, backgroundColor: kInkLight)),
          const SizedBox(width: 12),
          Expanded(child: Text(log.toString(), style: const TextStyle(color: kInkMid, fontSize: 13, height: 1.55))),
        ]),
      )).toList(),
    ]);
  }
}

// ─── Buttons ──────────────────────────────────────────────────────────────────
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
              colors: _h ? [const Color(0xFF1E3A8A), kBlue] : [kBlue, const Color(0xFF3B82F6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _h
              ? const [BoxShadow(color: Color(0x401D4ED8), blurRadius: 20, offset: Offset(0, 8))]
              : const [BoxShadow(color: Color(0x281D4ED8), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Center(child: widget.loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ])),
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
          width: double.infinity, height: 42,
          decoration: BoxDecoration(
            color: _h ? kAlt : kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _h ? kBlue.withOpacity(0.3) : kBorder),
          ),
          child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.icon, color: _h ? kBlue : kInkMid, size: 16),
            const SizedBox(width: 8),
            Text(widget.label, style: TextStyle(color: _h ? kBlue : kInkMid, fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
        ),
      ),
    );
  }
}
