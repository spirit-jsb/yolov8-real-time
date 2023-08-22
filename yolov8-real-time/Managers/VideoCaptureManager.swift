//
//  VideoCaptureManager.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/22.
//

import AVFoundation
import Foundation

protocol VideoCaptureManagerDelegate: NSObjectProtocol {
    func videoCaptureManager(_ manager: VideoCaptureManager, didOutput pixelBuffer: CVPixelBuffer)
}

class VideoCaptureManager: NSObject {
    enum Error: Swift.Error {
        case deviceNotFound
    }

    weak var delegate: VideoCaptureManagerDelegate?

    private let queue: DispatchQueue

    private var captureSession: AVCaptureSession?

    init(queue: DispatchQueue) {
        self.queue = queue
    }

    func startCapturing() {
        if self.captureSession == nil {
            self.captureSession = try? self.setupCaptureSession()
        }

        self.queue.async {
            self.captureSession?.startRunning()
        }
    }

    func stopCapturing() {
        self.queue.async {
            self.captureSession?.stopRunning()
        }
    }

    private func setupCaptureSession() throws -> AVCaptureSession {
        let captureSession = AVCaptureSession()

        try self.configureBackCamera(for: captureSession)
        self.configureVideoDataOutput(for: captureSession)

        return captureSession
    }

    private func configureBackCamera(for captureSession: AVCaptureSession) throws {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)

        guard let device = deviceDiscoverySession.devices.first else {
            throw Error.deviceNotFound
        }

        let deviceInput = try AVCaptureDeviceInput(device: device)

        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }

        if let highestResolution = self.highestResolution420Format(for: device) {
            try device.lockForConfiguration()
            device.activeFormat = highestResolution.format
            device.unlockForConfiguration()
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

        videoDataOutput.setSampleBufferDelegate(self, queue: self.queue)

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        if let captureConnection = videoDataOutput.connection(with: .video) {
            captureConnection.isEnabled = true

            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
    }
}

extension VideoCaptureManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            self.delegate?.videoCaptureManager(self, didOutput: imageBuffer)
        }
    }
}
