import LifeOSKit
import SwiftUI
import UIKit

/// The device, the kernel address, notifications, and unpair.
@MainActor
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @State private var address = ""
    @State private var addressProblem: String?
    @State private var confirmUnpair = false

    private var notificationLine: String {
        switch model.notificationsAllowed {
        case .some(true): return Copy.notificationsOn
        case .some(false): return Copy.notificationsOff
        case .none: return Copy.notificationsUnknown
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let credentials = model.credentials {
                    Section(Copy.deviceSection) {
                        LabeledContent(Copy.deviceName, value: credentials.deviceName)
                        LabeledContent(Copy.deviceID, value: credentials.deviceID)
                    }

                    Section {
                        TextField("https://", text: $address)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityLabel(Copy.kernelAddress)
                        Button(Copy.save) {
                            if model.changeKernel(to: address) {
                                addressProblem = nil
                            } else {
                                addressProblem = Copy.badAddress
                            }
                        }
                        .disabled(KernelAddress.parse(address) == nil || KernelAddress.parse(address) == credentials.kernel)
                    } header: {
                        Text(Copy.kernelAddress)
                    } footer: {
                        if let addressProblem {
                            Text(addressProblem)
                                .foregroundStyle(.red)
                        }
                    }

                    Section(Copy.notificationsSection) {
                        LabeledContent(Copy.notifications, value: notificationLine)
                        if model.notificationsAllowed == false {
                            Button(Copy.openSettings) {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                    openURL(url)
                                }
                            }
                        }
                    }

                    Section {
                        Button(Copy.unpair, role: .destructive) {
                            confirmUnpair = true
                        }
                    } footer: {
                        Text(Copy.unpairFooter)
                    }
                }
            }
            .navigationTitle(Copy.settingsTitle)
            .onAppear {
                address = model.credentials?.kernel.absoluteString ?? ""
            }
            .task {
                await model.refreshNotificationSetting()
            }
            .confirmationDialog(Copy.unpairQuestion, isPresented: $confirmUnpair, titleVisibility: .visible) {
                Button(Copy.unpair, role: .destructive) {
                    model.unpair()
                }
            }
        }
    }
}
