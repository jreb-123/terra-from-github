#cloud-config
ssh_authorized_keys:
  - ${ssh_public_key}

package_update: true
package_upgrade: true

packages:
  - curl
  - wget
  - ufw

runcmd:
  # Configurar firewall básico
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw allow 30080/tcp
  # K3s inter-node communication (flannel VXLAN + pod/service networks)
  - ufw allow 8472/udp
  - ufw allow from 10.42.0.0/16
  - ufw allow from 10.43.0.0/16
  - ufw --force enable
  - echo "Worker node ${node_index} initialized" > /var/log/cloud-init-done.log
