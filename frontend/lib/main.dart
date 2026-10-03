import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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
      title: 'Advanced Forensic Engine',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0B1120),
        cardColor: const Color(0xFF1E293B),
        fontFamily: 'Inter',
        useMaterial3: true,
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

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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
      _handleError("Connection failed. Make sure the FastAPI backend is running.");
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
      _handleError("Error processing QR image. Please try again.");
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
      _handleError("Server Error: $statusCode");
    }
  }

  void _handleError(String msg) {
    setState(() {
      _errorMessage = msg;
    });
  }

  Widget _buildMetricsBar(String label, int value, int max, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / max,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(value.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cybersec Forensic Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          indicatorWeight: 4,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.text_snippet), text: "Deep Text/URL Scan"),
            Tab(icon: Icon(Icons.qr_code_scanner), text: "QR Payload Scan"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTextAnalysisTab(),
          _buildQRAnalysisTab(),
        ],
      ),
    );
  }

  Widget _buildTextAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))]
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _textController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Paste suspicious payload (SMS, WhatsApp text, or UPI link) here...",
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: const Color(0xFF0B1120),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.troubleshoot),
                        onPressed: _isLoading ? null : _analyzeText,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        label: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Run Deep Forensic Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
              _buildErrorAndResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQRAnalysisTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_2, size: 100, color: Colors.blueAccent),
          const SizedBox(height: 24),
          const Text(
            "Upload QR for Payload Extraction",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            "Extracts embedded vectors and runs full forensic network analysis.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[400]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.upload_file),
            onPressed: _isLoading ? null : _analyzeQR,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              backgroundColor: Colors.purpleAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            label: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Upload & Analyze Image", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 40),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _buildErrorAndResults(),
          )
        ],
      ),
    );
  }

  Widget _buildErrorAndResults() {
    return Column(
      children: [
        const SizedBox(height: 32),
        if (_errorMessage.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withOpacity(0.5))),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
              ],
            ),
          ),
        if (_result != null) _buildResultDashboard(_result!),
      ],
    );
  }

  Widget _buildResultDashboard(Map<String, dynamic> data) {
    String status = data['status'];
    int score = data['score'];
    Color statusColor = status == "High Risk" ? Colors.redAccent : (status == "Suspicious" ? Colors.orangeAccent : Colors.greenAccent);
    
    return Column(
      children: [
        // Top Card: Summary & Score
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield, color: statusColor, size: 36),
                      const SizedBox(width: 12),
                      Text(status.toUpperCase(), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: statusColor, letterSpacing: 1.5)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: statusColor)
                    ),
                    child: Text("Threat Score: $score/100", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  )
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Executive Summary", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(data['summary'], style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1120),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Heuristic Metrics", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildMetricsBar("Urgency Factor", data['metrics']['urgency'] ?? 0, 5, Colors.orange),
                          _buildMetricsBar("Financial Triggers", data['metrics']['financial'] ?? 0, 5, Colors.purple),
                          _buildMetricsBar("URL Risk Level", data['metrics']['url_risk'] ?? 0, 3, Colors.red),
                        ],
                      ),
                    ),
                  )
                ],
              )
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Detailed Forensic Report Section
        if (data['forensic_report'] != null)
          _buildForensicReport(data['forensic_report'])
      ],
    );
  }

  Widget _buildForensicReport(Map<String, dynamic> forensicData) {
    List networkLogs = forensicData['network_analysis'] ?? [];
    List linguisticLogs = forensicData['linguistic_analysis'] ?? [];
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111827), // Darker for code/logs
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.terminal, color: Colors.greenAccent),
              SizedBox(width: 12),
              Text("Detailed Forensic Analysis Report", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          
          if (networkLogs.isNotEmpty) ...[
            const Text("[+] NETWORK & DNS INTELLIGENCE", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            ...networkLogs.map((log) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text("  > $log", style: const TextStyle(color: Colors.grey, fontFamily: 'monospace')),
            )).toList(),
            const SizedBox(height: 16),
          ],

          if (linguisticLogs.isNotEmpty) ...[
            const Text("[+] SEMANTIC & NLP ANALYSIS", style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            ...linguisticLogs.map((log) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text("  > $log", style: const TextStyle(color: Colors.grey, fontFamily: 'monospace')),
            )).toList(),
          ],
          
          if (networkLogs.isEmpty && linguisticLogs.isEmpty)
            const Text("  > No anomalies detected in payload.", style: TextStyle(color: Colors.grey, fontFamily: 'monospace'))
        ],
      ),
    );
  }
}
