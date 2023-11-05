resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/tftemplates/inventory.tftpl",
    {
      workers = [for droplet in digitalocean_droplet.worker : {
        name                 = droplet.name
        ipv4_address         = droplet.ipv4_address
        private_ipv4_address = droplet.ipv4_address_private
        user                 = var.k8s_ssh_additional_user
      }]
      masters = [for droplet in digitalocean_droplet.master : {
        name                 = droplet.name
        ipv4_address         = droplet.ipv4_address
        private_ipv4_address = droplet.ipv4_address_private
        user                 = var.k8s_ssh_additional_user
      }]
      lb_name                 = digitalocean_droplet.load-balancer.name
      lb_ipv4_address         = digitalocean_droplet.load-balancer.ipv4_address
      lb_private_ipv4_address = digitalocean_droplet.load-balancer.ipv4_address_private
      lb_user                 = var.k8s_ssh_additional_user
      lb_static_ipv4_address  = digitalocean_reserved_ip.load-balancer.ip_address
    }
  )
  filename = "${path.module}/ansible/inventory"
}

resource "local_file" "user_data" {
  content = templatefile("${path.module}/user_data/create_user.sh.tftpl",
    {
      user    = var.k8s_ssh_additional_user
      pub_key = digitalocean_ssh_key.default.public_key
    }
  )
  filename = "${path.module}/user_data/create_user.sh"
}
