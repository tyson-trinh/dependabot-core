[CmdletBinding(PositionalBinding = $false)]
param (
    [string]$feedUri,
    [string]$packageName,
    [string]$username = $Null,
    [string]$password = $Null,
    [Parameter(ValueFromRemainingArguments = $true)][String[]]$arguments
)

Set-StrictMode -version 2.0
$ErrorActionPreference = "Stop"

$logDirectory = Join-Path $PSScriptRoot "logs"
$logFile = Join-Path $logDirectory "NuGetFeedInfo.log"
$packageNameLower = $packageName.ToLower()

function TrimTrailingSlash($path) {
    if ($path -eq $Null) {
        return $path
    }

    if ($path.EndsWith('/')) {
        return $path.Substring(0, $path.Length - 1)
    }

    return $path
}

function Log($message) {
    Write-Host $message
    $message | Tee-Object $logFile -Append | Out-Null
}

function Write-Response($response, $fileName) {
    $response.Content | Out-File (Join-Path $logDirectory $fileName) | Out-Null
}

function GetAndLogUri($message, $uri, $responseFileName = $null) {
    $headers = @{}
    if ($password) {
        if ($username) {
            $authentication = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($username + ":" + $password)))"
            $headers["Authorization"] = $authentication
        }
        else {
            $authentication = "Bearer $password"
            $headers["Authorization"] = $authentication
        }
    }

    $response = Invoke-WebRequest -Uri $uri -Headers $headers -SkipHttpErrorCheck
    Log "GET [$uri] for ($message): [$($response.StatusCode)] => [$responseFileName]"
    if ($responseFileName -ne $null) {
        Write-Response $response $responseFileName
    }

    return , $response
}

function GetResourceByNamePreference($serviceIndex, $acceptableResourceNames) {
    foreach ($acceptableResourceName in $acceptableResourceNames) {
        $resourceElement = $serviceIndex.resources | Where-Object { $_."@type" -eq $acceptableResourceName } | Select-Object -ExpandProperty "@id" | Select-Object -First 1
        if ($resourceElement -ne $Null) {
            $result = TrimTrailingSlash $resourceElement
            Log "Returning resource URL [$result] for $acceptableResourceName"
            return $result
        }
    }

    return $Null
}

try {
    # delete logs directory if it exists
    if (Test-Path $logDirectory) {
        Remove-Item -Recurse -Force $logDirectory
    }

    New-Item -Type Directory -Path $logDirectory | Out-Null

    # query the service index
    $response = GetAndLogUri "service-index" $feedUri "service-index.json"
    $serviceIndex = $response.Content | ConvertFrom-Json
    $packageBaseAddress = GetResourceByNamePreference $serviceIndex @("PackageBaseAddress/3.0.0")
    $registrationsBaseUrl = GetResourceByNamePreference $serviceIndex @("RegistrationsBaseUrl/3.6.0", "RegistrationsBaseUrl/3.4.0", "RegistrationsBaseUrl/3.0.0-rc", "RegistrationsBaseUrl/3.0.0-beta", "RegistrationsBaseUrl")
    $searchQueryService = GetResourceByNamePreference $serviceIndex @("SearchQueryService/3.5.0", "SearchQueryService/3.0.0-rc", "SearchQueryService/3.0.0-beta", "SearchQueryService")

    # query for packages from PackageBaseAddress
    if ($packageBaseAddress -eq $Null) {
        Log "No PackageBaseAddress found"
    }
    else {
        $versionsUrl = "$packageBaseAddress/$packageNameLower/index.json"
        $response = GetAndLogUri "PackageBaseAddress-versions" $versionsUrl "versions-index.json"
        $versionsResponse = $response.Content | ConvertFrom-Json
        $firstVersion = $versionsResponse.versions | Select-Object -Last 1

        GetAndLogUri "PackageBaseAddress-nuspec" "$packageBaseAddress/$packageNameLower/$firstVersion/$packageNameLower.nuspec" "direct-nuspec-download.xml" | Out-Null
        GetAndLogUri "PackageBaseAddress-nupkg" "$packageBaseAddress/$packageNameLower/$firstVersion/$packageNameLower.$firstVersion.nupkg" | Out-Null
    }

    # check the registration index
    $registrationUrl = "$registrationsBaseUrl/$packageNameLower/index.json"
    $response = GetAndLogUri "registration-index" $registrationUrl "registration-index.json"

    # check the search query service
    $searchUrl = "${searchQueryService}?q=$packageName&prerelease=true&semVerLevel=2.0.0"
    $response = GetAndLogUri "SearchQueryService" $searchUrl "search-results.json"
    $searchResults = $response.Content | ConvertFrom-Json
    $searchResultsWithMatchingId = $searchResults.data | Where-Object { $_.id.ToLower() -eq $packageNameLower } | Select-Object -Last 1
    $lastSearchResult = $searchResultsWithMatchingId.versions | Select-Object -Last 1

    # check registration leaf
    $registrationLeafUrl = $lastSearchResult."@id" # this _MIGHT_ be a URL or the name of the package
    if ($registrationLeafUrl.ToLower() -eq $packageNameLower) {
        Log "Registration leaf URL appears to be the package name"
    }
    else {
        $response = GetAndLogUri "registration-leaf" $registrationLeafUrl "registration-leaf.json"
        $registrationLeaf = $response.Content | ConvertFrom-Json
        $expectedNupkgUrl = $registrationLeaf.packageContent
        GetAndLogUri "registration-leaf-nupkg-direct" $expectedNupkgUrl | Out-Null
    }
}
catch {
    Write-Host $_
    Write-Host $_.Exception
    Write-Host $_.ScriptStackTrace
    exit 1
}
