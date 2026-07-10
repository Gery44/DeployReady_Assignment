# Deployment Documentation

## 1. Cloud Provider and Service

**Provider:** Render (https://render.com)  
**Service type:** Web Service — container deployment from a registry image  
**Live URL:** https://deployready-assignment-latest.onrender.com

### Why Render?

Render was chosen over a raw VM (AWS EC2, GCP Compute Engine, Azure B1s) for the following reasons:

- **Zero infrastructure management** — no VM to provision, patch, or harden. The focus stays on the delivery pipeline, which is the core of this challenge.
- **Native Docker support** — Render pulls directly from a container registry (GHCR) and runs the image as-is, which means the same image tested locally and in CI runs in production without modification.
- **Automatic TLS** — HTTPS is provisioned automatically with no extra configuration.
- **Deploy hooks** — a single authenticated URL triggers a redeployment, which integrates cleanly into the GitHub Actions pipeline without requiring SSH keys or cloud-specific CLI tools.
- **Free tier** — suitable for a challenge environment with no cost overhead.

The trade-off is that Render abstracts away the underlying VM, so there is no direct SSH access or OS-level control. For a production SaaS at scale, a managed Kubernetes service or EC2 with an AMI pipeline would be more appropriate. For the scope of this challenge, Render satisfies all functional requirements.

---

## 2. How the Virtual Machine / Service Was Set Up

1. Logged into [render.com](https://render.com) and created a new **Web Service**.
2. Selected **Deploy an existing image from a registry**.
3. Set the image URL to:
   ```
   ghcr.io/gery44/deployready_assignment:latest
   ```
   This points to the GitHub Container Registry (GHCR) package that the CI/CD pipeline pushes to on every successful build.
4. Set the environment variable:
   ```
   PORT=3000
   ```
5. Clicked **Deploy Web Service**. Render provisions the container runtime, pulls the image, and starts the service automatically.

The GHCR package visibility was set to **public** (GitHub → Profile → Packages → Package Settings → Change Visibility) so Render can pull it without a registry credential.

---

## 3. How Docker Was Installed and the Image Was Pulled

Render manages the container runtime internally — there is no OS-level Docker installation to perform. The deployment process works as follows:

1. The GitHub Actions pipeline builds the Docker image using the multi-stage `Dockerfile` in the repository root.
2. The image is tagged with the full Git commit SHA (immutable) and with `latest`:
   ```
   ghcr.io/gery44/deployready_assignment:<commit-sha>
   ghcr.io/gery44/deployready_assignment:latest
   ```
3. Both tags are pushed to GHCR.
4. The pipeline then calls the **Render deploy hook** — a secret URL stored as a GitHub repository secret (`RENDER_DEPLOY_HOOK`). This tells Render to pull the `:latest` image and restart the service.
5. Render pulls the new image, stops the old container, and starts the new one with zero downtime.

---

## 4. How to Check if the Container Is Running

**Via the Render dashboard:**
1. Go to [dashboard.render.com](https://dashboard.render.com)
2. Select the `deployready-assignment` service
3. The **Events** tab shows deploy history and current status
4. A green **Live** badge confirms the service is running

**Via the health endpoint:**
```bash
curl https://deployready-assignment-latest.onrender.com/health
```
Expected response:
```json
{"status":"ok"}
```

**Via the metrics endpoint:**
```bash
curl https://deployready-assignment-latest.onrender.com/metrics
```
Expected response:
```json
{"uptime_seconds": <n>, "memory_mb": <n>, "node_version": "v20.14.0"}
```

---

## 5. How to View the Application Logs

**Via the Render dashboard:**
1. Go to [dashboard.render.com](https://dashboard.render.com)
2. Select the `deployready-assignment` service
3. Click the **Logs** tab
4. Logs stream in real time — all stdout/stderr from the Node.js process is captured here

**Via the Render CLI** (optional):
```bash
render logs --service deployready-assignment --tail
```

---

## 6. CI/CD Pipeline Summary

The full delivery pipeline is defined in `.github/workflows/deploy.yml` and runs on every push to `main`:

```
push to main
     │
     ▼
┌─────────────┐
│  Job 1: Test │  npm ci + jest --forceExit
│             │  Pipeline stops here on any test failure
└──────┬──────┘
       │ only if tests pass
       ▼
┌──────────────────┐
│ Job 2: Build &   │  docker build (multi-stage Dockerfile)
│       Push       │  Push to GHCR tagged with commit SHA + latest
└──────┬───────────┘
       │ only if build succeeds
       ▼
┌──────────────────┐
│  Job 3: Deploy   │  curl RENDER_DEPLOY_HOOK
│                  │  Render pulls latest image and restarts service
└──────────────────┘
```

**Secrets stored in GitHub repository settings (never in code):**

| Secret | Purpose |
|---|---|
| `RENDER_DEPLOY_HOOK` | Authenticated Render deploy hook URL |
| `GITHUB_TOKEN` | Auto-generated by Actions — used to push to GHCR |

---

## 7. Verification

All three API endpoints confirmed live at time of submission:

| Endpoint | Method | Response |
|---|---|---|
| `/health` | GET | `{"status":"ok"}` |
| `/metrics` | GET | `{"uptime_seconds":326,"memory_mb":53,"node_version":"v20.14.0"}` |
| `/data` | POST | `{"received":{"shipment_id":"KOR-001","status":"in_transit"}}` |
