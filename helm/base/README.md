# ghostfolio

Helm chart for [Ghostfolio](https://ghostfol.io) — open source wealth management software that tracks stocks, ETFs, and cryptocurrencies.

This chart installs the workload (Deployment, Service, HPA, PDB, HTTPRoute). For cross-cutting platform dependencies (PostgreSQL, Redis, secrets, observability), install the companion [ghostfolio-platform](../platform/README.md) chart.

**Documentation:** <https://hiroba.7kgroup.org/docs/apps/ghostfolio/helm-base>

## TL;DR

```bash
helm install ghostfolio \
  oci://harbor.7kgroup.org/7khiroba/charts/ghostfolio \
  --version 0.1.0
```

## Prerequisites

- Kubernetes 1.24+
- Gateway API CRDs installed in the cluster (the chart provisions an `HTTPRoute`)
- A running `Gateway` that your `HTTPRoute` can attach to
- PostgreSQL database accessible to the pod
- Redis instance accessible to the pod

## What gets installed

| Resource | Purpose |
|---|---|
| `Deployment` | Ghostfolio application pod |
| `Service` | ClusterIP fronting the deployment (port 80 -> 3333) |
| `HTTPRoute` | Gateway API routing |
| `ServiceAccount` | Pod identity |
| `HorizontalPodAutoscaler` | Optional — enabled via `autoscaling.enabled` |
| `PodDisruptionBudget` | Optional — enabled via `podDisruptionBudget.enabled` |

## Required environment variables

Ghostfolio needs the following environment variables at a minimum. Configure them via the `env` value, typically referencing a Secret created by the platform chart's `ExternalSecret`:

| Variable | Description |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string (`postgresql://user:pass@host:5432/ghostfolio`) |
| `REDIS_HOST` | Redis hostname |
| `REDIS_PORT` | Redis port (default `6379`) |
| `REDIS_PASSWORD` | Redis password |
| `ACCESS_TOKEN_SALT` | Random string for hashing access tokens |
| `JWT_SECRET_KEY` | Random string for signing JWTs |

Optional variables: `HOST`, `PORT`, `REDIS_DB`, `ROOT_URL`, `REQUEST_TIMEOUT`.

## Configuration

All values are documented in [`values.yaml`](values.yaml) and validated against [`values.schema.json`](values.schema.json). Artifact Hub renders the schema as an interactive form on the chart page.

## Image

By default the chart uses the official upstream image [`ghostfolio/ghostfolio`](https://hub.docker.com/r/ghostfolio/ghostfolio) from Docker Hub. Override `image.repository` and `image.tag` if you use a custom build.

## Part of the Hiroba ecosystem

Scaffolded with [Hiroba](https://github.com/7K-Hiroba/Hiroba). Source and issues: <https://github.com/7K-Hiroba/ghostfolio>.
