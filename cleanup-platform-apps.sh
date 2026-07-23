#!/usr/bin/env bash
#
# cleanup-platform-apps.sh
#
# Cleans up a cloned GoogleCloudPlatform/microservices-demo repo down to only
# what this project needs:
#   - src/{frontend,cartservice,checkoutservice,productcatalogservice} (built by CI)
#   - kubernetes-manifests/ (needed for Step 3 - ArgoCD deploys the full 11-service
#     app, pulling public Google images for the services we don't customize)
#   - .github/workflows/ci.yml (your custom pipeline)
#   - README.md, LICENSE (attribution - you're building on Google's sample app)
#
# Everything else (other 7 service source dirs, istio-manifests, kustomize,
# terraform/ [GCP-specific, irrelevant since you have your own AWS terraform],
# docs, release scripts, Google's own CI workflows, cloudbuild/skaffold config)
# gets removed.
#
# SAFE BY DEFAULT: run with no arguments to see what WOULD be deleted.
# Run with --apply to actually delete.
#
# Usage:
#   ./cleanup-platform-apps.sh              # dry run, shows what will be removed
#   ./cleanup-platform-apps.sh --apply       # actually deletes

set -euo pipefail

APPLY=false
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=true
fi

# --- Safety checks: make sure we're in the right repo ---
if [[ ! -d "src" || ! -d ".github" ]]; then
  echo "ERROR: This doesn't look like the platform-apps repo root."
  echo "Run this script from inside the platform-apps/ folder."
  exit 1
fi

if [[ ! -d "src/frontend" || ! -d "src/cartservice" ]]; then
  echo "ERROR: Expected src/frontend and src/cartservice to exist."
  echo "This doesn't look like a microservices-demo clone. Aborting."
  exit 1
fi

KEEP_SERVICES=("frontend" "cartservice" "checkoutservice" "productcatalogservice")

echo "=================================================="
if $APPLY; then
  echo "MODE: APPLY (files will actually be deleted)"
else
  echo "MODE: DRY RUN (nothing will be deleted - use --apply to execute)"
fi
echo "=================================================="
echo ""

remove_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    if $APPLY; then
      rm -rf -- "$path"
      echo "  [REMOVED] $path"
    else
      echo "  [WOULD REMOVE] $path"
    fi
  fi
}

# --- 1. Remove unused service source directories ---
echo "-- Trimming src/ to only the 4 customized services --"
if [[ -d "src" ]]; then
  for dir in src/*/; do
    svc=$(basename "$dir")
    keep=false
    for k in "${KEEP_SERVICES[@]}"; do
      [[ "$svc" == "$k" ]] && keep=true
    done
    if ! $keep; then
      remove_path "src/$svc"
    fi
  done
fi
echo ""

# --- 2. Remove GCP/Istio/Kustomize/Helm tooling not relevant to AWS+ArgoCD setup ---
echo "-- Removing GCP-specific and unused deployment tooling --"
remove_path "istio-manifests"
remove_path "kustomize"
remove_path "terraform"
remove_path "helm-chart"
remove_path "kubernetes-manifests/kustomize"
echo ""

# --- 3. Remove docs, release scripts, misc repo scaffolding ---
echo "-- Removing docs/release scaffolding not needed for this project --"
remove_path "docs"
remove_path "release"
remove_path "protos/demo.proto.bak"
remove_path "hack"
remove_path ".github/ISSUE_TEMPLATE"
remove_path ".github/PULL_REQUEST_TEMPLATE.md"
remove_path "CODEOWNERS"
remove_path "CONTRIBUTING.md"
remove_path "cloudbuild.yaml"
remove_path "skaffold.yaml"
remove_path ".git-blame-ignore-revs"
echo ""

# --- 4. Remove Google's own GitHub Actions workflows, keep only ci.yml ---
echo "-- Cleaning .github/workflows/ (keeping only ci.yml) --"
if [[ -d ".github/workflows" ]]; then
  for f in .github/workflows/*; do
    fname=$(basename "$f")
    if [[ "$fname" != "ci.yml" ]]; then
      remove_path "$f"
    fi
  done
fi
echo ""

echo "=================================================="
if $APPLY; then
  echo "Cleanup applied."
else
  echo "Dry run complete. Review the list above."
  echo "If it looks right, re-run with: ./cleanup-platform-apps.sh --apply"
fi
echo "=================================================="

# --- Show what's left ---
echo ""
echo "Remaining top-level structure:"
ls -la
