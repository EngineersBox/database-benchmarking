# Cassandra Benchmarking

1. Ensure you have SSH keys added on CloudLab
2. Create a Cassandra cluster on CloudLab
3. Open a shell to the `collector` node either in browser or via SSH
4. Run `sudo /var/lib/cluster/benchmarking/cassandra/run.sh --load_workload=<path> --run_workload=<path> --drive_config=<path>` (Run with `--help` to see options)
5. Wait for benchmarking to finish
