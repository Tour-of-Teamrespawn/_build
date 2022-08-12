# build.ps1

Simple repository for the latest version of the helper script to automatically update the version, pack as PBO and upload your mission to the Tour server.

- [build.ps1](#buildps1)
  - [Prerequisites](#prerequisites)
  - [How to configure](#how-to-configure)
  - [How to run](#how-to-run)
  - [build.ps1 variable reference](#buildps1-variable-reference)

## Prerequisites

Prerequisites for this helper script are as follows:

- ARMA 3 installed.
- ARMA 3 dedicated server installed.
  - Optional - To aid faster local development
- ARMA 3 Tools installed.
- PowerShell configured to allow scripts to run.
  - Already complete if you have followed the [README](https://github.com/Tour-of-Teamrespawn/.github/blob/main/profile/README.md#configure-powershell-git-and-build-script) in the org root.
  - Pretty much consists of running PowerShell as administrator and running `Set-ExecutionPolicy Unrestricted -Force -Confirm:$false` or adding `Set-ExecutionPolicy Unrestricted -Scope User` & some environment variables to your PowerShell profile.
- Tour server access to upload files via FTP. (Ask an admin for CPDeluxe access if you do not have this already)

## How to configure

1. Copy the `build.ps1` from this repository, to the root of your mission folder.
    1. e.g. `C:\Users\user\Documents\Arma 3 - Other Profiles\ARMA_User\missions\30_tour_mission_name.Altis\build.ps1`
2. If you want to use the start local dedicated server option, copy the `server.cfg` file to your Arma 3 install folder if you do not have one already.
    1. __NOT__ your mission folder! It should go in the same directory where the `arma3server.exe` / `arma3server_x64.exe` is located
    2. Replace `MY_PLAYER_ID` in the file with your Arma 3 ID to get admin/debug console.
3. Open the `build.ps1` file in your text editor and make all the variables are set correctly. If required, see [Variable reference](#buildps1-variable-reference) for more information.
4. Create or edit `init.sqf` in the root of your mission folder. Then add a comment _anywhere_ in the `init.sqf` with the format `###MISSION_VERSION 0.1` leaving `###MISSION_VERSION` exactly as-is and replacing `0.1` with the current mission version.
    1. The version currently __MUST__ be in the format of `X.X` where `X` is one or more digits [`0-9`].
    2. The comment can be either a line `// comment` or multi-line block `/* comment */` type.
5. Ensure that _ALL_ other files with a reference to the mission name and version in are updated to match the right format you set for `$MissionName_WithV`. If it does not _exactly_ match, then it won't update or change a reference.

## How to run

1. Open a PowerShell terminal (can be the integrated terminal in VS Code)
2. Navigate to your mission folder with `cd "c:\path\to\mission\folder"`
3. Enter and run: `.\build.ps1`
4. Follow the script prompts for desired options
5. ???
6. profit

## build.ps1 variable reference

This section is just a reference for the script variables that can be set, split into standard variables:

- `$MissionName_withV` is likely to be the only thing you need to change if you have installed everything with default settings. Make sure you leave out the version _number_ (e.g. `1.0`) but keep the `v`.
- `$Arma3InstallFolder` is just the directory where Arma 3 is installed to. (No trailing `\`).
- `$Arma3ToolsFolder` is where your Arma 3 Tools is installed. (No trailing `\`).
- `$OutputPath` is where the script will save the PBO. Defaults to your MPMissions folder to ease local testing.

...and dedicated server variables:

- `$A3_Server` is the file path to the Arma 3 server exe.
- `$A3_Server_Config` is the file path to the `server.cfg` file.
- `$ClientModList` is the list of REQUIRED mods for your clients. Those in the default list are all Tour standard, though it is not an exhaustive list. (MUST ALREADY BE INSTALLED FROM WORKSHOP).
- `$ServerModList` is the server-side only mod list. (MUST ALREADY BE INSTALLED FROM WORKSHOP).
