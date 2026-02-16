# Arquitectura del Cluster K3D en OVH

## Vista General

Cluster Kubernetes ligero ejecutado con **K3D** (K3s-in-Docker) sobre una VM en OVH Public Cloud, gestionado via **GitOps** con ArgoCD. Toda la infraestructura se provisiona con Terraform y se configura con Ansible, automatizado mediante GitHub Actions.

```
┌─────────────────────────────────────── INFRAESTRUCTURA ────────────────────────────────────────┐
│                                                                                                │
│  GitHub Actions (CI/CD)              GCP (Terraform State)                                     │
│  ├── terraform-plan/apply            └── GCS Backend                                          │
│  ├── deploy-apps                                                                               │
│  └── build-event-logger ──► GHCR (ghcr.io/usuario/event-logger)                              │
│         │                                                                                      │
└─────────┼──────────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────── OVH PUBLIC CLOUD ───────────────────────────────────────┐
│  VM b2-7 (4 vCPU, 7GB RAM) · Ubuntu 22.04 · IP: 51.255.12.10 · Region: GRA11                │
│  UFW: 22, 80, 443                                                                             │
│                                                                                                │
│  Docker Engine                                                                                 │
│  └── K3D Cluster "k3d-cluster" (K3s v1.31.5 in Docker)                                       │
│      ├── k3d-k3d-cluster-server-0 (control plane)                                             │
│      ├── k3d-k3d-cluster-agent-0  (worker)                                                    │
│      └── k3d-k3d-cluster-serverlb (ports 80/443 → host)                                      │
│                                                                                                │
│  ┌─────────────────────────────── NAMESPACES DEL CLUSTER ────────────────────────────────┐    │
│  │                                                                                        │    │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────┐  │    │
│  │  │  argocd                                                                          │  │    │
│  │  │  ArgoCD v2.9.5 (GitOps CD)                                                      │  │    │
│  │  │  http://argocd.51.255.12.10.nip.io                                              │  │    │
│  │  │  Gestiona 8 Applications desde Git                                               │  │    │
│  │  └───────────────────────────────┬──────────────────────────────────────────────────┘  │    │
│  │                                  │ sync                                                │    │
│  │          ┌───────────────────────┼───────────────────────┐                            │    │
│  │          ▼                       ▼                       ▼                            │    │
│  │  ┌──────────────┐    ┌───────────────────┐    ┌──────────────────┐                   │    │
│  │  │  kyverno     │    │  keda             │    │  nats            │                   │    │
│  │  │  v3.3.4      │    │  v2.19.0          │    │  v1.2.4          │                   │    │
│  │  │              │    │                   │    │  JetStream       │                   │    │
│  │  │  ClusterPolicy    │  ScaledObjects:   │    │  Stream: EVENTS  │                   │    │
│  │  │  genera      │    │  - cron (horario) │    │  PVC 2Gi         │                   │    │
│  │  │  ScaledObjects    │  - nats (eventos) │    │  :4222 / :8222   │                   │    │
│  │  └──────┬───────┘    └────────┬──────────┘    └────────┬─────────┘                   │    │
│  │         │ generate            │ scale                  │ consume/publish              │    │
│  │         ▼                     ▼                        ▼                              │    │
│  │  ┌─────────────────────────────────────────────────────────────────────────────────┐  │    │
│  │  │                        MICROSERVICIOS                                           │  │    │
│  │  │                                                                                 │  │    │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────────┐ │  │    │
│  │  │  │  nginx-demo     │  │  uptime-kuma    │  │  event-logger                  │ │  │    │
│  │  │  │  ns: nginx-demo │  │  ns: uptime-kuma│  │  ns: event-logger              │ │  │    │
│  │  │  │                 │  │                 │  │                                 │ │  │    │
│  │  │  │  nginx:1.25.4   │  │  uptime-kuma:1  │  │  Go app (GHCR)                │ │  │    │
│  │  │  │  NodePort:30080 │  │  Ingress:uptime.│  │  Ingress:events.               │ │  │    │
│  │  │  │                 │  │  PVC 2Gi        │  │                                 │ │  │    │
│  │  │  │  KEDA cron:     │  │  KEDA cron:     │  │  KEDA nats-jetstream:          │ │  │    │
│  │  │  │  L-V 8-20h → 2 │  │  L-V 8-20h → 1 │  │  lag > 10 → 1-5 replicas      │ │  │    │
│  │  │  │  resto   → 0   │  │  resto   → 0    │  │  siempre min 1 replica         │ │  │    │
│  │  │  └─────────────────┘  └─────────────────┘  └─────────────────────────────────┘ │  │    │
│  │  └─────────────────────────────────────────────────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                                │
│  Traefik (Ingress Controller - incluido en K3D)                                               │
│  *.51.255.12.10.nip.io → argocd / uptime / events                                            │
└────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Infraestructura (Terraform)

**Directorio:** `cluster/providers/ovh/terraform/`

| Recurso | Detalle |
|---------|---------|
| Proveedor cloud | OVH Public Cloud (OpenStack) |
| Region | GRA11 |
| VM | 1x `b2-7` (4 vCPU, 7GB RAM) |
| OS | Ubuntu 22.04 |
| Red | Ext-Net (IP publica) |
| SSH Keypair | `k3d-cluster-keypair` |
| State backend | GCP (via Workload Identity) |

**Cloud-init** instala Docker, configura UFW (puertos 22, 80, 443) y anade el usuario `ubuntu` al grupo docker.

## Configuracion (Ansible)

**Directorio:** `cluster/providers/ovh/ansible/`

### Roles

| Rol | Funcion |
|-----|---------|
| `docker` | Instala docker.io y docker-compose, habilita servicio, anade usuario al grupo docker |
| `k3d` | Instala k3d CLI y kubectl, crea cluster K3D con port mapping 80:80 y 443:443, configura kubeconfig |
| `argocd` | Instala ArgoCD v2.9.5, configura modo insecure (HTTP) para Traefik, expone como LoadBalancer |

### Playbooks (ejecucion secuencial)

1. `k3s-install.yml` - Ejecuta roles docker + k3d
2. `cluster-config.yml` - Verifica nodos del cluster K3D
3. `argocd-install.yml` - Instala ArgoCD

## Namespaces y Aplicaciones

```
K3D Cluster
├── argocd          ArgoCD (GitOps CD)
├── nats            NATS JetStream (mensajeria)
├── keda            KEDA (autoscaling por eventos y cron)
├── kyverno         Kyverno (policy engine - genera ScaledObjects)
├── nginx-demo      Nginx demo page
├── uptime-kuma     Uptime Kuma (monitoring)
└── event-logger    Event Logger (microservicio Go)
```

### ArgoCD (namespace: `argocd`)

- **Version:** v2.9.5
- **Funcion:** Continuous Delivery GitOps. Monitorea este repositorio Git y sincroniza automaticamente los manifiestos de Kubernetes con el cluster.
- **Acceso:** http://argocd.51.255.12.10.nip.io (admin / password en secret `argocd-initial-admin-secret`)
- **Configuracion:** Modo insecure (HTTP) para funcionar detras de Traefik. Servicio tipo LoadBalancer.
- **Apps gestionadas:** nats, keda, kyverno, kyverno-policies, nginx-demo, uptime-kuma, event-logger

### NATS JetStream (namespace: `nats`)

- **Chart:** nats v1.2.4 (https://nats-io.github.io/k8s/helm/charts/)
- **Funcion:** Sistema de mensajeria con persistencia (JetStream). Actua como event broker entre el endpoint HTTP de publicacion y los consumers.
- **Configuracion:**
  - JetStream habilitado con file storage (PVC 2Gi)
  - Monitoring HTTP en puerto 8222 (requerido por KEDA)
  - nats-box habilitado (pod utilitario para debug)
- **Stream:** `EVENTS` — subjects `events.>`, retencion 24h, file storage
- **Recursos:** 50m/128Mi (requests) — 250m/256Mi (limits)

### KEDA (namespace: `keda`)

- **Chart:** keda v2.19.0 (https://kedacore.github.io/charts)
- **Funcion:** Kubernetes Event-Driven Autoscaler. Escala pods automaticamente basandose en metricas externas. En este cluster, monitorea el consumer lag de NATS JetStream para escalar event-logger.
- **Configuracion:**
  - Sync via ServerSideApply (CRDs exceden el limite de 262144 bytes de client-side apply)
  - Recursos operator: 50m/128Mi (requests) — 250m/256Mi (limits)
- **ScaledObjects:**
  - **event-logger** (NATS): Monitorea stream `EVENTS`, consumer `event-logger`, lag threshold 10 mensajes. Escala de 1 a 5 replicas con polling cada 5s y cooldown de 30s.
  - **nginx-demo-cron** (Cron): Generado automaticamente por Kyverno. Escala a 2 replicas L-V 08:00-20:00, 0 fuera de horario.
  - **uptime-kuma-cron** (Cron): Generado automaticamente por Kyverno. Escala a 1 replica L-V 08:00-20:00, 0 fuera de horario.

### Kyverno (namespace: `kyverno`)

- **Chart:** kyverno v3.3.4 (https://kyverno.github.io/kyverno/)
- **Funcion:** Policy engine para Kubernetes. En este cluster, genera automaticamente ScaledObjects de KEDA con trigger cron para cualquier Deployment que tenga el label `keda/cron-schedule: "business-hours"`.
- **Configuracion:**
  - Sync via ServerSideApply (CRDs grandes)
  - 1 replica del admission controller
  - RBAC custom para gestionar recursos `keda.sh/ScaledObject` (ClusterRole + ClusterRoleBinding)
- **Recursos:** admissionController 100m/256Mi - backgroundController 50m/128Mi
- **ClusterPolicy:** `generate-keda-cron-scaledobject` — detecta Deployments con label y genera ScaledObject con `generateExisting: true` y `synchronize: true`

### Nginx Demo (namespace: `nginx-demo`)

- **Chart:** local (`cluster/apps/nginx-demo/`)
- **Funcion:** Pagina web estatica de demostracion. Sirve una landing page HTML personalizada con tema oscuro.
- **Configuracion:**
  - 2 replicas de nginx:1.25.4-alpine
  - Servicio NodePort en puerto 30080
  - HTML custom via ConfigMap
- **Recursos:** 50m/64Mi (requests) — 100m/128Mi (limits)

### Uptime Kuma (namespace: `uptime-kuma`)

- **Chart:** local (`cluster/apps/uptime-kuma/`)
- **Funcion:** Herramienta de monitoring de uptime. Permite configurar checks HTTP/TCP/Ping contra servicios y visualizar su disponibilidad.
- **Acceso:** http://uptime.51.255.12.10.nip.io
- **Configuracion:**
  - 1 replica de louislam/uptime-kuma:1
  - PVC 2Gi para persistencia de datos
  - Ingress via Traefik
- **Recursos:** 50m/128Mi (requests) — 200m/256Mi (limits)

### Event Logger (namespace: `event-logger`)

- **Chart:** local (`cluster/apps/event-logger/`)
- **Funcion:** Microservicio Go que publica y consume eventos via NATS JetStream. Expone una API HTTP para publicar eventos y consultarlos.
- **Acceso:** http://events.51.255.12.10.nip.io
- **Codigo fuente:** `services/event-logger/` (Go)
- **Endpoints:**
  - `POST /publish` — Publica un evento al stream NATS (`{"name": "...", "data": "..."}`)
  - `GET /events` — Lista los ultimos 100 eventos consumidos
  - `GET /health` — Health check (estado NATS)
- **Configuracion:**
  - Imagen: `ghcr.io/usuario/event-logger:latest`
  - Conecta a NATS en `nats://nats.nats.svc.cluster.local:4222`
  - Consumer durable `event-logger` en stream `EVENTS`
  - KEDA ScaledObject para autoscaling (1-5 replicas)
- **Recursos:** 25m/64Mi (requests) — 100m/128Mi (limits)

## Flujo de Datos (Event-Driven)

```
Cliente HTTP
    │
    ▼ POST /publish
┌──────────────┐     publish      ┌──────────────┐
│ event-logger │ ──────────────►  │    NATS      │
│   (Go app)   │                  │  JetStream   │
│              │ ◄────────────── │  Stream:     │
│              │    consume       │  EVENTS      │
└──────────────┘                  └──────────────┘
       ▲                                 │
       │ scale 1-5                       │ monitor lag
       │                                 ▼
┌──────────────┐              ┌──────────────────┐
│    KEDA      │ ◄─────────── │  NATS Monitoring │
│  Operator    │   HTTP :8222  │   (port 8222)   │
└──────────────┘              └──────────────────┘
```

## Networking

| Servicio | URL | Puerto interno |
|----------|-----|----------------|
| ArgoCD | http://argocd.51.255.12.10.nip.io | 80 |
| Uptime Kuma | http://uptime.51.255.12.10.nip.io | 3001 |
| Event Logger | http://events.51.255.12.10.nip.io | 8080 |
| Nginx Demo | NodePort :30080 | 80 |
| NATS | ClusterIP (interno) | 4222 |
| NATS Monitoring | ClusterIP (interno) | 8222 |

**Ingress Controller:** Traefik (incluido en K3D por defecto). Los Ingress usan `nip.io` para resolucion DNS basada en IP.

## CI/CD Workflows (GitHub Actions)

| Workflow | Trigger | Funcion |
|----------|---------|---------|
| `ovh-k3s-cluster-deploy.yml` | Manual (plan/apply/destroy/clean) | Provisiona VM con Terraform + configura con Ansible |
| `deploy-apps.yml` | Push a `cluster/apps/**` o manual | Copia manifiestos ArgoCD al cluster via SSH |
| `build-event-logger.yml` | Push a `services/event-logger/**` | Build y push de imagen Docker a GHCR |
| `terraform-plan.yml` | PR a main | Terraform fmt + validate + plan (comenta en PR) |
| `terraform-apply.yml` | Push a main | Terraform apply automatico |
| `terraform-destroy.yml` | Manual (requiere confirmacion) | Terraform destroy |
| `verify-cluster.yml` | Manual | Health check: nodos, pods, ArgoCD, NATS, KEDA |
| `debug-keda.yml` | Manual | Diagnostico KEDA: logs, pods, ScaledObject |
| `fix-argocd.yml` | Manual | Parcha ArgoCD a modo insecure + restart |
| `cleanup-keypair.yml` | Manual | Elimina SSH keypair de OpenStack |
| `test-openstack-auth.yml` | Manual | Valida credenciales OpenStack |

## Autoscaling por Horario (Ahorro de Costes)

### Objetivo

Escalar a 0 replicas los microservicios del entorno de desarrollo fuera del horario laboral para ahorrar costes:
- **Lunes a Viernes 08:00 - 20:00** (Europe/Madrid): replicas activas
- **Lunes a Viernes 20:00 - 08:00**: 0 replicas
- **Sabados y Domingos**: 0 replicas las 24 horas

### Arquitectura

```
┌──────────────────── FLUJO DE AUTOSCALING ─────────────────────┐
│                                                                │
│  Deployment                                                    │
│  + label: keda/cron-schedule: "business-hours"                │
│  + annotation: keda/desired-replicas: "2"                     │
│  + annotation: keda/timezone: "Europe/Madrid"                 │
│         │                                                      │
│         ▼                                                      │
│  Kyverno (ClusterPolicy)                                      │
│  generate-keda-cron-scaledobject                              │
│         │                                                      │
│         ▼ genera automaticamente                              │
│  ScaledObject (KEDA)                                          │
│  trigger: cron                                                │
│  start: "0 8 * * 1-5"  end: "0 20 * * 1-5"                  │
│         │                                                      │
│         ▼                                                      │
│  ┌────────────────────────────────────────┐                   │
│  │ L-V 08:00-20:00  → desiredReplicas    │                   │
│  │ L-V 20:00-08:00  → 0 replicas         │                   │
│  │ Sab-Dom          → 0 replicas         │                   │
│  └────────────────────────────────────────┘                   │
└────────────────────────────────────────────────────────────────┘
```

### Componentes

| Componente | Funcion |
|------------|---------|
| **KEDA** (v2.19.0) | Operator de autoscaling. Ejecuta los ScaledObjects con trigger `cron` |
| **Kyverno** (v3.3.4) | Policy engine. Genera automaticamente el ScaledObject cuando detecta el label |
| **ClusterPolicy** | Regla `generate-keda-cron-scaledobject` que crea ScaledObjects para Deployments etiquetados |

### Como funciona el trigger cron

```yaml
triggers:
  - type: cron
    metadata:
      timezone: "Europe/Madrid"
      start: "0 8 * * 1-5"    # 08:00 Lunes a Viernes
      end: "0 20 * * 1-5"     # 20:00 Lunes a Viernes
      desiredReplicas: "2"     # Replicas durante horario activo
```

- `minReplicaCount: 0` — fuera de cualquier trigger activo, KEDA escala a 0
- No hay trigger para sabados/domingos, por lo que aplica el minimo (0)

### Estado actual de los ScaledObjects

| Namespace | ScaledObject | Trigger | Min | Max | Replicas activas |
|-----------|-------------|---------|-----|-----|-----------------|
| event-logger | event-logger | nats-jetstream | 1 | 5 | 1-5 (segun carga NATS) |
| nginx-demo | nginx-demo-cron | cron | 0 | 10 | 2 (L-V 8-20h) / 0 (resto) |
| uptime-kuma | uptime-kuma-cron | cron | 0 | 10 | 1 (L-V 8-20h) / 0 (resto) |

**Nota:** event-logger NO tiene escalado cron. Su `minReplicaCount: 1` con trigger NATS garantiza al menos 1 replica siempre activa. KEDA no permite dos ScaledObjects para el mismo Deployment.

### Como anadir un nuevo microservicio al autoscaling

Solo hay que anadir el label y las annotations al Deployment. Kyverno genera el ScaledObject automaticamente:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mi-microservicio
  labels:
    keda/cron-schedule: "business-hours"    # Activa la policy de Kyverno
  annotations:
    keda/desired-replicas: "2"              # Replicas en horario laboral
    keda/timezone: "Europe/Madrid"          # Zona horaria
```

Para Helm charts, usar values.yaml:

```yaml
keda:
  enabled: true
  desiredReplicas: "2"
  timezone: "Europe/Madrid"
```

### Ficheros clave del autoscaling

| Fichero | Contenido |
|---------|-----------|
| `cluster/apps/argocd-apps/kyverno-app.yaml` | ArgoCD Application — instala Kyverno via Helm |
| `cluster/apps/argocd-apps/kyverno-policies-app.yaml` | ArgoCD Application — sincroniza las policies desde Git |
| `cluster/apps/kyverno-policies/generate-keda-cron-scaledobject.yaml` | ClusterPolicy que genera ScaledObjects |
| `cluster/apps/kyverno-policies/kyverno-keda-rbac.yaml` | ClusterRole + ClusterRoleBinding para permisos KEDA |

## Problemas Encontrados y Soluciones

### 1. Helm interpreta variables de Kyverno como templates

**Problema:** Al colocar la ClusterPolicy dentro de un Helm chart (`Chart.yaml` + `templates/`), ArgoCD ejecuta `helm template` que interpreta los `{{request.object.metadata.name}}` de Kyverno como expresiones de Helm, causando: `function "request" not defined`.

**Solucion:** Eliminar `Chart.yaml` y mover el manifiesto fuera del directorio `templates/`. ArgoCD lo trata como YAML crudo (tipo `Directory`) y no ejecuta `helm template`.

**Commit:** `bb58547` — Fix kyverno-policies: use raw manifests instead of Helm chart

### 2. Kyverno sin permisos para crear ScaledObjects de KEDA

**Problema:** El admission webhook de Kyverno rechaza la ClusterPolicy porque el ServiceAccount `kyverno-admission-controller` no tiene permisos `list,get` sobre el recurso `keda.sh/v1alpha1/ScaledObject`: `system:serviceaccount:kyverno:kyverno-admission-controller requires permissions list,get for resource keda.sh/v1alpha1/ScaledObject`.

**Solucion:** Crear un ClusterRole con permisos completos (get, list, watch, create, update, patch, delete) sobre `scaledobjects` del apiGroup `keda.sh`, y vincularlo a ambos ServiceAccounts de Kyverno (admission-controller y background-controller) via ClusterRoleBinding.

**Commit:** `c0b0549` — Add RBAC permissions for Kyverno to manage KEDA ScaledObjects

### 3. Kyverno no genera ScaledObjects para Deployments preexistentes

**Problema:** Las reglas `generate` de Kyverno solo se activan via admission webhook (cuando se crea o actualiza un recurso). Los Deployments de nginx-demo y uptime-kuma existian antes de crear la ClusterPolicy, por lo que Kyverno no generaba los ScaledObjects.

**Solucion:** Anadir `generateExisting: true` a la regla `generate` de la ClusterPolicy. Esto indica a Kyverno (via el background controller) que tambien procese recursos que ya existian cuando la policy fue creada.

**Commit:** `47ca755` — Fix Kyverno policy: add generateExisting for pre-existing Deployments

## Estructura de Ficheros

```
terraform/
├── .github/workflows/          # 12 workflows de CI/CD
├── cluster/
│   ├── apps/
│   │   ├── argocd-apps/        # Manifiestos ArgoCD Application
│   │   │   ├── argocd-ingress.yaml
│   │   │   ├── event-logger-app.yaml
│   │   │   ├── keda-app.yaml
│   │   │   ├── kyverno-app.yaml
│   │   │   ├── kyverno-policies-app.yaml
│   │   │   ├── nats-app.yaml
│   │   │   ├── nginx-demo-app.yaml
│   │   │   └── uptime-kuma-app.yaml
│   │   ├── kyverno-policies/    # Manifiestos Kyverno (YAML crudo, no Helm)
│   │   │   ├── generate-keda-cron-scaledobject.yaml  # ClusterPolicy
│   │   │   └── kyverno-keda-rbac.yaml                # RBAC para KEDA
│   │   ├── event-logger/       # Helm chart local
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   │       ├── deployment.yaml
│   │   │       ├── service.yaml
│   │   │       ├── ingress.yaml
│   │   │       └── scaledobject.yaml   # KEDA autoscaling
│   │   ├── nginx-demo/         # Helm chart local
│   │   │   ├── Chart.yaml
│   │   │   ├── values.yaml
│   │   │   └── templates/
│   │   └── uptime-kuma/        # Helm chart local
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       └── templates/
│   └── providers/ovh/
│       ├── terraform/
│       │   ├── compute.tf       # VM + keypair
│       │   ├── providers.tf     # OVH + OpenStack
│       │   ├── variables.tf     # Variables input
│       │   ├── versions.tf      # Versiones providers
│       │   ├── outputs.tf       # Inventario Ansible
│       │   ├── terraform.tfvars # Valores
│       │   └── templates/
│       │       └── cloud-init-master.tpl
│       └── ansible/
│           ├── ansible.cfg
│           ├── playbooks/
│           │   ├── k3s-install.yml
│           │   ├── cluster-config.yml
│           │   ├── argocd-install.yml
│           │   └── argocd-apps-bootstrap.yml
│           └── roles/
│               ├── docker/      # Instalacion Docker
│               ├── k3d/         # Instalacion K3D + cluster
│               └── argocd/      # Instalacion ArgoCD
├── services/
│   └── event-logger/            # Codigo fuente Go
│       ├── main.go
│       ├── go.mod
│       └── Dockerfile
└── docs/
    └── architecture.md          # Este documento
```

## Secrets de GitHub Requeridos

| Secret | Uso |
|--------|-----|
| `OVH_ENDPOINT` | API OVH (ovh-eu) |
| `OVH_APPLICATION_KEY` | Credencial API OVH |
| `OVH_APPLICATION_SECRET` | Credencial API OVH |
| `OVH_CONSUMER_KEY` | Credencial API OVH |
| `OPENSTACK_TENANT_ID` | Proyecto OpenStack |
| `OPENSTACK_USERNAME` | Usuario OpenStack |
| `OPENSTACK_PASSWORD` | Password OpenStack |
| `OVH_SSH_PUBLIC_KEY` | Clave publica SSH para VMs |
| `OVH_SSH_PRIVATE_KEY` | Clave privada SSH (Ansible + deploy) |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Backend state Terraform (GCS) |
| `GCP_SERVICE_ACCOUNT` | Service account GCP |
| `K3S_MASTER_IP` | IP de la VM (51.255.12.10) |

## Flujo de Despliegue Completo

```
1. terraform apply
   └── Crea VM en OVH con Docker (cloud-init)

2. Ansible playbooks (secuencial)
   ├── docker role   → Verifica Docker instalado
   ├── k3d role      → Crea cluster K3D (1 server + 1 agent)
   └── argocd role   → Instala ArgoCD v2.9.5

3. deploy-apps workflow
   └── Copia manifiestos ArgoCD Application al cluster

4. ArgoCD auto-sync
   ├── nats-app            → Helm chart NATS JetStream
   ├── keda-app            → Helm chart KEDA operator
   ├── kyverno-app         → Helm chart Kyverno policy engine
   ├── kyverno-policies-app → RBAC + ClusterPolicy (YAML crudo)
   ├── nginx-demo-app      → Chart local nginx (con label keda/cron-schedule)
   ├── uptime-kuma-app     → Chart local uptime-kuma (con label keda/cron-schedule)
   └── event-logger-app    → Chart local event-logger + ScaledObject NATS

5. Kyverno auto-generate
   └── Detecta Deployments con label keda/cron-schedule
       ├── nginx-demo-cron    → ScaledObject cron (0 → 2 replicas)
       └── uptime-kuma-cron   → ScaledObject cron (0 → 1 replica)
```
