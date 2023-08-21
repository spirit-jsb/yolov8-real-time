//
//  ViewController.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/17.
//

import AVFoundation
import UIKit
import Vision

class ViewController: UIViewController {
    /// AVCapture variables to hold sequence data
    private var captureSession: AVCaptureSession?

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    private var captureDevice: AVCaptureDevice?
    private var captureDeviceResolution = CGSize()

    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoDataOutputQueue: DispatchQueue?

    private var yoloRequests = [VNRequest]()

    private var frameCounter: Int = 0
    private var detectionIntervalFrames: Int = 1

    private var detectionOverlayLayer: CALayer? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        self.captureSession = self.setupCaptureSession()

        self.prepareYoloRequest()
        self.setupOverlayLayer()

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
        videoPreviewLayer.frame = self.view.layer.bounds
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

    private func prepareYoloRequest() {
        do {
            let yoloModel = try VNCoreMLModel(for: yolov8s().model)
            let objectRecognition = VNCoreMLRequest(model: yoloModel) { request, _ in
                DispatchQueue.main.async {
                    // perform all the UI updates on the main queue
                    if let results = request.results as? [VNRecognizedObjectObservation] {
                        self.drawObjectRecognizedResults(results)
                    }
                }
            }

            self.yoloRequests = [objectRecognition]
        } catch {
            let alertController = UIAlertController(title: "Unexpected Failure", message: "The model is not supported", preferredStyle: .alert)
            self.present(alertController, animated: true)
        }
    }

    private func setupOverlayLayer() {
        let overlayLayer = CALayer()
        overlayLayer.bounds = CGRect(origin: CGPoint.zero, size: self.captureDeviceResolution)
        overlayLayer.position = CGPoint(x: self.view.layer.bounds.midX, y: self.view.layer.bounds.midY)
        overlayLayer.masksToBounds = true
        overlayLayer.name = "DetectionOverlay"

        self.detectionOverlayLayer = overlayLayer

        self.view.layer.addSublayer(overlayLayer)

        self.updateLayerGeometry()
    }

    private func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer, let videoPreviewLayer = self.videoPreviewLayer else {
            return
        }

        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)

        let videoPreviewRect = videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0))

        let scaleX: CGFloat = videoPreviewRect.width / self.captureDeviceResolution.height
        let scaleY: CGFloat = videoPreviewRect.height / self.captureDeviceResolution.width

        var scale = max(scaleX, scaleY)
        if scale.isInfinite {
            scale = 1.0
        }

        // Scale and mirror the image to ensure upright presentation.
        overlayLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))

        // Cover entire screen UI.
        overlayLayer.position = CGPoint(x: self.view.layer.bounds.midX, y: self.view.layer.bounds.midY)

        CATransaction.commit()
    }

    private func drawObjectRecognizedResults(_ results: [VNRecognizedObjectObservation]) {
        CATransaction.begin()
        CATransaction.setValue(true, forKey: kCATransactionDisableActions)

        let displaySize = self.captureDeviceResolution

        // remove all the old recognized objects
        self.detectionOverlayLayer?.sublayers = nil

        for objectObservation in results {
            // Select only the label with the highest confidence.
            if let topLabelObservation = objectObservation.labels.first {
                let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(displaySize.width), Int(displaySize.height))

                let objectRectangleLayer = self.createObjectRectangleLayer(bounds: objectBounds)
                let objectLabelSublayer = self.createObjectLabelSublayer(bounds: objectBounds, identifier: topLabelObservation.identifier, confidence: topLabelObservation.confidence)

                objectRectangleLayer.addSublayer(objectLabelSublayer)
                self.detectionOverlayLayer?.addSublayer(objectRectangleLayer)
            }
        }

        self.updateLayerGeometry()

        CATransaction.commit()
    }

    private func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        switch UIDevice.current.orientation {
            case .portrait: // Device oriented vertically, home button on the bottom
                return .up
            case .portraitUpsideDown: // Device oriented vertically, home button on the top
                return .left
            case .landscapeLeft: // Device oriented horizontally, home button on the right
                return .upMirrored
            case .landscapeRight: // Device oriented horizontally, home button on the left
                return .down
            default:
                return .up
        }
    }

    private func createObjectRectangleLayer(bounds: CGRect) -> CALayer {
        let layer = CALayer()
        layer.bounds = bounds
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.backgroundColor = UIColor.yellow.withAlphaComponent(0.5).cgColor
        layer.name = "ObjectRectangle"
        return layer
    }

    private func createObjectLabelSublayer(bounds: CGRect, identifier: String, confidence: Float) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.bounds = CGRect(x: 0.0, y: 0.0, width: bounds.height - 10.0, height: bounds.width - 10.0)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.contentsScale = UIScreen.main.scale // retina rendering
        textLayer.name = "ObjectLabel"
        textLayer.string = NSAttributedString(string: "\(identifier): \(String(format: "%.2f", confidence))", attributes: [.font: UIFont.systemFont(ofSize: bounds.height * 0.1, weight: .bold), .foregroundColor: UIColor.white])
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.frameCounter += 1

        guard self.frameCounter == self.detectionIntervalFrames else {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        self.frameCounter = 0

        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestHandlerOptions[.cameraIntrinsics] = cameraIntrinsicData
        }

        let exifOrientation = self.exifOrientationFromDeviceOrientation()

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestHandlerOptions)
        do {
            try imageRequestHandler.perform(self.yoloRequests)
        } catch {
            DispatchQueue.main.async {
                let alertController = UIAlertController(title: "Unexpected Failure", message: "An unexpected failure happened during scheduling of the requests", preferredStyle: .alert)
                self.present(alertController, animated: true)
            }
        }
    }
}
