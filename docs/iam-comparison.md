# Comparacion IAM: OVH vs Azure

## Modelo General

```
Azure (Entra ID)                              OVH IAM
─────────────                                 ───────

Tenant                                        Cuenta OVH (NIC handle)
  └── Directorio (Entra ID)                     └── Organizacion
        ├── Usuarios                                   ├── Usuarios locales
        ├── Grupos                                     ├── Grupos
        ├── Aplicaciones (Service Principals)           ├── Service Accounts
        ├── Roles (RBAC)                               ├── Policies (acciones)
        └── Conditional Access                         └── Identity Federation
```

## Comparacion Directa

| Concepto | Azure (Entra ID + RBAC) | OVH IAM |
|---|---|---|
| **Directorio de usuarios** | Entra ID (ex Azure AD), completo | Usuarios locales en cuenta OVH |
| **Grupos** | Si, anidados, dinamicos | Si, basicos |
| **Roles predefinidos** | ~120 roles built-in (Owner, Contributor, Reader...) | Acciones por recurso (no roles predefinidos) |
| **Roles custom** | Si | Si (via policies) |
| **Policies** | Azure Policy (compliance) + RBAC (acceso) | Policies = identidades + recursos + acciones |
| **Service accounts** | Service Principals + Managed Identities | Service accounts (API keys) |
| **MFA** | Si, nativo, condicional | Si (2FA en cuenta OVH) |
| **SSO / Federation** | SAML, OIDC, WS-Fed nativo | SAML v2 (ADFS, Azure AD, Okta, Google Workspace) |
| **Conditional Access** | Si (por IP, dispositivo, riesgo, ubicacion) | No |
| **PIM (acceso privilegiado temporal)** | Si (Just-in-time, aprobacion, time-bound) | No |
| **Access Reviews** | Si (revisiones periodicas automaticas) | No |
| **Scope** | Management Group → Subscription → Resource Group → Recurso | Cuenta → Proyecto → Recurso |
| **Coste** | Entra ID Free/P1/P2 ($0-$9/usuario/mes) | Gratis (incluido) |
| **Terraform** | `azurerm` + `azuread` providers | `ovh` provider |

## Como se Define el Acceso

### Azure RBAC

```
Quien        +    Que rol       +    Donde
(usuario)         (Contributor)       (Resource Group "dev")

= Juan puede crear/modificar/borrar recursos en el Resource Group "dev"
```

```json
{
  "role": "Contributor",
  "principal": "juan@empresa.com",
  "scope": "/subscriptions/xxx/resourceGroups/dev"
}
```

### OVH IAM

```
Quien        +    Que acciones           +    Sobre que recursos
(usuario)         (publicCloud:create,        (proyecto Public Cloud)
                   publicCloud:delete)

= Juan puede crear y borrar recursos en el proyecto Public Cloud
```

```json
{
  "name": "dev-access-policy",
  "identities": ["urn:v1:eu:identity:user:xx1234-ovh/juan"],
  "resources": ["urn:v1:eu:resource:publicCloudProject:abc123"],
  "permissions": {
    "allow": [
      { "action": "publicCloudProject:apiovh:*" }
    ]
  }
}
```

## Nivel de Granularidad

```
Azure                                    OVH
─────                                    ───

Management Group                         (no existe)
  └── Subscription                       Cuenta OVH
        └── Resource Group                 └── Proyecto Public Cloud
              └── Recurso individual             └── Recurso individual
                    └── Sub-recurso              (no mas profundo)
```

Azure tiene mas niveles de jerarquia, lo que permite herencia de permisos mas compleja.

## Federation (SSO)

Ambos soportan conectar un directorio corporativo:

```
Empresa (Active Directory / Okta / Google Workspace)
         │
         │ SAML v2 / OIDC
         │
    ┌────┴────┐
    ▼         ▼
  Azure     OVH
  (nativo)  (federation)
```

La diferencia es que Azure **es** un directorio (Entra ID), mientras que OVH **se conecta** a uno externo.

## Resumen

| Aspecto | Azure | OVH |
|---|---|---|
| **Madurez** | Muy maduro (10+ anos) | Reciente (2023) |
| **Complejidad** | Alta (muchas opciones) | Simple (lo esencial) |
| **Para empresas grandes** | Ideal (PIM, Conditional Access, Access Reviews) | Suficiente para equipos medianos |
| **Para lab/dev** | Overkill | Suficiente |
| **Coste** | $0-$9/usuario/mes (segun features) | Gratis |
| **Lo que falta en OVH** | — | Conditional Access, PIM, Access Reviews, roles predefinidos |

**Conclusion**: Azure IAM es mas potente y complejo, pensado para governance enterprise. OVH IAM cubre lo esencial (usuarios, grupos, policies, federation) de forma gratuita y es suficiente para la mayoria de equipos.

## Referencias

- [OVHcloud IAM](https://www.ovhcloud.com/en/identity-security-operations/identity-access-management/)
- [OVHcloud IAM Policies](https://support.us.ovhcloud.com/hc/en-us/articles/19226818732563-Creating-an-IAM-policy-to-allow-users-access-to-the-OVHcloud-Control-Panel)
- [Azure IAM Security Identity](https://learn.microsoft.com/en-us/azure/architecture/aws-professional/security-identity)
