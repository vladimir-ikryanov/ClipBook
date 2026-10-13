import Foundation
import AppKit
import ServiceManagement

enum LaunchAtLoginService {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("ClipBook launch-at-login update failed: \(error.localizedDescription)")
            }
        }
    }
}
