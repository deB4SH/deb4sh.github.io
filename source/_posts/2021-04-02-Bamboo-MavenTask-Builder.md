---
title: Building a Maven Task Builder for Bamboo
date: 2021-04-02 00:00
comments: false
tags:
- bamboo
- bamboo ci server
- ci
- cd
- maven
- java
---

When working with the Atlassian Bamboo CI Server it gets pretty quick annoying to setup a nice and readable build pipeline. Within my current project we're having multiple consecutive maven tasks that build, test, deploy parts of the application. 

### Source

```javascript
console.log("DEBUG-MSG: Runtime-Extender start");
var intervalholder = null;
intervalholder =  setInterval(function(){
    if(Object.keys(openerp.instances).length > 0){
        console.log("Found openerp.instance, load your plugins");
        openerpInstance = openerp.instances.instance0;
        //load here
        openerp.yourextension(openerpInstance);
        clearInterval(intervalholder);
        intervalholder = null;
    }
}, 1000) ;
openerp.yourextension = function(instance){
    var module = instance.pointofsale;
    //code here
}
```

nice and simple, mh? ;)
