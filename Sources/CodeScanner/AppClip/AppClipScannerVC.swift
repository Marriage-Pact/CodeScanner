//
//  AppClipScannerVC.swift
//  Matchbox
//
//  Created by Ian Thomas on 11/20/24.
//

import UIKit
import RealityKit
import ARKit
import Combine
import SwiftUI

public struct ARSessionLoadingStateUpdate {
    public let isLoading: Bool
}

extension Notification.Name {
    public static let ARSessionLoadingState = Notification.Name("ARSessionLoadingState")
}

public struct AppClipScannerView: UIViewControllerRepresentable {
    
    public init(completion: @escaping (Result<ScanResult, ScanError>) -> Void) {
        self.completion = completion
    }
    
    public func makeUIViewController(context: Context) -> AppClipScannerVC {
        return AppClipScannerVC(parentView: self)
    }
    
    public func updateUIViewController(_ uiViewController: AppClipScannerVC, context: Context) {
        
    }
    
    public var completion: (Result<ScanResult, ScanError>) -> Void
}

public final class AppClipScannerVC: UIViewController, ARSessionDelegate, ARCoachingOverlayViewDelegate {
    
    private let parentView: AppClipScannerView
    
    init(parentView: AppClipScannerView) {
        self.parentView = parentView
//        appClipCodeCoachingOverlay = AppClipCodeCoachingOverlayView(parentView: arView)
        informationLabel = OverlayLabel()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let arView = ARView()
//    var appClipCodeCoachingOverlay: AppClipCodeCoachingOverlayView
    private var informationLabel: OverlayLabel
//    var unsupportedDeviceLabel: UILabel
    private let coachingOverlayWorldTracking = ARCoachingOverlayView()
    
    var decodedURLs: [URL] = []

    /// - Tag: ViewDidLoad
    public override func viewDidLoad() {
        super.viewDidLoad()
        /// - Important: Hard assumption that is device supports tracking
        
//        guard ARWorldTrackingConfiguration.supportsAppClipCodeTracking else {
//            displayUnsupportedDevicePrompt()
//            return
//        }
        
        initializeARView()
        initializeCoachingOverlays()
        initializeInformationLabel()
        
//        if
//            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
//            let sceneDelegate = windowScene.delegate as? SceneDelegate,
//            let appClipCodeLaunchURL = sceneDelegate.appClipCodeURL
//        {
//            // To provide a faster user experience, use the launch URL to begin loading content.
//            process(productKey: getProductKey(from: appClipCodeLaunchURL), initializePreview: false)
//        }
    }
    
    /// Hides the instruction prompt once the user has detected an app clip code.
    ///- Tag: SessionDidAddAnchors
//    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
//        for anchor in anchors {
//            if anchor is ARAppClipCodeAnchor {
                // Hide the coaching overlay since ARKit recognized an App Clip Code.
//                appClipCodeCoachingOverlay.setCoachingViewHidden(true)
//            }
//        }
//    }
    
    ///- Tag: SessionDidUpdateAnchors
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let appClipCodeAnchor = anchor as? ARAppClipCodeAnchor, appClipCodeAnchor.urlDecodingState != .decoding {

                switch appClipCodeAnchor.urlDecodingState {
                case .decoded:
                    if let appClipQRCode = appClipCodeAnchor.url {
                        
                        /// `didUpdate` is called so many times, when the user is pointing at an app clip
                        if decodedURLs.contains(appClipQRCode) == false {
                           decodedURLs.append(appClipQRCode)
                            
                            /// Doing type `QR` because their is nothing like app clip in the AVMediaObject class
                            let result = ScanResult(string: appClipQRCode.absoluteString, type: .qr)
                            self.parentView.completion(.success(result))
                        } else {
                            /// We've already decoded this app clip code
                        }
                        
                    } else {
                        sendFailureCompletion()
                    }
                case .failed:
                    self.sendFailureCompletion()
                 
//                    showInformationLabel("Decoding failure. Trying scanning a code again.")
                case .decoding:
                    continue
                default:
                    continue
                }
            }
        }
    }
    
    private func sendFailureCompletion() {
        self.resetDecodedUrls()
        self.parentView.completion(.failure(ScanError.badOutput))
    }
    
    private func resetDecodedUrls() {
        self.decodedURLs.removeAll()
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        guard Self.IsCameraPermissionError(error) == false else {
            /// This error is handled by showing the go to settings button
            self.parentView.completion(.failure(ScanError.permissionDenied))
            return
        }
       
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        DispatchQueue.main.async {
            // Present an alert informing about the error that occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.runARSession()
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    private static func IsCameraPermissionError(_ error: Error) -> Bool {
        if let asArError = error as? ARError {
            switch asArError.code {
            case .cameraUnauthorized:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    /*
    func displayUnsupportedDevicePrompt() {
        let promptText =
            """
            Device not supported
            
            App Clip Code tracking
            requires a device
            with an Apple Neural Engine.
            """
        unsupportedDeviceLabel = UILabel()
        unsupportedDeviceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(unsupportedDeviceLabel, at: 0)
        unsupportedDeviceLabel.fillParentView()
        unsupportedDeviceLabel.backgroundColor  = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        unsupportedDeviceLabel.adjustsFontSizeToFitWidth = false
        unsupportedDeviceLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        unsupportedDeviceLabel.text = promptText
        unsupportedDeviceLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        unsupportedDeviceLabel.textAlignment = .center
        unsupportedDeviceLabel.numberOfLines = 0
        unsupportedDeviceLabel.lineBreakMode = .byWordWrapping
    }
    */
    func initializeARView() {
        UIApplication.shared.isIdleTimerDisabled = true
        
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)
        arView.fillParentView()
        
        arView.session.delegate = self
        
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { [weak self] in
                self?.runARSession()
            }
        }
    }
    
    private func runARSession(withAdditionalReferenceImages additionalReferenceImages: Set<ARReferenceImage> = Set<ARReferenceImage>()) {
        
        NotificationCenter.default.post(name: .ARSessionLoadingState, object: ARSessionLoadingStateUpdate(isLoading: true))
        
        self.resetDecodedUrls()
        
        if let currentConfiguration = (arView.session.configuration as? ARWorldTrackingConfiguration) {
            // Add the additional reference images to the current AR session.
            currentConfiguration.detectionImages = currentConfiguration.detectionImages.union(additionalReferenceImages)
            currentConfiguration.maximumNumberOfTrackedImages = currentConfiguration.detectionImages.count
            arView.session.run(currentConfiguration)
        } else {
            // Initialize a new AR session with App Clip Code tracking and image tracking.
            arView.automaticallyConfigureSession = false
            let newConfiguration = ARWorldTrackingConfiguration()
            newConfiguration.detectionImages = additionalReferenceImages
            newConfiguration.maximumNumberOfTrackedImages = newConfiguration.detectionImages.count
            newConfiguration.automaticImageScaleEstimationEnabled = true
            newConfiguration.appClipCodeTrackingEnabled = true
            arView.session.run(newConfiguration)
        }
    }
    
    private var hasSentInitialLoadingStateNotification: Bool = false
    
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard hasSentInitialLoadingStateNotification == false else { return }
        hasSentInitialLoadingStateNotification = true
        NotificationCenter.default.post(name: .ARSessionLoadingState, object: ARSessionLoadingStateUpdate(isLoading: false))
    }
    
    func initializeCoachingOverlays() {
//        appClipCodeCoachingOverlay = AppClipCodeCoachingOverlayView(parentView: arView)
        
        arView.addSubview(coachingOverlayWorldTracking)
        coachingOverlayWorldTracking.translatesAutoresizingMaskIntoConstraints = false
        coachingOverlayWorldTracking.fillParentView()
        coachingOverlayWorldTracking.delegate = self
        coachingOverlayWorldTracking.session = arView.session
    }
    
    func initializeInformationLabel() {
//        informationLabel = OverlayLabel()
        arView.addSubview(informationLabel)
        informationLabel.lowerCenterInParentView()
    }
    
    func showInformationLabel(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            debugPrint(message)
            if let isCoachingActive = self?.coachingOverlayWorldTracking.isActive, !isCoachingActive {
                self?.setInformationLabelHidden(false)
                self?.informationLabel.text = message
            }
        }
    }
    
    func setInformationLabelHidden(_ hide: Bool) {
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.25, delay: 0, options: [.beginFromCurrentState], animations: { [weak self] in
                self?.informationLabel.alpha = hide ? 0 : 1
            })
        }
    }
    
    public func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        appClipCodeCoachingOverlay.setCoachingViewHidden(true)
//        setInformationLabelHidden(true)
    }
    
    public func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        if decodedURLs.isEmpty {
//            appClipCodeCoachingOverlay.setCoachingViewHidden(false)
//        }
    }
    
    public func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        hasSentInitialLoadingStateNotification = false
        initializeARView()
    }
    
    public override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}

