#Powershell script to add "SecurityEventLog,CloudWatchLogsSystem" flow to AWS.EC2.Windows.CloudWatch.json

#region PARAMETERS
    
    $region = (Invoke-RestMethod "http://169.254.169.254/latest/dynamic/instance-identity/document").region
    $EC2ConfigCWConfigurationFile = "C:\Program Files\Amazon\Ec2ConfigService\Settings\AWS.EC2.Windows.CloudWatch.json"
    $EC2ConfigConfigurationFile = "C:\Program Files\Amazon\Ec2ConfigService\Settings\config.xml"

#endregion

try{

    #Read the JSON into a PS object for manipulation
    $cloudWatchJSONConf = (Get-Content 'C:\Program Files\Amazon\Ec2ConfigService\Settings\AWS.EC2.Windows.CloudWatch.json') -Join "`n" -Replace "us-east-1",$region | ConvertFrom-Json
    # TO-DO: Need to check if the required configuration is already there.

    #Create new component
    $component = @'
            {
                "Id": "CloudWatchLogsForSecurityEvents",
                "FullName": "AWS.EC2.Windows.CloudWatch.CloudWatchLogsOutput,AWS.EC2.Windows.CloudWatch",
                "Parameters": {
                    "AccessKey": "",
                    "SecretKey": "",
                    "Region": "$REGION",
                    "LogGroup": "/heisenberg/security",
                    "LogStream": "{hostname}"
                }
            }

'@
    $component = $component.Replace('$REGION', $region).Trim()

    $cloudWatchJSONConf.EngineConfiguration.Components += $component | ConvertFrom-Json

    #Put new flow into variable to be worked on
    $flow = "SecurityEventLog,CloudWatchLogsForSecurityEvents"

    #Insert modified flows array into original object
    $cloudWatchJSONConf.EngineConfiguration.Flows.Flows += $flow

    #Rename original file
    Rename-Item $EC2ConfigCWConfigurationFile -NewName ($EC2ConfigCWConfigurationFile + ".original")

    #Convert back to JSON and write back to original file
    $cloudWatchJSONConf | ConvertTo-Json -Depth 10 -Compress | Out-File $EC2ConfigCWConfigurationFile

    #Enable CW integration
    [xml] $EC2ConfigConfiguration = Get-Content $EC2ConfigConfigurationFile
    $EC2ConfigConfiguration.SelectNodes("/Ec2ConfigurationSettings/Plugins/Plugin") | ? {$_.Name -eq "AWS.EC2.Windows.CloudWatch.PlugIn"} | % { $_.State ="Enabled"}

    #Rename original file
    Rename-Item $EC2ConfigConfigurationFile -NewName ($EC2ConfigConfigurationFile + ".original")

    $EC2ConfigConfiguration.Save($EC2ConfigConfigurationFile)

    Restart-Service EC2Config

}
catch{

    Write-Error $_.Exception.Message

    if(Test-Path ($EC2ConfigCWConfigurationFile + ".original")){

        if(Test-Path $EC2ConfigCWConfigurationFile){

            Remove-Item $EC2ConfigCWConfigurationFile

        }

        Rename-Item ($EC2ConfigCWConfigurationFile + ".original") -NewName $EC2ConfigCWConfigurationFile -Force

    }
   
}
