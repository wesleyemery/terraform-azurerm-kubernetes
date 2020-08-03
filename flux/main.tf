resource "kubernetes_namespace" "fluxcd" {
  metadata {
    name = "fluxcd"
  }
  lifecycle {
    ignore_changes = [metadata[0].annotations,metadata[0].labels]
  }
}

###############################################################
########## This would pre-install helm-operator crds ##########
###############################################################
### data "http" "flux_helm_operator_crds" {
###   url = "https://raw.githubusercontent.com/fluxcd/helm-operator/v${var.helm_operator_crd_version}/deploy/crds.yaml"
### }
### 
### resource  "helm_release" "init_flux_crds" {
###   name  = "init-flux-helm-operator-crds"
###   chart = "${path.module}/charts/init-flux-helm-operator-crds"
### 
###   set {
###     name  = "manifest"
###     value = replace(data.http.flux_helm_operator_crds.body, ",", "\\,")
###   }
### 
###   lifecycle {
###     ignore_changes = [chart]
###   }
### }
###############################################################

resource "kubernetes_secret" "config_repo_ssh_key" {
  depends_on = [kubernetes_namespace.fluxcd]

  metadata {
    namespace = "fluxcd"
    name      = "flux-ssh"
  }
  data = {
    identity = var.config_repo_ssh_key
  }
}

resource "kubernetes_secret" "default_repo_ssh_key" {
  depends_on = [kubernetes_namespace.fluxcd]

  metadata {
    namespace = "fluxcd"
    name      = "flux-ssh-default"
  }
  data = {
    identity = var.default_ssh_key
  }
}

data "external" "ssh_host_key" {
  program = ["sh", "${path.module}/ssh_host_key.sh"]

  query = {
    url = var.config_repo_url
  }
}

resource "helm_release" "flux" {
  depends_on = [kubernetes_secret.config_repo_ssh_key]

  name             = "flux"
  namespace        = "fluxcd"

  repository = "https://charts.fluxcd.io"
  chart      = "flux"
  version    = var.flux_helm_chart_version
  skip_crds  = true

  values = [
    templatefile("${path.module}/config.yaml.tmpl", {
      flux_version       = var.flux_version
      config_repo_url    = replace(var.config_repo_url, "github.com", "config.github.com")
      config_repo_host   = replace(data.external.ssh_host_key.result["host"], "github.com", "config.github.com")
      config_repo_branch = var.config_repo_branch
      config_repo_path   = var.config_repo_path
      ssh_host_key       = data.external.ssh_host_key.result["key"]
    }),
    var.additional_yaml_config
  ]

  lifecycle {
    ignore_changes = [values,version]
  }
}
