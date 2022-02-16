#setup a temp dir to download some files like Hack font
$winEnvBootstrapPath = Resolve-Path .
$hackNerdFontURL = "https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Hack.zip"
$fontTargetDir = "$env:localappdata\Microsoft\Windows\Fonts"
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


Write-Host "Copying the windows hack nerd font files to user font dir $env:localappdata\Microsoft\Windows\Fonts"
Write-Host "This requires Win10 17704 upwards to work"
#Move-Item "$tempFolderPath\*Windows*.ttf" -Destination "$env:localappdata\Microsoft\Windows\Fonts" -Force


# taken from Mick IT Blog 
# article: https://mickitblog.blogspot.com/2021/06/powershell-install-fonts.html
# github repo: https://github.com/MicksITBlogs/PowerShell/blob/master/InstallFonts.ps1
# adapted to not require admin priviledges
# requires win10 17704 upwards: https://superuser.com/questions/118025/using-custom-fonts-without-administrator-rights

function Install-Font {
	param
	(
		[Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][System.IO.FileInfo]$FontFile
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
		$Copy = $true
		Write-Host ('Copying' + [char]32 + $FontFile.Name + '.....') -NoNewline
		Copy-Item -Path $fontFile.FullName -Destination ("$fontTargetDir\" + $FontFile.Name) -Force
		#Test if font is copied over
		If ((Test-Path ("$fontTargetDir\" + $FontFile.Name)) -eq $true) {
			Write-Host ('Success') -Foreground Yellow
		} else {
			Write-Host ('Failed') -ForegroundColor Red
		}
		$Copy = $false
		#Test if font registry entry exists
		If ((Get-ItemProperty -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue) -ne $null) {
			#Test if the entry matches the font file name
			If ((Get-ItemPropertyValue -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts") -eq "$fontTargetDir\$FontFile.Name") {
				Write-Host ('Adding' + [char]32 + $FontName + [char]32 + 'to the registry.....') -NoNewline
				Write-Host ('Success') -ForegroundColor Yellow
			} else {
				$AddKey = $true
				Remove-ItemProperty -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -Force
				Write-Host ('Adding' + [char]32 + $FontName + [char]32 + 'to the registry.....') -NoNewline
				New-ItemProperty -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value "$fontTargetDir\$FontFile.Name" -Force -ErrorAction SilentlyContinue | Out-Null
				If ((Get-ItemPropertyValue -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts") -eq "$fontTargetDir\$FontFile.Name") {
					Write-Host ('Success') -ForegroundColor Yellow
				} else {
					Write-Host ('Failed') -ForegroundColor Red
				}
				$AddKey = $false
			}
		} else {
			$AddKey = $true
			Write-Host ('Adding' + [char]32 + $FontName + [char]32 + 'to the registry.....') -NoNewline
			New-ItemProperty -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value "$fontTargetDir\$FontFile.Name" -Force -ErrorAction SilentlyContinue | Out-Null
			If ((Get-ItemPropertyValue -Name $FontName -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts") -eq "$fontTargetDir\$FontFile.Name") {
				Write-Host ('Success') -ForegroundColor Yellow
			} else {
				Write-Host ('Failed') -ForegroundColor Red
			}
			$AddKey = $false
		}
		
	} catch {
		If ($Copy -eq $true) {
			Write-Host ('Failed') -ForegroundColor Red
			$Copy = $false
		}
		If ($AddKey -eq $true) {
			Write-Host ('Failed') -ForegroundColor Red
			$AddKey = $false
		}
		write-warning $_.exception.message
	}
	Write-Host
}

#Get a list of all font files relative to this script and parse through the list
foreach ($FontItem in (Get-ChildItem -Path $tempFolderPath | Where-Object {
			($_.Name -like '*Windows*.ttf') 
		})) {
	Install-Font -FontFile $FontItem
}