server           = true
bootstrap_expect = 5

client_addr = "0.0.0.0"

ui_config {
  enabled = true
}

retry_join = [
  "consul-0",
  "consul-1",
  "consul-2",
  "consul-3",
  "consul-4",
]
