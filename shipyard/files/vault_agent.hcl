auto_auth {
  method "jwt" {
    mount_path = "auth/jwt"
    config = {
      path = "/jwt.token"
      role = "api"
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

template {
  source      = "/config.tmpl"
  destination = "/config.json"
  command     = "kill -s SIGHUP $(cat /echo_config.pid)"
}