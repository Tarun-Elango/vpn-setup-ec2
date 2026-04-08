#!/bin/bash

set -e # tells script to exit immediately on failure

if [ "$EUID" -ne 0 ]; then # check if script is run as root
  echo "Error: Please run as root (sudo ./setup-vpn-server.sh <client_public_key>)"
  exit 1
fi

if [ -z "$1" ]; then # check if client public key argument is provided
  echo "Error: Missing client public key."
  echo "Usage: sudo ./setup-vpn-server.sh <client_public_key>"
  exit 1
fi

CLIENT_PUBLIC_KEY="$1" # get client public key from argument

# ── Step 1: Install WireGuard ──────────────────
echo "[1/6] Installing WireGuard..."
apt-get update -y -qq
apt-get install -y wireguard

# ── Step 2: Create config directory ───────────
echo "[2/6] Creating /etc/wireguard directory..."
mkdir -p /etc/wireguard

# ── Step 3: Generate server public key and private key ──────────
echo "[3/6] Generating server key pair..."
wg genkey > /etc/wireguard/server_private.key
wg pubkey < /etc/wireguard/server_private.key > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key /etc/wireguard/server_public.key # lock both keys to owner

SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)

# ── Step 4: Write wg0.conf ────────────────────
echo "[4/6] Creating wg0.conf..."
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -1) # required to check the network interface, different EC2 instance types may have different interfaces (e.g., eth0, ens5, etc.)
if [ -z "$DEFAULT_IFACE" ]; then
  echo "Error: Could not detect default network interface."
  exit 1
fi
echo "  Detected network interface: ${DEFAULT_IFACE}"

# Below is the content of wg0.conf - wireguard server config
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

chmod 600 /etc/wireguard/wg0.conf # enforce 600, why not
unset SERVER_PRIVATE_KEY # remove it from memory, cause why not

# ── Step 5: Enable IP forwarding ──────────────
echo "[5/6] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1 # turn on routing between interfaces immediately, receives on wg0 and forwards to default interface, and vice versa
grep -qxF 'net.ipv4.ip_forward = 1' /etc/sysctl.conf \
  || echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf # make it persist.

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
echo "============================================"