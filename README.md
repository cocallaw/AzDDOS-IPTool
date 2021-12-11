# AzDDOS-IPTool

To run this PowerShell Script from a local machine, you need to install the latest [Azure Powershell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps).

From a local PowerShell session or [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) run the PowerShell command below - 

`Invoke-Expression $(Invoke-WebRequest -uri aka.ms/azddospipreport-ps -UseBasicParsing).Content`

or the shorthand version -

`iwr -useb aka.ms/azddospipreport-ps | iex`

To download a local copy of the latest version of the script run the command below - 

`Invoke-WebRequest -Uri aka.ms/azddospipreport-ps -OutFile Get-AzDDOSProtectedIPs.ps1`
