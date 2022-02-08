# define where everything is located.
data "kubectl_file_documents" "namespace" {
  content = file("./argostuff/arcd-namespace.yaml")
}

data "kubectl_file_documents" "argocd" {
  content = file("./argostuff/argocd.yaml")
}

#data "kubectl_file_documents" "argo-app" {
#  content = file("./argostuff/argoapp.yaml")
#}






locals {
  cluster_name = "${terraform.workspace}-${var.cluster_name}"
}

#begin by deploying the cluster
resource "google_service_account" "main" {
  account_id   = "${local.cluster_name}-sa"
  display_name = "GKE Cluster ${local.cluster_name} Service Account"
}

resource "google_container_cluster" "main" {
  name               = local.cluster_name
  location           = "europe-west1"
  initial_node_count = 3
  node_config {
    service_account = google_service_account.main.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

#get cluster authorization to send kubectl orders
module "gke_auth" {
  depends_on           = [google_container_cluster.main]
  source               = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id           = "w38-eguillen"
  cluster_name         = google_container_cluster.main.name
  location             = "europe-west1"
  use_private_endpoint = false
}

#begin deploying kubectl manifests with the argo namespace, install file, and app file.
resource "kubectl_manifest" "namespace" {
  count              = length(data.kubectl_file_documents.namespace.documents)
  yaml_body          = element(data.kubectl_file_documents.namespace.documents, count.index)
  override_namespace = "argocd"
}

resource "kubectl_manifest" "argocd" {
  depends_on = [
    kubectl_manifest.namespace,
  ]
  count              = length(data.kubectl_file_documents.argocd.documents)
  yaml_body          = element(data.kubectl_file_documents.argocd.documents, count.index)
  override_namespace = "argocd"
}

#resource "kubectl_manifest" "argo-app" {
#  depends_on = [
#    kubectl_manifest.argocd,
#  ]
#  count              = length(data.kubectl_file_documents.argo-app.documents)
#  yaml_body          = element(data.kubectl_file_documents.argo-app.documents, count.index)
#  override_namespace = "argocd"
#}

resource "kubectl_manifest" "argo-app" {
  yaml_body = templatefile("./argostuff/argoapp.yaml", {
    env = terraform.workspace
  })
}