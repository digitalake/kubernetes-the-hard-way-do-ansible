resource "digitalocean_vpc" "primary" {
  name     = var.k8s_vpc_name
  region   = var.k8s_vpc_region
  ip_range = var.k8s_vpc_cidr
}
