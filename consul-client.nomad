job "consul-client" {
  type = "system"
  datacenters = ["dc1"]

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
          port "dns"      { static = 8600 }
          port "http"     { static = 8500 }
          port "serf_lan" { static = 8301 }
          port "serf_wan" { static = 8302 }
          port "server"   { static = 8300 }
        }
      }

      template {
        destination = "local/config.json"
        data = <<CONFIG
          {
            "data_dir": "{{ env "NOMAD_ALLOC_DIR" }}/consul-data",
            "ui": true,

            "retry_join": [
              "consul-server.lan.service.consul"
            ],
            "retry_join_wan": [
              "consul-server.wan.service.consul"
            ],

            "addresses": {
              "dns":      "{{ env "NOMAD_IP_dns" }}",
              "http":     "{{ env "NOMAD_IP_http" }}"
            },
            "client_addr": "{{ env "NOMAD_IP_server" }}",
            "serf_lan":    "{{ env "NOMAD_IP_serf_lan" }}",
            "serf_wan":    "{{ env "NOMAD_IP_serf_wan" }}",

            "advertise_addr":     "{{ env "NOMAD_IP_serf_lan" }}",
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
    }
  }
}

