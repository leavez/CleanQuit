import Foundation
import Signals

public struct CleanQuit {
    
    /// Set to kill all children processes when main process ends
    public static func enable(debug: Bool = false) {
        _debug = debug
        
        // Trap the signal
        // Although not all signals can be trapped, we just use all of them.
        Signals.trap(signals: [.hup,.int,.quit,.abrt,.kill,.alrm,.term,.pipe]) { signal in
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
            debugPrint("Final exit. Singal trapped: \(_exitFromTrap)")
        })
    }
    
}

private var _exitFromTrap = false
private var _killedOnce = false

func _killAllChildrenProcesses(signal: Int32) {
    
    let pids = findChildProcessIdsRecursively(pid: getpid())
    debugPrint("recursive child pids: \(pids)")
    for pid in pids.reversed() {
        kill(pid, signal)
    }
}

// find all children process ids recursively
func findChildProcessIdsRecursively(pid: Int32) -> [Int32] {
    
    func findRecursively(pid: String) -> [String] {
        var out = [String]()
        let result = exec("/usr/bin/pgrep", args: ["-P", pid])
        if result.code == 0 {
            let childIds = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n").map(String.init)
            out += childIds
            for c in childIds {
                out += findRecursively(pid: c)
            }
        }
        return out
    }
    
    return findRecursively(pid: "\(pid)").compactMap(Int32.init)
}

func exec(_ executablePath: String, args: [String]) -> (code: Int32, output:String) {
    // exec shell
    let task = Process()
    task.launchPath = executablePath
    task.arguments = args
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    task.waitUntilExit()
    
    return (task.terminationStatus, output)
}


func debugPrint(_ message: String) {
    if _debug {
        print("[CleanQuit]: " + message)
    }
}

var _debug = false
