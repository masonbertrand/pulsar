// Runs every test group, then exits non-zero if anything failed. Run with ./tests.sh.
import Foundation

testMeeting()
testTileLayout()
testLyrics()
testGridPaging()
testNextEvent()
testTileFlow()
testUpdateTiming()
testProcessUse()
testClaudeStages()
testTabsLogic()
testToolsLogic()
testTabOrder()
testTiles2Logic()
testLevels()
testNotionTasks()

print("\(checks) checks, \(failures) failed")
exit(failures == 0 ? 0 : 1)
