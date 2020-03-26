![Cocoapods](https://img.shields.io/cocoapods/v/Rx-Ver-ID.svg) ![CI](https://github.com/AppliedRecognition/Rx-Ver-ID-Apple/workflows/CI/badge.svg?event=push)

# Rx-Ver-ID-Apple
Reactive implementation of Ver-ID for iOS

## Installation
1. [Register your app](https://dev.ver-id.com/licensing/). You will need your app's bundle identifier.
2. Registering your app will generate an evaluation licence for your app. The licence is valid for 30 days. If you need a production licence please [contact Applied Recognition](mailto:sales@appliedrec.com).
2. When you finish the registration you'll receive a file called **Ver-ID identity.p12** and a password. Copy the password to a secure location and add the **Ver-ID identity.p12** file in your app:    
    - Open your project in Xcode.
    - From the top menu select **File/Add files to “[your project name]”...** or press **⌥⌘A** and browse to select the downloaded **Ver-ID identity.p12** file.
    - Reveal the options by clicking the **Options** button on the bottom left of the dialog.
    - Tick **Copy items if needed** under **Destination**.
    - Under **Added to targets** select your app target.
8. Ver-ID will need the password you received at registration.    
    - You can either specify the password when you create an instance of `RxVerID`:

        ~~~swift
        let rxVerID = RxVerID(veridPassword: "your password goes here")
        ~~~
    - Or you can add the password in your app's **Info.plist**:

        ~~~xml
        <key>com.appliedrec.verid.password</key>
        <string>your password goes here</string>
        ~~~
1. If your project is using [CocoaPods](https://cocoapods.org) for dependency management, open the project's **Podfile**. Otherwise make sure CocoaPods is installed and in your project's folder create a file named **Podfile** (without an extension).
1. Let's assume your project is called **MyProject** and it has an app target called **MyApp**. Open the **Podfile** in a text editor and enter the following:

	~~~ruby
	project 'MyProject.xcodeproj'
	workspace 'MyProject.xcworkspace'
	platform :ios, '10.3'
	target 'MyApp' do
		use_frameworks!
		pod 'Rx-Ver-ID'
	end
	~~~
1. Save the Podfile. Open **Terminal** and navigate to your project's folder. Then enter:

	~~~shell
	pod install
	~~~
1. You can now open **MyProject.xcworkspace** in **Xcode** and Rx-Ver-ID will be available to use in your app **MyApp**.

## Examples
### Detect a face in an image and crop the image to the bounds of the face
~~~swift
import RxVerID
import RxSwift

// Create an instance of RxVerID
let rxVerID = RxVerID()
// Set this to a file URL of an image with a face
let url = URL(fileURLWithPath: "test.jpg")
rxVerID.detectFacesInImageURL(url, limit: 1) // Detect one face
    .single() // Convert observable to single
    .flatMap { face in
        rxVerID.cropImageURL(url, toFace: face) // Crop the image
    }
    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default)) // Subscribe on a background thread
    .observeOn(MainScheduler()) // Observe on main thread
    .subscribe(onNext: { image in
      // The image is an instance of UIImage. You can display the image in an image view, save it, etc.
    }, onError: { error in
      // Something went wrong, inspect error
    }, onCompleted: nil, onDisposed: nil)
~~~

### Detect a face in an image and assign it to a user
~~~swift
import RxVerID
import RxSwift

// Create an instance of RxVerID
let rxVerID = RxVerID()
// Set this to a file URL of an image with a face
let url = URL(fileURLWithPath: "test.jpg")
// Set this to an identifier for your user
let userId = "testUserId"
rxVerID.detectRecognizableFacesInImageURL(url, limit: 1) // Detect one face
    .single() // Convert observable to single to ensure one face was found
    .flatMap { face in
        rxVerID.assignFace(face, toUser: userId) // Assign the detected face to user
    }
    .asCompletable()
    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default)) // Subscribe on a background thread
    .observeOn(MainScheduler()) // Observe on main thread
    .subscribe(onCompleted: {
      // The face has been assigned to user "testUserId"
    }, onError: { error in
      // Something went wrong, inspect error
    })
~~~

### Authenticate user in an image
~~~swift
import RxVerID
import RxSwift

// Create an instance of RxVerID
let rxVerID = RxVerID()
// Set this to a file URL of an image with a face
let url = URL(fileURLWithPath: "test.jpg")
// Set this to an identifier for your user
let userId = "testUserId"
rxVerID.authenticateUser(userId, inImageURL: url) // Detect one face
    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default)) // Subscribe on a background thread
    .observeOn(MainScheduler()) // Observe on main thread
    .subscribe(onSuccess: { authenticated in
    	if authenticated {
      		// The image has been authenticated as user "testUserId"
      }
    }, onError: { error in
      // Something went wrong, inspect error
    })
~~~

### Identify users in image
~~~swift
import RxVerID
import RxSwift

// Create an instance of RxVerID
let rxVerID = RxVerID()
// Set this to a file URL of an image with a face
let url = URL(fileURLWithPath: "test.jpg")
rxVerID.identifyUsersInImageURL(url) // Identify users
	.single() // Fail if no users or more than one user are identified
	.map { userScoreTuple in
		userScorePair.0 // We only need the user ID without the score
	}
	.subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default)) // Subscribe on a background thread
	.observeOn(MainScheduler()) // Observe on main thread
	.subscribe(onNext: { userId in
		// Identified userId
	}, onError: { error in
		// Something went wrong, inspect error
	}, onCompleted: nil, onDisposed: nil)
~~~

### Run a Ver-ID session
~~~swift
import RxVerID
import RxSwift

// Create an instance of RxVerID
let rxVerID = RxVerID()
// Create a dispose bag
let disposeBag = DisposeBag()
// Create session settings
let settings = LivenessDetectionSessionSettings()
// Get a window in which to run the session
guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow}).first else {
    return
}
rxVerID.sessionInWindow(window, settings: settings)
    .subscribeOn(ConcurrentDispatchQueueScheduler(qos: .default))
    .observeOn(MainScheduler.instance)
    .subscribe(onSuccess: { result in
        // Session succeeded 
    }, onError: { error in
        // Session failed
    }, onCompleted: {
        // Session was cancelled
    })
    .disposed(by: disposeBag)
~~~

## Advanced options

### Using only low-level API
If you're not planning to run Ver-ID sessions using RxVerID you can decrease the footprint of your app by only including the core part of the library. To do that change the pod spec to:

~~~ruby
pod 'Rx-Ver-ID/Core'
~~~

### Loading _Ver-ID identity.p12_ file from a URL
If you wish to use a _Ver-ID identity.p12_ file from a location different than your app's main bundle you can construct an instance of `VerIDIdentity` and pass it to the `RxVerID` initializer. This option is only available on iOS 10.3 or newer.

~~~swift
do {
    let url: URL // Set this to the URL pointing to your 'Ver-ID identity.p12' file
    let identity = try VerIDIdentity(url: url)
    let rxVerID = RxVerID(identity: identity)
} catch {
    // Failed to create Ver-ID identity
}
~~~

## [Reference documentation](https://appliedrecognition.github.io/Rx-Ver-ID-Apple/Classes/RxVerID.html)
