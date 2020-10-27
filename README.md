Onboard OMS extension for list of Linux and Windows Azure classic VMs
=====================================================================

            

 

Installs OMS extension for Linux and Windows Azure classic VMs. The Runbook takes comma seperated list of SubscriptionIds=SubscriptionName combination and

installs OMS Agent on each VMs in the subscription.
The runbook needs classic run as connection string to access VMs in other subscriptions.

This runbook calls child runbook Install-OMSClassicVMExtension. The Install-OMSClassicVMExtension should be available in the automation account.
This runbook can be used in scenario to mass onboard list of Azure classic VM for OMS update management solution.


 
If you are want to onboard both Classic and ARM VMs in a single runbook, please use Onboard-VMsForOMSUpdateManagement and set the input
parameter $OnboardClassicVMs to $true. Onboard-VMsForOMSUpdateManagement will invoke Onboard-ClassicVMsForOMSUpdateManagement internally.
The advantage of doing that would be Onboard-VMsForOMSUpdateManagement takes only comma seperated list of subscriptionId as input and there is no

neccessity to pass SubscriptionIds=SubscriptionName mapping.

 


        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
