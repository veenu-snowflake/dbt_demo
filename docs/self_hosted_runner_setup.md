# Self-Hosted GitHub Runner Setup Guide

This guide helps you set up a self-hosted GitHub Actions runner with a **fixed IP address** that can be whitelisted in Snowflake's network policy.

---

## Why Self-Hosted Runner?

| GitHub-Hosted | Self-Hosted |
|---------------|-------------|
| Dynamic IPs (5000+ ranges) | **Fixed IP** (your machine) |
| IPs change every run | Same IP always |
| Can't whitelist in Snowflake | ✅ Easy to whitelist |

---

## Option 1: Run on Your Local Machine (Quick Test)

### Step 1: Get Runner Setup Script

1. Go to: https://github.com/veenu-snowflake/dbt_demo/settings/actions/runners
2. Click **"New self-hosted runner"**
3. Select your OS (macOS/Linux/Windows)
4. Follow the commands shown

### Step 2: Example for macOS

```bash
# Create a folder
mkdir actions-runner && cd actions-runner

# Download the runner
curl -o actions-runner-osx-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-osx-x64-2.311.0.tar.gz

# Extract
tar xzf ./actions-runner-osx-x64-2.311.0.tar.gz

# Configure (use token from GitHub UI)
./config.sh --url https://github.com/veenu-snowflake/dbt_demo --token YOUR_TOKEN

# Run the runner
./run.sh
```

### Step 3: Add Your IP to Snowflake

Find your public IP:
```bash
curl ifconfig.me
```

Add to Snowflake network policy:
```sql
USE ROLE ACCOUNTADMIN;

-- Get current allowed IPs
DESCRIBE NETWORK POLICY ACCOUNT_VPN_POLICY_SE;

-- Add your IP (replace YOUR_IP)
ALTER NETWORK POLICY ACCOUNT_VPN_POLICY_SE 
ADD ALLOWED_IP_LIST = ('YOUR_PUBLIC_IP');
```

---

## Option 2: Run on a Cloud VM (Recommended for Production)

### AWS EC2 Example

```bash
# 1. Launch an EC2 instance (t3.small is sufficient)
# 2. Assign an Elastic IP (this gives you a FIXED IP)
# 3. SSH into the instance

# Install dependencies
sudo apt update && sudo apt install -y curl jq

# Create runner directory
mkdir actions-runner && cd actions-runner

# Download runner (check latest version)
curl -o actions-runner-linux-x64-2.311.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz

tar xzf ./actions-runner-linux-x64-2.311.0.tar.gz

# Configure
./config.sh --url https://github.com/veenu-snowflake/dbt_demo --token YOUR_TOKEN

# Install as service (runs on boot)
sudo ./svc.sh install
sudo ./svc.sh start
```

### Add Elastic IP to Snowflake

```sql
USE ROLE ACCOUNTADMIN;
ALTER NETWORK POLICY ACCOUNT_VPN_POLICY_SE 
ADD ALLOWED_IP_LIST = ('YOUR_ELASTIC_IP');
```

---

## Option 3: Use Docker (Clean Environment)

```dockerfile
# Dockerfile for self-hosted runner
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Snowflake CLI
RUN pip3 install snowflake-cli

# Create runner user
RUN useradd -m runner
USER runner
WORKDIR /home/runner

# Download runner
ARG RUNNER_VERSION=2.311.0
RUN curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf actions-runner.tar.gz \
    && rm actions-runner.tar.gz

# Entry point
ENTRYPOINT ["./config.sh"]
```

Run with:
```bash
docker build -t gh-runner .
docker run -it gh-runner --url https://github.com/veenu-snowflake/dbt_demo --token YOUR_TOKEN
```

---

## Verify Runner is Connected

1. Go to: https://github.com/veenu-snowflake/dbt_demo/settings/actions/runners
2. You should see your runner listed as **"Idle"**

```
┌─────────────────────────────────────────────────────────────────┐
│  Self-hosted runners                                             │
├─────────────────────────────────────────────────────────────────┤
│  🟢 my-runner    Idle    macOS    x64                           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pipeline Flow with Self-Hosted Runner

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     CI/CD with Self-Hosted Runner                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   GitHub Push                                                                │
│        │                                                                     │
│        ▼                                                                     │
│   ┌─────────────────┐                                                        │
│   │  Lint (SQLFluff)│  ← Runs on GitHub-hosted (no Snowflake access needed) │
│   │  ubuntu-latest  │                                                        │
│   └────────┬────────┘                                                        │
│            │                                                                 │
│            ▼                                                                 │
│   ┌─────────────────┐                                                        │
│   │  Deploy & Test  │  ← Runs on YOUR self-hosted runner                    │
│   │  self-hosted    │    (Fixed IP whitelisted in Snowflake)                │
│   └────────┬────────┘                                                        │
│            │                                                                 │
│            ▼                                                                 │
│   ┌─────────────────┐                                                        │
│   │  Deploy Prod    │  ← Runs on YOUR self-hosted runner                    │
│   │  self-hosted    │    (With manual approval)                             │
│   └─────────────────┘                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Runner not picking up jobs?

Check runner status:
```bash
./svc.sh status
```

Check logs:
```bash
cat _diag/Runner_*.log
```

### Permission denied?

Ensure runner user has access:
```bash
chmod -R 755 actions-runner/
```

### Snowflake still blocking?

Verify your IP is whitelisted:
```sql
DESCRIBE NETWORK POLICY ACCOUNT_VPN_POLICY_SE;
```

Check your current public IP:
```bash
curl ifconfig.me
```
