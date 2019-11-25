//
//  RxVerIDTests.swift
//  RxVerIDTests
//
//  Created by Jakub Dolejs on 21/11/2019.
//  Copyright © 2019 Applied Recognition Inc. All rights reserved.
//

import XCTest
import VerIDCore
import RxSwift
@testable import RxVerID

class RxVerIDTests: XCTestCase {
    
    private var rxVerID: RxVerID = RxVerID()
    
    override func setUp() {
        let detRecFactory = VerIDFaceDetectionRecognitionFactory(apiSecret: "87d19186bb9bcc5c3bfc29e0a4eb5366652ba003b35398e56bc9f8f429a4bf1b")
        rxVerID.faceDetectionFactory = detRecFactory
        rxVerID.faceRecognitionFactory = detRecFactory
        let userManagementFactory = VerIDUserManagementFactory(disableEncryption: true)
        rxVerID.userManagementFactory = userManagementFactory
    }
    
    // MARK: - Ver-ID creation
    
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

    // MARK: - Face detection
    
    func test_detectFaceInImageURL_returnOneFace() {
        let expectation = XCTestExpectation(description: "Detect face in image")
        guard let url = Bundle(for: type(of: self)).url(forResource: "test-images/jakub/Photo 04-05-2016, 18 57 50.png", withExtension: nil) else {
            XCTFail("Failed to read image")
            return
        }
        let disposable = rxVerID.detectFacesInImageURL(url, limit: 1).single().subscribe(onNext: { face in
            expectation.fulfill()
        }, onError: { error in
            expectation.fulfill()
            XCTFail(error.localizedDescription)
        }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_detectFaceInImageURL_failNoFace() {
        let expectation = XCTestExpectation(description: "Detect face in image")
        guard let url = Bundle(for: type(of: self)).url(forResource: "test-images/noface/IMG_6748.jpg", withExtension: nil) else {
            XCTFail("Failed to read image")
            return
        }
        let disposable = rxVerID.detectFacesInImageURL(url, limit: 1).single().subscribe(onNext: { face in
            expectation.fulfill()
            XCTFail("Detected face in an image without a face")
        }, onError: { error in
            expectation.fulfill()
        }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - Recognizable face detection
    
    func test_detectRecognizableFaceInImageURL_returnOneFace() {
        let expectation = XCTestExpectation(description: "Detect recognizable face in image")
        guard let url = Bundle(for: type(of: self)).url(forResource: "test-images/jakub/Photo 04-05-2016, 18 57 50.png", withExtension: nil) else {
            XCTFail("Failed to read image")
            return
        }
        let disposable = rxVerID.detectRecognizableFacesInImageURL(url, limit: 1).single().subscribe(onNext: { face in
            expectation.fulfill()
        }, onError: { error in
            expectation.fulfill()
            XCTFail(error.localizedDescription)
        }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_detectRecognizableFaceInImageURL_failNoFace() {
        let expectation = XCTestExpectation(description: "Detect recognizable face in image")
        guard let url = Bundle(for: type(of: self)).url(forResource: "test-images/noface/IMG_6748.jpg", withExtension: nil) else {
            XCTFail("Failed to read image")
            return
        }
        let disposable = rxVerID.detectRecognizableFacesInImageURL(url, limit: 1).single().subscribe(onNext: { face in
            expectation.fulfill()
            XCTFail("Detected face in an image without a face")
        }, onError: { error in
            expectation.fulfill()
        }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - User identification
    
    func test_identifyUsersInImageURL_returnsUser() {
        let expectation = XCTestExpectation(description: "Identify users in image")
        guard let registrationURL = Bundle(for: type(of: self)).url(forResource: "test-images/jakub/Photo 04-05-2016, 18 57 50.png", withExtension: nil) else {
            XCTFail("Failed to read registration image")
            return
        }
        guard let authenticationURL = Bundle(for: type(of: self)).url(forResource: "test-images/jakub/Photo 04-05-2016, 20 31 29.png", withExtension: nil) else {
            XCTFail("Failed to read authentication image")
            return
        }
        let userId = "test"
        let disposable = rxVerID.deleteUser(userId)
            .andThen(self.rxVerID.detectRecognizableFacesInImageURL(registrationURL, limit: 1))
            .single()
            .flatMap { face in
                self.rxVerID.assignFace(face, toUser: userId)
            }
            .asCompletable()
            .andThen(self.rxVerID.identifyUsersInImageURL(authenticationURL))
            .single()
            .flatMap { identification in
                return self.rxVerID.deleteUser(userId).andThen(Single<(String,Float)>.just(identification))
            }
            .subscribe(onNext: { (identifiedUser, score) in
                expectation.fulfill()
                XCTAssertEqual(userId, identifiedUser)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_identifyUsersInImageURL_returnsNobody() {
        let expectation = XCTestExpectation(description: "Identify users in image")
        guard let registrationURL = Bundle(for: type(of: self)).url(forResource: "test-images/jakub/Photo 04-05-2016, 18 57 50.png", withExtension: nil) else {
            XCTFail("Failed to read registration image")
            return
        }
        guard let authenticationURL = Bundle(for: type(of: self)).url(forResource: "test-images/don/IMG_20160502_133446.jpg", withExtension: nil) else {
            XCTFail("Failed to read authentication image")
            return
        }
        let userId = "test"
        let disposable = rxVerID.deleteUser(userId)
            .andThen(self.rxVerID.detectRecognizableFacesInImageURL(registrationURL, limit: 1))
            .single()
            .flatMap { face in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .asCompletable()
            .andThen(self.rxVerID.identifyUsersInImageURL(authenticationURL))
            .single()
            .flatMap { identification in
                return self.rxVerID.deleteUser(userId).andThen(Single<(String,Float)>.just(identification))
            }
            .subscribe(onNext: { (identifiedUser, score) in
                expectation.fulfill()
                XCTFail("Identified wrong user")
            }, onError: { error in
                expectation.fulfill()
            }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - Crop image to face
    
    func test_cropImageToFace_returnsCroppedImage() {
        let expectation = XCTestExpectation(description: "Crop image to face")
        guard let url = Bundle(for: type(of: self)).url(forResource: "test-images/jakub/Photo 04-05-2016, 18 57 50.png", withExtension: nil) else {
            XCTFail("Failed to read image")
            return
        }
        let disposable = rxVerID.detectFacesInImageURL(url, limit: 1)
            .single()
            .flatMap { face in
                return self.rxVerID.cropImageURL(url, toFace: face).map { image in
                    return (face, image)
                }
            }
            .subscribe(onNext: { (face, image) in
                expectation.fulfill()
                XCTAssertEqual(face.bounds.size.width, image.size.width, accuracy: 1.0)
                XCTAssertEqual(face.bounds.size.height, image.size.height, accuracy: 1.0)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - Face comparison
    
    func test_compareFaceToFace_returnsScore() {
        let expectation = XCTestExpectation(description: "Compare face to face")
        let disposable = self.testFaces(userId: 1).toArray()
            .flatMap { faces in
                return self.rxVerID.compareFace(faces.first!, toFaces: [faces.last!])
            }.subscribe(onSuccess: { score in
                expectation.fulfill()
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - User management
    
    func test_assignFaceToUser_succeeds() {
        let expectation = XCTestExpectation(description: "Assign face to user")
        let userId = "test"
        let disposable = self.testFaces(userId: 1)
            .flatMap { face in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .asCompletable()
            .andThen(self.rxVerID.users)
            .single { user in
                user == userId
            }
            .flatMap { user in
                return self.rxVerID.deleteUser(user)
            }
            .subscribe(onNext: nil, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            }, onCompleted: {
                expectation.fulfill()
            }, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_assignFacesToUser_succeeds() {
        let expectation = XCTestExpectation(description: "Assign face to user")
        let userId = "test"
        let disposable = self.testFaces(userId: 1).toArray().flatMapCompletable{ faces in
                return self.rxVerID.assignFaces(faces, toUser: userId)
            }
            .andThen(self.rxVerID.users)
            .single { user in
                user == userId
            }
            .flatMap { user in
                return self.rxVerID.deleteUser(user)
            }
            .subscribe(onNext: nil, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            }, onCompleted: {
                expectation.fulfill()
            }, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_deleteUser_succeeds() {
        let expectation = XCTestExpectation(description: "Delete user")
        let userId = "test"
        let disposable = self.testFaces(userId: 1).toArray().flatMapCompletable { faces in
                return self.rxVerID.assignFaces(faces, toUser: userId)
            }
            .andThen(self.rxVerID.users)
            .single { user in
                user == userId
            }
            .flatMap { user in
                return self.rxVerID.deleteUser(user)
            }
            .asCompletable()
            .andThen(self.rxVerID.users)
            .asMaybe()
            .subscribe(onSuccess: { user in
                expectation.fulfill()
                XCTFail("Users should be empty")
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            }, onCompleted: {
                expectation.fulfill()
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getUsers_returnsUsers() {
        let expectation = XCTestExpectation(description: "Get users")
        let userId = "test"
        var userNumber = 0
        let disposable = self.testFaces(userId: 1).flatMap { face -> Completable in
                userNumber += 1
                return self.rxVerID.assignFace(face, toUser: "\(userId)_\(userNumber)")
            }
            .ignoreElements()
            .andThen(self.rxVerID.users)
            .toArray()
            .asObservable()
            .flatMap { users -> Observable<String> in
                XCTAssertEqual(userNumber, users.count)
                return Observable<String>.from(users)
            }
            .flatMap { user in
                return self.rxVerID.deleteUser(user)
            }
            .ignoreElements()
            .subscribe(onCompleted: {
                expectation.fulfill()
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getFacesOfUser_returnsFaces() {
        let expectation = XCTestExpectation(description: "Get users")
        let userId = "test"
        var faceCount = 0
        let disposable = self.testFaces(userId: 1).flatMap { face -> Completable in
                faceCount += 1
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.rxVerID.facesOfUser(userId))
            .toArray()
            .subscribe(onSuccess: { faces in
                expectation.fulfill()
                XCTAssertEqual(faceCount, faces.count)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - User authentication
    
    func test_authenticateUserInFace_succeeds() {
        let expectation = XCTestExpectation(description: "Authenticate user")
        let userId = "test"
        let disposable = self.testFaces(userId: 1).take(1).single().flatMap { face -> Completable in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.testFaces(userId: 1).takeLast(1).single().flatMap { face in
                return self.rxVerID.authenticateUser(userId, inFace: face)
            })
            .single()
            .subscribe(onNext: { authenticated in
                expectation.fulfill()
                XCTAssertTrue(authenticated)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            }, onCompleted: nil, onDisposed: nil)
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_authenticateUserInImageURL_succeeds() {
        
    }
    
    // MARK: -
    
    func testFaces(userId: Int) -> Observable<RecognizableFace> {
        return Observable<RecognizableFace>.create { observer in
            do {
                let jsonDecoder = JSONDecoder()
                let faceResources: [String]
                switch userId {
                case 1:
                    faceResources = ["test-images/jakub/Photo 04-05-2016, 18 57 50.json", "test-images/jakub/Photo 04-05-2016, 20 31 29.json"]
                case 2:
                    faceResources = []
                default:
                    throw NSError(domain: kVerIDErrorDomain, code: 101, userInfo: [NSLocalizedDescriptionKey:"Invalid user ID \(userId)"])
                }
                let bundle = Bundle(for: type(of: self))
                for resource in faceResources {
                    guard let url = bundle.url(forResource: resource, withExtension: nil) else {
                        throw NSError(domain: kVerIDErrorDomain, code: 100, userInfo: [NSLocalizedDescriptionKey: "Failed to open url for resource \(resource)"])
                    }
                    let data = try Data(contentsOf: url)
                    let face = try jsonDecoder.decode(RecognizableFace.self, from: data)
                    observer.onNext(face)
                }
                observer.onCompleted()
            } catch {
                observer.onError(error)
            }
            return Disposables.create()
        }
    }
}
