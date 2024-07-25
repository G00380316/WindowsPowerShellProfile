### Enoch PowerShell Profile

# Import Modules and External Profiles
if (-not (Get-Module -ListAvailable -Name Terminal-Icons)) {
    Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module -Name Terminal-Icons

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}


function explorer {
    param (
        [string]$Path = "."
    )
    Invoke-Expression "explorer.exe $Path"
}
Set-Alias -Name open -Value explorer 

# Functions

# Update PowerShell
function Update-PowerShell {
    if (-not $global:canConnectToGitHub) { return }

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
        $updateNeeded = $false
        $currentVersion = $PSVersionTable.PSVersion.ToString()
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
        if ($currentVersion -lt $latestVersion) {
            $updateNeeded = $true
        }

        if ($updateNeeded) {
            Write-Host "Updating PowerShell..." -ForegroundColor Yellow
            winget upgrade "Microsoft.PowerShell" --accept-source-agreements --accept-package-agreements
            Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
        } else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    } catch {
        Write-Error "Failed to update PowerShell. Error: $_"
    }
}
Update-PowerShell

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}

$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
        elseif (Test-CommandExists pvim) { 'pvim' }
        elseif (Test-CommandExists vim) { 'vim' }
        elseif (Test-CommandExists vi) { 'vi' }
        elseif (Test-CommandExists code) { 'code' }
        elseif (Test-CommandExists notepad++) { 'notepad++' }
        elseif (Test-CommandExists sublime_text) { 'sublime_text' }
        else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

function Edit-Profile {
    vim $PROFILE.CurrentUserAllHosts
}

function touch($file) { "" | Out-File $file -Encoding ASCII }

function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

function winutil {
    iwr -useb https://christitus.com/win | iex
}

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = "& '$args'"
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}
Set-Alias -Name su -Value admin

function uptime {
    if ($PSVersionTable.PSVersion.Major -eq 5) {
        Get-WmiObject win32_operatingsystem | Select-Object @{Name='LastBootUpTime'; Expression={$_.ConverttoDateTime($_.lastbootuptime)}} | Format-Table -HideTableHeaders
    } else {
        net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
    }
}

function reload-profile { & $profile }

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}

function grep($regex, $dir) {
    if ($dir) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df { get-volume }

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content $Path -Tail $n -Wait:$f
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

# Navigation Shortcuts
function docs { Set-Location -Path $HOME\OneDrive\Documents }
function dtop { Set-Location -Path $HOME\OneDrive\Desktop }
function ep { vim $PROFILE }

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Devlopers
function runs {
    param([string]$scriptPath)

    # Check if the file exists
    if (-not (Test-Path $scriptPath)) {
        Write-Error "File not found: $scriptPath"
        return
    }

    # Get file extension and directory information
    $extension = [System.IO.Path]::GetExtension($scriptPath).ToLower()
    $dir = [System.IO.Path]::GetDirectoryName($scriptPath)
    $filename = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)

    # Determine the appropriate action based on file extension
    switch ($extension) {
        ".xml" {
            $option = Read-Host "Enter number based on the lifecycle you want to start `n1. clean`n2. validate`n3. compile`n4. test`n5. package`n6. verify`n7. install`n8. site`n9. deploy`n10. custom`n`nEnter option"
            switch ($option) {
               "1" {
                  mvn clean
                  $option = Read-Host "Do you want to run the Package lifecycle y(Yes) or n(No)"
                  if($option -eq "y"){
                     mvn package
                  }
                  else{}
               }
               "2" {
                  mvn validate
               }
               "3" {
                  mvn compile                                                                             
               }
               "4" {
                  mvn test
               }
               "5" {
                  mvn package
               }
               "6" {
                  mvn verify
               }
               "7" {
                  mvn install
               }
               "8" {
                  mvn site
               }
               "9" {
                  mvn deploy
               }
               "10" {
                  $custom = Read-Host "Enter custom command (e.g mvn [Fill])"
                  mvn $custom
               }
               default { 
                  Write-Error "Not a valid option: $option"
               }
            }
        }
        ".py" {
            python $scriptPath
        }
        ".rb" {
            ruby $scriptPath
        }
        ".json" {
        $option = Read-Host "Enter letter based on what kind of Server you want to start d (Dev) or s (Prod) or b (Build) or c (For entering a custom command)"
            if ($option -eq "d" -or $option -eq "D") {
                npm run dev
            } elseif ($option -eq "s" -or $option -eq "S") {
                npm run start
            } elseif ($option -eq "b" -or $option -eq "B") {
                npm run build -Wait
                $option = Read-Host "Do you want to run Production straight away y(Yes) or n(No)"
                if($option -eq "y"){
                npm run start
                }
                else{}
            } elseif ($option -eq "c" -or $option -eq "C") {
                $custom = Read-Host "Enter custom command (e.g npm run [Fill])"
                npm run $custom
            } else {
                Write-Error "Not a valid option: $option"
            }
        }
        ".js" {
            node $scriptPath
        }
        ".ts" {
            if (Test-Path "$dir/tsconfig.json") {
                tsc
                $jsFile = [System.IO.Path]::ChangeExtension($scriptPath, ".js")
                node $jsFile
            } else {
                tsc $scriptPath
                $jsFile = [System.IO.Path]::ChangeExtension($scriptPath, ".js")
                node $jsFile
            }
        }
        ".java" {
            javac $scriptPath
            $mainClassName = $filename
            $packagePath = Get-JavaPackagePath $scriptPath
            if ($packagePath) {
                $mainClassName = "$packagePath.$filename"
            }
            java $mainClassName
        }
        ".cpp" {
            $cppFiles = Get-ChildItem $dir -Filter *.cpp
            $objectFiles = @()
            foreach ($file in $cppFiles) {
                $objectFile = [System.IO.Path]::ChangeExtension($file.FullName, ".o")
                g++ -c $file.FullName -o $objectFile
                $objectFiles += $objectFile
            }
            $exeFile = "$dir\$filename.exe"
            g++ $objectFiles -o $exeFile
            & $exeFile
        }
        ".cs" {
            if (Test-Path "$dir/*.csproj") {
                Set-Location $dir
                dotnet run
            } else {
                $exeFile = "$dir\$filename.exe"
                csc $scriptPath
                & $exeFile
            }
        }
        ".php" {
            php $scriptPath
        }
        ".pl" {
            perl $scriptPath
        }
        ".sh" {
            bash $scriptPath
        }
        ".r" {
            Rscript $scriptPath
        }
        ".ps1" {
            & $scriptPath
        }
        ".go" {
            go run $scriptPath
        }
        ".hs" {
            runhaskell $scriptPath
        }
        ".kt" {
            kotlinc -script $scriptPath
        }
        ".swift" {
            swift $scriptPath
        }
        ".c" {
            $cFiles = Get-ChildItem $dir -Filter *.c
            $objectFiles = @()
            foreach ($file in $cFiles) {
                $objectFile = [System.IO.Path]::ChangeExtension($file.FullName, ".o")
                gcc -c $file.FullName -o $objectFile
                $objectFiles += $objectFile
            }
            $exeFile = "$dir\$filename.exe"
            gcc $objectFiles -o $exeFile
            & $exeFile
        }
        default {
            Write-Error "Unsupported file extension: $extension"
        }
    }
}

# Function to get Java package path from a Java source file
function Get-JavaPackagePath {
    param([string]$javaFilePath)

    # Get the package path if the file is inside a package
    $packagePath = ""
    $packageStatement = Get-Content $javaFilePath | Where-Object { $_ -match "^package\s+([\w\.]+)\s*;" }
    if ($packageStatement) {
        $packagePath = $matches[1].Replace(".", "\")
    }
    return $packagePath
}

# Add the 'run' alias for 'runs' function to the PowerShell profile
Set-Alias -Name run -Value runs

# Docker 

# List Docker Containers
function dp {
    docker ps
}

# Start Docker Container
function dstart {
    param([string]$containerName)
    docker start $containerName
}

# Stop Docker Container
function dstop {
    param([string]$containerName)
    docker stop $containerName
}

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Git Shortcuts
function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gp { git push }
function gb {
    git branch
}

function gcl { git clone "$args" }
function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}
function gpull {
    $repos = Get-ChildItem -Directory
    foreach ($repo in $repos) {
        Write-Host "Pulling $repo"
        Set-Location $repo.FullName
        git pull
        Set-Location ..
    }
}

# Github CLI Shortcuts

function gas {
    gh auth status
}

function gcr {
    param($repo)
    gh repo clone $repo
}

Set-Alias -Name clone -Value gcr

function grc {
        $Option = Read-Host "Do you want the Repository to be Public? y(Yes) or n(NO)"
        if($Option -eq "y" -or $Option -eq "Y"){
        $name = Read-Host "Enter the name of the Repository"
        gh repo create $name --public --source=. --remote=origin
        git push --set-upstream origin main
        }
        else{
        $name = Read-Host "Enter the name of the Repository"
        gh repo create $name --private --source=. --remote=origin
        git push --set-upstream origin main
        }
}

Set-Alias -Name cremote -Value grc

function grl {
   gh repo list 
}

Set-Alias -Name repos -Value grl

# Enhanced PowerShell Experience
Set-PSReadLineOption -Colors @{
    Command = 'Yellow'
    Parameter = 'Green'
    String = 'DarkCyan'
}

# Get theme from profile.ps1 or use a default theme
function Get-Theme {
    if (Test-Path -Path $PROFILE.CurrentUserAllHosts -PathType leaf) {
        $existingTheme = Select-String -Raw -Path $PROFILE.CurrentUserAllHosts -Pattern "oh-my-posh init pwsh --config"
        if ($null -ne $existingTheme) {
            Invoke-Expression $existingTheme
            return
        }
    } else {
        # This my own personal one so you can remove it otherwise one from the Internet should run
        oh-my-posh init pwsh --config 'C://Users/balli/OneDrive/Documents/Useful bat files/WindowsTerminal/jandedobbeleer.omp.json' | Invoke-Expression
        #oh-my-posh init pwsh --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json | Invoke-Expression
    }
}
Get-Theme

# Check if the GitHub CLI is installed
if (Get-Command gh -ErrorAction SilentlyContinue) {
} elseif (Get-Command -Name winget -ErrorAction SilentlyContinue) {
        try {
            Write-Host "GitHub CLI command not found. Attempting to install via Winget..."
            # Install GitHub CLI using Winget
            winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
            Write-Host "GitHub CLI installed successfully. Initializing..."
            # Authenticate with GitHub
            gh auth login
        } catch {
            Write-Error "Failed to install GitHub CLI. Error: $_"
        }
    } else {
        Write-Error "Winget is not available on this system. Please install Winget and try again."
    }

# Zoxide check
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

# Help Function
function Show-Help {
    @"
PowerShell Profile Help
=======================

runs - Used to run files ("Type in the file path with name and type after example 'run C://User/Documents/HelloWorld.java', Note: if your in the dir of the file you want to run then just enter the command like this 'run HelloWorld')
Update-PowerShell - Checks for the latest PowerShell release and updates if a new version is available.
Edit-Profile - Opens the current user's profile for editing using the configured editor.
touch <file> - Creates a new empty file.
ff <name> - Finds files recursively with the specified name.
Get-PubIP - Retrieves the public IP address of the machine.
winutil - Runs the WinUtil script from Chris Titus Tech.
uptime - Displays the system uptime.
reload-profile - Reloads the current user's PowerShell profile.
unzip <file> - Extracts a zip file to the current directory.
grep <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input.
df - Displays information about volumes.
sed <file> <find> <replace> - Replaces text in a file.
which <name> - Shows the path of the command.
export <name> <value> - Sets an environment variable.
pkill <name> - Kills processes by name.
pgrep <name> - Lists processes by name.
head <path> [n] - Displays the first n lines of a file (default 10).
tail <path> [n] - Displays the last n lines of a file (default 10).
nf <name> - Creates a new file with the specified name.
mkcd <dir> - Creates and changes to a new directory.
docs - Changes the current directory to the user's Documents folder.
dtop - Changes the current directory to the user's Desktop folder.
ep - Opens the profile for editing.
k9 <name> - Kills a process by name.
la - Lists all files in the current directory with detailed formatting.
ll - Lists all files, including hidden, in the current directory with detailed formatting.
gs - Shortcut for 'git status'.
ga - Shortcut for 'git add .'.
gc <message> - Shortcut for 'git commit -m'.
gp - Shortcut for 'git push'.
gas - Gets Github authentication status
grc - Creates a new Github Repostiory
gcom <message> - Adds all changes and commits with the specified message.
lazyg <message> - Adds all changes, commits with the specified message, and pushes to the remote repository.
sysinfo - Displays detailed system information.
flushdns - Clears the DNS cache.
Use 'Show-Help' to display this help message.
"@
}

Write-Host "Use 'Show-Help' to display help"

