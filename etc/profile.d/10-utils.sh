export PATH="/var/lib/cluster/scripts:$PATH"
for d in /var/lib/cluster/scripts/*; do
    if [ -d "${d}" ]; then
        export PATH="$d:$PATH"
    fi
done

alias jfu="journalctl -f -u"
alias sjfu="sudo journalctl -f -u"
alias jft="journalctl -f -t"
alias sjft="sudo journalctl -f -t"

alias dp="sudo docker ps -a"
alias dfl="sudo docker logs -f"
alias dl="sudo docker logs"

function logs() {
    less "/var/lib/cluster/logs/$1"
}
