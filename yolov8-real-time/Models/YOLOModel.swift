//
//  YOLOModel.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/22.
//

import CoreML
import Foundation

class YOLOModel {
    enum Tasks {
        case detection
        case segmentation
    }

    enum Weights {
        case nano
        case small
        case medium
        case large
        case xlarge
    }

    class Output {
        let output: MLMultiArray
        let proto: MLMultiArray?

        init(output: MLMultiArray, proto: MLMultiArray?) {
            self.output = output
            self.proto = proto
        }
    }

    let tasks: Tasks
    let weights: Weights

    private var modeln: yolov8n?

    private var models: yolov8s?

    private var _modeln_seg: Any?
    @available(iOS 15.0, *)
    private var modeln_seg: yolov8n_seg? {
        get {
            return self._modeln_seg as? yolov8n_seg
        }
        set {
            self._modeln_seg = newValue
        }
    }

    private var _models_seg: Any?
    @available(iOS 15.0, *)
    private var models_seg: yolov8s_seg? {
        get {
            return self._models_seg as? yolov8s_seg
        }
        set {
            self._models_seg = newValue
        }
    }

    init(tasks: Tasks, weights: Weights) {
        self.tasks = tasks
        self.weights = weights
    }

    func load() throws {
        switch (self.tasks, self.weights) {
            case (.detection, .nano):
                self.modeln = try yolov8n()
            case (.detection, .small):
                self.models = try yolov8s()
            case (.segmentation, .nano):
                guard #available(iOS 15.0, *) else {
                    fatalError("YOLOv8-seg model has not been implemented")
                }

                self.modeln_seg = try yolov8n_seg()
            case (.segmentation, .small):
                guard #available(iOS 15.0, *) else {
                    fatalError("YOLOv8-seg model has not been implemented")
                }

                self.models_seg = try yolov8s_seg()
            default:
                fatalError("Other models has not been implemented")
        }
    }

    func predict(image: CVPixelBuffer) throws -> Output {
        switch (self.tasks, self.weights) {
            case (.detection, .nano) where self.modeln != nil:
                let result = try self.modeln!.prediction(image: image, iouThreshold: 0.45, confidenceThreshold: 0.25)

                return Output(output: result.coordinates, proto: nil)
            case (.detection, .small) where self.models != nil:
                let result = try self.models!.prediction(image: image, iouThreshold: 0.45, confidenceThreshold: 0.25)

                return Output(output: result.coordinates, proto: nil)
            case (.segmentation, .nano):
                guard #available(iOS 15.0, *), self.modeln_seg != nil else {
                    fatalError("YOLOv8-seg model has not been implemented")
                }

                let result = try self.modeln_seg!.prediction(image: image)

                return Output(output: result.var_1053, proto: result.p)

            case (.segmentation, .small):
                guard #available(iOS 15.0, *), self.models_seg != nil else {
                    fatalError("YOLOv8-seg model has not been implemented")
                }

                let result = try self.models_seg!.prediction(image: image)

                return Output(output: result.var_1053, proto: result.p)
            default:
                fatalError("Other models has not been implemented")
        }
    }
}
