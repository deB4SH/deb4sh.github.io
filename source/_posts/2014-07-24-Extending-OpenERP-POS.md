---
title: Extending the OpenERP POS Module
date: 2014-07-24 00:00
comments: false
tags:
- OpenERP
- OpenERP POS Module
- OpenERP Point of Sale
- javascript
---

I am currently active on developing and extending the openerp point of sale extension. Didn't get anything of mine extensions into it.. The problem? Openerp initialises all Javascript-Code after rendering the whole page and its running the user-generated code befor running its own code. I found a very small and smart way to work around this problem with a recursive timeout caller. The script is nice as easy to understand. :)

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
