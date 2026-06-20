services {
  name    = "web"
  address = "172.28.0.32"
  port    = 5678

  check {
    http     = "http://172.28.0.32:5678/"
    interval = "10s"
    timeout  = "2s"
  }
}
