---
title: Issues with Cubietruck / Cubieboard 3
date: 2014-07-01 00:00
comments: false
tags: 
- Cubietruck 
- Cubieboard 3
- Unix
- UnixIssues
---

Hey everyone, I am currently setting up my cubietruck to get my personal cloud running with owncloud and services like firefox sync to backup my browsing history. I ran into some stupid things caused by ubuntu.com behaviour with hosting sources for old distributions on ports.ubunut.com. Linaro for Cubietruck runs from start with Quantal Quetzal Ubuntu, what is fine. After setting up the system , my usual behavior is, to get the lasted updates and fixes but nothing happend just 404 errors from ubuntu.com. After checking things like connection error on IPv6 and other stupid things, I check back if there is still something up for quantal. Nope, nothing in there... What now? You just need to update your /etc/apt/source.list - I uploaded my new one to 2 hosts. phcn.de (http://paste.phcn.de/?i=1409570170) w8l.org (http://paste.w8l.org/kt82xg4erqo9)

After updating your souces just type into the console apt-get update apt-get -y dist-upgrade

The system-ugrade on cubietruck may take a while - for me it was around an half hour to an hour.

Hope this could help some new-commers :)

## Update: 09.01.2021

Seems that both paste-services removed the past entries. Therefor this log entry is just for history reasons still available. 