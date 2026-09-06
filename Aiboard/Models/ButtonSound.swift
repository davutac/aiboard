import Defaults
import Foundation

// MARK: - ButtonSound
nonisolated enum ButtonSound: String, CaseIterable, Defaults.Serializable, Sendable {
    case none
    case keyClick
    case custom
    case cherryMXBlack = "kbsim-mxblack"
    case cherryMXBrown = "kbsim-mxbrown"
    case cherryMXBlue = "kbsim-mxblue"
    case gateronBlackInk = "kbsim-blackink"
    case gateronRedInk = "kbsim-redink"
    case kailhBoxNavy = "kbsim-boxnavy"
    case novelKeysCream = "kbsim-cream"
    case holyPanda = "kbsim-holypanda"
    case alpaca = "kbsim-alpaca"
    case turquoiseTealios = "kbsim-turquoise"
    case blueAlps = "kbsim-bluealps"
    case topre = "kbsim-topre"
    case bucklingSpring = "kbsim-buckling"

    static let mechanicalSwitches = allCases.filter {
        $0 != .none && $0 != .keyClick && $0 != .custom
    }

    // MARK: - Display
    var title: String {
        switch self {
        case .none: "None"
        case .keyClick: "Key Click (Default)"
        case .custom: "Custom file"
        case .cherryMXBlack: "Cherry MX Black"
        case .cherryMXBrown: "Cherry MX Brown"
        case .cherryMXBlue: "Cherry MX Blue"
        case .gateronBlackInk: "Gateron Black Ink"
        case .gateronRedInk: "Gateron Red Ink"
        case .kailhBoxNavy: "Kailh Box Navy"
        case .novelKeysCream: "NovelKeys Cream"
        case .holyPanda: "Holy Panda"
        case .alpaca: "Alpaca"
        case .turquoiseTealios: "Turquoise Tealios"
        case .blueAlps: "SKCM Blue Alps"
        case .topre: "Topre"
        case .bucklingSpring: "Buckling Spring"
        }
    }

    // MARK: - Resources
    var fileURL: URL? {
        switch self {
        case .none, .custom:
            nil
        case .keyClick:
            URL(
                fileURLWithPath:
                    "/System/Library/Input Methods/Assistive Control.app/Contents/Resources/SoundPressKey.aiff"
            )
        default:
            Bundle.main.url(forResource: rawValue, withExtension: "wav")
        }
    }
}

// MARK: - StoredButtonSound
nonisolated struct StoredButtonSound: Codable, Defaults.Serializable, Equatable, Sendable {
    let fileName: String
    let displayName: String
}
