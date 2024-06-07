import Foundation
import Combine

public protocol URLUploadSessionPublisher {
    var delegate: URLDelegate { get }
    func upload(
        request: URLRequest,
        data: Data?,
        _ callback: @escaping (Data?, URLResponse?, Error?) -> Void
    )
}

class URLSessionRestServiceClient: NSObject, RestServiceClient {
    typealias URLSessionResponse = (data: Data, response: URLResponse)
    
    let session: URLSession
    let decoder = JSONDecoder()

    public init(
        session: URLSession = URLSession.shared
    ) {
        self.session = session
    }

    func send<T: Decodable>(request: RestRequest) async throws -> T {
        do {
            let urlRequest = try request.getURLRequest()
            let urlSessionResponse = try await session.send(request: urlRequest)
            let data = try checkStatusCode(urlSessionResponse)
            return try decoder.decode(T.self, from: data)
        } catch {
            throw mapToAPIError(error)
        }
    }

    public func upload(request: RestRequest) async throws -> AsyncThrowingStream<UploadResponse, Error> {
        AsyncThrowingStream<UploadResponse, Error> { continuation in
            do {
                let urlRequest = try request.getUploadRequest()
                let delegate = URLDelegate(continuation: continuation)
                let uploadSession2 = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
                uploadSession2.uploadTask(with: urlRequest, from: request.body) { data, response, error in
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    if (response as? HTTPURLResponse)?.statusCode == 200 {
                        continuation.yield(.response(data: data))
                    }
                }.resume()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }

    public func multipart<T: Decodable>(request: RestRequest) async throws -> T {
        do {
            let urlRequest = try request.getURLRequest()
            let urlSessionResponse = try await session.send(request: urlRequest)
            let data = try checkStatusCode(urlSessionResponse)
            return try decoder.decode(T.self, from: data)
        } catch {
            throw mapToAPIError(error)
        }
    }

    private func mapToAPIError(_ error: Error) -> SmileIDError {
        if let requestError = error as? URLError {
            return .request(requestError)
        } else if let decodingError = error as? DecodingError {
            return .decode(decodingError)
        } else if let error = error as? SmileIDError {
            return error
        } else {
            return .unknown(error.localizedDescription)
        }
    }

    private func checkStatusCode(_ urlSessionResponse: URLSessionResponse) throws -> Data {
        guard let httpResponse = urlSessionResponse.response as? HTTPURLResponse,
              httpResponse.isSuccess
        else {
            if let decodedError = try? JSONDecoder().decode(
                SmileIDErrorResponse.self,
                from: urlSessionResponse.data
            ) {
                throw SmileIDError.api(decodedError.code, decodedError.message)
            }
            throw SmileIDError.httpError((urlSessionResponse.response as? HTTPURLResponse)?.statusCode ?? 500, urlSessionResponse.data)
        }

        return urlSessionResponse.data
    }
}

extension HTTPURLResponse {
    var isSuccess: Bool {
        let successCodes = Array(200...299)
        return successCodes.contains(statusCode)
    }
}

public class URLDelegate: NSObject, URLSessionTaskDelegate {

    let continuation: AsyncThrowingStream<UploadResponse, Error>.Continuation
    
    public init(continuation: AsyncThrowingStream<UploadResponse, Error>.Continuation) {
        self.continuation = continuation
    }

    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        self.continuation.yield(.progress(percentage: task.progress.fractionCompleted))
    }
    
    deinit {
        continuation.finish()
    }
}

public enum UploadResponse: Equatable {
    case progress(percentage: Double)
    case response(data: Data?)
}
