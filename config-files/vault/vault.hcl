api_addr      = "https://vault.home.brianpooe.com"
cluster_addr  = "https://0.0.0.0:8200"
cluster_name  = "vault-server"
disable_mlock = true
ui            = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

storage "file" {
  path    = "/vault/data"
}