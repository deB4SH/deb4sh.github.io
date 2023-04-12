---
title: DevOpsStories - Victoria Metrics Setup
date: 2023-04-06 00:00 
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
- kustomize 
- helmchartinflationgenerator
- kustomize helmchartinflationgenerator
---

Hi all, 
as some of you may know, I'm interested in homelabbing and are hosting my own kubernetes cluster at home. As part of a good homelab it is essential to keep track of logs and metrics.
The number one goto application for this usecase is often the kube Prometheus Stack, which is in my humble opinion a bit to big for my homelab in regard to memory, compute and storage footprint.
While looking for alternatives I stumbled upon [Victoria Metrics](https://victoriametrics.com/) which seems to be a perfect fit for my usecase.

It is build in a distributed fashion with a time-series storage ind mind. From my first view at the architectural view it looks quite fitting for my usecase and could be a nice general drop-in replacement for the Prometheus stack. 
![Victoria Metrics Architecture View](https://docs.victoriametrics.com/Cluster-VictoriaMetrics_cluster-scheme.png)
Source: [Docs Victoria Metrics](https://docs.victoriametrics.com/Cluster-VictoriaMetrics.html)

So let's get started in jump into the deep water and build our deployments.

A prepared example deployment is available [here](https://github.com/deB4SH/Kustomize-Victoria-Metrics)

# Victoria Metrics Cluster

The cluster deployment is composed of the official helm-chart made available and contains the three root components vmselect, vminsert and vmstorage.

VMStorage is the data backend for all stored metrics and is the single golden trough for your queryable data in a time range. Due to the fact that the vmstorage component manages raw data it becomes a stateful part of your cluster, which is requiring some sort of special care. 
VMInset and VMSelect are both stateless components in this stack and provide your third party applications access towards the raw data you are collecting in your cluster. 

Installing the metrics cluster is rather easy due to the provided helm chart, which is easiest to view via [ArtifactHub](https://artifacthub.io/packages/helm/victoriametrics/victoria-metrics-cluster).
At the time of writing this blog post version 0.9.60 is the newest and everything is based on this.

To reduce the tool dependency, I'm going to use the [HelmChartInflationGenerator](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_) for kustomize to keep everything in one *universe*.

First, we need to set up the inflation generator for this specific helm chart. 

> ./base/victoria-metrics-cluster/helmrelease.yaml
```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: victoria-metrics-cluster
releaseName: victoria-metrics-cluster
name: victoria-metrics-cluster
version: 0.9.60
repo: https://victoriametrics.github.io/helm-charts/
valuesInline: {}
IncludeCRDs: true
namespace: victoria-metrics
```

> ./base/victoria-metrics-cluster/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - helmrelease.yaml
```

The general information is pretty straight forward if you are already familiar with the helm-way to install prepared packages. 
You may notice that the **valuesInline** are empty. 
Due to the fact that I wanted to set up this deployment in a *patch-able* manor, the value overwrites are added with the next step.

> ./env/homelab/patches/patch-victoria-metrics-cluster.yaml
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
      storageClass: nfs-client
    podAnnotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8482"
```

This patch applies modifications towards the helm chart which are generally available via the preconfigured values within it. 
To elaborate my specific patch. 
I wanted to create specific RBAC rules for my environment but was required to disable the pod security policies, due to the fact that these were removed in Kubernetes 1.25.
Besides that, I have set for each component a replication count of one to reduce the load on my environment and configured the pod annotations so that metrics are collected afterward.

>NOTE: If you are going to use my example configuration. Please consider changing the storageClass, which may or may not be available in your infrastructure.

To collect both manifests, it is required to add an another kustomization with the following content.

> ./env/homelab/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: victoria-metrics

resources:
  - ../../base/victoria-metrics-cluster

patchesStrategicMerge:
  - patches/patch-victoria-metrics-cluster.yaml
```

Using the HelmChartInflationGenerator within kustomize is currently a bit tricky and requires a special third kustomization which *loads* the second kustomization as generator module.

> ./generators/homelab/kustomization.yaml
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: victoria-metrics

generators:
  - ../../env/homelab/
```

With this setup, you are able to deploy the cluster deployment with any cicd approach or even a gitops approach. 

If you are working with argocd to deploy this kustomization you need to add a *plugin* within your argocd-cm configmap and reference it within the plugin block in your application.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
data:
  configManagementPlugins: |
    - name: kustomize-build-with-helm
      generate:
        command: [ "sh", "-c" ]
        args: [ "kustomize build --enable-helm" ]
```

# Victoria Metrics Agent

Now with the cluster running, it is time to collect the first metrics from within the Kubernetes cluster. For this, it is possible to install the victoria metrics agent, which is also provided by a helm chart. 

The agent is a tiny software that collects metrics from various sources and writes them towards the configure remote address.

![Victoria Metrics Agent Overview](https://docs.victoriametrics.com/vmagent.png)
Source: [Victoria Metrics Documentation - VMagent](https://docs.victoriametrics.com/vmagent.html)

As first step, it is required to configure the helm inflation generator again. 

> ./base/victoria-metrics-agent/helmrelease.yaml
```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: victoria-metrics-agent
releaseName: victoria-metrics-agent 
name: victoria-metrics-agent 
version: 0.8.29
repo: https://victoriametrics.github.io/helm-charts/
valuesInline: {}
IncludeCRDs: true
namespace: victoria-metrics
```

Equally, to the cluster deployment, a initial kustomization is required to collect all manifest together and prepare them for patches.

As next step, the patch configuration is required to configure the agent with this deployment. 

>NOTE: This is a rather big patch and will be partly explained afterward


> ./env/homelab/patches/patch-victoria-metrics-agent.yaml
```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: victoria-metrics-agent
valuesInline: 
  rbac:
    pspEnabled: false
  
  deployment:
    enabled: false

  statefulset:
    enabled: true

  remoteWriteUrls:
   - http://victoria-metrics-cluster-vminsert.victoria-metrics:8480/insert/0/prometheus/
  
  config:
    global:
      scrape_interval: 10s

    scrape_configs:
      - job_name: vmagent
        static_configs:
          - targets: ["localhost:8429"]
      - job_name: "kubernetes-apiservers"
        kubernetes_sd_configs:
          - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
          - source_labels:
              [
                __meta_kubernetes_namespace,
                __meta_kubernetes_service_name,
                __meta_kubernetes_endpoint_port_name,
              ]
            action: keep
            regex: default;kubernetes;https
      - job_name: "kubernetes-nodes"
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/$1/proxy/metrics
      - job_name: "kubernetes-nodes-cadvisor"
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
          - target_label: __address__
            replacement: kubernetes.default.svc:443
          - source_labels: [__meta_kubernetes_node_name]
            regex: (.+)
            target_label: __metrics_path__
            replacement: /api/v1/nodes/$1/proxy/metrics/cadvisor
        metric_relabel_configs:
          - action: replace
            source_labels: [pod]
            regex: '(.+)'
            target_label: pod_name
            replacement: '${1}'
          - action: replace
            source_labels: [container]
            regex: '(.+)'
            target_label: container_name
            replacement: '${1}'
          - action: replace
            target_label: name
            replacement: k8s_stub
          - action: replace
            source_labels: [id]
            regex: '^/system\.slice/(.+)\.service$'
            target_label: systemd_service_name
            replacement: '${1}'
      - job_name: "kubernetes-service-endpoints"
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - action: drop
            source_labels: [__meta_kubernetes_pod_container_init]
            regex: true
          - action: keep_if_equal
            source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_container_port_number]
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels:
              [
                __address__,
                __meta_kubernetes_service_annotation_prometheus_io_port,
              ]
            action: replace
            target_label: __address__
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: kubernetes_name
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: kubernetes_node
      - job_name: "kubernetes-service-endpoints-slow"
        scrape_interval: 5m
        scrape_timeout: 30s
        kubernetes_sd_configs:
          - role: endpoints
        relabel_configs:
          - action: drop
            source_labels: [__meta_kubernetes_pod_container_init]
            regex: true
          - action: keep_if_equal
            source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_container_port_number]
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_scrape_slow]
            action: keep
            regex: true
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_scheme]
            action: replace
            target_label: __scheme__
            regex: (https?)
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels:
              [
                __address__,
                __meta_kubernetes_service_annotation_prometheus_io_port,
              ]
            action: replace
            target_label: __address__
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            action: replace
            target_label: kubernetes_name
          - source_labels: [__meta_kubernetes_pod_node_name]
            action: replace
            target_label: kubernetes_node
      - job_name: "kubernetes-services"
        metrics_path: /probe
        params:
          module: [http_2xx]
        kubernetes_sd_configs:
          - role: service
        relabel_configs:
          - source_labels:
              [__meta_kubernetes_service_annotation_prometheus_io_probe]
            action: keep
            regex: true
          - source_labels: [__address__]
            target_label: __param_target
          - target_label: __address__
            replacement: blackbox
          - source_labels: [__param_target]
            target_label: instance
          - action: labelmap
            regex: __meta_kubernetes_service_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_service_name]
            target_label: kubernetes_name
      - job_name: "kubernetes-pods"
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - action: drop
            source_labels: [__meta_kubernetes_pod_container_init]
            regex: true
          - action: keep_if_equal
            source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port, __meta_kubernetes_pod_container_port_number]
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: true
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels:
              [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
```
            

Most of the beforehand patch is the configuration for the agent to scrape targets and can be *ignored* or copied. The important parts are the first few lines.
With the *remoteWriteUrls* an external data source is configured. Due to the fact that both services are running side-by-side in a single cluster, it is possible to use the cluster ip to route this traffic internally. 

Both manifest locations added towards the environment overlay kustomization and the cicd environment should automatically install the agent. 

# Grafana

Building a collection of metrics is just one side of the medallion. The other side is displaying and reacting to changing metrics. 
As always, start with a helm chart inflation.

> ./base/grafana/helmrelease.yaml
```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: grafana
releaseName: grafana
name: grafana
version: 6.50.5
repo: https://grafana.github.io/helm-charts
valuesInline: {}
IncludeCRDs: true
namespace: victoria-metrics
```

The next step is to add the patch for Grafana.
With the following patch, the deployment will be configured to the desired environment. For example, the ingress configuration provides all required information to access Grafana afterward. 

The important part is the datasource configuration that provides the link between Grafana and the installed victoria metrics cluster. 
The VMSelect application provides a dropin replacement Prometheus endpoint for Grafana to be consumed. 

One downside of this used helm chart is that there is currently no support for a configuration reload sidecar container that refreshes the dashboards and configuration located in Kubernetes. Therefor, it is required to configure the default available dashboards within the dashboards block. 

> ./env/homelab/patches/patch-grafana.yaml
```yaml
apiVersion: builtin
kind: HelmChartInflationGenerator
metadata:
  name: grafana
valuesInline: 
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
        - name: victoriametrics
          type: prometheus
          orgId: 1
          url: http://victoria-metrics-cluster-vmselect.victoria-metrics:8481/select/0/prometheus/
          access: proxy
          isDefault: true
          updateIntervalSeconds: 10
          editable: true

  dashboardProviders:
   dashboardproviders.yaml:
     apiVersion: 1
     providers:
     - name: 'default'
       orgId: 1
       folder: ''
       type: file
       disableDeletion: true
       editable: true
       options:
         path: /var/lib/grafana/dashboards/default

  dashboards:
    default:
      victoriametrics:
        gnetId: 11176
        revision: 18
        datasource: victoriametrics
      vmagent:
        gnetId: 12683
        revision: 7
        datasource: victoriametrics
      kubernetes:
        gnetId: 14205
        revision: 1
        datasource: victoriametrics

  ingress:
    enabled: true
    annotations:
      cert-manager.io/cluster-issuer: selfsigned-ca-issuer
      kubernetes.io/ingress.class: traefik
      traefik.ingress.kubernetes.io/router.entrypoints: web, websecure
      traefik.ingress.kubernetes.io/router.tls: 'true'
      ingress.kubernetes.io/ssl-force-host: "true"
      ingress.kubernetes.io/ssl-redirect: "true"
    hosts:
      - grafana.lan
    tls:
     - secretName: grafana.lan
       hosts:
        - grafana.lan
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 100m
        memory: 128Mi
```

Adding all folder and resources to their relevant kustomizations, and you should be welcomed with a semi-complete monitoring stack for your Kubernetes environment. Missing components like the node-exporter could easily be added to the same deployment process with the already shown approach.

As a small reminder: the complete deployment is described within the prepared repository under the following url [https://github.com/deB4SH/Kustomize-Victoria-Metrics](https://github.com/deB4SH/Kustomize-Victoria-Metrics).
