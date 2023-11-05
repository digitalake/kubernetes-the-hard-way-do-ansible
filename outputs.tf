output "workers_" {
  value = {
    for name, droplet in digitalocean_droplet.worker : name => "public: ${droplet.ipv4_address}, private: ${droplet.ipv4_address_private}"
  }
}

output "masters" {
  value = {
    for name, droplet in digitalocean_droplet.master : name => "public: ${droplet.ipv4_address}, private: ${droplet.ipv4_address_private}"
  }
}

output "lb" {
  value = "${digitalocean_droplet.load-balancer.name} = public: ${digitalocean_droplet.load-balancer.ipv4_address}, private: ${digitalocean_droplet.load-balancer.ipv4_address_private}"
}