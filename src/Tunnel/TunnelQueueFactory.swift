import Foundation

class TunnelQueueFactory {
    static let queue = DispatchQueue(label: "NEKit.TunnelQueue", attributes: [])

    static func getQueue() -> DispatchQueue {
        if Opt.shareDispatchQueue {
            return queue
        } else {
            return DispatchQueue(label: "NEKit.TunnelQueue", attributes: [])
        }
    }
}
