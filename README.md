# Check-VspcVb365Mappings
Checks if all Veeam Backup for 365 tenants in Veeam Service Provider Console are mapped to companies for correct invoicing and license reporting. Outputs Nagios style OK: / CRITICAL: for easy parsing. 

# Parameters
server: If running this from a machine other than the VSPC server then specify the URL including port of your VAC / VSPC server.  Example: https://vspc.mycompany.com:1280 
Credential: a psCredential containing the username & password to access the API.  You can use your VSPC login to get started. 


# Example
$VspcCred = Get-Credential
.\Check-VspcVb365Mappings.ps1 -server https://vac.gmal.co.uk:1280 -Credential $VspcCred
