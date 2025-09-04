
#!/usr/bin/env bash
set -euo pipefail
sudo systemctl enable nftables
sudo systemctl start nftables
sudo nft list ruleset || true
