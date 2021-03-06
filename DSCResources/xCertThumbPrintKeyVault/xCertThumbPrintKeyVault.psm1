function Get-TargetResource
{
  [CmdletBinding()]
  [OutputType([System.Collections.Hashtable])]
  param
  (
    [parameter(Mandatory = $true)]
    [System.String]
    $Subject
  )

  $thumbprinttable = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object -FilterScript {
    $_.subject -eq "CN=$Subject"
  }

  $thumbprint = $thumbprinttable.Thumbprint
  $Subject = $thumbprinttable.Subject
    
  $returnValue = @{
    Thumbprint = [System.String]$thumbprint
    Subject    = [System.String]$Subject
  }
    
  $returnValue
}


function Set-TargetResource
{
  [CmdletBinding()]
  param
  (
    [parameter(Mandatory = $true)]
    [System.String]
    $Subject,

    [ValidateSet('Present','Absent')]
    [System.String]
    $Ensure,

    [System.String]
    $NodeName,

    [System.String]
    $VaultName,

    [System.Management.Automation.PSCredential]
    $VaultCredential
  )

  if ($Ensure -eq 'Present')
  {
    $PlainTextThumbprint = Get-ChildItem -Path Cert:\LocalMachine\My |
    Where-Object -FilterScript {
      $_.subject -eq "CN=$Subject"
    } |
    Select-Object -Property Thumbprint -ExpandProperty Thumbprint

    $Thumbprint = New-Object System.Security.SecureString

    $chars = $PlainTextThumbprint.ToCharArray()

    foreach ($char in $chars) {$Thumbprint.AppendChar($char)}
  
    Write-Verbose -Message "Getting the Certificate Thumbprint and putting it into Azure KeyVault."
    
    Add-AzureRmAccount -Credential $VaultCredential
          
    Set-AzureKeyVaultSecret -VaultName $VaultName -SecretValue $Thumbprint -Name $NodeName      
      
    Write-Verbose -Message 'Writing Thumbprint to Azure KeyVault.'
  }
  else 
  {
    Add-AzureRmAccount -Credential $VaultCredential

    Remove-AzureKeyVaultSecret -VaultName 'svenvanrijeneu' -Name $NodeName 
  }
}


function Test-TargetResource
{
  [CmdletBinding()]
  [OutputType([System.Boolean])]
  param
  (
    [parameter(Mandatory = $true)]
    [System.String]
    $Subject,

    [ValidateSet('Present','Absent')]
    [System.String]
    $Ensure,

    [System.String]
    $NodeName,

    [System.String]
    $VaultName,

    [System.Management.Automation.PSCredential]
    $VaultCredential
  )

  Write-Verbose -Message "Is the thumbprint for subject CN=$Subject available in the Key Vault?"
    
  Add-AzureRmAccount -Credential $VaultCredential | Out-Null
  
  Get-AzureKeyVaultSecret -VaultName $VaultName -Name $NodeName -ErrorAction SilentlyContinue -ErrorVariable ProcessError | Out-Null
    if ($ProcessError) {
      
      Write-Verbose -Message "Thumbprint does not exist in Key Vault or there was a problem login into the Key Vault"
      $false
      exit
    }
    else {

      $Secret = Get-AzureKeyVaultSecret -VaultName $VaultName -Name $NodeName

    }

  $test = $Secret.SecretValueText
  
  Write-Verbose -Message "$test"

  $test2 = Get-ChildItem -Path Cert:\LocalMachine\My |
  Where-Object -FilterScript {
    $_.subject -eq "CN=$Subject"
  } |
  Select-Object -Property Thumbprint -ExpandProperty Thumbprint
  
  Write-Verbose -Message "$test2"

  if ($test -eq $test2)
  {
    
    return $true
  }
  Else 
  {
    
    return $False
  }
}


Export-ModuleMember -Function *-TargetResource

