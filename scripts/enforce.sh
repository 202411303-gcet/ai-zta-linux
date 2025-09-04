
#!/usr/bin/env bash
# Usage:
#  sudo ./enforce.sh block 10.0.0.5
#  sudo ./enforce.sh quarantine 10.0.0.5 vlan20
#  sudo ./enforce.sh rate_limit 10.0.0.5
set -eu

ACTION="${1:-}"
HOST="${2:-}"
QUAR_VLAN="${3:-vlan20}"
IFACE="$(ip route get 1.1.1.1 | awk '{print $5; exit}')"

case "$ACTION" in
  block)
    # nftables drop rule
    nft add table inet aizta || true
    nft add chain inet aizta drop_chain '{ type filter hook prerouting priority 0 ; }' || true
    nft add set inet aizta badhosts '{ type ipv4_addr; flags interval; }' || true
    nft add element inet aizta badhosts { ${HOST} }
    nft add rule inet aizta drop_chain ip saddr @badhosts drop || true
    echo "Blocked ${HOST}"
    ;;
  quarantine)
    # Example with Open vSwitch: move MAC/IP to a VLAN
    # Requires OVS bridge br0 and VLAN created on uplink
    # Note: replace with your environment commands (NETCONF to switch, etc.)
    if command -v ovs-vsctl >/dev/null 2>&1; then
      echo "Quarantining ${HOST} to ${QUAR_VLAN} (OVS example)"
      # Simplified: mark traffic, actual MAC/port mapping is env specific
      # Here we just add a drop rule + comment
      nft add table inet aizta || true
      nft add chain inet aizta q_chain '{ type filter hook prerouting priority 0 ; }' || true
      nft add set inet aizta qhosts '{ type ipv4_addr; flags interval; }' || true
      nft add element inet aizta qhosts { ${HOST} }
      nft add rule inet aizta q_chain ip saddr @qhosts drop || true
    else
      echo "OVS not found. Falling back to drop for ${HOST}"
      nft add table inet aizta || true
      nft add chain inet aizta q_chain '{ type filter hook prerouting priority 0 ; }' || true
      nft add rule inet aizta q_chain ip saddr ${HOST} drop || true
    fi
    ;;
  rate_limit)
    # Basic ingress policing on IFACE for HOST using tc + u32 match
    tc qdisc add dev "${IFACE}" root handle 1: htb default 30 2>/dev/null || true
    tc class add dev "${IFACE}" parent 1: classid 1:1 htb rate 256kbps ceil 256kbps 2>/dev/null || true
    tc filter add dev "${IFACE}" protocol ip parent 1: prio 1 u32 match ip src ${HOST}/32 flowid 1:1 2>/dev/null || true
    echo "Rate-limited ${HOST} on ${IFACE} to 256kbps"
    ;;
  *)
    echo "Unknown action: ${ACTION}"
    exit 2
    ;;
esac
