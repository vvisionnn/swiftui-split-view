import SwiftUI

public struct SplitView<Sidebar: View, Content: View>: View {
	@State private var offset: Double = .zero
	@State private var lastDragOffset: Double = .zero
	@State private var progress: Double = .zero
	@State var sidebar: @MainActor () -> Sidebar
	@State var content: @MainActor () -> Content
	@State var sidebarWidth: Double
	@State var style: Style

	@MainActor
	public init(
		style: Style = .swipeShow,
		sidebarWidth: Double = 270,
		@ViewBuilder sidebar: @escaping @MainActor () -> Sidebar,
		@ViewBuilder content: @escaping @MainActor () -> Content
	) {
		self.sidebarWidth = sidebarWidth
		self.style = style
		self.sidebar = sidebar
		self.content = content
	}

	@MainActor
	@ViewBuilder
	var swipeShowBody: some View {
		GeometryReader { proxy in
			let maxWidth = proxy.size.width
			let sidebarWidth = min(sidebarWidth, maxWidth)
			ZStack(alignment: .leading) {
				sidebar()
					.frame(width: sidebarWidth)
					.offset(x: offset - sidebarWidth)
					.overlay(alignment: .trailing) {
						Rectangle()
							.frame(width: 1)
							.frame(maxHeight: .infinity)
							.foregroundStyle(Color(uiColor: .separator))
							.ignoresSafeArea()
					}
					.disabled(progress != 0 && progress != 1)
				content()
					.overlay(content: {
						Rectangle()
							.opacity(0.3 * progress)
							.ignoresSafeArea()

					})
					.offset(x: offset)
			}
			.simultaneousGesture(
				DragGesture()
					.onChanged { val in
						let translation = val.translation.width + lastDragOffset
						offset = max(0, min(translation, sidebarWidth))
						progress = max(0, min(offset / sidebarWidth, 1))
					}
					.onEnded { val in
						defer { lastDragOffset = offset }
						withAnimation(.snappy(duration: 0.25, extraBounce: .zero)) {
							if offset > (sidebarWidth / 2) {
								offset = sidebarWidth
								progress = 1
							} else {
								offset = 0
								progress = 0
							}
						}
					}
			)
		}
	}

	@MainActor
	@ViewBuilder
	var alwaysShowBody: some View {
		GeometryReader { proxy in
			let maxWidth = proxy.size.width
			let sidebarWidth = min(sidebarWidth, maxWidth)
			HStack(spacing: .zero) {
				sidebar()
					.frame(width: sidebarWidth)
				Divider()
					.foregroundStyle(Color(uiColor: .separator))
					.ignoresSafeArea()
				content()
			}
		}
	}

	@MainActor
	public var body: some View {
		switch style {
		case .alwaysShow: AnyView(alwaysShowBody)
		case .swipeShow: AnyView(swipeShowBody)
		}
	}
}

extension SplitView {
	public enum Style: Int, CaseIterable {
		case alwaysShow
		case swipeShow
	}
}

#Preview("Always Show Sidebar", body: {
	SplitView(style: .alwaysShow) {
		Rectangle()
			.foregroundStyle(Color(uiColor: .systemGreen))
			.ignoresSafeArea()
	} content: {
		Rectangle()
			.foregroundStyle(Color(uiColor: .systemMint))
			.ignoresSafeArea()
	}
})

#Preview("Swipe Show Sidebar", body: {
	SplitView(style: .swipeShow) {
		ScrollView(.vertical) {
			LazyVStack {
				ForEach(0 ..< 100) { index in
					Button(action: {
						debugPrint("item index: \(index)")
					}) {
						Text("Item \(index)")
							.foregroundStyle(Color(uiColor: .label))
							.frame(maxWidth: .infinity)
							.padding()
							.background(Color(uiColor: .secondarySystemBackground))
					}
				}
			}
		}
	} content: {
		Rectangle()
			.foregroundStyle(Color(uiColor: .systemMint))
			.ignoresSafeArea()
	}
})
