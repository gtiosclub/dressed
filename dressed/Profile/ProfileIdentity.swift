import Foundation

// There is no UserProfile service yet, so the signed-in user's own name comes from their
// Firebase account: its display name when set, otherwise the part of the email before "@".
// The result is shown only to that user and is never written to a post.

/// The name to show on the user's own profile, or nil when the account has neither value.
func profileDisplayName(displayName: String?, email: String?) -> String? {
    if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
        return name
    }
    guard let local = email?.split(separator: "@", omittingEmptySubsequences: false).first?
        .trimmingCharacters(in: .whitespacesAndNewlines), !local.isEmpty else { return nil }
    return local
}

/// The uppercase first letter or digit of `name`, or "?" when it has none.
func profileInitial(_ name: String?) -> String {
    guard let first = name?.first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
    return String(first).uppercased()
}
