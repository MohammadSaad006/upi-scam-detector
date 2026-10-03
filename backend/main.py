from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import re
import urllib.parse
import cv2
import numpy as np
import requests
import dns.resolver
import math
from collections import Counter
from datetime import datetime
from typing import Optional

app = FastAPI(
    title="TrustGuard Forensic UPI Intelligence API",
    description="A multi-layered forensic engine for UPI/payment scam detection using Evidence-Based Analysis.",
    version="5.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

scan_history: list = []

# ─── Pydantic Models ─────────────────────────────────────────────────────────

class ExplainabilityNote(BaseModel):
    module: str
    finding: str
    weight: int
    evidence: str

class AnalyzeResponse(BaseModel):
    status: str
    score: int
    confidence: str
    scam_category: str
    summary: str
    highlights: list[str]
    metrics: dict
    forensic_report: dict
    explainability: list[ExplainabilityNote]
    why_flagged: list[str]
    recommended_action: list[str]
    timestamp: str
    scan_id: str

class HistoryItem(BaseModel):
    scan_id: str
    timestamp: str
    status: str
    score: int
    scam_category: str
    preview: str

# ─── Evidence-Based Risk Engine ─────────────────────────────────────────────────

class ForensicAnalyzer:
    def __init__(self):
        # 1. Social Engineering
        self.se_urgency = ["urgent", "urgently", "immediately", "within 24 hours", "suspend", "block", "expire", "action required"]
        self.se_fear = ["deactivated", "penalty", "warrant", "arrest", "fine", "court", "disconnect", "disconnected", "unpaid"]
        self.se_reward = ["lottery", "prize", "winner", "cashback", "lucky draw", "free gift"]
        
        # 2. Payment Behavior
        self.pay_receive = ["receive", "claim", "credited to", "get refund", "cashback of"]
        self.pay_auth = ["pin", "otp", "password", "cvv", "scan qr", "enter upi pin"]
        
        # 3. Identity Signals & Conversational Phishing
        self.impersonation = ["rbi", "income tax", "police", "cbi", "cyber cell", "sbi official", "hdfc support", "electricity board"]
        
        self.conv_familiar = ["bhai", "bro", "dost", "friend", "pehchana", "uncle", "aunty", "mummy", "papa", "sir"]
        self.conv_emergency = ["emergency", "kharab", "hospital", "accident", "zaroorat", "help", "stuck", "problem"]
        self.conv_action = ["paise bhej", "send money", "gpay", "paytm", "phonepe", "naya number", "new number", "transfer", "udhar", "wapas", "return"]

        self.suspicious_tlds = [".xyz", ".top", ".loan", ".win", ".club", ".click", ".asia", ".tk", ".ml", ".cf", ".ga", ".gq", ".info"]
        self.spoof_targets = ["sbi", "hdfc", "icici", "paytm", "phonepe", "gpay", "bank", "axis", "kotak"]

    def calculate_entropy(self, text: str) -> float:
        if not text: return 0.0
        entropy = 0.0
        for x in Counter(text).values():
            p_x = float(x) / len(text)
            entropy -= p_x * math.log2(p_x)
        return round(entropy, 2)

    def resolve_dns(self, domain: str) -> list:
        try:
            answers = dns.resolver.resolve(domain, 'A')
            return [ip.to_text() for ip in answers]
        except Exception:
            return []

    def trace_redirects(self, url: str) -> str:
        try:
            response = requests.head(url, allow_redirects=True, timeout=3)
            return response.url
        except Exception:
            return url

    def extract_urls(self, text: str) -> list:
        return re.findall(r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[^\s]*', text)

    def extract_entities(self, text: str) -> dict:
        phones = re.findall(r'\+?\d{10,14}', text)
        upi_pattern = re.findall(r'[\w.\-]+@[\w.\-]+', text)
        return {"phones": phones, "upi_ids": upi_pattern}

    def analyze_deep(self, text: str) -> dict:
        text_lower = text.lower()
        score = 0
        highlights = []
        explainability = []
        why_flagged = []
        recommended_action = []
        
        metrics = {"urgency": 0, "financial": 0, "url_risk": 0, "impersonation": 0}
        forensic_report = {"network_analysis": [], "linguistic_analysis": [], "entity_extraction": {}}
        
        scam_categories_detected = set()

        # ── 1. Payment Behavior (The Core UPI Logic) ──
        has_receive = any(w in text_lower for w in self.pay_receive)
        has_auth = any(w in text_lower for w in self.pay_auth)
        
        if has_receive and has_auth:
            score += 80
            metrics["financial"] += 2
            scam_categories_detected.add("Payment Reversal / Refund Scam")
            why_flagged.append("✓ Requests UPI PIN/OTP to 'receive' money.")
            recommended_action.append("✕ NEVER enter your UPI PIN to receive funds. PINs are only for sending money.")
            explainability.append({
                "module": "Payment Behavior",
                "finding": "Conflicting payment flow (Receive + Auth)",
                "weight": 80,
                "evidence": "UPI architecture dictates that receiving money NEVER requires entering a PIN. Asking for a PIN to 'claim' money is a definitive scam signature."
            })
        elif has_auth:
            score += 30
            metrics["financial"] += 1
            why_flagged.append("✓ Requests sensitive authentication (PIN/OTP).")
            recommended_action.append("✓ Verify the recipient identity before approving any transaction.")

        # ── 2. Social Engineering (Urgency & Fear) ──
        has_urgency = any(w in text_lower for w in self.se_urgency)
        has_fear = any(w in text_lower for w in self.se_fear)
        
        if has_urgency or has_fear:
            score += 25
            metrics["urgency"] += 1
            if has_fear: scam_categories_detected.add("Coercion / Extortion")
            why_flagged.append("✓ Uses urgency or threat (e.g., account block, disconnection).")
            recommended_action.append("✕ Do not panic or act under pressure. Verify directly with the official service.")
            
        has_utility = any(w in text_lower for w in ["electricity", "power", "unpaid", "bill", "disconnected"])
        if has_utility and (has_urgency or has_fear):
            score += 20
            metrics["urgency"] += 1
            scam_categories_detected.add("Utility Disconnection Scam")
            why_flagged.append("✓ Threatens utility/service disconnection for unpaid bills.")
            
        if any(w in text_lower for w in self.se_reward):
            score += 40
            metrics["urgency"] += 1
            scam_categories_detected.add("Lottery / Prize Scam")
            why_flagged.append("✓ Unsolicited reward or lottery claim.")
            recommended_action.append("✕ Do not pay 'clearance fees' to claim a prize you didn't enter.")

        # ── 3. Identity & Impersonation ──
        for word in self.impersonation:
            if re.search(r'\b' + re.escape(word) + r'\b', text_lower):
                score += 30
                metrics["impersonation"] += 1
                highlights.append(word)
                scam_categories_detected.add("Authority Impersonation")
                why_flagged.append(f"✓ Impersonation of authority/institution ('{word}').")
                recommended_action.append(f"✓ Contact {word.upper()} through their official listed phone number, not the one in this message.")
                break # count once

        # ── 3.5. Conversational Spear Phishing (Hinglish/English) ──
        has_familiar = any(re.search(r'\b' + re.escape(w) + r'\b', text_lower) for w in self.conv_familiar)
        has_emergency = any(re.search(r'\b' + re.escape(w) + r'\b', text_lower) for w in self.conv_emergency) or has_urgency
        has_action = any(re.search(r'\b' + re.escape(w) + r'\b', text_lower) for w in self.conv_action)
        
        if (has_familiar or has_emergency) and has_action:
            score += 45
            metrics["impersonation"] += 1
            scam_categories_detected.add("Spear Phishing / Impersonation")
            why_flagged.append("✓ Detects informal request for money/help, often associated with hijacked accounts or 'new number' impersonation.")
            recommended_action.append("✕ Call the person directly on their OLD, known phone number to verify their identity before sending any money.")

        # ── 4. URL & Network Risk ──
        urls = self.extract_urls(text)
        has_malicious_url = False
        for original_url in urls:
            final_url = self.trace_redirects(original_url)
            if final_url != original_url:
                why_flagged.append(f"✓ URL redirect traced: hiding true destination ({final_url}).")
                
            parsed = urllib.parse.urlparse(final_url)
            domain = parsed.netloc.lower().replace("www.", "")

            # IP obfuscation
            if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$", domain):
                score += 50
                has_malicious_url = True
                scam_categories_detected.add("Phishing Link")
                why_flagged.append(f"✓ Suspicious IP-based URL detected ({domain}).")
                recommended_action.append("✕ Do not click the link. Legitimate organizations use registered domain names.")
            else:
                # DNS Checking
                ips = self.resolve_dns(domain)
                if not ips:
                    score += 20
                    why_flagged.append(f"✓ DNS Resolution Failed: Domain '{domain}' is offline or blacklisted.")

            # Shannon Entropy (DGA Detection)
            entropy = self.calculate_entropy(domain)
            if entropy > 4.0:
                score += 30
                metrics["url_risk"] += 1
                has_malicious_url = True
                scam_categories_detected.add("Algorithmically Generated Link (DGA)")
                why_flagged.append(f"✓ High Shannon Entropy ({entropy}): Domain looks randomly generated by malware.")
                recommended_action.append("✕ Do not click. This is a disposable domain used by cybercriminals.")
                
            # Suspicious TLD
            if any(domain.endswith(tld) for tld in self.suspicious_tlds):
                score += 40
                metrics["url_risk"] += 1
                has_malicious_url = True
                scam_categories_detected.add("Malicious Link")
                why_flagged.append(f"✓ Link uses a high-risk untrusted domain extension.")
                if "✕ Do not open the link or provide any personal details on that page." not in recommended_action:
                    recommended_action.append("✕ Do not open the link or provide any personal details on that page.")

            # Typosquatting
            for target in self.spoof_targets:
                if target in domain and not domain.endswith(f"{target}.com") and not domain.endswith(f"{target}.co.in"):
                    score += 45
                    metrics["url_risk"] += 1
                    has_malicious_url = True
                    scam_categories_detected.add("Brand Spoofing")
                    why_flagged.append(f"✓ Deceptive link trying to look like '{target}'.")
                    if "✕ This is a fake website. Do not enter login credentials." not in recommended_action:
                        recommended_action.append("✕ This is a fake website. Do not enter login credentials.")
                    break

        # ── Finalize Score & Verdict ──
        score = min(score, 100)
        
        # Determine Status and Confidence
        if score >= 70:
            status = "High Risk"
            confidence = "HIGH CONFIDENCE"
            summary = "This payload exhibits definitive scam signatures. Severe risk of financial loss."
            if not recommended_action:
                recommended_action.append("✕ Cease all interaction with the sender.")
        elif score >= 35:
            status = "Suspicious"
            confidence = "MEDIUM CONFIDENCE"
            summary = "Anomalies detected. This payload uses manipulative patterns often found in scams."
        else:
            status = "Safe"
            confidence = "INSUFFICIENT EVIDENCE"
            summary = "No strong scam indicators detected. ⚠ This does NOT prove the message is definitively legitimate, only that it passes heuristic checks."
            if not why_flagged:
                why_flagged.append("✓ Payload conforms to standard communication structures.")
            if not recommended_action:
                recommended_action.append("✓ Always remain vigilant. Verify the sender if you are unsure.")

        scam_category = list(scam_categories_detected)[0] if scam_categories_detected else "General Communication"

        return {
            "status": status,
            "score": score,
            "confidence": confidence,
            "scam_category": scam_category,
            "summary": summary,
            "highlights": list(set(highlights)),
            "metrics": metrics,
            "forensic_report": forensic_report,
            "explainability": explainability,
            "why_flagged": why_flagged,
            "recommended_action": recommended_action
        }

analyzer = ForensicAnalyzer()

# ─── API Endpoints ────────────────────────────────────────────────────────────

@app.post("/api/analyze", response_model=AnalyzeResponse)
async def analyze_content(text: str = Form(...)):
    if not text or not text.strip():
        raise HTTPException(status_code=400, detail="No content provided.")

    result = analyzer.analyze_deep(text)
    scan_id = f"TG-{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')[:18]}"
    timestamp = datetime.utcnow().isoformat() + "Z"

    scan_history.insert(0, {
        "scan_id": scan_id,
        "timestamp": timestamp,
        "status": result["status"],
        "score": result["score"],
        "scam_category": result["scam_category"],
        "preview": text[:80] + ("..." if len(text) > 80 else ""),
    })
    if len(scan_history) > 50:
        scan_history.pop()

    return AnalyzeResponse(**result, timestamp=timestamp, scan_id=scan_id)

@app.post("/api/analyze/qr", response_model=AnalyzeResponse)
async def analyze_qr(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        detector = cv2.QRCodeDetector()
        data, bbox, _ = detector.detectAndDecode(img)

        if not data:
            return AnalyzeResponse(
                status="Safe", score=0, confidence="INSUFFICIENT EVIDENCE",
                scam_category="None", highlights=[],
                summary="No valid QR code payload detected in the provided image.",
                metrics={"qr_read": False}, forensic_report={"qr": "No QR code found"},
                explainability=[], why_flagged=[], recommended_action=["✓ No action needed."],
                timestamp=datetime.utcnow().isoformat() + "Z", scan_id="TG-QR-NOOP",
            )

        result = analyzer.analyze_deep(data)
        result["metrics"]["qr_data_extracted"] = data
        result["summary"] = f"[QR PAYLOAD: {data}]\n\n{result['summary']}"
        scan_id = f"TG-QR-{datetime.utcnow().strftime('%Y%m%d%H%M%S%f')[:16]}"
        timestamp = datetime.utcnow().isoformat() + "Z"

        scan_history.insert(0, {
            "scan_id": scan_id, "timestamp": timestamp,
            "status": result["status"], "score": result["score"],
            "scam_category": result["scam_category"], "preview": f"[QR] {data[:60]}",
        })

        return AnalyzeResponse(**result, timestamp=timestamp, scan_id=scan_id)

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/history", response_model=list[HistoryItem])
async def get_history():
    return scan_history
