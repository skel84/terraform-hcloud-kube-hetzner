# Cluster config
variable "cluster_name" {
  type        = string
  default     = "k3s"
  description = "Name of the cluster."

  validation {
    condition     = can(regex("^[a-z0-9\\-]+$", var.cluster_name))
    error_message = "The cluster name must be in the form of lowercase alphanumeric characters and/or dashes."
  }
}

variable "base_domain" {
  type        = string
  default     = ""
  description = "Base domain of the cluster, used for reserve dns."

  validation {
    condition     = can(regex("^(?:(?:(?:[A-Za-z0-9])|(?:[A-Za-z0-9](?:[A-Za-z0-9\\-]+)?[A-Za-z0-9]))+(\\.))+([A-Za-z]{2,})([\\/?])?([\\/?][A-Za-z0-9\\-%._~:\\/?#\\[\\]@!\\$&\\'\\(\\)\\*\\+,;=]+)?$", var.base_domain)) || var.base_domain == ""
    error_message = "It must be a valid domain name (FQDN)."
  }
}

variable "enable_metrics_server" {
  type        = bool
  default     = true
  description = "Whether to enable or disable k3s metric server."
}

variable "create_kubeconfig" {
  type        = bool
  default     = true
  description = "Create the kubeconfig as a local file resource. Should be disabled for automatic runs."
}

variable "create_kustomization" {
  type        = bool
  default     = true
  description = "Create the kustomization backup as a local file resource. Should be disabled for automatic runs."
}

variable "export_values" {
  type        = bool
  default     = false
  description = "Export for deployment used values.yaml-files as local files."
}

variable "additional_tls_sans" {
  description = "Additional TLS SANs to allow connection to control-plane through it."
  default     = []
  type        = list(string)
}

# Hetzner CCM config
variable "hetzner_ccm_version" {
  type        = string
  default     = null
  description = "Version of Kubernetes Cloud Controller Manager for Hetzner Cloud."
}

variable "agent_nodes_custom_config" {
  type        = any
  default     = {}
  description = "Custom agent nodes configuration."
}

variable "disable_kube_proxy" {
  type        = bool
  default     = false
  description = "Disable kube-proxy in K3s (default false)."
}

variable "control_plane_nodepools" {
  description = "Number of control plane nodes."
  type = list(object({
    name                       = string
    server_type                = string
    location                   = string
    backups                    = optional(bool)
    labels                     = list(string)
    taints                     = list(string)
    count                      = number
    swap_size                  = optional(string, "")
    zram_size                  = optional(string, "")
    kubelet_args               = optional(list(string), ["kube-reserved=cpu=250m,memory=1500Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"])
    selinux                    = optional(bool, true)
    placement_group_compat_idx = optional(number, 0)
    placement_group            = optional(string, null)
  }))
  default = []
  validation {
    condition = length(
      [for control_plane_nodepool in var.control_plane_nodepools : control_plane_nodepool.name]
      ) == length(
      distinct(
        [for control_plane_nodepool in var.control_plane_nodepools : control_plane_nodepool.name]
      )
    )
    error_message = "Names in control_plane_nodepools must be unique."
  }
}

variable "agent_nodepools" {
  description = "Number of agent nodes."
  type = list(object({
    name                       = string
    server_type                = string
    location                   = string
    backups                    = optional(bool)
    floating_ip                = optional(bool)
    labels                     = list(string)
    taints                     = list(string)
    longhorn_volume_size       = optional(number)
    swap_size                  = optional(string, "")
    zram_size                  = optional(string, "")
    kubelet_args               = optional(list(string), ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"])
    selinux                    = optional(bool, true)
    placement_group_compat_idx = optional(number, 0)
    placement_group            = optional(string, null)
    count                      = optional(number, null)
    nodes = optional(map(object({
      server_type                = optional(string)
      location                   = optional(string)
      backups                    = optional(bool)
      floating_ip                = optional(bool)
      labels                     = optional(list(string))
      taints                     = optional(list(string))
      longhorn_volume_size       = optional(number)
      swap_size                  = optional(string, "")
      zram_size                  = optional(string, "")
      kubelet_args               = optional(list(string), ["kube-reserved=cpu=50m,memory=300Mi,ephemeral-storage=1Gi", "system-reserved=cpu=250m,memory=300Mi"])
      selinux                    = optional(bool, true)
      placement_group_compat_idx = optional(number, 0)
      placement_group            = optional(string, null)
      append_index_to_node_name  = optional(bool, true)
    })))
  }))
  default = []

  validation {
    condition = length(
      [for agent_nodepool in var.agent_nodepools : agent_nodepool.name]
      ) == length(
      distinct(
        [for agent_nodepool in var.agent_nodepools : agent_nodepool.name]
      )
    )
    error_message = "Names in agent_nodepools must be unique."
  }

  validation {
    condition     = alltrue([for agent_nodepool in var.agent_nodepools : (agent_nodepool.count == null) != (agent_nodepool.nodes == null)])
    error_message = "Set either nodes or count per agent_nodepool, not both."
  }

  validation {
    condition = alltrue([for agent_nodepool in var.agent_nodepools :
      alltrue([for agent_key, agent_node in coalesce(agent_nodepool.nodes, {}) : can(tonumber(agent_key)) && tonumber(agent_key) == floor(tonumber(agent_key)) && 0 <= tonumber(agent_key) && tonumber(agent_key) < 154])
    ])
    # 154 because the private ip is derived from tonumber(key) + 101. See private_ipv4 in agents.tf
    error_message = "The key for each individual node in a nodepool must be a stable integer in the range [0, 153] cast as a string."
  }

  validation {
    condition = sum([for agent_nodepool in var.agent_nodepools : length(coalesce(agent_nodepool.nodes, {})) + coalesce(agent_nodepool.count, 0)]) <= 100
    # 154 because the private ip is derived from tonumber(key) + 101. See private_ipv4 in agents.tf
    error_message = "Hetzner does not support networks with more than 100 servers."
  }

}
