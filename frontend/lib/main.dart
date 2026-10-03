import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Premium Security Intelligence',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC), // Ultra-soft cool gray
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F172A),
          surface: Colors.white,
        ),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String _errorMessage = "";

  Future<void> _analyzeText() async {
    if (_textController.text.trim().isEmpty) return;
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/analyze'),
        body: {'text': _textController.text},
      );
      _handleResponse(response.statusCode, response.body);
    } catch (e) {
      _handleError("Connection to intelligence server failed.");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _analyzeQR() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      _setLoading(true);
      var uri = Uri.parse('http://127.0.0.1:8000/api/analyze/qr');
      var request = http.MultipartRequest('POST', uri);
      
      if (kIsWeb) {
        Uint8List bytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: image.name));
      } else {
        request.files.add(await http.MultipartFile.fromPath('file', image.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      _handleResponse(response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['metrics'] != null && data['metrics']['qr_data_extracted'] != null) {
          _textController.text = data['metrics']['qr_data_extracted'];
        }
      }
    } catch (e) {
      _handleError("Failed to decode optical payload.");
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
      if (value) {
        _result = null;
        _errorMessage = "";
      }
    });
  }

  void _handleResponse(int statusCode, String body) {
    if (statusCode == 200) {
      setState(() => _result = json.decode(body));
    } else {
      _handleError("Server Error ($statusCode)");
    }
  }

  void _handleError(String msg) {
    setState(() => _errorMessage = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            children: [
              _buildTopNav(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Panel: Input
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Analyze Payload",
                              style: TextStyle(color: Color(0xFF0F172A), fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.0),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "Detect sophisticated phishing attempts, semantic manipulation, and network anomalies in real-time.",
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 48),
                            _buildInputSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 64),
                      // Right Panel: Analysis Canvas
                      Expanded(
                        flex: 6,
                        child: _buildResultSection(),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF0F172A), size: 20),
          ),
          const SizedBox(width: 16),
          const Text(
            "TrustGuard",
            style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          ),
          const Spacer(),
          const Text("v4.2.0 Intelligence Engine", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Data Stream", style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _textController,
              maxLines: 6,
              style: const TextStyle(color: Color(0xFF334155), fontSize: 15, height: 1.6),
              decoration: const InputDecoration(
                hintText: "Paste text message, SMS, or URL...",
                hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                contentPadding: EdgeInsets.all(24),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: HoverButton(
                  text: "Analyze Data",
                  icon: Icons.radar,
                  isLoading: _isLoading,
                  isPrimary: true,
                  onTap: _analyzeText,
                ),
              ),
              const SizedBox(width: 16),
              HoverButton(
                text: "Upload QR",
                icon: Icons.qr_code_scanner,
                isLoading: false,
                isPrimary: false,
                onTap: _analyzeQR,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildResultSection() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 2),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFEF4444))),
      );
    }

    if (_result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 8)),
                ]
              ),
              child: const Icon(Icons.analytics_outlined, size: 40, color: Color(0xFFCBD5E1)),
            ),
            const SizedBox(height: 24),
            const Text("Awaiting Intelligence Scan", style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text("Provide a payload on the left to begin analysis.", style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
          ],
        ),
      );
    }

    final data = _result!;
    String status = data['status'];
    int score = data['score'];
    
    // Apple-like smooth colors
    Color statusColor = status == "High Risk" ? const Color(0xFFEF4444) : (status == "Suspicious" ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    Color bgColor = status == "High Risk" ? const Color(0xFFFEF2F2) : (status == "Suspicious" ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              color: bgColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Threat Classification", style: TextStyle(color: statusColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(status == "High Risk" ? Icons.warning_rounded : Icons.verified_rounded, color: statusColor, size: 32),
                          const SizedBox(width: 12),
                          Text(status, style: TextStyle(color: statusColor, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 4)),
                      ]
                    ),
                    child: Text(score.toString(), style: TextStyle(color: statusColor, fontSize: 24, fontWeight: FontWeight.w800)),
                  )
                ],
              ),
            ),
            
            // Content Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Executive Summary", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Text(data['summary'], style: const TextStyle(color: Color(0xFF475569), fontSize: 15, height: 1.6)),
                    
                    const SizedBox(height: 48),
                    const Text("Heuristic Metrics", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildPremiumMetric("Urgency Indicators", data['metrics']['urgency'] ?? 0, 5, const Color(0xFFF59E0B))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildPremiumMetric("Financial Triggers", data['metrics']['financial'] ?? 0, 5, const Color(0xFF8B5CF6))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildPremiumMetric("Network Anomalies", data['metrics']['url_risk'] ?? 0, 3, const Color(0xFFEF4444))),
                      ],
                    ),
                    
                    if (data['forensic_report'] != null && 
                        ((data['forensic_report']['network_analysis'] as List).isNotEmpty || 
                         (data['forensic_report']['linguistic_analysis'] as List).isNotEmpty)) ...[
                      const SizedBox(height: 48),
                      const Text("Deep Forensic Log", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 24),
                      _buildCleanLogView(data['forensic_report']),
                    ]
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumMetric(String title, int value, int max, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)))),
              Text("$value", style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / max,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCleanLogView(Map<String, dynamic> forensicData) {
    List networkLogs = forensicData['network_analysis'] ?? [];
    List linguisticLogs = forensicData['linguistic_analysis'] ?? [];
    
    List<Widget> logWidgets = [];
    
    if (networkLogs.isNotEmpty) {
      logWidgets.add(const Text("Network & DNS Intelligence", style: TextStyle(color: Color(0xFF059669), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)));
      logWidgets.add(const SizedBox(height: 12));
      for (var log in networkLogs) {
        logWidgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_right_rounded, color: Color(0xFF94A3B8), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(log, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5))),
            ],
          ),
        ));
      }
      logWidgets.add(const SizedBox(height: 16));
    }

    if (linguisticLogs.isNotEmpty) {
      logWidgets.add(const Text("Semantic Manipulation", style: TextStyle(color: Color(0xFF7C3AED), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)));
      logWidgets.add(const SizedBox(height: 12));
      for (var log in linguisticLogs) {
        logWidgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_right_rounded, color: Color(0xFF94A3B8), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(log, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5))),
            ],
          ),
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: logWidgets,
      ),
    );
  }
}

// Custom Hover Button for Premium Interactions
class HoverButton extends StatefulWidget {
  final String text;
  final IconData icon;
  final bool isLoading;
  final bool isPrimary;
  final VoidCallback onTap;

  const HoverButton({
    super.key,
    required this.text,
    required this.icon,
    required this.isLoading,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    Color primaryColor = const Color(0xFF0F172A);
    Color hoverColor = const Color(0xFF1E293B);
    Color secondaryColor = Colors.white;
    Color secondaryHoverColor = const Color(0xFFF1F5F9);

    Color bgColor = widget.isPrimary
        ? (_isHovering ? hoverColor : primaryColor)
        : (_isHovering ? secondaryHoverColor : secondaryColor);
        
    Color textColor = widget.isPrimary ? Colors.white : primaryColor;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: widget.isPrimary ? null : Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: widget.isPrimary && !_isHovering ? [
              BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))
            ] : [],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: textColor, strokeWidth: 2))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(widget.icon, color: textColor, size: 18),
                      const SizedBox(width: 10),
                      Text(widget.text, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
