#!/bin/bash
nomad=./nomad
consul=./consul

: ${FINAL_NOMAD_ADDR:=$NOMAD_ADDR}
: ${FINAL_NOMAD_ADDR:=http://127.0.0.1:4646}

data_dir="$(mktemp -d)"

cleanup(){
  echo "Removing $data_dir"
  rm -rf $data_dir
}

trap cleanup 0

$nomad agent -config=bootstrap.hcl -data-dir="$data_dir" >bootstrap.log 2>&1 &

nomad_pid=$!
export NOMAD_ADDR=http://127.0.0.1:14646

shutdown(){
  echo "Drain Nomad"
  $nomad node eligibility -disable -self
  $nomad node drain -enable -self -yes
  $nomad node drain -enable -self -force -yes
  echo "Kill $nomad_pid"
  kill $nomad_pid
  cleanup
  exit 0
}
trap shutdown INT TERM

echo "Nomad starting as PID $nomad_pid..."
echo "Nomad data dir: $data_dir"
sleep 5s

echo "Starting Consul..."
$nomad run consul-server.nomad
$nomad run consul-client.nomad
$nomad run consul-bootstrap-client.nomad

sleep 5s

echo
echo "Joining consul client with consul server..."

consul_client_alloc_id=null
sleep=":"
while [ $consul_client_alloc_id = null ]; do
  consul_client_alloc_id="$(curl -s http://127.0.0.1:14646/v1/allocations | \
    jq -r '[.[] | select(.JobID == "consul-bootstrap-client" and .ClientStatus == "running") | .ID][0]')"
  consul_client_ip_port="$(curl -s http://127.0.0.1:14646/v1/allocation/$consul_client_alloc_id | \
    jq -r '.TaskResources.consul.Networks[0] | [.IP, ":", [.ReservedPorts[] | select(.Label == "http")][0].Value | tostring] | add')"
  eval "$sleep"
  sleep="echo .; sleep 1"
done

echo "Consul client: $consul_client_alloc_id $consul_client_ip_port"
export CONSUL_HTTP_ADDR="http://$consul_client_ip_port"

consul_server_alloc_id=null
sleep=":"
while [ $consul_server_alloc_id = null ]; do
  consul_server_alloc_id="$(curl -s http://127.0.0.1:14646/v1/allocations | \
    jq -r '[.[] | select(.JobID == "consul-server" and .ClientStatus == "running") | .ID][0]')"
  consul_server_ip_port="$(curl -s http://127.0.0.1:14646/v1/allocation/$consul_server_alloc_id | \
    jq -r '.TaskResources.consul.Networks[0] | [.IP, ":", [.DynamicPorts[] | select(.Label == "serf_lan")][0].Value | tostring] | add')"
  eval "$sleep"
  sleep="echo .; sleep 1"
done

echo "Consul server: $consul_server_alloc_id $consul_server_ip_port"

$consul join $consul_server_ip_port

sleep 5s

#$nomad alloc restart $consul_server_alloc_id

echo
echo "Register bootstrap Nomad server in Consul..."
$consul services register -id=_nomad-bootstrap-server-http -name=nomad -port=14646 -tag=http
$consul services register -id=_nomad-bootstrap-server-rpc  -name=nomad -port=14647 -tag=rpc
$consul services register -id=_nomad-bootstrap-server-serf -name=nomad -port=14648 -tag=serf

echo
echo "Starting Nomad server in Nomad..."
$nomad run nomad-server.nomad

old_server_members=""
while [ "$(curl -s $NOMAD_ADDR/v1/agent/servers | jq '. | length')" -le 1 ]; do
  server_members="$($nomad server members)"
  if [ "$old_server_members" != "$server_members" ]; then
    echo "$ nomad server members"
    echo "$server_members"
  fi
  sleep 5s
  old_server_members="$server_members"
done
echo "$ nomad server members"
$nomad server members

$consul services deregister -id=_nomad-bootstrap-server-http
$consul services deregister -id=_nomad-bootstrap-server-rpc
$consul services deregister -id=_nomad-bootstrap-server-serf

echo
echo "----------"
echo

join_addresses="$(curl -s $CONSUL_HTTP_ADDR/v1/catalog/service/nomad | \
  jq -r '[.[] | select(.ServiceTags[] | contains("rpc")) | .ServiceAddress + ":" + (.ServicePort | tostring)] | join(" ")')"

old_node_status=""
old_node_config=""
while [ "$(curl -s $NOMAD_ADDR/v1/nodes | jq '[.[] | select(.Status == "ready")] | length')" -le 1 ]; do
  node_status="$($nomad node status)"
  node_config="$(NOMAD_ADDR=$FINAL_NOMAD_ADDR $nomad node config -update-servers $join_addresses 2>&1)"
  if [ "$old_node_status$old_node_config" != "$node_status$node_config" ]; then
    echo
    echo "Ready to accept new Nomad client nodes."
    echo "Make the node available on NOMAD_ADDR=$FINAL_NOMAD_ADDR"
    echo "Or execute the manual join command:"
    echo "    nomad node config -update-servers $join_addresses"
    echo
    echo "$ nomad node status"
    echo "$node_status"
    echo
    echo "$ nomad node config -update-servers $join_addresses"
    echo "$node_config"
    echo
  fi
  sleep 5s
  old_node_status="$node_status"
  old_node_config="$node_config"
done

echo
echo "$ nomad node status"
$nomad node status
echo

echo "Nomad node joined, stopping bootstrap node..."

$nomad node eligibility -disable -self
$nomad node drain -enable -self -no-deadline -yes

echo "Stopping consul bootstrap client..."

$nomad stop -purge consul-bootstrap-client

echo "Nomad bootstrap node drained"

sleep 24h
