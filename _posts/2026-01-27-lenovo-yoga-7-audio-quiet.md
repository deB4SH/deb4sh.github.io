---
layout: post
title: Notes for Lenovo Yoga 7 Audio Issues
date: 2026-01-27 00:00 
categories: 
- Note
tags:
- note
- writeup
---
Hi all,
new year new laptop, eh? 
Sadly yes. My old laptop, a huawei matebook d14 from 2020, broke. The keyboard wasn't working anymore. A replacement was kind of difficult and I failed repairing it. Nevertheless, I need a laptop so I bought a new one. There was a nice warehouse deal at a large retailer in my area and I'm now a proud owner of a Lenovo Yoga 7 with a new Ryzen 5 AI Chip. Windows 11 on this device was... an experience and firmly removed and replaced with linux. Everything went smoothly. Only one thing seems to be off. Sound. It was kindof muffled. Seems like a driver issue. Everything was working nice on windows regarding sound. Fortunately, I was not the first one with this issue and there are serveral helping links all over reddit. [This particular one](https://www.reddit.com/r/Fedora/comments/1n7lyno/lenovo_yoga_pro_7_14asp10_sound_issue/?show=original) helped the most. Only downside is that the audio input is now not working anymore and I couldn't any fix yet. To preserve the information also in this note: follow the steps down below to get all speakers working again.

I'll hope this will help someone with the same issue.

### Audio Fix

> **NOTE:** This will presumably disable the audio input on your laptop too. Keep that in mind when changing the configuration.

First step: Check for audio devices via aplay (cli for alsa soundcard drivers) with `aplay -l`. Your output may look like the following. 
```
root@node:~# aplay -l 
**** Liste der Hardware-Geräte (PLAYBACK) ****
Karte 0: Generic [HD-Audio Generic], Gerät 3: HDMI 0 [HDMI 0]
  Sub-Geräte: 1/1
  Sub-Gerät #0: subdevice #0
Karte 0: Generic [HD-Audio Generic], Gerät 7: HDMI 1 [HDMI 1]
  Sub-Geräte: 1/1
  Sub-Gerät #0: subdevice #0
Karte 0: Generic [HD-Audio Generic], Gerät 8: HDMI 2 [HDMI 2]
  Sub-Geräte: 1/1
  Sub-Gerät #0: subdevice #0
Karte 0: Generic [HD-Audio Generic], Gerät 9: HDMI 3 [HDMI 3]
  Sub-Geräte: 1/1
  Sub-Gerät #0: subdevice #0
Karte 1: Generic_1 [HD-Audio Generic], Gerät 0: ALC287 Analog [ALC287 Analog]
  Sub-Geräte: 0/1
  Sub-Gerät #0: subdevice #0
```
As you are able to see in my laptop the ALC287 is build in.

Second step: Add a configuration for your driver specific device with the following command. `sudo nano /etc/modprobe.d/alc287.conf`

Third step: Add the following content towards the newly created configuration file. `options snd-hda-intel model=(null),alc287-yoga9-bass-spk-pin`
There is also a nice [bugzilla](https://bugzilla.kernel.org/show_bug.cgi?id=208555#c674) kernel.org issue regarding this configuration.

Fourth step: Save the file and restart your host. 

