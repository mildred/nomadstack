name = "bootstrap"

bind_addr = "0.0.0.0"
ports {
  http = 14646
  rpc  = 14647
  serf = 14648
}

server {
  enabled = true
  bootstrap_expect = 1
}

leave_on_interrupt = true
leave_on_terminate = true

client {
  enabled = true
}

consul {
  address = "127.0.0.1:8500"
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

