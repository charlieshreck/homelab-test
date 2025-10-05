resource "kubernetes_namespace" "infisical" {
  depends_on = [null_resource.wait_for_cilium]
  
  metadata {
    name = "infisical-operator-system"
  }
}

resource "helm_release" "infisical" {
  depends_on = [kubernetes_namespace.infisical]

  name       = "infisical-operator"
  repository = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  chart      = "secrets-operator"
  version    = "0.9.1"
  namespace  = "infisical-operator-system"

  values = [yamlencode({
    controllerManager = {
      manager = {
        image = {
          repository = "infisical/kubernetes-operator"
          tag        = "v0.9.1"
        }
      }
    }
  })]
}
