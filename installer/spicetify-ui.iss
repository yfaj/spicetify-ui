#define AppName "Spicetify UI"
#define AppVersion GetEnv("APP_VERSION")
#define AppPublisher "Spicetify UI contributors"

[Setup]
AppId={{8E2B5C3A-4F17-4C2B-9E1D-6A0F3C7D5B21}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\Spicetify UI
DefaultGroupName={#AppName}
OutputDir=dist
OutputBaseFilename=spicetify-ui-{#AppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\spicetify_ui.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\spicetify_ui.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Run]
Filename: "{app}\spicetify_ui.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
