# ghostfolio-platform

Platform dependencies for [Ghostfolio](https://ghostfol.io) — provisions the databases, cache, secrets, and observability resources that the base [ghostfolio](../base/README.md) chart's workload consumes.

Install this **alongside** `ghostfolio`, typically in the same namespace.

**Documentation:** <https://hiroba.7kgroup.org/docs/apps/ghostfolio/helm-platform>

## TL;DR

```bash
helm install ghostfolio-platform \
  oci://harbor.7kgroup.org/7khiroba/charts/ghostfolio-platform \
  --version 0.1.0
```

## Prerequisites

- Kubernetes 1.24+
- [CloudNativePG](https://cloudnative-pg.io/) — PostgreSQL operator (required by Ghostfolio)
- [Dragonfly Operator](https://www.dragonflydb.io/docs/managing-dragonfly/operator) — Redis-compatible cache (required by Ghostfolio)
- [External Secrets Operator](https://external-secrets.io/) — optional, for pulling secrets from a backend
- [Prometheus Operator](https://prometheus-operator.dev/) — optional, for `ServiceMonitor` and `PrometheusRule`
- Grafana with dashboard sidecar enabled — optional, for shipped dashboards

## What gets installed

| Resource | Purpose | Default |
|---|---|---|
| `Cluster` (CNPG) | PostgreSQL database (`ghostfolio` db) | **enabled** |
| `Dragonfly` | Redis-compatible cache via Dragonfly Operator | **enabled** |
| `ExternalSecret` | Sources app secrets from your secret backend | disabled |
| `ServiceMonitor` | Scrape config for the workload's metrics endpoint | disabled |
| Grafana dashboards | Shipped as `ConfigMap`s in `dashboards/`, picked up by the Grafana sidecar | disabled |
| `PrometheusRule` | Alerting rules (error rate, latency) | disabled |
| Crossplane `Bucket` | Optional — S3-compatible object storage | disabled |

## Ghostfolio-specific notes

Ghostfolio requires both **PostgreSQL** and **Redis** at runtime. This chart provisions both by default:

- **PostgreSQL** via CNPG — creates a `ghostfolio` database with `ghostfolio` owner
- **Redis** via Dragonfly Operator — creates a Redis-compatible instance

The CNPG cluster will produce a Secret named `<release>-pg-app` containing connection credentials. Wire these into the base chart's `env` section, or use an `ExternalSecret` to compose the `DATABASE_URL`.

## Configuration

Full values in [`values.yaml`](values.yaml), schema in [`values.schema.json`](values.schema.json). Artifact Hub renders the schema as an interactive form.

The chart is split so that **workload-lifecycle** resources (Deployment, HPA, PDB, HTTPRoute) live in [`ghostfolio`](../base/README.md), while **cross-cutting dependencies** (database, cache, ESO, ServiceMonitor, dashboards) live here. This keeps each chart focused and lets operators opt out of platform wiring without losing the app.

## Part of the Hiroba ecosystem

Scaffolded with [Hiroba](https://github.com/7K-Hiroba/Hiroba). Source and issues: <https://github.com/7K-Hiroba/ghostfolio>.
