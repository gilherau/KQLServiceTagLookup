# Setting the output path where we'll save the modified JSON
$MyOutPutPath = "c:\tmp\test\"
# Setting the reference Azure Region. This will NOT limit the service tags to that regions but instead determine which cloud to use (e.g. Public if you use eastus2)
# See https://docs.microsoft.com/en-us/powershell/module/az.network/Get-AzNetworkServiceTag for details
$MyRefRegion = "eastus2"
# loading up the service tags to an object
$serviceTags = Get-AzNetworkServiceTag -Location eastus2
# Creating an object to get only the child elements. We'll extract what we need from the root later.
$ServiceTagElements = $ServiceTags.Values
# We're grabbing the Cloud type and global change version from the root object and assiging them to variables so we can reinject them in each element later. This is done to make a 
# cleaner JSON that's Kusto friendly for ingestion
$CloudType = $serviceTags.Cloud
$CloudChangeNumber = $serviceTags.ChangeNumber
# Injecting the variables in the child elements
$ServiceTagElements | ForEach-Object {$_ | Add-Member -NotePropertyName CloudType -NotePropertyValue $CloudType}
$ServiceTagElements | ForEach-Object {$_ | Add-Member -NotePropertyName CloudChangeNumber -NotePropertyValue $CloudChangeNumber}
# Outputing the result to a JSON. Note the "Depth" variable is used. The default value is 2 and the AddressPrefixes element was being converted to a string 
# and we want it as an array so Kusto can use its Dynamic datatype. We're also injecting the CloudType and Change number to the file so we can do basic version control
$ServiceTagElements | ConvertTo-Json -Depth 3 -Compress | out-File $("c:\tmp\test\" + $CloudType + "_" + $CloudChangeNumber + ".json")

