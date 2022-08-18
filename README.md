# build.ps1

Simple repository for the latest version of the Tour dev helper script that can automatically update the version of your mission, pack it as a PBO, upload your mission to the Tour server, and then start a local dedicated server instance with your new mission loaded for LAN testing.

- [build.ps1](#buildps1)
  - [Prerequisites](#prerequisites)
  - [How to configure the script for your mission](#how-to-configure-the-script-for-your-mission)
  - [How to run the script](#how-to-run-the-script)
  - [OPTIONAL - Set environment variables to save entering server details every time](#optional---set-environment-variables-to-save-entering-server-details-every-time)
    - [Manually setting via PowerShell](#manually-setting-via-powershell)
    - [Manually setting via GUI](#manually-setting-via-gui)
    - [Using a PowerShell profile script](#using-a-powershell-profile-script)
  - [build.config.ps1 variable reference](#buildconfigps1-variable-reference)

## Prerequisites

Prerequisites for this helper script are as follows:

- ARMA 3 installed.
- ARMA 3 dedicated server installed.
  - Optional - To aid faster local development
- ARMA 3 Tools installed.
- PowerShell configured to allow scripts to run.
  - Already complete if you have followed the [README](https://github.com/Tour-of-Teamrespawn/.github/blob/main/profile/README.md#configure-powershell-git-and-build-script) in the org root.
  - Pretty much consists of running PowerShell as administrator and running `Set-ExecutionPolicy Unrestricted -Force -Confirm:$false` or adding `Set-ExecutionPolicy Unrestricted -Scope User` & some environment variables to your PowerShell profile.
- Tour server access to upload files via FTP. (Ask an admin for CPDeluxe access if you do not have this already).

## How to configure the script for your mission

1. Copy the `build.ps1` & `build.config.ps1` files from this repository, to the root of your mission folder.
    1. e.g. `C:\Users\user\Documents\Arma 3 - Other Profiles\ARMA_User\missions\30_tour_mission_name.Altis\build.ps1`.
2. If you want to use the start local dedicated server option, copy the `server.cfg` file to your Arma 3 install folder if you do not have one already.
    1. __NOT__ your mission folder! It should go in the same directory where the `arma3server.exe` / `arma3server_x64.exe` is located.
    2. Replace `MY_PLAYER_ID` in the file with your Arma 3 ID to get admin/debug console.
    3. If you already have a server.cfg or equivalent config file, ensure that you have a `Missions` class defined. See below for example:
```hpp
class Missions
{
	class TestMission01
	{
		template = MISSION_NAME.WORLD;
		difficulty = "veteran";
		class Params {};
	};
};
```
3. Open the `build.config.ps1` file in your text editor and make all the variables are set correctly. If required, see [Variable reference](#buildps1-variable-reference) for more information.
4. Create or edit `init.sqf` in the root of your mission folder. Then add a comment _anywhere_ in the `init.sqf` with the format `###MISSION_VERSION 0.1` leaving `###MISSION_VERSION` exactly as-is and replacing `0.1` with the current mission version.
    1. The version currently __MUST__ be in the format of `X.X` where `X` is one or more digits [`0-9`].
    2. The comment can be either a line `// comment` or multi-line block `/* comment */` type.
5. Ensure that _ALL_ other files with a reference to the mission name and version in are updated to match the right format you set for `$MissionName_WithV`. If it does not _exactly_ match, then it won't update or change a reference.

## How to run the script

1. Open a PowerShell terminal (can be the integrated terminal in VS Code).
2. Navigate to your mission folder with `cd "c:\path\to\mission\folder"`.
3. Enter and run: `.\build.ps1`.
4. Follow the on-screen script prompts, explanations for which are:
   1. Increment version and pack PBO.
      1. With automatic or manual versioning. Manually specifying version would be used to say "build / release _this_ as version 1.0" for example.
   2. Upload newly incremented & packed PBO to Tour server (requires step 1 to be chosen in this run).
      1. Specify Tour server IP (if environment variable `TOUR_SERVER_IP` is not defined).
      2. Specify Tour FTP port (if environment variable `TOUR_SERVER_PORT` is not defined).
      3. Specify Tour FTP username (if environment variable `TOUR_FTP_USERNAME` is not defined).
      4. Specify Tour FTP password (if environment variable `TOUR_FTP_PASSWORD` is not defined).
   3. Start local dedicated server with newly packed / incremented PBO.
5. (OPTIONAL) Use the script self-updater to save copy / pasting from GitHub
   1. Enter and run: `.\build.ps1 -Update`

## OPTIONAL - Set environment variables to save entering server details every time

It can get a little tedious to enter the Tour IP, FTP port, FTP user/pass each time you run the script, so there is the option to use environment variables to save entering them every run. There are various ways to set these variables, but I will cover three below. It is important to note that this so you don't have to type it out every time _but is 100% not required at all for the script to work_.

Choose __ONE__ of the following options:

1. Manually setting via PowerShell
2. Manually setting via Windows GUI
3. Using a PowerShell profile script that runs each time you open that PowerShell window

### Manually setting via PowerShell

This is the easiest option, however I have seen that it can take a _LONG_ time to apply (_1-2 minutes_) so be patient and as long as it doesn't throw an error then you'll be good to go.

Just open the terminal you will use to run the build script normally as your normal user (not as Admin) and enter:

```powershell
[Environment]::SetEnvironmentVariable("TOUR_SERVER_IP", '1.2.3.4', "User")
[Environment]::SetEnvironmentVariable("TOUR_SERVER_PORT", '8821', "User")
[Environment]::SetEnvironmentVariable("TOUR_FTP_USERNAME", 'MyCPDusername', "User")
[Environment]::SetEnvironmentVariable("TOUR_FTP_PASSWORD", 'Password123!', "User")
```

Restart your VS Code / PowerShell and then you should be good to go.

### Manually setting via GUI

This is the same as above but using the GUI, assumes Windows 10/11.

1. Click Start or press Windows Key
2. Search for & open the Settings App
3. Search for "Environment"
4. Select the option "Edit environment variables for your account"
5. In the pop-up window, click "New"
6. Enter the variable name `TOUR_SERVER_IP`
   1. Input the correct value
7. Repeat step 6 for
   1. `TOUR_SERVER_PORT`
   2. `TOUR_FTP_USERNAME`
   3. `TOUR_FTP_PASSWORD`
8. OK all Windows
9. Done

Now restart any VS Code or PowerShell windows to get the new variables.

### Using a PowerShell profile script

Open PowerShell from where you would normally run the build script, this would probably be using VS Code's integrated terminal if you use that (drag up from the bottom from between the blue/grey border and select the terminal tab) or just the normal PowerShell window if you don't.

The first step is to create the parent directory if it doesn't already exist:

```powershell
# Check the path where this PS would load a profile from, including file name
# You will notice this will be different when run from VS Code terminal and the native (blue) one
Write-Host $profile

# Create the parent directory, including any missing intermediates
mkdir $profile.substring(0,($profile).LastIndexOf('\'))
```

Then you will need to either manually create the file listed in that `$profile` variable OR run the below to create it, replacing below with actual values.

```powershell
# Create a new profile file, with specified contents
New-Item $profile -Value @"
# e.g. '12.23.34.45'
$ENV:TOUR_SERVER_IP ='ENTER_TOUR_IP'
$ENV:TOUR_SERVER_PORT = 8821
# if you have single quotes (') in your password, you can swap it below for doubles (")
$env:TOUR_FTP_PASSWORD = 'MY_PASSWORD_FOR_CPDELUXE'
$env:TOUR_FTP_USERNAME = 'MY_USERNAME_FOR_CPDELUXE'
"@
# Open up the file with your default text editor to check
Invoke-Item $Profile
```

If it all looks OK, then you can restart VS Code / PS and try to run the build script. If all is well it will not prompt you any more (until you change your CP Deluxe password!).

NOTE: If you get an error saying something like "Scripts are not allowed on this system" then you will need to open PowerShell as administrator and run: `Set-ExecutionPolicy Unrestricted -Force -Confirm:$false` and then close & re-open.

## build.config.ps1 variable reference

This section is just a reference for the script variables that can be set, split into standard variables:

- `$MissionName_withV` is likely to be the only thing you need to change if you have installed everything with default settings. Make sure you leave out the version _number_ (e.g. `1.0`) but keep the `v`.
- `$Arma3InstallFolder` is just the directory where Arma 3 is installed to. (No trailing `\`).
- `$Arma3ToolsFolder` is where your Arma 3 Tools is installed. (No trailing `\`).
- `$OutputPath` is where the script will save the PBO. Defaults to your MPMissions folder to ease local testing.
- `$FileBank_EXE` is the path to FileBank, which part of the Arma 3 Tools Steam download.

...and dedicated server variables:

- `$A3_Server` is the file path to the Arma 3 server exe.
- `$A3_Server_Config` is the file path to the `server.cfg` file.
- `$ClientModList` is the list of REQUIRED mods for your clients. Those in the default list are all Tour standard, though it is not an exhaustive list. (MUST ALREADY BE INSTALLED FROM WORKSHOP).
- `$ServerModList` is the server-side only mod list. (MUST ALREADY BE INSTALLED FROM WORKSHOP).
