Primary vulnerabilities:
- Overly permissive firewall rules between DMZ and LAN
- Path traversal vulnerability on webserver + download file feature
    - Attacker downloads SSH login keys, ssh'd into web server
- (Potential feature) RFI vulnerability with an upload file feature, exploited by secondary (unrelated) attacker
    - insecure permissions on daemon file + running daemon config file as root without validation

Chain of attack (main attack):
- Brute-force URL endpoints (w/ Gobuster)
- Vulnerability scan (w/ Nikto)
- Manual path traversal testing (w/ finding SSH keys)
- Remote SSH into webserver, rooting machine
- Exfiltrating DB and webserver src code to remote machine

Chain of attack (secondary attack):
- Brute-force URL endpoints (w/ Gobuster)
- Vulnerability scan (w/ Nikto)
- Attempting to upload various malicious files to server
- Identify that the server (1) runs as root; (2) overwrites existing files with the uploaded content, if the file paths are the same; (3) periodically restarts
    the daemon every 5 minutes without checking the file integrity (most likely luck based, since no way of identifying)
- Exploit the daemon to upload a reverse shell, and add their own ssh key into the server
- (Secondary attack ends here, most likely due to the system being locked down after main attack was spotted)

Decoy traffic:
- On LAN interface:
    - Clients attempting to access various websites on the Internet
    - Clients downloading files from the Internet (most likely Github)
- On WAN interface:
    - 1 client uploading and downloading random files (Python script to generate random encrypted files)
    - 1 client (admin user) attempting to VPN into the internal server and accessing the admin portal
        - This client should fail to access the page several times due to typos, then mistyping of passwords
