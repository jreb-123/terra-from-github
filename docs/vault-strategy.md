# Estrategia de Gestion de Secretos con Vault

## Problema

Los secretos (API keys, credenciales cloud, passwords) estan dispersos en GitHub Secrets, archivos locales y configuraciones manuales. Se necesita una solucion centralizada, segura y accesible desde cualquier cloud.

## Opciones Evaluadas

| Herramienta | Tipo | Multi-cloud | Multi-uso | Seguridad | Coste |
|-------------|------|-------------|-----------|-----------|-------|
| **GitHub Secrets** | CI/CD only | No (solo GitHub Actions) | No | Media | Gratis |
| **HashiCorp Vault** | Secrets manager | Si (cualquier cloud/on-prem) | Si (secrets + PKI + transit) | Muy alta | Gratis (OSS) / $$$$ (Enterprise) |
| **Vaultwarden** | Password manager | Si (web) | Si (passwords personales) | Alta | Gratis |
| **AWS Secrets Manager** | Cloud-native | No (solo AWS) | Parcial | Alta | $0.40/secreto/mes |
| **Azure Key Vault** | Cloud-native | No (solo Azure) | Parcial | Alta | $0.03/10k operaciones |

## Recomendacion: HashiCorp Vault

### Por que Vault

1. **Multi-cloud real**: Un unico Vault accesible desde OVH, AWS, Azure, GCP
2. **Multi-uso**: No solo claves de infraestructura, tambien passwords de plataformas, certificados, tokens API
3. **Seguridad superior**:
   - Cifrado AES-256-GCM en reposo
   - Unseal keys con algoritmo Shamir (requiere N de M claves para desbloquear)
   - Audit log completo de cada acceso
   - Lease/TTL — secretos con expiracion automatica
   - Politicas granulares (quien puede leer/escribir que paths)
   - Rotacion automatica de credenciales
4. **Integracion nativa con Terraform**: Provider `vault` para leer secretos en tiempo de plan/apply
5. **Integracion con Kubernetes**: Vault Agent Sidecar o CSI driver para inyectar secretos en pods

### Arquitectura Propuesta

```
                    ┌─────────────────────────────────────┐
                    │         HashiCorp Vault              │
                    │    (instancia dedicada o managed)     │
                    │                                     │
                    │  Secrets Engines:                    │
                    │  ├── kv/infra/ovh/*     → API keys   │
                    │  ├── kv/infra/aws/*     → IAM keys   │
                    │  ├── kv/infra/gcp/*     → SA keys    │
                    │  ├── kv/infra/ssh/*     → SSH keys   │
                    │  ├── kv/apps/*          → App secrets │
                    │  ├── kv/personal/*      → Passwords  │
                    │  └── pki/               → Certificados│
                    │                                     │
                    │  Auth Methods:                       │
                    │  ├── token    (CI/CD)                │
                    │  ├── userpass (personas)             │
                    │  ├── kubernetes (pods en K3s)        │
                    │  └── github   (GitHub Actions)      │
                    └──────────┬──────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
     ┌────────────┐   ┌────────────┐   ┌────────────┐
     │   OVH      │   │   AWS      │   │   GCP      │
     │            │   │            │   │            │
     │ Terraform  │   │ Terraform  │   │ Terraform  │
     │ K3s/K3D    │   │ Lambda     │   │ GKE        │
     │ ArgoCD     │   │ EKS        │   │ Cloud Run  │
     └────────────┘   └────────────┘   └────────────┘
```

### Organizacion de Secretos (KV v2)

```
vault kv/
├── infra/
│   ├── ovh/
│   │   ├── api          → OVH_APPLICATION_KEY, OVH_APPLICATION_SECRET, OVH_CONSUMER_KEY
│   │   └── openstack    → OPENSTACK_USERNAME, OPENSTACK_PASSWORD, OPENSTACK_TENANT_ID
│   ├── aws/
│   │   ├── iam          → AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
│   │   └── terraform    → state bucket credentials
│   ├── gcp/
│   │   ├── sa           → service account JSON key
│   │   └── workload-id  → WORKLOAD_IDENTITY_PROVIDER, SERVICE_ACCOUNT
│   └── ssh/
│       ├── ovh-master   → private key, public key
│       └── gcp-bastion  → private key, public key
├── apps/
│   ├── nats/            → NATS auth tokens (si se habilita)
│   ├── argocd/          → admin password, SSO config
│   └── uptime-kuma/     → admin credentials
├── personal/
│   ├── github           → PAT tokens
│   ├── docker-hub       → credentials
│   ├── cloudflare       → API token, zone ID
│   └── otras            → passwords de plataformas varias
└── pki/
    └── certs/           → certificados TLS generados por Vault
```

### Uso con Terraform

```hcl
# providers.tf
provider "vault" {
  address = "https://vault.midominio.com:8200"
  # Auth via VAULT_TOKEN env var o auth method
}

# Leer secretos de OVH
data "vault_kv_secret_v2" "ovh_api" {
  mount = "kv"
  name  = "infra/ovh/api"
}

# Usar en provider
provider "ovh" {
  endpoint           = "ovh-eu"
  application_key    = data.vault_kv_secret_v2.ovh_api.data["application_key"]
  application_secret = data.vault_kv_secret_v2.ovh_api.data["application_secret"]
  consumer_key       = data.vault_kv_secret_v2.ovh_api.data["consumer_key"]
}
```

### Uso con GitHub Actions

```yaml
jobs:
  deploy:
    steps:
      - name: Import secrets from Vault
        uses: hashicorp/vault-action@v2
        with:
          url: https://vault.midominio.com:8200
          method: github
          githubToken: ${{ secrets.VAULT_GITHUB_TOKEN }}
          secrets: |
            kv/data/infra/ovh/api application_key | OVH_APPLICATION_KEY ;
            kv/data/infra/ovh/api application_secret | OVH_APPLICATION_SECRET ;
            kv/data/infra/ovh/openstack username | OPENSTACK_USERNAME ;
```

### Uso con Kubernetes (K3s)

```yaml
# Vault Agent Sidecar — inyecta secretos como ficheros en el pod
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "event-logger"
    vault.hashicorp.com/agent-inject-secret-nats: "kv/data/apps/nats"
```

### Donde Desplegar Vault

| Opcion | Pros | Contras |
|--------|------|---------|
| **VM dedicada (OVH/GCP)** | Control total, coste bajo (~5€/mes) | Mantenimiento manual, backups propios |
| **HCP Vault (managed)** | Zero mantenimiento, HA incluido | Coste ($0.03/secreto/mes, minimo ~50$/mes) |
| **Pod en K3s** | Ya tienes el cluster | No ideal (Vault deberia estar fuera del cluster que gestiona) |

**Recomendacion para el lab**: VM dedicada pequena (b2-7 en OVH o e2-micro en GCP free tier) con Vault OSS en modo dev inicialmente, luego con almacenamiento persistente y unseal automatico.

## Seguridad: Vault vs Alternativas

| Aspecto | GitHub Secrets | Vaultwarden | HashiCorp Vault |
|---------|---------------|-------------|-----------------|
| **Cifrado en reposo** | Si (NaCl sealed box) | Si (AES-256) | Si (AES-256-GCM + seal) |
| **Cifrado en transito** | HTTPS | HTTPS | mTLS |
| **Control de acceso** | Por repo/org | Por usuario | Politicas granulares por path |
| **Audit log** | Limitado | No | Completo (cada operacion) |
| **Rotacion automatica** | No | No | Si (dynamic secrets) |
| **Expiracion de secretos** | No | No | Si (leases con TTL) |
| **Shamir unseal** | No | No | Si (N de M keys) |
| **MFA** | Si (cuenta GitHub) | Si (TOTP) | Si (MFA por path/operacion) |
| **Dynamic secrets** | No | No | Si (genera credenciales temporales) |
| **Integracion cloud** | Solo GitHub Actions | Web/extension | Terraform, K8s, CI/CD, API |

## Migracion Gradual

### Fase 1 — Instalar Vault (lab)
- Desplegar Vault en una VM
- Habilitar KV v2 secrets engine
- Migrar secretos de SSH y OVH API

### Fase 2 — Integrar con Terraform
- Configurar provider Vault en Terraform
- Reemplazar `terraform.tfvars` por lecturas de Vault
- Actualizar GitHub Actions para leer de Vault

### Fase 3 — Integrar con Kubernetes
- Habilitar auth method `kubernetes` en Vault
- Configurar Vault Agent Sidecar para pods que necesiten secretos
- Eliminar secretos hardcodeados en values.yaml

### Fase 4 — Passwords personales
- Habilitar path `kv/personal/`
- Configurar acceso via CLI (`vault kv get`) o UI web de Vault
- Opcionalmente, correr Vaultwarden en paralelo para passwords tipo browser (extension)

## Referencias

- [HashiCorp Vault](https://www.vaultproject.io/)
- [Vault Terraform Provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs)
- [Vault GitHub Actions](https://github.com/hashicorp/vault-action)
- [Vault Kubernetes Auth](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vaultwarden](https://github.com/dani-garcia/vaultwarden)
