import XCTest
@testable import DocuPass

final class DocupassCoreTests: XCTestCase {
    func testRegionEndpointResolution() {
        XCTAssertEqual(resolveDocupassEndpoint("EU-123"), DOCUPASS_API_ENDPOINT_EU)
        XCTAssertEqual(resolveDocupassEndpoint("us-123"), DOCUPASS_API_ENDPOINT_US)
        XCTAssertEqual(resolveDocupassEndpoint(nil), DOCUPASS_API_ENDPOINT_US)
    }

    func testAuthorizationProgressionInputs() async {
        let explicit = DocupassApiClient(config: .init(reference: "US-ref", authorization: "Bearer test"))
        let explicitHeader = await explicit.authorizationHeader()
        XCTAssertEqual(explicitHeader, "Bearer test")

        let party = DocupassApiClient(config: .init(reference: "US-ref", partyId: "party-1"))
        let partyHeader = await party.authorizationHeader()
        XCTAssertEqual(partyHeader, "DOCUPASS US-ref party-1")

        let session = DocupassApiClient(config: .init(reference: "US-ref", sessionId: "session-1"))
        let sessionHeader = await session.authorizationHeader()
        XCTAssertEqual(sessionHeader, "DOCUPASS_SESSION session-1")
    }

    func testWorkflowInsertsDocumentCapture() {
        let workflow = normalizeWorkflow([.selectCountry(), .selectDocument, .faceVerification([.turnLeft])])
        XCTAssertEqual(workflow, [.selectCountry(), .selectDocument, .captureDocument, .faceVerification([.turnLeft])])
    }

    func testFaceActionsAlwaysReturnTwoUniqueActions() {
        let actions = randomizedFaceActions([.turnLeft])
        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(Set(actions).count, 2)
        XCTAssertTrue(actions.contains(.turnLeft))
    }

    func testContractSignatureExtraction() {
        let html = #"<div data-signature data-uid='one' data-label='Customer'></div><img data-signature data-uid="two" data-party="B">"#
        let fields = extractContractSignatureFields(html)
        XCTAssertEqual(fields.map(\.uid), ["one", "two"])
        XCTAssertEqual(fields.first?.label, "Customer")
    }

    func testTerminalAndRecoveryErrorActions() {
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_COMPLETED", message: nil).action, .showCompleted)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_INVALID_ACTION", message: nil).action, .resyncSession)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_FATAL_ERROR", message: "LOCATION_HEADER_MISSING").action, .requestLocation)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_FACE_REJECTED", message: "FACE_MISMATCH").action, .retakeFace)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_DOCUMENT_REJECTED", message: "DOCUPASS_DOCUMENT_TYPE_MISMATCH").action, .retakeDocument)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_DOCUMENT_REJECTED", message: "NAME_VERIFICATION_FAILED").action, .retakeDocument)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_DOCUMENT_REJECTED", message: "UNDER_18").action, .showFailed)
        XCTAssertEqual(normalizeDocupassError(code: "DOCUPASS_FACE_REJECTED", message: "DOCUPASS_TOO_MANY_ATTEMPTS").action, .showFailed)
        XCTAssertEqual(normalizeDocupassError(code: "ERROR_INVALID_VALUE", message: "document").action, .retakeDocument)
        XCTAssertEqual(normalizeDocupassError(code: "ERROR_OPERATION_FAILED", message: "Invalid DocuPass mode.").action, .editInput)
        XCTAssertEqual(normalizeDocupassError(code: "ERROR_INTERNAL_ERROR", message: nil).action, .contactSupport)
        XCTAssertEqual(normalizeDocupassError(code: "ERROR_REQUEST_TOO_LARGE", message: nil).action, .retakeDocument)
    }
}
