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
    $htable = @{}
    $array = $ipconfigtext.Split('/') 
    $indexG = 0..($array.Length -1) | where {$array[$_] -eq 'resourceGroups'}
    $pipID = Get-AzSubFromID -subid $pipID 
    $htable = @{RG=$array.get($indexG+1);RType=$array[7];RName=$array[8];PIPn=$pipName;PIPa=$pipAddr;PIPsub=$pipID}
    $object = New-Object psobject -Property $htable
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

foreach ($pip in $pipinfo) {
    Write-Host "Resource Group: " $pip.RG
    Write-Host "Type: " $pip.RType
    Write-Host "Name: " $pip.RName
    Write-Host "PIP Name: " $pip.PIPn
    Write-Host "PIP Address: " $pip.PIPa
    Write-Host "PIP Subscription: " $pip.PIPsub

    if ($pip.RType -eq 'azureFirewalls') {
        $fw = Get-AzFirewall -ResourceGroupName $pip.RG -Name $pip.RName
        $fw.IpConfigurations.Subnet.Id
    }
    elseif ($pip.RType -eq 'virtualNetworkGateways') {
        $gw = Get-AzVirtualNetworkGateway -ResourceGroupName $pip.RG -Name $pip.RName
        $gw.IpConfigurations.Subnet.Id
    }
    elseif ($pip.RType -eq 'networkInterfaces') {
        $ni = Get-AzNetworkInterface -ResourceGroupName $pip.RG -Name $pip.RName
        $ni.IpConfigurations.Subnet.Id
    }
}
#endregion main