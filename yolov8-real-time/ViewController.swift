//
//  ViewController.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/17.
//

import AVFoundation
import UIKit

class ViewController: UIViewController {
    /// AVCapture variables to hold sequence data
    private var captureSession: AVCaptureSession?

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    private var captureDevice: AVCaptureDevice?
    private var captureDeviceResolution = CGSize()

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        self.captureSession = self.setupCaptureSession()

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }

    /// Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    /// Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    private func setupCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()

        do {
            try self.configureBackCamera(for: captureSession)
            self.configureVideoDataOutput(for: captureSession)
            self.designatePreviewLayer(for: captureSession)
            return captureSession
        } catch let executionError as NSError {
            let alertController = UIAlertController(title: "Failed with error \(executionError.code)", message: executionError.localizedDescription, preferredStyle: .alert)
            self.present(alertController, animated: true)
        } catch {
            let alertController = UIAlertController(title: "Unexpected Failure", message: "An unexpected failure has occured", preferredStyle: .alert)
            self.present(alertController, animated: true)
        }

        self.teardownAVCapture()

        return nil
    }

    private func configureBackCamera(for captureSession: AVCaptureSession) throws {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)

        guard let device = deviceDiscoverySession.devices.first else {
            throw NSError(domain: "ViewController", code: 1, userInfo: nil)
        }

        let deviceInput = try AVCaptureDeviceInput(device: device)

        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }

        if let highestResolution = self.highestResolution420Format(for: device) {
            try device.lockForConfiguration()
            device.activeFormat = highestResolution.format
            device.unlockForConfiguration()

            self.captureDevice = device
            self.captureDeviceResolution = highestResolution.resolution
        }
    }

    private func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)

        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format

            let deviceFormatDescription = deviceFormat.formatDescription

            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)

                if highestResolutionFormat == nil || candidateDimensions.width > highestResolutionDimensions.width {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }

        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))

            return (format: highestResolutionFormat!, resolution: resolution)
        }

        return nil
    }

    private func configureVideoDataOutput(for captureSession: AVCaptureSession) {
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.max.yolov8-real-time")

        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        if let captureConnection = videoDataOutput.connection(with: .video) {
            captureConnection.isEnabled = true

            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }

        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
    }

    private func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.frame = self.view.bounds
        videoPreviewLayer.name = "VideoPreview"
        videoPreviewLayer.videoGravity = .resizeAspectFill

        self.videoPreviewLayer = videoPreviewLayer

        self.view.layer.addSublayer(videoPreviewLayer)
    }

    private func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil

        if let videoPreviewLayer = self.videoPreviewLayer {
            videoPreviewLayer.removeFromSuperlayer()
            self.videoPreviewLayer = nil
        }
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {}
