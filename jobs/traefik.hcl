job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "8.8.8.8", "8.8.4.4"]
      }
      port "http" {
        static = 80
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.2"
        network_mode = "host"

        args = [
          "--metrics=true",
          "--accesslog=true",
          "--api.debug=true",
          "--metrics.prometheus=true",
          "--metrics.prometheus.manualrouting=true",
        ]

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
          "local/file-provider.toml:/etc/traefik/file-provider.toml",
        ]
      }

      template {
        data = <<EOF
[http.services]
  [http.services.nomad.loadBalancer]
    [[http.services.nomad.loadBalancer.servers]]
      url = "http://nomad-servers.service.dc1.consul:4646"

  [http.services.consul.loadBalancer]
    [[http.services.consul.loadBalancer.servers]]
      url = "http://consul.service.dc1.consul:8500"
  [http.routers]
    [http.routers.nomad]
    rule = "Host(`nomad.nomad-test.remerge.io`)"
    service = "nomad"

    [http.routers.consul]
    rule = "Host(`consul.nomad-test.remerge.io`)"
    service = "consul"
EOF
        destination = "local/file-provider.toml"
      }

      template {
        data = <<EOF
[entryPoints]
    [entryPoints.http]
    address = ":80"
    [entryPoints.traefik]
    address = ":8081"

[api]
    dashboard = true
    insecure  = true

[accessLog]
  filePath = "/access.log"
  format = "json"
[providers]
  [providers.file]
    filename = "/etc/traefik/file-provider.toml"

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
    prefix           = "traefik"
    exposedByDefault = false

    [providers.consulCatalog.endpoint]
      address = "172.17.0.1:8500"
      scheme  = "http"
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
