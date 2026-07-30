import AuthenticationServices
import Foundation
import Observation

/// Sign in with Apple state, persisted across launches.
/// Storage is intentionally minimal: the user identifier (sub) plus the
/// display name we got the one time Apple shares it. No tokens, no email —
/// we don't need them for an offline-first study app, and Sign in with
/// Apple only hands the display name back on the very first authorization.
@MainActor
@Observable
final class AppleAuthService {
    private static let userIdKey = "auth.appleUserId"
    private static let displayNameKey = "auth.appleDisplayName"

    private(set) var userId: String?
    private(set) var displayName: String?
    private(set) var lastError: String?

    var isSignedIn: Bool { userId != nil }

    init() {
        let defaults = UserDefaults.standard
        userId = defaults.string(forKey: Self.userIdKey)
        displayName = defaults.string(forKey: Self.displayNameKey)
        if let userId { revalidate(userId: userId) }
    }

    func handle(result: Result<ASAuthorization, Error>) {
        lastError = nil
        switch result {
        case .failure(let error):
            // Cancelations come through as a thrown error — silence them.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            lastError = error.localizedDescription
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            store(userId: credential.user, displayName: name.isEmpty ? nil : name)
        }
    }

    func signOut() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.userIdKey)
        defaults.removeObject(forKey: Self.displayNameKey)
        userId = nil
        displayName = nil
    }

    /// Permanently deletes the account. This app keeps no server-side account —
    /// the only account data is the Apple user identifier and display name held
    /// in UserDefaults — so deletion means erasing that stored identity. The
    /// caller (AppSession) additionally wipes the associated study data so no
    /// user-shared data remains, satisfying App Store Guideline 5.1.1(v).
    func deleteAccount() {
        signOut()
    }

    private func store(userId: String, displayName: String?) {
        let defaults = UserDefaults.standard
        defaults.set(userId, forKey: Self.userIdKey)
        self.userId = userId
        // Apple only sends the name on the first auth — only overwrite when
        // we actually got one, otherwise we'd erase what we had.
        if let displayName {
            defaults.set(displayName, forKey: Self.displayNameKey)
            self.displayName = displayName
        }
    }

    /// Apple recommends checking that a stored credential is still valid on
    /// app launch; if the user revoked or signed out from Settings.app, we
    /// clear our state silently.
    private func revalidate(userId: String) {
        #if DEBUG
        // In the screenshot harness we seed a signed-in identity that has no
        // real Apple credential, so skip revalidation (it would sign us out).
        if ScreenshotMode.isActive { return }
        #endif
        let provider = ASAuthorizationAppleIDProvider()
        provider.getCredentialState(forUserID: userId) { [weak self] state, _ in
            guard state != .authorized else { return }
            Task { @MainActor in self?.signOut() }
        }
    }
}
