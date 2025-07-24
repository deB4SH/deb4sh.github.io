---
layout: post
title: Scaling Beyond Kubernetes
date: 2025-07-06 00:00 
categories: 
- InfrastructureAsCode
- DevOpsStory
tags:
- platform engineering
- development
- platform
---

Hi all,
it's me again. After six months of silence there is a new blog post. Yaaay! Fun aside, the topic of this blog post is scaling beyond kubernetes. But what does this mean? I want to show you two simple cases on how to scale your manifest-infrastructure behind your kubernetes clusters and what possible advantages this may have for you and your services. Everything is build ontop of my small templater called Yet Another Random Templater (**YART**), which is also open source here: [Github Link](https://github.com/deb4SH/yart). Every usecase shown is also source available in a designated github repository under the following [link](https://github.com/deB4SH/demo-yart-scaling-beyond-kubernetes). Without further ado let us get started.

![banner rising problems](/assets/2025-07-16-scaling-beyond-kubernetes/banner_rising_problems.png)

### Setting up the Story
Let me set you up with a fictional story. Think of a company that has a rather large IT and runs serveral encapsulated workloads in different kubernetes clusters. Why different ones? To reduce the blast radius of possible attacks and outages of a single product. When one application fails due to a missconfigured manifest and destroys its own cluster it should not take down every other service with it. Let us assume that there are 20 different applications that should run in their isolated environments. Not every developer within the application service teams wants to tackle issues in a kubernetes environment. Most of them draw their line with the designated deployments for their applications. So the company needs some people to manage the underlying infrastructure and build the context for the application teams to run their applications on. A team of designated engineers is hired to maintain this infrastructure. But what now? How should they tackle the scaling issues. How to provision everything? How to work together? How to mitigate feature creep and keep most of the environment slim and fast moving? Do we just copy paste everything twenty times two to resolve every issue? How to tackle sleepy-eye issues while copy pasting configuration manifests and possibly destroy an other environment due to repetetive work with a high error rate? How to keep developers and engineers sane and out of burnout-boredome-hell? How to possibly stop the braindrain due to burnout leavers? The keen eye may already see issues and rising issues. 

Building the right tools for the job may help your engineers to grow and keep the sanity in check. Building these tools to do one particular job helps them reduce possible pitfalls, remove copy-paste hells and ease up possible join-move-leave topics with fluctuating team members or even inexperienced users. In the following chapters I would like to present you two usecases. Within the first usecase we are looking at a mixed team in which both the platform engineers and application developers are taking care of their designated stack. The second usecase describes a managed infrastructure team in which a designated team controlls all clusters and maintains them in a single golden source repository.

All these usecases are easy to maintain through [YART](https://github.com/deb4SH/yart). But how does this work? 
YART is build ontop of serveral frameworks that allows users a schema-based template approach for their projects. With the help of a [json schema](https://json-schema.org/) the templater maintainers, in both usecases done by the platform team, can describe the expected configuration down to the level of input checking with regex. After an successfull validation of the input configuration the templater hands over everything to jinja2 which templates all available files. 

![diagram yart builder](/assets/2025-07-16-scaling-beyond-kubernetes/preamble_yart_overview.drawio.svg){:style="display:block; margin-left:auto; margin-right:auto"}

A typical json schema may look like the following [nodePools.json](https://github.com/deB4SH/demo-yart-scaling-beyond-kubernetes/blob/main/case_1/schema/configuration/tanzu/nodePools.json) which describes a node pool within a tanzu kubernetes cluster. To not end as json schema reference guide please consult the official [reference guide](https://json-schema.org/understanding-json-schema/reference). In regard of setting up a yart template and how to work with dynamic paths, there are serveral documents available. In my [first blog post](https://deb4sh.github.io/development/2023/12/08/YART.html) for the general availability release back in 2023 I wrote a general overview how to work with yart. There is also a broader documentation available within the [README.md](https://github.com/deB4SH/YART/blob/main/README.md) at github.

But without any further storytelling - lets get started on the topic.

![banner teamwork dreamwork](/assets/2025-07-16-scaling-beyond-kubernetes/banner_teamwork_dreamwork.png)

### Use Case 1: Team Work Makes The Dream Work

*Team Work makes The Dream Work*, how often did you hear this punchline? I heared it alot. Mostly from managers trying to hype developers for something unrelated, but in this case it may be true. In this use case I would like to think of a shared responsibilty of running the services and infrastructure together as crossfunctional team. What does this mean? Platform Engineers and Application Developers are working together to provide a service. 
This does not mean the application developers are working on platform tools or vice versa. The common ground is a tool which gets prepared by the platform team and is mostly used by them in combination with the application developers. The software renders and prepares manifests, modules, codeblocks that are required to spin up infrastructure, clusters, networks and everything you may desire. Both teams are working with the same source on a *golden configuration* that creates everything related. For example: a platform engineer is mainly caring about the groundwork like network-security, node-pool sizes and autoscaling features. A developer may be interested in using serveral additional services on a provided kubernetes cluster like argocd, externaldns or an nginx ingress controller. Both work with the same tool and one single golden configuration to create a setup. In an abstract visualization that may look like the following.

![diagram use case one teamwork](/assets/2025-07-16-scaling-beyond-kubernetes/use_case_one_diag_teamwork.drawio.svg){:style="display:block; margin-left:auto; margin-right:auto"}

After all that yapping lets get into some code blocks. As already mention both teams are working on single *golden configuration*. In a standard setup with YART this golden source is called a [config.yaml](https://github.com/deB4SH/demo-yart-scaling-beyond-kubernetes/blob/main/case_1/config/config.yaml).

- kurz beschreiben was plattform engineers da so konfigurieren
- beschreiben über welche teilbereiche die application devs sich gedanken machen
- sicherheit durch json schema beschreiben (muss noch eingebaut werden in die demo)
- durch enge zusammenarbeit ist ein hoher wissensgewinn bei allen 

### Use Case 2: Managed Infrastructure Team
- kurze erläuterung was use case 2 ist und wie das team dort funktioniert


### Conclusion

### Socials and Thanks