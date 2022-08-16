# Setting the output path where we'll save the modified JSON
$MyOutPutPath = "c:\tmp\ServiceTags\"
# Setting the reference Azure Region. This will NOT limit the service tags to that regions but instead determine which cloud to use (e.g. Public if you use eastus2)
# See https://docs.microsoft.com/en-us/powershell/module/az.network/Get-AzNetworkServiceTag for details
# Note that you may get a 429 error due to throttling when too many requests are being made to one region. Use a less busy region such as canada central if it happens.
$MyRefRegion = "canadacentral"
# Make sure you use your Subscription ID, the below is a placeholder
$MySub = "00aa0a00-0a00-000a-0000-0000aa00000a"
# Log on to Azure
Connect-AzAccount
# setting to a specific subscription
Set-AzContext -Subscription $MySub
# loading up the service tags to an object
$serviceTags = Get-AzNetworkServiceTag -Location $MyRefRegion
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
$ServiceTagElements | ConvertTo-Json -Depth 3 -Compress | out-File $($MyOutPutPath + $CloudType + "_" + $CloudChangeNumber + ".json")