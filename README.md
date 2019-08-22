Nomadstack - nomad in nomad inception
=====================================

This project aims at running the hashicorp stack inside Nomad. Consul and Nomad servers are managed as Nomad jobs and are handled automatically. To run this, you only need to have nomad clients running, connecting to nomad servers inside the cluster.

Future improvements would be to include Vault.

To get up and running, a bootstrap phase is required, and this is the object of this project.

Current status
--------------

- nomad job contains hardcoded path to nomad and consul binaries
- bootstrap is on the way but not complete
- bootstrap is using a shell script and should be improved
- Full outage (such as power off on all the nomad nodes) is irrecoverable because the nomad clients will start up, but will be unable to spawn the nomad servers.

Current issues:

- Consul and Nomad must run a cluster of 3 minimum because Nomad, when draining allocs off nodes, it will stop the old alloc before the new alloc replacing it is fully started.
- Final nomad node created does not have consul connectivity (because the consul client that is running on it is just starting and hasn't joined). Because nomad in consul-template does not have nomad service discovery, it is impossible to automatically join consul
- New consul/nomad servers running on the final node will not join the existing clusters because of missing consul connectivity.


How to run it
-------------

Just start `bootstrap.sh`. It will:

- Start a nomad bootstrap node (both client and server mode)
- Run on the initial nomad cluster a Consul server
- Run a Consul agent in system mode (one allocation running per node) and connect it to the Consul server in Nomad
- Run a Nomad server cluster as Nomad jobs, and make them join the bootstrap Nomad server

You then have a bootstrap node with Consul client/server and Nomad server running in it. You then need to manually start a Nomad node in client mode and connect it to the running Consul cluster. It will automatically join the Nomad cluster and be ready to schedule Nomad allocations

For that, you can run `run-node.sh` that will run a Nomad node. You can use anything else you desire such as systemd unit.

Then, `bootstrap.sh` will detect this and sart draining the bootstrap nomad node. This will move the Nomad and Consul servers in the new node. Then, when the clusters are ready elsewhere, the bootstrap node can be stopped.

Future design
=============

Bundle in a single binary consul and nomad (à la k3s). Have this binary start the consul and nomad clients simultaneously.

Bootstrap mechanism:

- nomadstack starts a nomad client and a consul client
- nomadstack also listens to a specific API endpoint on localhost only
- an agent on the machine will ask via this API to perform a bootstrap
- nomadstack will start a nomad server on ports 146xx and a consul server on 18xxx
- it will join its nomad client with the nomad server and its consul client with the consul server
- it will start the consul-server and nomad-server in the nomad cluster
- ensuring the servers joined, it will stop the bootstrap servers

Cold boot mechanism:

- nomadstack starts up and restarts the consul and nomad clients
- consul and nomad tries to connect to the servers, but cannot
- if servers were running on that node, nomadstack has a copy of the raft folder (must not be tmpfs)
- it copies the raft folder and starts a bootstrap nomad server with this raft folder and itself as only peer in peers.json
- it joins the nomad client and the nomad server
- the nomad client should restart the nomad servers in nomad
    - probably the old servers will not be able to rejoin
    - if the ip and port of the servers is not the same (new allocs) then other nomad clients will not be able to rejoin ;(

Oops :(

Another idea: Use the nomad task drivers to register a specific nomadstack task driver. With this task driver, nomad jobs can ask nomadstack to execute either a consul or nomad server directly from the nomadstack binary. On cold boot, nomadstack remembers the nomad and consul servers started, and re-execute them without being told by nomad. And when the nomad client restarts, it re-attach to the nomad and consul servers.

See: https://www.nomadproject.io/docs/internals/plugins/task-drivers.html

