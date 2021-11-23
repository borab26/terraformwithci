provider "azurerm" {
  features {}
}

resource "random_pet" "prefix" {}


resource "azurerm_resource_group" "roadtoproad" {
  name     = "roadtoproad"
  location = "Switzerland North"

  tags = {
    environment = "testtoprod"
  }
}

resource "azurerm_kubernetes_cluster" "testenvofbora" {
  name                = "testenvofbora"
  location            = azurerm_resource_group.roadtoproad.location
  resource_group_name = azurerm_resource_group.roadtoproad.name
  dns_prefix          = "borabano"

  default_node_pool {
    name            = "default"
    node_count      = 2
    vm_size         = "Standard_D2_v2"
    os_disk_size_gb = 30
  }

  service_principal {
    client_id     = var.appId
    client_secret = var.password
  }

  role_based_access_control {
    enabled = true
  }

  tags = {
    environment = "testtoprod"
  }
}

provider "kubernetes" {
  config_path           = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
resource "kubernetes_namespace" "boratestenv" {
  metadata {
    name = "boratestenv"
  }
}


resource "kubernetes_deployment" "backend" {
  metadata {
    name                = "quiz-backend-update"
    namespace           = "boratestenv"
  }
  spec {
    replicas            = 2
    selector {
      match_labels      = {
        app             = "quiz-backend-update"
      }
    }
    template {
      metadata {
          labels        = {
            app         = "quiz-backend-update"
          }
      }
      spec {
        container {
          image             = "kontetsu/backend-update:v1"
          image_pull_policy = "Always"
          name              = "quiz-backend-update"
          port {
            container_port  = 8080
            name            = "http"
            protocol        = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backendservice" {
  metadata {
    name                    = "quiz-backend-update"
    namespace               = "boratestenv"
  }

  spec {
    port {
      port                  = 8080
      protocol              = "TCP"
      target_port           = 8080
    }
    selector                = {
      app                   = "quiz-backend-update"
    }
    type                    = "ClusterIP"
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name                        = "frontend"
    namespace                   = "boratestenv"
  }
  spec {
    replicas                    = 2
    selector {
      match_labels              = {
        app                     = "frontend"
      }
    }
    template {
      metadata {
        labels                  = {
            app                 = "frontend"
        }
      }
      spec {
        container {
          image                 = "kontetsu/frontend-update:v1"
          image_pull_policy     = "Always"
          name                  = "frontend"
          port {
            container_port      = 80
            protocol            = "TCP"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name                    = "frontend"
    namespace               = "boratestenv"
  }
  spec {
    port {
      port                  = 80
      protocol              = "TCP"
      target_port           = 80
    }
    selector                = {
      app                   = "frontend"
    }
    type                    = "ClusterIP"
  }
}



  resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "3.15.2"
  namespace  = "boratestenv"
  timeout    = 300
  values = [<<EOF
controller:
  admissionWebhooks:
    enabled: false
  electionID: ingress-controller-leader-internal
  ingressClass: nginx-hello-world-namespace
  podLabels:
    app: ingress-nginx
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
  scope:
    enabled: true
rbac:
  scope: true
EOF
  ]
}
