//
//  RxVerIDTests.swift
//  RxVerIDTests
//
//  Created by Jakub Dolejs on 21/11/2019.
//  Copyright © 2019 Applied Recognition Inc. All rights reserved.
//

import XCTest
import VerIDCore
import VerIDSDKIdentity
import RxSwift
@testable import RxVerID

class RxVerIDTests: XCTestCase {
    
    private lazy var rxVerID: RxVerID = {
        if #available(iOS 10.3, *), let url = Bundle(for: type(of: self)).url(forResource: "Ver-ID identity", withExtension: "p12"), let identity = try? VerIDIdentity(url: url, password: self.veridPassword) {
            return RxVerID(identity: identity)
        } else {
            return RxVerID()
        }
    }()
    private let veridPassword = "98733049-92a7-4a98-9490-ab4035d8303b"
    
    static let imageURLs: [String:String] = [
        "j1": "https://ver-id.s3.us-east-1.amazonaws.com/test_images/jakub/Photo%2004-05-2016%2C%2018%2057%2050.jpg",
        "j2": "https://ver-id.s3.us-east-1.amazonaws.com/test_images/jakub/Photo%2004-05-2016%2C%2020%2031%2029.jpg",
        "noface1": "https://ver-id.s3.us-east-1.amazonaws.com/test_images/noface/IMG_6748.jpg",
        "m1": "https://ver-id.s3.us-east-1.amazonaws.com/test_images/marcin/Photo%2031-05-2016%2C%2015%2020%2026.jpg",
        "m2": "https://ver-id.s3.us-east-1.amazonaws.com/test_images/marcin/Photo%2031-05-2016%2C%2015%2021%2008.jpg"
    ]
    static var imageTempFiles: [String:URL] = [:]
    
    override class func setUp() {
        imageTempFiles = imageURLs.compactMapValues({
            guard let url = URL(string: $0) else {
                return nil
            }
            guard let imageData = try? Data(contentsOf: url) else {
                return nil
            }
            guard let tempFile = (try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true))?.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg") else {
                return nil
            }
            do {
                try imageData.write(to: tempFile)
                return tempFile
            } catch {
                return nil
            }
        })
    }
    
    override class func tearDown() {
        RxVerIDTests.imageTempFiles.forEach({
            try? FileManager.default.removeItem(at: $0.value)
        })
    }
    
    override func setUp() {
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
        if #available(iOS 10.3, *) {
            guard let url = Bundle(for: type(of: self)).url(forResource: "Ver-ID identity", withExtension: "p12") else {
                XCTFail("Identity file not found")
                return
            }
            XCTAssertThrowsError(try VerIDIdentity(url: url, password: "invalid"))
        } else {
            let invalidRxVerID = RxVerID()
            let detRecFactory = VerIDFaceDetectionRecognitionFactory(apiSecret: "invalid")
            invalidRxVerID.faceDetectionFactory = detRecFactory
            invalidRxVerID.faceRecognitionFactory = detRecFactory
            
            let expectation = XCTestExpectation(description: "Create Ver-ID")
            
            let disposable = invalidRxVerID.verid.subscribe(onSuccess: { verid in
                expectation.fulfill()
                XCTFail("Should fail: invalid API secret")
            }, onError: { error in
                expectation.fulfill()
            })
            wait(for: [expectation], timeout: 20.0)
            disposable.dispose()
        }
    }

    // MARK: - Face detection
    
    func test_detectFaceInImageURL_returnOneFace() {
        let expectation = XCTestExpectation(description: "Detect face in image")
        guard let url = RxVerIDTests.imageTempFiles["j1"] else {
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
        guard let url = RxVerIDTests.imageTempFiles["noface1"] else {
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
        guard let url = RxVerIDTests.imageTempFiles["j1"] else {
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
        guard let url = RxVerIDTests.imageTempFiles["noface1"] else {
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
        guard let registrationURL = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read registration image")
            return
        }
        guard let authenticationURL = RxVerIDTests.imageTempFiles["j2"] else {
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
        guard let registrationURL = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read registration image")
            return
        }
        guard let authenticationURL = RxVerIDTests.imageTempFiles["m1"] else {
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
        guard let url = RxVerIDTests.imageTempFiles["j1"] else {
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
        let disposable = self.facesOfUser(1).toArray()
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
        let disposable = self.facesOfUser(1)
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
        let disposable = self.facesOfUser(1).toArray().flatMapCompletable{ faces in
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
        let disposable = self.facesOfUser(1).toArray().flatMapCompletable { faces in
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
        let disposable = self.facesOfUser(1).flatMap { face -> Completable in
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
        let disposable = self.facesOfUser(1).flatMap { face -> Completable in
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
        let disposable = self.facesOfUser(1).take(1).single().flatMap { face -> Completable in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.facesOfUser(1).takeLast(1).single().flatMap { face in
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
        let expectation = XCTestExpectation(description: "Authenticate user")
        let userId = "test"
        let disposable = self.facesOfUser(1).take(1).single().flatMap { face -> Completable in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(Observable<String>.just("j2").compactMap { path in
                RxVerIDTests.imageTempFiles[path]
            })
            .flatMap { url in
                self.rxVerID.authenticateUser(userId, inImageURL: url)
            }
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
    
    func test_authenticateUserInFaces_failsWithOtherUser() {
        let expectation = XCTestExpectation(description: "Authenticate user")
        let userId = "test"
        let disposable = self.facesOfUser(1).take(1).single().flatMap { face -> Completable in
                self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.facesOfUser(2).toArray())
            .flatMap { faces in
                self.rxVerID.authenticateUser(userId, inFaces: faces)
            }
            .subscribe(onSuccess: { authenticated in
                expectation.fulfill()
                XCTAssertFalse(authenticated)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: - Session result parsing
    
    func test_getImageURLsFromSessionResult_returnsImageURLs() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imageURLsFromSessionResult(result)
            }
            .toArray()
            .subscribe(onSuccess: { urls in
                expectation.fulfill()
                XCTAssertFalse(urls.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getImageURLsWithNonExistentBearingFromSessionResult_returnsEmptyArray() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imageURLsFromSessionResult(result, bearing: .left)
            }
            .toArray()
            .subscribe(onSuccess: { urls in
                expectation.fulfill()
                XCTAssertTrue(urls.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getImageURLsWithStraightBearingFromSessionResult_returnsImageURLs() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imageURLsFromSessionResult(result, bearing: .straight)
            }
            .toArray()
            .subscribe(onSuccess: { urls in
                expectation.fulfill()
                XCTAssertFalse(urls.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getImagesFromSessionResult_returnsImages() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imagesFromSessionResult(result)
            }
            .toArray()
            .subscribe(onSuccess: { images in
                expectation.fulfill()
                XCTAssertFalse(images.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getCroppedFaceImagesFromSessionResult_returnsCroppedImages() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.croppedFaceImagesFromSessionResult(result)
            }
            .toArray()
            .subscribe(onSuccess: { images in
                expectation.fulfill()
                XCTAssertFalse(images.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getFacesFromSessionResult_returnsFaces() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.facesFromSessionResult(result)
            }
            .toArray()
            .subscribe(onSuccess: { faces in
                expectation.fulfill()
                XCTAssertFalse(faces.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getRecognizableFacesFromSessionResult_returnsFaces() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.facesFromSessionResult(result)
            }
            .toArray()
            .subscribe(onSuccess: { faces in
                expectation.fulfill()
                XCTAssertFalse(faces.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    func test_getFacesAndImagesFromSessionResult_returnsArray() {
        let expectation = XCTestExpectation()
        let disposable = self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.facesAndImagesFromSessionResult(result)
            }
            .toArray()
            .subscribe(onSuccess: { faces in
                expectation.fulfill()
                XCTAssertFalse(faces.isEmpty)
            }, onError: { error in
                expectation.fulfill()
                XCTFail(error.localizedDescription)
            })
        wait(for: [expectation], timeout: 20.0)
        disposable.dispose()
    }
    
    // MARK: -
    
    func facesOfUser(_ userId: Int) -> Observable<RecognizableFace> {
        return Observable<RecognizableFace>.create { observer in
            do {
                let jsonDecoder = JSONDecoder()
                let faceResources: [String]
                switch userId {
                case 1:
                    faceResources = ["faces/Photo 04-05-2016, 18 57 50.json", "faces/Photo 04-05-2016, 20 31 29.json"]
                case 2:
                    faceResources = ["faces/Photo 31-05-2016, 15 21 08.json", "faces/Photo 31-05-2016, 15 20 26.json"]
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
    
    func sessionResult() -> Single<VerIDSessionResult> {
        let paths: [String] = ["m1","m2"]
        return Observable<String>.from(paths)
            .compactMap { path in
                RxVerIDTests.imageTempFiles[path]
            }
            .flatMap { url in
                self.rxVerID.detectRecognizableFacesInImageURL(url, limit: 1).map { face in
                    DetectedFace(face: face, bearing: .straight, imageURL: url)
                }
            }
            .toArray()
            .map { attachments in
                return VerIDSessionResult(attachments: attachments)
            }
    }
    
//    func test_facesToJson() {
//        let expectation = XCTestExpectation()
//        let paths: [String] = ["test-images/marcin/Photo 31-05-2016, 15 20 26.jpg","test-images/marcin/Photo 31-05-2016, 15 21 08.jpg","test-images/jakub/Photo 04-05-2016, 18 57 50.jpg", "test-images/jakub/Photo 04-05-2016, 20 31 29.jpg"]
//        let jsonEncoder = JSONEncoder()
//        let bundle = Bundle(for: type(of: self))
//        let disposable = Observable<String>.from(paths)
//            .compactMap { path in
//                bundle.url(forResource: path, withExtension: nil)
//            }.flatMap { url in
//                self.rxVerID.detectRecognizableFacesInImageURL(url, limit: 1).map { face -> XCTAttachment in
//                    let json = try jsonEncoder.encode(face)
//                    let attachment = XCTAttachment(data: json)
//                    attachment.name = url.deletingPathExtension().lastPathComponent+".json"
//                    attachment.lifetime = .keepAlways
//                    return attachment
//                }
//            }.subscribe(onNext: { attachment in
//                self.add(attachment)
//                expectation.fulfill()
//            }, onError: { error in
//                expectation.fulfill()
//                XCTFail(error.localizedDescription)
//            }, onCompleted: nil, onDisposed: nil)
//        wait(for: [expectation], timeout: 20.0)
//        disposable.dispose()
//    }
}
