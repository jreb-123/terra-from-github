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
  - docker.io
  - docker-compose

runcmd:
  # Configurar firewall para K3D
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable
  # Habilitar Docker
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  - echo "K3D host ${node_index} initialized" > /var/log/cloud-init-done.log
