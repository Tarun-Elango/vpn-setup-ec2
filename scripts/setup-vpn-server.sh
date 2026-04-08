#!/bin/bash

set -e

# ─────────────────────────────────────────────
# WireGuard VPN Server Setup Script
# Usage: sudo ./setup-vpn-server.sh <client_public_key>
# ─────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (sudo ./setup-vpn-server.sh <client_public_key>)"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Error: Missing client public key."
  echo "Usage: sudo ./setup-vpn-server.sh <client_public_key>"
  exit 1
fi

CLIENT_PUBLIC_KEY="$1"

# ── Step 1: Install WireGuard ──────────────────
echo "[1/6] Installing WireGuard..."
apt-get update -y -qq
apt-get install -y wireguard

# ── Step 2: Create config directory ───────────
echo "[2/6] Creating /etc/wireguard directory..."
mkdir -p /etc/wireguard

# ── Step 3: Generate server key pair ──────────
echo "[3/6] Generating server key pair..."
wg genkey > /etc/wireguard/server_private.key
wg pubkey < /etc/wireguard/server_private.key > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key /etc/wireguard/server_public.key

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)

# ── Step 4: Write wg0.conf ────────────────────
echo "[4/6] Creating wg0.conf..."
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -1)
if [ -z "$DEFAULT_IFACE" ]; then
  echo "Error: Could not detect default network interface."
  exit 1
fi
echo "  Detected network interface: ${DEFAULT_IFACE}"
echo "  (debug) ip route show default: $(ip route show default)"
# umask 077 ensures the file is created as 600 (root-only) from the start,
# avoiding any brief window where the private key could be world-readable.
(umask 077; cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIVATE_KEY}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_IFACE} -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = 10.0.0.2/32
EOF
)
# Belt-and-suspenders: explicitly enforce 600 in case umask was overridden
chmod 600 /etc/wireguard/wg0.conf

# ── Step 5: Enable IP forwarding ──────────────
echo "[5/6] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
grep -qxF 'net.ipv4.ip_forward = 1' /etc/sysctl.conf \
  || echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf

# ── Step 6: Start WireGuard ───────────────────
echo "[6/6] Starting WireGuard service..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0 || { echo "ERROR: Failed to start WireGuard"; journalctl -u wg-quick@wg0 --no-pager -n 20; exit 1; }

# ── Done ──────────────────────────────────────
echo ""
echo "============================================"
echo "  WireGuard VPN server setup complete!"
echo "============================================"
echo "  Server Public Key:"
echo "  $(cat /etc/wireguard/server_public.key)"
echo "============================================"
echo "  Use this public key in your client config."
echo "============================================"echo ""
echo "── WireGuard Interface Status ──────────────"
wg show