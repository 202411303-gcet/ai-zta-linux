
import os, time, yaml, json, subprocess, random
from typing import Optional
from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Optional, List
import httpx

POLICY_URL = os.getenv("POLICY_URL", "http://127.0.0.1:8181/v1/data/ai_zta/decision")
IFACE = os.getenv("IFACE", "eth0")
THRESHOLDS = os.getenv("THRESHOLDS", os.path.join(os.path.dirname(__file__), "..", "config", "config.yaml"))

app = FastAPI(title="AI-ZTA Edge Agent")

with open(THRESHOLDS, "r") as f:
    CFG = yaml.safe_load(f)

class Telemetry(BaseModel):
    src_ip: str
    dst_ip: Optional[str] = None
    features: List[float] = Field(default_factory=list)  # placeholder for TCN input
    risk_score: Optional[float] = None

def infer_risk(features):
    # Placeholder: replace with real TCN ensemble
    # Simulate higher risk when feature sum is large
    s = sum(features) if features else random.random()
    # normalize to [0,1]
    score = max(0.0, min(1.0, s % 1.0))
    return score

async def opa_decide(risk_score: float):
    payload = {"input": {"risk_score": risk_score}}
    async with httpx.AsyncClient(timeout=2.0) as client:
        r = await client.post(POLICY_URL, json=payload)
        r.raise_for_status()
        return r.json().get("result", {"action": "allow"})

def enforce(action: str, src_ip: str):
    if action == "allow" or action == "log":
        return {"ok": True, "msg": "no-op"}
    script = os.path.join(os.path.dirname(__file__), "..", "scripts", "enforce.sh")
    cmd = ["sudo", script, action, src_ip]
    # Add VLAN if quarantine
    if action == "quarantine":
        cmd.append(CFG.get("quarantine", {}).get("vlan", "vlan20"))
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        ok = (res.returncode == 0)
        return {"ok": ok, "stdout": res.stdout, "stderr": res.stderr}
    except Exception as e:
        return {"ok": False, "error": str(e)}

@app.post("/score_and_enforce")
async def score_and_enforce(t: Telemetry):
    rs = t.risk_score if t.risk_score is not None else infer_risk(t.features)
    decision = await opa_decide(rs)
    result = enforce(decision.get("action", "allow"), t.src_ip)
    return {"risk_score": rs, "decision": decision, "enforcement": result}

@app.get("/health")
def health():
    return {"status": "ok", "iface": IFACE, "policy": POLICY_URL}
