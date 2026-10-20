import AppKit
import PetGeometry

enum CharacterKind: String, CaseIterable { case chiikawa, hachiware, usagi }

struct CharacterProfile {
    let kind: CharacterKind
    init(kind: CharacterKind) { self.kind = kind }
    init(isHachiware: Bool) { kind = isHachiware ? .hachiware : .chiikawa }
    static var all: [CharacterProfile] { CharacterKind.allCases.map { CharacterProfile(kind: $0) } }
    static let current = CharacterProfile(kind: CommandLine.arguments.contains("--usagi") ? .usagi :
        (CommandLine.arguments.contains("--hachiware") ? .hachiware : .chiikawa))
    var isHachiware: Bool { kind == .hachiware }
    var isUsagi: Bool { kind == .usagi }
    var usesSpriteClip: Bool { kind != .chiikawa }
    var name: String {
        switch kind { case .chiikawa: return "치이카와"; case .hachiware: return "하치와레"; case .usagi: return "우사기" }
    }
    var role: String {
        switch kind { case .chiikawa: return "자동화 검수"; case .hachiware: return "BOM 업무"; case .usagi: return "회의·개인 일정" }
    }
    var style: CompanionMotion {
        switch kind { case .chiikawa: return .chiikawa; case .hachiware: return .hachiware; case .usagi: return .usagi }
    }
    var bottomPadding: CGFloat { isHachiware ? 18 : 0 }
    var bodyHeight: CGFloat { isUsagi ? 144 : 108 }
    var horizontalPadding: CGFloat { isUsagi ? 18 : 0 }
    var greeting: String {
        switch kind {
        case .chiikawa: return "히러.."
        case .hachiware: return "있잖아~ 고거 확인했어? BOM 말이야"
        case .usagi: return "이야아아아하!!!!!!!"
        }
    }
    var happyActionTitle: String { isUsagi ? "빙글빙글 돌기" : "기뻐하기" }
    var startOffset: CGFloat {
        switch kind { case .chiikawa: return -170; case .hachiware: return 0; case .usagi: return 170 }
    }
    func alertDetail(bomCount: Int) -> String {
        switch kind {
        case .chiikawa: return "자동화 검수 테스트 알림"
        case .hachiware: return "확인할 BOM 업무 \(bomCount)개 · 테스트"
        case .usagi: return "회의·개인 일정 테스트 알림"
        }
    }
    func asset(for state: String) -> String {
        if isUsagi {
            switch state {
            case "held": return "Usagi Daerong.gif"
            case "rest": return "Usagi Updream.gif"
            case "happy": return "Usagi turn.gif"
            case "run": return "Usagi run.gif"
            case "notify": return "Usagi Scream.gif"
            case "fall", "jump": return "Usagi drop.png"
            default: return "Usagi Walk.gif"
            }
        }
        if isHachiware {
            switch state {
            case "held": return "Hachiware hang.gif"
            case "rest": return "Hachiware sit.gif"
            case "happy": return "Hachiware happy.gif"
            case "run": return "Hachiware run.gif"
            case "notify": return "Hachiware talk.gif"
            case "fall", "jump": return "Hachiware Drop.png"
            default: return "Hachiware Walk.gif"
            }
        }
        switch state {
        case "held": return "chiikawa-held-sway.gif"
        case "notify": return "chiikawa-tremble-marks-only.gif"
        case "run": return "Chiikawa run.gif"
        case "rest": return "Chiikawa Updream.png"
        case "happy": return "Chiikawa Dance.gif"
        case "fall", "jump": return "Chiikawa Drop.png"
        default: return "Chiikawa Walk.gif"
        }
    }
}

func spriteURL(_ name: String) -> URL? {
    Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Resources")
        ?? Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Resources")
}
