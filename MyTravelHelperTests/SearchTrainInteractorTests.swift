//
//  SearchTrainInteractorTests.swift
//  MyTravelHelperTests
//
//  Created by Ganesh on 5/5/21.
//  Copyright © 2021 Sample. All rights reserved.
//

import XCTest
import XMLParsing
@testable import MyTravelHelper

class SearchTrainInteractorTests: XCTestCase {
    
    var urlSessionSUT: URLSession!
    var networkMonitor: Reach!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        try super.setUpWithError()
        urlSessionSUT = URLSession(configuration: .default)
        networkMonitor = Reach()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        urlSessionSUT = nil
        networkMonitor = nil
        try super.tearDownWithError()
    }
    
    func testAPICallCompletion() throws {
        try XCTSkipUnless( networkMonitor.isNetworkReachable(),
                           "Network connectivity needed for this test.")
        // given
        let urlString = "http://api.irishrail.ie/realtime/realtime.asmx/getAllStationsXML"
//        let urlString = "http://api.irishrail.ie/realtime/realtime.asm"//x/getAllStationsXML"
        let promise = expectation(description: "Completion handler invoked")
        var statusCode: Int?
        var responseError: Error?

        // when
        SearchTrainInteractor.fetchDataUsing(urlString: urlString, urlSession: urlSessionSUT) { (_, response, error) in
            statusCode = (response as? HTTPURLResponse)?.statusCode
            responseError = error
            promise.fulfill()
        }

        wait(for: [promise], timeout: 5)

        // then
        XCTAssertNil(responseError)
        XCTAssertEqual(statusCode, 200)
    }
    
    func testFetchAllStation() throws {
        let stubbedData = loadStub(name: "allStations", ext: "xml")
        let urlString = "http://api.irishrail.ie/realtime/realtime.asmx/getAllStationsXML"
        let url = URL(string: urlString)!
        let stubbedResponse = HTTPURLResponse(
          url: url,
          statusCode: 200,
          httpVersion: nil,
          headerFields: nil)
        let urlSessionStub = URLSessionStub(
          data: stubbedData,
          response: stubbedResponse,
          error: nil)
        let promise = expectation(description: "Completion handler invoked")
        var statusCode: Int?
        var responseError: Error?
        var stationList: [Station]?
        
        // when
        SearchTrainInteractor.fetchDataUsing(urlString: urlString, urlSession: urlSessionStub) { (data, response, error) in
            statusCode = (response as? HTTPURLResponse)?.statusCode
            responseError = error
            if let _data = data {
                let station = try? XMLDecoder().decode(Stations.self, from: _data)
                stationList = station?.stationsList
            }
            promise.fulfill()
        }
        
        wait(for: [promise], timeout: 5)
        
        // then
        XCTAssertNil(responseError)
        XCTAssertEqual(statusCode, 200)
        XCTAssertNotNil(stationList, "Station list is not fetched")
    }
}

extension XCTestCase {
    func loadStub(name: String, ext: String) -> Data {
        // Obtain Reference to Bundle
        let bundle = Bundle(for: type(of: self))

        // Ask Bundle for URL of Stub
        let url = bundle.url(forResource: name, withExtension: ext)

        // Use URL to Create Data Object
        return try! Data(contentsOf: url!)
    }
}
