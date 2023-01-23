---
title: Bamboo CI Server Environment Variable Inject
date: 2020-08-18 00:00
comments: false
tags:
- ci
- cd
- bamboo
- bamboo ci server
- bambo ci
- maven task bamboo
- script
- shell
---

Hi there! 

Due to a new project at work I got into a deep dive with the [bamboo build server](https://www.atlassian.com/de/software/bamboo) from atlassian. In around 4 months working as devops and ops engineer for the new project with bamboo, I came to the point that bamboo still needs a lot of work to be competetive with [jenkins](https://www.jenkins.io/) or something like gitlab-ci or github-ci. 

While developing the pipeline for releases, an issue came up that is quite difficult to resolve via bamboo. The issue was: exporting the version number of an branch and setting the maven version number aftwards based on that extracted number. Within jenkins I would extract the version number inside the relevant stage and inject it into the environment.
A snippet to do this task could look like the following

``` shell
stage('setVerion: release-branch') {
    when {
        branch 'release/*'
    }
    environment {
        BRANCHVERSION = sh(
                script: "echo ${env.BRANCH_NAME} | sed -E 's/release\\/([0-9a-zA-Z.\\-]+)/\\1/'",
                returnStdout: true
        ).trim()
    }
    steps {
        echo 'Setting release version'
        echo "${BRANCHVERSION}"
        sh 'mvn versions:set -DnewVersion=${BRANCHVERSION} -f ./pom.xml'
    }
}
```

Within the world of bamboo thats not that quite easy. 

## Solution

To achieve the same we need to split up the simple step into 4 parts. 

First we need a script to extract the version number and prepare it in some kind of file to inject it afterwards into the build context. Lets take a look into the following script example. 

``` shell
#!/usr/bin/env sh
currentBranch=$(echo $bamboo_planRepository_default_branchName)
if [[ $currentBranch == *"release/"* ]]; then
    export versionNumber=$(echo $currentBranch | sed -E 's/release\/([0-9a-zA-Z.\\-]+)/\1/')
else
  export versionNumber=$(echo "0.0.0-SNAPSHOT")
fi
echo "CONTAINER-VERSIONNUMBER: " $versionNumber
echo "Preparing versionnumber to inject into bamboo"
VALUE="versionNumber=$versionNumber"
echo $VALUE >> .version.cfg
echo "Created .version.cfg under the root directory"
```
Within this script we're using the provided bamboo variable for branchnames inside a multibranch pipeline. Extracting the version number if this is a *release* branch, else we're setting 0.0.0-SNAPSHOT as version number.
After extracting the versionnumber or setting a development number we are storing the information inside a cfg file that serves as temporary data storage to import data from.
With the following step we are going to import the data into the build context.

``` java
private Task exportBranchVersionNumber() {
    return new ScriptTask()
            .description("Exports the Branch-Version into an environment variable")
            .interpreterBinSh()
            .inlineBody("./version.sh");
}
```

```java
private InjectVariablesTask injectVersionnumberIntoBamboo(){
    return new InjectVariablesTask()
            .path(".version.cfg")
            .namespace("inject")
            .scope(InjectVariablesScope.LOCAL);
}
```

After injecting everything into the local scope of the current build context of the bamboo build server you easly can use the variables again over the reference schema. Just keep in mind that you need to add bamboo.inject infront to aquire the correct information.

The next step just shows how to use this in a real world example.

```java
private MavenTask changeVersion(){
    return new MavenTask()
            .description("Updates and changes the version number for all containers")
            .goal("versions:set -DnewVersion=${bamboo.inject.versionNumber} -f pom.xml -s settings.xml versions:update-child-modules")
            .hasTests(false)
            .version3()
            .jdk("JDK 1.8")
            .executableLabel("Maven-3.3.9");
}
```

## Conclusion

Bamboo needs a lot of scripting magic to get "well-known" pipeline steps running. Currently I am refining even more components of the global build file. Stay tuned for more bamboo guide in future.