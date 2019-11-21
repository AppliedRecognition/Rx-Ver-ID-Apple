//
//  RxVerID.swift
//  RxVerID
//
//  Created by Jakub Dolejs on 23/10/2019.
//  Copyright © 2019 Applied Recognition. All rights reserved.
//

import Foundation
import VerIDCore
import VerIDUI
import RxSwift

public class RxVerID: VerIDSessionDelegate {
    
    private var sessionObservers: [VerIDSession:(MaybeEvent<VerIDSessionResult>) -> Void] = [:]
    private var veridInstance: VerID?
    private let veridSemaphore = DispatchSemaphore(value: 1)
    
    // MARK: - Ver-ID session delegate
    
    public func session(_ session: VerIDSession, didFinishWithResult result: VerIDSessionResult) {
        if let observer = self.sessionObservers[session] {
            if let error = result.error {
                observer(.error(error))
            } else {
                observer(.success(result))
            }
        }
    }
    
    public func sessionWasCanceled(_ session: VerIDSession) {
        if let observer = self.sessionObservers[session] {
            observer(.completed)
        }
    }
    
    // MARK: -
    
    public var verid: Single<VerID> {
        return Single.create { single in
            self.veridSemaphore.wait()
            if let verid = self.veridInstance {
                single(.success(verid))
            } else {
                let factory = VerIDFactory()
                do {
                    self.veridInstance = try factory.createVerIDSync()
                    single(.success(self.veridInstance!))
                } catch {
                    single(.error(error))
                }
            }
            self.veridSemaphore.signal()
            return Disposables.create()
        }
    }
    
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
    
    public func detectFacesInImage(_ url: URL, limit: Int) -> Observable<Face> {
        return self.verid.asObservable().flatMap { verid in
            return self.veridImageFromURL(url).asObservable().flatMap { image in
                return self.detectFacesInImage(image, verid: verid, limit: limit)
            }
        }
    }
    
    public func detectFacesInImage(_ image: VerIDImage, verid: VerID, limit: Int) -> Observable<Face> {
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
    
    public func identifyUsersInImage(_ image: VerIDImage, verid: VerID) -> Observable<(String,Float)> {
        return Observable<(String,Float)>.create { observer in
            do {
                let faces = try verid.faceDetection.detectFacesInImage(image, limit: 1, options: 0)
                if !faces.isEmpty {
                    let recognizableFaces = try verid.faceRecognition.createRecognizableFacesFromFaces(faces, inImage: image)
                    let userIdentification = UserIdentification(verid: verid)
                    var identifiedUsers: [(String,Float)] = []
                    for face in recognizableFaces {
                        let identified = try userIdentification.identifyUsersInFace(face)
                        for (user,score) in identified {
                            identifiedUsers.append((user,score))
                        }
                    }
                    identifiedUsers.sort(by: { a, b in
                        if a.1 == b.1 {
                            return a.0 < b.0
                        }
                        return a.1 > b.1
                    })
                    for tuple in identifiedUsers {
                        observer.on(.next(tuple))
                    }
                }
                observer.on(.completed)
            } catch {
                observer.on(.error(error))
            }
            return Disposables.create()
        }
    }
    
    public func identifyUsersInImage(_ url: URL) -> Observable<(String,Float)> {
        return self.verid.asObservable().flatMap { verid in
            return self.veridImageFromURL(url).asObservable().flatMap { image in
                return self.identifyUsersInImage(image, verid: verid)
            }
        }
    }
    
    func writeImage(_ image: VerIDImage, usingService service: ImageWriterService) -> Single<URL> {
        return Single<URL>.create { single in
            var url: URL? = nil
            let callback: (Error?) -> Void = { error in
                if let err = error {
                    single(.error(err))
                } else if let imageURL = url {
                    single(.success(imageURL))
                } else {
                    single(.error(VerIDImageWriterServiceError.imageEncodingError))
                }
            }
            url = service.writeImage(image, completion: callback)
            return Disposables.create()
        }
    }
    
    public func imagesFromResult(_ result: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<URL> {
        return Observable<URL>.create { observer in
            for attachment in result.attachments {
                if let url = attachment.imageURL, bearing == nil || bearing! == attachment.bearing {
                    observer.onNext(url)
                }
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    public func croppedFaceImagesFromResult(_ result: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<UIImage> {
        return Observable<UIImage>.create { observer in
            for attachment in result.attachments {
                if let url = attachment.imageURL, bearing == nil || bearing! == attachment.bearing, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    UIGraphicsBeginImageContext(attachment.face.bounds.size)
                    image.draw(at: CGPoint(x: 0-attachment.face.bounds.minX, y: 0-attachment.face.bounds.minY))
                    if let croppedImage = UIGraphicsGetImageFromCurrentImageContext() {
                        observer.onNext(croppedImage)
                    }
                    UIGraphicsEndImageContext()
                }
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    public func facesFromResult(_ result: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<Face> {
        return Observable<Face>.create { observer in
            for attachment in result.attachments {
                if bearing == nil || bearing! == attachment.bearing {
                    observer.onNext(attachment.face)
                }
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    public func recognizableFacesFromResult(_ result: VerIDSessionResult, bearing: Bearing? = nil) -> Observable<RecognizableFace> {
        return Observable<RecognizableFace>.create { observer in
            let faces: [RecognizableFace]
            if let `bearing` = bearing {
                faces = result.facesSuitableForRecognition(withBearing: bearing)
            } else {
                faces = result.facesSuitableForRecognition
            }
            for face in faces {
                observer.onNext(face)
            }
            observer.onCompleted()
            return Disposables.create()
        }
    }
    
    public func session<T: VerIDSessionSettings>(settings: T) -> Maybe<VerIDSessionResult> {
        return self.verid.asMaybe().flatMap { verid in
            return self.session(verid: verid, settings: settings)
        }
    }
    
    public func session<T: VerIDSessionSettings>(verid: VerID, settings: T) -> Maybe<VerIDSessionResult> {
        return Maybe<VerIDSessionResult>.create { maybe in
            let session = VerIDSession(environment: verid, settings: settings)
            self.sessionObservers[session] = maybe
            session.delegate = self
            session.start()
            return Disposables.create()
        }
    }
    
    public func session<T: VerIDSessionSettings>(settings: T, imageProviderServiceFactory: ImageProviderServiceFactory, faceDetectionServiceFactory: FaceDetectionServiceFactory, resultEvaluationServiceFactory: ResultEvaluationServiceFactory, imageWriterServiceFactory: ImageWriterServiceFactory?) -> Observable<(FaceDetectionResult,VerIDSessionResult)> {
        do {
            let imageProviderService = imageProviderServiceFactory.makeImageProviderService()
            let faceDetectionService = try faceDetectionServiceFactory.makeFaceDetectionService(settings: settings)
            let resultEvaluationService = resultEvaluationServiceFactory.makeResultEvaluationService(settings: settings)
            let imageWriterService = try imageWriterServiceFactory?.makeImageWriterService()
            let expiry = Date(timeIntervalSinceNow: settings.expiryTime)
            
            return Observable<VerIDImage>.create { observer in
                var disposed: Bool = false
                do {
                    while (!disposed) {
                        if (Date().compare(expiry) == .orderedDescending) {
                            throw VerIDError.sessionTimeout
                        }
                        let image = try imageProviderService.dequeueImage()
                        observer.on(.next(image))
                    }
                } catch {
                    observer.on(.error(error))
                }
                return Disposables.create {
                    disposed = true
                }
            }.flatMap { image in
                return Observable<FaceDetectionResult>.create { observer -> Disposable in
                    let result = faceDetectionService.detectFaceInImage(image)
                    observer.on(.next(result))
                    observer.on(.completed)
                    return Disposables.create()
                }.flatMap { faceDetectionResult -> Observable<(FaceDetectionResult, VerIDSessionResult)> in
                    let imageURL: URL?
                    if faceDetectionResult.status == .faceAligned {
                        imageURL = imageWriterService?.writeImage(image, completion: nil)
                    } else {
                        imageURL = nil
                    }
                    return Observable<(FaceDetectionResult,VerIDSessionResult)>.create { observer in
                        let status = resultEvaluationService.addResult(faceDetectionResult, image: image, imageURL: imageURL)
                        let resultPair: (FaceDetectionResult,VerIDSessionResult) = (faceDetectionResult,resultEvaluationService.sessionResult)
                        observer.on(.next(resultPair))
                        if status == .finished {
                            if let error = resultEvaluationService.sessionResult.error {
                                observer.on(.error(error))
                            } else {
                                observer.on(.completed)
                            }
                        }
                        return Disposables.create()
                    }
                }
            }
        } catch {
            return Observable.error(error)
        }
    }
    
    public func session<T: VerIDSessionSettings>(settings: T, imageProviderServiceFactory: ImageProviderServiceFactory) -> Observable<(FaceDetectionResult,VerIDSessionResult)> {
        return self.verid.asObservable().flatMap { verid in
            return self.session(settings: settings, imageProviderServiceFactory: imageProviderServiceFactory, faceDetectionServiceFactory: VerIDFaceDetectionServiceFactory(environment: verid), resultEvaluationServiceFactory: VerIDResultEvaluationServiceFactory(environment: verid), imageWriterServiceFactory: VerIDImageWriterServiceFactory())
        }
    }
}
