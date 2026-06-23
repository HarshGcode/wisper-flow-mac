import Foundation
import Security

/// Self-protection: verifies the app's OWN code signature at launch.
///
/// macOS cryptographically seals every file in a signed .app bundle. If anyone
/// modifies the binary or injects code into the bundle AFTER it was signed
/// (a classic malware tactic), that seal breaks and `SecStaticCodeCheckValidity`
/// fails — so we can detect tampering and refuse to run.
///
/// This protects THIS app from being weaponized; it is not a system-wide virus
/// scanner.
enum IntegrityGuard {
    enum Status: Equatable {
        case verified          // signature intact, nothing modified
        case tampered(String)  // sealed files changed after signing — DANGER
        case unsigned          // no signature to check (e.g. raw dev build)
        case unknown(String)   // couldn't run the check

        var isSafe: Bool {
            switch self {
            case .verified, .unsigned, .unknown: return true
            case .tampered: return false
            }
        }

        var menuLabel: String {
            switch self {
            case .verified:        return "🔒 Integrity: Verified"
            case .tampered:        return "⚠️ Integrity: TAMPERED"
            case .unsigned:        return "🔓 Integrity: Unsigned build"
            case .unknown:         return "🔒 Integrity: Unknown"
            }
        }
    }

    static func check() -> Status {
        // 1. Reference to the currently running code.
        var codeRef: SecCode?
        let copyStatus = SecCodeCopySelf(SecCSFlags(), &codeRef)
        guard copyStatus == errSecSuccess, let code = codeRef else {
            return .unknown("SecCodeCopySelf failed (\(copyStatus))")
        }

        // 2. Its on-disk (static) representation, so we validate the whole bundle seal.
        var staticRef: SecStaticCode?
        let staticStatus = SecCodeCopyStaticCode(code, SecCSFlags(), &staticRef)
        guard staticStatus == errSecSuccess, let staticCode = staticRef else {
            return .unknown("SecCodeCopyStaticCode failed (\(staticStatus))")
        }

        // 3. Validate: checks the signature AND that no sealed file was modified.
        //    kSecCSStrictValidate enforces full resource-seal checking (so a changed
        //    icon, plist, or any bundled file is caught, not just the main binary).
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures
                                       | kSecCSCheckNestedCode
                                       | kSecCSStrictValidate)
        let result = SecStaticCodeCheckValidity(staticCode, flags, nil)

        switch result {
        case errSecSuccess:
            return .verified
        case errSecCSUnsigned:
            return .unsigned
        case errSecCSBadResource, errSecCSResourceRulesInvalid, errSecCSResourceNotSupported:
            return .tampered("a file in the app was modified after signing")
        case errSecCSSignatureFailed, errSecCSSignatureInvalid:
            return .tampered("the code signature is invalid")
        default:
            return .tampered("signature check failed (\(result))")
        }
    }
}
