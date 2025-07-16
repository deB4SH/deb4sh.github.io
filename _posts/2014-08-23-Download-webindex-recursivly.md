---
layout: post
title: Download a web-index recursivly
date: 2014-08-23 00:00
categories:
- Development
tags:
- shell magic
- shell
- wget
- console
---

Hey there, my professor keeps all its data in a seperate webstorage. The easiest way to get the files is to view files over the webbrowser at a specific domain. As a lazy person who dont wants to download all lecture files its a way easier to download it via wget in a resursive usage. For not downloading the parent folders you need to ignore them just with a secound parameter. The whole webstorage is secured with an simple httpauth

wget -r --no-parent --http-user=USERNAME --http-password=PASSWORD URL

Thats it :)
