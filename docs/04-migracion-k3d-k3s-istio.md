# Migracion K3D → K3s + Istio

## Motivo del cambio

El cluster K3D (K3s en Docker) sobre un b2-7 (2 vCPU, 7GB RAM) no tiene recursos suficientes para ejecutar Istio service mesh. Ademas, la capa Docker anade overhead innecesario (~500MB RAM) que se elimina con K3s directo.

**Objetivo**: Migrar a K3s directo sobre b2-15 (4 vCPU, 15GB RAM) con Istio como service mesh e ingress, reemplazando Traefik.

---

## Arquitectura antes / despues

### Antes (K3D + Traefik)

```
VM OVH b2-7 (2 vCPU, 7GB RAM)
│
├── Docker
│   └── K3D (K3s en contenedores)
│       ├── Traefik (ingress controller built-in)
│       ├── ArgoCD
│       ├── NATS JetStream
│       ├── Event Logger
│       ├── Uptime Kuma
│       ├── nginx-demo
│       ├── KEDA
│       └── Kyverno
│
│   Ingress: Traefik → Kubernetes Ingress resources
│   Puerto API: 6550 (K3D proxy)
```

### Despues (K3s + Istio)

```
VM OVH b2-15 (4 vCPU, 15GB RAM)
│
├── K3s (directo, sin Docker)
│   ├── Istio (service mesh + ingress)
│   │   ├── istiod (control plane)        namespace: istio-system
│   │   ├── Ingress Gateway               namespace: istio-ingress
│   │   └── Envoy sidecars (por pod)
│   ├── ArgoCD                             namespace: argocd
│   ├── NATS JetStream                     namespace: nats
│   ├── Event Logger                       namespace: event-logger
│   ├── Uptime Kuma                        namespace: uptime-kuma
│   ├── KEDA                               namespace: keda
│   └── Kyverno                            namespace: kyverno
│
│   Ingress: Istio Gateway → VirtualService resources
│   Puerto API: 6443 (K3s directo)
```

---

## Diagrama de red con Istio

```
                         ┌─────────────────────────────────────┐
                         │            INTERNET                  │
                         └──────────────┬──────────────────────┘
                                        │
                           http://events.IP.nip.io
                           http://uptime.IP.nip.io
                           http://argocd.IP.nip.io
                                        │
                         ┌──────────────▼──────────────────────┐
                         │   Istio Ingress Gateway              │
                         │   namespace: istio-ingress            │
                         │   type: LoadBalancer (:80, :443)      │
                         └──────────────┬──────────────────────┘
                                        │
                              ┌─────────┼─────────┐
                              ▼         ▼         ▼
                         Gateway → VirtualService routing
                              │         │         │
              ┌───────────────┘         │         └───────────────┐
              ▼                         ▼                         ▼
  ┌───────────────────┐   ┌───────────────────┐   ┌───────────────────┐
  │  ArgoCD           │   │  Event Logger     │   │  Uptime Kuma      │
  │  :80 (ClusterIP)  │   │  :8080 (ClusterIP)│   │  :3001 (ClusterIP)│
  │  ns: argocd       │   │  ns: event-logger │   │  ns: uptime-kuma  │
  │                   │   │  ┌─────┐          │   │                   │
  │                   │   │  │Envoy│ sidecar  │   │  ┌─────┐          │
  │                   │   │  └─────┘          │   │  │Envoy│ sidecar  │
  └───────────────────┘   └────────┬──────────┘   │  └─────┘          │
                                   │              └───────────────────┘
                    nats://nats.nats.svc:4222
                                   │
                    ┌──────────────▼──────────────┐
                    │  NATS JetStream              │
                    │  ns: nats                    │
                    │  ┌─────┐                     │
                    │  │Envoy│ sidecar             │
                    │  └─────┘                     │
                    │  Stream: EVENTS (PVC 2Gi)    │
                    └──────────────────────────────┘
```

---

## Conceptos clave de Istio

### Gateway

Un **Gateway** define los puntos de entrada al mesh. Es el equivalente a lo que hacia Traefik como ingress controller, pero con mas control:

```yaml
apiVersion: networking.istio.io/v1
kind: Gateway
metadata:
  name: main-gateway
spec:
  selector:
    istio: ingressgateway      # se aplica al pod del Ingress Gateway
  servers:
    - port:
        number: 80
        protocol: HTTP
      hosts:
        - "events.IP.nip.io"   # que dominios acepta
        - "uptime.IP.nip.io"
```

### VirtualService

Un **VirtualService** define las reglas de routing. Reemplaza al recurso `Ingress` de Kubernetes:

```yaml
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: event-logger
spec:
  hosts:
    - "events.IP.nip.io"
  gateways:
    - main-gateway             # usa el Gateway definido arriba
  http:
    - route:
        - destination:
            host: event-logger.event-logger.svc.cluster.local
            port:
              number: 8080
```

Equivale a un Ingress de Traefik pero con capacidades adicionales: traffic splitting, retries, timeouts, fault injection.

### Sidecar (Envoy Proxy)

Cada pod con sidecar injection recibe un contenedor Envoy extra que intercepta todo el trafico:

```
Pod: event-logger
┌─────────────────────────────────────────┐
│  ┌──────────────┐  ┌────────────────┐   │
│  │  Tu app      │  │  Envoy proxy   │   │
│  │  (Go API)    │◄─►  (sidecar)     │◄──┼── trafico
│  └──────────────┘  └────────────────┘   │
└─────────────────────────────────────────┘
```

Se habilita por namespace con el label `istio-injection: enabled`.

**Namespaces CON sidecar**: event-logger, uptime-kuma, nats
**Namespaces SIN sidecar**: argocd, keda, kyverno, istio-system, istio-ingress

---

## Cambios realizados

### Terraform

| Fichero | Cambio |
|---------|--------|
| `terraform.tfvars` | `cluster_name: k3s-istio`, `flavor_master: b2-15` |
| `cloud-init-master.tpl` | Eliminado Docker, anadidos puertos K3s (6443) e Istio (15017, 15021, 10250) |
| `outputs.tf` | Grupo inventario: `k3d_hosts` → `k3s_masters` |

### Ansible

| Fichero | Cambio |
|---------|--------|
| `roles/k3s-master/` | Nuevo role (basado en `ovh/terra-from-github-main`), con `--disable=traefik` |
| `playbooks/k3s-install.yml` | Roles: `docker` + `k3d` → `k3s-master` |
| `playbooks/*.yml` | Hosts: `k3d_hosts` → `k3s_masters`, `become: yes` |
| `roles/argocd/tasks/main.yml` | Service: `LoadBalancer` → `ClusterIP` |

### Istio (ArgoCD apps nuevas)

| App | Chart | sync-wave |
|-----|-------|-----------|
| `istio-base` | `base` v1.24.2 | -3 (CRDs) |
| `istiod` | `istiod` v1.24.2 | -2 (control plane) |
| `istio-ingressgateway` | `gateway` v1.24.2 | -1 (ingress) |
| `istio-config` | raw manifests | 0 (Gateway + VirtualServices) |

### Migracion de apps

| Antes (Traefik) | Despues (Istio) |
|-----------------|-----------------|
| `Ingress` en event-logger chart | `VirtualService` en istio-config/ |
| `Ingress` en uptime-kuma chart | `VirtualService` en istio-config/ |
| `Ingress` argocd-ingress.yaml | `VirtualService` en istio-config/ |
| nginx-demo (NodePort) | Eliminado |

### CI/CD

| Workflow | Cambio |
|----------|--------|
| `ovh-k3s-cluster-deploy.yml` | Nombre: K3D→K3s Istio, keypair: k3s-istio, wait: 7min |
| `deploy-apps.yml` | Nombre: K3D→K3s |

---

## Secuencia de ejecucion

```
1. Generar nueva clave SSH en equipo local
   ssh-keygen -t ed25519 -C "k3s-ovh" -f ~/.ssh/k3s-ovh

2. Actualizar GitHub Secrets
   OVH_SSH_PUBLIC_KEY  → contenido de ~/.ssh/k3s-ovh.pub
   OVH_SSH_PRIVATE_KEY → contenido de ~/.ssh/k3s-ovh

3. Commit y push de todos los cambios

4. Destruir cluster actual
   GitHub Actions → OVH K3s Istio Cluster Deploy → action: destroy

5. Crear nuevo cluster
   GitHub Actions → OVH K3s Istio Cluster Deploy → action: apply

6. Obtener nueva IP del output de Terraform

7. Actualizar NEW_IP en:
   - cluster/apps/istio-config/gateway.yaml
   - cluster/apps/istio-config/argocd-vs.yaml
   - cluster/apps/istio-config/events-vs.yaml
   - cluster/apps/istio-config/uptime-vs.yaml
   - GitHub Secret: K3S_MASTER_IP

8. Push cambios de IP → deploy-apps workflow se dispara

9. Verificar
   ssh -i ~/.ssh/k3s-ovh ubuntu@NEW_IP
   kubectl get nodes
   kubectl get pods -n istio-system
   curl http://events.NEW_IP.nip.io/health
```

---

## Estado final del cluster

```
┌──────────────────────────────────────────────────────────────┐
│                 K3s Cluster (OVH b2-15)                       │
│                 Istio Service Mesh                            │
│                                                              │
│  namespace: istio-system    → istiod (control plane)          │
│  namespace: istio-ingress   → Ingress Gateway (LoadBalancer)  │
│  namespace: argocd          → GitOps controller               │
│  namespace: nats            → NATS JetStream (PVC 2Gi)        │
│  namespace: event-logger    → Go API (producer/consumer)      │
│  namespace: uptime-kuma     → monitoreo (PVC 2Gi)             │
│  namespace: keda            → autoscaling engine              │
│  namespace: kyverno         → policy engine                   │
│  namespace: kube-system     → CoreDNS, metrics                │
│                                                              │
│  URLs:                                                       │
│    http://argocd.NEW_IP.nip.io  → ArgoCD                     │
│    http://events.NEW_IP.nip.io  → Event Logger               │
│    http://uptime.NEW_IP.nip.io  → Uptime Kuma                │
└──────────────────────────────────────────────────────────────┘
```
