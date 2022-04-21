network "dc1" {
  subnet = "10.7.0.0/16"
}

variable "vault_k8s_cluster" {
  default = "dc1"
}

module "vault" {
  source = "github.com/shipyard-run/blueprints?ref=ed077f6e8904d2cdbc016e1b7f6fff0ad410f5d2/modules//kubernetes-vault"
}

k8s_cluster "dc1" {
  driver = "k3s"
  network {
    name = "network.dc1"
  }
}


k8s_config "postgres" {
  cluster = "k8s_cluster.dc1"

  paths = [
    "./files/db.yaml",
  ]

  wait_until_ready = false
}

ingress "app" {
  source {
    driver = "local"
    config {
      port = 19090
    }
  }

  destination {
    driver = "k8s"
    config {
      cluster = "k8s_cluster.dc1"
      address = "app.default.svc"
      port    = 9090
    }
  }
}

ingress "postgres" {
  source {
    driver = "local"
    config {
      port = 15432
    }
  }

  destination {
    driver = "k8s"
    config {
      cluster = "k8s_cluster.dc1"
      address = "postgres.default.svc"
      port    = 5432
    }
  }
}

container "tools" {
  image {
    name = "shipyardrun/hashicorp-tools:v0.6.0"
  }

  network {
    name = "network.dc1"
  }

  command = ["tail", "-f", "/dev/null"]

  # Working files
  volume {
    source      = "./files"
    destination = "/files"
  }

  # Docker sock to be able to to do Docker builds 
  volume {
    source      = docker_host()
    destination = "/var/run/docker.sock"
  }

  # Shipyard config for Kube 
  volume {
    source      = "${shipyard()}"
    destination = "/root/.shipyard"
  }

  env {
    key   = "VAULT_TOKEN"
    value = "root"
  }

  env {
    key   = "KUBECONFIG"
    value = k8s_config_docker("dc1")
  }

  env {
    key   = "VAULT_ADDR"
    value = "http://${shipyard_ip()}:8200"
  }
}

container "jwt-util" {
  image {
    name = "nicholasjackson/jwt-util:0.0.1"
  }

  network {
    name = "network.dc1"
  }

  command = ["tail", "-f", "/dev/null"]

  # Working files
  volume {
    source      = "./files"
    destination = "/files"
  }
}

container "app" {
  image {
    name = "nicholasjackson/echo-config:0.0.1"
  }

  network {
    name = "network.dc1"
  }

  port {
    local  = 9090
    remote = 9090
    host   = 19090
  }

  env {
    key   = "VAULT_ADDR"
    value = "http://${shipyard_ip()}:8200"
  }

  volume {
    source      = "./files"
    destination = "/files"
  }
}

docs "docs" {
  path            = "./docs"
  port            = 18080
  open_in_browser = true

  index_title = "DocsExample"
  index_pages = [
    "index",
    "static_secrets",
    "policy",
    "authentication",
    "vault_agent",
  ]

  network {
    name = "network.dc1"
  }
}

exec_remote "generate_jwt" {
  target = "container.jwt-util"

  cmd = "sh"
  args = [
    "-c",
    "/files/generate_jwt.sh",
  ]
}

output "KUBECONFIG" {
  value = k8s_config("dc1")
}