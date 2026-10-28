import Foundation

struct SafeMargin: Equatable {
    var top: Int = 0
    var right: Int = 0
    var bottom: Int = 0
    var left: Int = 0

    func toJson() -> [String: Any] {
        return ["top": top, "right": right, "bottom": bottom, "left": left]
    }
}

struct SdkParams {
    let safeMargin: SafeMargin

    func toJson() -> [String: Any] {
        return ["safeMargin": safeMargin.toJson()]
    }
}
