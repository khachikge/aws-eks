provider "helm" {
  kubernetes {
    host                   = module.eks[0].cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = concat(["eks", "get-token", "--cluster-name", module.eks[0].cluster_name, "--output", "json"], var.argocd.extra_command_arg)
    }
  }
}

provider "kubernetes" {
  host                   = module.eks[0].cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks[0].cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = concat(["eks", "get-token", "--cluster-name", module.eks[0].cluster_name, "--output", "json"], var.argocd.extra_command_arg)
  }
}

resource "kubernetes_namespace" "argocd" {
  count = var.argocd.create && var.create ? 1 : 0
  metadata {
    name = var.argocd.namespace
  }
}

resource "kubernetes_secret" "repository_secret" {
  count = var.argocd.create && var.create ? 1 : 0
  metadata {
    name      = var.argocd.repo_credentials_configuration.secret_name
    namespace = kubernetes_namespace.argocd[0].id
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }
  data = {
    type          = "git"
    sshPrivateKey = data.aws_ssm_parameter.repo_ssh_key.value
    url           = var.argocd.repo_credentials_configuration.repo_url
  }
}

resource "helm_release" "argocd" {
  count      = var.argocd.create && var.create ? 1 : 0
  repository = var.argocd.chart_repo
  chart      = var.argocd.chart_name
  version    = var.argocd.chart_version

  name      = var.argocd.helm_release_name
  namespace = kubernetes_namespace.argocd[0].id
  values = [
    file(var.argocd.path_to_values)
  ]
}

resource "helm_release" "app_of_apps" {
  count = var.argocd.create && var.create ? 1 : 0

  depends_on = [helm_release.argocd]
  name       = var.argocd.app_of_apps.name
  repository = var.argocd.app_of_apps.chart_repo
  chart      = var.argocd.app_of_apps.chart_name
  namespace  = kubernetes_namespace.argocd[0].id
  version    = var.argocd.app_of_apps.chart_version
  values = [
    templatefile("${path.module}/templates/app_of_apps.yaml", {
      namespace      = kubernetes_namespace.argocd[0].id
      repoURL        = var.argocd.app_of_apps.repository.url
      targetRevision = var.argocd.app_of_apps.repository.targetRevision
      path           = var.argocd.app_of_apps.repository.path
      app_name       = var.argocd.app_of_apps.name
      project_name   = var.argocd.app_project_name
    })
  ]
}
