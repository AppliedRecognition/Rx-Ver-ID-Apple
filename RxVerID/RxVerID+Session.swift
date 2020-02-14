//
//  RxVerID+Session.swift
//  RxVerID
//
//  Created by Jakub Dolejs on 06/12/2019.
//  Copyright © 2019 Applied Recognition Inc. All rights reserved.
//

#if canImport(VerIDUI)

import Foundation
import VerIDCore
import VerIDUI
import RxSwift

fileprivate class SessionDelegate: VerIDSessionDelegate {
    
    private let event: (MaybeEvent<VerIDSessionResult>) -> Void
    
    init(_ event: @escaping (MaybeEvent<VerIDSessionResult>) -> Void) {
        self.event = event
    }
    
    func session(_ session: VerIDSession, didFinishWithResult result: VerIDSessionResult) {
        if let error = result.error {
            self.event(.error(error))
        } else {
            self.event(.success(result))
        }
    }
    
    func sessionWasCanceled(_ session: VerIDSession) {
        self.event(.completed)
    }
    
}

public extension RxVerID {
        
    // MARK: - Session
    
    /// Create and run a Ver-ID session
    /// - Parameter settings: Ver-ID session settings
    /// - Returns: Maybe whose value is a session result if the session completes successfully
    /// - Note: If the session is cancelled the maybe completes without a value. If the session fails the maybe returns an error.
    /// - Since: 1.0.0
    func session<T: VerIDSessionSettings>(settings: T) -> Maybe<VerIDSessionResult> {
        return self.session(settings: settings, translatedStrings: TranslatedStrings())
    }
    
    /// Create and run a Ver-ID session
    /// - Parameters:
    ///   - settings: Ver-ID session settings
    ///   - translatedStrings: Translations
    /// - Returns: Maybe whose value is a session result if the session completes successfully
    /// - Note: If the session is cancelled the maybe completes without a value. If the session fails the maybe returns an error.
    /// - Since: 1.1.0
    func session<T: VerIDSessionSettings>(settings: T, translatedStrings: TranslatedStrings) -> Maybe<VerIDSessionResult> {
        return self.createSession(settings: settings, translatedStrings: translatedStrings).asMaybe().flatMap({ session in
            self.runSession(session)
        }).subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
    }
    
    /// Run a Ver-ID session
    /// - Parameter session: Session to run
    /// - Since: 1.4.0
    func runSession(_ session: VerIDSession) -> Maybe<VerIDSessionResult> {
        return Maybe<VerIDSessionResult>.create(subscribe: { maybe in
            var delegate: SessionDelegate? = SessionDelegate(maybe)
            session.delegate = delegate
            session.start()
            return Disposables.create {
                delegate = nil
            }
        }).subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
    }
    
    /// Create a Ver-ID session
    /// - Parameter settings: Session settings
    /// - Since: 1.4.0
    func createSession<T: VerIDSessionSettings>(settings: T) -> Single<VerIDSession> {
        return self.createSession(settings: settings, translatedStrings: TranslatedStrings())
    }
    
    /// Create a Ver-ID session
    /// - Parameters:
    ///   - settings: Session settings
    ///   - translatedStrings: Translations
    /// - Since: 1.4.0
    func createSession<T: VerIDSessionSettings>(settings: T, translatedStrings: TranslatedStrings) -> Single<VerIDSession> {
        return self.verid.flatMap { verid in
            return Single<VerIDSession>.create { event in
                let session = VerIDSession(environment: verid, settings: settings, translatedStrings: translatedStrings)
                event(.success(session))
                return Disposables.create()
            }
        }
    }
    
    /// Set video writer service factory on session
    /// - Parameters:
    ///   - videoWriterFactory: Video writer service factory
    ///   - session: Session
    /// - Since: 1.4.0
    func setVideoWriterFactory(_ videoWriterFactory: VideoWriterServiceFactory, on session: VerIDSession) -> Single<VerIDSession> {
        return Single<VerIDSession>.create { event in
            session.videoWriterFactory = videoWriterFactory
            event(.success(session))
            return Disposables.create()
        }
    }
    
    /// Set face detection service factory on session
    /// - Parameters:
    ///   - faceDetectionFactory: Face detection service factory
    ///   - session: Session
    /// - Since: 1.4.0
    func setFaceDetectionFactory(_ faceDetectionFactory: FaceDetectionServiceFactory, on session: VerIDSession) -> Single<VerIDSession> {
        return Single<VerIDSession>.create { event in
            session.faceDetectionFactory = faceDetectionFactory
            event(.success(session))
            return Disposables.create()
        }
    }
    
    /// Set result evaluation service factory on session
    /// - Parameters:
    ///   - resultEvaluationFactory: Result evaluation service factory
    ///   - session: Session
    /// - Since: 1.4.0
    func setResultEvaluationFactory(_ resultEvaluationFactory: ResultEvaluationServiceFactory, on session: VerIDSession) -> Single<VerIDSession> {
        return Single<VerIDSession>.create { event in
            session.resultEvaluationFactory = resultEvaluationFactory
            event(.success(session))
            return Disposables.create()
        }
    }
    
    /// Set image writer service factory on session
    /// - Parameters:
    ///   - resultEvaluationFactory: Image writer service factory
    ///   - session: Session
    /// - Since: 1.4.0
    func setImageWriterFactory(_ imageWriterFactory: ImageWriterServiceFactory, on session: VerIDSession) -> Single<VerIDSession> {
        return Single<VerIDSession>.create { event in
            session.imageWriterFactory = imageWriterFactory
            event(.success(session))
            return Disposables.create()
        }
    }
    
    /// Set session view controllers factory on session
    /// - Parameters:
    ///   - resultEvaluationFactory: Session view controllers factory
    ///   - session: Session
    /// - Since: 1.4.0
    func setSessionViewControllersFactory(_ sessionViewControllersFactory: SessionViewControllersFactory, on session: VerIDSession) -> Single<VerIDSession> {
        return Single<VerIDSession>.create { event in
            session.sessionViewControllersFactory = sessionViewControllersFactory
            event(.success(session))
            return Disposables.create()
        }
    }
}
#endif
