import Foundation
import Signals

public struct CleanQuit {
    
    public typealias Signal = Int32
    
    public static let defaultCaptureSignals: [Signal] = [SIGHUP,SIGINT,SIGQUIT,SIGABRT,SIGKILL,SIGALRM,SIGTERM,SIGPIPE]
    
    /// Set to kill all children processes when main process ends
    /// - Parameters:
    ///   - signalMapping: transform signal to another signal when propagate to recursive child process
    ///   - debug: show debug log
    public static func enable(handledSignals:[Signal] = defaultCaptureSignals,
                              signalMapping: [Signal:Signal]? = nil,
                              debug: Bool = false)
    {
        _debug = debug
        _signalMapping = signalMapping
        
        // Trap the signal
        // Although not all signals can be trapped, we just use all of them.
        Signals.trap(signals: handledSignals.map({ Signals.Signal.user(Int($0)) })) { signal in
            if _killedOnce {
                debugPrint("Skipped catch signal \(signal) due to killed once")
                return
            }
            _killedOnce = true
            _exitFromTrap = true
            
            debugPrint("Caught signal \(signal)")
            _killAllChildrenProcesses(signal: signal)
            // about the exit code https://unix.stackexchange.com/a/99117/397790
            exit(128 + signal)
        }
        
        // Before normal exit
        atexit({
            if !_killedOnce {
                _killedOnce = true
                let signal: Int32 = SIGTERM
                _killAllChildrenProcesses(signal: signal)
            }
            debugPrint("Final exit. Signal trapped: \(_exitFromTrap)")
        })
    }
    
    // Add a hook action after performing the kill action
    // It can be called multiple times to add multiple hooks
    public static func AfterKillHook(action: @escaping ()->Void) {
        afterKillHooks.append(action)
    }
    
}

private var _exitFromTrap = false
private var _killedOnce = false
private var afterKillHooks: [()->Void] = []
private var _signalMapping: [Int32:Int32]?

func _killAllChildrenProcesses(signal: Int32) {
    let signal = _signalMapping?[signal] ?? signal
    
    let pids = findChildProcessIdsRecursively(pid: getpid())
    debugPrint("recursive child pids: \(pids)")
    for pid in pids.reversed() {
        kill(pid, signal)
    }
    for hook in afterKillHooks.reversed() { // FILO
        hook()
    }
}

// Find all children process ids recursively.
// The returned child process list is in BFS sequence of the process tree
func findChildProcessIdsRecursively(pid: Int32) -> [Int32] {
    
    func findChildren(pid: String) -> [String] {
        let result = exec("/usr/bin/pgrep", args: ["-P", pid])
        if result.code != 0 {
            return []
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").map(String.init)
    }
    var fifo = ["\(pid)"]
    var out: [String] = []
    while !fifo.isEmpty {
        let head = fifo[0]
        fifo = Array(fifo.dropFirst())
        let children = findChildren(pid: head)
        fifo += children
        out += children
    }
    
    return out.compactMap(Int32.init)
        .filter({ $0 != 0 }) // filter 0 as it has a special meaning for `kill`. It won't result a 0, just for insurance
}

func exec(_ executablePath: String, args: [String]) -> (code: Int32, output:String) {
    // exec shell
    let task = Process()
    task.launchPath = executablePath
    task.arguments = args
    
    let pipe = Pipe()
    task.standardOutput = pipe
    
    // waitUntilExit is vary slow. it involves the runlopp.
    let group = DispatchGroup()
    task.terminationHandler = { _ in
        group.leave()
    }
    group.enter()
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    group.wait()

    return (task.terminationStatus, output)
}


func debugPrint(_ message: String) {
    if _debug {
        print("[CleanQuit]: " + message)
    }
}

var _debug = false
