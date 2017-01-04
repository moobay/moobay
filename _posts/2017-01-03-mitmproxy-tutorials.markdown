---
title: "中间人代理服务器MITMPROXY"
date: 2017-01-03T13:07:45+08:00
---

## mitmproxy简介

近期由于工作需要研究了一段时间网络代理，发现一个功能强大且免费的代理服务器命令行工具`mitmproxy`，使用起来也非常简单

```bash
mitmproxy -p 8888 --follow
```

通过一行简单的命令搭建好了一台代理服务器，其中`-p 8888`指定了代理主机服务端口，`--follow`是可选参数，表示代理服务器可以实时刷新日志，运行时界面是这样的

![](/assets/mitmproxy/01.png)
<!--more-->
在运行界面点击任意一条日志，可以查看经过相关`http`协议的包头以及包体，就好似抓包工具一般，见下图

`http`包头信息
![](/assets/mitmproxy/02.png)
`http`包体信息
![](/assets/mitmproxy/03.png)

当然了`mitmproxy`的作用并不只是代理服务器，`mitm`是"Man In The Middle"(中间人)的意思，事实上`mitmproxy`角色也就是中间人代理，可以对经过`mitmproxy`的`https`协议发起中间人攻击，使用**[中间人攻击](https://en.wikipedia.org/wiki/Man-in-the-middle_attack)**可以解码使用非对称加密的`https`协议内容。简单来说，所有经过`mitmproxy`代理服务器的`https`都可被明文查看，就好像查看`http`协议一样简单，见下图

![](/assets/mitmproxy/04.png)

被解码`https`协议包头
![](/assets/mitmproxy/05.png)
被解码`https`协议包体
![](/assets/mitmproxy/06.png)
被解码`https`协议通信证书信息
![](/assets/mitmproxy/07.png)

看到这里大家应该对`mitmproxy`的功能有一定的了解了，那么问题来了：什么情况下`mitmproxy`会抓到`http(s)`协议包？下面我就详细介绍两种`mitmproxy`抓包环境。

## 配置网络代理

既然`mitmproxy`是代理服务器，那么使用代理服务器最常见的方式：在网络偏好里面添加网络代理配置

macOS设置网络代理<br/> 
![](/assets/mitmproxy/net-01.png)

iOS设置网络代理<br/> 
![](/assets/mitmproxy/net-02.png)

这样配置了代理服务器IP端口的电脑以及各种移动设备，就可以被`mitmproxy`轻易抓到网络通信包。这种方式使用起来相对还是有点门槛，使用前必须设置网络代理，如果条件不允许该怎么办？

## WiFi网络自动代理

通过该方法，可以轻松抓取连接到特殊配置的WiFi热点上的所有设备，即便目标设备不支持代理，只要可以通过WiFi上网就可以被抓包。原理也很简单，就是把通过WiFi热点的网络包重定向到代理服务器IP端口，然后再通过`mitmproxy`抓包，值得说明的是这个抓包过程对于设备是不可见的，也就是说连接到这个WiFi的设备也无法感知代理服务器的存在。下面让我以macOS系统为例，来介绍具体的实现方法。

### 1. 创建共享WiFi网络

通过macOS创建WiFi网络很简单，只需要连接到互联网的网线或者一部iPhone手机即可，由于我的笔记本没有网线插槽，下面我就一iPhone为例创建无线网络，与网线创建无线网络大同小异。

#### - 打开"个人热点"开关

![](/assets/mitmproxy/net-03.png)

#### - 关闭笔记本WiFi，然后通过USB线把手机连接到笔记本

关闭笔记本WiFi<br/>
![](/assets/mitmproxy/net-05.png)

系统偏好设置多出`iPhone USB`网络服务
![](/assets/mitmproxy/net-04.png)

#### - 配置网络共享
下拉框选择`iPhone USB`，下面勾选`WiFi`选项

![](/assets/mitmproxy/net-07.png)

确认打开WiFi网络

![](/assets/mitmproxy/net-08.png)

确认启动网络共享服务

![](/assets/mitmproxy/net-09.png)

此时`WiFi`网络已经建立成功

![](/assets/mitmproxy/net-06.png)

### 2. 把WiFi网络数据包转发到代理服务器

#### - 激活系统网络转发功能

```
sysctl net.inet.ip.forwarding=1
sysctl net.inet6.ip6.forwarding=1
```

#### - 配置网络转发规则

```
echo "rdr pass on bridge100 inet proto tcp to port {443,80} -> 127.0.0.1 port 8888" | sudo pfctl -evf -
``` 

规则说明：共享`WiFi`网络`bridge100`上所有经由443(`https`)、80(`http`)端口的请求，转发到本机`127.0.0.1`端口`8888`，也就是`mitmproxy`代理服务部署的IP端口。


### 3. 启动mitmproxy代理服务器

```bash
sudo mitmproxy -p 8888 --follow --transparent
```

整体的网络环境是这样

![](/assets/mitmproxy/network.png)

[详情阅读文档&raquo;](http://docs.mitmproxy.org/en/stable/transparent/osx.html "http://docs.mitmproxy.org/en/stable/transparent/osx.html")

## 配合Wireshark解码https协议

在启动`mitmproxy`命令之前，执行

```
export SSLKEYLOGFILE=/Users/larryhou/Downloads/mitm.log
```

由于Chrome和Firefox等浏览器会默认使用`SSLKEYLOGFILE`环境变量，避免冲突可以使用`MITMPROXY_SSLKEYLOGFILE`替代

```
export MITMPROXY_SSLKEYLOGFILE=/Users/larryhou/Downloads/mitm.log
```

[详情阅读文档&raquo;](http://docs.mitmproxy.org/en/stable/dev/sslkeylogfile.html "http://docs.mitmproxy.org/en/stable/dev/sslkeylogfile.html")

`mitmproxy`会自动使用上述环境变量，然后把运行时`https`协议加密串写入环境变量指定的文件里面，内容大致如下

>CLIENT_RANDOM 586b666139a5361533026c178940c5ba305bbae877a1d2e4ef0cb376ce9bdf05 c70b6ede72b7386e2208a71ff3f951eeb172f9421aaf908ab878e047c7553c2cb02bf7de275f8630a3afb8f4077daedb<br/>
CLIENT_RANDOM 409dbd42acab433bafb91ed4a7c581ab38de8313632b4328799f196d6b4e2535 4140860c6d4415bbb92f3f769bf6546d18613386714769819979651f2e1cf381da13ba9a3f82afb1da0568db640703be<br/>
CLIENT_RANDOM 586b66e311f929898a38dbd08bd378d50537c7ffb63e622810bb251e7e7ff31c 511325c2dc870c65a4ecd27c427dfff9a20f30ec04ce5b123cdd2614c1b6c5d93f7500782381ea4b7c6db6de165acbc0<br/>
CLIENT_RANDOM 456dee030d0859e58bd83481462e2f00e201c2002ececdb18ada3a525d194ea0 1ab023d7d50a7113a838443196e521b5fa55debe9e225b84d303233865c2650f416d0ad277544427f0a404ae91362776<br/>

然后在Wireshark偏好设置里面配置，`Preferences`->`Protocols`->`SSL`->`(Pre)-Master-Secret`

![](/assets/mitmproxy/net-10.png)

在Wireshark里面查看被解码的[Wikipedia](https://en.wikipedia.org/wiki/Man-in-the-middle_attack "Man-in-the-middle_attack")网站数据
![](/assets/mitmproxy/net-11.png)

不过暂时`mitmproxy`有个bug：使用`sudo`启动后，无法正常写入`MITMPROXY_SSLKEYLOGFILE`加密串文件，希望未来版本可以修复这个问题。


## mitmproxy安装

```
brew install python3
sudo -H pip3 install mitmproxy
```