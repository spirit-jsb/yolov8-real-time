//
//  EnvironmentValuesExtensions.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/22.
//

import SwiftUI

extension EnvironmentValues {
    var dismissable: () -> Void {
        return self.dismissAction
    }
}

private extension EnvironmentValues {
    func dismissAction() {
        if #available(iOS 15.0, *) {
            self.dismiss()
        } else {
            self.presentationMode.wrappedValue.dismiss()
        }
    }
}
