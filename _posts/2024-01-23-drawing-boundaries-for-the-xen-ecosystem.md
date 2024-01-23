---
layout: post
title: Drawing boundaries for the Xen ecosystem
date: 2024-01-23 13:01 +0800
cover-pic: "/assets/img/xen.png"
prerequisites: Hypervisor
tags:
---
The Xen ecosystem is quite ironic. It's main product is hypervisor
that cleanly separates hardware resources. However, when it comes to
the organization of it's ecosystem though, the lines between tools and
terminology are blurred and complicated. My post today is my
understanding and attempt to draw boundaries to help myself and other
beginners compartmentalize parts of the ecosystem. I will detail the 4
big components: Xen hypervisor, Xen-project, Xenserver and XAPI.

## Xen hypervisor
Xen is the name of a type-1 hypervisor (Bare metal) which gives
enables virtualization of multiple operating system to run on the
***same*** host machine. In the software stack, the Xen hypervisor can be
thought of as a custom kernel (excluding device drivers) which "shims"
in the functionality to separate and isolate the hardware. On top of
the hypervisor, there are regions known as "domains" which can be seen
as a container for each guest operating system. There is a special
domain called "dom0" aka the "Control domain" which holds contains a
Linux kernel that provides the device drivers for the host. It is a
privileged domain that is able to "talk" directly to the hypervisor
and instruct it to spin up or shutdown other guest operating
systems. The device drivers in dom0 are shared with the other guest
operating systems in their respective unprivileged domains, referred
to as "domU's".

The order in which the
components interface with one another are as follows:
``` text
            Guest OS_1, Guest OS_2, GuestOS_N... (domU's)
                        Control Domain (dom0)
                            Xen Hypervisor
                          Physical Hardware
```

## Xen-project
The Xen-project is a collection of open source projects hosted under
the ***Linux foundation***. It contains the hypervisor itself and
several sub-projects including: Windows PV driver, MirageOS, unikraft,
XAPI, XCP, etc.

#### Terminology: What is a Tool stack?
> A tool stack is a set of cooperating daemons that provide a
> higher-level interface to manage Xen hosts. It extends the base
> hypervisor to provides system management tools such as basic setup,
> configuration, etc.

## XAPI
XAPI refers to Xen-project default **tool stack** which includes basic
system management as well as functionality to remotely configuring and
controlling virtualised guests on hosts.

## Xenserver
An enterprise platform for orchestrating/managing Xen
virtualization. It packages the hypervisor, XAPI tool stack, custom
Linux kernel and other open source components (i.e. XenCenter ) to
provides a platform for large scale management. It can be thought of
as a "distro" because much of the work is about versioning and
integration of components. They also - like a distro, provide seamless
upstream patching for their users. It is being led by Citrix (now
acquired by Vista Equity Partners and Evergreen Coast Capital).

## Diagram
I think the relationship between these entities are best described
visually by these concentric circles.

![diagram](/assets/img/xen-diagram.png)

## Conclusion
In essence, we have the hypervisor which is the lowest level software
interacting with the hardware - providing the virtualization
capabilities. On top of that, XAPI is a collection of tools that
address system management of virtual machines using Xen. It includes
more than just a regular tool stack with remote management of Xen
hosts. The Xen-project is the overarching entity of open-source
projects around Xen including the hypervisor, XAPI and other tools
extending Xen. Finally Xenserver is an enterprise platform that builds
around XAPI and other tools with orchestration capabilities
Sysadmin-like user interface (XenCenter). The work being done around
Xenserver is "distro-like" in it's responsibilities of package
versioning and ensuring seamless integration between tools.
