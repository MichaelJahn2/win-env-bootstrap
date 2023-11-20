oh-my-posh --init --shell pwsh --config $HOME\microverse-power-modified.omp.json | Invoke-Expression
Set-PSReadlineKeyHandler -Key Tab -Function Complete
New-Alias which get-command
New-Alias vi vim
$Env:PATH += ";C:\Program Files\Scripts;C:\Users\jahmich\AppData\Local\Programs\Git\bin;C:\Users\jahmich\AppData\Local\Programs\Git\usr\bin;C:\Program Files (x86)\GnuWin32\bin"
Set-PSReadlineKeyHandler -Key Tab -Function Complete
