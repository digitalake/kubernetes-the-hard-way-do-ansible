resource "digitalocean_droplet" "master" {
  for_each  = var.k8s_masters
  name      = each.key
  image     = each.value.image
  region    = var.k8s_vpc_region
  size      = each.value.size
  ssh_keys  = each.value.provide_root_ssh_connection ? [digitalocean_ssh_key.default.fingerprint] : []
  user_data = local_file.user_data.content
  vpc_uuid  = digitalocean_vpc.primary.id
  tags      = ["terraform", "master"]
}

resource "digitalocean_droplet" "worker" {
  for_each  = var.k8s_workers
  name      = each.key
  image     = each.value.image
  region    = var.k8s_vpc_region
  size      = each.value.size
  ssh_keys  = each.value.provide_root_ssh_connection ? [digitalocean_ssh_key.default.fingerprint] : []
  user_data = local_file.user_data.content
  vpc_uuid  = digitalocean_vpc.primary.id
  tags      = ["terraform", "worker"]
}

resource "digitalocean_droplet" "load-balancer" {
  name      = var.k8s_api_lb_name
  image     = var.k8s_api_lb_image
  region    = var.k8s_vpc_region
  size      = var.k8s_api_lb_size
  ssh_keys  = [digitalocean_ssh_key.default.fingerprint]
  user_data = local_file.user_data.content
  vpc_uuid  = digitalocean_vpc.primary.id
  tags      = ["terraform", "lb"]
}

resource "digitalocean_reserved_ip" "load-balancer" {
  region = var.k8s_vpc_region
}

resource "digitalocean_reserved_ip_assignment" "load-balancer" {
  ip_address = digitalocean_reserved_ip.load-balancer.ip_address
  droplet_id = digitalocean_droplet.load-balancer.id
}

resource "digitalocean_ssh_key" "default" {
  name       = var.k8s_ssh_key_resource_name
  public_key = file(var.k8s_ssh_key_file_path)
}
