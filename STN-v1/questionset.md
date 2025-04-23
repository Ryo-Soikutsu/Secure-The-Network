## Question set for Secure The Network
1. What is the IP address of the attacker? - 201.172.32.43
2. What is the public IP address of the target? - 201.172.32.234
3. What tool did the attacker use to scan the target? Answer in all lower-case - nmap
4. What is the vulnerability used by the attacker on the target? Answer in all lower-case - path traversal/directory traversal
5. Give the timestamp when the enumeration process began. Answer in UTC (Format is MMM:DD, YYYY HH:MM:SS) - Nov 15, 2024 02:49:30
6. What is the first directory enumeration tool that the attacker uses? Answer in all lower-case - dirbuster
7. The attacker attempted to access the web server through SSH. What is the timestamp for the successful access? Answer in UTC (Format is YYYY-MM-DD HH:MM:SS) - 2024-11-1511:47:17
8. The attacker attempted to erase any traces of their attack by deleting system logs. Which files were modified by the attacker Answer in filename 1_filename 2 - auth.log_error.log
9. Upon further analysis of our firewall logs, it seems like one of the sysadmins had left in a rule which allowed for the attacker to access the remote server through
SSH. Identify this overly-permissive rule. Answer is the rule's tracker ID - 1730707767