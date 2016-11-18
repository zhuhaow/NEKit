import Foundation

class SocketStreamProcesser {
    var pipes: [StreamPipe]
    var currentPipeIndex = 0

    var inputOpen = false

    init(pipes: [StreamPipe]) {
        assert(pipes.count > 0)

        self.pipes = pipes
    }

    /// Start processing the input and output stream.
    ///
    /// - Returns: The data to send to the output stream, the next action for the input stream.
    func start() -> (Data?, StreamNextAction) {

    }

    func outputStreamInput(data: Data) -> Data {

    }

    func inputStreamInput(data: Data) -> (Data?, StreamNextAction) {

    }
}
