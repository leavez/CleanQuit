import Foundation
import Signals

public struct CleanQuit {
    
    /// Set to kill all children processes when main process ends
    public static func enable() {
        
        // Trap the signal
        // Although not all signals can be trapped, we just use all of them.
        Signals.trap(signals: [.hup,.int,.quit,.abrt,.kill,.alrm,.term,.pipe]) { signal in
            _killAllChildrenProcesses(signal: signal)
            _exitFromTrap = true
            // about the exit code https://unix.stackexchange.com/a/99117/397790
            exit(128 + signal)
        }
        
        // Before normal exit
        atexit({
            if !_exitFromTrap {
                let signal: Int32 = SIGTERM
                _killAllChildrenProcesses(signal: signal)
            }
        })
        
        // check depedency
        let pkillFilePath = "/usr/bin/pkill"
        if !FileManager.default.fileExists(atPath: pkillFilePath) {
            fatalError("[ERROR] CleanQuit failed. `/usr/bin/pkill` not exit")
        }
    }
    
}

private var _exitFromTrap = false

private func _killAllChildrenProcesses(signal: Int32) {
    let selfPid = getpid()
    let pkillFilePath = "/usr/bin/pkill"
    if !FileManager.default.fileExists(atPath: pkillFilePath) {
        print("[ERROR] /usr/bin/pkill not exit")
    }
    
    let task = Process()
    task.launchPath = pkillFilePath
    task.arguments = ["-\(signal)", "-P", "\(selfPid)"]
    task.launch()
    task.waitUntilExit()
    let code = task.terminationStatus
    
    let reasons: [Int32: String] =
        [0 : "One or more processes were matched.",
         1 : "No processes were matched.",
         2 : "Invalid options were specified on the command line.",
         3 : "An internal error occurred."]
    
    // Exit code 1 means `No processes were matched` @see `man pkill`
    // If it has no subprocess, just get code 1, and it's ok.
    if code != 0 && code != 1 {
        let reason = reasons[code] ?? "Unknow error"
        print("Killing all children processes failed. CODE: \(code) EXPLAIN: \(reason)")
    }
}


