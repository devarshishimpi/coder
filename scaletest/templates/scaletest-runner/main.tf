terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.22"
    }
  }
}

resource "time_static" "start_time" {
  # We con't set `count = data.coder_workspace.me.start_count` here because then
  # we can't use this value in `locals`. The permission check is recreated on
  # start, which will update the timestamp.
  triggers = {
    count : length(null_resource.permission_check)
  }
}

resource "null_resource" "permission_check" {
  count = data.coder_workspace.me.start_count

  # Limit which users can create a workspace in this template.
  # The "default" user and workspace are present because they are needed
  # for the plan, and consequently, updating the template.
  lifecycle {
    precondition {
      condition     = can(regex("^(default/default|scaletest/runner)$", "${data.coder_workspace.me.owner}/${data.coder_workspace.me.name}"))
      error_message = "User and workspace name is not allowed, expected 'scaletest/runner'."
    }
  }
}

locals {
  workspace_pod_name                             = "coder-scaletest-runner-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
  workspace_pod_instance                         = "coder-workspace-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
  workspace_pod_termination_grace_period_seconds = 5 * 60 * 60 # 5 hours (cleanup timeout).
  service_account_name                           = "scaletest-sa"
  cpu                                            = 16
  memory                                         = 64
  home_disk_size                                 = 10
  scaletest_run_id                               = "scaletest-${time_static.start_time.rfc3339}"
  scaletest_run_dir                              = "/home/coder/${local.scaletest_run_id}"
  grafana_url                                    = "https://stats.dev.c8s.io"
  grafana_dashboard_uid                          = "qLVSTR-Vz"
  grafana_dashboard_name                         = "coderv2-loadtest-dashboard"
}

data "coder_provisioner" "me" {
}

data "coder_workspace" "me" {
}

data "coder_parameter" "verbose" {
  order       = 1
  type        = "bool"
  name        = "Verbose"
  default     = false
  description = "Show debug output."
  mutable     = true
  ephemeral   = true
}

data "coder_parameter" "dry_run" {
  order       = 2
  type        = "bool"
  name        = "Dry-run"
  default     = true
  description = "Perform a dry-run to see what would happen."
  mutable     = true
  ephemeral   = true
}

data "coder_parameter" "create_concurrency" {
  order       = 10
  type        = "number"
  name        = "Create concurrency"
  default     = 10
  description = "The number of workspaces to create concurrently."
  mutable     = true

  # Setting zero = unlimited, but perhaps not a good idea,
  # we can raise this limit instead.
  validation {
    min = 1
    max = 100
  }
}

data "coder_parameter" "job_concurrency" {
  order       = 11
  type        = "number"
  name        = "Job concurrency"
  default     = 0
  description = "The number of concurrent jobs (e.g. when producing workspace traffic)."
  mutable     = true

  # Setting zero = unlimited, but perhaps not a good idea,
  # we can raise this limit instead.
  validation {
    min = 0
  }
}

data "coder_parameter" "cleanup_concurrency" {
  order       = 12
  type        = "number"
  name        = "Cleanup concurrency"
  default     = 10
  description = "The number of concurrent cleanup jobs."
  mutable     = true

  # Setting zero = unlimited, but perhaps not a good idea,
  # we can raise this limit instead.
  validation {
    min = 1
    max = 100
  }
}

data "coder_parameter" "cleanup_strategy" {
  order       = 13
  name        = "Cleanup strategy"
  default     = "always"
  description = "The strategy used to cleanup workspaces after the scaletest is complete."
  mutable     = true
  ephemeral   = true
  option {
    name        = "Always"
    value       = "always"
    description = "Automatically cleanup workspaces after the scaletest ends."
  }
  option {
    name        = "On stop"
    value       = "on_stop"
    description = "Cleanup workspaces when the workspace is stopped."
  }
  option {
    name        = "On success"
    value       = "on_success"
    description = "Automatically cleanup workspaces after the scaletest is complete if no error occurs."
  }
  option {
    name        = "On error"
    value       = "on_error"
    description = "Automatically cleanup workspaces after the scaletest is complete if an error occurs."
  }
}


data "coder_parameter" "workspace_template" {
  order        = 20
  name         = "workspace_template"
  display_name = "Workspace Template"
  description  = "The template used for workspace creation."
  default      = "kubernetes-minimal"
  icon         = "/emojis/1f4dc.png" # Scroll.
  mutable      = true
  option {
    name        = "Minimal"
    value       = "kubernetes-minimal" # Feather.
    icon        = "/emojis/1fab6.png"
    description = "Sized to fit approx. 32 per t2d-standard-8 instance."
  }
  option {
    name        = "Small"
    value       = "kubernetes-small"
    icon        = "/emojis/1f42d.png" # Mouse.
    description = "Provisions a small-sized workspace with no persistent storage."
  }
  option {
    name        = "Medium"
    value       = "kubernetes-medium"
    icon        = "/emojis/1f436.png" # Dog.
    description = "Provisions a medium-sized workspace with no persistent storage."
  }
  option {
    name        = "Large"
    value       = "kubernetes-large"
    icon        = "/emojis/1f434.png" # Horse.
    description = "Provisions a large-sized workspace with no persistent storage."
  }
}

data "coder_parameter" "num_workspaces" {
  order       = 21
  type        = "number"
  name        = "Number of workspaces to create"
  default     = 100
  description = "The scaletest suite will create this number of workspaces."
  mutable     = true

  validation {
    min = 0
    max = 1000
  }
}


data "coder_parameter" "load_scenarios" {
  order       = 22
  name        = "Load Scenarios"
  type        = "list(string)"
  description = "The load scenarios to run."
  mutable     = true
  ephemeral   = true
  default = jsonencode([
    "SSH Traffic",
    "Web Terminal Traffic",
    "Dashboard Traffic",
  ])
}

data "coder_parameter" "load_scenario_ssh_traffic_duration" {
  order       = 23
  name        = "SSH Traffic Duration"
  type        = "number"
  description = "The duration of the SSH traffic load scenario in minutes."
  mutable     = true
  default     = 30
  validation {
    min = 1
    max = 1440 // 24 hours.
  }
}

data "coder_parameter" "load_scenario_ssh_bytes_per_tick" {
  order       = 24
  name        = "SSH Bytes Per Tick"
  type        = "number"
  description = "The number of bytes to send per tick in the SSH traffic load scenario."
  mutable     = true
  default     = 1024
  validation {
    min = 1
  }
}

data "coder_parameter" "load_scenario_ssh_tick_interval" {
  order       = 25
  name        = "SSH Tick Interval"
  type        = "number"
  description = "The number of milliseconds between each tick in the SSH traffic load scenario."
  mutable     = true
  default     = 100
  validation {
    min = 1
  }
}

data "coder_parameter" "load_scenario_web_terminal_traffic_duration" {
  order       = 26
  name        = "Web Terminal Traffic Duration"
  type        = "number"
  description = "The duration of the web terminal traffic load scenario in minutes."
  mutable     = true
  default     = 30
  validation {
    min = 1
    max = 1440 // 24 hours.
  }
}

data "coder_parameter" "load_scenario_web_terminal_bytes_per_tick" {
  order       = 27
  name        = "Web Terminal Bytes Per Tick"
  type        = "number"
  description = "The number of bytes to send per tick in the web terminal traffic load scenario."
  mutable     = true
  default     = 1024
  validation {
    min = 1
  }
}

data "coder_parameter" "load_scenario_web_terminal_tick_interval" {
  order       = 28
  name        = "Web Terminal Tick Interval"
  type        = "number"
  description = "The number of milliseconds between each tick in the web terminal traffic load scenario."
  mutable     = true
  default     = 100
  validation {
    min = 1
  }
}

data "coder_parameter" "load_scenario_dashboard_traffic_duration" {
  order       = 29
  name        = "Dashboard Traffic Duration"
  type        = "number"
  description = "The duration of the dashboard traffic load scenario in minutes."
  mutable     = true
  default     = 30
  validation {
    min = 1
    max = 1440 // 24 hours.
  }
}

data "coder_parameter" "load_scenario_baseline_duration" {
  order       = 26
  name        = "Baseline Wait Duration"
  type        = "number"
  description = "The duration to wait before starting a load scenario in minutes."
  mutable     = true
  default     = 5
  validation {
    min = 0
    max = 60
  }
}

data "coder_parameter" "namespace" {
  order       = 999
  type        = "string"
  name        = "Namespace"
  default     = "coder-big"
  description = "The Kubernetes namespace to create the scaletest runner resources in."
}

data "archive_file" "scripts_zip" {
  type        = "zip"
  output_path = "${path.module}/scripts.zip"
  source_dir  = "${path.module}/scripts"
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  dir  = local.scaletest_run_dir
  os   = "linux"
  env = {
    VERBOSE : data.coder_parameter.verbose.value ? "1" : "0",
    DRY_RUN : data.coder_parameter.dry_run.value ? "1" : "0",
    CODER_CONFIG_DIR : "/home/coder/.config/coderv2",
    CODER_USER_TOKEN : data.coder_workspace.me.owner_session_token,
    CODER_URL : data.coder_workspace.me.access_url,
    CODER_USER : data.coder_workspace.me.owner,
    CODER_WORKSPACE : data.coder_workspace.me.name,

    # Global scaletest envs that may affect each `coder exp scaletest` invocation.
    CODER_SCALETEST_PROMETHEUS_ADDRESS : "0.0.0.0:21112",
    CODER_SCALETEST_PROMETHEUS_WAIT : "60s",
    CODER_SCALETEST_CONCURRENCY : "${data.coder_parameter.job_concurrency.value}",
    CODER_SCALETEST_CLEANUP_CONCURRENCY : "${data.coder_parameter.cleanup_concurrency.value}",

    # Expose as params as well, for reporting (TODO(mafredri): refactor, only have one).
    SCALETEST_PARAM_SCALETEST_CONCURRENCY : "${data.coder_parameter.job_concurrency.value}",
    SCALETEST_PARAM_SCALETEST_CLEANUP_CONCURRENCY : "${data.coder_parameter.cleanup_concurrency.value}",

    # Local envs passed as arguments to `coder exp scaletest` invocations.
    SCALETEST_RUN_ID : local.scaletest_run_id,
    SCALETEST_RUN_DIR : local.scaletest_run_dir,

    SCALETEST_PARAM_TEMPLATE : data.coder_parameter.workspace_template.value,
    SCALETEST_PARAM_NUM_WORKSPACES : data.coder_parameter.num_workspaces.value,
    SCALETEST_PARAM_CREATE_CONCURRENCY : "${data.coder_parameter.create_concurrency.value}",
    SCALETEST_PARAM_CLEANUP_STRATEGY : data.coder_parameter.cleanup_strategy.value,
    SCALETEST_PARAM_LOAD_SCENARIOS : data.coder_parameter.load_scenarios.value,
    SCALETEST_PARAM_LOAD_SCENARIO_SSH_TRAFFIC_DURATION : "${data.coder_parameter.load_scenario_ssh_traffic_duration.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_SSH_TRAFFIC_BYTES_PER_TICK : "${data.coder_parameter.load_scenario_ssh_bytes_per_tick.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_SSH_TRAFFIC_TICK_INTERVAL : "${data.coder_parameter.load_scenario_ssh_tick_interval.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_WEB_TERMINAL_TRAFFIC_DURATION : "${data.coder_parameter.load_scenario_web_terminal_traffic_duration.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_WEB_TERMINAL_TRAFFIC_BYTES_PER_TICK : "${data.coder_parameter.load_scenario_web_terminal_bytes_per_tick.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_WEB_TERMINAL_TRAFFIC_TICK_INTERVAL : "${data.coder_parameter.load_scenario_web_terminal_tick_interval.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_DASHBOARD_TRAFFIC_DURATION : "${data.coder_parameter.load_scenario_dashboard_traffic_duration.value}",
    SCALETEST_PARAM_LOAD_SCENARIO_BASELINE_DURATION : "${data.coder_parameter.load_scenario_baseline_duration.value}",

    GRAFANA_URL : local.grafana_url,

    SCRIPTS_ZIP : filebase64(data.archive_file.scripts_zip.output_path),
    SCRIPTS_DIR : "/tmp/scripts",
  }
  display_apps {
    vscode     = false
    ssh_helper = false
  }
  startup_script_timeout  = 86400
  shutdown_script_timeout = 7200
  startup_script_behavior = "blocking"
  startup_script          = file("startup.sh")
  shutdown_script         = file("shutdown.sh")

  # IDEA(mafredri): It would be pretty cool to define metadata to expect JSON output, each field/item could become a separate metadata item.
  # Scaletest metadata.
  metadata {
    display_name = "Scaletest status"
    key          = "00_scaletest_status"
    script       = file("metadata_status.sh")
    interval     = 1
    timeout      = 1
  }

  metadata {
    display_name = "Scaletest phase"
    key          = "01_scaletest_phase"
    script       = file("metadata_phase.sh")
    interval     = 1
    timeout      = 1
  }

  metadata {
    display_name = "Scaletest phase (previous)"
    key          = "02_scaletest_previous_phase"
    script       = file("metadata_previous_phase.sh")
    interval     = 1
    timeout      = 1
  }

  # Misc workspace metadata.
  metadata {
    display_name = "CPU Usage"
    key          = "80_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "81_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Home Disk"
    key          = "82_home_disk"
    script       = "coder stat disk --path $${HOME}"
    interval     = 60
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "83_cpu_usage_host"
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage (Host)"
    key          = "84_mem_usage_host"
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "85_load_host"
    # Get load avg scaled by number of cores.
    script   = <<-EOS
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOS
    interval = 60
    timeout  = 1
  }
}

module "code-server" {
  source          = "https://registry.coder.com/modules/code-server"
  agent_id        = coder_agent.main.id
  install_version = "4.8.3"
  folder          = local.scaletest_run_dir
}

module "filebrowser" {
  source   = "https://registry.coder.com/modules/filebrowser"
  agent_id = coder_agent.main.id
  folder   = local.scaletest_run_dir
}

resource "coder_app" "grafana" {
  agent_id     = coder_agent.main.id
  slug         = "00-grafana"
  display_name = "Grafana"
  url          = "${local.grafana_url}/d/${local.grafana_dashboard_uid}/${local.grafana_dashboard_name}?orgId=1&from=${time_static.start_time.unix * 1000}&to=now"
  icon         = "https://grafana.com/static/assets/img/fav32.png"
  external     = true
}

resource "coder_app" "prometheus" {
  agent_id     = coder_agent.main.id
  slug         = "01-prometheus"
  display_name = "Prometheus"
  // https://stats.dev.c8s.io:9443/classic/graph?g0.range_input=2h&g0.end_input=2023-09-08%2015%3A58&g0.stacked=0&g0.expr=rate(pg_stat_database_xact_commit%7Bcluster%3D%22big%22%2Cdatname%3D%22big-coder%22%7D%5B1m%5D)&g0.tab=0
  url      = "https://stats.dev.c8s.io:9443"
  icon     = "https://prometheus.io/assets/favicons/favicon-32x32.png"
  external = true
}

resource "coder_app" "manual_cleanup" {
  agent_id     = coder_agent.main.id
  slug         = "02-manual-cleanup"
  display_name = "Manual cleanup"
  icon         = "/emojis/1f9f9.png"
  command      = "/tmp/scripts/cleanup.sh manual"
}

resource "kubernetes_persistent_volume_claim" "home" {
  depends_on = [null_resource.permission_check]
  metadata {
    name      = "${local.workspace_pod_name}-home"
    namespace = data.coder_parameter.namespace.value
    labels = {
      "app.kubernetes.io/name"     = "coder-pvc"
      "app.kubernetes.io/instance" = "coder-pvc-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      // Coder specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace.me.owner_id
      "com.coder.user.username"  = data.coder_workspace.me.owner
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace.me.owner_email
    }
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${local.home_disk_size}Gi"
      }
    }
  }
}

resource "kubernetes_pod" "main" {
  depends_on = [null_resource.permission_check]
  count      = data.coder_workspace.me.start_count
  metadata {
    name      = local.workspace_pod_name
    namespace = data.coder_parameter.namespace.value
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = local.workspace_pod_instance
      "app.kubernetes.io/part-of"  = "coder"
      // Coder specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace.me.owner_id
      "com.coder.user.username"  = data.coder_workspace.me.owner
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace.me.owner_email
    }
  }
  # Set the pod delete timeout to termination_grace_period_seconds + 1m.
  timeouts {
    delete = "${(local.workspace_pod_termination_grace_period_seconds + 120) / 60}s"
  }
  spec {
    security_context {
      run_as_user = "1000"
      fs_group    = "1000"
    }

    # Allow this pod to perform scale tests.
    service_account_name = local.service_account_name

    # Allow the coder agent to perform graceful shutdown and cleanup of
    # scaletest resources. We add an extra minute so ensure work
    # completion is prioritized over timeout.
    termination_grace_period_seconds = local.workspace_pod_termination_grace_period_seconds + 60

    container {
      name              = "dev"
      image             = "gcr.io/coder-dev-1/scaletest-runner:latest"
      image_pull_policy = "Always"
      command           = ["sh", "-c", coder_agent.main.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      env {
        name  = "CODER_AGENT_LOG_DIR"
        value = "${local.scaletest_run_dir}/logs"
      }
      env {
        name = "GRAFANA_API_TOKEN"
        value_from {
          secret_key_ref {
            name = data.kubernetes_secret.grafana_editor_api_token.metadata[0].name
            key  = "token"
          }
        }
      }
      env {
        name = "SLACK_WEBHOOK_URL"
        value_from {
          secret_key_ref {
            name = data.kubernetes_secret.slack_scaletest_notifications_webhook_url.metadata[0].name
            key  = "url"
          }
        }
      }
      resources {
        # Set requests and limits values such that we can do performant
        # execution of `coder scaletest` commands.
        requests = {
          "cpu"    = "250m"
          "memory" = "512Mi"
        }
        limits = {
          "cpu"    = "${local.cpu}"
          "memory" = "${local.memory}Gi"
        }
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
      port {
        container_port = 21112
        name           = "prometheus-http"
        protocol       = "TCP"
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }

    affinity {
      pod_anti_affinity {
        // This affinity attempts to spread out all workspace pods evenly across
        // nodes.
        preferred_during_scheduling_ignored_during_execution {
          weight = 1
          pod_affinity_term {
            topology_key = "kubernetes.io/hostname"
            label_selector {
              match_expressions {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["coder-workspace"]
              }
            }
          }
        }
      }
      node_affinity {
        required_during_scheduling_ignored_during_execution {
          node_selector_term {
            match_expressions {
              key      = "cloud.google.com/gke-nodepool"
              operator = "In"
              values   = ["big-workspacetraffic"] # Avoid placing on the same nodes as scaletest workspaces.
            }
          }
        }
      }
    }
  }
}

data "kubernetes_secret" "grafana_editor_api_token" {
  metadata {
    name      = "grafana-editor-api-token"
    namespace = data.coder_parameter.namespace.value
  }
}

data "kubernetes_secret" "slack_scaletest_notifications_webhook_url" {
  metadata {
    name      = "slack-scaletest-notifications-webhook-url"
    namespace = data.coder_parameter.namespace.value
  }
}

resource "kubernetes_manifest" "pod_monitor" {
  count = data.coder_workspace.me.start_count
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PodMonitor"
    metadata = {
      namespace = data.coder_parameter.namespace.value
      name      = "podmonitor-${local.workspace_pod_name}"
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/instance" : local.workspace_pod_instance
        }
      }
      podMetricsEndpoints = [
        {
          port     = "prometheus-http"
          interval = "15s"
        }
      ]
    }
  }
}
