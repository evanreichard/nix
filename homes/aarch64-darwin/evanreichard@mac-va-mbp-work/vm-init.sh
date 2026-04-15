echo "
 ██████╗██████╗  ██████╗ ██╗    ██╗██████╗ ███████╗████████╗██████╗ ██╗██╗  ██╗███████╗
██╔════╝██╔══██╗██╔═══██╗██║    ██║██╔══██╗██╔════╝╚══██╔══╝██╔══██╗██║██║ ██╔╝██╔════╝
██║     ██████╔╝██║   ██║██║ █╗ ██║██║  ██║███████╗   ██║   ██████╔╝██║█████╔╝ █████╗  
██║     ██╔══██╗██║   ██║██║███╗██║██║  ██║╚════██║   ██║   ██╔══██╗██║██╔═██╗ ██╔══╝  
╚██████╗██║  ██║╚██████╔╝╚███╔███╔╝██████╔╝███████║   ██║   ██║  ██║██║██║  ██╗███████╗
 ╚═════╝╚═╝  ╚═╝ ╚═════╝  ╚══╝╚══╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝
         EVASION SYSTEM  -  Because IT can't handle Nix 
"

# Start VM
utmctl=/Applications/UTM.app/Contents/MacOS/utmctl
vm="lin-va-mbp-work-vm"

if ! "$utmctl" status "$vm" | grep -q "started"; then
    echo "  [*] CrowdStrike Evasion VM Starting..."
    "$utmctl" start "$vm"
fi

# Wait for VM & Start Tunnel
if ! pgrep -f "ssh -N -D 1080 adios-cs" > /dev/null; then
    echo "  [*] VM Starting..."
    until nc -z -w 2 192.168.64.3 22 &> /dev/null; do
        sleep 2
    done
    echo "  [✓] VM Started"

    echo "  [*] VM SOCKS Proxy Starting..."
    ssh -N -D 1080 adios-cs &> /dev/null &
    disown
    echo "  [✓] VM SOCKS Proxy Started"
else
    echo "  [✓] VM SOCKS Proxy Already Running"
fi

echo -e "  [*] Connecting..."

# Connect to VM
mosh --ssh="ssh -q" adios-cs -- tmux new-session -A -s main
