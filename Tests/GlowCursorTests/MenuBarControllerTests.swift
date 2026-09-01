import Testing
import ServiceManagement
@testable import GlowCursor

@Test func loginItemIsOnOnlyWhenServiceEnabled() {
    #expect(MenuBarController.loginItemIsOn(.enabled) == true)
    #expect(MenuBarController.loginItemIsOn(.notRegistered) == false)
    #expect(MenuBarController.loginItemIsOn(.requiresApproval) == false)
    #expect(MenuBarController.loginItemIsOn(.notFound) == false)
}
