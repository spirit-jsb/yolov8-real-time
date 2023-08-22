//
//  MainView.swift
//  yolov8-real-time
//
//  Created by JONO-Jsb on 2023/8/22.
//

import SwiftUI

struct MainView: View {
    @State
    private var showObjectDetection = false
    @State
    private var showObjectSegmentation = false

    var body: some View {
        VStack(spacing: 15.0) {
            self.button(title: "Detect", subtitle: "Identifying the location and class of objects") {
                self.showObjectDetection.toggle()
            }
            self.button(title: "Segment", subtitle: "Identifying individual objects and segmenting them from the rest") {
                self.showObjectSegmentation.toggle()
            }
        }
        .fullScreenCover(isPresented: self.$showObjectDetection) {
            PredictView()
        }
        .fullScreenCover(isPresented: self.$showObjectSegmentation) {
            PredictView()
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func button(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4.0) {
                Text(title)
                    .font(.system(size: 20.0)).bold()
                Text(subtitle)
                    .font(.system(size: 12.0))
                    .lineLimit(2)
            }
            .foregroundColor(Color.white)
            .padding(8.0)
            .frame(maxWidth: 250.0)
            .background(
                RoundedRectangle(cornerRadius: 15.0, style: .continuous)
                    .fill(Color.blue)
            )
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
