---
title: Quick'n'Dirty - VMWare Tanzu - Cluster Certificate Renewal
date: 2023-09-10 00:00 
comments: false 
tags:
- vmware
- vmware tanzu
- tanzu supervisor
- tanzu cluster
- certificate renew
- certificate
---

Hi all,
some projects and clusters may enter a maintenance mode in their lifetime and dont receive any updates, changes or even patches for a long time. If something like this happens it may be neccessary to rotate the certificates used by control planes. The control planes of vmware tanzu provide this functionality via kubeadm.
The following script automates this rotation.

```bash
#!/bin/bash
# CONFIGURATION AREA
# PLEASE CONFIGURE THE SUPERVISOR NAMESPACE
export SUPERVISOR="tanzu-supervisor-one"

# PLEASE NO CHANGES BEYOND THIS POINT
kubectl config use-context $SUPERVISOR
# get available tkcs
tkcs=$(kubectl get tkc --no-headers -o custom-columns=":metadata.name") 
# iterate over each tkc and rotate certs on control planes
while IFS= read -r tkc; do 
echo "next tkc: $tkc"
SSHPASS=$(kubectl get secret $tkc-ssh-password -o jsonpath='{.data.ssh-passwordkey}' | base64 -d)
echo "aquired sshpass - getting control-plane ips now"
IPS=$(kubectl get vm -owide | grep ^$tkc-control-plane | awk '{print $5}')
	echo "aquired ips - running commands now"
	while IFS= read -r CPIP; do
		echo "rotate certs on node with ip: $CPIP"
		sshpass -p $SSHPASS ssh -o "StrictHostKeyChecking=no" -q vmware-system-user@$CPIP sudo kubeadm certs check-expiration < /dev/null
		sshpass -p $SSHPASS ssh -o "StrictHostKeyChecking=no" -q vmware-system-user@$CPIP sudo kubeadm certs renew all < /dev/null
		sshpass -p $SSHPASS ssh -o "StrictHostKeyChecking=no" -q vmware-system-user@$CPIP sudo reboot now < /dev/null
		echo "done with node ip: $CPIP"
	done <<< "$IPS"
done <<< "$tkcs"
```

This script helped us to rotate multiple clusters at once. May it help you too.