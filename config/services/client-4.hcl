services {
  name    = "api"
  address = "172.28.0.34"
  port    = 5678

  check {
    http     = "http://172.28.0.34:5678/"
    interval = "10s"
    timeout  = "2s"
  }
}
