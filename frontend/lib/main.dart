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
      title: 'Premium Threat Intelligence',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Ultra-light Slate
        cardColor: Colors.white,
        fontFamily: 'Inter',
        useMaterial3: true,
        dividerColor: const Color(0xFFE2E8F0), // Subtle Slate
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F172A),
          surface: Colors.white,
        ),
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
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
      _handleError("Connection to analysis server failed.");
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
      _handleError("Failed to process the QR payload.");
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
      setState(() {
        _result = json.decode(body);
      });
    } else {
      _handleError("Server Error ($statusCode)");
    }
  }

  void _handleError(String msg) {
    setState(() {
      _errorMessage = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Premium White Sidebar
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Color(0xFFF1F5F9), width: 2)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                        ]
                      ),
                      child: const Icon(Icons.security, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      "TrustGuard",
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 56),
                const Text("INTELLIGENCE SUITE", style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                _buildNavItem(Icons.document_scanner_outlined, "Text & URL Analysis", 0),
                const SizedBox(height: 12),
                _buildNavItem(Icons.qr_code_scanner_outlined, "QR Payload Decoder", 1),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedIndex == 0 ? "Payload Analysis" : "QR Payload Scanner",
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedIndex == 0 
                            ? "Scan text, SMS, and URLs for sophisticated phishing and social engineering threats."
                            : "Extract and deeply analyze URLs and data embedded in QR codes.",
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 48),
                        
                        if (_selectedIndex == 0) _buildTextScannerUI() else _buildQRScannerUI(),
                        
                        const SizedBox(height: 40),
                        if (_errorMessage.isNotEmpty) _buildErrorBanner(),
                        if (_result != null) _buildProfessionalReport(_result!),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
          _result = null;
          _errorMessage = "";
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent, // Very soft blue
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B), size: 20),
            const SizedBox(width: 14),
            Text(title, style: TextStyle(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF475569), 
              fontSize: 15, 
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTextScannerUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _textController,
            maxLines: 6,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, height: 1.6),
            decoration: const InputDecoration(
              hintText: "Enter the suspicious payload here...",
              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              contentPadding: EdgeInsets.all(24),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _analyzeText,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A), // Slate 900
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("Analyze Payload", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildQRScannerUI() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 80),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.qr_code_2_rounded, size: 40, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 32),
          const Text("Upload QR Image", style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text("PNG, JPG up to 10MB", style: TextStyle(color: Color(0xFF64748B), fontSize: 15)),
          const SizedBox(height: 32),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _analyzeQR,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 32),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 2))
                : const Text("Select Image", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Text(_errorMessage, style: const TextStyle(color: Color(0xFF991B1B), fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildProfessionalReport(Map<String, dynamic> data) {
    String status = data['status'];
    int score = data['score'];
    
    // Premium soft colors for light theme
    Color dotColor = status == "High Risk" ? const Color(0xFFDC2626) : (status == "Suspicious" ? const Color(0xFFD97706) : const Color(0xFF059669));
    Color bgColor = status == "High Risk" ? const Color(0xFFFEF2F2) : (status == "Suspicious" ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));
    Color borderColor = status == "High Risk" ? const Color(0xFFFECACA) : (status == "Suspicious" ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0));
    Color textColor = status == "High Risk" ? const Color(0xFF991B1B) : (status == "Suspicious" ? const Color(0xFFB45309) : const Color(0xFF065F46));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Top Card: Summary & Score
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
            ],
            border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                        child: Icon(status == "High Risk" ? Icons.gpp_bad : Icons.gpp_good, color: dotColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text(status.toUpperCase(), style: TextStyle(color: const Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0))
                    ),
                    child: Text("Threat Score: $score / 100", style: const TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.w700, fontSize: 14)),
                  )
                ],
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFF1F5F9), height: 1, thickness: 2),
              const SizedBox(height: 32),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Executive Summary", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        Text(data['summary'], style: const TextStyle(color: Color(0xFF475569), fontSize: 15, height: 1.6)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0))
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Heuristic Metrics", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                          const SizedBox(height: 20),
                          _buildMetricsBar("Urgency Factor", data['metrics']['urgency'] ?? 0, 5, const Color(0xFFF59E0B)),
                          const SizedBox(height: 12),
                          _buildMetricsBar("Financial Triggers", data['metrics']['financial'] ?? 0, 5, const Color(0xFF8B5CF6)),
                          const SizedBox(height: 12),
                          _buildMetricsBar("URL Risk Level", data['metrics']['url_risk'] ?? 0, 3, const Color(0xFFEF4444)),
                        ],
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Detailed Forensic Report Section
        if (data['forensic_report'] != null)
          _buildForensicReport(data['forensic_report'])
      ],
    );
  }

  Widget _buildMetricsBar(String label, int value, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
            Text(value.toString(), style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / max,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildForensicReport(Map<String, dynamic> forensicData) {
    List networkLogs = forensicData['network_analysis'] ?? [];
    List linguisticLogs = forensicData['linguistic_analysis'] ?? [];
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.02), blurRadius: 16, offset: const Offset(0, 4)),
        ]
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.code_rounded, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 16),
              const Text("Forensic Analysis Log", style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 32),
          
          if (networkLogs.isNotEmpty) ...[
            const Text("NETWORK & DNS INTELLIGENCE", style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            ...networkLogs.map((log) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("→", style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                  const SizedBox(width: 12),
                  Expanded(child: Text(log, style: const TextStyle(color: Color(0xFF334155), fontFamily: 'monospace', fontSize: 13, height: 1.5))),
                ],
              ),
            )).toList(),
            const SizedBox(height: 24),
          ],

          if (linguisticLogs.isNotEmpty) ...[
            const Text("SEMANTIC & NLP ANALYSIS", style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.0)),
            const SizedBox(height: 12),
            ...linguisticLogs.map((log) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("→", style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                  const SizedBox(width: 12),
                  Expanded(child: Text(log, style: const TextStyle(color: Color(0xFF334155), fontFamily: 'monospace', fontSize: 13, height: 1.5))),
                ],
              ),
            )).toList(),
          ],
          
          if (networkLogs.isEmpty && linguisticLogs.isEmpty)
            const Text("No anomalies detected in payload.", style: TextStyle(color: Color(0xFF64748B), fontFamily: 'monospace', fontSize: 14))
        ],
      ),
    );
  }
}
