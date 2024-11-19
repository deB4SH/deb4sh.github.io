---
layout: post
title: Homelab Stories - Deploy your own Instance of Antennas in your Homelab
date: 2021-05-31 00:00
categories:
- Selfhosted
- DevOpsStories
- Kubernetes
tags:
- kubernetes
- antennas
- iptv
---

Hi all,

Watching linear tv-programs is annoying, or? But sometimes some good talk shows or series are airing over the "old" tv. A general purpose service to stream iptv content into your local network is
tvheaded. Sadly some awesome projects like jellyfin or plex are not able to catch the streams directly from tvheaded and require a HDHomeRun api. Antennas serves as proxy between the media systems and
tvheaded as api-gateway.

## Motivation

As viewer want to watch and record tv shows directly without any requirement of letting my computer run or record it via vlc.
As viewer I want to watch recorded shows somewhere, without being required to some magic like calling through vlc some kind of volume on my NAS.
Also as viewer would like to use my media system (jellyfin) to stream the dvr content of, due to easy usage through any device here. 
Jellyfin is available on android and firetv, so it should be easy to provide it on any device inside my household. 

Currently there is a TVheaded available that maps the iptv service provided by the telekom to all local devices. 

From the looks of it: TVheaded as inbound, Antennas as API-Gateway, Jellyfin as Media-System for all devices for easier access

## Solution

To get antennas running in our cluster we are required to provide serveral manifest files that contain crucial parts. I am using as namespace media in this case, but you are free to change that to whatever you desire. 
It is a good practice to create for each individual application a namespace, but also to group them by topic. Feel free to change it to your desire.

Lets start with the deployment.

````yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: antennas
  namespace: media

spec:
  replicas: 1
  selector:
    matchLabels:
      app: antennas
  template:
    metadata:
      labels:
        app: antennas
      name: antennas
    spec:
      containers:
        - image: thejf/antennas:latest
          imagePullPolicy: IfNotPresent
          name: antennas
          ports:
            - containerPort: 5004
              name: http
              protocol: TCP
          envFrom:
            - configMapRef:
                name: configmap-antennas
          resources:
            limits:
              cpu: 250m
              memory: 100M
            requests:
              cpu: 50m
              memory: 30M
````

I know using **latest** as tag is a bad design by default, but sadly the author *thejf* tagged the latest image only with **latest** not something else. Beside this there are multiple other and older
tags available, which may or may not be, working. Also keep in mind: the current image is not available for armv8, armv7 or armhf. If you have set up a mixed cluster please add the following block
infront of your container defintion.

````yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: beta.kubernetes.io/arch
              operator: In
              values:
                - amd64
````

Beside that: The deployment is pretty much straight forward. Antennas is not really ressource-hungry and is quite "
overpowered" with 250m cpu and 100m memory. The interesting part is the configmap which contains the url for antennas and the connectionstrings for tvheaded. Keep in mind, if your tvheaded is secured
with credentials you are displaying them here. In that case I would suggest moving them into a secret or even a keystore like Vault.

````yaml
apiVersion: v1
kind: ConfigMap

metadata:
  name: configmap-antennas
  namespace: media

data:
  ANTENNAS_URL: "http://192.168.1.102:5004"
  TVHEADEND_URL: "http://service-tvheaded-clusterip.media:9981"
  TUNER_COUNT: "2"
````

Antennas itself is providing its api under an ip address in my local area network. Due to the fact that mac-vlan is pretty difficult to provide in kubernetes I went with
MetalLB (https://metallb.universe.tf/) which provides a Layer2 loadbalancer for this kind of service. There is also a story available for setting up metallb in your cluster. Check out my post **Homelab Kubernetes Stories - Deploy METALLB in your homemlab** for further information.

````yaml
kind: Service
apiVersion: v1
metadata:
  name: service-antennas
spec:
  ports:
    - name: http-antennas
      protocol: TCP
      port: 5004
      targetPort: 5004 #container port
  selector:
    app: antennas
  externalTrafficPolicy: Local
  loadBalancerIP: 192.168.1.102
  type: LoadBalancer
````

Due to the functionality of kubernetes to access services and dns names clusterwide over the combination of **servicename**.**namespace** it is pretty easy to access your tvheaded instance if it is running the same cluster.
To access the tvheaded instance I am directly using the service of tvheaded, so traffic is not required to run "externally" over a local address in my network. 

If your media system is also running in the same cluster, you could also switch the *LoadBalancer* against a *ClusterIP* service or keep them running simultaneously in your infra.

````yaml
kind: Service
apiVersion: v1
metadata:
  name: service-antennas-clusterip
spec:
  type: ClusterIP
  ports:
    - name: http-antennas
      protocol: TCP
      port: 5004
      targetPort: 5004 #container port
  selector:
    app: antennas
````

After setting up the three or four files, it is easiest to hook them together in a single kustomization.yaml and use it as aggregation place for simple deployments.

````yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: media

resources:
  - base/deployment.yaml
  - base/service-lb.yaml
  - base/service-clusterip.yaml
  - base/configmap.yaml
````

With that in place it is possible to simply call ```k apply -k ./``` to deploy your newly created deployment in your kubernetes cluster inside the namespace media.

## Conclusion

We are now pretty much set up to stream any available iptv content from tvheaded via a hdhomerun api. Due to the clusterip it is possible to use that directly in jellyfin via ```http://service-antennas-clusterip.media:5004/```. _"No external traffic required"_
If available it is possible to grab XMLtv directly off tvheaded too with ```http://service-tvheaded-clusterip.media:9981/xmltv/channels``` to have some kind of tv program available.

With this setup you should be good to go and _stream away_. 

![screenshot antennas](/assets/2021-05-31-Kubernetes-Manifest-Antennas/antennas-screenshot.jpg)

### FAQ

If there are any questions - feel free to reach out via [twitter](https://twitter.com/deb4sh) or [reddit](https://www.reddit.com/user/deb4sh)

####  Why no SSL?
I know. SSL everything. Due to the fact that this is only local traffic, I do not want to setup the ssl required "overhead" like cert-manager, ingress to provide the traffic secured, make everything available with my self-signed root-ca.

