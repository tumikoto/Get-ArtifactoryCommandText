#
# Script to dump all commandText data from local docker images/builds from an Artifactory server using REST API username + key
#

# Server
$serverBaseUri = "https://artifactory.example.com/artifactory"

# Setting up auth headers
$b64 = "Your <user>:<api-key> in base64 or encypted token goes here"
$headers = @{
	Authorization="Basic " + $b64;
	Accept="application/json, text/plain, */*"
}

# For storing output
$file = $env:userprofile + "\Desktop\artifactory_cmdtext_" + $b64.Substring(0,5) + ".csv"
$output = @()

# Getting all repos
Write-Host [+] Getting all repos we have access to
$repos = Invoke-RestMethod -Method GET -Headers $headers -Uri ($serverBaseUri + "/api/repositories")

# Loop through all repos that are docker/local
foreach ($repo in $repos | where {$_.packageType -match "docker" -and $_.type -match "local"})
{
	# Get all docker images in repo
	$reponame = $repo.key
	Write-Host [+] Getting all docker images in repo $reponame
	$images = Invoke-RestMethod -Method GET -Headers $headers -Uri ($serverBaseUri + "/api/docker/" + $reponame + "/v2/_catalog/")
	
	# Loop through all docker images
	foreach ($image in $images.repositories)
	{
		# Getting all 'paths' (builds/runs?) for the image
		Write-Host [+] Getting all `"paths`" for image $reponame/$image
		$text = $image.Split('/') |  Select -Last 1
		$body = '{"type":"junction","repoType":"local","repoKey":"' + $reponame + '","path":"' + $image + '","text":"' + $text + '","trashcan":false}'
		$treebrowser = Invoke-WebRequest -Uri ($serverBaseUri + "/ui/treebrowser?compacted=true&`$no_spinner=true") -Method "POST" -Headers $headers -ContentType "application/json" -Body $body
		[PSObject]$respObj = $treebrowser.content | ConvertFrom-Json
		
		# Loop through all 'paths' (builds/runs?) for the image
		foreach ($item in $respObj.data)
		{
			# Some text for your text so you can text while texting
			$text2 = $item.text
			
			# Hit that magic API endpoint to get that juicy commandText data
			Write-Host [+] Getting command data for $image/$text2`, cover your ears darlin`'
			$body = '{"view": "dockerv2", "repoKey": "' + $reponame + '", "path": "' + $image + '/' + $text2 + '"}'
			$response = Invoke-RestMethod -Method POST -Body $body -Headers $headers -Uri ($serverBaseUri + "/ui/views/dockerv2") -ContentType "application/json"
			
			# Append psobjs to output obj array
			$output += $response.blobsInfo
		}
	}
}

# Export output objs array to CSV file
$output | export-csv -path $file -notypeinformation -encoding utf8

# Done
Write-Host [+] Done!

