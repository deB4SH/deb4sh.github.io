---
title: DevOpsStories - ArgoCD Multi-Cluster Deployments
date: 2023-02-09 00:00 
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
I'm currently working on refactoring the way to set up kubernetes clusters within the infrastructure of my current employer. (Role: Plattform Engineer)
Due to growing configuration requirements and time-consuming decisions we've decided within our team that is time to refactor the stack and try out something new. 
The current setup is based on flux-cd with a self-written templating software to render manifests based on a single configuration file. 
This configuration file is called `config.yaml`, who would have guessed that, and contains all cricital information to bootstrap and deploy a new cluster environment. 
Basic manifests are provided from an internal *kubernetes service catalog* which is version pinned for a cluster. 
The rendered manifests are stored within a dedicated kubernetes-clusters repository (`${cluster.name}/cluster.generated/${service.name}`) and are initially deployed with a ci/cd approach to apply the tanzu kubernetes cluster and kickstart flux-cd on it. 
After the initial setup: flux-cd picks up the stored manifest files within the kubernetes cluster repository and installs everything. 

A catalog deployment from our kubernetes service catalog may looks like:

NOTE: I will focus on the cluster part here. The service catalog is collection of typical flux manifests (HelmRepository, HelmRelease) with a default configuration in it.

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
Due to the limitation that flux doesn't have any filesystem at this point of deployment you can't use something like stategic merges with files. 

The following listing shows a example patch that is appended on the flux kustomization at the last position within the patches list.

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

The downside is that upgrades on our infrastructure or changes to it are time consuming, due to the fact that everything within the specific clusters is maintained within it's dedicated reposiotory. 
Every change needs to be done within the golden configuration file for each environment, which results in a render of the templates, which also results in a validation of the rendered manifests and a checkin of every required change.
Each deployment has multiple files for patches and changes to the base-configuration which can't be loaded from a file or merged with strategic merges.
The process sounds fun when it's done for a single environment.. if there are twenty.. good luck with that.

To reduce the costs of maintenance for every environment we want to create a cockpit from which we can deploy manifests remotly.
We also want to aggregate the configuration files for each environment within less repository, so you dont need to switch contexts all the time. 

Within a small timeframe and some proof-of-concept work we decided to go with argo-cd and it's capabilities to deploy manifests into different clusters and maintain a smaller footprint git repository.


# Proposed Proof of Concept Setup

* general structure
```console
.
├── argocd-applicationsets
├── helm
├── kustomize
├── README.md
└── cluster-environments
```

* use of helm dependency in charts to have charts in a single repository

* structure of values.yaml and cluster-values

* application set to deploy to nodes

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
        repoURL: https://corporate-repository-argocd.corporage.tld/kubernetes-service-catalog
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


# Conclusion

