package ai_zta

# Default decision
default decision := {"action": "allow"}

# Main decision rule (OPA v1 syntax uses `if`)
decision := {"action": action} if {
  risk := input.risk_score
  action := decide(risk)
}

# Threshold-based mapping
decide(r) := "allow" if {
  r < data.thresholds.log_only
}

decide(r) := "log" if {
  r >= data.thresholds.log_only
  r < data.thresholds.rate_limit
}

decide(r) := "rate_limit" if {
  r >= data.thresholds.rate_limit
  r < data.thresholds.quarantine
}

decide(r) := "quarantine" if {
  r >= data.thresholds.quarantine
  r < data.thresholds.block
}

decide(r) := "block" if {
  r >= data.thresholds.block
}
