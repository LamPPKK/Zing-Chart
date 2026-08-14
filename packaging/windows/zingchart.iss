#ifndef SourceDir
  #error SourceDir must point to the Flutter Windows release bundle
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{A05D8F41-7176-42B0-9C16-6A6DBE356946}
AppName=#zingChart
AppVersion={#AppVersion}
AppPublisher=#zingChart
DefaultDirName={autopf}\#zingChart
DefaultGroupName=#zingChart
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename=zingchart-windows-installer
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayIcon={app}\zmp3chart.exe

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\#zingChart"; Filename: "{app}\zmp3chart.exe"
Name: "{autodesktop}\#zingChart"; Filename: "{app}\zmp3chart.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
Filename: "{app}\zmp3chart.exe"; Description: "Launch #zingChart"; Flags: nowait postinstall skipifsilent
