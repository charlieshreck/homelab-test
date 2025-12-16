# ==============================================================================
# infisical.tf - Infisical Secrets Operator Configuration
#
# FIXES APPLIED:
# 1. Changed from kubectl_manifest to kubernetes_secret for better reliability
# 2. Proper dependency on CNI being ready
# 3. Added wait flags to Helm release
# ==============================================================================

# FIX: Use kubernetes_secret instead of kubectl_manifest
resource "kubernetes_namespace" "infisical" {
  depends_on = [null_resource.wait_for_cluster]
  
  metadata {
    name = "infisical-operator-system"
  }
}

resource "kubernetes_secret" "infisical_universal_auth" {
  depends_on = [kubernetes_namespace.infisical]

  metadata {
    name      = "universal-auth-credentials"
    namespace = "infisical-operator-system"
  }

  type = "Opaque"

  data = {
    clientId     = var.infisical_client_id
    clientSecret = var.infisical_client_secret
  }
}

resource "helm_release" "infisical" {
  depends_on = [kubernetes_secret.infisical_universal_auth]

  name             = "infisical-operator"
  repository       = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  chart            = "secrets-operator"
  version          = "0.10.16"
  namespace        = "infisical-operator-system"
  create_namespace = false
  wait             = false

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