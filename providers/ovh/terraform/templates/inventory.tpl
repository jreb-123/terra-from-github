all:
  children:
    k3s_cluster:
      children:
        k3s_masters:
          hosts:
%{ for name, ip in master_ips ~}
            ${name}:
              ansible_host: ${ip}
              ansible_user: ubuntu
              ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
              node_role: master
%{ endfor ~}
        k3s_workers:
          hosts:
%{ for name, ip in worker_ips ~}
            ${name}:
              ansible_host: ${ip}
              ansible_user: ubuntu
              ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
              node_role: worker
%{ endfor ~}
      vars:
        k3s_version: v1.28.5+k3s1
        ansible_python_interpreter: /usr/bin/python3
