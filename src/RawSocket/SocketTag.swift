import Foundation

/**
 Constants for predefined socket tags.

 - note: All nagtive integers are reserved. Use positive integers for custom tags.
*/
public struct SocketTag {
    public static let Forward = 0

    // -2000
    public struct HTTP {
        // HTTP read tag
        public static let Header = -2101
        public static let Content = -2102

        // HTTP write tag
        public static let ConnectResponse = -2200
        public static let RemoteContent = -2201
    }

    // -3000
    public struct SOCKS5 {
        /**
        Client sends the hello information [0x05, 0x01] to begin connect.
        */
        public static let Open = -3000

        public static let ConnectMethod = -3010

        /**
        Client sends the connet information
        */
        public static let ConnectInit = -3001

        /**
        Client sends the IPv4 address
        */
        public static let ConnectIPv4 = -3002

        /**
        Client sends the IPv6 address
        */
        public static let ConnectIPv6 = -3002

        /**
        Client sends the domain length
        */
        public static let ConnectDomainLength = -3003

        /**
        Client sends the domain name
        */
        public static let ConnectDomain = -3004

        /**
        Client sends the remote port
        */
        public static let ConnectPort = -3005

        /**
        Server sends the response to the client hello
        */
        public static let MethodResponse = -3100

        /**
        Server sends the information about the remote connection
        */
        public static let ConnectResponse = -3101
    }

    // -10000
    public static let tunnelTag = -10000
}
