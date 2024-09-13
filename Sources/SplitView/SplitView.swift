import SwiftUI

public struct SplitView<Sidebar: View, Content: View>: View {
	private let animation: Animation = .snappy(duration: 0.25, extraBounce: .zero)
	@State private var offset: Double = .zero
	@State private var lastDragOffset: Double = .zero
	@State private var progress: Double = .zero
	@State var sidebar: @MainActor () -> Sidebar
	@State var content: @MainActor () -> Content
	@Binding var sidebarWidth: Double
	@State var style: Style

	@MainActor
	public init(
		style: Style = .swipeShow,
		sidebarWidth: Binding<Double> = .constant(270),
		@ViewBuilder sidebar: @escaping @MainActor () -> Sidebar,
		@ViewBuilder content: @escaping @MainActor () -> Content
	) {
		self._sidebarWidth = sidebarWidth
		self.style = style
		self.sidebar = sidebar
		self.content = content
	}

	@MainActor
	@ViewBuilder
	var swipeShowContent: some View {
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
							.ignoresSafeArea()
							.onTapGesture {
								guard progress == 1.0 else { return }
								withAnimation(animation) {
									progress = 0
									offset = 0
									lastDragOffset = 0
								}
							}
							.opacity(0.3 * progress)

					})
					.offset(x: offset)
			}
		}
	}

	@MainActor
	@ViewBuilder
	var swipeShowBody: some View {
		if #available(iOS 18.0, *) {
			swipeShowContent
				.gesture(SplitViewSwipeGesture(handle: { gesture in
					let state = gesture.state
					let translation = gesture.translation(in: gesture.view).x + lastDragOffset
					let velocity = gesture.velocity(in: gesture.view).x
					switch state {
					case .began, .changed:
						offset = max(0, min(translation, sidebarWidth))
						progress = max(0, min(offset / sidebarWidth, 1))
					default:
						defer { lastDragOffset = offset }
						withAnimation(animation) {
							if (velocity + offset) > (sidebarWidth / 2) {
								offset = sidebarWidth
								progress = 1
							} else {
								offset = 0
								progress = 0
							}
						}
					}
				}))
		} else {
			swipeShowContent
				.dragGesture(onUpdate: { val in
					let translation = val.translation.width + lastDragOffset
					offset = max(0, min(translation, sidebarWidth))
					progress = max(0, min(offset / sidebarWidth, 1))
				}, onEnd: { val in
					let velocity = val.translation.width / 3
					defer { lastDragOffset = offset }
					withAnimation(animation) {
						if (velocity + offset) > (sidebarWidth / 2) {
							offset = sidebarWidth
							progress = 1
						} else {
							offset = 0
							progress = 0
						}
					}
				}, onCancel: {
					defer { lastDragOffset = offset }
					withAnimation(animation) {
						if offset > (sidebarWidth / 2) {
							offset = sidebarWidth
							progress = 1
						} else {
							offset = 0
							progress = 0
						}
					}
				})
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

extension SplitView {
	struct SplitViewSwipeGesture: UIGestureRecognizerRepresentable {
		var handle: (UIPanGestureRecognizer) -> Void
		func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
			UIPanGestureRecognizer()
		}

		func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {}
		func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
			handle(recognizer)
		}
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
			.overlay {
				Text("Content")
			}
	}
})

#Preview("Swipe Show Sidebar", body: {
	SplitView(style: .swipeShow) {
		ScrollView(.vertical) {
			LazyVStack {
				ForEach(0 ..< 100) { index in
					Button(action: {}) {
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
			.overlay {
				Text("Content")
			}
	}
})

#if DEBUG
struct SidebarAdaptivePreviewView: View {
	@State var sidebarWidth: Double = 270
	@Namespace var namespace
	var body: some View {
		SplitView(style: .alwaysShow, sidebarWidth: $sidebarWidth) {
			NavigationStack {
				ScrollView(.vertical) {
					LazyVStack {
						ForEach(0 ..< 100) { index in
							Button(action: {
								withAnimation(.snappy(duration: 1)) {
									sidebarWidth = sidebarWidth == 270 ? 84 : 270
								}
							}) {
								ZStack(alignment: .center) {
									if sidebarWidth != 270 {
										HStack {
											Image(systemName: "gear")
												.transition(.opacity)
												.matchedGeometryEffect(id: "icon-\(index)", in: namespace)
										}
										.padding()
									} else {
										HStack {
											Image(systemName: "gear")
												.transition(.opacity)
												.matchedGeometryEffect(id: "icon-\(index)", in: namespace)
											
											Text("Item \(index)")
												.lineLimit(1)
											
											Spacer()
										}
										.background(Color.red)
										.foregroundStyle(Color(uiColor: .label))
										.frame(minWidth: .zero, maxWidth: .infinity)
										.padding()
									}
								}
								.background(
									RoundedRectangle(cornerRadius: 12, style: .continuous)
										.foregroundStyle(Color(uiColor: .secondarySystemBackground))
								)
								.padding(.horizontal)
							}
						}
					}
				}
			}
		} content: {
			Rectangle()
				.foregroundStyle(Color(uiColor: .systemMint))
				.ignoresSafeArea()
				.overlay {
					Text("Content")
				}
				.frame(maxWidth: .infinity)
		}
	}
}

#Preview("Always Show Sidebar Adaptive", body: {
	SidebarAdaptivePreviewView()
})
#endif
