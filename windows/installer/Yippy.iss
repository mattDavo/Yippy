; The Yippy for Windows installer (Inno Setup 6.7 or later).
;
; Installs Yippy.exe for the current user (no administrator rights), with the Win+V scripts, a Start menu shortcut, and
; optionally launch at sign-in and Win+V. Uninstalling gives Win+V back to Windows and asks before deleting the history.
;
; Build it after publishing Yippy.exe (see README.md):
;   iscc /DAppVersion=1.2.3 /DPublishDir=..\publish Yippy.iss
; The setup is written to installer\output\Yippy-<version>-setup.exe.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef PublishDir
  #define PublishDir "..\publish"
#endif

#define AppName "Yippy"
#define AppExe "Yippy.exe"
#define AppUrl "https://github.com/Hamza-Shewa/Yippy"
; Yippy's single-instance mutex (Local\Yippy.Instance, see Yippy.App/Shell/SingleInstance.cs)
#define InstanceMutex "Yippy.Instance"

[Setup]
; Never change the AppId: it is how an update finds the installed copy
AppId={{6C0E8E52-4D0B-4E43-9F5B-0B7D6E2C9A1F}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppName}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
AppCopyright=Copyright © Matthew Davidson and contributors
VersionInfoVersion={#AppVersion}
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} Setup

; Per user, in %LOCALAPPDATA%\Programs\Yippy: no UAC prompt, like Yippy's data and settings
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763

LicenseFile=..\..\LICENSE
SetupIconFile=..\src\Yippy.App\Assets\Yippy.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
WizardStyle=modern dynamic windows11
WizardImageFile=WizardImage.bmp,WizardImage@2x.bmp
WizardSmallImageFile=WizardSmallImage.png,WizardSmallImage@2x.png

; Setup closes Yippy itself, so it can save its history first (see PrepareToInstall)
CloseApplications=no
RestartApplications=no
SetupMutex={#AppName}Setup

OutputDir=output
OutputBaseFilename={#AppName}-{#AppVersion}-setup
Compression=lzma2/max
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
english.OptionsGroup=Options:
english.StartupTask=Start Yippy when I sign in
english.WinVTask=Open Yippy with Win+V instead of Windows' clipboard history (the taskbar restarts for a moment)
english.HandingOverWinV=Handing Win+V to Yippy…
english.StillRunning=Yippy is still running.%n%nRight-click its icon in the notification area and choose Quit Yippy, then select Retry.
english.StillRunningAbort=Yippy is still running. Quit it, then run Setup again.
english.DeleteDataTitle=Delete your clipboard history too?
english.DeleteDataText=Your clipboard history, favourites and settings are still on this PC. Keep them if you might install Yippy again.
english.DeleteData=Delete them
english.KeepData=Keep them

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "{cm:StartupTask}"; GroupDescription: "{cm:OptionsGroup}"
Name: "winv"; Description: "{cm:WinVTask}"; GroupDescription: "{cm:OptionsGroup}"; Flags: unchecked

[Files]
Source: "{#PublishDir}\{#AppExe}"; DestDir: "{app}"; Flags: ignoreversion
; The same scripts are built into Yippy.exe (Settings > Shortcut > Save scripts)
Source: "..\scripts\*.ps1"; DestDir: "{app}\scripts"; Flags: ignoreversion
Source: "..\..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"; Comment: "Everything you copy, a shortcut away"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Registry]
; The same entry as Settings > General > Start Yippy when I sign in, so either can turn it off
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; \
    ValueData: """{app}\{#AppExe}"""; Tasks: startup
; Removed on uninstall however it was turned on
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "{#AppName}"; \
    Flags: uninsdeletevalue dontcreatekey

[Run]
Filename: "{app}\{#AppExe}"; Parameters: "--use-win-v"; StatusMsg: "{cm:HandingOverWinV}"; Tasks: winv; \
    Flags: runhidden waituntilterminated
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall

[UninstallRun]
; Gives Win+V back to Windows if Yippy had it; does nothing otherwise
Filename: "{app}\{#AppExe}"; Parameters: "--restore-win-v"; RunOnceId: "RestoreWinV"; Flags: runhidden waituntilterminated

[Code]
function IsYippyRunning(): Boolean;
begin
  Result := CheckForMutexes('{#InstanceMutex}');
end;

{ Asks the running copy to quit (it saves its history first) through Exe's --quit command, then waits for the user if it
  is still running, e.g. an older version that doesn't know --quit. }
function CloseYippy(const Exe: String): Boolean;
var
  ResultCode: Integer;
begin
  if IsYippyRunning() and FileExists(Exe) then
    Exec(Exe, '--quit', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := not IsYippyRunning();
  while not Result do
  begin
    if SuppressibleMsgBox(CustomMessage('StillRunning'), mbError, MB_RETRYCANCEL, IDCANCEL) = IDCANCEL then
      Exit;
    Result := not IsYippyRunning();
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  if IsYippyRunning() then
  begin
    { The new Yippy.exe can close a running copy wherever it was started from }
    ExtractTemporaryFile('{#AppExe}');
    if not CloseYippy(ExpandConstant('{tmp}\{#AppExe}')) then
      Result := CustomMessage('StillRunningAbort');
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := CloseYippy(ExpandConstant('{app}\{#AppExe}'));
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if (CurUninstallStep <> usPostUninstall) or UninstallSilent() then
    Exit;
  DataDir := ExpandConstant('{userappdata}\{#AppName}');
  if DirExists(DataDir) and (TaskDialogMsgBox(CustomMessage('DeleteDataTitle'), CustomMessage('DeleteDataText'),
      mbConfirmation, MB_YESNO, [CustomMessage('DeleteData'), CustomMessage('KeepData')], 0) = IDYES) then
    DelTree(DataDir, True, True, True);
end;
