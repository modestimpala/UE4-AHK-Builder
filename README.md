# UE4 Mod Builder

AutoHotkey v2 scripts for automating Unreal Engine 4 mod building and deployment. (Primarily for VotV but can be easily adapted)

## Requirements

- AutoHotkey v2.0
- Unreal Engine 4.27
- UE4 project file (.uproject)
- Voices of the Void (this targets 082c_011)

## Installation

1. Place both .ahk files in the same directory
2. Run `ue4_ez_build.ahk`
3. Follow setup prompts to configure paths

## Usage

### Hotkeys

- `Ctrl+Shift+B` - Quick build with defaults
- `F12` - Alternative quick build  
- `Ctrl+Shift+Alt+B` - Build with custom parameters
- `Ctrl+Shift+X` - Stop all builds
- `Ctrl+Shift+H` - Show help

### Configuration

Right-click the tray icon to:
- Set build defaults (map name, pak ID, profile, pak name)
- Configure game executable path
- Toggle auto-launch game after build
- View current settings

## First Run

The script will prompt you to:
1. Locate RunUAT.bat (usually in UE4 installation)
2. Select your .uproject file
3. Choose profiles directory
4. Set default build parameters

Configuration is saved automatically.

## In-Editor

[Primary Asset Labels](https://dev.epicgames.com/documentation/en-us/unreal-engine/cooking-content-and-creating-chunks-in-unreal-engine) are your friend. Create a label inside your mod folder and designate a Chunk ID and set to "Always Cook" and "Label Assets in My Directory"

Mod structure:

/Content/Mods/MyMod/Label_MyMod
/Content/Mods/MyMod/ModMap.umap
/Content/Mods/MyMod/MapActor
/Content/Mods/MyMod/ModActor
/Content/Mods/MyMod/...

Create a dummy actor "MapActor" with an array variable for UObjects called "objs" or similar.
In your Mod folder do Filters -> Tick All and add every asset from your mod folder EXCEPT the ModMap.umap and MapActor. Then open ModMap and place MapActor inside of the level. Save all.

Configure build settings:

Map Name: ModMap

Pak ID: Your Asset Label Chunk ID.

Profile: The r2modman profile name to copy to once cooked.

Pak Name: Should be your Mod Name. ^ i.e. MyMod (Folder structure is important)



