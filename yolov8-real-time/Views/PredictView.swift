//
//  PredictView.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/22.
//

import SwiftUI

struct PredictView: View {
    @Environment(\.dismissable)
    var dismissable

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    self.button(systemName: "xmark") {
                        self.dismissable()
                    }

                    Spacer()
                }
                .padding()

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func button(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 40.0, height: 40.0)
                .foregroundColor(Color.white)
                .background(
                    RoundedRectangle(cornerRadius: 20.0, style: .continuous)
                        .fill(Color.black.opacity(0.3))
                )
        }
    }
}

struct PredictView_Previews: PreviewProvider {
    static var previews: some View {
        PredictView()
    }
}
