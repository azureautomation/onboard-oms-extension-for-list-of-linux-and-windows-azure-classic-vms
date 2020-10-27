<#  
.SYNOPSIS  
Onboard OMS extension for list of Linux and Windows Azure classic VMs.

.DESCRIPTION  
Installs OMS extension for Linux and Windows Azure classic VMs. The Runbook takes comma seperated list of SubscriptionIds=SubscriptionName combination and 
installs OMS Agent on each VMs in the subscription.

The runbook needs classic run as connection string to access VMs in other subscriptions.

This runbook calls child runbook Install-OMSClassicVMExtension. The Install-OMSClassicVMExtension should be available in the automation account.
This runbook can be used in scenario to mass onboard list of Azure classic VM for OMS update management solution.

If you are want to onboard both Classic and ARM VMs in a single runbook, please use Onboard-VMsForOMSUpdateManagement and set the input
parameter $OnboardClassicVMs to $true. Onboard-VMsForOMSUpdateManagement will invoke Onboard-ClassicVMsForOMSUpdateManagement internally.
The advantage of doing that would be Onboard-VMsForOMSUpdateManagement takes only comma seperated list of subscriptionId as input and there is no 
neccessity to pass SubscriptionIds=SubscriptionName mapping. 


.EXAMPLE
.\Onboard-ClassicVMsForOMSUpdateManagement

.NOTES
If you are want to onboard both Classic and ARM VMs in a single runbook, please use Onboard-VMsForOMSUpdateManagement and set the input
parameter $OnboardClassicVMs to $true. Onboard-VMsForOMSUpdateManagement will invoke Onboard-ClassicVMsForOMSUpdateManagement internally.
The advantage of doing that would be Onboard-VMsForOMSUpdateManagement takes only comma seperated list of subscriptionId as input and there is no 
neccessity to pass SubscriptionIds=SubscriptionName mapping. 

AUTHOR: Azure Automation Team
LASTEDIT: 2017.06.22
#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Comma seperated values of SubscriptionId=SubscriptionName combination. SubId and SubName should be seperated by =.")] 
    [String] $subIdSubNameCSVList,
    [Parameter(Mandatory=$true)] 
    [String] $workspaceId,
    [Parameter(Mandatory=$true)] 
    [String] $workspaceKey	
)
$ErrorActionPreference = 'Stop'
$ConnectionAssetName = "AzureClassicRunAsConnection"
$InstallOMSVMExtensionRunbookName = "InstallOMSClassicVMExtension"

# Authenticate to Azure with certificate
Write-Verbose "Get connection asset: $ConnectionAssetName" -Verbose
$Conn = Get-AutomationConnection -Name $ConnectionAssetName
if ($Conn -eq $null) 
{
    throw "Could not retrieve connection asset: $ConnectionAssetName. Assure that this asset exists in the Automation account."
}

$CertificateAssetName = $Conn.CertificateAssetName
Write-Verbose "Getting the certificate: $CertificateAssetName" -Verbose
$AzureCert = Get-AutomationCertificate -Name $CertificateAssetName
if ($AzureCert -eq $null) 
{
    throw "Could not retrieve certificate asset: $CertificateAssetName. Assure that this asset exists in the Automation account."
}

$subIdSubNameList = @{};
$pairs = $subIdSubNameCSVList -split ',';

foreach ($pair in $pairs) 
{
    $split = $pair -split '=';
    if ($split[0] -ne $null -and $split[1] -ne $null) 
    {
        $subIdSubNameList.Add($split[0], $split[1])
    }
    else 
    {
        Write-Error "Invalid input $($pair)"
    }
}
 
foreach($subId in $subIdSubNameList.Keys) 
{
    $subId
    $subscriptionName =  $subIdSubNameList[$subId]
    $subscriptionName
    Write-Verbose "Authenticating to Azure with certificate." -Verbose
    Set-AzureSubscription -SubscriptionId $subId -SubscriptionName $subscriptionName -Certificate $AzureCert 
 

    Write-Output "Selecting Subscription $($subId)"
    Select-AzureSubscription -SubscriptionId $subId
	
    $VMs = Get-AzureVM | Where {$_.VM.OSVirtualHardDisk.OS -eq "Linux" -or $_.VM.OSVirtualHardDisk.OS -eq "Windows"}
    $VMJobCount = 0
    # for each of the VMs
    foreach ($VM in $VMs) 
    {
        # check if extension is installed
        try 
        {
            $ExtentionNameAndTypeValue = 'MicrosoftMonitoringAgent'
	        if ($VM.VM.OSVirtualHardDisk.OS -eq "Linux") 
            {
                $ExtentionNameAndTypeValue = 'OmsAgentForLinux'	
	    }
	 
            $VME = Get-AzureVMExtension -VM $VM -ExtensionName $ExtentionNameAndTypeValue -Publisher 'Microsoft.EnterpriseCloud.Monitoring' -ErrorAction 'SilentlyContinue'
   	        if ($VME -ne $null) 
            {
                Write-Output "MMAExtension is already installed for VM $($VM.Name)"
                Continue
            }
	    }
	    catch 
       	 {
            # ignore failure
        }

        Start-Sleep -s 2 # Just to make sure we are not trottled
	    $InstallJobId =    Start-AutomationRunbook -Name $InstallOMSVMExtensionRunbookName -Parameters @{'subId'=$subId;'VMName'=$VM.Name;'ServiceName'=$VM.ServiceName;'workspaceId'=$workspaceId;'workspaceKey'=$workspaceKey;'subscriptionName'=$subscriptionName }
	    if($InstallJobId -ne $null)
	    {
	        Write-Output "Extension installation Job started with JobId $($InstallJobId) on VM $($VM.Name)"
            $VMJobCount = $VMJobCount + 1
            if ($VMJobCount -gt 10)
            {
               	Write-output "Job count is greater than 10 sleeping so that VM Extension installations are not throttled."
               	Start-Sleep -s 180
               	$VMJobCount = 0
            }
	    }
    }	  
}
