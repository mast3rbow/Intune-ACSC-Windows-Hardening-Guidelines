# PowerShell Automation scripts
# ---------------------Variables-------------------------------------------
# Use beta Graph AP
# $true or $false
$beta = $true
$DisplayName = "Vinti"
# ---------------------Update and Install---------------------------------
# Set's execution policy to required standards
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Checks for the module, if it exsits updates the module to latest API otherwise installs the latest
Write-Host "Installing or Updating Microsoft Graph"
$isGraphInstalled = Get-InstalledModule Microsoft.Graph

if ($isGraphInstalled) {
    Write-Host "Updating Graph API"
    Update-Module Microsoft.Graph -force -verbose
}else{
    Write-Host "Installling Graph API"
    Install-Module Microsoft.Graph -force -verbose
}
Import-Module Microsoft.Graph

# Leave to leverage beta API or it will use production v1.0 API
if ($beta = $true) {
    Select-MgProfile -Name "beta"
}

# -----------------Authencation-----------------------------------
# Connects to API Graph, add scopes where required
Connect-MgGraph -Scopes 'DeviceManagementConfiguration.ReadWrite.All'

# -----------------Import JSON Scripts ---------------------------
$DisplayName = "Vinti"

$ASR = Get-Content '.\policies\ASR.json' | ConvertFrom-Json
$ASR.displayName = ($DisplayName + " Attack Surface Reduction Policies")

$UserRights = Get-Content '.\policies\UserRights.json' | ConvertFrom-Json
$UserRights.displayName = ($DisplayName + " User Rights Policies")

$WindowsHardening = Get-Content '.\policies\WindowsHardening.json' | ConvertFrom-Json
$WindowsHardening.name = ($DisplayName + " Windows Hardening Policies")

$WindowsBaseLine = Get-Content '.\policies\WindowsSecurityBaseline.json' | ConvertFrom-Json
$WindowsBaseLine.displayName = ($DisplayName + " Windows Security Baseline")

Write-Host ("Deploying " + $ASR.displayName + " Policies")
Write-Host ("Deploying " + $UserRights.displayName + " Policies")
Write-Host ("Deploying " + $WindowsHardening.name + " Policies")
Write-Host ("Deploying " + $WindowsBaseLine.displayName + " Policies")

# Convert Objects back to JSON
$JsonASR = $ASR | ConvertTo-Json -Depth 100
$JsonUserRights = $UserRights | ConvertTo-Json -Depth 100
$JsonWindowsHardening = $WindowsHardening | ConvertTo-Json -Depth 100
$JsonWindowsBaseLine = $WindowsBaseLine | ConvertTo-Json -Depth 100

# --------------------------Deploy Policies---------------------------------

# Adds Windows Hardening Policy
Invoke-MgGraphRequest -Method POST https://graph.microsoft.com/beta/deviceManagement/configurationPolicies -Body $JsonWindowsHardening

# Adds User Rights Policy
Invoke-MgGraphRequest -Method POST https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations -Body $JsonUserRights

# Adds ASR
Invoke-MgGraphRequest -Method POST https://graph.microsoft.com/beta/deviceManagement/templates/0e237410-1367-4844-bd7f-15fb0f08943b/createInstance -Body $JsonASR

# Adds Windows Baseline
Invoke-MgGraphRequest -Method POST https://graph.microsoft.com/beta/deviceManagement/templates/034ccd46-190c-4afc-adf1-ad7cc11262eb/createInstance -Body $JsonWindowsBaseLine

# ------------------------Add PowerShell Scripts-----------------------------

Get-ChildItem ".\scripts\*.ps1" |
Foreach-Object {
    write-host = "Importing Script " + $_.FullName 

    $params = @{
        ScriptName = $ScriptName
        ScriptContent = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content -Path $_.FullName -Raw -Encoding UTF8)))
        DisplayName = $_.BaseName
        Description = $_.BaseName
        RunAsAccount = "system"
        EnforceSignatureCheck = "false"
        RunAs32Bit = "false"
    }

    $Json = @"
    {
        "@odata.type": "#microsoft.graph.deviceManagementScript",
        "displayName": "$($params.DisplayName)",
        "description": "$($Params.Description)",
        "scriptContent": "$($Params.ScriptContent)",
        "runAsAccount": "$($Params.RunAsAccount)",
        "enforceSignatureCheck": $($Params.EnforceSignatureCheck),
        "fileName": "$($Params.ScriptName)",
        "runAs32Bit": $($Params.RunAs32Bit)
    }
"@

    write-host = $json
    Invoke-MgGraphRequest -Method POST https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts -Body $Json
}




