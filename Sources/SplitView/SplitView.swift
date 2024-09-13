import SwiftUI

public struct SplitView<Sidebar: View, Content: View>: View {
	private let animation: Animation = .snappy(duration: 0.25, extraBounce: .zero)
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

struct DragGestureViewModifier: ViewModifier {
	@GestureState private var isDragging: Bool = false
	@State var gestureState: GestureStatus = .idle

	var onStart: (() -> Void)?
	var onUpdate: ((DragGesture.Value) -> Void)?
	var onEnd: ((DragGesture.Value) -> Void)?
	var onCancel: (() -> Void)?

	func body(content: Content) -> some View {
		content
			.simultaneousGesture(
				DragGesture()
					.updating($isDragging) { _, isDragging, _ in
						isDragging = true
					}
					.onChanged(onDragChange(_:))
					.onEnded(onDragEnded(_:))
			)
			.onChange(of: gestureState) { state in
				guard state == .started else { return }
				gestureState = .active
			}
			.onChange(of: isDragging) { value in
				if value, gestureState != .started {
					gestureState = .started
					onStart?()
				} else if !value, gestureState != .ended {
					gestureState = .cancelled
					onCancel?()
				}
			}
	}

	func onDragChange(_ value: DragGesture.Value) {
		guard gestureState == .started || gestureState == .active else { return }
		onUpdate?(value)
	}

	func onDragEnded(_ value: DragGesture.Value) {
		gestureState = .ended
		onEnd?(value)
	}

	enum GestureStatus: Equatable {
		case idle
		case started
		case active
		case ended
		case cancelled
	}
}

extension View {
	func dragGesture(
		onStart: (() -> Void)? = nil,
		onUpdate: ((DragGesture.Value) -> Void)? = nil,
		onEnd: ((DragGesture.Value) -> Void)? = nil,
		onCancel: (() -> Void)? = nil
	) -> some View {
		modifier(DragGestureViewModifier(onStart: onStart, onUpdate: onUpdate, onEnd: onEnd, onCancel: onCancel))
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
