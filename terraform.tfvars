### DigitalOcean VPC variables block

k8s_vpc_name = "the-hard-way"

k8s_vpc_cidr = "10.240.0.0/24"

k8s_vpc_region = "fra1"

### DigitalOcean Kubernetes nodes configuration variables block

k8s_masters = {
  "master-02" = {
    image                       = "ubuntu-20-04-x64"
    size                        = "s-2vcpu-2gb"
    provide_root_ssh_connection = true
  },
  "master-01" = {
    image                       = "ubuntu-20-04-x64"
    size                        = "s-2vcpu-2gb"
    provide_root_ssh_connection = true
  },
}

k8s_workers = {
  "worker-01" = {
    image                       = "ubuntu-20-04-x64"
    size                        = "s-2vcpu-2gb"
    provide_root_ssh_connection = true
  },
  "worker-02" = {
    image                       = "ubuntu-20-04-x64"
    size                        = "s-2vcpu-2gb"
    provide_root_ssh_connection = true
  },
}

k8s_ssh_key_resource_name = "ssh-pub"

k8s_ssh_key_file_path = "/home/vanadium/.ssh/spacelink.pub"

k8s_ssh_additional_user = "kubernetes"