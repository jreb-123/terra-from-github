# Problema de conectividad de ArgoCD en K3s

## Sintoma

ArgoCD Application queda en estado **Unknown** y el controller repite este error constantemente:

```
Failed to save clusters info: dial tcp: lookup argocd-redis: i/o timeout
```

## Causa raiz

El firewall (UFW) del **worker node** bloquea el puerto **8472/UDP** que usa flannel VXLAN para la comunicacion entre nodos. Sin este puerto, los pods del master no pueden alcanzar los pods del worker (CoreDNS, Redis), rompiendo DNS y toda la conectividad interna del cluster.

## Diagnostico rapido

Desde el master, hacer ping al rango de pods del worker:

```bash
ping -c 3 10.42.1.1
```

Si hay **100% packet loss**, el problema es este.

## Solucion

### Opcion A - Abrir solo los puertos necesarios (recomendado)

En **ambos nodos** (master y worker):

```bash
sudo ufw allow 8472/udp     # Flannel VXLAN (comunicacion entre nodos)
sudo ufw allow from 10.42.0.0/16  # Trafico entre pods
sudo ufw allow from 10.43.0.0/16  # Trafico de servicios internos
```

Solo en el master:

```bash
sudo ufw allow 6443/tcp     # API server K3s
```

### Opcion B - Desactivar UFW (rapido pero menos seguro)

En **ambos nodos**:

```bash
sudo ufw disable
```

### Despues de aplicar la solucion

Reiniciar el controller de ArgoCD para limpiar el cache DNS roto:

```bash
sudo kubectl delete pod argocd-application-controller-0 -n argocd --kubeconfig /etc/rancher/k3s/k3s.yaml
```

Verificar en 30 segundos:

```bash
sudo kubectl get application -n argocd -o wide --kubeconfig /etc/rancher/k3s/k3s.yaml
```

El estado debe cambiar de **Unknown** a **Synced**.
