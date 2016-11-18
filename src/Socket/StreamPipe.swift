import Foundation

enum StreamPipeStatus {
    case processing, finished, errored
}

enum StreamNextAction {
    case stop, wait, remove, read, readLength(Int), readPattern(Data)
}

protocol StreamPipe {
    /// Processing the read stream
    ///
    /// - Parameters:
    ///   - data: The data to process.
    /// - Returns: The processed data; whether to pass it to the next pipe or send it out; next action to take.
    func inputStreamInput(data: Data) -> (Data?, Bool, StreamNextAction)

    func outputStreamInput(data: Data) -> (Data?, Bool)
}
