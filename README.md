# CleanQuit

Kill all children processes when main program ends.

Children processes may be create by `Process` class, which usually used to call shell commands. When the main swift processes killed by ctr+c, the children processes won't be killed and become an orphan process owned by pid 1.

This lib provides a method to kill all direct children processes automatically when process exit or be killed by signal.

## Usage

SPM
```
.package(url: "https://github.com/leavez/CleanQuit.git", from: "1.0.0"),
```

```
import CleanQuit

CleanQuit.enable()
```
