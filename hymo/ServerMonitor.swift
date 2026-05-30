import Foundation
import Observation

/// LISTEN 중인 로컬 TCP 서버를 조회하고 Kill / Pause·Resume 한다.
/// 영속화 없음 — 항상 라이브 데이터.
@Observable
final class ServerMonitor {

    /// lsof가 조회한 전체 목록(시스템 포함).
    private(set) var allServers: [ServerProcess] = []
    var isRefreshing = false

    /// 시스템/앱 서버까지 모두 보일지 여부. 기본은 dev 서버만.
    var showSystem: Bool {
        didSet { UserDefaults.standard.set(showSystem, forKey: "showSystemServers") }
    }

    /// 화면에 보여줄 목록 — showSystem이 false면 dev 서버만.
    var servers: [ServerProcess] {
        showSystem ? allServers : allServers.filter { !$0.isSystem }
    }

    /// dev 필터로 가려진 시스템 서버 수.
    var hiddenSystemCount: Int {
        allServers.lazy.filter { $0.isSystem }.count
    }

    @ObservationIgnored private var timer: Timer?
    /// SIGSTOP을 보낸 pid를 로컬에 기억해 refresh 사이 깜빡임을 막는다.
    @ObservationIgnored private var knownPaused: Set<pid_t> = []

    init() {
        showSystem = UserDefaults.standard.bool(forKey: "showSystemServers")
    }

    // MARK: - 새로고침

    func refresh() {
        isRefreshing = true
        let known = knownPaused
        Task {
            let scanned = await Task.detached { Self.scan() }.value
            var merged = scanned
            for i in merged.indices where known.contains(merged[i].pid) {
                merged[i].isPaused = true
            }
            self.allServers = merged
            self.isRefreshing = false
        }
    }

    func startAutoRefresh() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stopAutoRefresh() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - 액션

    /// SIGTERM 후 살아있으면 SIGKILL.
    func terminate(_ server: ServerProcess) {
        let pid = server.pid
        kill(pid, SIGTERM)
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            if Self.isAlive(pid) { kill(pid, SIGKILL) }
            try? await Task.sleep(for: .milliseconds(150))
            self.knownPaused.remove(pid)
            self.refresh()
        }
    }

    /// SIGSTOP ↔ SIGCONT 토글.
    func togglePause(_ server: ServerProcess) {
        let pid = server.pid
        if server.isPaused {
            kill(pid, SIGCONT)
            knownPaused.remove(pid)
        } else {
            kill(pid, SIGSTOP)
            knownPaused.insert(pid)
        }
        // 같은 pid의 모든 행에 낙관적 반영 (다음 refresh가 ps stat으로 확정)
        let paused = knownPaused.contains(pid)
        for i in allServers.indices where allServers[i].pid == pid {
            allServers[i].isPaused = paused
        }
    }

    // MARK: - 시스템 조회 헬퍼 (메인 액터 밖에서 실행)

    nonisolated static func scan() -> [ServerProcess] {
        let output = runProcess("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"])
        var servers = parseLsof(output)
        guard !servers.isEmpty else { return [] }

        // pid별 메타데이터는 ps 한 번씩(전체)으로 모아온다 — pid마다 ps를 띄우지 않는다.
        let info = psInfoAll()        // pid → (ppid, stat, uid, comm)
        let commands = psCommandAll() // pid → 표시용 명령줄
        for i in servers.indices {
            let meta = info[servers[i].pid]
            servers[i].isPaused = meta?.stat.contains("T") ?? false
            servers[i].fullCommand = commands[servers[i].pid]
            servers[i].isSystem = isSystemProcess(uid: meta?.uid ?? 0, execPath: meta?.comm, ppid: meta?.ppid ?? 0)
        }
        return servers.sorted { $0.port < $1.port }
    }

    /// 시스템 데몬 / 백그라운드 앱이면 true → 기본 dev 목록에서 숨긴다.
    /// 판별:
    ///   (1) 다른 유저(root 등) 소유
    ///   (2) 부모가 launchd(ppid==1) — GUI 앱·adb·brew 서비스 등 데몬은 launchd가 띄운다.
    ///       내가 터미널에서 띄운 dev 서버는 부모가 셸/node/npm(ppid≠1)이라 통과한다.
    ///   (3) 시스템 실행 경로 — 부모가 launchd가 아닌 시스템 헬퍼(보안앱 서비스 등) 보강.
    nonisolated static func isSystemProcess(uid: uid_t, execPath: String?, ppid: pid_t) -> Bool {
        if uid != getuid() { return true }
        if ppid == 1 { return true }
        guard let p = execPath else { return false }
        let systemPrefixes = [
            "/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/",
            "/Library/Apple/", "/Library/Application Support/",
            "/Library/PrivilegedHelperTools/", "/Library/CoreServices/"
        ]
        return systemPrefixes.contains(where: { p.hasPrefix($0) })
    }

    /// lsof `-F pcn` 출력 파싱. p=pid, c=command, n=주소(`*:3000`, `127.0.0.1:3000`, `[::1]:4000`).
    nonisolated static func parseLsof(_ output: String) -> [ServerProcess] {
        var byKey: [String: ServerProcess] = [:]
        var curPid: pid_t = 0
        var curCommand = ""

        for rawLine in output.split(separator: "\n") {
            guard let prefix = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch prefix {
            case "p":
                curPid = pid_t(value) ?? 0
            case "c":
                curCommand = value
            case "n":
                guard let (addr, port) = addressAndPort(value) else { continue }
                let key = "\(curPid)-\(port)"
                if byKey[key] == nil {
                    byKey[key] = ServerProcess(
                        pid: curPid,
                        command: curCommand,
                        port: port,
                        address: addr,
                        fullCommand: nil,
                        isPaused: false,
                        isSystem: false
                    )
                }
            default:
                break
            }
        }
        return Array(byKey.values)
    }

    /// `127.0.0.1:3000` / `*:3000` / `[::1]:4000` → (주소, 포트). 마지막 `:` 기준 분리.
    nonisolated static func addressAndPort(_ name: String) -> (String, Int)? {
        guard let colon = name.lastIndex(of: ":") else { return nil }
        let addr = String(name[name.startIndex..<colon])
        let portStr = String(name[name.index(after: colon)...])
        guard let port = Int(portStr) else { return nil }
        return (addr, port)
    }

    /// 한 번의 ps 호출로 모든 프로세스의 부모pid/상태/uid/실행경로를 모은다.
    /// 각 줄 예: "  88789     1 SN     501 /usr/libexec/rapportd" → pid ppid stat uid comm(나머지).
    nonisolated static func psInfoAll() -> [pid_t: (ppid: pid_t, stat: String, uid: uid_t, comm: String?)] {
        let out = runProcess("/bin/ps", ["-axww", "-o", "pid=,ppid=,stat=,uid=,comm="])
        var map: [pid_t: (pid_t, String, uid_t, String?)] = [:]
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 5,
                  let pid = pid_t(parts[0]),
                  let ppid = pid_t(parts[1]),
                  let uid = uid_t(parts[3]) else { continue }
            map[pid] = (ppid, String(parts[2]), uid, parts[4...].joined(separator: " "))
        }
        return map
    }

    /// 한 번의 ps 호출로 모든 프로세스의 표시용 명령줄(argv)을 모은다.
    nonisolated static func psCommandAll() -> [pid_t: String] {
        let out = runProcess("/bin/ps", ["-axww", "-o", "pid=,command="])
        var map: [pid_t: String] = [:]
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 2, let pid = pid_t(parts[0]) else { continue }
            map[pid] = parts[1...].joined(separator: " ")
        }
        return map
    }

    nonisolated static func isAlive(_ pid: pid_t) -> Bool {
        // kill(pid, 0): 0 = 존재, -1 & EPERM = 존재하지만 권한없음 → 살아있음
        return kill(pid, 0) == 0 || errno == EPERM
    }

    /// 지정 실행 파일을 돌려 stdout 문자열을 반환. waitUntilExit 전에 파이프를 비워 데드락 방지.
    nonisolated static func runProcess(_ launchPath: String, _ args: [String]) -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = args
        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()
        do {
            try proc.run()
        } catch {
            return ""
        }
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
