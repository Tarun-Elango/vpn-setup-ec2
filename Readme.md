# Setup your private VPN on AWS EC2

I decided to watch 'Akira' its been in my watchlist for a while, i found out its available on Mubi, but Mubi mexico and Mubi Brazil. I dont live in either of those countries. The obvious solution was to subscribe to a VPN. But then I thought, this is a perfect excuse to spin up a VPN server on AWS EC2. So here we are, enjoy! 

Edit: i really enjoyed the movie, highly recommend it.

## What is a VPN?

When you browse the internet normally, your traffic travels directly from your device to whatever website or service you're visiting — and along the way, your Internet Service Provider, network administrators, or anyone monitoring the network can see what you're doing and where you're connecting from.
A VPN (Virtual Private Network) creates an encrypted tunnel between your device and a server. All your internet traffic gets routed through that server first, so to the outside world it looks like the traffic is coming from the server, not from you.

## What this guide is about

In this guide we're building our own personal VPN from scratch using:

- **AWS EC2** — a cloud server that you own and control (choose your preferred region)
- **WireGuard** — an open source VPN protocol (https://www.wireguard.com)

> **Disclaimer:** There are quite a few commands in this guide. I do my best to explain them, so use them with caution and understand what they do before running them.


## Requirements

- A **client device** (laptop, desktop, iPad, iPhone, etc.) with WireGuard installed — this guide assumes you're using the WireGuard GUI app.
- A **personal computer** with an AWS account — this will be used to launch and configure an EC2 instance as your WireGuard VPN server.

> **Note:** Your personal computer and client device can be the same machine.

---

## Step 1: Generate Client Keys

Download the WireGuard client: https://www.wireguard.com/install/  ( desktop, ipad, iphone, etc. )

On the client, create a private and public key pair. If you have the GUI, you can use WireGuard's built-in tools (generate keypair in the UI). Share the public key with the server out of band (email, text, etc). The private key should be kept secret and not shared with anyone.
We will fill the rest of the client configuration in Step 4.

> **Keep Track Of (for Step 3):** Keep the public key of the client handy.

---

## Step 2: Set Up AWS EC2

### Create EC2 Instance
- Instance type: Choose smallest available (e.g. `t2.nano`)
- OS: Ubuntu Linux

### Create Key Pair for SSH Access
- Download the `.pem` file.

### Configure Security Group
In the AWS console, edit inbound rules to add:
1. **SSH**: Port 22/TCP from your IP
2. **WireGuard**: Port 51820/UDP from your IP

Then launch the instance.

> **Keep Track Of (for Step 3):**
> - **EC2 Public IP** (from AWS console)
> - **Your `.pem` filename**
> - **SSH command** (from instance → connect → SSH client)

---

## Step 3: Configure VPN Server

### Setup
1. On your local machine, create a folder and either clone `https://github.com/Tarun-Elango/vpn-setup-ec2` or copy `setup-vpn-server.sh`, from the repository, into it
2. Place your `.pem`, which you downloaded from AWS, file in the same directory as `setup-vpn-server.sh`

### Run the Setup Commands in your Terminal
```bash
# Secure the .pem file
chmod 400 <your-key.pem>

# Copy script from local machine to EC2
scp -i <your-key.pem> setup-vpn-server.sh ubuntu@<EC2-Public-DNS>:/home/ubuntu/

# SSH into EC2
ssh -i <your-key.pem> ubuntu@<EC2-Public-DNS>

    # inside EC2, verify script was copied
    ls -l setup-vpn-server.sh

    # inside EC2, make script executable
    chmod +x setup-vpn-server.sh

    # inside EC2, run the setup script with your client public key, the key from step 1
    sudo ./setup-vpn-server.sh <client_public_key>
    # if you dont want to run the script, you can also run the commands in the script one by one
```

### What the Script Does
- Installs WireGuard
- Creates `/etc/wireguard` directory
- Generates server key pair
- Creates `wg0.conf` configuration
- Enables IP forwarding
- Starts WireGuard service

> **Keep Track Of (for Step 4):** **Server public key** (printed at the end of the script)

---

## Step 4: Configure Client

Fill in the client configuration, continuing from Step 1, in your WireGuard client app with the following details:

**Interface Settings:**
- Addresses: `10.0.0.2/24` — the client's VPN IP address assigned when connecting
- DNS: `1.1.1.1`

**Peer Settings:**
- Public key: server public key from Step 3
- Endpoint: `<EC2-Public-IP>:51820`
- Allowed IPs: `0.0.0.0/0` — routes all traffic through the VPN
- Persistent keepalive: `25`

Save and activate the VPN connection in your WireGuard client. You should now be connected to your personal VPN server on AWS EC2!

---

## Security Notes

- The `.pem` file should be kept secure and not shared, as it provides SSH access to your EC2 instance.
- This process involves exchanging the public keys of both client and server — this is not a security risk, but keep them secure regardless.
- Security groups should be configured to only allow access from your IP (port 22/TCP for SSH, port 51820/UDP for WireGuard) to minimize exposure to the internet.