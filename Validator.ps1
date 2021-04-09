#
# gestione parametri
#
param ($jobname)

# Carica le API di Veeam
# Non funziona sui job di copia, eliminato la parte relativa nello script.
Add-PSSnapIn VeeamPSSNapin

$backupjobs = Get-VBRComputerBackupJob
#$copyjobs = Get-VBRComputerBackupCopyJob

# se non sono specificati parametri stampa l'elenco dei parametri validi
if ($jobname -eq $null) {
	Write-Host
	Write-Host -Foregroundcolor green "Job configurati:"
	foreach ($job in $backupjobs) {
		Write-Host $job.name
	}
	Write-Host

	$jobname = Read-Host -Prompt "Inserire il nome del job da validare"
}

# se alla richiesta di inserire il parametro si preme "invio" esce con un errore
if ($jobname -eq "") {
	Write-Error "Specificare il nome di un job." -ErrorAction Stop
}

# controlla che il nome del job esista e sia valido
$valido = 0

foreach ($job in $backupjobs) {
	if ($jobname -eq $job.name) {
		$valido = 1
		break
	}
}
if ($valido -eq 0) {
	Write-Error "Il nome del job non è valido." -ErrorAction Stop
}

#
# configurazione variabili
#

# indirizzi email mittente e destinatario
$SenderAddr = "sender@domain.tld"
$DestinationAddr = "recipient@domain.tld"

# email server
$SMTPServer = "server.domain.tld"

# path dell'eseguibile
$pwd = Get-Location
Set-Location "C:\Program Files\Veeam\Backup and Replication\Backup"

#
# Report per i job di backup
#

$job = Get-VBRComputerBackupJob -Name $jobname

# gruppo di macchine inserite nel job
$group = Get-VBRJobObject $job

# usare group.location, usando group.name non funziona per windows servers. Non so perchè.
$protectiongroup = Get-VBRProtectionGroup -Name $group.location

# macchine virtuali che fanno parte del gruppo
$vms = Get-VBRDiscoveredComputer -ProtectionGroup $protectiongroup.name

foreach ($vm in $vms) { 
	# percorso in cui salvare i report
	$date = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd-hh-mm')
	$VeeamOutputFile = "c:\Users\user\Desktop\VeeamValidator\$vm-$date.html"
	
	# debug
	#Write-Host
	#Write-Host -Foregroundcolor yellow "Macchina: $vm" 
	#Write-Host "Job: $jobname"
	#Write-Host "Gruppo protezione: $protectiongroup"
	#Write-Host "Report: $VeeamOutputFile"

	# lancia il comando Veeam.BackupValidator coi parametri necessari
	.\Veeam.Backup.Validator.exe /backup:"$jobname" /vmname:"$vm" /format:html /report:"$VeeamOutputFile"
		
	# invia il report via email
	send-mailmessage -from "<$SenderAddr>" -to "<$DestinationAddr>" -subject "Veeam Validation Report for $jobname - $vm" -body "Report Attached." -Attachments "$VeeamOutputFile" -dno onSuccess, onFailure -smtpServer $SMTPServer
	# debug
	#send-mailmessage -from "<$SenderAddr>" -to "<$DestinationAddr>" -subject "Veeam Validation Report for $jobname - $vm" -body "Report Attached." -dno onSuccess, onFailure -smtpServer $SMTPServer
}

# torna alla directory da cui è stato lanciato lo script
Set-Location $pwd
