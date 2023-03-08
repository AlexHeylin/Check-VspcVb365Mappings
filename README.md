# Check-VspcVb365Mappings
Checks if all Veeam Backup for 365 (VBO365/VBM365) tenants in Veeam Service Provider Console (VSPC) are mapped to companies for correct invoicing and license reporting. Outputs Nagios style OK: / CRITICAL: for easy parsing. 

# Background
If tenants aren't correctly mapped to companies, their licenses are counted (and reported to Veeam) as being consumed by the Veeam Cloud Service Provider (VCSP) rather than the tenant.  Worse, this also means the tenant is not invoiced by VSPC for their license usage.  If you're a VCSP you may be able to see more about this here https://forums.veeam.com/post479501.html#p479501


# Parameters
server: If running this from a machine other than the VSPC server then specify the URL including port of your VAC / VSPC server.  Example: https://vspc.mycompany.com:1280 

Credential: a psCredential containing the username & password to access the API.  You can use your VSPC login to get started. 


# Example
```
$VspcCred = Get-Credential
.\Check-VspcVb365Mappings.ps1 -server https://vac.gmal.co.uk:1280 -Credential $VspcCred
```

# Thanks
Thanks to Konstantin Komelin at Veeam for pointing me at the API endpoints to get this going. 

Thanks to Microsoft (and the plugin writers!) for Visual Studio Code which isn't as terrible for PowerShell as it first seemed.  The gentle nagging to improve the code has made this code tidier and less ambiguous.
