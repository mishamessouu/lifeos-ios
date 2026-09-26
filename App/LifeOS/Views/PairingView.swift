import LifeOSKit
import SwiftUI

/// Paste the link the box prints, or type the code. Scanning a QR code is a later step.
@MainActor
struct PairingView: View {
    @Environment(AppModel.self) private var model
    @State private var link = ""
    @State private var address = ""
    @State private var name = "iPhone"
    @State private var busy = false

    private var input: PairingInput? { PairingInput.parse(link) }
    private var needsAddress: Bool { input != nil && input?.kernel == nil }
    private var canPair: Bool {
        guard let input else { return false }
        return input.kernel != nil || KernelAddress.parse(address) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(Copy.pairLinkPlaceholder, text: $link, axis: .vertical)
                        .lineLimit(1...4)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityLabel(Copy.pairLinkHeader)
                        .accessibilityIdentifier("pairing.link")
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first {
                            link = first
                        }
                    }
                } header: {
                    Text(Copy.pairLinkHeader)
                } footer: {
                    Text(Copy.pairFooter)
                }

                if needsAddress {
                    Section {
                        TextField("https://", text: $address)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .accessibilityLabel(Copy.kernelAddress)
                    } header: {
                        Text(Copy.kernelAddress)
                    } footer: {
                        Text(Copy.kernelAddressFooter)
                    }
                }

                Section {
                    TextField(Copy.deviceName, text: $name)
                        .accessibilityLabel(Copy.deviceName)
                } header: {
                    Text(Copy.deviceName)
                }

                Section {
                    Button {
                        pair()
                    } label: {
                        HStack {
                            Text(Copy.pairButton)
                            Spacer()
                            if busy {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!canPair || busy)
                    .accessibilityIdentifier("pairing.button")
                } footer: {
                    if let status = model.status {
                        Text(status)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Copy.pairTitle)
        }
    }

    private func pair() {
        busy = true
        Task {
            _ = await model.pair(text: link, address: address, name: name)
            busy = false
        }
    }
}
