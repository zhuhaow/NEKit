import Foundation

class QueueFactory {
    static let queue = DispatchQueue(label: "NEKit.ProcessingQueue")

    static func getQueue() -> DispatchQueue {
        return QueueFactory.queue
    }
}
