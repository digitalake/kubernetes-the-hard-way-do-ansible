### DigitalOcean VPC variables block

variable "k8s_vpc_name" {
  type        = string
  description = "Define a name for the VPC"
  default     = "milky-way"
}

variable "k8s_vpc_cidr" {
  type        = string
  description = "Define a VPC private ip adresses cidr block by RFC1918"
  default     = "172.16.0.0/16"
}

variable "k8s_vpc_region" {
  type        = string
  description = "Define a region to place Kubernetes resources"
  default     = "fra1"
}

### DigitalOcean Kubernetes nodes configuration variables block

variable "k8s_masters" {
  type = map(object({
    image                       = string
    size                        = string
    provide_root_ssh_connection = bool
  }))
  description = "Define Kubernetes masters VMs configurations"
}

variable "k8s_workers" {
  type = map(object({
    image                       = string
    size                        = string
    provide_root_ssh_connection = bool
  }))
  description = "Define Kubernetes workers VMs configurations"
}

variable "k8s_ssh_key_resource_name" {
  type        = string
  description = "Define a name for the public key resource"
  default     = "hubble"
}

variable "k8s_ssh_key_file_path" {
  type        = string
  description = "Define a local path to load the public ssh key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "k8s_ssh_additional_user" {
  type        = string
  description = "Define a username for adding to machines"
  default     = "kubernetes"
}

variable "k8s_api_lb_name" {
  type    = string
  default = "api-lb"
}

variable "k8s_api_lb_image" {
  type    = string
  default = "ubuntu-20-04-x64"
}

variable "k8s_api_lb_size" {
  type    = string
  default = "s-2vcpu-2gb"
}


