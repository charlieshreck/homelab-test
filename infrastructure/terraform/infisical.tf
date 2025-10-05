resource "kubernetes_namespace" "infisical" {
  depends_on = [null_resource.wait_for_cilium]
  
  metadata {
    name = "infisical-operator-system"
  }
}

resource "kubectl_manifest" "infisical_universal_auth" {
  depends_on = [kubernetes_namespace.infisical]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "universal-auth-credentials"
      namespace = "infisical-operator-system"
    }
    type = "Opaque"
    stringData = {
      clientId     = "26428618-6807-4a12-a461-33242ec1af50"
      clientSecret = "8176c36e0e932f660327236ad288cfb1edbbced739d9c2d074d8cedabf492ee3"
    }
  })
}

resource "helm_release" "infisical" {
  depends_on = [kubectl_manifest.infisical_universal_auth]
  
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