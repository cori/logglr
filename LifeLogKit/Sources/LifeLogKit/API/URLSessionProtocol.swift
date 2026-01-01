import Foundation

/// Protocol for URLSession to enable testing with mocks
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Make URLSession conform to the protocol
extension URLSession: URLSessionProtocol {}
