//
//  RxVerIDTests.swift
//  RxVerIDTests
//
//  Created by Jakub Dolejs on 21/11/2019.
//  Copyright © 2019 Applied Recognition Inc. All rights reserved.
//

import XCTest
import VerIDCore
@testable import RxVerID

class RxVerIDTests: XCTestCase {
    
    private var rxVerID: RxVerID = RxVerID()
    
    override func setUp() {
        let detRecFactory = VerIDFaceDetectionRecognitionFactory(apiSecret: "87d19186bb9bcc5c3bfc29e0a4eb5366652ba003b35398e56bc9f8f429a4bf1b")
        rxVerID.faceDetectionFactory = detRecFactory
        rxVerID.faceRecognitionFactory = detRecFactory
    }
    
    func test_createVerID_succeeds() {
        let expectation = XCTestExpectation(description: "Create Ver-ID")
        
        let disposable = rxVerID.verid.subscribe(onSuccess: { verid in
            expectation.fulfill()
        }, onError: { error in
            expectation.fulfill()
            XCTFail(error.localizedDescription)
        })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_createVerID_failsInvalidAPISecret() {
        let detRecFactory = VerIDFaceDetectionRecognitionFactory(apiSecret: "invalid")
        rxVerID.faceDetectionFactory = detRecFactory
        rxVerID.faceRecognitionFactory = detRecFactory
        
        let expectation = XCTestExpectation(description: "Create Ver-ID")
        
        let disposable = rxVerID.verid.subscribe(onSuccess: { verid in
            expectation.fulfill()
            XCTFail("Should fail: invalid API secret")
        }, onError: { error in
            expectation.fulfill()
        })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }

}
