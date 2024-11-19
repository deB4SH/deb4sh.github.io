---
layout: post
title: Automating Kubernetes on Proxmox
date: 2024-07-19 00:00 
categories: 
- Infrastructure as Code
tags:
- terraform
- opentofu
- terraform module
- tf
- proxmox
- kubernetes
image:
  path: /assets/2024-07-19-terraform-proxmox-kubernetes-module/header.png
---
Hi all,
As someone who's spent countless hours setting up and managing infrastructure, I know how tedious and error-prone it can be to create a kubernetes clusters on different environments or service providers. But what if I told you there's a way to make this process a whole lot easier? Enter Terraform - a powerful tool for automating infrastructure deployment - which many of you readers may already be aware of. So let's skip the broad introduction and get right into the details.

First the module is available on Github under the following domain: https://github.com/deB4SH/terraform-proxmox-cloud-init-kubernetes

### What does this module do?
This Terraform module takes care of creating a Kubernetes cluster on proxmox using cloud-init and kubeadm. 

With it, you'll be able to:
* Automate the creation of a Kubernetes cluster with just a few variables
* Customize the scale of your cluster

> **Important Sidenote**: currently the module is not able to scale up multiple control planes - I'm planning to implement it down the road.

### How does everything work?
The module is pretty much ready to run on your infrastructure you simply need to configure some values.
Within the `variables.tf` you can easily review all available configuration: https://github.com/deB4SH/terraform-proxmox-cloud-init-kubernetes/blob/main/variables.tf
For example a value you need to overlay is the `user_password` and `user_pub_key` to automatically add your credentials to each vm. 

A typical configuration based on this module may look like the following listing:

```
module "kubernetes" {
  providers = {
    proxmox = proxmox.YOUR_NODE_NAME
  }
  source = "github.com/deB4SH/terraform-proxmox-cloud-init-kubernetes?ref=0.1"

  user = var.user
  user_password = var.user_password
  user_pub_key = var.user_pub_key
  node_name = var.YOUR_NODE_NAME.node_name

  vm_dns = {
    domain = "."
    servers = ["10.10.10.2"]
  }
  
  vm_ip_config = {
    address = "10.10.10.10/24"
    gateway = "10.10.10.1"
  }

  vm_datastore_id = "local-lvm"

  workers = [
    {
      node = "YOUR_NODE_NAME"
      name = "worker01"
      vm_cpu_cores = 6
      vm_memory = 12288
      ip = "10.10.10.11/24"
      id_offset = 1
      image_type = "amd64"
    }
  ]

  vm_images = [ 
  {
    name = "amd64"
    filename = "kubernetes-debian-12-generic-amd64-20240507-1740.img"
    url = "https://cloud.debian.org/images/cloud/bookworm/20240507-1740/debian-12-generic-amd64-20240507-1740.qcow2"
    checksum = "f7ac3fb9d45cdee99b25ce41c3a0322c0555d4f82d967b57b3167fce878bde09590515052c5193a1c6d69978c9fe1683338b4d93e070b5b3d04e99be00018f25"
    checksum_algorithm = "sha512"
    datastore_id = "nas"
  },
  {
    name = "arm64"
    filename = "kubernetes-debian-12-generic-arm64-20240507-1740.img"
    url = "https://cloud.debian.org/images/cloud/bookworm/20240507-1740/debian-12-generic-arm64-20240507-1740.qcow2"
    checksum = "626a4793a747b334cf3bc1acc10a5b682ad5db41fabb491c9c7062001e5691c215b2696e02ba6dd7570652d99c71c16b5f13b694531fb1211101d64925a453b8"
    checksum_algorithm = "sha512"
    datastore_id = "nas"
  }
  ]
  
}

```

To break things down. The provider block configures the proxmox endpoint you using to do the api calls to. For a overview how to use this provider please review the official documentation here: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
The source block configures the module to use. In this case we are referencing version 0.1 of the module. Don't be confused by this version - it's just a development number for now.

The following blocks are delegated blocks towards each vm and configure their respective parts. For example the dns block configures the available dns the vm should use.
`vm_ip_config` describes currently the ip address of the control plane. This will change in future when this module allows multiple control planes. 

The list around the configuration value for `workers` describe the amount of vms you want to create as worker nodes for your cluster. 

Last but not least: You are able to configure multiple vm images for amd64 and or arm. It would also be possible to inject different images for workers this way.

### What are you getting after a successful deployment
Well a barebones kubernetes cluster. No networking. No fancy load balancing pods. Pretty much nothing. A blank slate to work on.
```
KUBECONFIG=config k get nodes  
NAME                      STATUS     ROLES           AGE     VERSION  
kubernetes-controlplane   NotReady   control-plane   5m21s   v1.30.2  
worker01                  NotReady   <none>          106s    v1.30.2
```

A good next step would be adding a network component to your cluster. 
I like cilium and prepared an umbrella helm-chart for this setup in my helm-charts repository. Available here: https://github.com/deB4SH/helm-charts/tree/main/charts/cilium
After a successful apply your nodes should become ready for workloads.


### What's next for this module?

Good question! There are several things this module is currently missing out on. 

First thing - it would be awesome if this module also allows you to create highly available kubernetes clusters with multiple control planes
It would also be awesome if there is some configuration available to automatically join a new cluster towards existing gitops solutions like argocd or flux to automatically apply services like cilium, external-dns, external-secrets or sops any many more.
Lastly: this module may be a bit cluttered configuration-wise and doesn't follow any particular standard currently. Standardizing this would surely improve configurability and ease up the usage.

As always - I'm hoping this blog post helps others to get your toes into the big blue ocean of platform engineering on proxmox with kubeadm.


##### Sources

* [Terraform Module Proxmox Kubernetes](https://github.com/deB4SH/terraform-proxmox-cloud-init-kubernetes)
* [Helm Charts Repository](https://github.com/deB4SH/helm-charts)
* [Terraform Provider Proxmox](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
* [Cilium](https://cilium.io/)