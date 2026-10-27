import Foundation

func testProcessUse() {
    let ps = """
      12.5  204800 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
      30.0  102400 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Google Chrome Helper (Renderer)
      55.1   51200 /usr/local/bin/node
       0.0    1024 ps
       3,5   10240 /System/Library/CoreServices/WindowServer
      junk line
    """
    let rows = ProcessUse.parse(ps)
    equal(rows.count, 3, "Chrome's helper joins Chrome; ps itself and junk are skipped")
    let chrome = rows.first { $0.name == "Google Chrome" }
    equal(chrome?.cpu, 42.5, "CPU of an app adds up its helpers")
    equal(chrome?.mb, 300, "memory adds up too")
    equal(rows.first { $0.name == "WindowServer" }?.cpu, 3.5, "a comma decimal is read")
    equal(ProcessUse.topCPU(rows, 2).map(\.name), ["node", "Google Chrome"], "busiest first, programs outside apps count")
    equal(ProcessUse.topMemory(rows, 5).map(\.name), ["Google Chrome"], "memory list keeps to apps")
    equal(ProcessUse.cpuText(42.5), "42%"); equal(ProcessUse.cpuText(3.46), "3.5%")
    equal(ProcessUse.mbText(300), "300 MB"); equal(ProcessUse.mbText(2048), "2.0 GB")
}
