The `NuGetFeedInfo.ps1` script is used to gather information from a NuGet feed.  The following arguments are supported:

| Name | Description |
|------|-------------|
| -feedUri | The full URI of the package feed.  Examples include `https://nuget.pkg.github.com/NAMESPACE/index.json` and `https://MY_ORG.jfrog.io/artifactory/api/nuget/v3/nuget-local` |
| -packageName | The name of a sample package that exists on the feed. |
| -username | (OPTIONAL) The username to use when authenticating to the feed. |
| -password | (OPTIONAL) The password to use when authenticating to the feed. |

The result of running the script is a directory named `logs` that will contain `NuGetFeedInfo.log` and the response objects of several HTTP queries.

Full example:

``` powershell
NuGetFeedInfo.ps1 -feedUri "https://nuget.pkg.github.com/NAMESPACE/index.json" -packageName "Sample.Package" -username "MY-USERNAME" -password "MY-PASSWORD"
```
