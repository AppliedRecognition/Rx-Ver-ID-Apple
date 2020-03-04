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
import RxBlocking
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
        XCTAssertNoThrow(try rxVerID.verid.toBlocking().single())
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
            XCTAssertThrowsError(try invalidRxVerID.verid.toBlocking().single())
        }
    }

    // MARK: - Face detection
    
    func test_detectFaceInImageURL_returnOneFace() {
        guard let url = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read image")
            return
        }
        XCTAssertNoThrow(try rxVerID.detectFacesInImageURL(url, limit: 1).toBlocking().single())
    }
    
    func test_detectFaceInImageURL_failNoFace() {
        guard let url = RxVerIDTests.imageTempFiles["noface1"] else {
            XCTFail("Failed to read image")
            return
        }
        XCTAssertThrowsError(try rxVerID.detectFacesInImageURL(url, limit: 1).toBlocking().single())
    }
    
    // MARK: - Recognizable face detection
    
    func test_detectRecognizableFaceInImageURL_returnOneFace() {
        guard let url = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read image")
            return
        }
        XCTAssertNoThrow(try rxVerID.detectRecognizableFacesInImageURL(url, limit: 1).toBlocking().single())
    }
    
    func test_detectRecognizableFaceInImageURL_failNoFace() {
        guard let url = RxVerIDTests.imageTempFiles["noface1"] else {
            XCTFail("Failed to read image")
            return
        }
        XCTAssertThrowsError(try rxVerID.detectRecognizableFacesInImageURL(url, limit: 1).toBlocking().single())
    }
    
    // MARK: - User identification
    
    func test_identifyUsersInImageURL_returnsUser() {
        guard let registrationURL = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read registration image")
            return
        }
        guard let authenticationURL = RxVerIDTests.imageTempFiles["j2"] else {
            XCTFail("Failed to read authentication image")
            return
        }
        let userId = "test"
        XCTAssertEqual(try rxVerID.deleteUser(userId)
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
            }.toBlocking().single().0, userId)
    }
    
    func test_identifyUsersInImageURL_returnsNobody() {
        guard let registrationURL = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read registration image")
            return
        }
        guard let authenticationURL = RxVerIDTests.imageTempFiles["m1"] else {
            XCTFail("Failed to read authentication image")
            return
        }
        let userId = "test"
        XCTAssertThrowsError(try rxVerID.deleteUser(userId)
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
            }.toBlocking().single())
    }
    
    // MARK: - Crop image to face
    
    func test_cropImageToFace_returnsCroppedImage() {
        guard let url = RxVerIDTests.imageTempFiles["j1"] else {
            XCTFail("Failed to read image")
            return
        }
        do {
            let (face, image) = try rxVerID.detectFacesInImageURL(url, limit: 1)
                .single()
                .flatMap { face in
                    return self.rxVerID.cropImageURL(url, toFace: face).map { image in
                        return (face, image)
                    }
                }.toBlocking().single()
            XCTAssertEqual(face.bounds.size.width, image.size.width, accuracy: 1.0)
            XCTAssertEqual(face.bounds.size.height, image.size.height, accuracy: 1.0)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    // MARK: - Face comparison
    
    func test_compareFaceToFace_returnsScore() {
        XCTAssertNoThrow(try self.facesOfUser(1).toArray()
            .flatMap { faces in
                return self.rxVerID.compareFace(faces.first!, toFaces: [faces.last!])
            }.toBlocking().single())
    }
    
    // MARK: - User management
    
    func test_assignFaceToUser_succeeds() {
        let userId = "test"
        XCTAssertNoThrow(try self.facesOfUser(1)
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
            }.toBlocking().first())
    }
    
    func test_assignFacesToUser_succeeds() {
        let userId = "test"
        XCTAssertNoThrow(try self.facesOfUser(1).toArray().flatMapCompletable{ faces in
                return self.rxVerID.assignFaces(faces, toUser: userId)
            }
            .andThen(self.rxVerID.users)
            .single { user in
                user == userId
            }
            .flatMap { user in
                return self.rxVerID.deleteUser(user)
            }.toBlocking().first())
    }
    
    func test_deleteUser_succeeds() {
        let userId = "test"
        XCTAssertNil(try self.facesOfUser(1).toArray().flatMapCompletable { faces in
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
            .toBlocking().first())
    }
    
    func test_getUsers_returnsUsers() {
        let userId = "test"
        var userNumber = 0
        XCTAssertNoThrow(try self.facesOfUser(1).flatMap { face -> Completable in
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
            .toBlocking()
            .first())
    }
    
    func test_getFacesOfUser_returnsFaces() {
        let userId = "test"
        var faceCount = 0
        XCTAssertEqual(try self.facesOfUser(1).flatMap { face -> Completable in
                faceCount += 1
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.rxVerID.facesOfUser(userId))
            .toArray()
            .toBlocking().single().count, faceCount)
    }
    
    // MARK: - User authentication
    
    func test_authenticateUserInFace_succeeds() {
        let userId = "test"
        XCTAssertTrue(try self.facesOfUser(1).take(1).single().flatMap { face -> Completable in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.facesOfUser(1).takeLast(1).single().flatMap { face in
                return self.rxVerID.authenticateUser(userId, inFace: face)
            })
            .toBlocking()
            .single())
    }
    
    func test_authenticateUserInImageURL_succeeds() {
        let userId = "test"
        XCTAssertTrue(try self.facesOfUser(1).take(1).single().flatMap { face -> Completable in
                return self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(Observable<String>.just("j2").compactMap { path in
                RxVerIDTests.imageTempFiles[path]
            })
            .flatMap { url in
                self.rxVerID.authenticateUser(userId, inImageURL: url)
            }
            .toBlocking().single())
    }
    
    func test_authenticateUserInFaces_failsWithOtherUser() {
        let userId = "test"
        XCTAssertFalse(try self.facesOfUser(1).take(1).single().flatMap { face -> Completable in
                self.rxVerID.assignFace(face, toUser: userId)
            }
            .ignoreElements()
            .andThen(self.facesOfUser(2).toArray())
            .flatMap { faces in
                self.rxVerID.authenticateUser(userId, inFaces: faces)
            }
            .toBlocking().single())
    }
    
    // MARK: - Session result parsing
    
    func test_getImageURLsFromSessionResult_returnsImageURLs() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imageURLsFromSessionResult(result)
            }
            .toArray()
            .toBlocking().single().isEmpty)
    }
    
    func test_getImageURLsWithNonExistentBearingFromSessionResult_returnsEmptyArray() {
        XCTAssertTrue(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imageURLsFromSessionResult(result, bearing: .left)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
    }
    
    func test_getImageURLsWithStraightBearingFromSessionResult_returnsImageURLs() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imageURLsFromSessionResult(result, bearing: .straight)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
    }
    
    func test_getImagesFromSessionResult_returnsImages() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.imagesFromSessionResult(result)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
    }
    
    func test_getCroppedFaceImagesFromSessionResult_returnsCroppedImages() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.croppedFaceImagesFromSessionResult(result)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
    }
    
    func test_getFacesFromSessionResult_returnsFaces() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.facesFromSessionResult(result)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
    }
    
    func test_getRecognizableFacesFromSessionResult_returnsFaces() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.facesFromSessionResult(result)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
    }
    
    func test_getFacesAndImagesFromSessionResult_returnsArray() {
        XCTAssertFalse(try self.sessionResult()
            .asObservable()
            .flatMap { result in
                self.rxVerID.facesAndImagesFromSessionResult(result)
            }
            .toArray()
            .toBlocking()
            .single().isEmpty)
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
