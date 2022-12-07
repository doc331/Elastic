#Powershell AD Query *KeepITsimple

$prop="SamAccountName", "GivenName", "Surname", "Name", "DistinguishedName", "Enabled", "SID", "UserPrincipalName", "PasswordExpired", "PasswordLastSet", "PasswordNeverExpires"

$Users=Get-ADUser -filter * | select-object SamAccountName | select -ExpandProperty SamAccountName

Foreach ($User in $Users){
Get-ADUser -Identity $User -properties * | select $prop | ConvertTo-Json -Compress >> adds.json
} 