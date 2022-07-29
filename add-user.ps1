
$usersXMLPath = "C:\ProgramData\filezilla-server\users.xml"
$usersXMLPathBackup ="C:\ProgramData\filezilla-server\backup\"
$ftpRoot = "D:\FTPRoot\"
$param = @{}
$crypt = @{}

Write-Host "### AddUser script for filezilla-server compatible with version 1.5.0 ###`n" -ForegroundColor Green
Write-Host ""
$param.username= (Read-Host -Prompt "Enter username" ).ToUpper().Trim()
$param.password= (Read-Host -Prompt "Enter password").Trim()

if(!$param.username -or $param.username -eq "" -or $param.username.Length -notmatch 6){
    Write-Host "username not valid" -ForegroundColor Red
    Timeout /T 60
    exit
}
if(!$param.password -or $param.password -eq "" -or $param.password.Length -le 7){
    Write-Host "password not valid" -ForegroundColor Red
    Timeout /T 60
    exit
}

## CONFIRM BOX ##

$title    = 'Filezilla add user'
$question = "This wil create user "+$param.username+" `nAre you sure you want to proceed?"
$choices  = '&Yes', '&No'

$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
if ($decision -eq 0) {
    Write-Host 'confirmed'
} else {
    Write-Host 'cancelled'
    exit
}
## CONFIRM BOX ##


#create credentials for new user
$cryptOutput = ($param.password | C:\Program` Files\FileZilla` Server\filezilla-server-crypt.exe user.password )
#Write-Output $cryptOutput
$cryptOutput = $cryptOutput.split()
foreach ($row in $cryptOutput){
    if($row -like "*user.password.hash=*"){
        $crypt.hash = $row.Substring($row.IndexOf("=")+1)
    
    }
    if($row -like "*user.password.iterations=*"){
        $crypt.iterations =  $row.Substring($row.IndexOf("=")+1)
    }
    if($row -like "*user.password.salt=*"){
        $crypt.salt = $row.Substring($row.IndexOf("=")+1)
    }
}
#todo validate all vars are set
#Write-Output $crypt.hash
#Write-Output $crypt.salt
#Write-Output $crypt.iterations
#Write-Output $cryptOutput


#START HACK to fix faulty xml should be fixed after filezilla server v1.5.0 see https://forum.filezilla-project.org/viewtopic.php?f=6&p=181259
Function replaceLine {
param(
    [Parameter(Mandatory=$true)][string]$File,
    [Parameter(Mandatory=$true)][string]$Match,
    [Parameter(Mandatory=$true)][string]$Replace
)
    if(Test-Path $file) {
        $Text = Get-Content $File
        $outputString = $null
        ForEach ($Line in $Text) {
            if($Line -match $Match) {
                $Line = $Replace
            }
            $outputString = $outputString + $Line
        }
        return $outputString
    } else {
        write-host "ERROR: $File file Not Found!" -ForegroundColor "RED"
    }
}

$FilezillaCFGFile = $usersXMLPath
    [xml]$FilezillaCFG = replaceLine -File $FilezillaCFGFile -Match "<filezilla fz:product_flavour=" -Replace "<filezilla>"

    $FTP_Port    = $FilezillaCFG.ftp_filezilla.server.listener.port                             #FileZilla Config FTP Port
    $FTP_PASV_PORT_MIN = $FilezillaCFG.filezilla.ftp_server.session.pasv.port_range.min         #FileZilla Config FTP Lower Passive Mode Port
    $FTP_PASV_PORT_MAX = $FilezillaCFG.filezilla.ftp_server.session.pasv.port_range.max         #FileZilla Config FTP Upper Passive Mode Port
#END HACK

    # check if user already exsists
    $FilezillaCFG.filezilla.user.ForEach(
        {
        if($_.name -eq $param.username){

             Write-Host("User already exsists. no action taken!")
             Exit
             
            }
        }  
    )
    

    # create user object
    $user = $FilezillaCFG.CreateElement("user")
    $FilezillaCFG.filezilla.AppendChild($user)| Out-Null

    $user.SetAttribute("name", $param.username)
    $user.SetAttribute("enabled", "true")

    $mount_point = $FilezillaCFG.CreateElement("mount_point")
    $mount_point.SetAttribute("tvfs_path", "/")
    $mount_point.SetAttribute("native_path", "D:\FTPRoot\"+$param.username)
    $mount_point.SetAttribute("access", "1")
    $mount_point.SetAttribute("recursive", "2")
    $user.AppendChild($mount_point)| Out-Null

    $rate_limits = $FilezillaCFG.CreateElement("rate_limits")
    $rate_limits.SetAttribute("inbound", "unlimited")
    $rate_limits.SetAttribute("outbound", "unlimited")
    $rate_limits.SetAttribute("session_inbound", "unlimited")
    $rate_limits.SetAttribute("session_outbound", "unlimited")
    $user.AppendChild($rate_limits)| Out-Null

    $user.AppendChild($FilezillaCFG.CreateElement("allowed_ips"))| Out-Null
    $user.AppendChild($FilezillaCFG.CreateElement("disallowed_ips"))| Out-Null

    $description = $FilezillaCFG.CreateElement("description")
    $description.InnerText = $param.password
    $user.AppendChild($description)| Out-Null

    $group = $FilezillaCFG.CreateElement("group")
    $group.InnerText = "supplier"
    $user.AppendChild($group)| Out-Null
    

    $password = $FilezillaCFG.CreateElement("password")
    $password.SetAttribute("index", "1")
        $hash = $FilezillaCFG.CreateElement("hash")
        $hash.InnerText = $crypt.hash
        $password.AppendChild($hash)| Out-Null

        $salt = $FilezillaCFG.CreateElement("salt")
        $salt.InnerText = $crypt.salt
        $password.AppendChild($salt)| Out-Null

        $iterations = $FilezillaCFG.CreateElement("iterations")
        $iterations.InnerText = $crypt.iterations
        $password.AppendChild($iterations)| Out-Null

    $user.AppendChild($password)| Out-Null
   
   
    # serialize the to formatted xml for debug use
    #$sw = New-Object System.IO.StringWriter
    #$writer = New-Object System.Xml.XmlTextwriter($sw)
    #$writer.Formatting = [System.XML.Formatting]::Indented
    #$FilezillaCFG.WriteContentTo($writer)    
    #Write-Output  ($sw.ToString())

    # backup xml
    $dateString = Get-Date -Format "yyyyMMddHHmmss"
    $usersXMLPathbackup = $usersXMLPathBackup +"users"+$dateString+".xml"
    
    

    try {
        Copy-Item $usersXMLPath -Destination $usersXMLPathbackup -errorAction stop | Out-Null
        Write-Output "- Created config backup $usersXMLPathbackup"
    }
    catch{
        Write-Output "Error while making backup. aborted."
        Write-Output $_.Exception.Message
        exit
    }
    (gci $usersXMLPathbackup).LastWriteTime = Get-Date


    #create FTP folders for user

    $userFolder = $ftpRoot+$param.username

    New-Item $userFolder -ItemType Directory | Out-Null
    New-Item $userFolder"\corrections" -ItemType Directory | Out-Null
    New-Item $userFolder"\processed" -ItemType Directory | Out-Null
    New-Item $userFolder"\corrections\orders" -ItemType Directory | Out-Null
    Write-Output "- Created new folders for user at $userFolder"
    

    #Save changes to users.xml
    $FilezillaCFG.save($usersXMLPath)
    Write-Output "- Updated added $params.username Users.xml at $usersXMLPath"

    # reload config 
    #https://forum.filezilla-project.org/viewtopic.php?p=179338
    Write-Output "- Signaling filezilla to reload config"
    sc.exe control filezilla-server paramchange | Out-Null
    Write-Host "- Done created user " $param.username -ForegroundColor Green

    #pause to let user read result
    Write-Host -NoNewLine 'Press any key to continue...';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');