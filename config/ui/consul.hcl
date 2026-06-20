server      = false
client_addr = "0.0.0.0"

# Portable across the upgrade range: ui_config{} is 1.9+, but `ui = true` is
# accepted from 1.8 through current, so the same config boots every hop.
ui = true

retry_join = [
  "172.28.0.10",
  "172.28.0.11",
  "172.28.0.12",
  "172.28.0.13",
  "172.28.0.14",
]
