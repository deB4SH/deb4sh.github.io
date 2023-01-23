---
title: DevOpsStory - Keep your local maven repository clear
date: 2021-04-21 00:00
comments: false
tags:
- devopsstory
- devops
- ops
- maven
- build infrastructure
- maven basics
---

Hi there!

Due to my current project I'm heavly in contact with an CI/CD infrastructure provided by an client. There is no downside with that, but it generates a massive security and build issue if something like the local maven-repository is shared between multiple build-nodes. The shared local repository opens up a lot of attack vectors for applications build on that same node, it also generates noise if someone tries to disturb your build. 

*Example Case*
Someone with malicious motives could install through mvn install a broken or wrong jar instead of the correct dependency you are expecting to receive.
This is easyly done through

```shell
mvn install:install-file –Dfile=my_dummy_app.jar -DgroupId=randomGroup.tld -DartifactId=awesomeArtifact -Dversion=1.0.0
```

Once the jar is in your local maven repository in place, maven doesn't redownload it in first place. It expects that you're doing the right thing.
Sooo= Clearing the maven cache is one way to be ahead of this. 

## Solution

Clearing the maven cache is a pretty easy task todo. There are two easy ways to remove it from your local environment or ci/cd environment.

### Remove the cache

Due to its file-based nature of the maven repository cache you can simply remove relevant data from it and you are good to go. In most cases the maven cache is configured by default in a *.m2* directory in your home or the executing user. 

Windows: C:\Users\YOUR_USERNAME\.m2
Linux: /home/YOUR_USERNAME/.m2

Keep in mind that dot-directories are hidden by default in many linux-derivates. After you've located your .m2 simply execute a remove command on it and the whole cache should be removed.

```shell
rm -rf .m2/
```

Inside a CI-environment with shared cache this may hurt other build-tasks, so a more lacy approach is needed. Simply head down the .m2 directory into the *repository* directory and remove components with caution. 

If you're using *clean install* it is a good task to clean up your build-artifacts after deploying them into an artifact directory. 

### Purge the cache through maven

An even simpler approach is purging the maven cache with maven. The dependency plugin provides a purge-local-repository function https://maven.apache.org/plugins/maven-dependency-plugin/examples/purging-local-repository.html

```shell
mvn dependency:purge-local-repository
```

Within the default setup of the dependency plugin it purges everything including transitive dependencies of your application. This would result in a complete redownload of all artifacts. With the parameter actTransitively this behaviour is deactivatable. 

```shell
mvn dependency:purge-local-repository -DactTransitively=false
```

After taking a look into two approaches how to remove artifacts from the local cache. How about take a look into changing the cache dir into something temporary?

## Solution Number Two

Most of our CI/CD infrastructures are build on top of containers (eg. docker container). An another approach would be redirecting your local maven repository inside the container. This wouldnt resolve the issue when working with ssh-workers/nodes that are persistent. 

```shell
mvn -Dmaven.repo.local=/tmp/mvn_repo clean install
```

The maven parameter *maven.repo.local* allows you to redirect the cache for the current maven call. 

## Conclusion

In short, we looked at three approaches to tackel the issue with shared maven cache repositories in your environments.
Based on my experience I often tend towards *Solution Number Two*, while writing down build steps. It fits most projects best and the overhead in traffic is often compensated through a local maven-mirror.