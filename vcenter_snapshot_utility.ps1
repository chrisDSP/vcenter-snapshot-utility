<#
.SYNOPSIS
vCenter Snapshot Management Utility

Written by Chris Vincent

.DESCRIPTION
This script utilizes the VMWare PowerCLI Powershell Module Cmdlets to allow for simplified management of guest VM snapshots. 

Call the script with at least one virtual machine as an argument in order to create and delete snapshots for the VM(s).

.EXAMPLE
.\vcenter_snapshot_utility.ps1 "server1.foo.com,server2.bar.com" vcenter.foo.com

.PARAMETER guest_vm_array
Required parameter.

The hostname of at least one vSphere guest VM. Separate multiple server hostnames with a comma.

.PARAMETER vcenter_host
Required parameter.

The hostname of the vCenter server/appliance that manages the environment for the guest VMs in the first argument. 


#>

param(

    [parameter(mandatory=$true,Position=1)]
    [ValidateNotNullOrEmpty()]    
        [string]$guest_vm_string=$(throw "guest_vm_string argument must contain a comma separated list of guest hostnames."),
    [parameter(mandatory=$true,Position=2)]
    [ValidateNotNullOrEmpty()]    
        [string]$vcenter_host=$(throw "vcenter_host argument must contain a hostname for the target vcenter server.")
)


#BEGIN FUNCTION DECLARATIONS

function Connect-VC {

	$credentials=Get-Credential -UserName username -Message "Enter your vCenter password"

	Connect-VIServer -Server $vcenter_host -Credential $credentials


}


function Check-Vsphere-Connection {

    if ($global:DefaultVIServers.Name -like $vcenter_host)

    {

        Write-Host "You have successfully connected to $global:DefaultVIServers!" -ForegroundColor Green

        Write-Host ""

        } 

    else {

        Write-Host "==================================================================================================================================================" -ForegroundColor Red
        Write-Host "                                                           !!AUTHENTICATION ERROR!!"  -ForegroundColor Red
        Write-Host ""
        Write-Host "Login to vSphere has failed. Please re-run this script in order to make another attempt at authentication."  -ForegroundColor Red
        Write-Host "Only users with access to the target vSphere environment will be able to make us of this utility."  -ForegroundColor Red
        Write-Host ""
        Write-Host "==================================================================================================================================================" -ForegroundColor Red
        Write-Host ""

        Disconnect-VIServer -Confirm:$false

        exit

        }

    }   

function List-AllGuestSnapshots {

    #Confirm-GuestOperation
            
    $snapshot_array = New-Object System.Collections.ArrayList       
    $snapshot_array += $guest_obj_array | % {$_ | Get-Snapshot;}             
    $snapshot_array | %{Write-Host $_.VM; Write-Host `t "Guest: " $_.Name `n`t "Created on: "$_.Created}

}

function List-LastGuestSnapshots {

    #Confirm-GuestOperation
            
    $snapshot_array = New-Object System.Collections.ArrayList                  
    $snapshot_array += $guest_obj_array | % {$_ | Get-Snapshot | Select -Last 1;} 
    $snapshot_array | %{Write-Host $_.VM; Write-Host `t "Guest: " $_.Name `n`t "Created on: "$_.Created}
            

}

function Remove-LastGuestSnapshot {

    Confirm-GuestOperation

    #REMOVE SNAPSHOTS BEGIN
    #instantitate an empty arraylist for snapshot objects to be returned from Get-Snapshot
    $snapshot_array = New-Object System.Collections.ArrayList

    #pass each VM object to Get-Snapshot querying on the snapshot name. capture each snapshot object as a member in $snapshot_array
    $snapshot_array += $guest_obj_array | % {$_ | Get-Snapshot | Select -Last 1;} 

    #pass each snapshot object to Remove-Snapshot
    $snapshot_array | % {$_ | Remove-Snapshot -Confirm:$false; Write-Host "Snapshot deleted for VM: $_" -ForegroundColor Green;}
    #REMOVE SNAPSHOTS END

}

function Create-GuestSnapshots {
            
    $names = Read-Host -Prompt "Snapshot name: "

    #CREATE SNAPSHOTS BEGIN
    #one member at a time, pass each VM object handle to New-Snapshot
    $guest_obj_array | % {$_ | New-Snapshot -Name $names; Write-Host "Snapshot made for VM: $_" -ForegroundColor Green;}
    #CREATE SNAPSHOTS END

}


<#
   
function Restore-LastGuestSnapshots {

    Confirm-GuestOperation

    #RESTORE TO SNAPSHOT BEGIN
    #BE CAREFUL with this loop. Set-VM needs both a VM object and a snapshot object, so we'll just directly access the array elements with an iteration variable.
        #make sure the $guest_obj_array and $snapshot_array have the same ordinality, 
        #e.g., that the first element in snapshot_array is a snapshot of the first element (vm) in guest_obj_array.
    0..$guest_obj_array.Count | % {$guest_obj_array[$_] | Set-VM -Snapshot $snapshot_array[$_] -Confirm:$false}
    #RESTORE TO SNAPSHOT END

}


#>

function Confirm-GuestOperation {                       
    do {
        Write-Host "You are operating on the following VMs:"
        $guest_obj_array | % {Write-Host `t$_ -ForegroundColor Yellow}
        $confirmation_response = $(Read-Host -Prompt "Type YES to proceed. Type NO to halt the script: ").ToUpper()                
        if ($confirmation_response -EQ "YES") 
            {                       
            return            
            }
            if ($confirmation_response -EQ "NO") 
            {                    
            exit                
            }                 

        }
    while ($confirmation_response -NE (("YES") -or ("NO")))
}

function Print-Help {

    Write-Host "`nSNAPSHOT UTILITY HELP`n" -ForegroundColor Yellow
    Write-Host "`tCOMMAND:`t`t DESCRIPTION:`n" -ForegroundColor Yellow
    Write-Host "`tLIST ALL`t`t List all snapshots for each guest VM" -ForegroundColor Yellow
    Write-Host "`tCREATE`t`t`t Create snapshots for each guest VM" -ForegroundColor Yellow
    Write-Host "`tLIST LAST`t`t List the most recent snapshot made for each guest VM" -ForegroundColor Yellow       
    Write-Host "`tDELETE LAST`t`t Delete the most recent snapshot made for each guest VM" -ForegroundColor Yellow
    Write-Host "`tRESTORE LAST`t Restore all guest VMs to the most recent snapshot" -ForegroundColor Yellow
    Write-Host "`tEXIT`t`t`t Quit the application" -ForegroundColor Yellow
}


function End-Session {

    Disconnect-VIServer -Confirm:$false
}

#END FUNCTION DECLARATIONS

#BEGIN EXECUTION


[System.Collections.ArrayList]$guest_vm_array = $guest_vm_string.Split(",".ToCharArray());


try

    {
        #Tries to import the VMware automationmodule. #-ErrorAction Stop makes the error a terminating error which means the Catch portion of this statement will actually catch it.
        Import-Module VMware.VimAutomation.Core -ErrorAction Stop

    }

catch

{
        #If the import above resulted in an error, show the error text below and stop.
        Write-Host "======================================================================================================================" -ForegroundColor Red
        Write-Host "                                                    !!ERROR!!"  -ForegroundColor Red
        Write-Host ""
        Write-Host "The VMware PowerCLI module is unavailable on this system. Install VMware PowerCLI and then run the script again."  -ForegroundColor Red
        Write-Host "This tool relies on VMware's Powershell Modules, so until they are installed, this tool is not going to work properly."  -ForegroundColor Red
        Write-Host ""
        Write-Host "======================================================================================================================" -ForegroundColor Red
        Write-Host ""

        exit

    }


$vspherechoice = Read-Host "Type 'Y' to attempt a connection to $vcenter_host"

if ($vspherechoice -eq "Y") {
                    
    Write-Host "Connection in progress..." -ForegroundColor Green

    Write-Host ""

    Connect-VC
    }
    else {
    Write-Host "Aborting snapshot operation..." -ForegroundColor Red

    exit

}

Check-Vsphere-Connection   


Write-Host "VM retreival in progress..." -ForegroundColor Green

#RETRIEVE VMs BEGIN
#instantiate an empty arraylist for the objects returned by Get-VM 
$guest_obj_array = New-Object System.Collections.ArrayList
     
#pass the array of hostname strings to Get-VM one at a time, then push the returned VM object for each on to the object array
$guest_vm_array | %  {$guest_obj_array.Add((Get-VM -Name $_)); Write-Host "VM Object $_ extracted." -ForegroundColor Green};
#RETRIEVE VMs END



do {
    
    Print-Help
    $selected_input = Read-Host -Prompt "Enter a command."

    switch ($selected_input.toUpper()) {

        

        "LIST ALL" {List-AllGuestSnapshots}
        "CREATE" {Create-GuestSnapshots}
        "LIST LAST" {List-LastGuestSnapshots}
        "DELETE LAST" {Remove-LastGuestSnapshot}
        #"RESTORE LAST" {Restore-LastGuestSnapshots}
        "EXIT" {End-Session; exit}
        "?" {Print-Help}
        "HELP" {Print-Help}
        default {Write-Host "Invalid option." -ForegroundColor Red; Print-Help}

    }

}

while ($valid_input -ne $true)


#END EXECUTION        

      
        
  