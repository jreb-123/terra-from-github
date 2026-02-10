output "ansible_inventory" {
  value = yamlencode({
    all = {
      children = {
        k3s_masters = {
          hosts = {
            for idx, master in openstack_compute_instance_v2.k3s_master :
            master.name => {
              ansible_host = master.access_ip_v4
              ansible_user = "ubuntu"
            }
          }
        }
      }
    }
  })
}
