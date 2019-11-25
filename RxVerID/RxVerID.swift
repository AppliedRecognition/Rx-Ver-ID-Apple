//
//  RxVerID.swift
//  RxVerID
//
//  Created by Jakub Dolejs on 23/10/2019.
//  Copyright © 2019 Applied Recognition. All rights reserved.
//

import UIKit
import VerIDCore
import VerIDUI
import RxSwift

/// Reactive implementation of common Ver-ID tasks
public class RxVerID: VerIDSessionDelegate {
    
    private var sessionObservers: [VerIDSession:(MaybeEvent<VerIDSessionResult>) -> Void] = [:]
    private var veridInstance: VerID?
    private let veridSemaphore = DispatchSemaphore(value: 1)
    
    /// Initializer
    /// - Since: 1.0.0
    public init() {
        let detectionRecognitionFactory = VerIDFaceDetectionRecognitionFactory(apiSecret: nil)
        self.faceDetectionFactory = detectionRecognitionFactory
        self.faceRecognitionFactory = detectionRecognitionFactory
        self.userManagementFactory = VerIDUserManagementFactory()
    }
    
    // MARK: - Ver-ID instance
    
    /// Create Ver-ID instance
    /// - Since: 1.0.0
    public var verid: Single<VerID> {
        return Single.create { single in
            self.veridSemaphore.wait()
            if let verid = self.veridInstance {
                self.veridSemaphore.signal()
                single(.success(verid))
            } else {
                let factory = VerIDFactory()
                factory.faceDetectionFactory = self.faceDetectionFactory
                factory.faceRecognitionFactory = self.faceRecognitionFactory
                factory.userManagementFactory = self.userManagementFactory
                do {
                    let verid = try factory.createVerIDSync()
                    self.veridInstance = verid
                    self.veridSemaphore.signal()
                    single(.success(verid))
                } catch {
                    self.veridSemaphore.signal()
                    single(.error(error))
                }
            }
            return Disposables.create()
        }
    }
    
    /// Face detection factory
    /// - Since: 1.0.0
    public var faceDetectionFactory: FaceDetectionFactory {
        willSet {
            self.veridSemaphore.wait()
            self.veridInstance = nil
            self.veridSemaphore.signal()
        }
    }
    
    /// Face recognition factory
    /// - Since: 1.0.0
    public var faceRecognitionFactory: FaceRecognitionFactory {
        willSet {
            self.veridSemaphore.wait()
            self.veridInstance = nil
            self.veridSemaphore.signal()
        }
    }
    
    /// User management factory
    /// - Since: 1.0.0
    public var userManagementFactory: UserManagementFactory {
        willSet {
            self.veridSemaphore.wait()
            self.veridInstance = nil
            self.veridSemaphore.signal()
        }
    }
    
    // MARK: - Image conversion
    
    /// Create VerIDImage from an image from the given URL
    /// - Parameter url: Image URL
    /// - Returns: Ver-ID image
    /// - Since: 1.0.0
    public func veridImageFromURL(_ url: URL) -> Single<VerIDImage> {
        return Single.create { single in
            if let image = VerIDImage(url: url) {
                single(.success(image))
            } else {
                single(.error(VerIDImageWriterServiceError.imageEncodingError))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Face detection
    
    /// Detect faces in image URL
    /// - Parameters:
    ///   - url: Image URL
    ///   - limit: Maximum number of faces to detect
    /// - Returns: Observable whose elements are faces
    /// - Since: 1.0.0
    public func detectFacesInImageURL(_ url: URL, limit: Int) -> Observable<Face> {
        return self.veridImageFromURL(url).asObservable().flatMap { image in
            return self.detectFacesInImage(image, limit: limit)
        }
    }
    
    /// Detect faces in Ver-ID image
    /// - Parameters:
    ///   - image: Image
    ///   - limit: Maximum number of faces to detect
    /// - Returns: Observable whose elements are faces
    /// - Since: 1.0.0
    public func detectFacesInImage(_ image: VerIDImage, limit: Int) -> Observable<Face> {
        return self.verid.asObservable().flatMap { verid in
            return Observable<Face>.create { observer in
                do {
                    let faces = try verid.faceDetection.detectFacesInImage(image, limit: Int32(limit), options: 0)
                    for face in faces {
                        observer.on(.next(face))
                    }
                    observer.on(.completed)
                } catch {
                    observer.on(.error(error))
                }
                return Disposables.create()
            }
        }
    }
    
    // MARK: - Recognizable face detection
    
    /// Detect faces that can be used for face recognition in image URL
    /// - Parameters:
    ///   - url: Image URL
    ///   - limit: Maximum number of faces to detect
    /// - Returns: Observable whose elements are faces that can be used for face recognition
    /// - Since: 1.0.0
    public func detectRecognizableFacesInImageURL(_ url: URL, limit: Int) -> Observable<RecognizableFace> {
        return self.veridImageFromURL(url).asObservable().flatMap { image in
            return self.detectRecognizableFacesInImage(image, limit: limit)
        }
    }
    
    /// Detect faces that can be used for face recognition in Ver-ID image
    /// - Parameters:
    ///   - image: Image
    ///   - limit: Maximum number of faces to detect
    /// - Returns: Observable whose elements are faces that can be used for face recognition
    /// - Since: 1.0.0
    public func detectRecognizableFacesInImage(_ image: VerIDImage, limit: Int) -> Observable<RecognizableFace> {
        return self.verid.asObservable().flatMap { verid in
            return self.detectFacesInImage(image, limit: limit).flatMap { face in
                return self.createRecognizableFaceFromFace(face, image: image)
            }
        }
    }
    
    // MARK: - Face to recognizable face conversion
    
    /// Create face that can be used for face recognition from a detected face and Ver-ID image
    /// - Parameters:
    ///   - face: Detected face
    ///   - image: Image
    /// - Returns: Observable whose elements are faces that can be used for face recognition
    /// - Since: 1.0.0
    public func createRecognizableFaceFromFace(_ face: Face, image: VerIDImage) -> Observable<RecognizableFace> {
        return self.verid.asObservable().flatMap { verid in
            return Observable<RecognizableFace>.create { observer in
                do {
                    if let recognizableFace = try verid.faceRecognition.createRecognizableFacesFromFaces([face], inImage: image).first {
                        observer.onNext(RecognizableFace(face: face, recognitionData: recognizableFace.recognitionData, version: recognizableFace.version))
                    }
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
                return Disposables.create()
            }
        }
    }
    
    // MARK: - User identification
    
    /// Identify users in image URL
    /// - Parameter url: Image URL
    /// - Returns: Observable whose elements are tuples of user ID and similarity score
    /// - Since: 1.0.0
    public func identifyUsersInImageURL(_ url: URL) -> Observable<(String,Float)> {
        return self.veridImageFromURL(url).asObservable().flatMap { image in
            return self.identifyUsersInImage(image)
        }
    }
    
    /// Identify users in Ver-ID image
    /// - Parameter image: Image
    /// - Returns: Observable whose elements are tuples of user ID and similarity score
    /// - Since: 1.0.0
    public func identifyUsersInImage(_ image: VerIDImage) -> Observable<(String,Float)> {
        return self.detectRecognizableFacesInImage(image, limit: 1).flatMap { face in
            return self.identifyUsersInFace(face)
        }
    }
    
    /// Identify users in face
    /// - Parameter face: Face
    /// - Returns: Observable whose elements are tuples of user ID and similarity score
    /// - Since: 1.0.0
    public func identifyUsersInFace(_ face: Recognizable) -> Observable<(String,Float)> {
        return self.verid.asObservable().flatMap { verid in
            return Observable<(String,Float)>.create { observer in
                do {
                    let userIdentification = UserIdentification(verid: verid)
                    var identifiedUsers: [(String,Float)] = []
                    let identified = try userIdentification.identifyUsersInFace(face)
                    for (user,score) in identified {
                        identifiedUsers.append((user,score))
                    }
                    identifiedUsers.sort(by: { a, b in
                        if a.1 == b.1 {
                            return a.0 < b.0
                        }
                        return a.1 > b.1
                    })
                    for tuple in identifiedUsers {
                        observer.onNext(tuple)
                    }
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
                return Disposables.create()
            }
        }
    }
    
    // MARK: - Cropping image to face
    
    /// Crop image to the bounds of a detected face
    /// - Parameters:
    ///   - url: Image URL
    ///   - face: Face whose bounds to use for cropping the image
    /// - Returns: Single whose value is a UIImage cropped to the bounds of the face
    /// - Since: 1.0.0
    public func cropImageURL(_ url: URL, toFace face: Face) -> Single<UIImage> {
        return Single<UIImage>.create { emitter in
            do {
                let data = try Data(contentsOf: url)
                guard let image = UIImage(data: data) else {
                    throw ImageError.failedToReadImage
                }
                UIGraphicsBeginImageContext(face.bounds.size)
                defer {
                    UIGraphicsEndImageContext()
                }
                image.draw(at: CGPoint(x: 0-face.bounds.minX, y: 0-face.bounds.minY))
                guard let croppedImage = UIGraphicsGetImageFromCurrentImageContext() else {
                    throw ImageError.failedToReadImage
                }
                emitter(.success(croppedImage))
            } catch {
                emitter(.error(error))
            }
            return Disposables.create()
        }
    }
    
    // MARK: - Face comparison
    
    /// Compare face to other faces
    /// - Parameters:
    ///   - face: Face to compare to other faces
    ///   - faces: Other faces to compare to the face
    /// - Returns: Single whose value is a face comparison score
    /// - Note: Comparisons with scores above VerID.faceRecognition.authenticationScoreThreshold can be considered similar enough to pass authentication
    /// - Since: 1.0.0
    public func compareFace(_ face: Recognizable, toFaces faces: [Recognizable]) -> Single<Float> {
        return self.verid.flatMap { verid in
            return Single<Float>.create { emitter in
                do {
                    let score = try verid.faceRecognition.compareSubjectFaces([face], toFaces: faces)
                    emitter(.success(score.floatValue))
                } catch {
                    emitter(.error(error))
                }
                return Disposables.create()
            }
        }
    }
    
    // MARK: - User management
    
    /// Assign faces to user
    /// - Parameters:
    ///   - faces: Faces
    ///   - user: User ID
    /// - Since: 1.0.0
    public func assignFaces(_ faces: [Recognizable], toUser user: String) -> Completable {
        return self.verid.flatMapCompletable { verid in
            return Completable.create { emitter in
                var event: ((CompletableEvent) -> Void)? = emitter
                verid.userManagement.assignFaces(faces, toUser: user) { error in
                    if let err = error {
                        event?(.error(err))
                    } else {
                        event?(.completed)
                    }
                }
                return Disposables.create {
                    event = nil
                }
            }
        }
    }
    
    /// Assign face to user
    /// - Parameters:
    ///   - face: Face
    ///   - user: User ID
    /// - Since: 1.0.0
    public func assignFace(_ face: Recognizable, toUser user: String) -> Completable {
        return self.assignFaces([face], toUser: user)
    }
    
    /// Delete user
    /// - Parameter user: Identifier of the user to delete
    /// - Since: 1.0.0
    public func deleteUser(_ user: String) -> Completable {
        return self.verid.flatMapCompletable { verid in
            return Completable.create { emitter in
                var event: ((CompletableEvent) -> Void)? = emitter
                verid.userManagement.deleteUsers([user]) { error in
                    if let err = error {
                        event?(.error(err))
                    } else {
                        event?(.completed)
                    }
                }
                return Disposables.create {
                    event = nil
                }
            }
        }
    }
    
    /// Get users
    /// - Returns: Observable whose elements are identifiers of users with assigned faces
    /// - Since: 1.0.0
    public var users: Observable<String> {
        return self.verid.asObservable().flatMap { verid in
            return Observable<String>.create { observer in
                do {
                    let users = try verid.userManagement.users()
                    for user in users {
                        observer.onNext(user)
                    }
                    observer.onCompleted()
                } catch {
                    observer.onError(error)
                }
                return Disposables.create()
            }
        }
    }
    
    /// Get faces of user
    /// - Parameter user: Identifier for the user
    /// - Returns: Observable whose elements are faces of the user
    /// - Since: 1.0.0
    public func facesOfUser(_ user: String) -> Observable<Recognizable> {
        return self.verid.asObservable().flatMap { verid in
            return Observable<Recognizable>.create { observer in
                do {
                    let faces = try verid.userManagement.facesOfUser(user)
                    for face in faces {
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
    
    // MARK: - User authentication
    
    /// Authenticate user in faces
    /// - Parameters:
    ///   - user: Identifier for the user to be authenticated
    ///   - faces: Faces to use for authentication
    /// - Returns: Single whose value is a boolean (`true` if the user is authenticated)
    /// - Since: 1.0.0
    public func authenticateUser(_ user: String, inFaces faces: [Recognizable]) -> Single<Bool> {
        return self.verid.flatMap { verid in
            return self.facesOfUser(user).toArray().flatMap { userFaces in
                return Observable<Recognizable>.from(faces).flatMap { face in
                    return self.compareFace(face, toFaces: userFaces).asObservable()
                }.map { score in
                    return score >= verid.faceRecognition.authenticationScoreThreshold.floatValue
                }.toArray().map { authentications in
                    return authentications.contains(true)
                }
            }
        }
    }
    
    /// Authenticate user in face
    /// - Parameters:
    ///   - user: Identifier for the user to be authenticated
    ///   - face: Face to use for authentication
    /// - Returns: Single whose value is a boolean (`true` if the user is authenticated)
    /// - Since: 1.0.0
    public func authenticateUser(_ user: String, inFace face: Recognizable) -> Single<Bool> {
        return self.verid.flatMap { verid in
            return self.facesOfUser(user).toArray().flatMap { userFaces in
                return self.compareFace(face, toFaces: userFaces).map { score in
                    return score >= verid.faceRecognition.authenticationScoreThreshold.floatValue
                }
            }
        }
    }
    
    /// Authenticate user in image
    /// - Parameters:
    ///   - user: Identifier for the user to be authenticated
    ///   - url: Image URL in which to find the face to use for authentication
    /// - Returns: Single whose value is a boolean (`true` if the user is authenticated)
    /// - Since: 1.0.0
    public func authenticateUser(_ user: String, inImageURL url: URL) -> Single<Bool> {
        return self.detectRecognizableFacesInImageURL(url, limit: 1).asSingle().flatMap { face in
            return self.authenticateUser(user, inFace: face)
        }
    }
    
    /// Authenticate user in image
    /// - Parameters:
    ///   - user: Identifier for the user to be authenticated
    ///   - image: Image in which to find the face to use for authentication
    /// - Returns: Single whose value is a boolean (`true` if the user is authenticated)
    /// - Since: 1.0.0
    public func authenticateUser(_ user: String, inImage image: VerIDImage) -> Single<Bool> {
        return self.detectRecognizableFacesInImage(image, limit: 1).asSingle().flatMap { face in
            return self.authenticateUser(user, inFace: face)
        }
    }
    
    // MARK: - Session
    
    /// Run a Ver-ID session
    /// - Parameter settings: Ver-ID session settings
    /// - Returns: Maybe whose value is a session result if the session completes successfully
    /// - Note: If the session is cancelled the maybe completes without a value. If the session fails the maybe returns an error.
    /// - Since: 1.0.0
    public func session<T: VerIDSessionSettings>(settings: T) -> Maybe<VerIDSessionResult> {
        return self.verid.asMaybe().flatMap { verid in
            return Maybe<VerIDSessionResult>.create { maybe in
                let session = VerIDSession(environment: verid, settings: settings)
                self.sessionObservers[session] = maybe
                session.delegate = self
                session.start()
                return Disposables.create {
                    self.sessionObservers.removeValue(forKey: session)
                }
            }
        }
    }
    
    // MARK: - Session result parsing
    
    /// Get image URLs from session result
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the images
    /// - Returns: Observable whose elements are URLs of images collected in the session
    /// - Since: 1.0.0
    public func imageURLsFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<URL> {
        return Observable<URL>.create { observer in
            for attachment in sessionResult.attachments {
                if let url = attachment.imageURL, bearing == nil || bearing! == attachment.bearing {
                    observer.onNext(url)
                }
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    /// Get images from session result
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the images
    /// - Returns: Observable whose elements are images collected in the session
    /// - Since: 1.0.0
    public func imagesFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<UIImage> {
        return self.imageURLsFromSessionResult(sessionResult, bearing: bearing).flatMap { url in
            return Single<UIImage>.create { observer in
                do {
                    let data = try Data(contentsOf: url)
                    guard let image = UIImage(data: data) else {
                        throw ImageError.failedToReadImage
                    }
                    observer(.success(image))
                } catch {
                    observer(.error(error))
                }
                return Disposables.create()
            }.asObservable()
        }
    }
    
    /// Get images from session result and crop them to their corresponding faces
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the images
    /// - Returns: Observable whose elements are images collected in the session cropped to their corresponding faces
    /// - Since: 1.0.0
    public func croppedFaceImagesFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<UIImage> {
        return Observable<DetectedFace>.from(sessionResult.attachments).compactMap { attachment in
            guard let url = attachment.imageURL, bearing == nil || bearing! == attachment.bearing else {
                return nil
            }
            return (attachment.face, url)
        }.flatMap { (tuple: (Face,URL)) in
            return self.cropImageURL(tuple.1, toFace: tuple.0).asObservable()
        }
    }
    
    /// Get faces from session result
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the faces
    /// - Returns: Observable whose elements are faces collected in the session
    /// - Since: 1.0.0
    public func facesFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<Face> {
        return Observable<DetectedFace>.from(sessionResult.attachments).compactMap { attachment in
            guard bearing == nil || bearing! == attachment.bearing else {
                return nil
            }
            return attachment.face
        }
    }
    
    /// Get faces that can be used for face recognition from session result
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the faces
    /// - Returns: Observable whose elements are recognizable faces collected in the session
    /// - Since: 1.0.0
    public func recognizableFacesFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<RecognizableFace> {
        let faces: [RecognizableFace]
        if let `bearing` = bearing {
            faces = sessionResult.facesSuitableForRecognition(withBearing: bearing)
        } else {
            faces = sessionResult.facesSuitableForRecognition
        }
        return Observable<RecognizableFace>.from(faces)
    }
    
    /// Get faces and images from session result
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the elements
    /// - Returns: Observable whose elements are triplets of face, URL and bearing
    /// - Since: 1.0.0
    public func facesAndImagesFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<(Face,URL,Bearing)> {
        return Observable<DetectedFace>.from(sessionResult.attachments).compactMap { attachment in
            guard let url = attachment.imageURL, bearing == nil || bearing! == attachment.bearing else {
                return nil
            }
            return (attachment.face, url, attachment.bearing)
        }
    }
    
    /// Get recognizable faces and images from session result
    /// - Parameters:
    ///   - sessionResult: Session result
    ///   - bearing: Optional face bearing by which to filter the elements
    /// - Returns: Observable whose elements are triplets of recognizable face, URL and bearing
    /// - Since: 1.0.0
    public func recognizableFacesAndImagesFromSessionResult(_ sessionResult: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<(RecognizableFace,URL,Bearing)> {
        return Observable<DetectedFace>.from(sessionResult.attachments).compactMap { attachment in
            guard let face = attachment.face as? RecognizableFace, let url = attachment.imageURL, bearing == nil || bearing! == attachment.bearing else {
                return nil
            }
            return (face, url, attachment.bearing)
        }
    }
    
    // MARK: - Ver-ID session delegate
    
    public func session(_ session: VerIDSession, didFinishWithResult result: VerIDSessionResult) {
        if let observer = self.sessionObservers[session] {
            if let error = result.error {
                observer(.error(error))
            } else {
                observer(.success(result))
            }
            self.sessionObservers.removeValue(forKey: session)
        }
    }
    
    public func sessionWasCanceled(_ session: VerIDSession) {
        if let observer = self.sessionObservers[session] {
            observer(.completed)
            self.sessionObservers.removeValue(forKey: session)
        }
    }
    
//    func writeImage(_ image: VerIDImage, usingService service: ImageWriterService) -> Single<URL> {
//        return Single<URL>.create { single in
//            var url: URL? = nil
//            var event: ((SingleEvent<URL>) -> Void)? = single
//            url = service.writeImage(image) { error in
//                guard let single = event else {
//                    return
//                }
//                if let err = error {
//                    single(.error(err))
//                } else if let imageURL = url {
//                    single(.success(imageURL))
//                } else {
//                    single(.error(VerIDImageWriterServiceError.imageEncodingError))
//                }
//            }
//            return Disposables.create {
//                event = nil
//            }
//        }
//    }
//
//    public func session<T: VerIDSessionSettings>(settings: T, imageProviderServiceFactory: ImageProviderServiceFactory, faceDetectionServiceFactory: FaceDetectionServiceFactory, resultEvaluationServiceFactory: ResultEvaluationServiceFactory, imageWriterServiceFactory: ImageWriterServiceFactory?) -> Observable<(FaceDetectionResult,VerIDSessionResult)> {
//        do {
//            let imageProviderService = imageProviderServiceFactory.makeImageProviderService()
//            let faceDetectionService = try faceDetectionServiceFactory.makeFaceDetectionService(settings: settings)
//            let resultEvaluationService = resultEvaluationServiceFactory.makeResultEvaluationService(settings: settings)
//            let imageWriterService = try imageWriterServiceFactory?.makeImageWriterService()
//            let expiry = Date(timeIntervalSinceNow: settings.expiryTime)
//
//            return Observable<VerIDImage>.create { observer in
//                var disposed: Bool = false
//                do {
//                    while (!disposed) {
//                        if (Date().compare(expiry) == .orderedDescending) {
//                            throw VerIDError.sessionTimeout
//                        }
//                        let image = try imageProviderService.dequeueImage()
//                        observer.on(.next(image))
//                    }
//                } catch {
//                    observer.on(.error(error))
//                }
//                return Disposables.create {
//                    disposed = true
//                }
//            }.flatMap { image in
//                return Observable<FaceDetectionResult>.create { observer -> Disposable in
//                    let result = faceDetectionService.detectFaceInImage(image)
//                    observer.on(.next(result))
//                    observer.on(.completed)
//                    return Disposables.create()
//                }.flatMap { faceDetectionResult -> Observable<(FaceDetectionResult, VerIDSessionResult)> in
//                    let imageURL: URL?
//                    if faceDetectionResult.status == .faceAligned {
//                        imageURL = imageWriterService?.writeImage(image, completion: nil)
//                    } else {
//                        imageURL = nil
//                    }
//                    return Observable<(FaceDetectionResult,VerIDSessionResult)>.create { observer in
//                        let status = resultEvaluationService.addResult(faceDetectionResult, image: image, imageURL: imageURL)
//                        let resultPair: (FaceDetectionResult,VerIDSessionResult) = (faceDetectionResult,resultEvaluationService.sessionResult)
//                        observer.on(.next(resultPair))
//                        if status == .finished {
//                            if let error = resultEvaluationService.sessionResult.error {
//                                observer.on(.error(error))
//                            } else {
//                                observer.on(.completed)
//                            }
//                        }
//                        return Disposables.create()
//                    }
//                }
//            }
//        } catch {
//            return Observable.error(error)
//        }
//    }
//
//    public func session<T: VerIDSessionSettings>(settings: T, imageProviderServiceFactory: ImageProviderServiceFactory) -> Observable<(FaceDetectionResult,VerIDSessionResult)> {
//        return self.verid.asObservable().flatMap { verid in
//            return self.session(settings: settings, imageProviderServiceFactory: imageProviderServiceFactory, faceDetectionServiceFactory: VerIDFaceDetectionServiceFactory(environment: verid), resultEvaluationServiceFactory: VerIDResultEvaluationServiceFactory(environment: verid), imageWriterServiceFactory: VerIDImageWriterServiceFactory())
//        }
//    }
}

public enum ImageError: Int, Error {
    case failedToReadImage
}
