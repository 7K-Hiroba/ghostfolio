# Agent Guide

This file is for AI agents and automated tools making changes to this repository. Read this before modifying any files.

## What This Repo Is

A **purely infrastructure repo** — no `src/`, no `Dockerfile`, no application code. Ghostfolio uses the official upstream image (`docker.io/ghostfolio/ghostfolio`). Both Helm charts and GitOps manifests live here; the base chart deploys the upstream container, the platform chart wires in databases, cache, secrets, and observability.

## Philosophy: Near-Native

Prefer upstream, official solutions over custom implementations. The base chart wraps the official image; the platform chart is always custom (that is where Hiroba adds value). **Do not rewrite what upstream already does well.**

## Repository Structure

```text
├── helm/
│   ├── base/                          # Application Helm chart (Deployment, Service, HTTPRoute, etc.)
│   │   ├── Chart.yaml                 # appVersion tracks upstream Ghostfolio version
│   │   ├── values.yaml                # Overrides + custom values
│   │   ├── values.schema.json         # Required — CI validates against this
│   │   ├── templates/                 # deployment, service, httproute, hpa, pdb, serviceaccount
│   │   └── tests/                     # helm-unittest suites (<template>_test.yaml)
│   ├── platform/                      # Platform dependencies (always custom)
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values.schema.json
│   │   ├── .ci-api-versions           # CRD versions simulated in CI (must update when adding operators)
│   │   ├── dashboards/                # Grafana dashboard JSON files
│   │   ├── templates/
│   │   │   ├── _helpers.tpl           # platform.name, platform.labels, platform.baseSelectorLabels
│   │   │   ├── checks.yaml           # Operator-presence checks — fail at render time if CRD missing
│   │   │   ├── database/             # CNPG cluster, CNPG scheduled backup, Dragonfly Redis
│   │   │   ├── storage/              # S3 via Crossplane, S3 via Garage
│   │   │   ├── secrets/              # ExternalSecret
│   │   │   └── observability/        # ServiceMonitor, GrafanaDashboard, PrometheusRules
│   │   └── tests/
│   ├── base-artifacthub-repo.yml      # ArtifactHub metadata for base chart
│   └── platform-artifacthub-repo.yml  # ArtifactHub metadata for platform chart
├── compositions/
│   └── crossplane/                    # Crossplane XRDs & Compositions (placeholder — examples only)
│       └── examples/
├── gitops/
│   ├── argocd/                        # ArgoCD Application manifests (root.yaml + applications/)
│   └── fluxcd/                        # FluxCD Kustomization manifests
├── docs/                              # TechDocs (Docusaurus, published via Backstage)
└── catalog-info.yaml                  # Backstage catalog entry
```

## Ghostfolio-Specific Facts

- **Upstream image**: `docker.io/ghostfolio/ghostfolio` — do not add a Dockerfile
- **App listens on port 3333** (configurable via `PORT` env var). `service.targetPort` is already set to `3333`.
- **Health endpoint**: `/api/v1/health` (used for both liveness and readiness probes)
- **readOnlyRootFilesystem: true** — a `/tmp` emptyDir volume is required for Node.js/Prisma temp writes. Already configured in `values.yaml` under `extraVolumes`/`extraVolumeMounts`.
- **Required env vars** (set via `env`/`envFrom` in base chart):
  - `DATABASE_URL` — from CNPG secret `uri` key
  - `REDIS_HOST` — Dragonfly service name
  - `ACCESS_TOKEN_SALT` — random salt
  - `JWT_SECRET_KEY` — random key
- **Optional OIDC env vars**: `ENABLE_FEATURE_AUTH_OIDC`, `OIDC_ISSUER`, `OIDC_CLIENT_ID`, `OIDC_CLIENT_SECRET`
- **Platform resources**: `postgres` (CNPG) and `redis` (Dragonfly) are both enabled by default; `s3`, `externalSecrets`, and `observability` are disabled by default

## Where to Add What

### Application changes (deployment, ports, probes, scaling)

Modify `helm/base/values.yaml`. The base chart is self-authored (not wrapping an upstream chart), so changes go directly in its templates and values.

### Database, cache, storage, secrets, or observability

Add or modify resources under `helm/platform/templates/<category>/`. Each resource is gated by an `enabled` flag in `helm/platform/values.yaml`.

| Category | Path | Resources |
| --- | --- | --- |
| database | `templates/database/` | CNPG Cluster, CNPG Scheduled Backup, Dragonfly Redis |
| storage | `templates/storage/` | S3 via Crossplane, S3 via Garage |
| secrets | `templates/secrets/` | ExternalSecret |
| observability | `templates/observability/` | ServiceMonitor, GrafanaDashboard, PrometheusRules |

### New platform provider variant

1. Create `helm/platform/templates/<category>/<resource>-<provider>.yaml`
2. Gate it with `{{- if and .Values.<resource>.enabled (eq .Values.<resource>.provider "<provider>") }}`
3. Add provider-specific values under `<resource>.<provider>:` in `values.yaml`
4. Add the provider to the `enum` in `values.schema.json`
5. Add the CRD API version to `.ci-api-versions` and a check in `checks.yaml`

### Grafana dashboards

Place JSON files in `helm/platform/dashboards/`. The `grafana-dashboard.yaml` template mounts them as a ConfigMap with `grafana_dashboard: "1"` label.

## Conventions

### Helm

- API version: `apiVersion: v2`
- All resources use `app.kubernetes.io/*` labels via `_helpers.tpl` (base: `app.*` helpers; platform: `platform.*` helpers)
- All resources include `app.kubernetes.io/part-of: hiroba`
- Security defaults: `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, all capabilities dropped
- External traffic uses **Gateway API** (`gateway.networking.k8s.io/v1` HTTPRoute), not Ingress
- Every chart **must** include `values.schema.json` and unit tests under `tests/`

### Values schema

- JSON Schema draft-07, `additionalProperties: false` on key objects
- When adding a new value to `values.yaml`, always add the corresponding schema entry in `values.schema.json`

### Unit tests

- One test file per template: `<template>_test.yaml`
- For platform chart tests, set `capabilities.apiVersions` to satisfy `checks.yaml` (see existing tests for the pattern)
- Test both enabled and disabled states; test conditional rendering

### Platform chart

- Every resource gated behind `<resource>.enabled` (default `false` for optional resources)
- Provider switch: `<resource>.provider` selects the template variant
- Template naming: `<resource>-<provider>.yaml` inside the category subfolder

### API versions

- Prefer latest stable (GA) API version. Only use alpha/beta when no GA version exists upstream.
- When adding a new operator dependency, update **all three**: the template, `checks.yaml`, and `.ci-api-versions`

### External Secrets

- Use `external-secrets.io/v1` ExternalSecret
- Reference a `ClusterSecretStore` by default
- Map keys via `data[]` or bulk-import via `dataFrom[]`

## CI/CD

### CI (`.github/workflows/ci.yml`)

- **PR title lint** — must follow Conventional Commits
- **Helm chart jobs** — conditional on path changes to `helm/base/` or `helm/platform/`
- **Docs job** — conditional on path changes to `docs/`
- The `.ci-api-versions` file is auto-loaded by the reusable workflow to simulate CRDs during `helm template`

### Releases (`.github/workflows/release-please.yml`)

Fully automated via release-please. Commit messages drive versioning using [Conventional Commits](https://www.conventionalcommits.org/):

- `fix(helm-base): correct probe path` → patch bump
- `feat(helm-platform): add redis provider` → minor bump
- `feat(helm-base)!: change gateway API version` → major bump

Scope must match the component. Release-please uses path-based detection:

| Component | Path | Tag prefix | release-please type |
| --- | --- | --- | --- |
| app | (no Dockerfile yet) | `app/v*` | `simple` |
| helm-base | `helm/base/` | `helm-base/v*` | `helm` |
| helm-platform | `helm/platform/` | `helm-platform/v*` | `helm` |
| docs | `docs/` | `docs/v*` | `simple` |
| crossplane | `compositions/crossplane/` | `crossplane/v*` | `simple` |

Config files: `release-please-config.json` (component definitions), `.release-please-manifest.json` (version tracking, committed by release-please).

**Note**: The `app` component is defined in release-please config but no Dockerfile exists yet. Do not add one unless explicitly asked.

## Markdown Linting

CI runs `markdownlint-cli2`. Config (`.markdownlint.yaml`): only `MD013` (line length) is disabled.

```bash
npx markdownlint-cli2 "**/*.md"
```

Fix errors by correcting markup — do not disable rules inline. New `.md` files must start with a top-level heading (MD041).
