job "consul-server" {
  datacenters = ["dc1"]

  update {
    canary       = 1
    auto_promote = true
  }

  migrate {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "1m"
    healthy_deadline = "5m"
  }

  group "consul" {

    # Minimum 3 servers are needed to perform migrations off draining nodes
    # without loosing the cluster. Nomad does not wait the new alloc to be
    # healthy before terminating the old one.
    count = 3

    task "consul" {
      driver = "raw_exec"

      config {
        command = "/home/mildred/Projects/nomadstack/consul"
        args = [
          "agent",
          "-config-file=${NOMAD_TASK_DIR}/config.json",
        ]
      }

      env {
        RESCHEDULE = 1
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
          {{- $is_bootstrap_alloc := and (eq (env "NOMAD_ALLOC_INDEX") "0") (eq (env "node.unique.name") "bootstrap") }}
          {
            "server": true,
            "node_name": "consul-server-{{ env "NOMAD_ALLOC_ID" }}",

            {{ if $is_bootstrap_alloc }}
            "bootstrap": true,
            {{ end }}

            "data_dir": "{{ env "NOMAD_ALLOC_DIR" }}/consul-data",

            "retry_join": [
              {{- if not $is_bootstrap_alloc }}
              {{- range service "lan.consul-server" }}
              "{{ .Address }}:{{ .Port }}",
              {{- end }}
              {{- end }}
              "consul-server.lan.service.consul"
            ],
            "retry_join_wan": ["consul-server.wan.service.consul" ],

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

      service {
        name = "consul-server"
        port = "http"
        tags = [ "http" ]
        check {
          type           = "http"
          name           = "Consul node status"
          interval       = "5s"
          timeout        = "1s"
          initial_status = "critical"
          path           = "/v1/agent/self"
          check_restart {
            grace = "30s"
            limit = 1
          }
        }
        check {
          type           = "http"
          name           = "Consul cluster status"
          interval       = "5s"
          timeout        = "1s"
          initial_status = "critical"
          path           = "/v1/operator/raft/configuration"
        }
      }
    }
  }
}

