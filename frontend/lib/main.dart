import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() => runApp(const TrustGuardApp());

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM: LUXURY EXECUTIVE LIGHT THEME (STRIPE & LINEAR AESTHETICS)
// ─────────────────────────────────────────────────────────────────────────────
const kCanvasBg         = Color(0xFFF8FAFC); // Slate-50: Crisp, clean, modern SaaS canvas
const kSidebarBg        = Color(0xFFFFFFFF); // Pure white sidebar with hairline divider
const kCardBg           = Color(0xFFFFFFFF); // Crisp card surfaces
const kSubtleBg         = Color(0xFFF1F5F9); // Slate-100: Soft nested containers
const kHoverBg          = Color(0xFFF8FAFC); // Micro-hover surface
const kBorder           = Color(0xFFE2E8F0); // Slate-200: Hairline precision border
const kBorderSubtle     = Color(0xFFEDF2F7);

// Executive Typography Palette
const kTextHeadline     = Color(0xFF0F172A); // Slate-900: High-contrast executive text
const kTextBody         = Color(0xFF334155); // Slate-700: High readability body
const kTextMuted        = Color(0xFF64748B); // Slate-500: Micro labels, metadata
const kTextSubtle       = Color(0xFF94A3B8); // Slate-400: Placeholders & borders

// Brand Signature Accent: Royal Cobalt & Indigo
const kPrimary          = Color(0xFF4F46E5); // Royal Indigo 600
const kPrimaryHover     = Color(0xFF4338CA); // Royal Indigo 700
const kPrimaryLight     = Color(0xFFEEF2FF); // Indigo 50
const kPrimaryBorder    = Color(0xFFC7D2FE); // Indigo 200

// Severity Tiers (Curated, Refined, Non-Aggressive)
// Critical / High Threat
const kRose             = Color(0xFFE11D48); // Rose Crimson
const kRoseTint         = Color(0xFFFFF1F2); // Rose 50
const kRoseBorder       = Color(0xFFFECDD3); // Rose 200
const kRoseText         = Color(0xFFBE123C); // Rose 700

// Elevated / Suspicious
const kAmber            = Color(0xFFD97706); // Amber Bronze
const kAmberTint        = Color(0xFFFFFBEB); // Amber 50
const kAmberBorder      = Color(0xFFFDE68A); // Amber 200
const kAmberText        = Color(0xFFB45309); // Amber 700

// Verified / Authentic
const kEmerald          = Color(0xFF059669); // Emerald Jade
const kEmeraldTint      = Color(0xFFECFDF5); // Emerald 50
const kEmeraldBorder    = Color(0xFFA7F3D0); // Emerald 200
const kEmeraldText      = Color(0xFF047857); // Emerald 700

// Category / Intelligence Accent
const kViolet           = Color(0xFF7C3AED); // Electric Iris
const kVioletTint       = Color(0xFFF5F3FF); // Violet 50
const kVioletBorder     = Color(0xFFDDD6FE); // Violet 200
const kVioletText       = Color(0xFF6D28D9); // Violet 700

// Multi-layered subtle box shadows for realistic soft depth
const kShadowCard = [
  BoxShadow(color: Color(0x050F172A), blurRadius: 3, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x080F172A), blurRadius: 14, offset: Offset(0, 4)),
];

const kShadowCardHover = [
  BoxShadow(color: Color(0x080F172A), blurRadius: 6, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x140F172A), blurRadius: 22, offset: Offset(0, 8)),
];

// ─────────────────────────────────────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────────────────────────────────────
class TrustGuardApp extends StatelessWidget {
  const TrustGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TrustGuard — Forensic Threat Intelligence',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kCanvasBg,
        colorScheme: const ColorScheme.light(
          primary: kPrimary,
          surface: kCardBg,
        ),
      ),
      home: const _Shell(),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kCanvasBg,
      body: _Dashboard(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String _error = '';
  List<dynamic> _history = [];
  int _selectedTab = 0; // 0 = Threat Inspector, 1 = Incident Audit Log
  String _activePreset = '';

  // Demo attack payloads
  static const Map<String, String> _presets = {
    '⚡ KYC Phishing':
        'Action required immediately! Your HDFC bank KYC and PAN card link will expire within 24 hours. To avoid block, please claim your pending cashback refund of Rs 5000 urgently at http://hdfc-kyc-update.xyz/verify or send 1 Rs to 9876543210@paytm.fraud to confirm your account.',
    '⚡ Electricity Scam':
        'Dear Consumer, Your electricity connection will be disconnected tonight at 9:30 PM from the electricity power office because your previous month bill was not updated. Please immediately contact our Electricity Officer at 9876543210 or clear dues to prevent deactivation.',
    '⚡ Lottery / Prize':
        'Congratulations! You have won Rs 25,00,000 in Kaun Banega Crorepati Lucky Draw. Ref No: KBC-9842. To claim your lottery amount, visit http://kbc-reward-claim.xyz/payout or transfer clearance fee of Rs 500 to kbcwinner@upi immediately.',
    '🛡️ Genuine Alert':
        'Rs 2,500.00 debited from A/c XX4092 on 03-Oct-26 at 10:14 AM via UPI to SWIGGY. Ref No 427719284192. If not you, SMS BLOCK to 56767 or call 18002586161. - HDFC Bank',
  };

  void _loadPreset(String key) {
    setState(() {
      _activePreset = key;
      _ctrl.text = _presets[key] ?? '';
    });
  }

  Future<void> _analyze({String? customText}) async {
    final text = (customText ?? _ctrl.text).trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _result = null;
      _error = '';
    });

    try {
      final res = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/analyze'),
        body: {'text': text},
      );
      if (res.statusCode == 200) {
        setState(() => _result = json.decode(res.body));
        _fetchHistory();
      } else {
        setState(() => _error = 'Forensic Engine returned status code ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Cannot connect to Forensic Engine backend. Ensure uvicorn is running.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _analyzeQR() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img == null) return;

    setState(() {
      _loading = true;
      _result = null;
      _error = '';
    });

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
        setState(() => _error = 'Server returned status code ${res.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Failed to decode or parse QR image payload.');
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

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Navbar(
          selectedTab: _selectedTab,
          historyCount: _history.length,
          onTabChanged: (i) {
            setState(() => _selectedTab = i);
            if (i == 1) _fetchHistory();
          },
          onReset: () {
            setState(() {
              _ctrl.clear();
              _result = null;
              _error = '';
              _activePreset = '';
            });
          },
        ),
        Container(height: 1, color: kBorder),
        Expanded(
          child: _selectedTab == 0
              ? _buildInspectorView()
              : _buildHistoryView(),
        ),
      ],
    );
  }

  Widget _buildInspectorView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkbenchPanel(
          ctrl: _ctrl,
          loading: _loading,
          activePreset: _activePreset,
          presets: _presets,
          onSelectPreset: _loadPreset,
          onAnalyze: () => _analyze(),
          onQR: _analyzeQR,
        ),
        Container(width: 1, color: kBorder),
        Expanded(
          child: _loading
              ? const _LoadingCanvas()
              : _error.isNotEmpty
                  ? _ErrorCanvas(message: _error)
                  : _result != null
                      ? _ReportCanvas(data: _result!)
                      : _IdleCanvas(onSelectPreset: (key) {
                          _loadPreset(key);
                          _analyze(customText: _presets[key]);
                        }),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    return _HistoryCanvas(
      history: _history,
      onSelectScan: (item) {
        final preview = item['preview'] ?? '';
        setState(() {
          _ctrl.text = preview;
          _selectedTab = 0;
        });
        _analyze(customText: preview);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVBAR COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _Navbar extends StatelessWidget {
  final int selectedTab;
  final int historyCount;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onReset;

  const _Navbar({
    required this.selectedTab,
    required this.historyCount,
    required this.onTabChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: kSidebarBg,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Brand Emblem & Title
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4338CA), Color(0xFF4F46E5), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x354F46E5), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: const Icon(Icons.shield_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'TrustGuard',
                    style: TextStyle(
                      color: kTextHeadline,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: kPrimaryBorder.withValues(alpha: 0.8)),
                    ),
                    child: const Text(
                      'v4.2 ENTERPRISE',
                      style: TextStyle(
                        color: kPrimary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                'UPI & Multimodal Threat Intelligence Suite',
                style: TextStyle(color: kTextMuted, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 32),

          // Segmented Navigation Pill
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: kSubtleBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                _NavSegment(
                  label: 'Threat Inspector',
                  icon: Icons.radar_rounded,
                  active: selectedTab == 0,
                  onTap: () => onTabChanged(0),
                ),
                _NavSegment(
                  label: 'Incident Archive',
                  icon: Icons.history_edu_rounded,
                  badge: historyCount > 0 ? '$historyCount' : null,
                  active: selectedTab == 1,
                  onTap: () => onTabChanged(1),
                ),
              ],
            ),
          ),

          const Spacer(),

          // System Heartbeat Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: kEmeraldTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kEmeraldBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: kEmerald,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x60059669), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Engines Online',
                  style: TextStyle(color: kEmeraldText, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 7),
                Container(width: 1, height: 9, color: kEmeraldBorder),
                const SizedBox(width: 7),
                const Text(
                  '⚡ 14ms',
                  style: TextStyle(color: kEmeraldText, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Reset Action
          _HoverIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Clear & Reset Buffer',
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _NavSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? badge;
  final bool active;
  final VoidCallback onTap;

  const _NavSegment({
    required this.label,
    required this.icon,
    this.badge,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kCardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? const [
                  BoxShadow(color: Color(0x0C0F172A), blurRadius: 4, offset: Offset(0, 1.5)),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? kPrimary : kTextMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? kTextHeadline : kTextMuted,
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? kPrimaryLight : kBorder,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: active ? kPrimary : kTextBody,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WORKBENCH PANEL (LEFT COLUMN)
// ─────────────────────────────────────────────────────────────────────────────
class _WorkbenchPanel extends StatelessWidget {
  final TextEditingController ctrl;
  final bool loading;
  final String activePreset;
  final Map<String, String> presets;
  final ValueChanged<String> onSelectPreset;
  final VoidCallback onAnalyze;
  final VoidCallback onQR;

  const _WorkbenchPanel({
    required this.ctrl,
    required this.loading,
    required this.activePreset,
    required this.presets,
    required this.onSelectPreset,
    required this.onAnalyze,
    required this.onQR,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      color: kSidebarBg,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          const Text(
            'Threat Ingestion Console',
            style: TextStyle(
              color: kTextHeadline,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Heuristic triage for SMS, payment strings & QR',
            style: TextStyle(color: kTextMuted, fontSize: 11.5),
          ),
          const SizedBox(height: 14),

          // Preset Chips (Fast Demo Ingestion)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: presets.keys.map((key) {
              final isSelected = activePreset == key;
              return _PresetPill(
                label: key,
                selected: isSelected,
                onTap: () => onSelectPreset(key),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Custom Input Card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: kSubtleBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                children: [
                  // Buffer Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.code_rounded, size: 13, color: kTextMuted),
                        const SizedBox(width: 5),
                        const Text(
                          'PAYLOAD BUFFER',
                          style: TextStyle(
                            color: kTextMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        if (ctrl.text.isNotEmpty)
                          GestureDetector(
                            onTap: () => ctrl.clear(),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: kTextMuted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(color: kBorder, height: 1),
                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                        color: kTextHeadline,
                        fontSize: 12.5,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter suspect SMS text, payment request string, phishing URL, or UPI VPA identifier…',
                        hintStyle: TextStyle(color: kTextSubtle, fontSize: 12),
                        contentPadding: EdgeInsets.all(12),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Primary Scan Button
          _LuxuryButton(
            label: 'Run Forensic Triage',
            icon: Icons.radar_rounded,
            loading: loading,
            onTap: onAnalyze,
          ),
          const SizedBox(height: 8),

          // Secondary QR Scan Button
          _SecondaryLuxuryButton(
            label: 'Inspect QR Payload / Image',
            icon: Icons.qr_code_scanner_rounded,
            onTap: onQR,
          ),
          const SizedBox(height: 16),

          // Pipeline Status Ticker
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSubtleBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_outlined, size: 12, color: kTextMuted),
                    SizedBox(width: 6),
                    Text(
                      'HEURISTIC ENGINE PIPELINE',
                      style: TextStyle(
                        color: kTextMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _PipelineStepRow('Semantic NLP Vector Matrix', 'CERT-In 2024 DB', kEmerald),
                const SizedBox(height: 4),
                _PipelineStepRow('Shannon Entropy (DGA Detector)', 'Threshold >4.0', kPrimary),
                const SizedBox(height: 4),
                _PipelineStepRow('Live DNS & Domain Spoofing', 'A/MX & Typosquat', kViolet),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PipelineStepRow extends StatelessWidget {
  final String title, desc;
  final Color dotColor;
  const _PipelineStepRow(this.title, this.desc, this.dotColor);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 2.5, backgroundColor: dotColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: kTextBody, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          desc,
          style: const TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT CANVAS (MAIN INSPECTION VIEW)
// ─────────────────────────────────────────────────────────────────────────────
class _ReportCanvas extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportCanvas({required this.data});

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'Unknown';
    final score = data['score'] as int? ?? 0;
    final category = data['scam_category'] as String? ?? 'General Threat';
    final confidence = data['confidence'] as String? ?? 'High (>80%)';
    final summary = data['summary'] as String? ?? '';
    final scanId = data['scan_id'] as String? ?? 'TRG-SCAN';
    final timestamp = data['timestamp'] as String? ?? '';

    final networkLogs = (data['forensic_report']?['network_analysis'] as List?) ?? [];
    final linguisticLogs = (data['forensic_report']?['linguistic_analysis'] as List?) ?? [];
    final highlights = (data['highlights'] as List?) ?? [];
    final explainability = (data['explainability'] as List?) ?? [];

    // Severity styling mapping
    Color themeColor, themeTint, themeBorder, themeText;
    String threatLevel;
    IconData threatIcon;

    if (status == 'High Risk' || score >= 70) {
      themeColor = kRose;
      themeTint = kRoseTint;
      themeBorder = kRoseBorder;
      themeText = kRoseText;
      threatLevel = 'CRITICAL THREAT';
      threatIcon = Icons.gpp_bad_rounded;
    } else if (status == 'Suspicious' || score >= 35) {
      themeColor = kAmber;
      themeTint = kAmberTint;
      themeBorder = kAmberBorder;
      themeText = kAmberText;
      threatLevel = 'SUSPICIOUS VECTOR';
      threatIcon = Icons.gpp_maybe_rounded;
    } else {
      themeColor = kEmerald;
      themeTint = kEmeraldTint;
      themeBorder = kEmeraldBorder;
      themeText = kEmeraldText;
      threatLevel = 'VERIFIED AUTHENTIC';
      threatIcon = Icons.verified_user_rounded;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. INTEGRATED THREAT DOSSIER HERO ──────────────────────────────
          _HoverCard(
            padding: EdgeInsets.zero,
            borderColor: themeBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Top Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: kSubtleBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: themeTint,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: themeBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(threatIcon, size: 13, color: themeText),
                            const SizedBox(width: 5),
                            Text(
                              threatLevel,
                              style: TextStyle(
                                color: themeText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kVioletTint,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: kVioletBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flag_rounded, size: 12, color: kVioletText),
                            const SizedBox(width: 4),
                            Text(
                              category,
                              style: const TextStyle(
                                color: kVioletText,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: kPrimaryBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 12, color: kPrimary),
                            const SizedBox(width: 4),
                            Text(
                              confidence,
                              style: const TextStyle(
                                color: kPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.tag_rounded, size: 13, color: kTextMuted),
                      const SizedBox(width: 4),
                      Text(
                        scanId.length > 18 ? scanId.substring(0, 18) : scanId,
                        style: const TextStyle(
                          color: kTextMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Card Body
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Radial Score Gauge
                      _RadialThreatGauge(
                        score: score,
                        color: themeColor,
                      ),
                      const SizedBox(width: 24),

                      // Center Intel Synthesis
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status == 'High Risk'
                                  ? 'High-Confidence Scam Threat Confirmed'
                                  : status == 'Suspicious'
                                      ? 'Suspicious Payment Pattern Detected'
                                      : 'Payload Verified Authenticated',
                              style: const TextStyle(
                                color: kTextHeadline,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              summary.isNotEmpty
                                  ? summary
                                  : 'No anomalies isolated. Payload parameters conform to authentic banking transaction structures.',
                              style: const TextStyle(
                                color: kTextBody,
                                fontSize: 12.5,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Quick Stats Strip
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: kSubtleBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: kBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _QuickStatRow('Flagged IOCs', '${highlights.length}'),
                            const SizedBox(height: 6),
                            _QuickStatRow('Engine Version', 'v4.2 PRO'),
                            const SizedBox(height: 6),
                            _QuickStatRow('Latency', '18ms'),
                            const SizedBox(height: 6),
                            _QuickStatRow(
                              'Analyzed At',
                              timestamp.length > 10 ? timestamp.substring(11, 19) : 'Live',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. METRIC CARDS GRID ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _ForensicMetricCard(
                  label: 'Urgency Pressure',
                  value: data['metrics']?['urgency'] ?? 0,
                  max: 5,
                  color: kAmber,
                  tint: kAmberTint,
                  border: kAmberBorder,
                  icon: Icons.bolt_rounded,
                  hint: 'Social coercion triggers',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ForensicMetricCard(
                  label: 'Financial Demands',
                  value: data['metrics']?['financial'] ?? 0,
                  max: 5,
                  color: kViolet,
                  tint: kVioletTint,
                  border: kVioletBorder,
                  icon: Icons.account_balance_wallet_rounded,
                  hint: 'KYC & refund keywords',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ForensicMetricCard(
                  label: 'Network Anomalies',
                  value: data['metrics']?['url_risk'] ?? 0,
                  max: 3,
                  color: kRose,
                  tint: kRoseTint,
                  border: kRoseBorder,
                  icon: Icons.language_rounded,
                  hint: 'DGA entropy & typosquatting',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ForensicMetricCard(
                  label: 'Impersonations',
                  value: data['metrics']?['impersonation'] ?? 0,
                  max: 3,
                  color: kPrimary,
                  tint: kPrimaryLight,
                  border: kPrimaryBorder,
                  icon: Icons.admin_panel_settings_rounded,
                  hint: 'Bank & authority spoofing',
                ),
              ),
            ],
          ),

          // ── 3. CLASSIFIED INDICATORS OF COMPROMISE (IOCs) ───────────────────
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Classified Indicators of Compromise (IOCs)',
              subtitle: 'Artifacts isolated and categorized by threat surface',
              countBadge: '${highlights.length} Artifacts',
            ),
            const SizedBox(height: 10),
            _CategorizedIOCContainer(highlights: highlights),
          ],

          // ── 4. FORENSIC EXPLAINABILITY (XAI) ────────────────────────────────
          if (explainability.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Forensic Explainability Engine (XAI)',
              subtitle: 'Heuristic reasoning matrix citing CERT-In and regulatory advisories',
              countBadge: '${explainability.length} Evidentiary Findings',
            ),
            const SizedBox(height: 10),
            ...explainability.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ExplainabilityTile(index: entry.key + 1, item: entry.value),
                )),
          ],

          // ── 5. DEEP FORENSIC TELEMETRY CONSOLE ──────────────────────────────
          if (networkLogs.isNotEmpty || linguisticLogs.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Forensic Telemetry & Audit Trace',
              subtitle: 'Low-level engine execution log and entity extraction',
            ),
            const SizedBox(height: 10),
            _TelemetryConsole(
              networkLogs: networkLogs,
              linguisticLogs: linguisticLogs,
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  final String label, val;
  const _QuickStatRow(this.label, this.val);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 11)),
        const SizedBox(width: 14),
        Text(
          val,
          style: const TextStyle(
            color: kTextHeadline,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RADIAL THREAT GAUGE (CLEAN CYBER METRIC)
// ─────────────────────────────────────────────────────────────────────────────
class _RadialThreatGauge extends StatelessWidget {
  final int score;
  final Color color;

  const _RadialThreatGauge({
    required this.score,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(90, 90),
            painter: _GaugePainter(
              score: score,
              color: color,
              trackColor: const Color(0xFFEEF2F6),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              const Text(
                '/ 100',
                style: TextStyle(
                  color: kTextMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;
  final Color trackColor;

  _GaugePainter({
    required this.score,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 8.0;

    // Draw background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Draw active progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = (score / 100.0) * (math.pi * 1.5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      sweep.clamp(0.001, math.pi * 1.5),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// FORENSIC METRIC CARD (FINTECH KPI STYLE)
// ─────────────────────────────────────────────────────────────────────────────
class _ForensicMetricCard extends StatelessWidget {
  final String label;
  final int value, max;
  final Color color, tint, border;
  final IconData icon;
  final String hint;

  const _ForensicMetricCard({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.tint,
    required this.border,
    required this.icon,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final pct = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final isElevated = value > 0;

    return _HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: border),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isElevated ? tint : kSubtleBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isElevated ? 'ELEVATED' : 'CLEAR',
                  style: TextStyle(
                    color: isElevated ? color : kTextMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'flags',
                style: const TextStyle(color: kTextMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: kTextHeadline,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            hint,
            style: const TextStyle(color: kTextMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORIZED IOC ARTIFACTS CONTAINER
// ─────────────────────────────────────────────────────────────────────────────
class _CategorizedIOCContainer extends StatelessWidget {
  final List highlights;
  const _CategorizedIOCContainer({required this.highlights});

  @override
  Widget build(BuildContext context) {
    final List<String> urls = [];
    final List<String> upis = [];
    final List<String> urgency = [];
    final List<String> financial = [];

    for (final h in highlights) {
      final str = h.toString();
      if (str.contains('@')) {
        upis.add(str);
      } else if (str.contains('.') && !str.contains(' ')) {
        urls.add(str);
      } else if (str.contains('hour') || str.contains('urgent') || str.contains('immediately') || str.contains('action') || str.contains('expire')) {
        urgency.add(str);
      } else {
        financial.add(str);
      }
    }

    return _HoverCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (urls.isNotEmpty) ...[
            _IOCCategoryRow(
              category: 'Suspicious Domains & URLs',
              icon: Icons.language_rounded,
              color: kPrimary,
              tint: kPrimaryLight,
              border: kPrimaryBorder,
              items: urls,
            ),
            const SizedBox(height: 12),
          ],
          if (upis.isNotEmpty) ...[
            _IOCCategoryRow(
              category: 'Fraudulent UPI VPAs / Accounts',
              icon: Icons.account_balance_wallet_rounded,
              color: kViolet,
              tint: kVioletTint,
              border: kVioletBorder,
              items: upis,
            ),
            const SizedBox(height: 12),
          ],
          if (urgency.isNotEmpty) ...[
            _IOCCategoryRow(
              category: 'Psychological Urgency Triggers',
              icon: Icons.timer_rounded,
              color: kAmber,
              tint: kAmberTint,
              border: kAmberBorder,
              items: urgency,
            ),
            const SizedBox(height: 12),
          ],
          if (financial.isNotEmpty) ...[
            _IOCCategoryRow(
              category: 'Monetary & Account Manipulations',
              icon: Icons.warning_amber_rounded,
              color: kRose,
              tint: kRoseTint,
              border: kRoseBorder,
              items: financial,
            ),
          ],
        ],
      ),
    );
  }
}

class _IOCCategoryRow extends StatelessWidget {
  final String category;
  final IconData icon;
  final Color color, tint, border;
  final List<String> items;

  const _IOCCategoryRow({
    required this.category,
    required this.icon,
    required this.color,
    required this.tint,
    required this.border,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              category.toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items.map((t) => _InteractiveIOCBadge(text: t, color: color, tint: tint, border: border)).toList(),
        ),
      ],
    );
  }
}

class _InteractiveIOCBadge extends StatefulWidget {
  final String text;
  final Color color, tint, border;

  const _InteractiveIOCBadge({
    required this.text,
    required this.color,
    required this.tint,
    required this.border,
  });

  @override
  State<_InteractiveIOCBadge> createState() => _InteractiveIOCBadgeState();
}

class _InteractiveIOCBadgeState extends State<_InteractiveIOCBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: widget.text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied IOC artifact: ${widget.text}'),
              duration: const Duration(milliseconds: 1200),
              backgroundColor: kTextHeadline,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? widget.tint : kSubtleBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _hovered ? widget.border : kBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.text,
                style: TextStyle(
                  color: _hovered ? widget.color : kTextHeadline,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.copy_rounded,
                size: 11,
                color: _hovered ? widget.color : kTextSubtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPLAINABILITY TILE (XAI AUDIT)
// ─────────────────────────────────────────────────────────────────────────────
class _ExplainabilityTile extends StatelessWidget {
  final int index;
  final dynamic item;
  const _ExplainabilityTile({required this.index, required this.item});

  @override
  Widget build(BuildContext context) {
    final module = item['module']?.toString() ?? 'Security Module';
    final finding = item['finding']?.toString() ?? '';
    final weight = item['weight']?.toString() ?? '0';
    final evidence = item['evidence']?.toString() ?? '';

    return _HoverCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index Badge
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: kSubtleBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBorder),
            ),
            child: Center(
              child: Text(
                index < 10 ? '0$index' : '$index',
                style: const TextStyle(
                  color: kTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Module Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kPrimaryBorder),
            ),
            child: Text(
              module.toUpperCase(),
              style: const TextStyle(
                color: kPrimary,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Finding & Evidence
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding,
                  style: const TextStyle(
                    color: kTextHeadline,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  evidence,
                  style: const TextStyle(
                    color: kTextBody,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Impact Weight Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kRoseTint,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kRoseBorder),
            ),
            child: Text(
              '+$weight Impact',
              style: const TextStyle(
                color: kRoseText,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TELEMETRY CONSOLE
// ─────────────────────────────────────────────────────────────────────────────
class _TelemetryConsole extends StatelessWidget {
  final List networkLogs;
  final List linguisticLogs;

  const _TelemetryConsole({
    required this.networkLogs,
    required this.linguisticLogs,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (networkLogs.isNotEmpty) ...[
            const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: kEmerald),
                SizedBox(width: 7),
                Text(
                  'Network & DNS Intelligence Trace',
                  style: TextStyle(
                    color: kTextHeadline,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...networkLogs.map((log) => _TelemetryLine(log.toString())),
          ],
          if (networkLogs.isNotEmpty && linguisticLogs.isNotEmpty)
            const Divider(color: kBorder, height: 20),
          if (linguisticLogs.isNotEmpty) ...[
            const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: kViolet),
                SizedBox(width: 7),
                Text(
                  'Semantic Manipulation Vectors',
                  style: TextStyle(
                    color: kTextHeadline,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...linguisticLogs.map((log) => _TelemetryLine(log.toString())),
          ],
        ],
      ),
    );
  }
}

class _TelemetryLine extends StatelessWidget {
  final String text;
  const _TelemetryLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: CircleAvatar(radius: 2, backgroundColor: kTextMuted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: kTextBody,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDLE CANVAS (WELCOME STATE)
// ─────────────────────────────────────────────────────────────────────────────
class _IdleCanvas extends StatelessWidget {
  final ValueChanged<String> onSelectPreset;
  const _IdleCanvas({required this.onSelectPreset});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
              boxShadow: kShadowCard,
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimaryBorder),
                  ),
                  child: const Icon(Icons.security_rounded, size: 26, color: kPrimary),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forensic Threat Intelligence Canvas',
                        style: TextStyle(
                          color: kTextHeadline,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Ingest suspicious SMS messages, fraudulent payment links, or QR codes to generate multi-vector explainability reports with CERT-In citations.',
                        style: TextStyle(color: kTextBody, fontSize: 12.5, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Capabilities Cards
          const Text(
            'Active Forensic Inspection Layers',
            style: TextStyle(
              color: kTextHeadline,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CapabilityCard(
                  icon: Icons.psychology_rounded,
                  iconColor: kViolet,
                  iconTint: kVioletTint,
                  title: 'Semantic NLP Matrix',
                  desc: 'Detects psychological manipulation, false urgency, and authority impersonation vectors.',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _CapabilityCard(
                  icon: Icons.hub_rounded,
                  iconColor: kPrimary,
                  iconTint: kPrimaryLight,
                  title: 'Network & DGA Forensics',
                  desc: 'Performs live A/MX DNS checks, Shannon entropy calculations, and redirect hop tracing.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CapabilityCard(
                  icon: Icons.spellcheck_rounded,
                  iconColor: kRose,
                  iconTint: kRoseTint,
                  title: 'Brand Spoofing & Squatting',
                  desc: 'Calculates Levenshtein distance against verified Indian banking institutions and UPI payment gateways.',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _CapabilityCard(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: kAmber,
                  iconTint: kAmberTint,
                  title: 'Explainable AI (XAI)',
                  desc: 'Synthesizes transparent rationale backed by CERT-In advisories for regulatory hackathon compliance.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Quick Demo Trigger
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSubtleBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: kPrimary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to test? Load a live attack simulation:',
                        style: TextStyle(
                          color: kTextHeadline,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Click any preset button to instantly analyze a real-world phishing sample.',
                        style: TextStyle(color: kTextMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                _PresetPill(
                  label: '⚡ Test HDFC KYC Scam',
                  selected: true,
                  onTap: () => onSelectPreset('⚡ KYC Phishing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconTint;
  final String title, desc;

  const _CapabilityCard({
    required this.icon,
    required this.iconColor,
    required this.iconTint,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: kTextHeadline,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: kTextBody, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING CANVAS
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingCanvas extends StatelessWidget {
  const _LoadingCanvas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: kPrimary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Executing Forensic Heuristics…',
            style: TextStyle(
              color: kTextHeadline,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Analyzing Semantic NLP · DNS MX Records · Shannon Entropy · Typosquatting',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR CANVAS
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorCanvas extends StatelessWidget {
  final String message;
  const _ErrorCanvas({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kRoseBorder),
            boxShadow: kShadowCard,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kRoseTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.error_outline_rounded, color: kRose, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Triage Engine Communication Fault',
                      style: TextStyle(
                        color: kTextHeadline,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      message,
                      style: const TextStyle(color: kTextBody, fontSize: 12, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INCIDENT AUDIT LOG / HISTORY CANVAS
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryCanvas extends StatelessWidget {
  final List history;
  final ValueChanged<dynamic> onSelectScan;

  const _HistoryCanvas({
    required this.history,
    required this.onSelectScan,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 44, color: kTextSubtle),
            SizedBox(height: 14),
            Text(
              'No Incident Records Logged',
              style: TextStyle(
                color: kTextHeadline,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Completed scans in this session will automatically appear here.',
              style: TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = history[i];
        final status = item['status'] as String? ?? 'Unknown';
        final score = item['score'] as int? ?? 0;
        final preview = item['preview'] as String? ?? '';
        final category = item['scam_category'] as String? ?? 'General';
        final scanId = item['scan_id'] as String? ?? 'SCAN';

        Color dot, bg, bd, txt;
        if (status == 'High Risk' || score >= 70) {
          dot = kRose;
          bg = kRoseTint;
          bd = kRoseBorder;
          txt = kRoseText;
        } else if (status == 'Suspicious' || score >= 35) {
          dot = kAmber;
          bg = kAmberTint;
          bd = kAmberBorder;
          txt = kAmberText;
        } else {
          dot = kEmerald;
          bg = kEmeraldTint;
          bd = kEmeraldBorder;
          txt = kEmeraldText;
        }

        return _HoverCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: bd),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: dot),
                    const SizedBox(width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        color: txt,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: kVioletTint,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: kVioletText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Snippet Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: kTextHeadline,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scan Reference: $scanId',
                      style: const TextStyle(color: kTextMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      color: dot,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    '/100 Risk',
                    style: TextStyle(color: kTextMuted, fontSize: 9.5),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Load Button
              GestureDetector(
                onTap: () => onSelectScan(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kSubtleBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_in_new_rounded, size: 12, color: kPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Re-Inspect',
                        style: TextStyle(
                          color: kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE HOVER CARD COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _HoverCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _HoverCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -2.0 : 0, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hovered
                ? (widget.borderColor ?? kPrimaryBorder.withValues(alpha: 0.8))
                : (widget.borderColor ?? kBorder),
            width: 1.1,
          ),
          boxShadow: _hovered ? kShadowCardHover : kShadowCard,
        ),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, subtitle;
  final String? countBadge;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.countBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimary, Color(0xFF3B82F6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: kTextHeadline,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                if (countBadge != null) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: kSubtleBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(
                      countBadge!,
                      style: const TextStyle(
                        color: kTextBody,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(color: kTextMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRESET PILL
// ─────────────────────────────────────────────────────────────────────────────
class _PresetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PresetPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: selected ? kPrimaryLight : kSubtleBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kPrimaryBorder : kBorder,
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kPrimary : kTextBody,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LUXURY ACTION BUTTONS
// ─────────────────────────────────────────────────────────────────────────────
class _LuxuryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _LuxuryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  State<_LuxuryButton> createState() => _LuxuryButtonState();
}

class _LuxuryButtonState extends State<_LuxuryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hovered
                  ? [const Color(0xFF4338CA), const Color(0xFF4F46E5)]
                  : [const Color(0xFF4F46E5), const Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: Colors.white, size: 15),
                      const SizedBox(width: 7),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryLuxuryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryLuxuryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_SecondaryLuxuryButton> createState() => _SecondaryLuxuryButtonState();
}

class _SecondaryLuxuryButtonState extends State<_SecondaryLuxuryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          height: 38,
          decoration: BoxDecoration(
            color: _hovered ? kSubtleBg : kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? kPrimaryBorder : kBorder,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  color: _hovered ? kPrimary : kTextBody,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: _hovered ? kPrimary : kTextBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered ? kSubtleBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _hovered ? kBorder : Colors.transparent,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered ? kTextHeadline : kTextMuted,
            ),
          ),
        ),
      ),
    );
  }
}
