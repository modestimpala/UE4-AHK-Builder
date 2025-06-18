#Requires AutoHotkey v2.0

; Mod Build Hotkey Manager - AutoHotkey v2 Script
; Uses UE4ModBuilder class for building and deploying mods

; Include the UE4ModBuilder class
; Make sure ue4_mod_builder.ahk is in the same directory or adjust path
#Include "ue4_mod_builder.ahk"

class ModHotkeyManager {
    
    static ConfigFile := A_ScriptDir . "\mod_hotkey_config.ini"
    
    ; Default configuration
    static Config := {
        ; Build settings
        MapName: "",
        PakID: "", 
        Profile: "",
        PakName: "",
        
        ; Game settings
        GameExe: "",
        GameArgs: "",
        AutoLaunchGame: true,
        
        ; UI settings
        ShowTraytips: false
    }
    
    ; Initialize the manager
    static Init() {
        this.LoadConfig()
        this.AutoDetectSettings()
        this.SaveConfig()
        this.CreateTrayMenu()
        
        ; Initialize the mod builder
        UE4ModBuilder.Init()
        
        if (this.Config.ShowTraytips) {
            TrayTip("Mod Build Hotkeys", "Ready for builds! Press Ctrl+Shift+H for help", "Mute")
        }
    }
    
    ; Auto-detect game and other settings
    static AutoDetectSettings() {
        ; Auto-detect game executable if not set
        if (!this.Config.GameExe || !FileExist(this.Config.GameExe)) {
            this.AutoDetectGameExe()
        }
        
        ; Build game arguments if not manually set
        if (!this.Config.GameArgs) {
            this.Config.GameArgs := this.BuildGameArgs()
        }
    }
    
    ; Auto-detect game executable
    static AutoDetectGameExe() {
        ; Common game locations
        commonPaths := [
            A_Desktop . "\UE\082c_0011\WindowsNoEditor\VotV.exe",
            A_ProgramFiles . "\VotV\VotV.exe",
            A_MyDocuments . "\VotV\VotV.exe"
        ]
        
        for path in commonPaths {
            if (FileExist(path)) {
                this.Config.GameExe := path
                return
            }
        }
        
        ; Search common game directories
        searchDirs := [A_Desktop, A_ProgramFiles, A_MyDocuments]
        
        for dir in searchDirs {
            if (DirExist(dir)) {
                Loop Files, dir . "\*VotV*.exe", "FR" {
                    this.Config.GameExe := A_LoopFileFullPath
                    return
                }
            }
        }
    }
    
    ; Build game arguments dynamically
    static BuildGameArgs() {
        profilesDir := UE4ModBuilder.UseDefaultProfiles ? UE4ModBuilder.DefaultProfilesDir : UE4ModBuilder.ProfilesDir
        profile := this.Config.Profile
        
        return '--mod-dir "' . profilesDir . '\' . profile . '\shimloader\mod" ' .
               '--pak-dir "' . profilesDir . '\' . profile . '\shimloader\pak" ' .
               '--cfg-dir "' . profilesDir . '\' . profile . '\shimloader\cfg"'
    }
    
    ; Main build function
    static BuildMod(mapName := "", pakID := "", profile := "", pakName := "") {
        ; Use defaults if not provided
        if (!mapName) mapName := this.Config.MapName
        if (!pakID) pakID := this.Config.PakID
        if (!profile) profile := this.Config.Profile
        if (!pakName) pakName := this.Config.PakName
        
        if (this.Config.ShowTraytips) {
            TrayTip("Building Mod", "Starting build for " . mapName, "Mute")
        }
        
        ; Use UE4ModBuilder instead of batch file
        success := UE4ModBuilder.BuildMod(mapName, pakID, profile, pakName)
        
        if (success) {
            if (this.Config.ShowTraytips) {
                TrayTip("Build Complete", "Mod ready: " . mapName, "Mute")
            }
            
            ; Auto-launch game if enabled
            if (this.Config.AutoLaunchGame) {
                this.LaunchGame()
            }
        } else {
            TrayTip("Build Failed", "Check console for errors", "Mute")
        }
        
        return success
    }
    
    ; Launch the game
    static LaunchGame() {
        if (!this.Config.GameExe || !FileExist(this.Config.GameExe)) {
            TrayTip("Game Launch Error", "Game executable not found or not configured", "Mute")
            return false
        }
        
        ; Update game args in case profile changed
        gameArgs := this.BuildGameArgs()
        
        try {
            Run('"' . this.Config.GameExe . '" ' . gameArgs, , "Hide")
            if (this.Config.ShowTraytips) {
                TrayTip("Game Launched", "Starting game...", "Mute")
            }
            return true
        } catch Error as e {
            TrayTip("Game Launch Error", "Failed to start: " . e.Message, "Mute")
            return false
        }
    }
    
    ; Build with custom parameters (input dialog)
    static BuildWithInput() {
        ; Get map name
        result := InputBox("Enter map name:", "Build Mod", "w250 h100", this.Config.MapName)
        if (result.Result = "Cancel")
            return
        mapInput := result.Value ? result.Value : this.Config.MapName
        
        ; Get pak ID
        result := InputBox("Enter pak ID:", "Build Mod", "w250 h100", this.Config.PakID)
        if (result.Result = "Cancel") 
            return
        pakInput := result.Value ? result.Value : this.Config.PakID
        
        ; Get profile (show available profiles)
        profiles := UE4ModBuilder.GetProfiles()
        profileList := ""
        for profile in profiles {
            profileList .= profile . "`n"
        }
        
        profilePrompt := "Enter profile name:"
        if (profiles.Length > 0) {
            profilePrompt .= "`n`nAvailable profiles:`n" . profileList
        }
        
        result := InputBox(profilePrompt, "Build Mod", "w300 h200", this.Config.Profile)
        if (result.Result = "Cancel") 
            return
        profileInput := result.Value ? result.Value : this.Config.Profile
        
        ; Get pak name
        result := InputBox("Enter pak name:", "Build Mod", "w250 h100", this.Config.PakName)
        if (result.Result = "Cancel") 
            return
        pakNameInput := result.Value ? result.Value : this.Config.PakName
        
        ; Build with custom parameters
        this.BuildMod(mapInput, pakInput, profileInput, pakNameInput)
    }
    
    ; Emergency stop build processes
    static StopAllBuilds() {
        try {
            RunWait("taskkill /f /im AutomationTool.exe", , "Hide")
            RunWait("taskkill /f /im UE4Editor-Cmd.exe", , "Hide")
            RunWait("taskkill /f /im UnrealBuildTool.exe", , "Hide")
        }
        TrayTip("Build Stopped", "All build processes terminated", "Mute")
    }
    
    ; Configuration functions
    static LoadConfig() {
        if (!FileExist(this.ConfigFile)) 
            return
        
        ; Load build settings
        this.Config.MapName := IniRead(this.ConfigFile, "Build", "MapName", this.Config.MapName)
        this.Config.PakID := IniRead(this.ConfigFile, "Build", "PakID", this.Config.PakID)
        this.Config.Profile := IniRead(this.ConfigFile, "Build", "Profile", this.Config.Profile)
        this.Config.PakName := IniRead(this.ConfigFile, "Build", "PakName", this.Config.PakName)
        
        ; Load game settings
        this.Config.GameExe := IniRead(this.ConfigFile, "Game", "Executable", this.Config.GameExe)
        this.Config.GameArgs := IniRead(this.ConfigFile, "Game", "Arguments", this.Config.GameArgs)
        this.Config.AutoLaunchGame := IniRead(this.ConfigFile, "Game", "AutoLaunch", "1") = "1"
        
        ; Load UI settings
        this.Config.ShowTraytips := IniRead(this.ConfigFile, "UI", "ShowTraytips", "0") = "1"
    }
    
    static SaveConfig() {
        ; Save build settings
        IniWrite(this.Config.MapName, this.ConfigFile, "Build", "MapName")
        IniWrite(this.Config.PakID, this.ConfigFile, "Build", "PakID") 
        IniWrite(this.Config.Profile, this.ConfigFile, "Build", "Profile")
        IniWrite(this.Config.PakName, this.ConfigFile, "Build", "PakName")
        
        ; Save game settings
        IniWrite(this.Config.GameExe, this.ConfigFile, "Game", "Executable")
        IniWrite(this.Config.GameArgs, this.ConfigFile, "Game", "Arguments")
        IniWrite(this.Config.AutoLaunchGame ? "1" : "0", this.ConfigFile, "Game", "AutoLaunch")
        
        ; Save UI settings
        IniWrite(this.Config.ShowTraytips ? "1" : "0", this.ConfigFile, "UI", "ShowTraytips")
    }
    
    ; Settings management
    static ConfigureGamePath() {
        result := InputBox("Enter game executable path:", "Configure Game", "w400 h100", this.Config.GameExe)
        if (result.Result != "Cancel" && result.Value) {
            this.Config.GameExe := result.Value
            this.SaveConfig()
            if (this.Config.ShowTraytips) {
                TrayTip("Game Path Updated", "New path set", "Mute")
            }
        }
    }
    
    static ConfigureBuildDefaults() {
        ; Configure map name
        result := InputBox("Default map name:", "Configure Build Defaults", "w300 h100", this.Config.MapName)
        if (result.Result = "Cancel") 
            return
        if (result.Value) this.Config.MapName := result.Value
        
        ; Configure pak ID
        result := InputBox("Default pak ID:", "Configure Build Defaults", "w300 h100", this.Config.PakID)
        if (result.Result = "Cancel") 
            return
        if (result.Value) this.Config.PakID := result.Value
        
        ; Configure profile
        profiles := UE4ModBuilder.GetProfiles()
        profilePrompt := "Default profile:"
        if (profiles.Length > 0) {
            profilePrompt .= "`n`nAvailable: " . profiles.Length ? profiles[1] : "None"
            for i, profile in profiles {
                if (i > 1) 
                    profilePrompt .= ", " . profile
            }
        }
        
        result := InputBox(profilePrompt, "Configure Build Defaults", "w300 h150", this.Config.Profile)
        if (result.Result = "Cancel") 
            return
        if (result.Value) this.Config.Profile := result.Value
        
        ; Configure pak name
        result := InputBox("Default pak name:", "Configure Build Defaults", "w300 h100", this.Config.PakName)
        if (result.Result = "Cancel") 
            return
        if (result.Value) this.Config.PakName := result.Value
        
        this.SaveConfig()
        if (this.Config.ShowTraytips) {
            TrayTip("Defaults Updated", "Build defaults saved", "Mute")
        }
    }
    
    static ToggleAutoLaunch() {
        this.Config.AutoLaunchGame := !this.Config.AutoLaunchGame
        this.SaveConfig()
        this.UpdateAutoLaunchCheck()
        
        status := this.Config.AutoLaunchGame ? "enabled" : "disabled"
        if (this.Config.ShowTraytips) {
            TrayTip("Auto-launch " . status, "Game launch after build " . status, "Mute")
        }
    }
    
    static ToggleTraytips() {
        this.Config.ShowTraytips := !this.Config.ShowTraytips
        this.SaveConfig()
        this.UpdateTraytipsCheck()
        
        status := this.Config.ShowTraytips ? "enabled" : "disabled"
        TrayTip("Notifications " . status, "", "Mute")
    }
    
    static UpdateAutoLaunchCheck() {
        if (this.Config.AutoLaunchGame) {
            A_TrayMenu.Check("Auto-launch game after build")
        } else {
            A_TrayMenu.Uncheck("Auto-launch game after build")
        }
    }
    
    static UpdateTraytipsCheck() {
        if (this.Config.ShowTraytips) {
            A_TrayMenu.Check("Show notifications")
        } else {
            A_TrayMenu.Uncheck("Show notifications")
        }
    }
    
    static ShowSettings() {
        gameArgs := this.BuildGameArgs()
        profiles := UE4ModBuilder.GetProfiles()
        
        settingsText := "Current Configuration:`n`n"
        settingsText .= "Build Settings:`n"
        settingsText .= "  Map: " . this.Config.MapName . "`n"
        settingsText .= "  Pak ID: " . this.Config.PakID . "`n"
        settingsText .= "  Profile: " . this.Config.Profile . "`n"
        settingsText .= "  Pak Name: " . this.Config.PakName . "`n`n"
        
        settingsText .= "Game Settings:`n"
        settingsText .= "  Auto-launch: " . (this.Config.AutoLaunchGame ? "Yes" : "No") . "`n"
        settingsText .= "  Executable: " . (this.Config.GameExe ? this.Config.GameExe : "Not set") . "`n`n"
        
        settingsText .= "Available Profiles: "
        if (profiles.Length > 0) {
            settingsText .= profiles[1]
            for i, profile in profiles {
                if (i > 1) 
                    settingsText .= ", " . profile
            }
        } else {
            settingsText .= "None found"
        }
        
        MsgBox(settingsText, "Current Settings")
    }
    
    static ShowHelp() {
        helpText := "Mod Build Hotkeys:`n`n"
        helpText .= "Ctrl+Shift+B       - Quick build with defaults`n"
        helpText .= "F12                - Alternative quick build`n"
        helpText .= "Ctrl+Shift+Alt+B   - Build with custom parameters`n"
        helpText .= "Ctrl+Shift+X       - Emergency stop all builds`n"
        helpText .= "Ctrl+Shift+H       - Show this help`n`n"
        
        helpText .= "Right-click tray icon for:`n"
        helpText .= "• Toggle auto-launch game`n"
        helpText .= "• Configure game path`n"
        helpText .= "• Set build defaults`n"
        helpText .= "• View mod builder config`n`n"
        
        helpText .= "Current Defaults:`n"
        helpText .= "Map: " . this.Config.MapName . "`n"
        helpText .= "Pak ID: " . this.Config.PakID . "`n" 
        helpText .= "Profile: " . this.Config.Profile . "`n"
        helpText .= "Pak Name: " . this.Config.PakName . "`n"
        helpText .= "Auto-launch: " . (this.Config.AutoLaunchGame ? "ON" : "OFF")
        
        MsgBox(helpText, "Mod Build Hotkeys - Help")
    }
    
    static CreateTrayMenu() {
        ; Remove default menu
        A_TrayMenu.Delete()
        
        ; Add toggles
        A_TrayMenu.Add("Auto-launch game after build", (*) => this.ToggleAutoLaunch())
        A_TrayMenu.Add("Show notifications", (*) => this.ToggleTraytips())
        A_TrayMenu.Add()
        
        ; Add configuration options
        A_TrayMenu.Add("Configure game path", (*) => this.ConfigureGamePath())
        A_TrayMenu.Add("Configure build defaults", (*) => this.ConfigureBuildDefaults())
        A_TrayMenu.Add()
        
        ; Add info options
        A_TrayMenu.Add("Show current settings", (*) => this.ShowSettings())
        A_TrayMenu.Add("Show mod builder config", (*) => UE4ModBuilder.ShowConfig())
        A_TrayMenu.Add("Help (Ctrl+Shift+H)", (*) => this.ShowHelp())
        A_TrayMenu.Add()
        
        ; Add utility options
        A_TrayMenu.Add("Reload script", (*) => Reload())
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        
        ; Update checkbox states
        this.UpdateAutoLaunchCheck()
        this.UpdateTraytipsCheck()
    }
}

; Global hotkey handlers
; Quick build with defaults: Ctrl+Shift+B
^+b:: ModHotkeyManager.BuildMod()

; Alternative quick build: F12
F12:: ModHotkeyManager.BuildMod()

; Build with custom parameters: Ctrl+Shift+Alt+B
^+!b:: ModHotkeyManager.BuildWithInput()

; Emergency stop: Ctrl+Shift+X
^+x:: ModHotkeyManager.StopAllBuilds()

; Show help: Ctrl+Shift+H
^+h:: ModHotkeyManager.ShowHelp()

; Initialize the manager on startup
ModHotkeyManager.Init()