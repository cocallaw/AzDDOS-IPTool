#region variables
$filepathp = ".\pipresources.json"
$filepathv = ".\vnetresources.json"
$filepathr = ".\Az_PIP_DDOS_Report-$(get-date -Format yyyyMMdd).csv"
$pipinfo = @()
$vnetinfo = @()
#endregion variables
#-----------------------------------------------------------------------------------------------------------------------
#region functions
function Get-PIPResources {
    if ($context) {
        $pipResource = @()
        $allSub = Get-AzSubscription
        Write-Host "Collecting information on Publiic IP and Virtual Network resources for all subscriptions..." -ForegroundColor Yellow
        $allSub | foreach {
            Set-AzContext -SubscriptionId $_.Id
            $pipResource += Get-AzPublicIpAddress
            $vnetResource += Get-AzVirtualNetwork
        }
        $pipResource | ConvertTo-Json | Out-File pipresources.json
        $vnetResource | ConvertTo-Json | Out-File vnetresources.json
        Write-Host "Finished collecting Public IP and Virtual Network information" -ForegroundColor Green
    }
    else {
        Write-Host "Please Login first in order to continue" -ForegroundColor Red
    }
}
function Get-IPConfigDetails {
    param (
        [Parameter(Mandatory)]
        [String]$ipconfigtext,
        [Parameter(Mandatory)]
        [String]$pipName,
        [Parameter(Mandatory)]
        [String]$pipAddr,
        [Parameter(Mandatory)]
        [String]$pipID
    )
    $piphtable = @{}
    $array = $ipconfigtext.Split('/') 
    $pipID = Get-AzSubFromID -subid $pipID 
    $piphtable = @{RG = $array[4]; RType = $array[7]; RName = $array[8]; PIPn = $pipName; PIPa = $pipAddr; PIPsub = $pipID }
    $objectp = New-Object psobject -Property $piphtable
    return $objectp
}
function Get-ConfigDetailsFromBEID {
    param (
        [Parameter(Mandatory)]
        [String]$BEnicconfigID
    )
    $lbhtable = @{}
    $array = $BEnicconfigID.Split('/')
    $lbhtable = @{RG = $array[4]; RType = $array[7]; RName = $array[8] }
    $object = New-Object psobject -Property $lbhtable
    return $object
}
function Get-VnetDetails {
    param (
        [Parameter(Mandatory)]
        [String]$vName,
        [Parameter(Mandatory)]
        [String]$vDDOSe,
        [Parameter(Mandatory)]
        [String]$vDDOSp
    )
    $vnethtable = @{}
    $vnethtable = @{VNetName = $vName; DDOSEnabled = $vDDOSe; DDOSPlan = $vDDOSp } 
    $objectv = New-Object psobject -Property $vnethtable
    return $objectv
}
function Get-AzSubFromID {
    param (
        [Parameter(Mandatory)]
        [String]$subid
    )
    $sub = $subid.Split('/')
    return $sub[2]
}
function Get-AzVNetFromSubnetID {
    param (
        [Parameter(Mandatory)]
        [String]$subnetid
    )
    $vnet = $subnetid.Split('/')
    return $vnet[8]
}
function Get-AzResourceRGfromID {
    param (
        [Parameter(Mandatory)]
        [String]$resourceID
    )
    $rrg = $resourceID.Split('/')
    return $rrg[4]
}
function Get-AzDDOSProtectPlan {
    param (
        [Parameter(Mandatory)]
        [String]$ddosplanID
    )
    $ddosplan = $ddosplanID.Split('/')
    return $ddosplan[8]
}
function New-CSVReportFile {
    param (
        [Parameter(Mandatory)]
        [String]$filepath
    )
    New-Item $filepath -type file -force
    Set-Content $filepath 'PIP_Name,PIP_Address,PIP_Subscription,Resource_Group,Associated_Resource,Resource_Type,Associated_Resource_RG,VNet,DDOS_Enabled,DDOS_Plan'
    Write-Host "Created $($filepathr)" -ForegroundColor Green
}
function Clear-CreatedJSONFiles {
    param (
        [Parameter(Mandatory)]
        [String]$filepathp,
        [Parameter(Mandatory)]
        [String]$filepathv
    )
    Write-Host "Removing created JSON files..." -ForegroundColor Yellow
    Remove-Item $filepathp -force
    Remove-Item $filepathv -force
    Write-Host "Removed JSON files $($filepathp) and $($filepathv)" -ForegroundColor Green
}
#endregion functions
#--------------------------------------------------------------------------------------------
#region main
# Check if the user is logged in
Write-Host "Checking if there is an active Azure Context..." -ForegroundColor Yellow
$context = Get-AzContext
if (!$context) {
    Connect-AzAccount
    $context = Get-AzContext
}
Write-Host "Context Retrieved Successfully." -ForegroundColor Green
Write-Host $context.Name
# Get the PIP and VNet resources from all available Azure Subscriptions
Get-PIPResources

New-CSVReportFile -filepath $filepathr
# Parse the PIP resrouces from the pipresources JSON file
Write-Host "Parsing Public IP resources..." -ForegroundColor Yellow
Get-Content -Path $filepathp | ConvertFrom-Json | foreach {
    $pipinfo += Get-IPConfigDetails -ipconfigtext $_.IpConfigurationText -pipName $_.Name -pipAddr $_.IpAddress -pipID $_.Id
}
# Parse the VNet resources from the vnetresources JSON file
Write-Host "Parsing Virtual Network resources..." -ForegroundColor Yellow
Get-Content -Path $filepathv | ConvertFrom-Json | foreach {
    if ($_.DdosProtectionPlan.Id -ne $null) { $dplan = Get-AzDDOSProtectPlan -ddosplanID $_.DdosProtectionPlan.Id } else { $dplan = "Not Enabled" }
    $vnetinfo += Get-VnetDetails -vName $_.Name -vDDOSe $_.EnableDdosProtectionText -vDDOSp $dplan
}
Write-Host "Finished parsing Public IP and Virtual Network resources" -ForegroundColor Green
# Loop through the PIP resources sorted by PIP subscription to build the report csv file
Write-Host "Building report CSV file..." -ForegroundColor Yellow
$pipinfo = $pipinfo | sort-object -Property PIPsub 
foreach ($p in $pipinfo) {
    # Check if the current Azure Subscription matches the PIP Subscription, if not Change the Azure Subscription
    $currentsub = (Get-AzContext).Subscription.id
    if ($p.PIPsub -ne $currentsub) {
        Write-Host "Current Subscription: " $currentsub " Changing to: " $p.PIPsub
        $si = $p.PIPsub
        Select-Azsubscription -Subscription $si
    }
    elseif ($p.PIPsub -eq $currentsub) {
        # Do nothing and continue on if the current subscription is the same as the PIP Subscription
    }
    else {
        Write-Host "There is a subscription issue"
    }
    #Filter based on resource type to perform proper get command on the azure resource for VNet information
    $v = $null
    $err = $null
    if ($p.RType -eq "azureFirewalls" -or $p.RType -eq "virtualNetworkGateways" -or $p.RType -eq "networkInterfaces" -or $p.RType -eq "bastionHosts") {
        if ($p.RType -eq 'azureFirewalls') {
            $fw = Get-AzFirewall -ResourceGroupName $p.RG -Name $p.RName
            $v = Get-AzVnetFromSubnetID -subnetid $fw.IpConfigurations.Subnet.Id
            $rrg = Get-AzResourceRGfromID -resourceID $fw.Id
        }
        elseif ($p.RType -eq 'virtualNetworkGateways') {
            $gw = Get-AzVirtualNetworkGateway -ResourceGroupName $p.RG -Name $p.RName
            $v = Get-AzVnetFromSubnetID -subnetid $gw.IpConfigurations.Subnet.Id
            $rrg = Get-AzResourceRGfromID -resourceID $gw.Id
        }
        elseif ($p.RType -eq 'networkInterfaces') {
            $ni = Get-AzNetworkInterface -ResourceGroupName $p.RG -Name $p.RName
            $v = Get-AzVnetFromSubnetID -subnetid $ni.IpConfigurations.Subnet.Id
            $rrg = Get-AzResourceRGfromID -resourceID $ni.Id
        }
        elseif ($p.RType -eq 'bastionHosts') {
            $ba = Get-AzBastion -ResourceGroupName $p.RG -Name $p.RName
            $v = Get-AzVnetFromSubnetID -subnetid $ba.IpConfigurations.Subnet.Id
            $rrg = Get-AzResourceRGfromID -resourceID $ba.Id
        }
        $vr = $vnetinfo | where { $_.VNetName -eq $v } 
        "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $p.PIPn, $p.PIPa, $p.PIPsub, $p.RG, $p.RName, $p.RType, $rrg, $v, $vr.DDOSEnabled, $vr.DDOSPlan  | add-content -path $filepathr
    }
    elseif ($p.RType -eq "applicationGateways") {
        $ag = Get-AzApplicationGateway -ResourceGroupName $p.RG -Name $p.RName
        if ($ag.BackendAddressPools.BackendAddresses.Count -gt 0) {
            $ag.BackendAddressPools.BackendAddresses | foreach {
                "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $p.PIPn, $p.PIPa, $p.PIPsub, $p.RG, $p.RName, $p.RType, $_.IpAddress, "Manual IP", "N/A", "N/A"  | add-content -path $filepathr
            }
        }
        if ($ag.BackendAddressPools.BackendIpConfigurations.Count -gt 0) {
            $ag.BackendAddressPools.BackendIpConfigurations | foreach {
                $apgwi = Get-ConfigDetailsFromBEID -BEnicconfigID $_.Id
                $appgwni = Get-AzNetworkInterface -ResourceGroupName $apgwi.RG -Name $apgwi.RName
                $appgwv = Get-AzVnetFromSubnetID -subnetid $appgwni.IpConfigurations.Subnet.Id
                $rrg = Get-AzResourceRGfromID -resourceID $appgwni.Id
                $vr = $vnetinfo | where { $_.VNetName -eq $appgwv }   
                "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $p.PIPn, $p.PIPa, $p.PIPsub, $p.RG, $apgwi.RName, $apgwi.RType, $rrg, $appgwv, $vr.DDOSEnabled, $vr.DDOSPlan  | add-content -path $filepathr
            }
        }          
    }
    elseif ($p.RType -eq "loadBalancers") {
        $lb = Get-AzLoadBalancer -ResourceGroupName $p.RG -Name $p.RName
        $lb.BackendAddressPools | foreach {
            $_.LoadBalancerBackendAddresses | foreach {
                $lbi = Get-ConfigDetailsFromBEID -BEnicconfigID $_.NetworkInterfaceIpConfiguration.Id
                $ni = Get-AzNetworkInterface -ResourceGroupName $lbi.RG -Name $lbi.RName
                $v = Get-AzVnetFromSubnetID -subnetid $ni.IpConfigurations.Subnet.Id
                $vr = $vnetinfo | where { $_.VNetName -eq $v }   
                "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $p.PIPn, $p.PIPa, $p.PIPsub, $p.RG, $lbi.RName, $lbi.RType, $lbi.RG, $v, $vr.DDOSEnabled, $vr.DDOSPlan  | add-content -path $filepathr 
            }
        }
    }
    else {
        Write-Host "Associated resource type not found for $($p.PIPn)" -ForegroundColor Red
        $err = 'Unable_To_Determine'
        $vr = $vnetinfo | where { $_.VNetName -eq $v } 
        "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f $p.PIPn, $p.PIPa, $p.PIPsub, $err, $err, $err, $rrg , $err, $err, $err  | add-content -path $filepathr
    }
}
Write-Host "Finished building report CSV file" -ForegroundColor Green
Clear-CreatedJSONFiles -filepathp $filepathp -filepathv $filepathv
Write-Host "Generated report CSV file: $($filepathr)" -ForegroundColor Green
#endregion main