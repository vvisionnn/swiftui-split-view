//
//  DragGestureViewModifier.swift
//  swiftui-split-view
//
//  Created by Andy Wen on 9/14/24.
//

import SwiftUI

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
