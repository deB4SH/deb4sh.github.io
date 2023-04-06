---
title: DevOpsStories - Victoria Metrics Setup
date: 2023-03-22 00:00 
comments: false 
tags:
- kustomize
- kubernetes
- helm chart
- helm
- k8s
- argocd
- multicluster
- devops
---

Hi all, 
as some of you may know I'm interested in homelabbing and are hosting my own kubernetes cluster at home. As part of a good homelab it is essential to keep track of logs and metrics.
The number one goto application for this usecase is often the kube prometheus stack, which is in my humble opinion a bit to big for my homelab.
While looking for alternatives I stumbled upon (Victoria Metrics)[https://victoriametrics.com/] which seems to be perfect fit for my usecase.