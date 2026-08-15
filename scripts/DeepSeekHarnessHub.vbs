Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
d = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run "cmd /c """ & d & "\DeepSeekHarnessHub.bat""", 0, False
