job "nomad-server" {
  datacenters = ["dc1"]

  update {
    canary           = 1
    auto_promote     = true
    health_check     = "checks"
    min_healthy_time = "1m"
    healthy_deadline = "5m"
  }

  migrate {
    max_parallel     = 1
    health_check     = "checks"
    min_healthy_time = "1m"
    healthy_deadline = "5m"
  }

  group "nomad" {
    count = 3
    task "nomad" {
      driver = "raw_exec"

      config {
        command = "/home/mildred/Projects/nomadstack/nomad"
        args = [
          "agent",
          "-config=${NOMAD_TASK_DIR}/config.hcl"
        ]
      }

      resources {
        memory = 256
        network {
          port "http" {}
          port "rpc" {}
          port "serf" {}
        }
      }

      template {
        destination = "local/config.hcl"
        data = <<CONFIG
          name = "nomad-server-{{ env "NOMAD_ALLOC_ID" }}",
          data_dir = "{{ env "NOMAD_ALLOC_DIR" }}/nomad-data"
          server {
            enabled  = true
          }
          leave_on_interrupt = true
          leave_on_terminate = true
          consul {
            address = "{{ env "attr.unique.network.ip-address" }}:8500"
          }
          addresses {
            http = "{{ env "NOMAD_IP_http" }}"
            rpc  = "{{ env "NOMAD_IP_rpc" }}"
            serf = "{{ env "NOMAD_IP_serf" }}"
          }
          ports {
            http = {{ env "NOMAD_PORT_http" }}
            rpc  = {{ env "NOMAD_PORT_rpc" }}
            serf = {{ env "NOMAD_PORT_serf" }}
          }
        CONFIG
      }

      service {
        port = "http"
        check {
          type           = "http"
          name           = "Nomad cluster status"
          interval       = "5s"
          timeout        = "1s"
          initial_status = "critical"
          path           = "/v1/operator/raft/configuration"
        }
      }
    }
  }
}