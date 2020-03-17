import Foundation
import Signals
import SwiftShell

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
    }
    
}

private var _exitFromTrap = false

private func _killAllChildrenProcesses(signal: Int32) {
    let selfPid = getpid()
    let r = SwiftShell.run(bash: "pkill -\(signal) -P \(selfPid)")
    // Exit code 1 means `No processes were matched` @see `man pkill`
    // If it has no subprocess, just get code 1, and it's ok.
    if !r.succeeded && r.exitcode != 1 {
        print("Killing all children processes failed. CODE: \(r.exitcode) ERROR: \(r.stderror)")
    }
}


