; GekyChat Windows installer (Inno Setup 6)
; Build: ISCC.exe /DMyAppVersion=1.0.0 windows\installer\gekychat.iss

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#define MyAppName "GekyChat"
#define MyAppPublisher "GekyChat"
#define MyAppURL "https://gekychat.com"
#define MyAppExeName "gekychat_desktop.exe"
#define MyAppId "c75eae72-24ff-5d2d-82dc-31fa5575483d"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/contact
AppUpdatesURL={#MyAppURL}/download
DefaultDirName={autopf}\{#MyAppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
OutputDir=..\..\build\windows\x64\installer\Release
OutputBaseFilename=GekyChat-x64-{#MyAppVersion}-Installer
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableDirPage=auto
DisableProgramGroupPage=auto
; Upgrade over existing install (same AppId), reuse install folder.
UsePreviousAppDir=yes
; Force-close GekyChat so gekychat_desktop.exe / DLLs are not locked during upgrade.
CloseApplications=force
RestartApplications=no

[InstallDelete]
Type: filesandordirs; Name: "{app}\*"

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}";

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// GekyChat hides to the system tray on window close — the process keeps running and
// locks the install folder. Kill it before upgrade so Inno Setup can replace files.
procedure KillRunningGekyChat();
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/F /IM {#MyAppExeName} /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(800);
end;

function InitializeSetup(): Boolean;
begin
  KillRunningGekyChat();
  Result := True;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  KillRunningGekyChat();
  Result := '';
end;
