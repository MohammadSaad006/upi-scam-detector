# 🛡️ TrustGuard — Forensic UPI Threat Intelligence System
> **Hackathon PS-04 | Cybersecurity Track**  
> A production-grade, multi-layered forensic engine to detect UPI payment scams, phishing, and social engineering attacks in real time.

---

## 🔴 The Problem

India processes **14 billion UPI transactions per month**. In FY2023-24, Indian citizens lost ₹1,750+ crore to UPI-related financial fraud. Existing payment apps only flag transactions **after** the money is gone. There is no tool that analyzes the **message or QR code** a victim receives *before* they act.

**TrustGuard intercepts the threat at the social engineering layer — before any payment is made.**

---

## 🧠 How It Actually Works (No Hype)

This is **not** a black-box "AI says scam" classifier. TrustGuard runs a deterministic, transparent, multi-module forensic pipeline. Every finding is explainable and traceable.

### Detection Pipeline

```
Raw Input (Text / SMS / URL / QR Image)
        │
        ▼
┌───────────────────────────────────────────────────────┐
│  Module 1: Semantic NLP                               │
│  → Urgency trigger detection (20 pts/trigger)         │
│  → Financial keyword extraction (15 pts/keyword)      │
│  → Authority impersonation detection (30 pts/keyword) │
│  → Social engineering pattern matching                │
└───────────────────┬───────────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────────┐
│  Module 2: Entity Extraction                          │
│  → UPI handle analysis & anomaly scoring              │
│  → Phone number extraction                            │
│  → Malformed UPI keyword inspection                   │
└───────────────────┬───────────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────────┐
│  Module 3: Network & DNS Forensics                    │
│  → Live DNS A-record resolution                       │
│  → Redirect chain tracing (URL unshortening)          │
│  → Raw IP obfuscation detection (+50 pts)             │
│  → Shannon Entropy analysis for DGA domains (>4.0)    │
│  → High-risk TLD classification (APWG blacklist)      │
│  → Brand spoofing / typosquatting detection           │
└───────────────────┬───────────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────────┐
│  Module 4: Scam Category Classifier                   │
│  → KYC Fraud / Refund Scam / Lottery / OTP Phishing   │
│  → Authority Impersonation / Malicious URL            │
│  → Social Engineering                                 │
└───────────────────┬───────────────────────────────────┘
                    │
                    ▼
┌───────────────────────────────────────────────────────┐
│  Module 5: Explainability Engine                      │
│  → Per-finding justification with evidence            │
│  → Risk weight breakdown per module                   │
│  → Confidence scoring with probabilistic reasoning    │
└───────────────────────────────────────────────────────┘
        │
        ▼
Threat Score (0–100) + Category + Confidence + Forensic Log
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Client (Flutter Desktop)                │
│  Text/URL Input ──► Analyze ──► Visual Report           │
│  QR Image Upload ──► OpenCV Decode ──► Full Analysis    │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP/REST (POST /api/analyze)
                         ▼
┌─────────────────────────────────────────────────────────┐
│              FastAPI Backend (Python 3.12)               │
│                                                         │
│  ┌──────────────┐  ┌───────────────┐  ┌─────────────┐ │
│  │  NLP Engine  │  │ DNS Resolver  │  │  OpenCV     │ │
│  │  (Regex+NLP) │  │  (dnspython)  │  │  QR Decoder │ │
│  └──────────────┘  └───────────────┘  └─────────────┘ │
│                                                         │
│  Endpoints:                                             │
│  POST /api/analyze      → Text/URL forensic scan        │
│  POST /api/analyze/qr   → QR image decode + scan        │
│  GET  /api/history      → Session scan history          │
│  GET  /api/health       → Engine module status          │
│  GET  /docs             → Interactive Swagger UI         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔬 Detection Capabilities

| Attack Vector | Detection Method | Score Impact |
|---|---|---|
| Urgency Social Engineering | Semantic NLP keyword matching | +20 per trigger |
| Financial Manipulation | NLP keyword extraction | +15 per keyword |
| Authority Impersonation (RBI, Police) | Authority word vector matching | +30 per hit |
| Malicious UPI Handles | Regex entity extraction + keyword check | +35 |
| Raw IP in URL | Regex pattern matching | +50 |
| DGA / Random Domains | Shannon Entropy (threshold: 4.0 bits) | +25 |
| High-risk TLDs (.xyz, .tk, .loan) | APWG-sourced TLD blacklist | +25 |
| Brand Typosquatting | String containment + domain validation | +45 |
| Redirect Chain | Live HTTP HEAD request tracing | +15 |
| QR Code Payload | OpenCV QRCodeDetector → full pipeline | All modules |

---

## 📊 Explainability — What Makes This Different

Unlike black-box classifiers, every finding includes:
- **Which module** raised the alert
- **What was found** (the exact trigger)
- **Why it matters** (cited evidence from CERT-In, RBI, APWG)
- **How much weight** it contributed to the final score

This makes the system **auditable, trustworthy, and suitable for regulatory contexts.**

---

## 🚀 Quick Start

### Prerequisites
- Python 3.10+
- Flutter SDK (Windows / macOS / Linux)

### Backend
```bash
cd backend
pip install -r requirements.txt
python -m uvicorn main:app --reload
# API docs available at: http://127.0.0.1:8000/docs
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d windows   # or -d macos / -d linux
```

---

## 📡 API Reference

### `POST /api/analyze`
```json
// Request (form-data)
{ "text": "Your HDFC KYC will expire within 24 hours. Click http://hdfc-kyc.xyz/verify" }

// Response
{
  "status": "High Risk",
  "score": 95,
  "confidence": "Very High (>95%)",
  "scam_category": "KYC Fraud",
  "summary": "THREAT CONFIRMED. This KYC Fraud attempt uses 4 distinct attack vectors...",
  "highlights": ["kyc", "within 24 hours", "hdfc", "hdfc-kyc.xyz"],
  "metrics": { "urgency": 1, "financial": 1, "url_risk": 2, "impersonation": 0 },
  "forensic_report": {
    "network_analysis": ["Brand spoofing detected: 'hdfc' in 'hdfc-kyc.xyz'..."],
    "linguistic_analysis": ["Urgency trigger: 'within 24 hours'..."],
    "entity_extraction": { "phones": [], "upi_ids": [] }
  },
  "explainability": [
    {
      "module": "Semantic NLP",
      "finding": "Urgency keyword: 'within 24 hours'",
      "weight": 20,
      "evidence": "Used in 73% of phishing messages (CERT-In 2023)"
    }
  ],
  "scan_id": "TG-20241003104500",
  "timestamp": "2024-10-03T10:45:00Z"
}
```

### `POST /api/analyze/qr`
Upload a QR code image (`multipart/form-data`, field: `file`). OpenCV extracts the payload and runs the full forensic pipeline.

### `GET /api/history`
Returns the last 50 scans in the current session.

### `GET /api/health`
Returns engine module status and supported scam categories.

---

## 🔮 Roadmap

- [ ] **LLM Integration** — Fine-tuned BERT/DistilBERT on labeled Indian scam SMS corpus (TRAI + CERT-In datasets)
- [ ] **Multilingual Detection** — Hindi, Hinglish, Tamil, Bengali NLP
- [ ] **Persistent Database** — PostgreSQL / MongoDB scan history with analytics
- [ ] **WhatsApp Bot Interface** — Forward any suspicious message for instant analysis
- [ ] **Threat Intelligence Feed** — Real-time domain blacklist sync (APWG, Google Safe Browsing API)
- [ ] **Mobile App** — Android/iOS via Flutter cross-compilation
- [ ] **API-as-a-Service** — B2B integration endpoint for payment apps (PhonePe, Paytm SDK)

---

## 🧪 Test Cases

```
HIGH RISK:
"Action required immediately! Your HDFC bank KYC and PAN card link will expire within 24 hours.
 Claim your cashback refund at http://hdfc-kyc-update.xyz/verify or send 1 Rs to 9876543210@paytm.fraud"

SUSPICIOUS:
"Dear customer, your account needs verification. Please update your details within 48 hours."

SAFE:
"You have received Rs 500 from Rahul via UPI. Reference: 4239128392"
```

---

## 👥 Team

> Built for **YCC College Hackathon 2024** — PS-04: UPI Scam Detection & Risk Analysis  
> Cybersecurity Track

---

## 📜 References

- CERT-In Annual Report 2023 — Social Engineering Attack Taxonomy
- APWG eCrime Symposium 2023 — Phishing Domain TLD Analysis
- RBI Annual Report 2023-24 — Digital Payment Fraud Statistics
- TRAI Unsolicited Commercial Communication Framework
