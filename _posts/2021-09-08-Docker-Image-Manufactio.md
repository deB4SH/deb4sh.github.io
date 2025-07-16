---
layout: post
title: Docker Image - Minecraft Manufactio Docker Image 
date: 2021-09-08 00:00 
categories: 
- Docker 
tags:
- docker
- ci
- cd
- minecraft manufactio
- maven
- dind
- jenkins
- jeninsfile
---

Hi all, last week we had a discussion on our discord server to play a minecraft modpack as group again and pretty much everyone knows - "this gets difficult to find one". Due to the fact that in the
last few years everyone hosted a modpack for the whole discord there are multiple playthroughs done in many modpacks for minecraft. After a kinda long search we settled on Manufactio by
Golrith. [Link to curseforge](https://www.curseforge.com/minecraft/modpacks/manufactio). From the looks of it - it is a pretty solid modpack but without any easy support for setting up a server.

So, welcome to my new blog post. Let's create a docker image for this modpack specific.

## Creating the Dockerfile

Everything starts with a Dockerfile in Docker. So lets get started.

Due to the fact that this modpack is only available for a pretty "old" minecraft version `1.12` it is easier to start from a jdk8, preferably a oracle-jdk one. Luckily binarybabel is providing older
jdk8 images via dockerhub, so we don't need to setup our own in this case.

````Dockerfile
FROM binarybabel/oracle-jdk:8-debian
LABEL maintainer=deB4SH(https://github.com/deB4SH)
ENV ACCEPT_ORACLE_BCLA=true
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
COPY docker-entrypoint.sh /tmp/docker-entrypoint.sh
````

Beside the `ACCEPT_ORACLE_BCLA` that is required for using the oracle-jdk, there are static environment variables for `LC_ALL` and `LANG` set up. To set up a minecraft server these two are pretty much
optional and not required, but we want to check the server status while it's active and running. For this we are going to rely on [mcstatus](https://github.com/Dinnerbone/mcstatus) which provides a
nice cli interface. At last import a `docker-entrypoint.sh` script to define what should happen after the image is started as container.

Next step should be to install some required packages. As already mentioned we want to use mcstatus to monitor the minecraft instance. Beside that... unzip is required to unpack the modpack.

````Dockerfile
COPY apt/source.list /etc/apt/sources.list
RUN apt update && apt install unzip && apt install python3 python3-pip -y
RUN python3 -m pip install mcstatus
````

After these steps there is the big part still open. Setting up the forge and manufactio inside the image.

````Dockerfile
RUN mkdir /var/manufactio
RUN mkdir /var/manufactioconfig
COPY forgeserver/forge-1.12.2-14.23.5.2855-installer.jar /var/manufactio
WORKDIR /var/manufactio
RUN java -jar forge-1.12.2-14.23.5.2855-installer.jar --installServer
#COPY Mods
COPY manufactio.zip  /var/manufactio.zip
WORKDIR /var
RUN unzip manufactio.zip
RUN rm -rf manufactio.zip
WORKDIR /var/manufactio
#Link specific files to different folder for easier docker-setups
RUN mv /var/manufactio/banned-ips.json /var/manufactioconfig && \
    mv /var/manufactio/ops.json /var/manufactioconfig && \
    mv /var/manufactio/eula.txt /var/manufactioconfig && \
    mv /var/manufactio/server.properties /var/manufactioconfig && \
    mv /var/manufactio/options.txt /var/manufactioconfig
RUN ln -s /var/manufactioconfig/banned-ips.json /var/manufactio/banned-ips.json && \
    ln -s /var/manufactioconfig/ops.json /var/manufactio/ops.json && \
    ln -s /var/manufactioconfig/eula.txt /var/manufactio/eula.txt && \
    ln -s /var/manufactioconfig/server.properties /var/manufactio/server.properties && \
    ln -s /var/manufactioconfig/options.txt /var/manufactio/options.txt
````

The steps are self explanatory. First there we need to set up two directories inside the image. The folder `/var/manufactio` provides everything. Starting from the forge server installation up to the
manufactio mods that are used. After that we need to copy the installer and ofcorse install the server itself inside the image. If you are reproducing this image based on this guide - an additional
step could be to remove the installer after the installation process. It is not required to be available after that. As next step we need to copy all mods into the image. To achieve that there is a
.zip available inside this git, which provides everything required. The zip is based on the downloadable client from curseforge with some parts stripped away. We do not need every client mod on our
server to get the mod running.

Last step in this block is moving and symbolic linking copnfiguration files into a seperate folder. This eases up the usage inside a kubernetes environment where configurations may be provided as
configmap and mounted into the container. **These steps are fully optional**. If your usecase is just hosting via docker-compose you could also easyly mount files directly
with `${PWD}/config/banned-ips.json:/var/manufactio/banned-ips.json`.

To round things up we need to add an `Entrypoint` to the docker image. In our case the docker-entrypoint that got copied into the image.

````Dockerfile
#RUN SERVER
ENTRYPOINT ["/bin/bash", "/tmp/docker-entrypoint.sh"]
````

After that, the image is pretty much done. We could build this image with docker, tag it, use it to host our own manufactio server, but in this guide we are going a bit deeper into the rabbit hole and
start building up a cicd infrastructure.

### Dockerfile

The full Dockerfile is available inside the github repository found
here: [https://github.com/deB4SH/Docker-Manufactio/blob/master/src/docker/Dockerfile](https://github.com/deB4SH/Docker-Manufactio/blob/master/src/docker/Dockerfile)

## CI CD

For setting up an automated build we need to start with thinking about - "how we want to build the image, how to tag, how to deploy somewhere". This example uses the following stack:

* Maven
  * structured aproach for defining variables and components for each build
* [Maven Docker Fabric8 Plugin](https://github.com/fabric8io/docker-maven-plugin)
  * awesome plugin to build, tag, deploy images with maven
* Jenkins

In regard of maven - The scope of this tutorials is primarly on the dockerfile and build, deployment process. Describing the whole maven build-cycle is a bit out of scope for this.
The  [pom.xml](https://github.com/deB4SH/Docker-Manufactio/blob/master/pom.xml) describes the whole build, if you are firm in maven. If desired I'm going to write an another post with this in
focus. :)
After removing maven of the scope lets get a deeper look into the [Jenkinsfile](https://github.com/deB4SH/Docker-Manufactio/blob/master/Jenkinsfile) that provides everything to instruct my homelab
jenkins for building an deploying the image.

### Jenkinsfile

My homelab jenkins is set up with the [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/) that provides an easy interface to allocate dynamic agents inside my homelab for builds. Due to the
fact that we are going to build a docker image inside Jenkins we are going to need a Docker-In-Docker, in short **dind**, image. There are multiple available
on [dockerhub](https://hub.docker.com/search?q=dind&type=image). Some also provide maven out of the box. Inside this guide: my dind image that provides maven and a jdk is used. Found
here: (https://github.com/deB4SH/Docker-Maven-Dind)[https://github.com/deB4SH/Docker-Maven-Dind]

````Jenkinsfile
agent {
    kubernetes {
        yaml '''
        apiVersion: v1
        kind: Pod
        spec:
          containers:
          - name: maven
            image: ghcr.io/deb4sh/docker-maven-dind:3.8.2-jdk-11-17.12.0
            command:
            - sleep
            args:
            - 99999
            volumeMounts:
            - name: dockersock
              mountPath: /var/run/docker.sock
          volumes:
          - name: dockersock
            hostPath:
              path: /var/run/docker.sock
        '''
        defaultContainer 'maven'
    }
}
````

Jenkins is going to provision a maven container alongside the jnlp-container that is required by the jenkins for communication. To keep the container running we are going to let it sleep for a long
time.

Next up, we need to define the stages to build and push the image. This is also possible in one stage block. If desired everything could be merged into one.

_As personal sidenote: splitting tasks allows for structured control and decisions when to do certain tasks. e.g. we don't need to push every build in a multibranch pipeline, but want to build all
branches to check if there are any issues_

````Jenkinsfile
//stages to build and deploy
stages {
    stage ('check: prepare') {
        steps {
            sh '''
                mvn -version
                export MAVEN_OPTS="-Xmx1024m"
            '''
        }
    }
    stage('build image') {
        steps {
            sh 'mvn clean install -f pom.xml'
        }
    }
    stage('push image') {
        when {
            branch 'master'
        }
        steps {
            withCredentials([usernamePassword(credentialsId: 'docker-push-token', passwordVariable: 'pass', usernameVariable: 'user')]) {
                sh 'docker login ghcr.io -u $user -p $pass'
                sh 'mvn docker:push -f pom.xml'
            }
        }
    }
}
````

The first stage checks if maven is available in any version and sets an environment variable for MAVEN_OPTS. In this specific case: increasing the max ram amount for the build. This is optional and
could be removed. Second stage provides all steps required to build the image with maven. Last but not least, the third stages executes a docker login onto the github container registry to push to
image towards and also the command to push the image afterwards.

If everything works out in your Jenkins you should be greeted with a nice stage view after some runs.

![jenkins stage view](/assets/2021-09-08-Docker-Image-Manufactio/jenkins_stageview.PNG)

## Conclusion

After implementing all parts we are able to build an image, deploy it and also tag it. The image should be available over github in your container registry or in your local docker-engine for local
usage only. This image also works in a kubernetes environment where configuration-files are stored inside a configmap that get mounted into the running container. 

Happy mining!
