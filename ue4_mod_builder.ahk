; UE4 Mod Builder - AutoHotkey v2 Script
class UE4ModBuilder {
    
    static ConfigFile := A_ScriptDir . "\ue4_mod_builder.ini"
    static UATPath := ""
    static ProjectPath := ""
    static UseDefaultProfiles := true
    static ProfilesDir := ""
    static DefaultProfilesDir := A_AppData . "\r2modmanPlus-local\VotV\profiles"
    
    ; Initialize the builder - call this first
    static Init() {
        this.LoadConfig()
        
        ; Check UAT path
        if (!this.UATPath || !FileExist(this.UATPath)) {
            this.SetupUAT()
        }
        
        ; Check project path
        if (!this.ProjectPath || !FileExist(this.ProjectPath)) {
            this.SetupProject()
        }
        
        ; Setup profiles
        this.SetupProfiles()
        
        this.SaveConfig()
    }
    
    ; Main build function - callable from other scripts
    static BuildMod(mapname, pakID, profile, pakName) {
        if (!mapname || !pakID || !profile || !pakName) {
            MsgBox("Error: All parameters required (mapname, pakID, profile, pakName)", "UE4 Mod Builder", 16)
            return false
        }
        
        ; Ensure initialization
        if (!this.UATPath || !this.ProjectPath) {
            this.Init()
        }
        
        OutputDebug("========================================")
        OutputDebug("Building mod with parameters:")
        OutputDebug("Map: " . mapname)
        OutputDebug("Pak ID: " . pakID)
        OutputDebug("Profile: " . profile)
        OutputDebug("Pak Name: " . pakName)
        OutputDebug("========================================")
        
        ; Build the mod
        if (!this.RunUATBuild(mapname)) {
            return false
        }
        
        ; Copy pak file
        if (!this.CopyPakFile(pakID, profile, pakName)) {
            return false
        }
        
        ; Success
        OutputDebug("========================================")
        OutputDebug("SUCCESS! Mod built and copied.")
        OutputDebug("========================================")
        
        ; Play success sound
        try {
            SoundPlay("C:\Windows\Media\chimes.wav", true)
        }
        
        return true
    }
    
    ; Get available profiles
    static GetProfiles() {
        profiles := []
        profilesPath := this.UseDefaultProfiles ? this.DefaultProfilesDir : this.ProfilesDir
        
        ; Debug output
        OutputDebug("Looking for profiles in: " . profilesPath)
        OutputDebug("Directory exists: " . DirExist(profilesPath))
        
        if (!DirExist(profilesPath)) {
            OutputDebug("Profile directory does not exist")
            return profiles
        }
        
        Loop Files, profilesPath . "\*", "D" {
            OutputDebug("Found profile directory: " . A_LoopFileName)
            profiles.Push(A_LoopFileName)
        }
        
        OutputDebug("Total profiles found: " . profiles.Length)
        return profiles
}
    
    ; Setup UAT path
    static SetupUAT() {
        ; Try common locations first (4.27 ONLY)
        commonPaths := [
            "C:\Program Files\Epic Games\UE_4.27\Engine\Build\BatchFiles\RunUAT.bat"
        ]
        
        for path in commonPaths {
            if (FileExist(path)) {
                this.UATPath := path
                OutputDebug("Found UAT at: " . path)
                return
            }
        }
        
        ; If not found, prompt user
        MsgBox("UAT (RunUAT.bat) not found in common locations. Please select the file.", "UE4 Mod Builder", 64)
        selectedFile := FileSelect(1, "C:\Program Files\Epic Games", "Select RunUAT.bat", "Batch Files (*.bat)")
        
        if (selectedFile) {
            this.UATPath := selectedFile
        } else {
            MsgBox("UAT path is required. Exiting.", "UE4 Mod Builder", 16)
            ExitApp()
        }
    }
    
    ; Setup project path
    static SetupProject() {
        MsgBox("Please select your .uproject file.", "UE4 Mod Builder", 64)
        selectedFile := FileSelect(1, A_MyDocuments, "Select .uproject file", "Unreal Project Files (*.uproject)")
        
        if (selectedFile) {
            this.ProjectPath := selectedFile
        } else {
            MsgBox("Project file is required. Exiting.", "UE4 Mod Builder", 16)
            ExitApp()
        }
    }
    
    ; Setup profiles
    static SetupProfiles() {
        result := MsgBox("Use default AppData profiles directory?`n`n" . this.DefaultProfilesDir, "UE4 Mod Builder", 4)
        
        if (result = "Yes") {
            this.UseDefaultProfiles := true
            this.ProfilesDir := this.DefaultProfilesDir
        } else {
            this.UseDefaultProfiles := false
            MsgBox("Please select your profiles directory.", "UE4 Mod Builder", 64)
            selectedDir := DirSelect("*" . A_AppData, 2, "Select profiles directory")
            
            if (selectedDir) {
                this.ProfilesDir := selectedDir
            } else {
                ; Fall back to default
                this.UseDefaultProfiles := true
                this.ProfilesDir := this.DefaultProfilesDir
            }
        }
        
        ; Show available profiles
        profiles := this.GetProfiles()
        if (profiles.Length > 0) {
            profileList := ""
            for profile in profiles {
                profileList .= profile . "`n"
            }
            MsgBox("Available profiles:`n" . profileList, "UE4 Mod Builder", 64)
        } else {
            MsgBox("No profiles found in: " . this.ProfilesDir, "UE4 Mod Builder", 48)
        }
    }
    
    ; Run UAT build
    static RunUATBuild(mapname) {
        OutputDebug("Starting UAT build...")
        
        ; Create output file path
        outputFile := A_ScriptDir . "\uat_build_output.log"
        
        ; Build command
        baseCommand := '"' . this.UATPath . '" BuildCookRun -project="' . this.ProjectPath . '" -platform=Win64 -cook -map=' . mapname . ' -stage -pak -package -clientconfig=Shipping -AdditionalCookerOptions="-cookprocesscount=8"'
        
        ; Use CMD to run and capture output
        command := 'cmd /c "' . baseCommand . ' > "' . outputFile . '" 2>&1"'
        
        ; Run the command
        result := RunWait(command, , "Hide")
        
        ; Process the output file
        if (FileExist(outputFile)) {
            try {
                buildOutput := FileRead(outputFile)
                OutputDebug("Build output captured (" . StrLen(buildOutput) . " chars)")
                errorLines := this.ExtractErrorLines(buildOutput)

                ; If there are errors, show them
                if (errorLines != "") {
                    MsgBox("Build errors found:`n`n" . errorLines, "UE4 Mod Builder - Build Errors", 16)
                } else {
                    OutputDebug("No errors found in build output.")
                }
                
            } catch Error as e {
                OutputDebug("Failed to read output file: " . e.Message)
            }
        }
        
        if (result != 0) {
            MsgBox("Build failed! Error code: " . result . "`n`nFull output saved to: " . outputFile, "UE4 Mod Builder", 16)
            return false
        }
        
        OutputDebug("Build completed successfully.")
        return true
    }

    ; Helper method to extract UAT-specific error information from output
    static ExtractErrorLines(output) {
        lines := StrSplit(output, "`n")
        errorInfo := ""
        
        ; Look for the key UAT error patterns at the end of the log
        for i, line in lines {
            line := Trim(line)
            
            ; Capture ERROR: lines (main error description)
            if (InStr(line, "ERROR:")) {
                errorInfo .= line . "`n"
            }
            
            ; Capture AutomationTool exit codes
            else if (InStr(line, "AutomationTool exiting with ExitCode=")) {
                ; Only if the exit code is not 0
                match := ""
                if (RegExMatch(line, "ExitCode=(\d+)", &match) && match[1] != "0") {
                    errorInfo .= "AutomationTool exit code: " . match[1] . "`n"
                }
            }
            
            ; Capture BUILD FAILED
            else if (InStr(line, "BUILD FAILED")) {
                errorInfo .= line . "`n"
            }
            
            ; Capture log file references for debugging
            else if (InStr(line, "(see ") && InStr(line, "Log.txt")) {
                errorInfo .= line . "`n"
            }
            
            ; Capture COMMAND FAILED patterns
            else if (InStr(line, "COMMAND FAILED") || InStr(line, "Failed.")) {
                errorInfo .= line . "`n"
            }
        }
        ; If no errors found, we'll return a nothing string
        return errorInfo
    }
    
    ; Copy pak file
    static CopyPakFile(pakID, profile, pakName) {
        ; Get project directory from project path
        projectDir := RegExReplace(this.ProjectPath, "\\[^\\]+\.uproject$", "")
        
        sourcePak := projectDir . "\Saved\StagedBuilds\WindowsNoEditor\VotV\Content\Paks\pakchunk" . pakID . "-WindowsNoEditor.pak"
        
        profilesPath := this.UseDefaultProfiles ? this.DefaultProfilesDir : this.ProfilesDir
        destDir := profilesPath . "\" . profile . "\shimloader\pak"
        destPak := destDir . "\" . pakName . ".pak"
        
        OutputDebug("========================================")
        OutputDebug("Copying pak file...")
        OutputDebug("From: " . sourcePak)
        OutputDebug("To: " . destPak)
        OutputDebug("========================================")
        
        ; Create destination directory if it doesn't exist
        if (!DirExist(destDir)) {
            OutputDebug("Creating directory: " . destDir)
            DirCreate(destDir)
        }
        
        ; Check if source file exists
        if (!FileExist(sourcePak)) {
            errorMsg := "ERROR: Source pak file not found: " . sourcePak . "`n`nAvailable pak files:"
            
            ; List available pak files
            pakDir := projectDir . "\Saved\StagedBuilds\WindowsNoEditor\VotV\Content\Paks"
            if (DirExist(pakDir)) {
                Loop Files, pakDir . "\*.pak" {
                    errorMsg .= "`n" . A_LoopFileName
                }
            }
            
            MsgBox(errorMsg, "UE4 Mod Builder", 16)
            return false
        }
        
        ; Copy the file
        try {
            FileCopy(sourcePak, destPak, true)
            OutputDebug("File copied successfully.")
            OutputDebug("Pak file location: " . destPak)
            return true
        } catch Error as e {
            MsgBox("Copy failed! " . e.Message, "UE4 Mod Builder", 16)
            return false
        }
    }
    
    ; Load configuration
    static LoadConfig() {
        if (FileExist(this.ConfigFile)) {
            this.UATPath := IniRead(this.ConfigFile, "Paths", "UAT", "")
            this.ProjectPath := IniRead(this.ConfigFile, "Paths", "Project", "")
            this.UseDefaultProfiles := IniRead(this.ConfigFile, "Profiles", "UseDefault", "1") = "1"
            this.ProfilesDir := IniRead(this.ConfigFile, "Profiles", "Directory", this.DefaultProfilesDir)
        }
    }
    
    ; Save configuration
    static SaveConfig() {
        IniWrite(this.UATPath, this.ConfigFile, "Paths", "UAT")
        IniWrite(this.ProjectPath, this.ConfigFile, "Paths", "Project")
        IniWrite(this.UseDefaultProfiles ? "1" : "0", this.ConfigFile, "Profiles", "UseDefault")
        IniWrite(this.ProfilesDir, this.ConfigFile, "Profiles", "Directory")
    }
    
    ; Reset configuration (helper function)
    static ResetConfig() {
        if (FileExist(this.ConfigFile)) {
            FileDelete(this.ConfigFile)
        }
        this.UATPath := ""
        this.ProjectPath := ""
        this.UseDefaultProfiles := true
        this.ProfilesDir := this.DefaultProfilesDir
        this.Init()
    }
    
    ; Show current configuration (helper function)
    static ShowConfig() {
        config := "Current Configuration:`n`n"
        config .= "UAT Path: " . this.UATPath . "`n"
        config .= "Project Path: " . this.ProjectPath . "`n"
        config .= "Use Default Profiles: " . (this.UseDefaultProfiles ? "Yes" : "No") . "`n"
        config .= "Profiles Directory: " . this.ProfilesDir . "`n`n"
        
        profiles := this.GetProfiles()
        if (profiles.Length > 0) {
            config .= "Available Profiles:`n"
            for profile in profiles {
                config .= "  • " . profile . "`n"
            }
        } else {
            config .= "No profiles found."
        }
        
        MsgBox(config, "UE4 Mod Builder - Configuration", 64)
    }
}

; Example usage (uncomment to test):
; UE4ModBuilder.Init()
; UE4ModBuilder.BuildMod("jermatest", "3", "idk", "Jerma")

; Helper functions for external calling:

; Initialize the mod builder
ModBuilder_Init() {
    UE4ModBuilder.Init()
}

; Build a mod
ModBuilder_Build(mapname, pakID, profile, pakName) {
    return UE4ModBuilder.BuildMod(mapname, pakID, profile, pakName)
}

; Get available profiles
ModBuilder_GetProfiles() {
    return UE4ModBuilder.GetProfiles()
}

; Show configuration
ModBuilder_ShowConfig() {
    UE4ModBuilder.ShowConfig()
}

; Reset configuration
ModBuilder_ResetConfig() {
    UE4ModBuilder.ResetConfig()
}