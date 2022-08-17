# KQLServiceTagLookup
a fun utility to help work with firewalls and service tags, all made easy using KQL and the ADX free cluster!

## Context
Dealing with IP addresses is a fact of life when architecting solutions in Azure. ADX has specific functions that will accelerate time to insights when dealing with IP networking. This post will go over a real-life scenario using special KQL function that will blow your mind!

Imagine you have some host and it wants to talk to an azure service over many different IP addresses and obviously you do not want to create Firewall rules for every IP address. Service tags will help you do that. The goal of this demo is to show a set of IP addresses that represents a hypothetical network traffic capture. We want to know if some of the Ips we see are covered by a service tag. This is where KQL will help us.

## What is a service tag
In Azure, a “ServiceTags” represents a set of IP address range (in CIDR notation) that belong to a specific service. For example, the service tag “DataFactory.CanadaCentral” allows you to get all the public IP addresses prefixes that are associated with the Azure Data Factory service in the CanadaCentral region. 
Here are the prefixes:
- "13.71.175.80/28",
- "20.38.147.224/28",
- "20.48.201.0/26",
- "52.228.80.128/25",
- "52.228.81.0/26",
- "52.228.86.144/29",
- "52.246.155.224/28",
- "2603:1030:f05:1::480/121",
- "2603:1030:f05:1::500/122",
- "2603:1030:f05:1::700/121",
- "2603:1030:f05:1::780/122",
- "2603:1030:f05:402::330/124",
- "2603:1030:f05:802::210/124",
- "2603:1030:f05:c02::210/124"

This is used extensively inside azure to perform micro-segmentation using Network Security Groups (NSGs). But one less common use case is when a customer wants to know which IP address, they need to whitelist in their on-premises outbound firewall for a given service. i.e. I have a machine here on-premise and it’s trying to talk to a blob store in Azure, what IP range do I have to whitelist?

Now of course you can create firewall rule using the IP addresses themselves, but Azure is big! Really big! And we add new IP Addresses frequently. It’s important to keep your firewall rules up to date and to that end, we’ve created ways to programmatically get all the IP addresses linked to a service tag and thus give you the ability to update your firewall periodically.

If you want to do this manually, you can also download a JSON file with all the IPs for you to manually scan and determine what are the IP range for a given tag. For example, [this link](https://www.microsoft.com/download/details.aspx?id=56519) will take you to the public cloud IP file list. The [other azure cloud are available on the main page](https://docs.microsoft.com/en-us/azure/virtual-network/service-tags-overview#service-tags-on-premises) as well.

## Getting the latest set of service tags

For this post, you can skip right to downloading the JSON here but if you are interested, check out this Git Repo where I have a [PowerShell script](/Code/Powershell/GetServiceTags.ps1) that generates an ADX friendly version that you can ingest once in a while to keep this up to day..

The goal here is to have a JSON file with all the tags and while Microsoft already provides a direct link to a Downloadable JSON file, it’s not really great for ingestion into ADX so I had to tweak it a bit. This is what the PowerShell does. Please take a peek if you are curious of just [download the file in the repo](/Code/Sample%20Data/Public_101.json). Note that I have included two version of the file. They were generated using the script about two weeks apart. You can ingest the 101 version followed by the 102 version in the ingestion steps below. This will demo how we can use ADX go always get the latest.

## Putting it all together using ADX

## Getting our ADX environment ready

**Requirements:** 

- The powershell script uses packages that are pretty standard for PowerShell but if you do not have them already, you will need sufficient permissions to add packages.
- You will also need an azure subscription to pull the data from when using the script. 
- If you have not done so already, go get your [free ADX cluster](https://aka.ms/adx.free) and let’s get started.
- Create a blank new Database or use an existing one

### Creating a table and the associated data mapping

Use the following [KQL code](/Code/KQL/1-%20Create%20Table%20and%20Mapping.kql) to create the table where we will store the service tag data:

```kql
.create table ['MyServiceTags']  
(
  ['ServiceTagName']:string
, ['ServiceTagId']:string
, ['ServiceTagRegion']:string
, ['ServiceTagAddressPrefixes']:dynamic
, ['ServiceTagSystemService']:string
, ['ServiceTagChangeNumber']:string
, ['CloudType']:string
, ['CloudChangeNumber']:int
)
``` 

Now use the following code to create the data mapping

```kql
.create table ['MyServiceTags'] ingestion json mapping 'MyServiceTags_mapping' 
'[
  {"column":"ServiceTagName",Properties":{"Path":"$[\'Name\']"}}
 ,{"column":"ServiceTagId",Properties":{"Path":"$[\'Id\']"}}
 ,{"column":"ServiceTagRegion","Properties":{"Path":"$[\'Properties\'][\'Region\']"}}
 ,{"column":"ServiceTagAddressPrefixes","Properties":{"Path":"$[\'Properties\'][\'AddressPrefixes\']"}}
 ,{"column":"ServiceTagSystemService","Properties":{"Path":"$[\'Properties\'][\'SystemService\']"}}
 ,{"column":"ServiceTagChangeNumber", "Properties":{"Path":"$[\'Properties\'][\'ChangeNumber\']"}}
 ,{"column":"CloudType", "Properties":{"Path":"$[\'CloudType\']"}}
 ,{"column":"CloudChangeNumber", "Properties":{"Path":"$[\'CloudChangeNumber\']"}}
]'
``` 
### Ingesting the file

With the table created and the mapping in place, we can easily use “one-click” ingestion to get this data in our free cluster.
- Head over to your query pane, right click on your database and select “Ingest data”.
- Make sure “Existing table” is selected and “MyServiceTag” table name is selected in the drop-down list. Hit “Next: Source”
- Make sure the “source type” is set to “from file” and select the JSON you downloaded earlier. Hit “Next: Schema”
- Make sure to toggle “Use Existing Mapping” on and select “MyServiceTags_mapping” in the drop-down.
- Hit “Next: Start ingestion” and let the process complete. Once it is done, you are ready to put this data to work!

### Assembling the final query
If you remember our scenario, we are simulating a case where a network engineer has in his or her possession a list of IP addresses that represents outbound traffic that must be whitelisted to Azure. The engineer knows that they could use one firewall rule per IP address but it’s horribly inefficient and does not scale well with the rapid rate of change that Azure has. So, the engineer wants to compare the IP address that we have in the list with the Service tag address prefix. Here’s how we do it.

**GetLatestServiceTags function**
First, let's make a function that acts like a view and always returns the latest IP ranges for a given set of tags. You can then periodically run the PowerShell script, ingest the resulting JSON and the function will always return up to date info.

Here's the [KQL script](/Code/KQL/2%20-%20Create%20Function%20GetLatestServiceTags.kql) with comments:

```kql
.create-or-alter function with (folder = "Helper Functions", docstring = "Get latest service tags", skipvalidation = "true") GetLatestServiceTags() {
        // First we get the latest CloudChangeNumber so we get the latest set of service tags and corresponding addressPrefixes
        // Note I am using the Arg_max function on the change number and returning that number. I have to use toscalar() in order
        // to use this as a variable for my where clause below.
    let MaxCloudChangeNumber = 
    toscalar(MyServiceTags | summarize arg_max(CloudChangeNumber, CloudChangeNumber));
    MyServiceTags
    | where CloudChangeNumber == MaxCloudChangeNumber
        // The address prefixes are stored in an array so we have to expand that array using the Mv-expand command.
        // note I am using aliasing the resulting column "ServiceTagAddressPrefix" (singular) to denote that we are 
        // expecting on prefix per row after the expand operation
    | mv-expand ServiceTagAddressPrefix = ServiceTagAddressPrefixes
        // we're keeping only these two columns to keep things simple
    | project 
         ServiceTagName
            //Next we are explicitly casting the IP prefix (or range) as a string because the MV-expand makes no assumptions and keeps it as a Dynamic data type which is not what we want for the next step
        ,ServiceTagIpRange = tostring(ServiceTagAddressPrefix)
        ,CloudChangeNumber
    } 
```
**Using the ipv4_lookup plugin**

Now we are ready to put it all together and invoke the IPv4_lookup plugin which will do the work for us. This plugin will, in effect, run a for each loop in a sense that will check whether the IP address in our “MyIp” in memory table (see below) matches one of the address prefix in the “MyServiceTag” table. Here’s how to do it. This script can be found [in the repo here](/Code/KQL/3%20-%20Ipv4_lookup%20script.kql).

```Kql
// first we create a table with a set of IP adresses we want to check against the service tag data
// We're using a let statement that returns a table called "MyIps" with the IPs in it. 
let MyIps = datatable(ip:string)
[
    '13.71.175.81',
    '2.20.183.12', 
    '5.8.1.2',     
    '192.165.12.17',
];
MyIps
| evaluate ipv4_lookup
                (
                     // First parameter is the lookup table. Here we're calling the helper function
                     GetLatestServiceTags()    
                    // next we tell it what column to use in the sample table. Here it's called "ip"
                    ,ip                     
                    // finally we tell it the column to compare it to. Here it is the "ServiceTagIpRange"
                    ,ServiceTagIpRange      
                )   
```
If everything worked, only one of the IP addresses above will be a match. Indeed **13.71.175.81** is an IP reserved for Data Factory in the CanadaCentral region. Let’s dig into the results and see what this means:

|ip| ServiceTagName	|ServiceTagIpRange	|CloudChangeNumber|
|--| -------------- | ----------------- | --------------- |
13.71.175.81 | DataFactoryManagement | 	13.71.175.80/28 | 102 |
13.71.175.81 | DataFactory.CanadaCentral |	13.71.175.80/28 | 102 |
13.71.175.81 | DataFactory |	13.71.175.80/28 | 102 |
13.71.175.81 | AzureCloud.canadacentral | 13.71.160.0/19 | 102 |
13.71.175.81 | AzureCloud |	13.71.160.0/19 | 102 |

As a network engineer, you want to whitelist the least number of public IPs as possible. List returned has a number of different service tags and they all cover that **13.71.175.81** IP but you don't necessarely want to whitelist a tag that contains a large number of IP range since you don't necessarely will use them all.
Let's use KQL to get a sense of how many ranges we have for each of them. We can use the function created earlier but run a [quick stats script](/Code/KQL/4%20-%20ServiceTagStats.kql) like so:

```Kql
// Let's get a quick datatable with our servicetags of interest in it
let MyServiceTagSample = datatable(ServiceTagName:string)
[
'ServiceTagName',
'DataFactoryManagement',
'DataFactory.CanadaCentral',
'DataFactory',
'AzureCloud.canadacentral',
'AzureCloud'
];
// use an inner join to get the ranges associated with the service tags of interest
GetLatestServiceTags
| join kind=inner MyServiceTagSample on ServiceTagName
// casting a flag to determine is it's an IP V4 or IP V6 so we don't skew the count
| extend isIpv4 = case(indexof(ServiceTagIpRange,":") > 0, 0, 1)
| summarize StCount = count() by ServiceTagName, isIpv4
// Ordering by count and by service tags
| order by StCount, ServiceTagName
```
Let's dig into the results:

| ServiceTagName | isIpv4 | StCount |
| -------------- | ------ | ------- | 
| AzureCloud | 1 | 5325 |
| AzureCloud | 0 | 1040 |
| DataFactory |	1 | 344 |
| DataFactory |	0 | 279 |
| DataFactoryManagement | 1 | 212 |
| DataFactoryManagement | 0 | 194 |
| AzureCloud.canadacentral | 1 | 73 |
| AzureCloud.canadacentral | 0 | 13 |
| DataFactory.CanadaCentral | 1 | 8 |
| DataFactory.CanadaCentral | 0 | 7 |

As you can see, if you whitelist the AzureCloud service tag, the **13.71.175.81** is included in the one the ranges but you are, in effect, whitelisting the entire list of public IPs for everything in the public azure cloud. So obviously not what we want.

As you make your way down the list, you can see the list of service tags getting progressively more precise. The very last one "**DataFactory.CanadaCentral**" is the clear winner here with only 8 IP ranges. Ultimately, the choice is made by the network engineer to either use a narrowed down service tags or a broader one. Depending on your strategy and regional scale, a broader service tag may be more useful.

With this approach, you can help your customer be more intentional with their firewall rules and take the trial-and-error approach out of the picture. Some of the more modern network security appliances on the market even support Azure Service Tags so network engineer can create on-premises firewall rule that are "azure aware" and can thus abstract away the complexities of running a large-scale firewall rule set.

I hope you found this helpful, there is tons of ways we can make this even more powerful so please be generous with your feedback and contributions!




