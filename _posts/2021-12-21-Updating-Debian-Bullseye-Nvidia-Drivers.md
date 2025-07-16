---
layout: post
title: Debian Bullseye - Update to latest nvidia drivers
date: 2021-12-21 00:00 
categories: 
- Linux
tags:
- gnulinux
- debian
- debian bulleye
- nvidia
- nvidia driver
---

Hi all, 
due to the awesome progress with proton and the integration in steam.. lets be honest... there is no need for Windows if you are not playing games that are competetiv nor secured via kernel-level anticheat. I'm also working most of my time with containers and kubernetes environments. Integrations of those two in windows are more or less not existing. Due to the wsl it gets better but it's not quite native yet. Switching to an open operating system was the next logical step in my mind sooo.. here we are. 

Due to the being of debian the packages are a bit dated and considered stable, which is fine for everyday software but not that amazing if you want to get your new gpu working. Debian is currently provinding on all branches a 470.x.y version for nvidia-driver, which is a bit dated. On date of writing this we are currently by 495.x.y.

With the following steps you can update your graphic card drivers from 470.x.y to 495.x.y. 
Keep in mind.. *READ BEFORE COPY PASTING*. 

## Download the latest drivers:

Downloading the latest is easiest via an existing browser and the unix driver archive of nvidia.
Simply head towards: https://www.nvidia.com/en-us/drivers/unix/ and checkout the latest feature branch version for your system. In most cases x86/amd64.

Store it somewhere you are able to remember. For example: /home/your_user/nvidia/NVIDIA-Linux-x86_64-495.46.run

## Uninstall existing drivers (if available)

Depending if this is a system you've already used and installed drivers from any debian repository uninstall them. If you keep them installed the kernel-modules are still available and loaded after an reboot, which makes installing the driver directly from nvidia  impossible.

````bash
apt-get remove --purge '^nvidia-.*'
````

## Preparing for reboot!

Next on the list: preparing the system for the reboot into the multi-user.target. 
To install the nvidia driver directly you need to setup serveral things.

Install headers for your current kernel, build-essentials, libglvnd-dev and pkg-config.

```bash
apt install linux-headers-$(uname -r) build-essential libglvnd-dev pkg-config
```

Also create, if not existing, a new file under */etc/modprobe.d/blacklist-nouveau.conf* with following content.
```bash
blacklist nouveau
options nouveau modeset=0
```
With this you are blacklisting nouveau drivers. 

Next we need to update kernel-initramfs.
```bash
update-initramfs -u
```

At last we need to setup the default target at boot and reboot the system.
```bash
systemctl set-default multi-user.target
reboot now
```

## Install Nvidia Drivers

After a reboot you should be greeted with login prompt. Enter your credentials.
Next head towards your created folder with the driver inside. Execute the following inside.

```bash
bash NVIDIA-Linux-x86_64-495.46.run
```

If executed properly, you should see and loading bar growing. After a short while your should be greeted with questions. 

* Install NVIDIA's 32-bit compatibility libraries?
* Would you like to run the nvidia-xconfig utility to automatically update your X configuration file so that the NVIDIA X driver will be used when you restart X? 

Both questions should be answered with yes. 

You should see a process bar that indicates the status of building your new kernel with the nvidia driver bundled. After it finished everything should be set up and ready to go.
You've installed the driver manually.

The last step is to return to an graphical interface after boot, which is acomplished by executing the following command.
```bash
systemctl set-default graphical.target
```

After an fresh reboot you should be greeted by your desktop environment / login interface.

You can check if the correct driver is running with `nvidia-smi`

```bash
/home/b4sh [core@debian] [13:55]
> nvidia-smi
Tue Dec 21 13:55:38 2021       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 495.46       Driver Version: 495.46       CUDA Version: 11.5     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce ...  Off  | 00000000:1C:00.0  On |                  N/A |
|  0%   46C    P0    41W / 260W |    962MiB /  7979MiB |      6%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+
```