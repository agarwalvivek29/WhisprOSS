//
//  SidebarView.swift
//  WhisprOSS
//
//  Sidebar navigation for the main app
//

import SwiftUI

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @EnvironmentObject var controller: ConversationController

    var body: some View {
        List(NavigationItem.allCases, selection: $selection) { item in
            NavigationLink(value: item) {
                Label(item.label, systemImage: item.icon)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("WhisprOSS")
        .safeAreaInset(edge: .bottom) {
            statusFooter
        }
    }

    private var statusFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(controller.isRecording ? Color.red : Color.green)
                .frame(width: 8, height: 8)

            Text(controller.isRecording ? "Recording..." : "Ready")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

#Preview {
    SidebarView(selection: .constant(.home))
        .environmentObject(ConversationController(
            llm: LiteLLMClient(config: .init(baseURL: URL(string: "http://127.0.0.1:4000")!, apiKey: nil)),
            settings: AppSettings()
        ))
        .frame(width: 220)
}
