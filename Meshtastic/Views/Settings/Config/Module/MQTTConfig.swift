//
//  MQTT.swift
//  Meshtastic
//
//  Copyright (c) Garth Vander Houwen 9/4/22.
//
import SwiftUI

struct MQTTConfig: View {

	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager
	@Environment(\.dismiss) private var goBack
	var node: NodeInfoEntity?
	@State private var isPresentingSaveConfirm: Bool = false
	@State var hasChanges: Bool = false
	@State var enabled = false
	@State var address = ""
	@State var username = ""
	@State var password = ""
	@State var encryptionEnabled = false
	@State var jsonEnabled = false

	var body: some View {

		Form {
			if node != nil && node?.metadata == nil && node?.num ?? 0 != bleManager.connectedPeripheral?.num ?? 0 {
				Text("There has been no response to a request for device metadata over the admin channel for this node.")
					.font(.callout)
					.foregroundColor(.orange)

			} else if node != nil && node?.num ?? 0 != bleManager.connectedPeripheral?.num ?? 0 {
				// Let users know what is going on if they are using remote admin and don't have the config yet
				if node?.mqttConfig == nil {
					Text("MQTT config data was requested over the admin channel but no response has been returned from the remote node. You can check the status of admin message requests in the admin message log.")
						.font(.callout)
						.foregroundColor(.orange)
				} else {
					Text("Remote administration for: \(node?.user?.longName ?? "Unknown")")
						.font(.title3)
				}
			} else if node != nil && node?.num ?? 0 == bleManager.connectedPeripheral?.num ?? 0 {
				Text("Configuration for: \(node?.user?.longName ?? "Unknown")")
					.font(.title3)
			} else {
				Text("Please connect to a radio to configure settings.")
					.font(.callout)
					.foregroundColor(.orange)
			}
			Section(header: Text("options")) {
				Toggle(isOn: $enabled) {

					Label("enabled", systemImage: "dot.radiowaves.right")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))

				Toggle(isOn: $encryptionEnabled) {

					Label("Encryption Enabled", systemImage: "lock.icloud")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))

				Toggle(isOn: $jsonEnabled) {

					Label("JSON Enabled", systemImage: "ellipsis.curlybraces")
				}
				.toggleStyle(SwitchToggleStyle(tint: .accentColor))
			}
			Section(header: Text("Custom Server")) {
				HStack {
					Label("Address", systemImage: "server.rack")
					TextField("Server Address", text: $address)
						.foregroundColor(.gray)
						.autocapitalization(.none)
						.disableAutocorrection(true)
						.onChange(of: address, perform: { _ in
							let totalBytes = address.utf8.count
							// Only mess with the value if it is too big
							if totalBytes > 30 {
								let firstNBytes = Data(username.utf8.prefix(30))
								if let maxBytesString = String(data: firstNBytes, encoding: String.Encoding.utf8) {
									// Set the shortName back to the last place where it was the right size
									address = maxBytesString
								}
							}
							hasChanges = true
						})
						.foregroundColor(.gray)
						.keyboardType(.default)
				}
				.autocorrectionDisabled()

				HStack {
					Label("mqtt.username", systemImage: "person.text.rectangle")
					TextField("mqtt.username", text: $username)
						.foregroundColor(.gray)
						.autocapitalization(.none)
						.disableAutocorrection(true)
						.onChange(of: username, perform: { _ in

							let totalBytes = username.utf8.count

							// Only mess with the value if it is too big
							if totalBytes > 62 {

								let firstNBytes = Data(username.utf8.prefix(62))

								if let maxBytesString = String(data: firstNBytes, encoding: String.Encoding.utf8) {

									// Set the shortName back to the last place where it was the right size
									username = maxBytesString
								}
							}
							hasChanges = true
						})
						.foregroundColor(.gray)
				}
				.keyboardType(.default)
				.scrollDismissesKeyboard(.interactively)
				HStack {
					Label("password", systemImage: "wallet.pass")
					TextField("password", text: $password)
						.foregroundColor(.gray)
						.autocapitalization(.none)
						.disableAutocorrection(true)
						.onChange(of: password, perform: { _ in

							let totalBytes = password.utf8.count

							// Only mess with the value if it is too big
							if totalBytes > 62 {

								let firstNBytes = Data(password.utf8.prefix(62))

								if let maxBytesString = String(data: firstNBytes, encoding: String.Encoding.utf8) {

									// Set the shortName back to the last place where it was the right size
									password = maxBytesString
								}
							}
							hasChanges = true
						})
						.foregroundColor(.gray)
				}
				.keyboardType(.default)
				.scrollDismissesKeyboard(.interactively)
			}
			Text("WiFi or Ethernet must also be enabled for MQTT to work. You can set uplink and downlink for each channel.")
				.font(.callout)
		}
		.scrollDismissesKeyboard(.interactively)
		.disabled(self.bleManager.connectedPeripheral == nil || node?.mqttConfig == nil)

		Button {
			isPresentingSaveConfirm = true
		} label: {
			Label("save", systemImage: "square.and.arrow.down")
		}
		.disabled(bleManager.connectedPeripheral == nil || !hasChanges)
		.buttonStyle(.bordered)
		.buttonBorderShape(.capsule)
		.controlSize(.large)
		.padding()
		.confirmationDialog(
			"are.you.sure",
			isPresented: $isPresentingSaveConfirm,
			titleVisibility: .visible
		) {
			let connectedNode = getNodeInfo(id: bleManager.connectedPeripheral?.num ?? -1, context: context)
			if connectedNode != nil {
				let nodeName = node?.user?.longName ?? NSLocalizedString("unknown", comment: "Unknown")
				let buttonText = String.localizedStringWithFormat(NSLocalizedString("save.config %@", comment: "Save Config for %@"), nodeName)
				Button(buttonText) {
					var mqtt = ModuleConfig.MQTTConfig()
					mqtt.enabled = self.enabled
					mqtt.address = self.address
					mqtt.username = self.username
					mqtt.password = self.password
					mqtt.encryptionEnabled = self.encryptionEnabled
					mqtt.jsonEnabled = self.jsonEnabled
					let adminMessageId =  bleManager.saveMQTTConfig(config: mqtt, fromUser: connectedNode!.user!, toUser: node!.user!, adminIndex: connectedNode?.myInfo?.adminIndex ?? 0)
					if adminMessageId > 0 {
						// Should show a saved successfully alert once I know that to be true
						// for now just disable the button after a successful save
						hasChanges = false
						goBack()
					}
				}
			}
		}
		message: {
			Text("config.save.confirm")
		}
		.navigationTitle("mqtt.config")
		.navigationBarItems(trailing:
			ZStack {
				ConnectedDevice(bluetoothOn: bleManager.isSwitchedOn, deviceConnected: bleManager.connectedPeripheral != nil, name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName : "????")
		})
		.onAppear {
			self.bleManager.context = context
			self.enabled = (node?.mqttConfig?.enabled ?? false)
			self.address = node?.mqttConfig?.address ?? ""
			self.username = node?.mqttConfig?.username ?? ""
			self.password = node?.mqttConfig?.password ?? ""
			self.encryptionEnabled = (node?.mqttConfig?.encryptionEnabled ?? false)
			self.jsonEnabled = (node?.mqttConfig?.jsonEnabled ?? false)
			self.hasChanges = false

			// Need to request a TelemetryModuleConfig from the remote node before allowing changes
			if bleManager.connectedPeripheral != nil && node?.mqttConfig == nil {
				print("empty mqtt module config")
				let connectedNode = getNodeInfo(id: bleManager.connectedPeripheral.num, context: context)
				if node != nil && connectedNode != nil {
					_ = bleManager.requestMqttModuleConfig(fromUser: connectedNode!.user!, toUser: node!.user!, adminIndex: connectedNode?.myInfo?.adminIndex ?? 0)
				}
			}
		}
		.onChange(of: enabled) { newEnabled in
			if node != nil && node?.mqttConfig != nil {
				if newEnabled != node!.mqttConfig!.enabled { hasChanges = true }
			}
		}
		.onChange(of: encryptionEnabled) { newEncryptionEnabled in
			if node != nil && node?.mqttConfig != nil {
				if newEncryptionEnabled != node!.mqttConfig!.encryptionEnabled { hasChanges = true }
			}
		}
		.onChange(of: jsonEnabled) { newJsonEnabled in
			if node != nil && node?.mqttConfig != nil {
				if newJsonEnabled != node!.mqttConfig!.jsonEnabled { hasChanges = true }
			}
		}
	}
}
