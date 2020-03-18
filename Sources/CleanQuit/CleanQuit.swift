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
    }
    
}

private var _exitFromTrap = false

func _killAllChildrenProcesses(signal: Int32) {
    
    let selfPid = getpid()
    
    // find all children process ids recursively
    let bashScript = """
    pids=''
    function recursiveFindChild() {
        local parentPid=$1
        for childId in $(pgrep -P $parentPid); do
            # action
            pids+="$childId,"
            # recursive
            recursiveFindChild $childId
        done
    }
    
    # recursive find the children processes
    recursiveFindChild \(selfPid)
    echo "$pids"
    """
    
    let result = bash(bashScript)
    if result.code == 0 {
        let pids = result.output.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",").filter({ $0.count > 0 }).compactMap({ Int32($0) })
        for pid in pids.reversed() {
            killpg(pid, signal)
        }
    }
}

func bash(_ script: String) -> (code: Int32, output:String) {
    // exec shell
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", script]
    
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    task.waitUntilExit()
    
    return (task.terminationStatus, output)
}


