---
layout: post
title: Kubernetes - Kustomize up your Helm chart
date: 2023-01-30 00:00 
categories: 
- Kubernetes
tags:
- kustomize
- kubernetes
- helm chart
- helm
- k8s
---

Hi all, 
it's been some time since I wrote my last article here. I switched jobs, started reading a lot more, worked on different projects so that blogging came way to short. 
With the new year I want to try to write at least a monthly entry with one new thing I learned and want to share. 
The following post describes the helm chart capabilities of kustomize and how to use it in your workflow.

This article is not focused on the topic if templates are a good thing or how to template with kustomize. Feel free to leave a comment over in mastodon: @deb4sh@hachyderm.io

# Motivation

From time to time it is nessecary to edit and helm-chart further than the estimated approach of the original author of one helmchart. 
A common usecase is editing the service afterwards to fit your needs. I often need to patch those after a deployment to append loadbalancer configuration or the ip that should be used. This is often a two step approach by installing the helm chart first and apply the manifest with patches afterwards. 
An another example could be the overlaying of values for different environments. 

With the [helmChart](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/chart.md) and the Helm Chart Inflation Generator you can unpack the helm chart withing kustomize and handle the resulting manifests directly.

# How to do

For demonstation purposes I've set up a kustomized helm installation for victoria metrics under the following [link](https://github.com/deB4SH/Kustomize-Victoria-Metrics).

Everything starts with a *HelmChartInflationGenerator* which is found under `/base/*/helmrelease.yaml`.

```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: victoria-metrics-cluster
releaseName: victoria-metrics-cluster
name: victoria-metrics-cluster
version: 0.9.52
repo: https://victoriametrics.github.io/helm-charts/
valuesInline: {}
IncludeCRDs: true
namespace: victoria-metrics
```

The generation describes the location of the victoria metrics helm chart and every relevant metadata with it like the name, version, values and namespace.
The next step is to set up an aggregator for all your Helm Charts and patch all values for installation. 
This is done within the `/env/*/kustomization.yaml`.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: victoria-metrics

resources:
  - ../../base/victoria-metrics-cluster
  - ../../base/victoria-metrics-agent
  - ../../base/grafana

patchesStrategicMerge:
  - patches/patch-cluster-values.yaml
  - patches/patch-agent-values.yaml
  - patches/patch-grafana-values.yaml
```

The kustomization collects all configured bases and patches their values accordingly. 
Inside the following listing is the patch described for the victoria metrics cluster.

```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: victoria-metrics-cluster
valuesInline: 
  rbac:
    create: true
    pspEnabled: false
  vmselect:
    replicaCount: 1
    podAnnotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8481"

  vminsert:
    replicaCount: 1
    podAnnotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8480"
    extraArgs:
      envflag.enable: "true"
      envflag.prefix: VM_
      loggerFormat: json

  vmstorage:
    replicaCount: 1
    persistentVolume:
      storageClass: longhorn
    podAnnotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8482"
```

Inline values provide an overlay for the default values that are available withing the helm chart. 
This patching mechanism can be used to overlay the values even further if installations share the same base. 

As last step we need to instruct kustomize to generate the ressources from the configured helmchart and values.
This could be done with the following listing.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: victoria-metrics

generators:
  - ../../env/homelab/
```

The generator points towards the previously described environment configuration. 
When run with `kustomize build --enable-helm` you should receive the rendered helm chart as kubernetes manifests.

# Conclusion

With the `helmchart` and `HelmChartInflationGenerator` we are able to render helmcharts nativly in kustomize. 
Due to the general patching mechanism with kustomize we can manipulate the resulting manifests with ease before everything gets deployed towards the cluster.

The generator needs some work... for example is the `--enable-helm` command line dependency something that a lot of people are going to script away. 
There are also some heafty changes located within the milestone [v5.0.0](https://github.com/kubernetes-sigs/kustomize/milestone/9) for kustomize.

IMHO: It's a nice progress for kustomize to allow helm charts directly within my workflow. I can remove one application from build-stack to rollout services to my clusters.