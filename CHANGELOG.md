# Change Log
All notable changes to this project will be documented in this file.
I will do my best to guarantee that this project adheres to [Semantic Versioning](http://semver.org/) after 1.0.0, but please do read change log before updating.

## 0.15.0

### Changed
- MMDB no longer ships GeoLite2 database with the framework. Developer must set `database` in the `GeoIP` before using it.
- Update all dependencies to latest.

## 0.14.0

### Changed
- Migrate to Swift 5.
- Update all dependencies to latest.

## 0.13.1

### Fixed
- URL parser can parse domain with hyphen.

## 0.13.0

### Fixed
- Build on Xcode 10

## 0.12.7

### Fixed
- Make sure modification accesses are exclusive. Latest compiler (or swift runtime) enforces that.

## 0.12.6

### Fixed
- Update MMDB-Swift which fixes a potential error when downloading GeoIP database.

## 0.12.5

### Fixed
- Fix wrong access control level for `GCDProxyServer`.

## 0.12.4

### Fixed
- Fix that HTTPS adapter crash when using with `NWTCPSocket`.

## 0.12.3

### Fixed
- Unset delegate when deinit `NWTCPSocket`.
- Sending proper SNI information in SSL negotiation.
- Keep reference of observer in `Tunnel`.

### Changed
- Updated for Swift 4

## 0.12.2

### Fixed
- Update MMDB to fix that the database is not downloaded correcly.

## 0.12.1

### Changed
- The build-in GeoIP database will be updated automatically with every new release.

## 0.12.0

### Fixed
- Fix that the SOCKS adapter will send IP bytes in wrong order.

## 0.11.0

### Changed
- Courageous adventurers are never satisfied with the status quo. They are not only always prepared, but also desired to explore something new, something never happened before. Some of the bravest tried to let the Internet know thay were here, ready to chanllenge the law and order and put an end to the old, antiquated and decayed speficications. Well, they have been acknowledged. 
- A very tolerant parser will be used if the URL is illegal.
- **`ota: true` is obsolete, use the configuration of ShadowsocksR (`protocol: verify_sha1`) instead.**
- `IPv4Address` is removed. Now both IPv4 and IPv6 are represented by one class `IPAddress`.
- `IPPool` now supports both IPv4 and IPv6 addresses.
- Now there is an interval (see `Opt`) between each read, this should reduce the number of total system calls.

### Added
- Add support for `simple_http` and `tls1.2_ticket_auth` obfuscation for SSR.
- **`ota: true` is obsolete, use the configuration of ShadowsocksR (`obfs: verify_sha1`) instead.**

## 0.10.5

### Fixed
- Fix that `RejectAdapter` uses a wrong delay interval.

## 0.10.4

### Fixed
- Fix an error when parsing literal IP address.

## 0.10.3

### Fixed
- Fix that when the request is an IP address it will not be processed correctly.

### Changed
- Now `internalStatus` is changed to read and write status.

## 0.10.2

### Changed
- Set DNS timeout to 1 second.

## 0.10.1

### Fixed
- SOCKS5 proxy will work correctly when dealing with socket sending data first.

## 0.10.0

### Changed
- Now there is only one dispatch queue and it is guaranteed everything will be executed on that queue.

## 0.9.1

### Fixed
- Fix crash when OTA data block is too large.

## 0.9.0
### Changed
- `state` in `SocketProtocol` is changed to `status`.
- All interfaces relating to adapter, proxy and tunnel are refined according to the new Swift 3 convention.
- All data tags are removed, now information is saved in `internalStatus`.
- `SpeedAdapter` now signals observer with partial information.

## 0.8.1
### Changed
- Fix versions of dependecies.

## Unreleased
### Changed
- `ConnectRequest` is renamed to `ConnectSession`, `ConnectResponse` is removed.

## 0.8.0
### Changed
- Updated to Swift 3.
- `type` in `SocketProtocol` is changed to `typeName`.

### Fixed
- Now http header with empty value will be handled.
- Correctly generate key for shadowsocks.
- Correctly encrypt with chacha20 and salsa20.

### Added
- Now all tunnel can be run in the same serial dispatch queue, this means there is no need to limit the number of active tunnels anymore on iOS. Check out `Opt`.

## 0.7.3
### Changed
- `DirectAdapterSocket` and `SpeedAdapter` will disconnect when the request host is IPv6 address.
- GeoIP now also supports IPv6 address.
- It's possible to match to a domain exactly now in `DomainRuleList`.

### Fixed
- `NWTCPSocket` will not crash if `disconnect` is called before `connectTo`.
- Hashing of `IPv4Address` might overflow on 32bit machines.
- Error when parsing HTTP header with ":" in the value.

## 0.7.2
### Fixed
- HTTP server now gets host information from request url instead of Host field in header.

## [0.7.1]
### Fixed
- Correctly handle empty line in list files.
 
## [0.7.0]
### Added
- `DomainRuleList` can match domain based on prefix, suffix and keyword.

### Fixed
- Parse error when HTTP header contains non-ascii characters.

## [0.6.2]
### Added
- You can limit the number of active sockets in `GCDProxyServer` by setting `Opt.ProxyActiveSocketLimit`. But **DO USE WITH CAUTION**.

## [0.6.1]
### Fixed
- Fixed a bug when the http request has no header fields the parsing of the header fails.

## [0.6.0]
### Changed
- Updated to Swift 2.3.

## [0.5.4]
## Fixed
- Fixed a very edge case where `inet_ntoa` does not support multi-thread.

## [0.5.3]
## Fixed
- SOCKS5 proxy now can correctly process IPv6 requests. Thx yarshure.

## [0.5.2]
## Fixed
- SOCKS5 proxy correctly handles connections with IP address.

## [0.5.1]
## Added
- Now one can initailize a `Port` by an integer directly.

### Changed
- The interface of `Port` is refined.
- Now SOCKS5 proxy response with `BND.ADDR = 0x00, 0x00, 0x00, 0x00` and `BND.PORT = 0`.

### Fixed
- SOCKS5 proxy now handles client which supports more than one method.

## [0.5.0]
### Added
- Added test.
- Support for SOCKS5 adapter.

### Fixed
- Fixed a bug when `IPRange` handling IP range with `/32`.

## [0.4.2]
### Fixed
- GeoIP now returns `nil` if input is not a valid IP address, so it is distinguishable from a failed search. 

## [0.4.1]
### Fixed
- `ShadowsocksAdapter` works correctly with IP-based request now.
- `HTTPHeader` parses header incorrectly when the header is non-CONNECT with a non default(80) port.

### Changed
- Now all encryption methods are represented in uppercase.

## [0.4.0]
### Changed
- Many things are now exposed as `public`.
- Some meta-parameters can be set in `Opt`.

### Added
- Support to reject request.

## [0.3.1]
### Fixed
- A potential memory leakage if DNS response is lost in transmission.

## [0.3.0]
### Changed
- Proxy server can listen on port without specific IP address.
- IPv4Address will return `nil` when initialize with an invalid IP address string.
- `ListRule` is renamed to `DomainListRule`.

### Fixed
- DNS server will only process A queries and return others intact.

### Added
- Support for IP range list matching rule.

## [0.2.5]
### Changed
- Many things in `HTTPHeader` and `ConnectSession` become `public`.
- Refined `description` of many classes.

### Added
- The `RuleManager` now triggers events.


## [0.2.4]
### Changed
- The `ProxyServer.mainProxy` is removed and instead you should set the `proxyServer` in the implementation of `IPStackProtocol` (`TCPStack` as of now) which requires a proxy server to function.
- Many things are now `public` instead of `internal`.

### Added
- The proxy server, adapter socket, proxy socket and tunnel now trigger events.
- A build-in debug observer to help with debugging.

### Fixed
- Chacha20 and Salsa20 encryption are fixed.
