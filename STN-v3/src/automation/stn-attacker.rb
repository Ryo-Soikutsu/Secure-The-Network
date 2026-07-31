###
# Secure The Network v3 automated attacker module
# This module will recreate the intended attack chain with minimal manual work
# Only use this module on simulated STN virtual networks

# Attack chain:
# - Initial network enumeration with nmap
# - Web enumeration + SSH brute-force
# - Exploit information disclosure vulnerability
# - Login as user via SSH
# - Exploit SUID binary to gain root access
# - Pillage + exfiltrate loot
# - Create backdoor cronjob and systemd service
###
