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
    
    /// Run a Ver-ID session
    /// - Parameter settings: Ver-ID session settings
    /// - Returns: Maybe whose value is a session result if the session completes successfully
    /// - Note: If the session is cancelled the maybe completes without a value. If the session fails the maybe returns an error.
    /// - Since: 1.0.0
    func session<T: VerIDSessionSettings>(settings: T) -> Maybe<VerIDSessionResult> {
        return self.verid.asMaybe().flatMap { verid in
            return Maybe<VerIDSessionResult>.create { maybe in
                var delegate: SessionDelegate? = SessionDelegate(maybe)
                let session = VerIDSession(environment: verid, settings: settings)
                session.delegate = delegate
                session.start()
                return Disposables.create {
                    delegate = nil
                }
            }
        }.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
    }
    
    /// Run a Ver-ID session
    /// - Parameters:
    ///   - settings: Ver-ID session settings
    ///   - translatedStrings: Translations
    /// - Returns: Maybe whose value is a session result if the session completes successfully
    /// - Note: If the session is cancelled the maybe completes without a value. If the session fails the maybe returns an error.
    /// - Since: 1.1.0
    func session<T: VerIDSessionSettings>(settings: T, translatedStrings: TranslatedStrings) -> Maybe<VerIDSessionResult> {
        return self.verid.asMaybe().flatMap { verid in
            return Maybe<VerIDSessionResult>.create { maybe in
                let session = VerIDSession(environment: verid, settings: settings, translatedStrings: translatedStrings)
                var delegate: SessionDelegate? = SessionDelegate(maybe)
                session.delegate = delegate
                session.start()
                return Disposables.create {
                    delegate = nil
                }
            }
        }.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
    }
}
#endif
