import Combine
import Foundation

protocol RestServiceClient {
    func send<T: Decodable>(request: RestRequest) -> AnyPublisher<T, Error>
    func multipart<T: Decodable>(request: RestRequest) -> AnyPublisher<T, Error>
    func upload(request: RestRequest) -> AnyPublisher<UploadResponse, Error>
}
