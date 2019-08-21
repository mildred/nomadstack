job "consul-server" {
  datacenters = ["dc1"]

  update {
    canary       = 1
    auto_promote = true
  }

  group "consul" {
    task "consul" {
      driver = "raw_exec"

      config {
        command = "/home/mildred/Projects/nomadstack/consul"
        args = [
          "agent",
          "-config-file=${NOMAD_TASK_DIR}/config.json",
        ]
      }

      resources {
        memory = 256
        network {
          port "dns" {}
          port "http" {}
          port "serf_lan" {}
          port "serf_wan" {}
          port "server" {}
        }
      }

      template {
        destination = "local/config.json"
        data = <<CONFIG
          {
            "server": true,
            "node_name": "consul-server-{{ env "NOMAD_ALLOC_ID" }}",

            {{ if eq (env "NOMAD_ALLOC_INDEX") "0" }}
            "bootstrap": true,
            {{ end }}

            "data_dir": "{{ env "NOMAD_ALLOC_DIR" }}/consul-data",

            "retry_join":     ["consul-server.lan.service.consul"],
            "retry_join_wan": ["consul-server.wan.service.consul"],

            "addresses": {
              "dns":      "{{ env "NOMAD_IP_dns" }}",
              "http":     "{{ env "NOMAD_IP_http" }}"
            },
            "client_addr": "{{ env "NOMAD_IP_server" }}",
            "serf_lan":    "{{ env "NOMAD_IP_serf_lan" }}",
            "serf_wan":    "{{ env "NOMAD_IP_serf_wan" }}",

            "advertise_addr":     "{{ env "NOMAD_IP_server" }}",
            "advertise_addr_wan": "{{ env "NOMAD_IP_serf_wan" }}",

            "ports": {
              "dns":      {{ env "NOMAD_PORT_dns" }},
              "http":     {{ env "NOMAD_PORT_http" }},
              "serf_lan": {{ env "NOMAD_PORT_serf_lan" }},
              "serf_wan": {{ env "NOMAD_PORT_serf_wan" }},
              "server":   {{ env "NOMAD_PORT_server" }}
            }
          }
        CONFIG
      }

      service {
        name = "consul-server"
        port = "serf_lan"
        tags = [ "lan" ]
      }

      service {
        name = "consul-server"
        port = "serf_wan"
        tags = [ "wan" ]
      }
    }
  }
}

