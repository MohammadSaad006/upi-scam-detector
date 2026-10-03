from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from pydantic import BaseModel
from fastapi.middleware.cors import CORSMiddleware
import re
import urllib.parse
import cv2
import numpy as np

app = FastAPI(title="Advanced UPI Scam Detection API")

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
    highlights: list[str]
    summary: str
    metrics: dict

# --- Advanced Risk Analyzer Module ---

class RiskAnalyzer:
    def __init__(self):
        # High-risk keywords grouped by intent
        self.urgency_words = [r"urgently", r"immediately", r"within 24 hours", r"suspend", r"block", r"blocked", r"expire"]
        self.financial_words = [r"kyc", r"pan", r"aadhar", r"refund", r"cashback", r"lottery", r"prize", r"winner"]
        self.action_words = [r"click here", r"verify now", r"update", r"claim"]
        
        # Known bad TLDs and suspicious domains
        self.suspicious_tlds = [".xyz", ".top", ".loan", ".win", ".club", ".click"]
        self.spoof_targets = ["sbi", "hdfc", "icici", "paytm", "phonepe", "gpay", "bank"]

    def extract_urls(self, text):
        url_pattern = re.compile(r'https?://(?:[-\w.]|(?:%[\da-fA-F]{2}))+[^\s]*')
        return url_pattern.findall(text)

    def analyze_url(self, url):
        score = 0
        highlights = []
        try:
            parsed = urllib.parse.urlparse(url)
            domain = parsed.netloc.lower()
            path = parsed.path.lower()
            
            # 1. IP address instead of domain name
            if re.match(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$", domain):
                score += 40
                highlights.append(domain)
            
            # 2. Suspicious TLDs
            if any(domain.endswith(tld) for tld in self.suspicious_tlds):
                score += 30
                highlights.append(domain)
                
            # 3. Spoofing - e.g., sbi-update-kyc.com
            for target in self.spoof_targets:
                if target in domain and domain != f"{target}.com" and domain != f"{target}.co.in":
                    score += 40
                    highlights.append(target)
            
            # 4. Long / suspicious paths with financial keywords
            if any(word in path for word in ["kyc", "verify", "refund"]):
                score += 20
                highlights.append("verify" if "verify" in path else ("kyc" if "kyc" in path else "refund"))

        except Exception:
            pass
        return score, highlights

    def analyze_text(self, text):
        text_lower = text.lower()
        score = 0
        highlights = []
        
        metrics = {
            "urgency": 0,
            "financial": 0,
            "url_risk": 0
        }

        # 1. Check Urgency
        for word in self.urgency_words:
            if re.search(r'\b' + word + r'\b', text_lower):
                score += 25
                metrics["urgency"] += 1
                highlights.append(word)

        # 2. Check Financial/Scam Themes
        for word in self.financial_words:
            if re.search(r'\b' + word + r'\b', text_lower):
                score += 20
                metrics["financial"] += 1
                highlights.append(word)
                
        # 3. Analyze any URLs in the text
        urls = self.extract_urls(text)
        for url in urls:
            url_score, url_highlights = self.analyze_url(url)
            score += url_score
            metrics["url_risk"] += 1
            highlights.extend(url_highlights)
            
        # 4. Detect suspicious UPI IDs
        if re.search(r'[\w.-]+@[\w.-]+', text_lower) and not urls:
            # basic check if it's not an email, but a typical upi string
            if "upi" in text_lower or "paytm" in text_lower:
                if re.search(r'\b\d{10}@', text_lower) or re.search(r'random|fraud|cash', text_lower):
                    score += 30
                    highlights.append(re.search(r'[\w.-]+@[\w.-]+', text_lower).group())

        # Cap score at 100
        score = min(score, 100)
        
        # Determine Status
        if score >= 70:
            status = "High Risk"
            summary = "Alert! This is highly likely a phishing or scam attempt. The message creates fake urgency and contains suspicious links or financial triggers. DO NOT click any links or share OTPs."
        elif score >= 30:
            status = "Suspicious"
            summary = "Warning! This message contains elements commonly used by scammers. Verify the sender through official channels before proceeding."
        else:
            status = "Safe"
            summary = "This message appears safe. No major risk indicators were found. Still, always exercise caution with personal data."

        return score, status, summary, list(set(highlights)), metrics


analyzer = RiskAnalyzer()

@app.post("/api/analyze", response_model=AnalyzeResponse)
async def analyze_content(text: str = Form(...)):
    if not text or not text.strip():
        raise HTTPException(status_code=400, detail="No content provided")
        
    score, status, summary, highlights, metrics = analyzer.analyze_text(text)
    
    return AnalyzeResponse(
        status=status,
        score=score,
        highlights=highlights,
        summary=summary,
        metrics=metrics
    )

@app.post("/api/analyze/qr", response_model=AnalyzeResponse)
async def analyze_qr(file: UploadFile = File(...)):
    try:
        # Read image
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        # Decode QR
        detector = cv2.QRCodeDetector()
        data, bbox, _ = detector.detectAndDecode(img)
        
        if not data:
            return AnalyzeResponse(
                status="Safe",
                score=0,
                highlights=[],
                summary="No valid QR code detected in the image.",
                metrics={"qr_read": False}
            )
            
        # Analyze the extracted QR data (which is usually a URL or UPI string)
        score, status, summary, highlights, metrics = analyzer.analyze_text(data)
        metrics["qr_data_extracted"] = data
        
        return AnalyzeResponse(
            status=status,
            score=score,
            highlights=highlights,
            summary=f"[QR Data: {data}]\n\n{summary}",
            metrics=metrics
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/")
def read_root():
    return {"message": "Advanced UPI Scam Detection Engine is online."}
