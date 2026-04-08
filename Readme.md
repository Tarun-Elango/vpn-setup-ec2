# VPN Setup on AWS EC2 in 4 Steps

I decided to watch 'Akira' its been in my watchlist for a while, i found out its available on Mubi, but Mubi mexico and Mubi Brazil. I dont live in either of those countries. The obvious solution was to subscribe to a VPN. But then I thought, why not show off my computer skills and set up my own VPN server on AWS EC2?. And create a blog post about it. So here we are, enjoy! 

Edit: i really enjoyed the movie, highly recommend it.

## What is a VPN?

When you browse the internet normally, your traffic travels directly from your device to whatever website or service you're visiting — and along the way, your Internet Service Provider, network administrators, or anyone monitoring the network can see what you're doing and where you're connecting from.
A VPN (Virtual Private Network) creates an encrypted tunnel between your device and a server. All your internet traffic gets routed through that server first, so to the outside world it looks like the traffic is coming from the server, not from you.

## What this guide is about

In this guide we're building our own personal VPN from scratch using:

AWS EC2 — a cloud server that you own and control. ( choose your preferred region )
WireGuard — a open source VPN protocol. (https://www.wireguard.com)

Disclaimer: There are quite a few commands in this guide, i do my best to explain them, so use them with caution, and understand what they do before running them.


## Requirements

- A **client device** (laptop, desktop, iPad, iPhone, etc.) with WireGuard installed — this guide assumes you're using the WireGuard GUI app.
- A **personal computer** with an AWS account — this will be used to launch and configure an EC2 instance as your WireGuard VPN server.

> **Note:** Your personal computer and client device can be the same machine.

---

## Step 1: Generate Client Keys _(Manual)_

On the client, create private and public key pair, if you have the GUI you can use WireGuard's built-in tools (generate keypair in the UI). Share the public key with the server out of band (email, text, etc).
The private key should be kept secret and not shared with anyone.


### ⚠️ Keep Track Of (for Step 3):
<u>*Keep the public key of the client handy.*</u>

---

## Step 2: Set Up AWS EC2 _(Manual)_

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

### ⚠️ Keep Track Of (for Step 3):
<u> **EC2 Public IP** (from AWS console)</u> <br>
<u> **Your `.pem` filename**</u> <br>
<u> **SSH command** (from instance → connect → SSH client)</u>

---

## Step 3: Configure VPN Server _(Automation)_

### Setup
1. cd into scripts directory in your local machine.
1. Place your `.pem` file in the same directory as `setup-vpn-server.sh`
2. Open a terminal in that directory
3. Now, you'll need your **client public key** from Step 1

### Run the Setup Commands
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

    # inside EC2, run the setup script with your client public key
    sudo ./setup-vpn-server.sh <client_public_key>
```

### What the Script Does
- Installs WireGuard
- Creates `/etc/wireguard` directory
- Generates server key pair
- Creates `wg0.conf` configuration
- Enables IP forwarding
- Starts WireGuard service

### ⚠️ Keep Track Of (for Step 4):
- **Server public key** (printed at the end of the script)

---

## Step 4: Configure Client _(Manual)_

Fill in the client configuration in your WireGuard client app with the following details:

**Interface Settings:**
- Addresses: `10.0.0.2/24`
- DNS: `1.1.1.1`

**Add Peer:**
- Public key: server public key from Step 3
- Endpoint: `<EC2-Public-IP>:51820`
- Allowed IPs: `0.0.0.0/0`
- Persistent keepalive: `25`

Save and activate the VPN connection in your WireGuard client. You should now be connected to your personal VPN server on AWS EC2!

---

### Things to note - security wise:
- the .pem file should be kept secure and not shared, as it provides SSH access to your EC2 instance
- this process involves exchanging the public keys of both client and server, but that's not a security risk as the public key is meant to be shared, regardless keep them secure.
- On the AWS instance, security groups should be configured to only allow access from your IP ( one inbound for tcp, port 22 for ssh, and one inbound for udp, port 51820 for wireguard) to minimize exposure to the internet.