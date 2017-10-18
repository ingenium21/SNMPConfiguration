#get server names from input file;

$computers = get-content .\servers.txt;

#declare Variables
$regpath = "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities";

# Define log paths 
$log = ".\snmplog\log.txt"

#rename old log file 
If (Test-Path $log){
    $fileObj = get-item $log
    $logfilenameonly = $fileObj.Name
    $starttimeformat = get-date -uformat "%Y-%m-%d@%H-%M-%S"
    rename-item "$fileObj" " $logfilenameonly-$starttimeformat.txt"
}

foreach ($c in $computers) {

    write-host "Starting work on $c";

    #test connection with the server
    If (Test-connection -ComputerName $c -count 1) {

        #get SNMP service and assign to variable
        $SnmpInstalled = invoke-command -ComputerName $c -ScriptBlock{get-wmiobject Win32_Service -filter "Name='SNMP'"}
        
        #if it's not installed, install it
        if (!($SnmpInstalled)){
            try {
            invoke-command -computername $c -Scriptblock {Install-WindowsFeature -IncludeAllSubFeature 'SNMP-Service'};
            "The SNMP installed on $c" | out-file $log -Append 
            }
            Catch {
            "The SNMP Service could not be installed on $c" | out-file $log -Append;
            }
        }

        Else {
            "The SNMP Service is already installed on $c" | out-file $log -Append;
            }

        #check Server if community string already exists
        invoke-command -ComputerName $c -ScriptBlock {
        $regpath = "HKLM:\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities";
        $dword = get-item -path $regpath | select -ExpandProperty property;
        }
        
        #if it does not exist, run psexec to install the registry keys.
        if ($dword -eq $null) {

            try {
            invoke-command -computerName $c -ScriptBlock { regedit.exe /S "\\[SERVER_LOCATION_NAME]\[REG_FILE_NAME];"}
            "Ran the Registry key file successfully on $c `r`n" | out-file $log -Append;
            }

            Catch {
            "Could not set up registry key on $c `r`n" | out-file $log -Append;
            }

        }

        Else {
        "SNMP community string has already been set up on $c `r`n" | out-file $log -Append;
        }
        
    }

    Else {
    "Could not connect to Host $c `r`n" | out-file $log -Append;
    }
    
}
