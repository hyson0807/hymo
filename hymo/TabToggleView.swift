import SwiftUI

/// 헤더의 Hymo | Server 글래스 pill 토글.
struct TabToggleView: View {
    @Binding var selection: AppTab
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                segment(tab)
            }
        }
        .padding(2)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private func segment(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Text(tab.title)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.12))
                        .matchedGeometryEffect(id: "tabHighlight", in: highlight)
                }
            }
            .contentShape(Capsule())
            .onTapGesture {
                guard selection != tab else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selection = tab
                }
            }
    }
}
