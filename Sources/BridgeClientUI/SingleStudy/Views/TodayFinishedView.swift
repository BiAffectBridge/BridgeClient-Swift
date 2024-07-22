// Created 2/21/23
// swift-tools-version:5.0

import SwiftUI
import BridgeClientExtension
import SharedMobileUI

/// Wrapped `UploadingMessageView` for use with MobileToolboxApp or other apps that do not require
/// subclassing the app manager or today timeline view model because EnvironmentObjects must be final.
struct TodayFinishedView : View {

    var body: some View {
        ZStack {
            Image(decorative: "available_complete", bundle: .module)
            Text("Nice, you’re all up to date!", bundle: .module)
                // TODO: syoung 09/23/2021 Cut the image so that I can make this text dynamic.
                .font(.latoFont(fixedSize: 18))
        }
        .padding(.vertical, 24)
    }
}

#Preview {
    TodayFinishedView()
}
