---
layout: post
title: ArgoCD Multi-Cluster Deployments
date: 2023-03-22 00:00 
comments: false 
categories: 
- Kubernetes
- Deployment
- GitOps
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
I'm currently working on refactoring the way to set up kubernetes clusters within the infrastructure of my current employer. (Role: Platform Engineer) 
Due to growing configuration requirements and time-consuming decisions we’ve decided within our team that it is time to refactor the stack and try out something new. 
The current setup is based on flux-cd with a self-written templating software to render manifests based on a single configuration file. 
This configuration file is called config.yaml, who would have guessed that, and contains all critical information to bootstrap and deploy a new cluster environment. 
Basic manifests are provided from an internal *kubernetes service catalog* which is version pinned for a cluster. 
The rendered manifests are stored within a dedicated kubernetes-clusters repository (`${cluster.name}/cluster.generated/${service.name}`) and are initially deployed with a ci/cd approach to apply the tanzu kubernetes cluster and kickstart flux-cd on it. 
After the initial setup: flux-cd picks up the stored manifest files within the kubernetes cluster repository and installs everything. 

A catalog deployment from our kubernetes service catalog may look like:

> **NOTE:** I will focus on the cluster part here. The service catalog is a collection of typical flux manifests (HelmRepository, HelmRelease) with a default configuration in it. 

For the reference the following code snippet provides the Git Repository for flux-cd to pull manifests from.
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: service-catalog
  namespace: service-catalog
spec:
  interval: 10m0s
  ref:
    semver: 2.5.*
  secretRef:
    name: service-catalog-pat
  url: https://corporage-git-repository.corporate.tld/_git/kubernetes-service-catalog
  gitImplementation: libgit2
```

As starting point is always a flux-cd kustomization that picks up the provided manifests within the service catalog.
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta1
kind: Kustomization
metadata:
  name: external-dns
  namespace: service-catalog
spec:
  timeout: 5m
  interval: 10m0s
  retryInterval: 15s
  path: ./dns/external-dns
  prune: true
  sourceRef:
    kind: GitRepository
    name: service-catalog
    namespace: service-catalog
  validation: client
  patches:
  - placeholder-patch
```

As you may already see we're adding a (not so valid) blank placeholder patch that is required for the next steps.
To change values for the helm release we are appending a patch to the flux kustomization. 
Due to the limitation that flux doesn't have any filesystem at this point of deployment you can't use something like strategic merges with files. 

The following listing shows an example patch that is appended on the flux kustomization at the last position within the patches list.

```yaml
- op: add
  path: "/spec/patches/-"
  value:
    target:
      kind: HelmRelease
      name: external-dns
    patch: |-
      apiVersion: helm.toolkit.fluxcd.io/v2beta1
      kind: HelmRelease
      metadata:
        name: external-dns
        namespace: external-dns
      spec:
        values:
          provider: pdns
          pdns:
            apiUrl: "https://powerdns.corporate.tld"
            apiPort: "443"
            secretName: "external-dns"
          domainFilters:
            - devops-test-cluster.k8s.corporate.tld
            - devops-test-cluster.corporate.tld
          txtOwnerId: "devops-test-cluster"
          extraArgs:
            pdns-tls-enabled: false
```
With this mechanism we are able to change the provided default configuration for each cluster environment and render those patches dynamically base on the configuration within the `config.yaml`.

Everything is hooked together with a simple kustomization.yaml which is controlled by a *top-level* kustomization.
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- release-external-dns.yaml


patches:
  - path: patches/settings.yaml
    target:
      group: kustomize.toolkit.fluxcd.io
      kind: Kustomization
      name: external-dns
  - path: patches/remove-placeholder.yaml
    target:
      group: kustomize.toolkit.fluxcd.io
      kind: Kustomization

```

The remove placeholder patch is nothing special. It just removed the first element.

```yaml
- op: remove
  path: "/spec/patches/0"
```

Deployments of our customers are located within a different directory (`${cluster.name}/cluster.custom/*`) that is picked up by flux or a completly different repository.

This approach provides us a highly customizable and secured state of deployment. 
Due to the reproducable rendered templates we are able to throw away the **cluster.generated** folder for each upgrade and can work in a *fire and forget* environment.

The downside is that upgrades on our infrastructure or changes to it are time consuming, due to the fact that everything is maintained within it's dedicated reposiotory. There is no centralization. 
Every change needs to be done within the golden configuration file for each environment, which results in a render of the templates, which also results in a validation of the rendered manifests and a checkin of every required change.
Each deployment has multiple files for patches and changes to the base-configuration which can't be loaded from a file or merged with strategic merges.

> **NOTE:** The process sounds fun when it's done for a single environment.. if there are twenty.. good luck with that.

The scalability of this approach lacks behind and each new cluster creates a new context for our team-members to keep track of. 
Without any action against this: it is going to be a big pain-point in daily operation.

To reduce the costs of maintenance for every environment we want to create a cockpit from which we can deploy manifests remotly.
We also want to aggregate the configuration files for each environment within one repository, so you dont need to switch contexts all the time. 

Within a small timeframe and some proof-of-concept work we decided to go with argo-cd and it's capabilities to deploy manifests into different clusters and maintain a smaller footprint git repository.

# Proposed Proof of Concept Setup

To tackle the presented issues from the beforehand chapter I like to take a deeper dive into the structure of our current argocd stack and the proof of concept stack before that. 

Removing context switches was one of our primary goals. Achieving this resulted in a complete restructuring of our kubernetes service catalog and deployment strategy. Everything from manifests to deployment configuration should be located in a single repository. The result of this restructuring is shown in the following tree view listing.

```console
./
├── argocd-applicationsets
├── helm
├── kustomize
├── README.md
└── cluster-environments
```

As always it is necessary to question your own concepts and dicisions.
The initial setup was split into two repositories, one which contains all manifests, one that hold the deployment configuration.
The advantage of collecting everything is kind of obvious but we reduced the amount of context changes with tremendously. The workflow of editing and adding new software to our general deployment is now streamlined.

On of the next migration steps was to ease up the usage of helm.

## Setting up Helm Subcharts
Many of our applications we are providing to our internal customers are provided via helm. Helm allows it's users to inline values or load them directly from configuration files. 

To allow extendability of one helm chart we've build our own helm charts ontop of the existing ones and reference the desired charts as subcharts/dependencies. 

Structurally our setup for helm charts looks like the following tree view.

```console
./
├── Chart.yaml
├── templates
│   ├── external-dns-secret.yaml
│   └── root-ca-01.yaml
└── values.yaml
```

The pivotal point of helm is always the **Chart.yaml** which contains every relevant information to install the chart on a cluster.
```yaml
apiVersion: v2
name: external-dns
version: 1.0.0
description: This Chart deploys external-dns.
dependencies:
  - name: external-dns
    version: 6.13.*
    repository: https://charts.bitnami.com/bitnami
```
As shown within the listing we are building our chart ontop of a dependency that installs the application itself. 
Configuration changes are done within the **values.yaml** and may look like this.

```yaml
pdns_api_key: overlay_me

external-dns:
  pdns:
    apiUrl: "https://powerdns.corporate.tld"
    apiPort: "443"
    secretName: "external-dns"

  txtOwnerId: "your_awesome_textowner_id"

  image:
    registry: proxy.corporate.tld/hub.docker.com
  rbac:
    pspEnabled: true
  provider: pdns

  extraVolumeMounts:
    - name: certs
      mountPath: "/etc/ssl/certs/root-ca-01.pem"
      subPath: "root-ca-01.pem"

  extraVolumes:
    - name: certs
      configMap:
        name: root-ca-01

  extraArgs:
    pdns-tls-enabled: false
    tls-ca: /etc/ssl/certs/root-ca-01.pem
```

The important point is that values of your dependencies require a correct indentation under the same name as configured within the chart.

Additional manifests, like the root-ca, are provided from within the template directory. With this approach you can easily provide additional manifests with the default installation. 

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: root-ca-01
data:
  root-ca-01.pem: |
    -----BEGIN CERTIFICATE-----
    MII[....redacted....]Bg==
    -----END CERTIFICATE-----

```

Based on this approach it is also possible to repack multiple helm charts into an single installation. Keep in mind that building a single collection of multiple charts in one single chart may bring additional code complexity and increases the hurdles to maintain.

As next step I want to deploy the newly created helm chart onto multiple clusters without referencing it everywhere. 
ArgoCD provides a nice approach to create applications in a dynamic fashion.
Within the next chapter I like to present the [application set](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/) of argocd and our current approach to provision the charts on each maintained cluster.

## ArgoCD Application Set

The argocd application set provides the functionality to generate automatically applications based on set generators. To keep the focus on the general structure I removed a lot of moving parts from the next ApplicationSet and reduced it to the critical components. 

In our current infrastructure we are following the general consense to provide all projects a development cluster for their daily-task and a seperate production cluster for the actualy live service.
With the following ApplicationSet we are generating for each cluster, which is labeld with dev or prd, an application to rollout the external dns. 

> **NOTE:** The cluster connection is done beforehand in a seperate task. To add clusters to a argocd instance please use the argocd cli or create the service accounts on your own. 

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: external-dns
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: dev
    - clusters:
        selector:
          matchLabels:
            env: prd
  template:
    metadata:
      name: "{{name}}-external-dns"
      annotations:
        argocd.argoproj.io/manifest-generate-paths: ".;.."
    spec:
      project: bootstrap
      source:
        repoURL: https://corporate-repository-argocd.corporate.tld/kubernetes-service-catalog
        targetRevision: main
        path: "./helm/dns/external-dns"
        helm:
          releaseName: "external-dns"
          valueFiles:
            - "values.yaml"
            - "../../../values/{{name}}/dns/external-dns/values.yaml"
      destination:
        name: "{{name}}"
        namespace: "external-dns"
      syncPolicy:
        automated:
          prune: false
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
        retry:
          limit: 2
```
Through this deployment configuration we achieve that every connected cluster receives the same artifacts defined within our kubernetes service catalog. 
Overlaying cluster specific information is done via a second helm value file that merges into the first on. 
```yaml
pdns_api_key: T[...redacted...]c=

external-dns:
  domainFilters:
    - example-cluster.corporate.tld
  txtOwnerId: "example-cluster"
```

Through this method we are reducing the required configuration tremendously. Only cluster specific configuration resides within the second values file. Generic corporate related configuration like proxy configuration and generic purpose configuration resides inside the first.
We also achieved with this approach that all values are directly filebased and not embedded within any kustomize-alike patch file. 

# Conclusion
With our switch from fluxcd to argocd we were able to streamline our tasks as platform team and provision our client clusters directly without the hassle of managing multiple cluster configuration within several places. We were able to reduce the code complexity that was building up with more and more services running per default on our platform. We were able to reduce the required time to maintain numerous clusters with a small team and deliver updates quick to each environment. 
We were able to scale our platform accordingly to our needs without the hassle of maintain a collection of different scopes. We were able to reduce our time to market by hours due to a smaller configuration footprint.
We were able to onboard new collegues easily due to the reduced complexity.

As a clarification: Fluxcd is not a bad tool. Do not get me wrong. It simply did not cater our needs. 

I hope through this devops story you get a small glimpse into my daily business. If there are any open questions: please feel free to contact me.
