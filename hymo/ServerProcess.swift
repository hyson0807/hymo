import Foundation

/// 현재 LISTEN 중인 로컬 TCP 서버 한 개(프로세스 + 포트 단위).
struct ServerProcess: Identifiable, Equatable {
    let pid: pid_t
    let command: String        // lsof 'c' — 짧은 프로세스명 (node, ruby, Python …)
    let port: Int
    let address: String        // *, 127.0.0.1, [::1] …
    var fullCommand: String?   // ps -o command= — 표시용 전체 명령줄
    var isPaused: Bool
    var isSystem: Bool = false // 시스템 데몬 / GUI 앱이면 true (기본 목록에서 숨김)

    // (pid, port) 단위로 유일 — IPv4/IPv6 중복 listen은 같은 id로 합쳐진다.
    var id: String { "\(pid)-\(port)" }
}
