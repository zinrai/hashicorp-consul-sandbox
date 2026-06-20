services {
  name    = "cache"
  address = "172.28.0.33"
  port    = 5678

  check {
    http     = "http://172.28.0.33:5678/"
    interval = "10s"
    timeout  = "2s"
  }
}
