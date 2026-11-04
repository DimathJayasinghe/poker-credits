; Inno Setup script for the Windows installer. Built by .github/workflows/desktop-builds.yml.
; Inputs (passed with /D): AppVersion, SourceDir (the Flutter Release folder), OutputDir.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

[Setup]
; Never change AppId: it is how Windows recognises an upgrade or an uninstall of this app.
AppId={{5D0B6B1E-7E0C-4C0E-9B8E-2B7C7D6A41F3}
AppName=Poker Credits
AppVersion={#AppVersion}
AppPublisher=Poker Credits
DefaultDirName={autopf}\Poker Credits
DefaultGroupName=Poker Credits
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=poker-credits-windows-x64-setup
SetupIconFile=..\..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\poker_credits.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Installs for the current user without an administrator prompt; the wizard offers
; "for all users" as a choice.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Shortcuts:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Poker Credits"; Filename: "{app}\poker_credits.exe"
Name: "{group}\Uninstall Poker Credits"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Poker Credits"; Filename: "{app}\poker_credits.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\poker_credits.exe"; Description: "Start Poker Credits"; Flags: nowait postinstall skipifsilent
