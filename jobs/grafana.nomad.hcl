job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "8.8.8.8", "8.8.4.4"]
      }
      port "http" {
        static = 3000
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana"
        ports = ["http"]
      }

      env {
        GF_LOG_LEVEL          = "DEBUG"
        GF_LOG_MODE           = "console"
        GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
      }

      template {
        data        = <<EOTC
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus.service.dc1.consul:9090
  - name: Loki
    type: loki
    access: proxy
    url: http://loki.service.dc1.consul:3100
    jsonData:
      derivedFields:
        - datasourceUid: tempo
          matcherRegex: (?:traceID|trace_id)=(\w+)
          name: TraceID
          url: $${__value.raw}
EOTC
        destination = "/local/grafana/provisioning/datasources/ds.yaml"
      }
      template {
        data        = <<EOTC
apiVersion: 1
providers:
- name: dashboards
  type: file
  updateIntervalSeconds: 30
  options:
    path: /local/grafana/dashboards
    foldersFromFilesStructure: true
EOTC
        destination = "/local/grafana/provisioning/dashboards/dashboard.yaml"
      }
      artifact {
        source      = "https://gist.githubusercontent.com/cyriltovena/6c755356417196bb9ee401262f06a303/raw/1eb96b31cef43097617eff43d7ee805ad0c09572/nomad-dashboard.json"
        destination = "/local/grafana/dashboards/tns.json"
      }

      resources {
        cpu    = 100
        memory = 100
      }

      service {
        name = "grafana"
        port = "http"
        tags = ["monitoring"]

        check {
          name     = "Grafana HTTP"
          type     = "http"
          path     = "/api/health"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}