# AzDDOS-IPTool

## Prerequisites
* Current Version of [Azure Powershell](https://docs.microsoft.com/en-us/powershell/azure/install-az-p)
* User running script must be logged into Azure Powershell with the appropriate RBAC permissions to view/list Public IP Addresses and Virtual Networks

## How To Run

From a local PowerShell session or [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) run the PowerShell command below - 

`Invoke-Expression $(Invoke-WebRequest -uri aka.ms/azddospipreport-ps -UseBasicParsing).Content`

or the shorthand version -

`iwr -useb aka.ms/azddospipreport-ps | iex`

To download a local copy of the latest version of the script run the command below - 

`Invoke-WebRequest -Uri aka.ms/azddospipreport-ps -OutFile Get-AzDDOSProtectedIPs.ps1`


## Output
This script will generate a CSV file containing the following infomration for each Public IP Address that is visible to the user running the script 

| PIP_Name            | Name of the Azure Public IP Address resource                                                                                           |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| PIP_Address         | Public IP Address currently assigned to the Public IP Address resource                                                                 |
| PIP_Subscription    | Azure Subscription GUID for where the Public IP Address resource was found                                                             |
| Resource_Group      | Name of the Azure Resource Group that contains the Public IP Address                              |
| Associated_Resource | Name of the Azure resource that the Public IP Address is associated with                                                               |
| Resource_Type       | Type of resource that the Public IP Address is associated with                                                                         |
| Associated_Resource_RG       | Name of the Azure Resource Group that contains the associated resource                                                                         |
| VNet                | Name of the Azure Virtual Network that the Public IP Address and its associated resource are connected to                              |
| DDOS_Enabled        | True or False value if Azure DDOS is enabled on the Virtual Network the Public IP Address and its associated resource are connected to |
| DDOS_Plan           | Name of the DDOS Plan that the Azure Virtual Network is using                                                                          |

## Things To Note
* If the associated resource can not be determenined the script will output "Associated resource type not found for sample-PIP", and the CSV file will populate the appropriate columns with "Unable_To_Determine"
* If the associated resource is an Azure Load Balancer that is not configured with a backend, the CSV will populate the VNet column with "Invalid_Subnet_ID"

## Known Issues 
* Tthis script does have full logic for parsing External Azure Loadbalancers (12/13/2021 - Currently Testing)
* This script does have full logic for parsing Application Gateways (12/13/2021 - Currently Testing)
* This script has not been tested to parse Public IP Addresses that are associated with a ExpressRoute Gateway