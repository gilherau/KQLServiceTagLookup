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

### Creating a table

Use the following KQL code to create the table where we will store the service tag data:

```Kusto
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





