# Copia este archivo a terraform.tfvars y rellena los valores

service_name            = "7661ad09e6144c26bb271f3945d00680"
region                  = "GRA11"
cluster_name            = "k3s-prod"
master_count            = 1
worker_count            = 2
flavor_master           = "b2-7"
flavor_worker           = "b2-7"
<<<<<<< HEAD
ssh_public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3sxiv9tekVFpQ7JdwFd6dXWN/02R1gASLuyn/iLkvQY3Zi7eTrUUpgj9/My8iP2QtGVey5Jdc4SK+yHCxKZ2tosY1q373pHVLBhfjogFz3DxjoFPxTrLcAiaxwY5mirlBzql5mjd67tbzOEpHnGlmyk/am5Fd4DYwZNj9kAXpJ1xU8+Gz831/0qRDAoDvrACbfUBXSHTIgMSdxaizVH2PUCH6VrqS9cbxGuYHL9oQMFo6qURysmcgnkjRvTbprDebp7qv0q66ABwYtHUlORwH+RKobuOcjRl5ezKgN236vD+JDCflUsOGdYVA4IOBTT60z6EYlXYWaTXj1nkOgovu5oGuySyqDg/EcnZGG5ZvykHBJOYfKU8HHpQqHqoICjJkOIsExsF4G68RjKkf29NuaJXt8w2KzeDdjG359oW7cbqX/6NMb2EczqIxQ+QKeNjsuxV3jQvoRnGyX8PX1OU72JKeuf6HSu/WVlLB2D6nn5l+IHEwzaHqAnzxQhO2CqhjdDeYjbxT5o1zS775LlObRanM70Bf+COWfOgn+b5obEAaEXegB6Qh+PRCKxKfcmKg+mMOqcCK6/OYiWHpxriYQUCMXS7eh2EGm4ocj4PG2Y07VUSKbEdYKh6qjTv72GVFwARnQWgK6RQbtIBzsPN5RzYsjR4+pMcLWK008UB99w=="
=======
ssh_public_key          = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC4McwCuwFqu5lrVElPVnzj4+Y0ik1MRJVjZ56zyIwj8Xm+g3PWV+NlDQ34K63oKDxjE2DEVT7d6drri6OfS4d17N71RCYZemyhANcqT5F4y+05nrU5EhkXqgda8I02peSK4nGGOxx+9fyPVcmzqUZgQZbt4cvC7ynqgA4IX+z59EJqtwx8fBcnDlmrDB7LeZDkTfVxlWBww8NXuU3EMLupfWg1YFhQTL7d+/MEuCDqKHFYhthzLQUf5kkNkCInI/ewWSULYG3Sd5ySo6/23qkuUZmmAy+CCQd284ii/LdeiYaQb/5lOqov7w5tjbFWx+RhN46O4JLks9ireZDmWt3PXexuSGrn/E/dsGdDFjAUWA48d+SshO91znybKP0Ns4aiQu/8TR2myb3BgH7xnfPjUoau4iidh3SfxVKDBAfV1BmR2dN0oBuJWKnJd+rqXEr2sdLZl8e/16d4Lrtd4+qUHr8tJqZx9bj1IBKwRng7xXnFgEO6d28VR7HTJ33vx1QDBpaxGm7NzoylH/J3dHJVcW4muFDp/ZeBF9KXr4JAZGKRtG+eduqUHUzdp8fPDemYqaMZFJj1K8FS91UF9zf/PmWjFuJVkdvARltoTlS6HRYsRMKd1/rpyJxjZS4efi07A3YrWDO8R8rZrnTZOvRUwscnz6/Ub1kCUtyvThzMow== "
>>>>>>> 8306258 (feat: añadir infraestructura K3s en OVH con ArgoCD)
image_name              = "Ubuntu 22.04"
