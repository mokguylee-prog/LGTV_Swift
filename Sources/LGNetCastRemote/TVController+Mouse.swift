import Foundation

// MARK: - Mouse / Touchpad Input

extension TVController {

    @discardableResult
    func setMouseCursorVisible(_ visible: Bool) async -> Bool {
        guard visible else { return true }
        // A tiny move wakes the TV cursor without displacing the user's pointer.
        let shown = await sendLegacyTouchCommand(
            type:   "HandleTouchMove",
            fields: "<x>1</x>\n            <y>0</y>",
            timeout: 1.5
        )
        if shown {
            _ = await sendLegacyTouchCommand(
                type:   "HandleTouchMove",
                fields: "<x>-1</x>\n            <y>0</y>",
                timeout: 1.5
            )
        }
        return shown
    }

    @discardableResult
    func sendMouseMove(deltaX: Int, deltaY: Int) async -> Bool {
        guard deltaX != 0 || deltaY != 0 else { return true }
        return await sendLegacyTouchCommand(
            type:      "HandleTouchMove",
            fields:    "<x>\(deltaX)</x>\n            <y>\(deltaY)</y>",
            keepAlive: true,
            timeout:   1.5
        )
    }

    @discardableResult
    func sendMouseClick() async -> Bool {
        _ = await setMouseCursorVisible(true)
        return await sendLegacyTouchCommand(type: "HandleTouchClick", timeout: 2)
    }

    @discardableResult
    func sendMouseWheel(up: Bool) async -> Bool {
        _ = await setMouseCursorVisible(true)
        let ok = await sendLegacyTouchCommand(
            type:    "HandleTouchWheel",
            fields:  "<value>\(up ? "up" : "down")</value>",
            timeout: 2
        )
        if !ok { statusMessage = "이 TV는 터치패드 휠 명령을 지원하지 않습니다" }
        return ok
    }
}
