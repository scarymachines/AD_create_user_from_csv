# create_user_from_csv

This Powershell script creates Active Directory users using a CSV file (UTF-8 without BOM).

It supports German umlauts and uses the German date format in the log file.

The domain name must be configured in the $domain variable

Two paths must be set:
$csvpath to the CSV file with the users 
$logpath for saving the log file.

The Powershell file contains additional comments in German.
