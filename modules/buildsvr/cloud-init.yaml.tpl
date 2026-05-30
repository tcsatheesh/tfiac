#cloud-config
# Build server bootstrap.
# - Installs Azure CLI from packages.microsoft.com
# - Installs the GitHub Actions self-hosted runner v${github_runner_version}
# - Registers the runner only when a non-empty token is supplied
package_update: true
package_upgrade: false

packages:
  - curl
  - jq
  - unzip
  - ca-certificates
  - apt-transport-https
  - lsb-release
  - gnupg

write_files:
  - path: /opt/buildsvr/bootstrap.sh
    permissions: "0755"
    owner: root:root
    content: |
      #!/usr/bin/env bash
      set -euo pipefail

      LOG=/var/log/buildsvr-bootstrap.log
      exec > >(tee -a "$LOG") 2>&1
      echo "[$(date -Iseconds)] buildsvr bootstrap starting"

      # ----- Azure CLI -----
      if ! command -v az >/dev/null 2>&1; then
        curl -sL https://aka.ms/InstallAzureCLIDeb | bash
      fi
      az --version || true

      # ----- Mount data disk at /mnt/runner if present (lun 0) -----
      DEV=$(readlink -f /dev/disk/azure/scsi1/lun0 2>/dev/null || true)
      if [ -n "$${DEV:-}" ] && [ -b "$DEV" ]; then
        if ! blkid "$DEV" >/dev/null 2>&1; then
          mkfs.ext4 -F "$DEV"
        fi
        mkdir -p /mnt/runner
        if ! grep -q "/mnt/runner" /etc/fstab; then
          UUID=$(blkid -s UUID -o value "$DEV")
          echo "UUID=$UUID /mnt/runner ext4 defaults,nofail 0 2" >> /etc/fstab
        fi
        mount -a
        chown ${admin_username}:${admin_username} /mnt/runner
      fi

      # ----- GitHub Actions runner -----
      RUNNER_HOME=/mnt/runner/actions-runner
      if [ ! -d /mnt/runner ]; then
        RUNNER_HOME=/home/${admin_username}/actions-runner
      fi
      mkdir -p "$RUNNER_HOME"
      cd "$RUNNER_HOME"
      if [ ! -f ./config.sh ]; then
        ARCH=x64
        curl -fsSL -o actions-runner.tar.gz \
          "https://github.com/actions/runner/releases/download/v${github_runner_version}/actions-runner-linux-$${ARCH}-${github_runner_version}.tar.gz"
        tar xzf actions-runner.tar.gz
        rm -f actions-runner.tar.gz
      fi
      chown -R ${admin_username}:${admin_username} "$RUNNER_HOME"

      TOKEN='${github_runner_token}'
      if [ -n "$TOKEN" ]; then
        sudo -u ${admin_username} ./config.sh \
          --url "${github_runner_url}" \
          --token "$TOKEN" \
          --name "${runner_name}" \
          --labels "${runner_labels}" \
          --unattended --replace --disableupdate || true
        ./svc.sh install ${admin_username} || true
        ./svc.sh start || true
      else
        echo "[$(date -Iseconds)] GITHUB runner token empty; skipping registration. Run ./config.sh manually."
      fi

      echo "[$(date -Iseconds)] buildsvr bootstrap finished"

runcmd:
  - [/opt/buildsvr/bootstrap.sh]
