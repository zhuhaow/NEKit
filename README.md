# NEKit

[![Build Status](https://travis-ci.org/zhuhaow/NEKit.svg?branch=master)](https://travis-ci.org/zhuhaow/NEKit)

A toolkit for Network Extension Framework.

NEKit is the successor of [Soca](https://github.com/zhuhaow/soca-ios). The design goal of NEKit is to provide everything needed in building a Network Extension app with TunnelProvider while keep the framework as non-opinionated as possible.

**NEKit does not depend on Network Extension framework. You can use NEKit without Network Extension entitlement to build a rule based proxy in a few lines.**

Currently, NEKit supports:

- Forward requests through different proxies based on remote host location, remote host domain or the connection speed of proxies.
- Integrated tun2socks framework to reassemble TCP packets into TCP flows.
- A DNS server that rewrites request and response.
- Some tools to build IP packets.
- ...

Check document [here](https://zhuhaow.github.io/NEKit), which is not finished yet.

Also, you may be more interested in [Potatso](https://github.com/shadowsocks/Potatso-iOS) if you just need a working app with GUI supporting shadowsocks.

## Principle

NEKit tries to be as flexible and non-opionated as possible. 

However, it is not always as modular as you may think if you want to reproduce transport layer from network layer.

NEKit follows one fundamental principle to keep the best network performance: The host connecting to target server resolves the domain. 

This should not be a problem if the applications on your device connect to the local proxy server directly, where we can get the request domain information then send that to remote proxy server if needed.

But think that if an application tries to make a socket connection by itself (e.g., Twitter.app), which generally consists of two steps: 

1. Make a DNS lookup to find the IP address of the target server.
2. Connect to the remote server by socket API provided by the system.

We can read only two independent things from the TUN interface, a UDP packet containing the DNS lookup request and a TCP flow consisting of a serial of TCP packets. So there is no way we can know the initial request domain for the TCP flow. And since there may be multiple domains served on the same host, we can not get the origin domain by save the DNS response and look that up reversely later.

The only solution is to create a fake IP pool and assign each requested domain with a unique fake IP so we can look that up reversely. Every connection later need to look that up from the DNS server; this is the only non-modular part of NEKit which is already encapsulated in `ConnectRequest`.

## Usage

### Add it to you project
I recommend adding this project to your project, which is easier to debug. 

However, you can still use it with Carthage by adding
```
github "zhuhaow/NEKit"
```
to you `Cartfile`.

### Overview
NEKit basically consists of two parts, a proxy server forwarding socket data based on user defined rules and an IP stack reassembling IP packets back to TCP flow as a socket.

### Rule manager
Before starting any proxy server, we need to define rules.

Each rule consists of two parts, one defining what kinding of request matches this rule and another defining what adapter to use. An adapter represents the abstraction of a socket connection to a remote proxy server (or connecting directly). We use `AdapterFactory` to build adapters.

```swift
// Define remote adapter first
let directAdapterFactory = DirectAdapterFactory()
let httpAdapterFactory = HTTPAdapterFactory(serverHost: "remote.http.proxy", serverPort: 3128, auth: nil)
let ssAdapterFactory = ShadowsocksAdapterFactory(serverHost: "remote.ss.proxy", serverPort: 7077, encryptMethod: "AES-256-CFB", password: "1234567890")

// Then create rules
let chinaRule = CountryRule(countryCode: "CN", match: true, adapterFactory: directAdapterFactory)
// `urls` are regular expressions
let listRule = try! ListRule(adapterFactory: ssAdapterFactory, urls: ["some\\.site\\.does\\.not\\.exists"])
let allRule = AllRule(adapterFactory: httpAdapterFactory)

// Create rule manager, rules will be matched in order.
let manager = RuleManager(fromRules: [listRule, chinaRule, allRule], appendDirect: true)

// Set this manager as the active manager
RuleManager.currentManager = ruleManager
```

There is also `Configuration` to load rules from a Yaml config file. But that is not recommended.


### Proxy server
Now we can start a proxy server locally.

```swift
let server = GCDSOCKS5ProxyServer(address: IPv4Address(fromString: "127.0.0.1"), port: Port(port: 9090)
// There can be multiple proxies running at the same time, but one of them must be set as the `mainProxy` to handle TCP socket from IP stack.
ProxyServer.mainProxy = server
try! ProxyServer.mainProxy.start()
```

Now there is a SOCKS5 proxy server running on `127.0.0.1:9090` which will forward requests based on rules defined in `RuleManager.currentManager`.

If you do not want to handle IP packets, then that's it, just set the proxy to `127.0.0.1:9090` in System Preferences and you are good to go.

If you want to read on, you will have to request Network Extention entitlement from Apple.

### IP stack

Assuming you already set up a working extension with correct routing configurations (Google how, this is not trivial).

In 

```swift
startTunnelWithOptions(options: [String : NSObject]?, completionHandler: (NSError?) -> Void)
``` 
set `RuleManager` and start proxy server(s) and then create an instance representing the TUN interface by

```swift
let stack = TUNInterface(packetFlow: packetFlow)
``` 

We also have to set

```swift
RawSocketFactory.TunnelProvider = self
```
to create socket to connect to remote servers with `NETunnelProvider`.

Then we need to register ip stacks implementing `IPStackProtocol` to process IP packets.

NEKit provides several stacks.

#### TCPStack
`TCPStack` process TCP packets and reassembles them back into TCP flows then send them to the `ProxyServer.mainProxy` server (Do not worry about the type of the proxy server, they will be handled as direct connection).

#### DNSServer
DNS server is implemented as an IP stack processing UDP packets send to it.

First create an DNS server with a fake IP pool. (You should use fake IP, but you can disable it if you want to by set it to nil.)

```swift
let fakeIPPool = IPv4Pool(start: IPv4Address(fromString: "172.169.1.0"), end: IPv4Address(fromString: "172.169.255.0"))
let dnsServer = DNSServer(address: IPv4Address(fromString: "172.169.0.1"), port: Port(port: 53), fakeIPPool: fakeIPPool)
```

Then we have to define how to resolve the DNS requests, NEKit provides the most trivial one which sends the request to remote DNS server directly with UDP protocol, you can do anything you want by implementing `DNSResolverProtocol`.

```swift
let resolver = UDPDNSResolver(address: IPv4Address(fromString: "114.114.114.114"), port: Port(port: 53))
dnsServer.registerResolver(resolver)
```

It is very important to set 

```swift 
DNSServer.currentServer = dnsServer
```
so we can look up the fake IP reversely.

#### UDPDirectStack
`UDPDirectStack` sends and reads UDP packets to and from remote server directly.


You can register these stack to TUN interface by

```swift
interface.registerStack(dnsServer)
// Note this sends out every UDP packets directly so this must comes after any other stack that processes UDP packets.
interface.registerStack(UDPDirectStack())
interface.registerStack(TCPStack.stack)
```

When everything is set up, you should start processing packets by calling `interface.start()` in the completion handler of `setTunnelNetworkSettings`.

## Dive in
TODO

## License
Copyright (c) 2016, Zhuhao Wang
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of NEKit nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
