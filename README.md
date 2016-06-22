# NEKit
A toolkit for NetworkExtension Framework

The design goal of NEKit is to provide everything needed in building a Network Extension app with TunnelProvider while keep the framework as non-opinionated as possible.

Currently, NEKit supports:
- Forward request through different proxies based on remote host location, remote host domain or the connection speed of proxies.
- Integrated tun2socks framework to support TUN interface.
- A DNS server that rewrites request and response.
- Some tools to build IP packets.
- ...

Check document [here](https://zhuhaow.github.io/NEKit), which is not finished yet.
