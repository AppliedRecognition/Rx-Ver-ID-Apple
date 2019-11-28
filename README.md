![Cocoapods](https://img.shields.io/cocoapods/v/Rx-Ver-ID)

# Rx-Ver-ID-Apple
Reactive implementation of Ver-ID for iOS

## Installation
1. [Request an API secret](https://dev.ver-id.com/admin/register) for your app. We will need your app's bundle ID.
1. Add the following entry in your app's **Info.plist** substituting `[API secret]` for the API secret obtained in step 1:

	~~~xml
	<key>com.appliedrec.verid.apiSecret</key>
	<string>[API secret]</string>
	~~~
1. If your project is using [CocoaPods](https://cocoapods.org) for dependency management, open the project's **Podfile**. Otherwise make sure CocoaPods is installed and in your project's folder create a file named **Podfile** (without an extension).
1. Let's assume your project is called **MyProject** and it has an app target called **MyApp**. Open the **Podfile** in a text editor and enter the following:

	~~~ruby
	project 'MyProject.xcodeproj'
	workspace 'MyProject.xcworkspace'
	platform :ios, '11.0'
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

### [Reference documentation](https://appliedrecognition.github.io/Rx-Ver-ID-Apple/Classes/RxVerID.html)
