// swiftlint:disable force_cast
import Combine
import Foundation
@testable import SmileID
import XCTest

class MockServiceHeaderProvider: ServiceHeaderProvider {
    var expectedHeaders = [HTTPHeader(name: "", value: "")]

    func provide(request _: RestRequest) -> [HTTPHeader]? {
        expectedHeaders
    }
}

class MockURLSessionPublisher: URLSessionPublisher {
    var expectedData = Data()
    var expectedResponse = URLResponse()

    func send(
        request _: URLRequest
    ) -> AnyPublisher<(data: Data, response: URLResponse), URLError> {
        Result.Publisher((expectedData, expectedResponse))
            .eraseToAnyPublisher()
    }
}

class MockSmileIdentityService: SmileIDServiceable {
    func getValidDocuments(
        request: ProductsConfigRequest
    ) -> AnyPublisher<ValidDocumentsResponse, Error> {
        let response = ValidDocumentsResponse(validDocuments: [ValidDocument]())
        if MockHelper.shouldFail {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        } else {
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }

    func getServices() -> AnyPublisher<ServicesResponse, Error> {
        var response: ServicesResponse
        do {
            response = try ServicesResponse(
                bankCodes: [],
                hostedWeb: HostedWeb(from: JSONDecoder() as! Decoder)
            )
        } catch {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        }

        if MockHelper.shouldFail {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        } else {
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }

    func authenticate(request _: AuthenticationRequest) -> AnyPublisher<AuthenticationResponse, Error> {
        let params = PartnerParams(
            jobId: "jobid",
            userId: "userid",
            jobType: .enhancedKyc
        )
        let response = AuthenticationResponse(
            success: true,
            signature: "sig",
            timestamp: "time",
            partnerParams: params
        )
        if MockHelper.shouldFail {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        } else {
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }

    func prepUpload(request _: PrepUploadRequest) -> AnyPublisher<PrepUploadResponse, Error> {
        let response = PrepUploadResponse(
            code: "code",
            refId: "refid",
            uploadUrl: "",
            smileJobId: "8950"
        )
        if MockHelper.shouldFail {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        } else {
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }

    func upload(zip _: Data = Data(), to _: String = "") -> AnyPublisher<UploadResponse, Error> {
        let response = UploadResponse.response(data: Data())
        if MockHelper.shouldFail {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        } else {
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }

    func getJobStatus<T: JobResult>(
        request _: JobStatusRequest
    ) -> AnyPublisher<JobStatusResponse<T>, Error> {
        let response = try! JobStatusResponse<T>(from: JSONDecoder() as! Decoder)
        if MockHelper.shouldFail {
            return Fail(error: SmileIDError.request(URLError(.resourceUnavailable)))
                .eraseToAnyPublisher()
        } else {
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }

    func doEnhancedKycAsync(
        request _: EnhancedKycRequest
    ) -> AnyPublisher<EnhancedKycAsyncResponse, Error> {
        if MockHelper.shouldFail {
            let error = SmileIDError.request(URLError(.resourceUnavailable))
            return Fail(error: error)
                .eraseToAnyPublisher()
        } else {
            let response = EnhancedKycAsyncResponse(success: true)
            return Result.Publisher(response)
                .eraseToAnyPublisher()
        }
    }
}

class MockResultDelegate: SmartSelfieResultDelegate {
    var successExpectation: XCTestExpectation?
    var failureExpectation: XCTestExpectation?

    func didSucceed(
        selfieImage _: URL,
        livenessImages _: [URL],
        jobStatusResponse _: JobStatusResponse<SmartSelfieJobResult>
    ) {
        successExpectation?.fulfill()
    }

    func didError(error _: Error) {
        failureExpectation?.fulfill()
    }
}

enum MockHelper {
    static var shouldFail = false
    static var jobComplete = true
}
