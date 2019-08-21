#!/bin/bash
nomad=./nomad

consul_client_alloc_id="$(curl -s http://127.0.0.1:14646/v1/allocations | \
  jq -r '[.[] | select(.JobID == "consul-client" and .ClientStatus == "running") | .ID][0]')"
consul_client_ip_port="$(curl -s http://127.0.0.1:14646/v1/allocation/$consul_client_alloc_id | \
  jq -r '.TaskResources.consul.Networks[0] | [.IP, ":", [.ReservedPorts[] | select(.Label == "http")][0].Value | tostring] | add')"

data_dir="$(mktemp -d)"

cleanup(){
  echo "Removing $data_dir"
  rm -rf $data_dir
}

trap cleanup 0

exec $nomad agent -config=nomad-node.hcl -data-dir="$data_dir" -consul-address="$consul_client_ip_port"
