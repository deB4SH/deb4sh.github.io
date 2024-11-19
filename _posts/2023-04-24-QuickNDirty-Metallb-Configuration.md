---
layout: post
title: MetalLB Custom Resource Configuration
date: 2023-04-24 00:00 
categories: 
- Kubernetes
tags:
- kustomize
- kubernetes
- k8s
- metallb
- loadbalancer
- devops
- kustomize 
- homelab writeup
---

Hi all, 
with the version 0.13.2 of metallb comes a change in regard to layer2 ip announcements. 
Therefor it is now required to switch from the old configmap setup to a custom resource setup. 
To document my upgrade steps - here is a small write-up of things required to get metallb running again.

# Upgrade Guide

This guide assumes that you had been running an older version of metallb with a configmap for address pool configuration similar to the following listing:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.1.100-192.168.1.195
      avoid-buggy-ips: true
```
This configuration can be removed from the deployment and will be replaced with the following two custom resource manifests.

At first, it is important to create an IPAddressPool manifest which provides the address range accordingly to the previous configmap configuration.
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name:  default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.100-192.168.1.240
```
>NOTE: Keep in mind that you need top change the addresses range accordingly to your setup.

Next, it is required to set up an L2Advertisement to announce all used IP to your local network. 
This advertisement references the ipAddressPools directly within it specification and can be named something different.
To keep things in line, I named it accordingly to the IPAddressPool.

```yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
```

After checking in these manifests, metallb should pick them up and announce all used IP accordingly. 