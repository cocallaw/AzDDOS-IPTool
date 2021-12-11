#region variables
$filepathp = ".\pipresources.json"
$filepathv = ".\vnetresources.json"
$filepathr = ".\Az_PIP_DDOS_Report-$(get-date -Format yyyyMMdd).csv"
$pipinfo = @()
$vnetinfo = @()
#endregion variables
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
    $indexG = 0..($array.Length - 1) | where { $array[$_] -eq 'resourceGroups' }
    $pipID = Get-AzSubFromID -subid $pipID 
    $piphtable = @{RG = $array.get($indexG + 1); RType = $array[7]; RName = $array[8]; PIPn = $pipName; PIPa = $pipAddr; PIPsub = $pipID }
    $objectp = New-Object psobject -Property $piphtable
    return $objectp
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
function New-CSVReportFile {
    param (
        [Parameter(Mandatory)]
        [String]$filepath
    )
    New-Item $filepath -type file -force
    Set-Content $filepath 'PIP_Name,PIP_Address,PIP_Subscription,Resource_Group,Associated_Resource,Resource_Type,VNet,DDOS_Enabled,DDOS_Plan'
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
    $vnetinfo += Get-VnetDetails -vName $_.Name -vDDOSe $_.EnableDdosProtectionText -vDDOSp $_.DdosProtectionPlanText
}
Write-Host "Finished parsing Public IP and Virtual Network resources" -ForegroundColor Green
# Loop through the PIP resources sorted by PIP subscription to build the report csv file
Write-Host "Building report CSV file..." -ForegroundColor Yellow
$pipinfo | sort-object -Property PIPsub | foreach {
    # Check if the current Azure Subscription matches the PIP Subscription, if not Change the Azure Subscription
    $currentsub = (Get-AzContext).Subscription.id
    if ($_.PIPsub -ne $currentsub) {
        Write-Host "Current Subscription: " $currentsub " Changing to: " $_.PIPsub
        $si = $_.PIPsub
        Select-Azsubscription -Subscription $si
    }
    elseif ($_.PIPsub -eq $currentsub) {
        # Do nothing and continue on if the current subscription is the same as the PIP Subscription
    }
    else {
        Write-Host "There is a subscription issue"
    }
    #Filter based on resource type to perform proper get command on the azure resource for VNet information
    if ($_.RType -eq 'azureFirewalls') {
        $fw = Get-AzFirewall -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $fw.IpConfigurations.Subnet.Id
    }
    elseif ($_.RType -eq 'virtualNetworkGateways') {
        $gw = Get-AzVirtualNetworkGateway -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $gw.IpConfigurations.Subnet.Id
    }
    elseif ($_.RType -eq 'networkInterfaces') {
        $ni = Get-AzNetworkInterface -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $ni.IpConfigurations.Subnet.Id
    }
    elseif ($_.RType -eq '--Azure Bastion--') {
        $ba = Get-AzBastion -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $ba.IpConfigurations.Subnet.Id
    }
    elseif ($_.RType -eq '--Azure Load Balancer--') {
        $lb = Get-AzLoadBalancer -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $lb.IpConfigurations.Subnet.Id
    }
    elseif ($_.RType -eq '--NAT Gateway--') {
        $ng = Get-AzNatGateway -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $ng.IpConfigurations.Subnet.Id
    }
    elseif ($_.RType -eq '--App Gateway--') {
        $ag = Get-AzApplicationGateway -ResourceGroupName $_.RG -Name $_.RName
        $v = Get-AzVnetFromSubnetID -subnetid $ag.IpConfigurations.Subnet.Id
    }
    else {
        Write-Host "Associated resource type not found" -ForegroundColor Red
    }
    $vr = $vnetinfo | where { $_.VNetName -eq $v } 
    "{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f $_.PIPn, $_.PIPa, $_.PIPsub, $_.RG, $_.RName, $_.RType, $v, $vr.DDOSEnabled, $vr.DDOSPlan  | add-content -path $filepathr
}
Write-Host "Finished building report CSV file" -ForegroundColor Green
#Clear-CreatedJSONFiles -filepathp $filepathp -filepathv $filepathv
Write-Host "Generated report CSV file: $($filepathr)" -ForegroundColor Green
#endregion main