import Foundation

/**
 Constants for predefined socket tags.

 - note: All nagtive integers are reserved. Use positive integers for custom tags.
*/
struct SocketTag {
    static let Forward = 0

    // -2000
    struct HTTP {
        // HTTP read tag
        static let Header = -2101
        static let Content = -2102

        // HTTP write tag
        static let ConnectResponse = -2200
        static let RemoteContent = -2201
    }

    // -3000
    struct SOCKS5 {
        /**
        Client sends the hello information [0x05, 0x01, 0x00] to begin connect.
        */
        static let Open = -3000

        /**
        Client sends the connet information
        */
        static let ConnectInit = -3001

        /**
        Client sends the IPv4 address
        */
        static let ConnectIPv4 = -3002

        /**
        Client sends the IPv6 address
        */
        static let ConnectIPv6 = -3002

        /**
        Client sends the domain length
        */
        static let ConnectDomainLength = -3003

        /**
        Client sends the domain name
        */
        static let ConnectDomain = -3004

        /**
        Client sends the remote port
        */
        static let ConnectPort = -3005

        /**
        Server sends the response to the client hello
        */
        static let MethodResponse = -3100

        /**
        Server sends the information about the remote connection
        */
        static let ConnectResponse = -3101
    }

    // -10000
    static let tunnelTag = -10000
}
