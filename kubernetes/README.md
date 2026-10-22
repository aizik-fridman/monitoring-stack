# Kubernetes deployment overlays

These Helm values are production-oriented starting points, not a turnkey
multi-tenant deployment. Pin chart versions in your release process, supply
secret values through an external secret manager, and review resource requests,
storage classes, retention, and network policies for your cluster.

Install the chart overrides from this directory using the upstream Helm charts:

```powershell
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add vm https://victoriametrics.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
  --namespace monitoring --create-namespace `
  -f values-kube-prometheus-stack.yaml
helm upgrade --install vm-cluster vm/victoria-metrics-single `
  --namespace monitoring -f values-victoria-metrics.yaml
helm upgrade --install loki grafana/loki `
  --namespace monitoring -f values-loki.yaml
helm upgrade --install alloy grafana/alloy `
  --namespace monitoring -f values-alloy.yaml
```

Deploy Tempo with the `grafana/tempo-distributed` chart and
`values-tempo-distributed.yaml`; its S3 bucket and IRSA role are provisioned
by Terraform. Replace the role ARN placeholders in `thanos-serviceaccount.yaml`
and `values-tempo-distributed.yaml` with Terraform outputs before applying.
Configure the Prometheus pods to use the `thanos` service account, then deploy
Thanos Query, Store Gateway, and Compactor with the same S3 object-storage
secret. The object-storage secret must be populated outside this repository.
The local Compose credentials in `../config/thanos/objstore.yml` are for
development only.

`kube-prometheus-stack` installs kube-state-metrics and node-exporter for
Kubernetes infrastructure telemetry. For Windows nodes, enable the chart's
Windows exporter integration and scope scheduling with node selectors and
tolerations appropriate to the Windows node pool.
