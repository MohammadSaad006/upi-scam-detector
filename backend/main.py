from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import re
import urllib.parse
import cv2
import numpy as np
import requests
import dns.resolver
import math
from collections import Counter
import socket

app = FastAPI(title="Forensic UPI Scam Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class AnalyzeResponse(BaseModel):
    status: str
    score: int
    summary: str
    highlights: list[str]
    metrics: dict
    forensic_report: dict

class ForensicAnalyzer:
    def __init__(self):
        self.urgency_words = [r"urgently", r"immediately", r"within 24 hours", r"suspend", r"block", r"expire", r"action required"]
        self.financial_words = [r"kyc", r"pan", r"aadhar", r"refund", r"cashback", r"lottery", r"prize", r"winner", r"credited"]
        self.suspicious_tlds = [".xyz", ".top", ".loan", ".win", ".club", ".click", ".asia", ".tk"]
        self.spoof_targets = ["sbi", "hdfc", "icici", "paytm", "phonepe", "gpay", "bank", "axis"]
        
    def calculate_entropy(self, text):
        if not text:
            return 0
        entropy = 0
        for x in Counter(text).values():
            p_x = float(x) / len(text)
            entropy += - p_x * math.log2(p_x)
        return round(entropy, 2)

    def resolve_dns(self, domain):
        try:
            answers = dns.resolver.resolve(domain, 'A')
            return [ip.to_text() for ip in answers]
        except Exception:
            return []

    def trace_redirects(self, url):
        try:
            # Setting a timeout to prevent hanging on malicious sites
            response = requests.head(url, allow_redirects=True, timeout=3)
            if response.history:
                return response.url # The final destination URL
            return url
        except Exception:
            return url

    def extract_urls(self, text):
        return re.findall(r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[^\s]*', text)

    def extract_entities(self, text):
        phones = re.findall(r'\+?\d{10,14}', text)
        emails = re.findall(r'[\w.-]+@[\w.-]+', text)
        upi_ids = [e for e in emails if "upi" in e or "paytm" in e or "ybl" in e or "ibl" in e]
        return {"phones": phones, "upi_ids": upi_ids}

    def analyze_deep(self, text):
        text_lower = text.lower()
        score = 0
        highlights = []
        metrics = {"urgency": 0, "financial": 0, "url_risk": 0}
        
        forensic_report = {
            "network_analysis": [],
            "linguistic_analysis": [],
            "entity_extraction": {}
        }

        # 1. Linguistic & Semantic Analysis
        for word in self.urgency_words:
            if re.search(r'\b' + word + r'\b', text_lower):
                score += 25
                metrics["urgency"] += 1
                highlights.append(word)
                forensic_report["linguistic_analysis"].append(f"High urgency semantic trigger detected: '{word}'")

        for word in self.financial_words:
            if re.search(r'\b' + word + r'\b', text_lower):
                score += 20
                metrics["financial"] += 1
                highlights.append(word)
                forensic_report["linguistic_analysis"].append(f"Financial manipulation trigger detected: '{word}'")

        # 2. Entity Extraction
        entities = self.extract_entities(text_lower)
        forensic_report["entity_extraction"] = entities
        if entities["upi_ids"]:
            for upi in entities["upi_ids"]:
                if re.search(r'fraud|random|cash|prize', upi):
                    score += 40
                    highlights.append(upi)
                    forensic_report["network_analysis"].append(f"Malicious UPI Handle structure detected: {upi}")

        # 3. Deep URL/Network Analysis
        urls = self.extract_urls(text)
        if urls:
            for original_url in urls:
                final_url = self.trace_redirects(original_url)
                if final_url != original_url:
                    forensic_report["network_analysis"].append(f"URL Redirection mapped: {original_url} -> {final_url}")
                
                parsed = urllib.parse.urlparse(final_url)
                domain = parsed.netloc.lower()
                
                # Check for IP address obfuscation
                if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$", domain):
                    score += 50
                    highlights.append(domain)
                    forensic_report["network_analysis"].append(f"Direct IP routing used instead of DNS (Obfuscation): {domain}")
                else:
                    # DNS Resolution
                    ips = self.resolve_dns(domain)
                    if not ips:
                        forensic_report["network_analysis"].append(f"Domain {domain} failed DNS A-record resolution (Possibly blacklisted/dead)")
                    else:
                        forensic_report["network_analysis"].append(f"Domain {domain} resolved to IPs: {', '.join(ips)}")
                
                # Domain Entropy (DGA Detection)
                entropy = self.calculate_entropy(domain)
                if entropy > 4.0:
                    score += 30
                    forensic_report["network_analysis"].append(f"High Shannon Entropy ({entropy}) in domain. Potential DGA (Domain Generation Algorithm).")
                
                # Suspicious TLDs
                if any(domain.endswith(tld) for tld in self.suspicious_tlds):
                    score += 30
                    metrics["url_risk"] += 1
                    highlights.append(domain)
                    forensic_report["network_analysis"].append(f"Domain utilizes a high-risk/cheap TLD common in phishing.")
                    
                # Brand Spoofing (Typosquatting)
                for target in self.spoof_targets:
                    if target in domain and not domain.endswith(f"{target}.com") and not domain.endswith(f"{target}.co.in"):
                        score += 50
                        metrics["url_risk"] += 1
                        highlights.append(target)
                        forensic_report["network_analysis"].append(f"Brand Spoofing Detected: Target '{target}' found in unregulated domain '{domain}'")

        score = min(score, 100)
        
        if score >= 70:
            status = "High Risk"
            summary = "Alert! Forensic analysis confirms this is a phishing or scam attempt. The message utilizes manipulative linguistics and suspicious network routing."
        elif score >= 30:
            status = "Suspicious"
            summary = "Warning! Our engine detected anomalies in the linguistic patterns or URLs. Proceed with extreme caution."
        else:
            status = "Safe"
            summary = "Forensic analysis found no immediate threat vectors (Spoofing, DGA, or High-Risk IPs) in this content."

        return score, status, summary, list(set(highlights)), metrics, forensic_report

analyzer = ForensicAnalyzer()

@app.post("/api/analyze", response_model=AnalyzeResponse)
async def analyze_content(text: str = Form(...)):
    if not text or not text.strip():
        raise HTTPException(status_code=400, detail="No content provided")
        
    score, status, summary, highlights, metrics, forensic = analyzer.analyze_deep(text)
    
    return AnalyzeResponse(
        status=status,
        score=score,
        summary=summary,
        highlights=highlights,
        metrics=metrics,
        forensic_report=forensic
    )

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
                status="Safe",
                score=0,
                summary="No valid QR code detected in the image.",
                highlights=[],
                metrics={"qr_read": False},
                forensic_report={}
            )
            
        score, status, summary, highlights, metrics, forensic = analyzer.analyze_deep(data)
        metrics["qr_data_extracted"] = data
        
        return AnalyzeResponse(
            status=status,
            score=score,
            summary=f"[QR Extracted Payload: {data}]\n\n{summary}",
            highlights=highlights,
            metrics=metrics,
            forensic_report=forensic
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def read_root():
    return {"message": "Forensic Cybersec Engine is online."}
