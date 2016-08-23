# Change Log
All notable changes to this project will be documented in this file.
I will do my best to guarantee that this project adheres to [Semantic Versioning](http://semver.org/) after 1.0.0, but please do read change log before updating.

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
- Many things in `HTTPHeader` and `ConnectRequest` become `public`.
- Refined `description` of many classes.

### Added
- The `RuleManager` now triggers events.


## [0.2.4]
### Changed
- The `ProxyServer.mainProxy` is removed and instead you should set the `proxyServer` in the implemention of `IPStackProtocol` (`TCPStack` as of now) which requires a proxy server to function.
- Many things are now `public` instead of `internal`.

### Added
- The proxy server, adapter socket, proxy socket and tunnel now trigger events.
- A build-in debug observer to help with debugging.

### Fixed
- Chacha20 and Salsa20 encryption are fixed.