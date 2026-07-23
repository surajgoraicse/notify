terraform {
  required_providers {
    kafka = {
      source  = "Mongey/kafka"
      version = "~> 0.7"
    }
  }
}

# provider "kafka" {
#   bootstrap_servers = var.kafka_brokers
#   tls_enabled       = false
# }

# variable "kafka_brokers" {
#   type = list(string)
# }

variable "kafka_port" {
  type    = string
  default = "9092"
}

provider "kafka" {
  bootstrap_servers = ["localhost:${var.kafka_port}"]
  tls_enabled       = false
}


# ---------------------------------------------------------
# Desired state, defined once, generated for every
# channel x priority combination via for_each.
# Adding a channel or priority tier = one line change,
# not 6 new hand-written blocks.
# ---------------------------------------------------------

locals {
  channels = ["whatsapp", "sms", "email", "android_pn", "apple_pn"]

  # keep priority tiers to what you actually need separate
  # worker pools for -- don't create a topic per priority
  # level "just in case"
  priorities = ["high", "standard"]

  retry_tiers = {
    "retry-30s" = "30000"
    "retry-5m"  = "300000"
    "retry-30m" = "1800000"
  }

  # cartesian product of channels x priorities
  main_topics = {
    for pair in setproduct(local.channels, local.priorities) :
    "${pair[0]}-${pair[1]}" => {
      channel  = pair[0]
      priority = pair[1]
    }
  }

  retry_topics = {
    for pair in setproduct(local.channels, keys(local.retry_tiers)) :
    "${pair[0]}-${pair[1]}" => {
      channel = pair[0]
      tier    = pair[1]
    }
  }
}

# ---- Main channel/priority topics ----
resource "kafka_topic" "main" {
  for_each = local.main_topics

  name               = "notif.${each.value.channel}.${each.value.priority}"
  partitions         = each.value.priority == "high" ? 24 : 12
  replication_factor = 1

  config = {
    "retention.ms"        = "172800000" # 48h -- consumed fast, short replay window
    "cleanup.policy"      = "delete"
    "min.insync.replicas" = "1"
  }
}

# ---- Retry topics (fixed-delay tiers, per channel) ----
resource "kafka_topic" "retry" {
  for_each = local.retry_topics

  name               = "notif.${each.value.channel}.${each.value.tier}"
  partitions         = 6
  replication_factor = 1

  config = {
    "retention.ms"        = "172800000"
    "cleanup.policy"      = "delete"
    "min.insync.replicas" = "1"
  }
}

# ---- Dead-letter topics (one per channel, not per priority) ----
resource "kafka_topic" "dlq" {
  for_each = toset(local.channels)

  name               = "notif.${each.value}.dlq"
  partitions         = 3
  replication_factor = 1

  config = {
    "retention.ms"        = "2592000000" # 30d -- needs manual triage, keep longer
    "cleanup.policy"      = "delete"
    "min.insync.replicas" = "1"
  }
}
