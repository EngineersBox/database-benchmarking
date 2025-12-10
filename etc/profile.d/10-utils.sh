export PATH="/var/lib/cluster/scripts:$PATH"
for d in /var/lib/cluster/scripts/*; do
    if [ -d "${d}" ]; then
        export PATH="/var/lib/cluster/scripts/$d:$PATH"
    fi
done
