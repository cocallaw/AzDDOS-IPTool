#region variables
$filepathp = ".\pipresources.json"
$filepathv = ".\vnetresources.json"
$pipinfo = @()
$vnetinfo = @()

#endregion variables

#region functions
function Get-PIPResources {
    if ($context) {
        $pipResource = @()
        $allSub = Get-AzSubscription
        $allSub | foreach {
            Set-AzContext -SubscriptionId $_.Id
            $pipResource += Get-AzPublicIpAddress
            $vnetResource += Get-AzVirtualNetwork
        }
        $pipResource | ConvertTo-Json | Out-File pipresources.json
        $vnetResource | ConvertTo-Json | Out-File vnetresources.json
    }
    else {
        Write-Host "Please Login first in order to continue"
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
    $object = New-Object psobject -Property $piphtable
    return $object
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
#endregion functions

#region main
$context = Get-AzContext
if (!$context) {
    Connect-AzAccount
    $context = Get-AzContext
}
Write-Host "Context Retrieved Successfully."
Write-Host $context.Name

Get-PIPResources
Get-Content -Path $filepathp | ConvertFrom-Json | foreach {
    $pipinfo += Get-IPConfigDetails -ipconfigtext $_.IpConfigurationText -pipName $_.Name -pipAddr $_.IpAddress -pipID $_.Id
}

$pipinfo | sort-object -Property PIPsub | foreach {
    Write-Host "Resource Group: " $_.RG
    Write-Host "Type: " $_.RType
    Write-Host "Name: " $_.RName
    Write-Host "PIP Name: " $_.PIPn
    Write-Host "PIP Address: " $_.PIPa
    Write-Host "PIP Subscription: " $_.PIPsub

    $currentsub = (Get-AzContext).Subscription.id
    if ($_.PIPsub -ne $currentsub) {
        Write-Host "Current Subscription: " $currentsub " Changing to: " $_.PIPsub
        $si = $_.PIPsub
        Select-Azsubscription -Subscription $si
    }
    elseif ($_.PIPsub -eq $currentsub) {
    }
    else {
        Write-Host "There is a subscription issue"
    }

    if ($_.RType -eq 'azureFirewalls') {
        $fw = Get-AzFirewall -ResourceGroupName $_.RG -Name $_.RName
        $fwv = Get-AzVnetFromSubnetID -subnetid $fw.IpConfigurations.Subnet.Id
        Write-Host "VNET PIP is on: " $fwv
    }
    elseif ($_.RType -eq 'virtualNetworkGateways') {
        $gw = Get-AzVirtualNetworkGateway -ResourceGroupName $_.RG -Name $_.RName
        $gwv = Get-AzVnetFromSubnetID -subnetid $gw.IpConfigurations.Subnet.Id
        Write-Host "VNET PIP is on: " $gwv
    }
    elseif ($_.RType -eq 'networkInterfaces') {
        $ni = Get-AzNetworkInterface -ResourceGroupName $_.RG -Name $_.RName
        $niv = Get-AzVnetFromSubnetID -subnetid $ni.IpConfigurations.Subnet.Id
        Write-Host "VNET PIP is on: " $niv
    }
}
#endregion main