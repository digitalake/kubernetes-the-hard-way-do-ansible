# kubernetes-the-hard-way-do-ansible
Create infrastructure on DO using Terraform and deploy K8s cluster using Ansible

### Terraform | Infrastructure creation

Terraform code in this repo is used to deploy several hosts for creating Kubernetes cluster:

- Kubernetes manager nodes (`masters`)
- Kubernetes `workers` nodes
- `Load balancer` with static IP address that will be attached to the external Load Balancer fronting the Kubernetes API Servers

All the variables for infra defined in `variables.tf` file so values can be passed using `*.tfvars` file (an example of values are in terraform.tfvars)

Terraform uses templates for generating `create_user.sh` script and `inventory` for Ansible which is used to Bootstrap Kubernetes cluster. The `inventory` file is generated dynamicly so You can use the node number of your choice (all cluster bootstrap roles are configuring cluster dynamicly based on the inventory provided).

After running `terraform apply` You are getting such output:

```
lb = "api-lb = public: xx.xx.xx.xx, private: 10.240.0.3"
masters = {
  "master-01" = "public: xx.xx.xx.xx, private: 10.240.0.6"
  "master-02" = "public: xx.xx.xx.xx, private: 10.240.0.5"
}
workers_ = {
  "worker-01" = "public: xx.xx.xx.xx, private: 10.240.0.4"
  "worker-02" = "public: xx.xx.xx.xx, private: 10.240.0.2"
}
```
The `inventory` file generated under /ansible directory looks like:
```
[masters]
master-01 ansible_host=xx.xx.xx.xx ansible_user=kubernetes ansible_host_private=10.240.0.6
master-02 ansible_host=xx.xx.xx.xx ansible_user=kubernetes ansible_host_private=10.240.0.5

[workers]
worker-01 ansible_host=xx.xx.xx.xx ansible_user=kubernetes ansible_host_private=10.240.0.4
worker-02 ansible_host=xx.xx.xx.xx ansible_user=kubernetes ansible_host_private=10.240.0.2

[api-lb]
api-lb ansible_host=xx.xx.xx.xx ansible_user=kubernetes ansible_host_private=10.240.0.3

[all:vars]
lb_api_ipv4=xx.xx.xx.xx
```
 Also you can see the `create_user.sh` script under /user_data dir for creating user on DigitalOcean droplets:
```
 #!/bin/bash
adduser --disabled-password --gecos "" kubernetes
usermod -aG sudo kubernetes
echo "kubernetes ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/kubernetes
mkdir -p /home/kubernetes/.ssh
echo "<SSH KEY HERE>" >> /home/kubernetes/.ssh/authorized_keys
chown -R kubernetes:kubernetes /home/kubernetes/.ssh
chmod 700 /home/kubernetes/.ssh
chmod 600 /home/kubernetes/.ssh/authorized_keys
```
### Ansible | Ansible roles description

Ansible roles directory looks like:

```
.
├── api-load-balancer         --> configuring Load Balancer using NginX
├── control-plane-bootstrap   --> installing binaries and configuring control planes
├── delegating                --> distributing all the configs and certificates with keys to the nodes
├── etcd-bootstrap            --> installing binaries and configuring ETCD cluster
├── generating                --> generating all the configs and certificates with keys for Kubernetes
├── tools-setup               --> setting up kubectl
└── workers-bootstrap         --> installing binaries and configuring workers
```
The roles are being executed in such order defined in `kubernets.yml` playbook:

```
- name: install CFSSL and Kubectl
  hosts: all
  roles:
  - tools-setup
  
- name: Generate Kubernetes certificates
  hosts: localhost
  roles:
  - generating

- name: Delegate Kubernetes certificates
  hosts: all
  roles:
  - delegating

- name: Bootstrap ETCD cluster on masters
  hosts: masters
  roles:
  - etcd-bootstrap

- name: Bootstrap Kube CP
  hosts: masters
  roles:
  - control-plane-bootstrap

- name: Botstrap API LB
  hosts: api-lb
  roles:
  - api-load-balancer

- name: Bootstrap worker nodes
  hosts: workers
  roles:
  - workers-bootstrap
```

### Ansible roles | tools-setup

In this role there is nothing special, so just the kubectl installation is being executed

### Ansible roles | generating

This role requires `cfssl`, `cfssljson` and `kubectl` installed on the Ansible control host because certificate generation is being made on the localhost. You can see the templates and files for the certificate requests in the `templates` nad `files` dirs.

`generating` role generates:

- CA configuration file, certificate, and private key
- client `certificate` and `private key` for:
  - `admin`
  - each `worker node` (ansible iterates through the `workers` hosts form the inventory)
  - `kube-controller-manager`
  - `kube-proxy`
  - `kube-scheduler`
  - `Kubernetes API Server`
  - `service-account`
- `kubeconfig` file for:
  - each `worker node`
  - `kube-proxy service`
  - `kube-controller-manager service`
  - `kube-scheduler service`
  - `admin user`
- `encryption-config.yaml` encryption config file

So the resulting directory contain (in my case i have `2 workers`):
```
├── admin.csr
├── admin-csr.json
├── admin-key.pem
├── admin.kubeconfig
├── admin.pem
├── ca-config.json
├── ca.csr
├── ca-csr.json
├── ca-key.pem
├── ca.pem
├── encryption-config.yaml
├── kube-controller-manager.csr
├── kube-controller-manager-csr.json
├── kube-controller-manager-key.pem
├── kube-controller-manager.kubeconfig
├── kube-controller-manager.pem
├── kube-proxy.csr
├── kube-proxy-csr.json
├── kube-proxy-key.pem
├── kube-proxy.kubeconfig
├── kube-proxy.pem
├── kubernetes.csr
├── kubernetes-csr.json
├── kubernetes-key.pem
├── kubernetes.pem
├── kube-scheduler.csr
├── kube-scheduler-csr.json
├── kube-scheduler-key.pem
├── kube-scheduler.kubeconfig
├── kube-scheduler.pem
├── service-account.csr
├── service-account-csr.json
├── service-account-key.pem
├── service-account.pem
├── worker-01.csr
├── worker-01-csr.json
├── worker-01-key.pem
├── worker-01.kubeconfig
├── worker-01.pem
├── worker-02.csr
├── worker-02-csr.json
├── worker-02-key.pem
├── worker-02.kubeconfig
└── worker-02.pem
```

### Ansible roles | delegating

This roles iterates through the `masters` host group and `workers` node group and delivers all the necessary files to the target nodes.

To `workers`:

- ca.pem
- `{{ inventory_hostname }}`-key.pem
- `{{ inventory_hostname }}`.pem
- `{{ inventory_hostname }}`.kubeconfig
- kube-proxy.kubeconfig

To `masters`:

- ca.pem
- ca-key.pem
- kubernetes-key.pem
- kubernetes.pem
- service-account-key.pem service-account.pem
- admin.kubeconfig
- kube-controller-manager.kubeconfig
- kube-scheduler.kubeconfig
- encryption-config.yaml

### Ansible roles | etcd-bootstrap

In this role the `etcd` binaries are downloaded on each `master` node. `etcd.service` unit file is created dynamically based on the `inventory` and the `etcd cluster` is being started.

To check if `etcd` is succesfuly loaded by executing the following command:

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem
```

### Ansible roles | control-plane-bootstrap

In this role the following Kubernetes binaris are installed:

- `kube-apiserver`
- `kube-controller-manager`
- `kube-scheduler`
- `kubectl`

Also `control-plane-bootstrap` role generates systemd unit files and starts services:

- `kube-apiserver.service`
- `kube-controller-manager.service`
- `kube-scheduler.service` (requires config file which is being generated too)

Part of Kelsey Hightower's original Kubernetes the Hard Way guide involves setting up an nginx proxy on each controller to provide access to the Kubernetes API /healthz endpoint over http. So `control-plane-bootstrap` role also insytalls `NginX` with the necessary configuration and starts it.

Additionally `RBAC permissions` to allow the `Kubernetes API Server` to access the `Kubelet API` on each `worker node` are cretaed via `kubernets.core` Ansible module from templates. Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

### Ansible roles | api-load-balancer

In order to achieve redundancy for your Kubernetes cluster, you will need to load balance usage of the Kubernetes API across multiple control nodes. In this role, simple nginx server creating is being made to perform this balancing. Load balancer allows to interact with both control nodes of your kubernetes cluster using the `NginX` load balancer.

In order to keep my roles dynamic, the following jinja2 template was prepared:
```
stream {
    upstream kubernetes {
        {% for host in groups['masters'] %}
        server {{ hostvars[host]['ansible_host_private'] }}:6443;
        {% endfor %}
    }

    server {
        listen 6443;
        listen 443;
        proxy_pass kubernetes;
    }
}
```

So the result in /etc/nginx/tcpconf.d/kubernetes.conf on the Load Balancer host is:
```
stream {
    upstream kubernetes {
                server 10.240.0.6:6443;
                server 10.240.0.5:6443;
            }

    server {
        listen 6443;
        listen 443;
        proxy_pass kubernetes;
    }
}
```

### Ansible roles | workers-bootstrap

The requirenments are installed:

- `socat` (enables support for the `kubectl port-forward` command)
- `conntrack`
- `ipset`

In this role the following Kubernetes binaries are installed:

- `crictl`
- `runc`
- `cni-plugins` binaries
- `containerd`
- `kubectl`
- `kube-proxy`
- `kubelet`

Also `control-plane-bootstrap` role generates systemd unit files and configurations for the components:

- `CNI` congiguration:
  - `10-bridge.conf` network configuration file
  - `99-loopback.conf` network configuration file
- `Containerd` configuration:
  - `config.toml` config
  - `containerd.service` systemd unit file
- `Kubelet` configuration:
  - `kubelet-config.yaml` configuration file
  - `kubelet.service` systemd unit file
- `Kube-proxy` configuration:
  - `kube-proxy-config.yaml` configuration file
  - `kube-proxy.service` systemd unit file
 
After configuring, Ansible role starts `containerd`, `kubelet`, `kube-proxy` services.

### Ansible | networking

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network routes.
Create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address. Pod on each worker node needs to be able to find a pod on another worker node.

In my case i used `ip route add` with Ansible to provide the necessary routes (Because DigitalOcean does not provide any extra tools for it). My `pod subnets` were defined with `worker group instance count fact`:

```
...
- name: Set worker index for maping pod CIDRS
  set_fact:
    cidr_index: "{{ groups.workers.index(inventory_hostname) | int + 1 }}"
  tags: routes
```
So my `worker-01` received `cidr_index=1`, `worker-02` received `cidr_index=2` etc. 

In my `kubelet-config.yaml` configuration file i have:

```
...
podCIDR: "10.200.{{ cidr_index }}.0/24"
...
```
So now used the same fact to iterate through workers and add rules for each worker with the `routes.sh.j2` template:
```
#!/bin/bash
{% for worker in groups['workers'] %}
{% if worker != inventory_hostname %}
ip route add 10.200.{{ hostvars[worker].cidr_index }}.0/24 via {{ hostvars[worker].ansible_host_private }}
{% endif %}
{% endfor %}
```
And a task using this template is:
```
- name: Generate route configuration script
  template:
    src: routes.sh.j2
    dest: /home/{{ ansible_user }}/routes.sh
    mode: '0755'
  vars:
    cidr_index: "{{ cidr_index }}"
  tags: routes
```

It allows to set up right routing rules dynamically based on the `inventory` no matter how many workers exist.

To deploy the `DNS` cluster addon:

```
kubectl create -f https://raw.githubusercontent.com/lpmi-13/kubernetes-the-hard-way-do/main/deployments/core-dns.yaml
```

### Results:

Check the `etcd status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/8daa8f59-8af3-473e-8db4-1a45e47e2799" width="800">


List the `etcd cluster members`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/507b0b82-6f4f-443f-a43f-19ff38df2a2e" width="1000">

Check the `kube-apiserver status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/ef5eccfb-ca57-426f-be6a-f17cb4959f12" width="800">

Check the `kube-controller-manager status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/09dcd267-3f25-4c56-a7ab-c3d943113f91" width="800">

Check the `kube-scheduler status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/897f00a0-27b6-44ee-9235-4bae5c46e318" width="800">

Ckech the `cluster status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/ad0ea4ed-f39b-4a9e-9499-8f2039aa8b6d" width="800">

Test the `nginx HTTP health check proxy`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/064bf142-8eaf-4f58-97f4-b291df012d22" width="600">

Make a HTTP request for the `Kubernetes version info` using the Load Balancer ip:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/88f48171-6922-4910-a0b0-1814f20d388c" width="700">

Check the `containerd status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/71424123-a4f4-410b-8543-6a078cf7ede8" width="800">

Check the `kubelet status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/0d9b0b09-5e5d-44be-8863-fe31fe866b4b" width="800">

Check the `kube-proxy status`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/b48971f0-6992-4f57-b99a-dbc830f2b489" width="800">

Get the `node list` via kubectl:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/d920892d-1c2f-4619-8b64-3af62070051f" width="350">

`Applying test manifest` with `namespace`, `service` and `deployment` with 2 nginx replicas:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/30ad60ac-af32-468e-a17b-8f0e35d21bdc" width="800">

Check `pods` of deployment:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/beed4f6d-05fa-470c-9a54-ceec3d885ff9" width="550">

Check the `service` of deployment:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/f3fb9b8d-ca11-476a-91cb-faecfb0d1d10" width="550">

Describe the `service`

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/aecb3d60-1d01-46e1-9efc-512ea4f9746f" width="450">

Ckech if `port forwarding` is working:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/961c7c83-8c30-4746-9ed4-28b268cae7e2" width="650">

Check `forwarded port on the localhost`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/041c538d-4828-4859-a0d9-320ef8c693aa" width="350">

Describe newly created `service with NodePort type` to check the nodeport:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/1132531e-e11b-426d-b327-f4454207b7b0" width="450">

Verify that NginX `pod is accesible with external ip`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/7082db58-cd00-4db8-95cd-26a710a3ed89" width="450">

Verify the ability to `retrieve container logs`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/b05ff5f4-ee77-4073-b7d9-1e1d80dbcd3b" width="700">

Verify the ability to `execute commands in a container`:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/ff958d0c-893d-480a-a8f2-bdf4d303903d" width="700">

Check `images list` with crictl:

<img src="https://github.com/digitalake/kubernetes-the-hard-way-do-ansible/assets/109740456/c0c7d0ba-5746-4cac-ac5a-b5e8f87047bd" width="900">























 


 



