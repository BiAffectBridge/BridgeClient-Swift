// Created 7/18/24
// swift-version:5.0

import SwiftUI
import BridgeClientExtension

/// A general purpose implementation of the header view when there are no assessments currently available
/// that does not directly tie to the backing view models.
struct UploadingMessageView : View {
    @Binding var networkStatus: NetworkStatus
    let isNextSessionSoon: Bool
    let hasSessionAvailableNow: Bool
    
    var body: some View {
        if networkStatus.contains(.notConnected) || !hasSessionAvailableNow {
            uploadingView()
        } else {
            EmptyView()
        }
    }
        
    @ViewBuilder
    func uploadingView() -> some View {
        VStack(alignment: .center, spacing: 24) {
            if networkStatus.contains(.notConnected) {
                Image(systemName: "wifi.exclamationmark")
                    .scaleEffect(x: 1.5, y: 1.5, anchor: .center)
                    .foregroundColor(.errorRed)
            } else {
                progressSpinner()
            }
            uploadingMessageText()
                .italic()
        }
        .padding()
    }
    
    @ViewBuilder
    func progressSpinner() -> some View {
        if #available(iOS 15.0, *) {
            ProgressView()
                .tint(.accentColor)
                .scaleEffect(x: 1.5, y: 1.5, anchor: .center)
        } else {
            ProgressView()
        }
    }
    
    @ViewBuilder
    func uploadingMessageText() -> some View {
        switch networkStatus {
        case .cellularDenied:
            Text("Connect to WiFi or turn on cellular data in your phone's \"Settings\" to allow the app to upload your results.", bundle: .module)
        case .notConnected:
            Text("Please connect to the internet to upload your results.", bundle: .module)
        default:
            if isNextSessionSoon || hasSessionAvailableNow {
                Text("Your results are uploading...", bundle: .module)
            } else {
                Text("Your results are uploading. Please wait to close the app.", bundle: .module)
            }
        }
    }
}

// Used to allow previewing the UploadingMessageView.
fileprivate struct PreviewUploadingMessageView : View {
    @State var networkStatus: NetworkStatus = .notConnected
    @State var isNextSessionSoon: Bool = true
    @State var hasSessionAvailableNow: Bool = false
    
    var body: some View {
        VStack {
            UploadingMessageView(
                networkStatus: $networkStatus,
                isNextSessionSoon: isNextSessionSoon,
                hasSessionAvailableNow: hasSessionAvailableNow
            )
            Spacer()
            Form {
                Toggle("isNextSessionSoon", isOn: $isNextSessionSoon)
                Toggle("hasSessionAvailableNow", isOn: $hasSessionAvailableNow)
                Picker("Network Connection", selection: $networkStatus) {
                    ForEach(NetworkStatus.allCases, id: \.self) { value in
                        Text(value.stringValue)
                            .tag(value)
                    }
                }
            }
        }
    }
}

#Preview {
    PreviewUploadingMessageView()
}
