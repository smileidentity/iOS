import Combine
import Foundation

public protocol SmileIDServiceable {
    func authenticate(request: AuthenticationRequest) -> AnyPublisher<AuthenticationResponse, Error>
    func prepUpload(request: PrepUploadRequest) -> AnyPublisher<PrepUploadResponse, Error>
    func upload(zip: Data, to url: String) -> AnyPublisher<UploadResponse, Error>
    func getJobStatus<T: JobResult>(
        request: JobStatusRequest
    ) -> AnyPublisher<JobStatusResponse<T>, Error>
    func getServices() -> AnyPublisher<ServicesResponse, Error>

    /// Query the Identity Information of an individual using their ID number from a supported ID
    /// Type. Return the personal information of the individual found in the database of the ID
    /// authority. The final result is delivered to the url provided in the request's `callbackUrl`
    /// (which is required for this request)
    /// - Requires: The `callbackUrl` must be set on the `request`
    /// - Parameter request: The Enhanced KYC request
    /// - Returns: A response indicating whether the request was successfully submitted or not
    func doEnhancedKycAsync(
        request: EnhancedKycRequest
    ) -> AnyPublisher<EnhancedKycAsyncResponse, Error>

    /// Gets supported documents and metadata for Document Verification
    /// - Parameter request: request description
    /// - Returns: description
    func getValidDocuments(
        request: ProductsConfigRequest
    ) -> AnyPublisher<ValidDocumentsResponse, Error>
}

extension SmileIDServiceable {
    /// Polls the server for the status of a Job until it is complete. This should be called after
    /// the  Job has been submitted to the server. The returned flow will be updated with every job
    /// status response. The flow will complete when the job is complete, or the attempt limit is
    /// reached. If any exceptions occur, only the last one will be thrown. If there is a successful
    /// API response after an exception, the exception will be ignored.
    /// - Parameters:
    ///   - request: The JobStatus request to made
    ///   - interval: The time interval in seconds between each poll
    ///   - numAttempts: The maximum number of polls before ending the flow
    public func pollJobStatus<T: JobResult>(
        request: JobStatusRequest,
        interval: TimeInterval,
        numAttempts: Int
    ) -> AnyPublisher<JobStatusResponse<T>, Error> {

        var lastError: Error?
        var attemptCount = 0

        func makeRequest() -> AnyPublisher<JobStatusResponse<T>, Error> {
            attemptCount += 1

            return SmileID.api.getJobStatus(request: request)
                // swiftlint:disable force_cast
                .map { response in response as! JobStatusResponse<T> }
                // swiftlint:enable force_cast
                .flatMap { response -> AnyPublisher<JobStatusResponse<T>, Error> in
                    if response.jobComplete {
                        return Just(response).setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    } else if attemptCount < numAttempts {
                        return makeRequest()
                    } else {
                        return Fail(error: SmileIDError.jobStatusTimeOut).eraseToAnyPublisher()
                    }
                }
                .catch { error -> AnyPublisher<JobStatusResponse<T>, Error> in
                    lastError = error
                    if attemptCount < numAttempts {
                        return makeRequest()
                    } else {
                        return Fail(error: lastError ?? error).eraseToAnyPublisher()
                    }
                }
                .eraseToAnyPublisher()
        }

        return makeRequest()
    }
}

public class SmileIDService: SmileIDServiceable, ServiceRunnable {
    public func getServices() -> AnyPublisher<ServicesResponse, Error> {
        get(to: "services")
    }

    @Injected var serviceClient: RestServiceClient
    typealias PathType = String

    public func authenticate(
        request: AuthenticationRequest
    ) -> AnyPublisher<AuthenticationResponse, Error> {
        post(to: "auth_smile", with: request)
    }

    public func prepUpload(request: PrepUploadRequest) -> AnyPublisher<PrepUploadResponse, Error> {
        post(to: "upload", with: request)
    }

    public func upload(zip: Data, to url: String) -> AnyPublisher<UploadResponse, Error> {
        upload(data: zip, to: url, with: .put)
    }

    public func getJobStatus<T>(
        request: JobStatusRequest
    ) -> AnyPublisher<JobStatusResponse<T>, Error> {
        post(to: "job_status", with: request)
    }

    public func doEnhancedKycAsync(
        request: EnhancedKycRequest
    ) -> AnyPublisher<EnhancedKycAsyncResponse, Error> {
        post(to: "async_id_verification", with: request)
    }

    public func getValidDocuments(
        request: ProductsConfigRequest
    ) -> AnyPublisher<ValidDocumentsResponse, Error> {
        post(to: "valid_documents", with: request)
    }
}
