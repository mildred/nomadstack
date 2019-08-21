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

How to run it
-------------

Just start `bootstrap.sh`. It will:

- Start a nomad bootstrap node (both client and server mode)
- Run on the initial nomad cluster a Consul server
- Run a Consul agent in system mode (one allocation running per node) and connect it to the Consul server in Nomad
- Run a Nomad server cluster as Nomad jobs, and make them join the bootstrap Nomad server

You then have a bootstrap node with Consul client/server and Nomad server running in it. You then need to manually start a Nomad node in client mode and connect it to the running Consul cluster. It will automatically join the Nomad cluster and be ready to schedule Nomad allocations

For that, you can run `run-node.sh` that will run a Nomad node. You can use anything else you desire such as systemd unit.

Then, `bootstrap.sh` will detect this and:

- Start draining the bootstrap nomad node. This will move the Nomad and Consul servers in the new node
- Currently this fails because the nomaad client cannot execute on both the bootstrap nomad client and the new nomad client node as port numbers are in conflict. idea: prevent consul client to run on the bootstrap node and manually instanciate it in the bootstrap script. Then shut down the consul client to leave port numbers for the new consul client. possible problem: nomad will not have access to consul while starting the new consul client.
- new Consul servers cannot register with the existing consul cluster because consul DNS does not work and retry-join fails. idea: use the nomad templates to fetch existing consul addresses
- New Nomad servers cannot register with the nomad cluster because the consul server is in bad state (no known servers)
- Stop the bootstrap node
