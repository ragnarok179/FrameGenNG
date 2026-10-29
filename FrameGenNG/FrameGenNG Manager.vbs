Option Explicit

Dim shell, fileSystem, packageRoot, managerScript, command
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

packageRoot = fileSystem.GetParentFolderName(WScript.ScriptFullName)
managerScript = fileSystem.BuildPath(packageRoot, "manager\FrameGenNG-Manager.ps1")

If Not fileSystem.FileExists(managerScript) Then
    MsgBox "FrameGenNG Manager could not find:" & vbCrLf & managerScript, vbCritical, "FrameGenNG"
    WScript.Quit 1
End If

command = "powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & managerScript & """"
shell.Run command, 0, False
