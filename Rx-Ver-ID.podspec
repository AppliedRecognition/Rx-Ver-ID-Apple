Pod::Spec.new do |s|
  s.name         = "Rx-Ver-ID"
  s.module_name  = "RxVerID"
  s.version      = "1.5.0"
  s.summary      = "Reactive implementation of Ver-ID face detection and recognition"
  s.homepage     = "https://github.com/AppliedRecognition"
  s.license      = { :type => "COMMERCIAL", :file => "LICENCE.txt" }
  s.author       = "Jakub Dolejs"
  s.platform     = :ios, "10.0"
  s.source	 = { :git => "https://github.com/AppliedRecognition/Rx-Ver-ID-Apple.git", :tag => "v#{s.version}" }
  s.dependency "RxSwift", "~> 5"
  s.dependency "RxCocoa", "~> 5"
  s.swift_versions = ["5.0", "5.1"]
  s.documentation_url = "https://appliedrecognition.github.io/Rx-Ver-ID-Apple/"
  s.subspec "Core" do |core|
    core.source_files = "RxVerID/RxVerID.swift"
    core.dependency "Ver-ID-Core", ">= 1.11.1", "< 2"
  end
  s.subspec "UI" do |ui|
    ui.source_files = "RxVerID/RxVerID+Session.swift"
    ui.dependency "Rx-Ver-ID/Core", "#{s.version}"
    ui.dependency "Ver-ID-UI", ">= 1.11.1", "< 2"
  end
end
