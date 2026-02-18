#cloud-config
ssh_authorized_keys:
  - ${ssh_public_key}

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - git
  - ufw

runcmd:
  # Firewall for K3s + Istio
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 22/tcp
  - ufw allow 6443/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 10250/tcp
  - ufw allow 15017/tcp
  - ufw allow 15021/tcp
  - ufw --force enable
  - echo "K3s master ${node_index} initialized" > /var/log/cloud-init-done.log
