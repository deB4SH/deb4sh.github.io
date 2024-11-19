---
layout: post
title: Exclude Robots from etherpad lite
date: 2014-08-07 00:00
categories:
- Selfhosted
- Development
tags: 
- etherpad 
- seo 
- javascript
---

Etherpad lite is easy to extend via npm install ep. While extending etherpad you need to keep in mind that there are some plugins which create new public sites that are crawable by google, bing and co. As example a beloved plugin by me (https://github.com/JohnMcLear/eplist_pads). It creates nice lists of all your pads, but it creates public searchable ids under /list and /public. To fix that is pretty easy. You need just to edit your robots.txt file under /static/robots.txt. You can find it under etherpad-light/src/static. Just add these two lines at the bottom of the file.

Disallow: /list Disallow: /public
