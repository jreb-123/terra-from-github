output "ansible_inventory" {
  value = yamlencode({
    all = {
      children = {
        k3s_masters = {
          hosts = {
            for idx, host in openstack_compute_instance_v2.k3s_master :
            host.name => {
              ansible_host = host.access_ip_v4
              ansible_user = "ubuntu"
            }
          }
        }
      }
    }
  })
}
