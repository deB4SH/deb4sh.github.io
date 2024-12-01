---
layout: post
title: Building a simple internal developer platform with ArgoCD
date: 2024-12-01 00:00 
categories: 
- InfrastructureAsCode
tags:
- gitops
- argocd
- kubernetes
---
Hi all,
in my current role as platform engineer I'm maintaining and building with a very small team a scalable kubernetes infrastructure for multiple clients in many sizes and usecases. With this post I want to showcase our approach to solve scalability and extendability of our setup and how to still follow the principals of fail fast and fail often to achieve a solid solution.

### Historic growth and emerging challenges
Each good story starts with a bit of a retrospective at the start. We started back in 2022 with a pretty much blank canvas on how to build a scalable kubernetes environment for clients. After a small look-around and first playtests we settled on fluxcd. Out clients received an infrastructure repository that created the whole context for them. From external-dns up to certificate managent via cert-manager. Pretty much just in time after the first clients onboarded on this endeavor we realized that not all of them are relaxed when the need arises to maintain their configuration for the provided services and also their workload services all together. A first iteration of a cluster templater arose with the approach of an *throw-away* part for cluster base services and an area where our clients could place their workloads. The persepective shifted and it was kind of smooth sailing for a time. With the first steps done and everything running arose a second thought issue. How do we update such a decentralized environment? Updating our templater was the obvious choise but with each new iteration there were changes within the configuration that needed to be explained to each project related team member. The communication overhead was enormous and we struggeled to maintain a high speed in ongoing changes. 
Our perspective shifted towards a centralized approach. A team split *occured* and a platform team was born. The maintainers of the internal kubernetes infrastructure and base context on it. The maintenance part of the kubernetes cluster went away from the dev teams that could now focus on maintaining their specific appliction workload. Updates, Security-Patches, generic configurations were not centralized in one team that specifically focuses on this term.
With this major organisational change came the productivity again. We also reevaluated our tech-stack this time and wanted an another aproach for our clusters. A switch to argocd was welcoming. Our cluster design is now topic of the next part in this blog post.

### Control plane clusters are awesome

No one does simply rule multiple clusters from one instance! Hah. You can. ArgoCD provides an handy interface to join multiple clusters to an existing argocd instance and control them centrally. A general documentation is available here [https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-management/](argocd cluster management).
You simple need an active logged in session towards the target cluster and an active login via argocd cli to join the target towards your *new* instance.

To achieve somewhat of an *infrastructure as code* approach we scripted something to join clusters based on their name. This also determines if a cluster is joined towards the production environment or development environment. 

#TODO: insert script to identify clusters here

With this script each cluster also receives specific labels which control which *bundle* is deployed on it. A bundle is a set of applications prepared by the platform team which will work in tandem to provide a service. A good example could be the security-basic bundle which contains services like falco, node-exporter, kyverno and otterize.

>**NOTE:** As a short headup what the applications are that we deploy in our security-basic bundle.
>Falco is a cloud native security tool that provides runtime security across hosts, containers, Kubernetes, and cloud environments. 
>Node-Exporter is a tool that exports health metrics of the specific node.
>Kyverno is a policy engine designed for Kubernetes.
>Otterize is a bundle of network related tools to easyly create and control network policies.

#TODO: add graphic that displays the "spiderweb" from a control plance cluster to its childs with different bundles

With everything setup accordingly we simply needed to configure the services as desired by most clients or development teams.
To ease up usage we decided that it may be best to seperate our values into two parts. 
A well-known part that can be publically available and a secret part that contains values that may be related to a onpremise environment, confidental or just not to be shared publically. 

This sparked the creation of an publically available [https://github.com/Hamburg-Port-Authority/kubernetes-service-catalog/](kubernetes service catalog) in which our umbrella charts reside and provide an extendable space for changes to other thrid party helm charts. This also provided us with an easier way to share a common configuration accross all kubernetes clusters in different hosting locations. 

>**NOTE: What is an umbrella chart? An umbrella chart is a helm configuration that wraps around one-to-many existing charts and extends them configuration-wise or template-wise. 

Building these is straight forward. Simply create *default* helm chart yaml and extend it with a **dependencies** block in which you configure your charts to pre-configure or extend. A good example is our umbrella chart for our victoria-metrics-operator deployment found [https://github.com/Hamburg-Port-Authority/kubernetes-service-catalog/blob/main/monitoring/victoria-metrics-operator/Chart.yaml](here)

````yaml
apiVersion: v2
name: victoria-metrics-operator
version: 1.0.0
description: This Chart deploys victoria-metrics-operator.
dependencies:
  - name: victoria-metrics-operator
    version: 0.37.0
    repository: https://victoriametrics.github.io/helm-charts/
````
Each cluster that applies this chart comes with a preconfigured values file which contains the minimal setup for our environment. The values file can be found [https://github.com/Hamburg-Port-Authority/kubernetes-service-catalog/blob/main/monitoring/victoria-metrics-operator/values.yaml](here).



### One templater to rule them all
- how did we write our python templater

### Further considerations
- Sveltos
- modern templater (yart)