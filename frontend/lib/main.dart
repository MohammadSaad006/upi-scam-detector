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

  String get _apiUrl {
    if (kIsWeb) {
      return Uri.base.origin; // Uses the Vercel domain when hosted
    }
    return 'http://127.0.0.1:8000';
  }

  Future<void> _analyze() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _loading = true; _result = null; _error = ''; });
    try {
      final res = await http.post(Uri.parse('$_apiUrl/api/analyze'), body: {'text': text});
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
      final req = http.MultipartRequest('POST', Uri.parse('$_apiUrl/api/analyze/qr'));
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
      final res = await http.get(Uri.parse('$_apiUrl/api/history'));
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
              Image.asset('assets/logo.jpeg', width: 32, height: 32),
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
                _NavLink(title: 'Test cases', onTap: _populateTestCase),
                _NavLink(title: 'Safety tips', onTap: _showSafetyTips),
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

  void _populateTestCase() {
    _reset();
    _ctrl.text = "Dear Customer, Your HDFC account KYC is pending. It will be blocked today if not updated. Please update immediately at http://hdfc-kyc-update.xyz/login";
  }

  void _showSafetyTips() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MizanTheme.parchment,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.shield_outlined, color: MizanTheme.brass),
            SizedBox(width: 12),
            Text("General Safety Tips", style: TextStyle(color: MizanTheme.ink, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("1. Never share your OTP, PIN, or CVV.", style: TextStyle(height: 1.5, color: MizanTheme.ink, fontSize: 14)),
            SizedBox(height: 12),
            Text("2. Do not click on unknown links sent via SMS or WhatsApp.", style: TextStyle(height: 1.5, color: MizanTheme.ink, fontSize: 14)),
            SizedBox(height: 12),
            Text("3. Always verify the source by contacting the organization directly using their official number.", style: TextStyle(height: 1.5, color: MizanTheme.ink, fontSize: 14)),
            SizedBox(height: 12),
            Text("4. Legitimate banks will not create artificial urgency to suspend your account.", style: TextStyle(height: 1.5, color: MizanTheme.ink, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it", style: TextStyle(color: MizanTheme.sienna, fontWeight: FontWeight.w700)),
          )
        ],
      ),
    );
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
    final status = (d['status'] as String? ?? 'Unknown').toUpperCase();
    
    final isHighRisk = score >= 70 || status.contains('HIGH');
    final isSuspicious = score >= 35 && score < 70 || status.contains('SUSPICIOUS');
    
    final verdictColor = isHighRisk ? MizanTheme.sienna : (isSuspicious ? MizanTheme.brass : MizanTheme.obsidian);
    final verdictBg = isHighRisk ? MizanTheme.highRisk : (isSuspicious ? MizanTheme.suspicious : MizanTheme.safe);
    
    String headline = "NO MAJOR WARNING SIGNS FOUND";
    String subHeadline = "This message does not currently show strong signals associated with common scams.";
    if (isHighRisk) {
      headline = "This looks like a scam.";
      subHeadline = "MIZAN found several warning signs that commonly appear in fraudulent payment or account messages.";
    } else if (isSuspicious) {
      headline = "Be careful before acting on this message.";
      subHeadline = "MIZAN found signals that deserve verification.";
    }

    final whyFlagged = (d['why_flagged'] as List?) ?? [];
    final recommendedAction = (d['recommended_action'] as List?) ?? [];
    final highlights = (d['highlights'] as List?) ?? [];
    
    // We try to make sense of the backend data to map to human-readable cards
    List<Widget> reasonCards = [];
    for (int i = 0; i < whyFlagged.length; i++) {
      String raw = whyFlagged[i].toString();
      String title = "Warning Sign";
      String what = raw.replaceAll('✓', '').trim();
      String why = "This pattern is frequently used by malicious actors.";
      IconData icon = Icons.warning_amber_rounded;
      
      if (raw.toLowerCase().contains('urgency') || raw.toLowerCase().contains('immediately')) {
        title = "Creates urgency";
        icon = Icons.notifications_active_outlined;
        why = "Scammers often create urgency to stop you from thinking or verifying the request.";
      } else if (raw.toLowerCase().contains('url') || raw.toLowerCase().contains('domain') || raw.toLowerCase().contains('link')) {
        title = "Suspicious link";
        icon = Icons.link_rounded;
        why = "A misleading or unfamiliar domain can be used to imitate a legitimate website.";
      } else if (raw.toLowerCase().contains('impersonation') || raw.toLowerCase().contains('informal request') || raw.toLowerCase().contains('spoofing')) {
        title = "Possible impersonation";
        icon = Icons.account_balance_outlined;
        why = "Scammers often imitate trusted organizations or contacts to make requests look genuine.";
      }
      
      reasonCards.add(_buildReasonCard(
        index: i + 1,
        title: title,
        icon: icon,
        whatFound: what,
        whyMatters: why,
      ));
    }

    if (reasonCards.isEmpty) {
      reasonCards.add(_buildReasonCard(index: 1, title: "Clean scan", icon: Icons.check_circle_outline, whatFound: "No immediate threats detected.", whyMatters: "The message passes standard heuristic checks."));
    }

    // Evidence mapping
    List<Widget> evidenceCards = [];
    if (highlights.isNotEmpty) {
      evidenceCards.add(_buildEvidenceCard(
        icon: Icons.chat_bubble_outline,
        title: "Suspicious message text",
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: highlights.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: MizanTheme.highRisk.withOpacity(0.5),
            child: Text(e.toString(), style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 13, color: MizanTheme.sienna, fontWeight: FontWeight.w600)),
          )).toList(),
        )
      ));
    }
    
    String? foundUrl;
    for (var f in whyFlagged) {
      if (f.toString().contains('http')) {
        foundUrl = f.toString().split(' ').firstWhere((e) => e.contains('http'), orElse: () => 'link');
        break;
      }
    }
    if (foundUrl != null) {
      evidenceCards.add(_buildEvidenceCard(
        icon: Icons.link_rounded,
        title: "Link found in message",
        content: Text(foundUrl, style: const TextStyle(fontFamily: 'Roboto Mono', fontSize: 13, color: MizanTheme.ink)),
        badge: "Not an official domain",
      ));
    }

    // Actions
    List<Widget> actionSteps = [];
    for (int i = 0; i < recommendedAction.length; i++) {
      String raw = recommendedAction[i].toString().replaceAll('✕', '').trim();
      actionSteps.add(_buildActionStep(i + 1, raw));
    }
    if (actionSteps.isEmpty) {
      actionSteps.add(_buildActionStep(1, "Verify directly through official channels before acting."));
    }

    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
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
              const SizedBox(height: 24),
              
              // --- HERO SECTION ---
              isDesktop ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _buildVerdictPanel(status, headline, subHeadline, verdictColor, verdictBg, isHighRisk)),
                    const SizedBox(width: 16),
                    _buildScorePanel(score, verdictColor, verdictBg),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildDisclaimerPanel()),
                  ],
                ),
              ) : Column(
                children: [
                  _buildVerdictPanel(status, headline, subHeadline, verdictColor, verdictBg, isHighRisk),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildScorePanel(score, verdictColor, verdictBg)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildDisclaimerPanel(),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // --- WHY FLAGGED SECTION ---
              const _SectionHeader(title: "Why MIZAN flagged this", subtitle: "These are the main warning signs found in your message.", icon: Icons.bar_chart_rounded),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: reasonCards.map((c) => Padding(padding: const EdgeInsets.only(right: 16), child: c)).toList(),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // --- EVIDENCE SECTION ---
              if (evidenceCards.isNotEmpty) ...[
                const _SectionHeader(title: "Evidence we found", subtitle: "These are the specific elements from your message that triggered the risk signals.", icon: Icons.search_rounded),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: evidenceCards,
                ),
                const SizedBox(height: 40),
              ],
              
              // --- ACTION SECTION ---
              Container(
                decoration: BoxDecoration(color: MizanTheme.safe.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: MizanTheme.obsidian.withOpacity(0.1))),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: MizanTheme.obsidian, shape: BoxShape.circle), child: const Icon(Icons.shield_outlined, color: MizanTheme.white, size: 24)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("What you should do now", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MizanTheme.ink, letterSpacing: -0.5)),
                              Text("Follow these steps to keep your money and information safe.", style: TextStyle(fontSize: 14, color: MizanTheme.ink.withOpacity(0.7))),
                            ],
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 32),
                    isDesktop 
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Wrap(
                                spacing: 24, runSpacing: 24,
                                children: actionSteps,
                              )
                            ),
                            if (isHighRisk || isSuspicious) ...[
                              const SizedBox(width: 24),
                              Expanded(flex: 1, child: _buildEmergencyPanel()),
                            ]
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...actionSteps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 16), child: s)),
                            if (isHighRisk || isSuspicious) ...[
                              const SizedBox(height: 16),
                              _buildEmergencyPanel(),
                            ]
                          ],
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerdictPanel(String status, String headline, String subHeadline, Color color, Color bg, bool isHighRisk) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              if (isHighRisk) ...[
                Icon(Icons.warning_rounded, color: color, size: 28),
                const SizedBox(width: 12),
              ],
              Text(status, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 16),
          Text(headline, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: MizanTheme.ink, letterSpacing: -1, height: 1.1)),
          const SizedBox(height: 16),
          Text(subHeadline, style: TextStyle(fontSize: 16, color: MizanTheme.ink.withOpacity(0.8), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildScorePanel(int score, Color color, Color bg) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: bg.withOpacity(0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Text("Risk score", style: TextStyle(fontSize: 14, color: MizanTheme.ink, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Icon(Icons.info_outline, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$score', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w800, color: color, height: 1, letterSpacing: -2)),
                Text('/100', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color.withOpacity(0.7))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(score >= 70 ? "Severe risk" : (score >= 35 ? "Moderate risk" : "Low risk"), style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerPanel() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: MizanTheme.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: MizanTheme.stone.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: MizanTheme.brass, size: 24),
              SizedBox(width: 12),
              Text("What this means", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MizanTheme.ink)),
            ],
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: MizanTheme.ink.withOpacity(0.8), height: 1.5),
              children: const [
                TextSpan(text: "MIZAN's analysis shows indicators of a potential threat. This is "),
                TextSpan(text: "not a diagnosis", style: TextStyle(fontWeight: FontWeight.w700, color: MizanTheme.ink)),
                TextSpan(text: ", but an AI-based risk assessment to help you make a safer decision.\n\n"),
                TextSpan(text: "It is not a guarantee that fraud has occurred. Always verify through the official source before taking any action."),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonCard({required int index, required String title, required IconData icon, required String whatFound, required String whyMatters}) {
    return Container(
      width: 340,
      decoration: BoxDecoration(color: MizanTheme.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: MizanTheme.stone.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('0$index', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MizanTheme.brass)),
                const SizedBox(width: 16),
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: MizanTheme.sienna.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: MizanTheme.sienna, size: 24)),
                const SizedBox(width: 16),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MizanTheme.ink))),
              ],
            ),
          ),
          const Divider(height: 1, color: MizanTheme.stone),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("What we found", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MizanTheme.ink)),
                      const SizedBox(height: 8),
                      Text(whatFound, style: TextStyle(fontSize: 13, color: MizanTheme.ink.withOpacity(0.7), height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: MizanTheme.highRisk.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Why it matters", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MizanTheme.sienna)),
                        const SizedBox(height: 8),
                        Text(whyMatters, style: TextStyle(fontSize: 13, color: MizanTheme.sienna.withOpacity(0.9), height: 1.4)),
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

  Widget _buildEvidenceCard({required IconData icon, required String title, required Widget content, String? badge}) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: MizanTheme.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: MizanTheme.stone.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: MizanTheme.brass, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MizanTheme.ink))),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: MizanTheme.highRisk.withOpacity(0.5), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: MizanTheme.sienna, size: 12),
                      const SizedBox(width: 4),
                      Text(badge, style: const TextStyle(fontSize: 11, color: MizanTheme.sienna, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              ]
            ],
          ),
          const SizedBox(height: 20),
          content,
        ],
      ),
    );
  }

  Widget _buildActionStep(int number, String text) {
    return SizedBox(
      width: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: MizanTheme.obsidian, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$number', style: const TextStyle(color: MizanTheme.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MizanTheme.ink, height: 1.3)),
                const SizedBox(height: 6),
                Text("Follow official procedures.", style: TextStyle(fontSize: 13, color: MizanTheme.ink.withOpacity(0.6))),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmergencyPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: MizanTheme.parchment, borderRadius: BorderRadius.circular(12), border: Border.all(color: MizanTheme.brass.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline_rounded, color: MizanTheme.sienna, size: 24),
              SizedBox(width: 12),
              Expanded(child: Text("If you have already clicked the link or shared information", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: MizanTheme.sienna, height: 1.3))),
            ],
          ),
          const SizedBox(height: 16),
          const Text("Contact your bank or payment provider immediately and follow their security steps.", style: TextStyle(fontSize: 13, color: MizanTheme.ink, height: 1.4)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: MizanTheme.brass, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: MizanTheme.ink, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 14, color: MizanTheme.ink.withOpacity(0.7))),
            ],
          ),
        )
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
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 80, color: MizanTheme.ink),
                    const SizedBox(height: 8),
                    Text('Scan & Pay', style: TextStyle(fontSize: 12, color: MizanTheme.ink.withOpacity(0.6), fontWeight: FontWeight.w600)),
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
                            children: [
                              Text('Payment Request', style: TextStyle(fontSize: 12, color: MizanTheme.ink.withOpacity(0.6), fontWeight: FontWeight.w600)),
                              const Text('₹5,000', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: MizanTheme.ink)),
                              Text('from business@upi', style: TextStyle(fontSize: 12, color: MizanTheme.ink.withOpacity(0.6), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: Border.all(color: MizanTheme.stone), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: const Text('Decline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MizanTheme.ink)))),
                        const SizedBox(width: 12),
                        Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: MizanTheme.stone.withOpacity(0.5), borderRadius: BorderRadius.circular(20)), alignment: Alignment.center, child: const Text('Pay', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: MizanTheme.ink)))),
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
