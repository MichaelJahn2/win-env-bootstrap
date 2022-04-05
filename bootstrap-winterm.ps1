winget install JanDeDobbeleer.OhMyPosh

#setup a temp dir to download some files like Hack font
$winEnvBootstrapPath = Resolve-Path .
$hackNerdFontURL = "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Hack.zip"
$tempFolderPath = Join-Path $Env:Temp $(New-Guid)

New-Item -Type Directory -Path $tempFolderPath | Out-Null

# welp. symbolic links require admin priviledges in Windows. Keeping this option for later.
# so we stupidly just copy files instead of linking to the git directory
#New-Item -ItemType SymbolicLink -path "$profile" -Target "$winEnvBootstrapPath\powershell-profile.ps1"

Write-Host "Copy Powershell Profile to ~profile"
New-Item -Path $profile -ItemType "file" -Force
Copy-Item powershell-profile.ps1 $profile 

Write-Host "Copy my oh-my-posh to home dir"
Copy-Item microverse-power-modified.omp.json ~

Write-Host "Download Hack Nerd Font to $tempFolderPath"
Invoke-WebRequest -Uri "$hackNerdFontURL" -OutFile "$tempFolderPath\hack.zip"

Write-Host "Extracting Hack Nerd Font files to $tempFolderPath"
Expand-Archive -LiteralPath "$tempFolderPath\hack.zip" -DestinationPath "$tempFolderPath"

# taken from Mick IT Blog 
# article: https://mickitblog.blogspot.com/2021/06/powershell-install-fonts.html
# github repo: https://github.com/MicksITBlogs/PowerShell/blob/master/InstallFonts.ps1
# adapted to not require admin priviledges
# requires win10 17704 upwards: https://superuser.com/questions/118025/using-custom-fonts-without-administrator-rights
function Install-Font {
	param
	(
		[Parameter(Mandatory)][ValidateNotNullOrEmpty()][System.IO.FileInfo]$FontFile,
		[Parameter(Mandatory)][Boolean]$InstallSystemWide
	)
	
	#Get Font Name from the File's Extended Attributes
	$oShell = new-object -com shell.application
	$Folder = $oShell.namespace($FontFile.DirectoryName)
	$Item = $Folder.Items().Item($FontFile.Name)
	$FontName = $Folder.GetDetailsOf($Item, 21)
	try {
		switch ($FontFile.Extension) {
			".ttf" {$FontName = $FontName + [char]32 + '(TrueType)'}
			".otf" {$FontName = $FontName + [char]32 + '(OpenType)'}
		}
		if ($InstallSystemWide) {
				$fontTarget = $env:windir + "\Fonts\" + $FontFile.Name
				$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
				$regValue = $FontFile.Name
				$regName = $FontName
		} else {
				# Check whether Windows Version is high enough to support per-user font installation without admin rights
				$winMajorVersion = [Environment]::OSVersion.Version.Major
				$winBuild = [Environment]::OSVersion.Version.Build
				If ( -not (($winMajorVersion -ge 10) -and ($winBuild -ge 17044))) {
					throw "At least Windows 10 Build 17044 is required for local user installation. You have Win $winMajorVersion Build $winBuild."
				}
				$fontTarget = $env:localappdata + "\Microsoft\Windows\Fonts\" + $FontFile.Name
				$regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
				$regValue = $fontTarget
				$regName = $FontName
		}

		$CopyFailed = $true
		Write-Host ("Copying $($FontFile.Name).....") -NoNewline
		Copy-Item -Path $fontFile.FullName -Destination ($fontTarget) -Force
		# Test if font is copied over
		If ((Test-Path ($fontTarget)) -eq $true) {
			Write-Host ('Success') -Foreground Yellow
		} else {
			Write-Host ('Failed to copy file') -ForegroundColor Red
		}
		$CopyFailed = $false

		# Create Registry item for font
		Write-Host ("Adding $FontName to the registry.....") -NoNewline
		If (!(Test-Path $regPath)) {
			New-Item -Path $regPath -Force | Out-Null
		}
		New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType string -Force -ErrorAction SilentlyContinue| Out-Null

		$AddKeyFailed = $true
		If ((Get-ItemPropertyValue -Name $regName -Path $regPath) -eq $regValue) {
			Write-Host ('Success') -ForegroundColor Yellow
		} else {
			Write-Host ('Failed to set registry key') -ForegroundColor Red
		}
		$AddKeyFailed = $false
		
	} catch {
		If ($CopyFailed -eq $true) {
			Write-Host ('Font file copy Failed') -ForegroundColor Red
			$CopyFailed = $false
		}
		If ($AddKeyFailed -eq $true) {
			Write-Host ('Registry Key Creation Failed') -ForegroundColor Red
			$AddKeyFailed = $false
		}
		write-warning $_.exception.message
	}
	Write-Host
}

#Get a list of all font files relative to this script and parse through the list
foreach ($FontItem in (Get-ChildItem -Path $tempFolderPath | Where-Object {
			($_.Name -like '*.ttf') -or ($_.Name -like '*.OTF')
		})) {
	Install-Font -FontFile $FontItem $false
}

