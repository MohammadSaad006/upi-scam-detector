import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Process;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MizanApp());
}

class MizanTheme {
  static const Color parchment = Color(0xFFF5F0E6);
  static const Color obsidian = Color(0xFF10251F);
  static const Color sienna = Color(0xFFB94A2C);
  static const Color brass = Color(0xFFC89A45);
  static const Color ink = Color(0xFF18201D);
  static const Color stone = Color(0xFFDDD6C8);
  static const Color white = Colors.white;

  static const Color safe = Color(0xFFDCE6DD);
  static const Color suspicious = Color(0xFFF2E1BD);
  static const Color highRisk = Color(0xFFE9C5BC);

  static const TextStyle headingHero = TextStyle(fontFamily: 'Inter', fontSize: 84, fontWeight: FontWeight.w800, color: ink, letterSpacing: -2, height: 0.95);
  static const TextStyle headingSection = TextStyle(fontFamily: 'Inter', fontSize: 32, fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.5);
  static const TextStyle bodyText = TextStyle(fontFamily: 'Inter', fontSize: 16, color: ink, height: 1.5);
  
  static final List<BoxShadow> cardShadow = [
    BoxShadow(color: ink.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 20)),
    BoxShadow(color: ink.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
  ];
}

class MizanApp extends StatelessWidget {
  const MizanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MIZAN | Measure before you trust',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: MizanTheme.parchment,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: MizanTheme.sienna,
          surface: MizanTheme.parchment,
          error: MizanTheme.sienna,
        ),
      ),
      home: const MizanHome(),
    );
  }
}

class MizanHome extends StatefulWidget {
  const MizanHome({super.key});
  @override
  State<MizanHome> createState() => _MizanHomeState();
}

class _MizanHomeState extends State<MizanHome> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _error = '';
  List<dynamic> _history = [];
  
  // 0: Message, 1: URL, 2: QR, 3: Payment
  int _inputMode = 0;
  
  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _result = null; _error = ''; });
    try {
      final res = await http.post(Uri.parse('http://127.0.0.1:8000/api/analyze'), body: {'text': text});
      if (res.statusCode == 200) {
        setState(() => _result = json.decode(res.body));
        _fetchHistory();
      } else {
        setState(() => _error = 'Error: \${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Could not connect to the analysis engine.');
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
        if (d['metrics']?['qr_data_extracted'] != null) {
          _ctrl.text = d['metrics']['qr_data_extracted'];
        }
        _fetchHistory();
      } else {
        setState(() => _error = 'Error: \${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Failed to analyze QR code.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:8000/api/history'));
      if (res.statusCode == 200) {
        setState(() => _history = json.decode(res.body));
      }
    } catch (_) {}
  }

  void _reset() {
    setState(() {
      _result = null;
      _error = '';
      _ctrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MizanTheme.parchment,
      body: Stack(
        children: [
          // Background graphic if no result
          if (_result == null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 200,
              child: CustomPaint(painter: BottomWavePainter()),
            ),
          
          Column(
            children: [
              _buildNav(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: _result != null 
                      ? _buildResultView() 
                      : _buildHomeContent(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNav() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Row(
            children: [
              const Icon(Icons.account_balance_rounded, color: MizanTheme.brass, size: 28),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Text('MIZAN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MizanTheme.ink, letterSpacing: 1)),
                      SizedBox(width: 8),
                      Text('ميزان', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: MizanTheme.brass)),
                    ],
                  ),
                  const Text('Measure before you trust.', style: TextStyle(fontSize: 11, color: MizanTheme.ink, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Center Nav
          if (MediaQuery.of(context).size.width > 800)
            Row(
              children: [
                _NavLink(title: 'Analyze', isActive: true, onTap: _reset),
                _NavLink(title: 'How it works', onTap: _openDocumentation),
                _NavLink(title: 'Test cases', onTap: () {}),
                _NavLink(title: 'Safety tips', onTap: () {}),
              ],
            ),
          const Spacer(),
          // Right CTA
          InkWell(
            onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: MizanTheme.obsidian,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: const [
                  Text('Get Started', style: TextStyle(color: MizanTheme.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: MizanTheme.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDocumentation() {
    try {
      if (!kIsWeb && Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', '..\\MIZAN_Project_Documentation.html']);
      }
    } catch (e) {
      debugPrint('Error opening doc: $e');
    }
  }

  Widget _buildHomeContent(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1000;
    
    return Column(
      children: [
        // Hero
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: isDesktop 
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildHeroLeft()),
                  Expanded(flex: 6, child: const EvidenceArtwork()),
                ],
              )
            : Column(
                children: [
                  _buildHeroLeft(),
                  const SizedBox(height: 40),
                  const SizedBox(height: 400, child: EvidenceArtwork()),
                ],
              ),
        ),
        // Combined Input Panel and Features shifted up
        Transform.translate(
          offset: const Offset(0, -220),
          child: Column(
            children: [
              // Input Panel
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: _buildAnalysisInput(),
                  ),
                ),
              ),
              
              const SizedBox(height: 60),
              
              // Features
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: const [
                    FeatureBlock(
                      icon: Icons.find_in_page_outlined, 
                      title: 'Multiple Input Types', 
                      desc: 'Analyze suspicious SMS, WhatsApp forwards, phishing links, QR codes, and malicious UPI payment requests all in one unified dashboard.'
                    ),
                    FeatureBlock(
                      icon: Icons.receipt_long_outlined, 
                      title: 'Exact Evidence', 
                      desc: 'Don\'t just rely on a black-box score. MIZAN highlights the exact keywords, psychological triggers, and URLs that indicate fraud.'
                    ),
                    FeatureBlock(
                      icon: Icons.translate_rounded, 
                      title: 'Works Across Languages', 
                      desc: 'Scammers don\'t just speak English. Our engine understands Hindi, conversational Hinglish, and regional slang used to coerce victims.'
                    ),
                    FeatureBlock(
                      icon: Icons.shield_outlined, 
                      title: 'Clear Explanations', 
                      desc: 'Get clear, actionable advice on why a payload is dangerous, the exact tactics being used, and the immediate steps you should take.'
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              const Text('SCROLL', style: TextStyle(color: MizanTheme.brass, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 2)),
              const Icon(Icons.keyboard_arrow_down_rounded, color: MizanTheme.brass),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroLeft() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FINANCIAL VERIFICATION', style: TextStyle(color: MizanTheme.ink, fontWeight: FontWeight.w700, letterSpacing: 2, fontSize: 12)),
        const SizedBox(height: 24),
        Text('Check before', style: MizanTheme.headingHero.copyWith(fontSize: MediaQuery.of(context).size.width < 600 ? 56 : 84)),
        Text('you pay.', style: TextStyle(fontFamily: 'Inter', fontSize: MediaQuery.of(context).size.width < 600 ? 56 : 84, fontWeight: FontWeight.w800, color: MizanTheme.sienna, letterSpacing: -2, height: 0.95)),
        const SizedBox(height: 32),
        const SizedBox(
          width: 500,
          child: Text(
            'Analyze suspicious messages, links, QR codes or payment requests and understand exactly why they may be Safe, Suspicious, or High Risk — with clear explanations and real evidence.',
            style: MizanTheme.bodyText,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisInput() {
    return Container(
      decoration: BoxDecoration(
        color: MizanTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MizanTheme.cardShadow,
        border: Border.all(color: MizanTheme.stone.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: MizanTheme.stone.withOpacity(0.3))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _InputTab(title: 'Message', icon: Icons.message_outlined, desc: 'SMS, WhatsApp, etc.', isActive: _inputMode == 0, onTap: () => setState(() => _inputMode = 0)),
                  _InputTab(title: 'URL / Link', icon: Icons.link_rounded, desc: 'Check suspicious links', isActive: _inputMode == 1, onTap: () => setState(() => _inputMode = 1)),
                  _InputTab(title: 'QR Code', icon: Icons.qr_code_2_rounded, desc: 'Upload or paste QR', isActive: _inputMode == 2, onTap: () => setState(() => _inputMode = 2)),
                  _InputTab(title: 'Payment Request', icon: Icons.currency_rupee_rounded, desc: 'UPI, amount, recipient', isActive: _inputMode == 3, onTap: () => setState(() => _inputMode = 3)),
                ],
              ),
            ),
          ),
          
          // Input Area
          Padding(
            padding: const EdgeInsets.all(24),
            child: _inputMode == 2
              ? _buildQRDropzone()
              : Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: MizanTheme.parchment.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MizanTheme.stone.withOpacity(0.5)),
                  ),
                  child: TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    onChanged: (_) => setState((){}),
                    style: const TextStyle(color: MizanTheme.ink, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Paste the message you received...',
                      hintStyle: TextStyle(color: MizanTheme.ink.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
          ),
          
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(_error, style: const TextStyle(color: MizanTheme.sienna, fontSize: 13, fontWeight: FontWeight.w600)),
            ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: MizanTheme.ink.withOpacity(0.4)),
                const SizedBox(width: 8),
                Expanded(child: Text('Your data stays private. We don\'t store your messages or payment details.', style: TextStyle(color: MizanTheme.ink.withOpacity(0.5), fontSize: 12))),
                const SizedBox(width: 16),
                Text('${_ctrl.text.length}/1000', style: TextStyle(color: MizanTheme.ink.withOpacity(0.5), fontSize: 12)),
                const SizedBox(width: 16),
                InkWell(
                  onTap: _loading ? null : (_inputMode == 2 ? _analyzeQR : _analyze),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: MizanTheme.sienna,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: MizanTheme.white, strokeWidth: 2))
                      : Row(
                          children: const [
                            Text('Analyze', style: TextStyle(color: MizanTheme.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: MizanTheme.white, size: 16),
                          ],
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRDropzone() {
    return InkWell(
      onTap: _analyzeQR,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: MizanTheme.parchment.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MizanTheme.stone.withOpacity(0.5), style: BorderStyle.solid),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.upload_file_rounded, color: MizanTheme.brass, size: 32),
              SizedBox(height: 8),
              Text('Click to upload QR Code image', style: TextStyle(color: MizanTheme.ink, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
  
  // --- RESULT VIEW ---
  Widget _buildResultView() {
    final d = _result!;
    final score = d['score'] as int? ?? 0;
    final status = d['status'] as String? ?? 'Unknown';
    final summary = d['summary'] as String? ?? '';
    final whyFlagged = (d['why_flagged'] as List?) ?? [];
    final recommendedAction = (d['recommended_action'] as List?) ?? [];
    final highlights = (d['highlights'] as List?) ?? [];
    final metrics = d['metrics'] as Map<String, dynamic>? ?? {};

    Color verdictColor;
    Color verdictBg;
    if (score >= 70 || status.toLowerCase().contains('high')) {
      verdictColor = MizanTheme.sienna;
      verdictBg = MizanTheme.highRisk;
    } else if (score >= 35 || status.toLowerCase().contains('suspicious')) {
      verdictColor = MizanTheme.obsidian;
      verdictBg = MizanTheme.suspicious;
    } else {
      verdictColor = MizanTheme.obsidian;
      verdictBg = MizanTheme.safe;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              InkWell(
                onTap: _reset,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back_rounded, color: MizanTheme.ink, size: 16),
                    SizedBox(width: 8),
                    Text('Back to Analysis', style: TextStyle(color: MizanTheme.ink, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Verdict Header
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: verdictBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: verdictColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: verdictColor, height: 1),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(status.toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: verdictColor, letterSpacing: 2)),
                          const SizedBox(height: 8),
                          Text(summary, style: TextStyle(fontSize: 18, color: verdictColor.withOpacity(0.8), height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Telemetry
              const Text('EXAMINATION TELEMETRY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: MizanTheme.brass)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(width: 200, child: _buildMetricBar('Urgency', metrics['urgency'] ?? 0, 5)),
                  SizedBox(width: 200, child: _buildMetricBar('Financial', metrics['financial'] ?? 0, 5)),
                  SizedBox(width: 200, child: _buildMetricBar('URL Risk', metrics['url_risk'] ?? 0, 3)),
                  SizedBox(width: 200, child: _buildMetricBar('Impersonation', metrics['impersonation'] ?? 0, 3)),
                ],
              ),
              
              const SizedBox(height: 40),
              
              if (highlights.isNotEmpty) ...[
                const Text('EXTRACTED EVIDENCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: MizanTheme.brass)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: highlights.map((e) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: MizanTheme.white, border: Border.all(color: MizanTheme.stone), borderRadius: BorderRadius.circular(4)),
                    child: Text(e.toString(), style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 13, color: MizanTheme.ink)),
                  )).toList(),
                ),
                const SizedBox(height: 40),
              ],
              
              if (whyFlagged.isNotEmpty) ...[
                const Text('WHY FLAGGED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: MizanTheme.brass)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: MizanTheme.white, border: const Border(left: BorderSide(color: MizanTheme.sienna, width: 4)), boxShadow: MizanTheme.cardShadow),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: whyFlagged.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.emergency_outlined, color: MizanTheme.sienna, size: 18),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.toString(), style: const TextStyle(fontSize: 15, color: MizanTheme.ink, height: 1.5))),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 40),
              ],
              
              if (recommendedAction.isNotEmpty) ...[
                const Text('RECOMMENDED ACTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: MizanTheme.brass)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: MizanTheme.white, border: const Border(left: BorderSide(color: MizanTheme.obsidian, width: 4)), boxShadow: MizanTheme.cardShadow),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: recommendedAction.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: MizanTheme.obsidian, size: 18),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.toString(), style: const TextStyle(fontSize: 15, color: MizanTheme.ink, height: 1.5))),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBar(String label, int value, int max) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MizanTheme.ink)),
            Text('\$value/\$max', style: const TextStyle(fontSize: 12, color: MizanTheme.stone)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 4,
          width: double.infinity,
          color: MizanTheme.stone.withOpacity(0.3),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(color: value > 0 ? MizanTheme.sienna : MizanTheme.stone),
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  const _NavLink({required this.title, this.isActive = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: TextStyle(color: MizanTheme.ink, fontSize: 14, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 4),
            Container(height: 2, width: 24, color: isActive ? MizanTheme.brass : Colors.transparent),
          ],
        ),
      ),
    );
  }
}

class _InputTab extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  const _InputTab({required this.title, required this.desc, required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? MizanTheme.white : MizanTheme.parchment.withOpacity(0.3),
          border: Border(bottom: BorderSide(color: isActive ? MizanTheme.sienna : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? MizanTheme.sienna : MizanTheme.ink, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isActive ? MizanTheme.sienna : MizanTheme.ink, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(desc, style: const TextStyle(color: MizanTheme.stone, fontSize: 11), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FeatureBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const FeatureBlock({required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MizanTheme.sienna.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MizanTheme.sienna.withOpacity(0.15)),
            ),
            child: Icon(icon, color: MizanTheme.sienna, size: 32),
          ),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: MizanTheme.ink, letterSpacing: -0.3)),
          const SizedBox(height: 12),
          Text(
            desc, 
            style: TextStyle(fontSize: 15, color: MizanTheme.ink.withOpacity(0.75), height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// BESPOKE ARTWORK WIDGETS
// ----------------------------------------------------

class EvidenceArtwork extends StatelessWidget {
  const EvidenceArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 500,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Painter
          Positioned.fill(child: CustomPaint(painter: ArtworkPainter())),
          
          // Elements
          
          // 1. Message Card
          Positioned(
            top: 20,
            right: 120,
            child: Transform.rotate(
              angle: -0.05,
              child: _buildEvidenceCard(
                width: 280,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.account_circle, size: 16, color: MizanTheme.stone),
                        SizedBox(width: 8),
                        Text('+91 98765 43210', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Spacer(),
                        Text('now', style: TextStyle(fontSize: 10, color: MizanTheme.stone)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontFamily: 'Inter', fontSize: 15, color: MizanTheme.ink, height: 1.4),
                        children: [
                          TextSpan(text: 'Your '),
                          TextSpan(text: 'KYC has expired.', style: TextStyle(backgroundColor: MizanTheme.highRisk, fontWeight: FontWeight.w600)),
                          TextSpan(text: '\n'),
                          TextSpan(text: 'Verify immediately', style: TextStyle(backgroundColor: MizanTheme.highRisk, fontWeight: FontWeight.w600)),
                          TextSpan(text: '\nusing the link below:\n'),
                          TextSpan(text: 'upi-verify.xyz', style: TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
                badge: Icons.priority_high_rounded,
              ),
            ),
          ),
          
          // 2. URL Card
          Positioned(
            top: 240,
            right: 80,
            child: Transform.rotate(
              angle: 0.06,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: MizanTheme.ink,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: MizanTheme.cardShadow,
                  border: Border.all(color: MizanTheme.stone.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: MizanTheme.white.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.link, color: MizanTheme.stone, size: 14),
                    ),
                    const SizedBox(width: 12),
                    const Text('https://upi-verify.xyz/login', style: TextStyle(color: MizanTheme.sienna, fontFamily: 'Roboto Mono', fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: MizanTheme.sienna, shape: BoxShape.circle),
                      child: const Icon(Icons.priority_high_rounded, size: 14, color: MizanTheme.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // 3. QR Card
          Positioned(
            top: 140,
            right: -20,
            child: Transform.rotate(
              angle: 0.04,
              child: _buildEvidenceCard(
                width: 140,
                child: Column(
                  children: const [
                    Icon(Icons.qr_code_2_rounded, size: 80, color: MizanTheme.ink),
                    SizedBox(height: 8),
                    Text('Scan & Pay', style: TextStyle(fontSize: 11, color: MizanTheme.stone)),
                    Text('₹4,999', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: MizanTheme.ink)),
                  ],
                ),
              ),
            ),
          ),
          
          // 4. Payment Request
          Positioned(
            bottom: 60,
            right: 60,
            child: Transform.rotate(
              angle: -0.03,
              child: _buildEvidenceCard(
                width: 260,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: const BoxDecoration(color: MizanTheme.stone, shape: BoxShape.circle),
                          child: const Center(child: Text('P', style: TextStyle(color: MizanTheme.white, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Payment Request', style: TextStyle(fontSize: 11, color: MizanTheme.stone)),
                              Text('₹5,000', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MizanTheme.ink)),
                              Text('from business@upi', style: TextStyle(fontSize: 11, color: MizanTheme.stone)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: Border.all(color: MizanTheme.stone), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                        const SizedBox(width: 12),
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: MizanTheme.stone.withOpacity(0.3), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                      ],
                    ),
                  ],
                ),
                badge: Icons.priority_high_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard({required Widget child, required double width, IconData? badge}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MizanTheme.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: MizanTheme.cardShadow,
        border: Border.all(color: MizanTheme.stone.withOpacity(0.3)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (badge != null)
            Positioned(
              top: -16,
              right: -16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MizanTheme.sienna, 
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: MizanTheme.sienna.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Icon(badge, size: 20, color: MizanTheme.white),
              ),
            ),
        ],
      ),
    );
  }
}

class ArtworkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark Pine abstract background shape
    final paintPine = Paint()..color = MizanTheme.obsidian..style = PaintingStyle.fill;
    final path = Path();
    path.moveTo(size.width * 0.1, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.9);
    path.lineTo(size.width * 0.7, size.height);
    path.lineTo(0, size.height * 0.3);
    path.close();
    canvas.drawPath(path, paintPine);

    // Subtle inner geometric accent
    final paintAccent = Paint()..color = MizanTheme.white.withOpacity(0.02)..style = PaintingStyle.fill;
    final pathAccent = Path();
    pathAccent.moveTo(size.width * 0.3, 0);
    pathAccent.lineTo(size.width * 0.9, 0);
    pathAccent.lineTo(size.width * 0.8, size.height * 0.6);
    pathAccent.lineTo(size.width * 0.2, size.height * 0.2);
    pathAccent.close();
    canvas.drawPath(pathAccent, paintAccent);

    // 2. Brass investigative tracing lines
    final paintBrass = Paint()..color = MizanTheme.brass.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height * 0.2), Offset(size.width * 0.6, size.height * 0.4), paintBrass);
    canvas.drawLine(Offset(size.width * 0.6, size.height * 0.4), Offset(size.width, size.height * 0.2), paintBrass);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.4), 6, paintBrass);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.4), 2, Paint()..color = MizanTheme.obsidian);

    final paintSienna = Paint()..color = MizanTheme.sienna.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2.0;
    canvas.drawLine(Offset(size.width * 0.3, size.height * 0.8), Offset(size.width * 0.8, size.height * 0.95), paintSienna);

    // Background metric ticks
    final paintTicks = Paint()..color = MizanTheme.brass.withOpacity(0.4)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    for (int i = 0; i < 5; i++) {
      canvas.drawLine(Offset(size.width * 0.1, size.height * 0.5 + (i * 15)), Offset(size.width * 0.13, size.height * 0.5 + (i * 15)), paintTicks);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.6);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.2, size.width * 0.6, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.85, size.height * 0.95, size.width, size.height * 0.5);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = MizanTheme.obsidian);
    
    final linePath = Path();
    linePath.moveTo(0, size.height * 0.5);
    linePath.quadraticBezierTo(size.width * 0.3, size.height * 0.1, size.width * 0.6, size.height * 0.6);
    linePath.quadraticBezierTo(size.width * 0.85, size.height * 0.85, size.width, size.height * 0.4);
    canvas.drawPath(linePath, Paint()..color = MizanTheme.brass.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
