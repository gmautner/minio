# Self-Hosted GitHub Actions Runner Setup

This document describes how to set up a self-hosted runner for the mint test workflow.

## Prerequisites

- A Linux VM (Ubuntu 24.04 recommended)
- At least 4 CPU cores, 8 GB RAM, 100 GB disk
- Root access

## Step 1: Install Dependencies

```bash
sudo apt update
sudo apt install -y build-essential git curl
```

## Step 2: Install Docker

Reference: <https://docs.docker.com/engine/install/ubuntu/>

```bash
# Add Docker's official GPG key
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# Install Docker packages
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Step 3: Create Runner User

The GitHub Actions runner cannot run as root. Create a dedicated user:

```bash
adduser --disabled-password --gecos "" runner
usermod -aG docker runner

# Grant passwordless sudo (required for workflow cleanup steps)
echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner
chmod 440 /etc/sudoers.d/runner
```

## Step 4: Install GitHub Actions Runner

Switch to the runner user and download the runner:

```bash
su - runner
mkdir actions-runner && cd actions-runner

# Download the latest runner (check https://github.com/actions/runner/releases for current version)
curl -o actions-runner-linux-x64-2.330.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.330.0/actions-runner-linux-x64-2.330.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.330.0.tar.gz
```

## Step 5: Configure the Runner

Get a registration token from GitHub:

1. Go to <https://github.com/gmautner/minio/settings/actions/runners>
2. Click "New self-hosted runner"
3. Copy the token from the configure step

Run the configuration:

```bash
./config.sh --url https://github.com/gmautner/minio --token YOUR_TOKEN_HERE
```

Accept the defaults or customize:

- **Runner group**: Default
- **Runner name**: Use hostname or custom name (e.g., `minio-mint-runner`)
- **Labels**: Add `mint` if you want to use `runs-on: mint` in workflows
- **Work folder**: `_work`

## Step 6: Install as a Service

Exit back to root and install the systemd service:

```bash
exit  # Back to root
cd /home/runner/actions-runner
./svc.sh install runner
./svc.sh start
```

Verify the service is running:

```bash
./svc.sh status
```

## Service Management

```bash
# Check status
./svc.sh status

# Stop the runner
./svc.sh stop

# Start the runner
./svc.sh start

# Uninstall the service
./svc.sh uninstall
```

## Updating the Workflow

To use the self-hosted runner, update `.github/workflows/mint.yml`:

```yaml
jobs:
  mint-test:
    runs-on: self-hosted  # or use a custom label like 'mint'
```

## Maintenance

Periodically clean up Docker resources to free disk space:

```bash
docker system prune -af --volumes
```

View runner logs:

```bash
journalctl -u actions.runner.gmautner-minio.minio-mint-runner.service -f
```

## Security Notes

- Self-hosted runners on public repositories can execute arbitrary code from PRs
- For public repos, consider using branch protection rules or limiting runner access
- Keep the runner and Docker updated regularly
