import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Advanced Forensic Control Center',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Tech light gray
        cardColor: Colors.white,
        fontFamily: 'Inter',
        colorScheme: const ColorScheme.light(primary: Color(0xFF0F172A)),
      ),
      home: const CyberCommandCenter(),
    );
  }
}

class CyberCommandCenter extends StatefulWidget {
  const CyberCommandCenter({super.key});

  @override
  State<CyberCommandCenter> createState() => _CyberCommandCenterState();
}

class _CyberCommandCenterState extends State<CyberCommandCenter> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String _errorMessage = "";
  int _analysisTimeMs = 0;
  
  // Fake telemetry data for the dashboard feel
  final String _systemVersion = "v4.2.0-core";
  final int _threatsBlocked = 14092;

  Future<void> _analyzeText() async {
    if (_textController.text.trim().isEmpty) return;
    _startScan();
    try {
      final stopWatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/api/analyze'),
        body: {'text': _textController.text},
      );
      stopWatch.stop();
      _analysisTimeMs = stopWatch.elapsedMilliseconds;
      _handleResponse(response.statusCode, response.body);
    } catch (e) {
      _handleError("Uplink failed. Backend unreachable.");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _analyzeQR() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      _startScan();
      final stopWatch = Stopwatch()..start();
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
      stopWatch.stop();
      _analysisTimeMs = stopWatch.elapsedMilliseconds;
      
      _handleResponse(response.statusCode, response.body);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['metrics'] != null && data['metrics']['qr_data_extracted'] != null) {
          _textController.text = data['metrics']['qr_data_extracted'];
        }
      }
    } catch (e) {
      _handleError("Vision Engine failed to decode payload.");
    } finally {
      _setLoading(false);
    }
  }

  void _startScan() {
    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = "";
    });
  }

  void _setLoading(bool value) {
    setState(() => _isLoading = value);
  }

  void _handleResponse(int statusCode, String body) {
    if (statusCode == 200) {
      setState(() => _result = json.decode(body));
    } else {
      _handleError("Server Error (CODE: $statusCode)");
    }
  }

  void _handleError(String msg) {
    setState(() => _errorMessage = msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Status Bar (Highly Technical)
          Container(
            height: 48,
            color: const Color(0xFF0F172A), // Dark strip at the top for contrast
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.shield_moon, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 12),
                const Text("TRUSTGUARD FORENSIC TERMINAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 13)),
                const Spacer(),
                _buildTopBadge("SYS_STATE", "ONLINE", const Color(0xFF10B981)),
                const SizedBox(width: 16),
                _buildTopBadge("ENGINE", _systemVersion, const Color(0xFF38BDF8)),
                const SizedBox(width: 16),
                _buildTopBadge("LATENCY", "12ms", const Color(0xFFF59E0B)),
              ],
            ),
          ),
          
          // Main Dashboard Workspace
          Expanded(
            child: Row(
              children: [
                // Left Panel: Payload Input & Controls (Techy form)
                Container(
                  width: 380,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: Color(0xFFCBD5E1), width: 1)),
                  ),
                  child: Column(
                    children: [
                      // Panel Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("PAYLOAD INJECTION", style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
                            SizedBox(height: 4),
                            Text("Awaiting raw text, URL, or optical QR data", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle("TEXT / URL PAYLOAD"),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TextField(
                                  controller: _textController,
                                  maxLines: 7,
                                  style: const TextStyle(fontFamily: 'Courier', fontSize: 13, color: Color(0xFF0F172A), height: 1.5),
                                  decoration: const InputDecoration(
                                    hintText: "> Enter raw data stream here...",
                                    hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                                    contentPadding: EdgeInsets.all(16),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _analyzeText,
                                  icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.radar, size: 18),
                                  label: const Text("EXECUTE TEXT SCAN", style: TextStyle(letterSpacing: 1.0, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 40),
                              _buildSectionTitle("OPTICAL PAYLOAD (QR)"),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                                  borderRadius: BorderRadius.circular(4),
                                  color: const Color(0xFFF8FAFC),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(Icons.qr_code_scanner, size: 48, color: Color(0xFF64748B)),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _isLoading ? null : _analyzeQR,
                                        icon: const Icon(Icons.upload_file, size: 16),
                                        label: const Text("UPLOAD & DECODE", style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFF0F172A),
                                          side: const BorderSide(color: Color(0xFF94A3B8)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                
                // Right Panel: The Analytics Canvas
                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9), // Tech gray background
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mini Stats Row
                        Row(
                          children: [
                            _buildStatCard("THREATS NEUTRALIZED", _threatsBlocked.toString(), Icons.gpp_good),
                            const SizedBox(width: 16),
                            _buildStatCard("NLP ENGINE", "ACTIVE", Icons.memory),
                            const SizedBox(width: 16),
                            _buildStatCard("VISION ENGINE", "STANDBY", Icons.visibility),
                            const SizedBox(width: 16),
                            _buildStatCard("ANALYSIS TIME", _analysisTimeMs > 0 ? "${_analysisTimeMs}ms" : "--", Icons.timer),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // Results Area
                        Expanded(
                          child: _isLoading 
                            ? _buildScanningAnimation()
                            : _errorMessage.isNotEmpty 
                              ? _buildErrorPanel()
                              : _result != null 
                                ? _buildResultsPanel(_result!)
                                : _buildIdlePanel(),
                        )
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTopBadge(String label, String value, Color valueColor) {
    return Row(
      children: [
        Text("$label: ", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5));
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCBD5E1)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF38BDF8), size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'Courier')),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildIdlePanel() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.hub_outlined, size: 80, color: Color(0xFFCBD5E1)),
          SizedBox(height: 24),
          Text("SYSTEM READY. AWAITING PAYLOAD.", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        ],
      ),
    );
  }

  Widget _buildScanningAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3),
          const SizedBox(height: 24),
          const Text("DECONSTRUCTING PAYLOAD...", style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, letterSpacing: 2.0, fontFamily: 'Courier')),
          const SizedBox(height: 8),
          Text("Running Heuristic NLP & DNS Entropy Checks", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildErrorPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), border: Border.all(color: const Color(0xFFEF4444), width: 2), borderRadius: BorderRadius.circular(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SYSTEM FAILURE", style: TextStyle(color: Color(0xFFEF4444), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          const SizedBox(height: 12),
          Text(_errorMessage, style: const TextStyle(color: Color(0xFF991B1B), fontFamily: 'Courier', fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildResultsPanel(Map<String, dynamic> data) {
    String status = data['status'];
    int score = data['score'];
    
    Color riskColor = status == "High Risk" ? const Color(0xFFEF4444) : (status == "Suspicious" ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
    Color bgColor = status == "High Risk" ? const Color(0xFFFEF2F2) : (status == "Suspicious" ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5));
    
    return Column(
      children: [
        // Top Results Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: riskColor, width: 6), top: const BorderSide(color: Color(0xFFCBD5E1)), right: const BorderSide(color: Color(0xFFCBD5E1)), bottom: const BorderSide(color: Color(0xFFCBD5E1))),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("THREAT CLASSIFICATION", style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(status == "High Risk" ? Icons.warning : Icons.verified, color: riskColor, size: 28),
                      const SizedBox(width: 12),
                      Text(status.toUpperCase(), style: TextStyle(color: riskColor, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: riskColor.withOpacity(0.3))),
                child: Column(
                  children: [
                    const Text("RISK SCORE", style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    Text("$score", style: TextStyle(color: riskColor, fontSize: 36, fontWeight: FontWeight.w900, fontFamily: 'Courier')),
                  ],
                ),
              )
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Split view for Summary and Metrics
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary & Forensic Log
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    // Summary Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCBD5E1))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("EXECUTIVE SUMMARY", style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                          const SizedBox(height: 12),
                          Text(data['summary'], style: const TextStyle(color: Color(0xFF475569), fontSize: 14, height: 1.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Terminal Log
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.terminal, color: Color(0xFF10B981), size: 16),
                                SizedBox(width: 8),
                                Text("SYSTEM.FORENSIC_LOG", style: TextStyle(color: Colors.white, fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const Divider(color: Color(0xFF334155)),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _buildForensicLog(data['forensic_report'] ?? {}),
                              ),
                            )
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
              
              const SizedBox(width: 24),
              
              // Technical Metrics Panel
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFCBD5E1))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("VECTOR ANALYSIS", style: TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      const SizedBox(height: 24),
                      _buildTechMetric("Urgency Indicators", data['metrics']['urgency'] ?? 0, 5, const Color(0xFFF59E0B)),
                      const SizedBox(height: 24),
                      _buildTechMetric("Financial Exploits", data['metrics']['financial'] ?? 0, 5, const Color(0xFF8B5CF6)),
                      const SizedBox(height: 24),
                      _buildTechMetric("Network Anomalies", data['metrics']['url_risk'] ?? 0, 3, const Color(0xFFEF4444)),
                      const Spacer(),
                      
                      // Highlighted Triggers
                      if ((data['highlights'] as List).isNotEmpty) ...[
                        const Text("EXTRACTED IOCs (Indicators of Compromise)", style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (data['highlights'] as List).map((h) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), border: Border.all(color: const Color(0xFFEF4444))),
                            child: Text(h.toString(), style: const TextStyle(color: Color(0xFF991B1B), fontFamily: 'Courier', fontSize: 12, fontWeight: FontWeight.bold)),
                          )).toList(),
                        )
                      ]
                    ],
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTechMetric(String label, int value, int max, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w600)),
            Text("$value / $max", style: TextStyle(color: color, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / max,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildForensicLog(Map<String, dynamic> forensicData) {
    List networkLogs = forensicData['network_analysis'] ?? [];
    List linguisticLogs = forensicData['linguistic_analysis'] ?? [];
    
    if (networkLogs.isEmpty && linguisticLogs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Text("> No anomalies detected in current payload stream.", style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Courier', fontSize: 13)),
      );
    }

    List<Widget> logs = [];
    
    if (networkLogs.isNotEmpty) {
      logs.add(const Text("[MODULE: NETWORK_INTEL]", style: TextStyle(color: Color(0xFF38BDF8), fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12)));
      for (var log in networkLogs) {
        logs.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text("> $log", style: const TextStyle(color: Color(0xFFCBD5E1), fontFamily: 'Courier', fontSize: 13)),
        ));
      }
      logs.add(const SizedBox(height: 16));
    }
    
    if (linguisticLogs.isNotEmpty) {
      logs.add(const Text("[MODULE: SEMANTIC_NLP]", style: TextStyle(color: Color(0xFFA78BFA), fontFamily: 'Courier', fontWeight: FontWeight.bold, fontSize: 12)));
      for (var log in linguisticLogs) {
        logs.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text("> $log", style: const TextStyle(color: Color(0xFFCBD5E1), fontFamily: 'Courier', fontSize: 13)),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: logs);
  }
}
