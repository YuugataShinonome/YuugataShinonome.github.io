---
title: NixOS介绍 
date: 2024-07-10 14:45:55
tags:
---

## NixOS到底是什么？

NixOS是一个基于Nix包管理器的发行版，具有“声明式配置”的特性，即一个系统的所有的配置，包括软件包、网络甚至是内核等，都通过一个单一的配置文件管理。
Nix配置文件使用Nix语言，下面是一个刚装好的NixOS的配置文件示例：
```nix
# /etc/nixos/configuration.nix
{ config, pkgs, ... }:

{
  # 使用的 NixOS 版本
  system.stateVersion = "23.05"; # 更改此处为实际的 NixOS 版本号

  # 主机名设置
  networking.hostName = "my-nixos-machine"; # 将此处替换为机器的实际名称

  # 启用 SSH 服务
  services.openssh.enable = true;

  # 设置系统时区
  time.timeZone = "Asia/Shanghai";

  # 启用 NTP 时间同步
  services.ntp.enable = true;

  # 启用 sound (ALSA sound system)
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # 指定显示管理器和桌面环境（如 GNOME）
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # 启用防火墙
  networking.firewall.enable = true;

  # 设置用户（可以根据需要自定义）
  users.users.myuser = {
    isNormalUser = true;
    description = "My User";
    extraGroups = [ "wheel" "audio" "video" ]; # 允许 sudo 和多媒体权限
    password = "password"; # 设置密码（建议使用 hashed 密码）
  };

  # 设置安装的软件包
  environment.systemPackages = with pkgs; [
    vim           # 文本编辑器
    git           # 版本控制
    wget          # 文件下载工具
    htop          # 系统监控工具
    firefox       # 浏览器
  ];

  # 启用开机自启动服务
  systemd.services.myservice = {
    description = "My Custom Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo Hello NixOS'";
    };
  };

  # 启用主机的 GRUB 引导程序
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.devices = [ "/dev/sda" ];

  # 启用日志记录
  systemd.services.journald = {
    description = "Persistent System Logs";
    serviceConfig.Persistent = "yes";
  };
}
```
而且，NixOS还是无状态的，即每次启动时系统都会恢复到由上面的配置文件所声明的状态（关于这一点是如何做到的下面再说）。
这种设计模式会带来一些革命性的优点：
1. 系统是可复现的，只要使用相同的配置文件，每台机器的系统都一模一样
2. 系统可以通过git进行管理，可以清晰的看到系统更改的历史，也可以多人协作维护系统
3. 永远不会把系统弄坏，改坏了直接回滚到上一个版本就好了

想象一下，若你有很多台机器，这些机器都需要一模一样的系统，那么只要在一个系统上修改然后把修改后的配置文件上传到Github上，
其他系统自动拉取更改并应用，那么维护瞬息就可以完成。而且利用git和Github，许多人可以共同维护一套有效的开源配置，
例如NixOS的[软件仓库](https://github.com/NixOS/nixpkgs)就是Github上的一个Nix语言代码合集而已。
而且，得益于可复现性，现在NixOS的软件仓库有世界上数量最多、最丰富的软件，因为每个开发者只要在自己的系统上能够测试成功，
那么在其他人的系统也一定能给复现，这样就消灭了软件随着规模增大而指数级增大的复杂性，因而能够以平稳的线性速度扩大系统规模。

正因为这些革命性的优点，NixOS才被许多人追捧。但是，NixOS真的只有优点而没有缺点吗？

## NixOS的原理与缺陷

NixOS彻底放弃了LFS，转而使用自己的文件系统结构。NixOS把所有文件存放在`/nix`目录下，而且这个目录一般是只读挂载的。
每个软件都通过描述其的代码的哈希值唯一确定。
假如软件A需要依赖D1和D2，那么就在构建时所有所需的文件只能存放在`/nix/D1-xxxx`和`/nix/D2-xxx`，
例如需要这两个目录下存放的库为文件为`/nix/D1-xxx/libd1.a`和`/nix/D2-xxx/libd2.a`，那么在构建的时候就需要写：`gcc -l/nix/D1-xxx/libd1.a -l/nix/D2-xxx/libd2.a`。
所以NixOS的软件必须在取得源代码的情况下构建。对于一些应用广泛的构建系统，例如CMake，有现成的函数可以使用；
但是对于一些构建方式比较奇怪的软件，那就是十分难受的。

还有一种软件是通过二进制发行的软件。这种软件所需要的动态库路径必须通过修改二进制文件的方式修改，若有些软件是检测修改的那更加麻烦。
这就导致有些软件很难打包。以vscode为例，由于vscode的很多插件会附带二进制文件，这些插件必须通过NixOS包管理器的方式安装。

关于NixOS特有的种类繁多的打包困难问题，可以参考[这篇文章](https://lantian.pub/article/modify-computer/nixos-packaging.lantian/)。


## 打包质量问题

Debian以卓越的软件质量著称，ArchLinux以总是提供最新的稳定版软件著称，那么NixOS的软件仓库的特点是什么呢？
NixOS的软件仓库分为滚动更新的unstable版和固定发行周期的稳定版。但是，稳定版也没有那么稳定。
打包是一项困难的任务，软件虽然多，但是若打包质量不好，不能达到服务器系统对于软件质量的要求，也难以广泛应用。
NixOS的软件还经常依赖同一个软件的不同版本，即使这些版本是兼容的，这就会导致所有的版本都必须存储在本地，
磁盘占用大大增加，这对于磁盘比较小的VPS或者嵌入式设备来说是很致命的。
而且，由于追求极致的声明式，很多手动hack的方法不被提倡，因此若要做一些例如增减编译参数之类的细致调整的话，就不得不自己修改源码。
实际上，对于很多NixOS的用户，修改现有的包以创建符合自己需求的包是常有的事。
这就导致另一个问题，那就是Nix语言本身。

## Nix语言

不同于C之类的过程式语言，Nix语言充斥着函数式设计思想，因为“无状态”这个概念很大程度就是来源于函数式编程语言。
许多不习惯这类语言的人，包括笔者，一开始也感到难以上手，需要花大量的时间去debug。
Nix语言在设计上比较追求简洁，换句话说，比较简陋，这就对程序员的代码抽象与复用水平提出了更高的要求。

## 难以追求纯粹的无状态

虽然NixOS一直在追求纯粹的无状态、声明式的环境，但由于软件本身的复杂性，这种理想状态总是难以达到。
典型的例子就是家目录和`/var`目录，这些目录下的大量脚本、配置文件和运行数据之类的不能通过声明式来解决，
不同系统之间的不可迁移的差异性仍然存在。
而且，对于很多任务，比如开发来说，运行一些手动构建或者下载的二进制文件是非常常见的任务，
这时NixOS不能直接运行二进制文件的特性反而是桎梏。
NixOS对此的解决方案是为开发任务创建一个单独的环境，但是这未免有些过于麻烦了。

## 替代的解决方案

容器化已经很大程度上能替代NixOS的角色。容器化能确保应用程序在每一台机器上都运行在一个确定、“干净”的环境里，
而且还能隔离CPU、网络等资源，容器化具有更大的灵活性。

## 总结

NixOS虽然带来了革命性的进步，解决了许多痛点，甚至被誉为“下一代发行版”，但是也有很多缺点。
笔者认为，NixOS最好用于大规模、成批量地部署同一系统，并通过细致的手工优化和配置来达到最稳定和最大效率。
至于开发用途、日常使用用途或少批量部署，我觉得传统发行版仍然难以代替。


