# Deploying Godot Demo Projects on Render

This guide walks you through deploying all Godot demo projects as a web application on [Render](https://render.com). The demos are exported to HTML5/WebAssembly and served via Nginx.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [How It Works](#how-it-works)
3. [Option A – One-Click Blueprint Deploy](#option-a--one-click-blueprint-deploy)
4. [Option B – Manual Docker Service Setup](#option-b--manual-docker-service-setup)
5. [Option C – Pre-Built Static Site Deploy](#option-c--pre-built-static-site-deploy)
6. [Important Configuration Details](#important-configuration-details)
7. [Troubleshooting](#troubleshooting)
8. [Cost Considerations](#cost-considerations)

---

## Prerequisites

- A [Render account](https://dashboard.render.com/register) (free tier available, but see [Cost Considerations](#cost-considerations)).
- This repository pushed to **GitHub** or **GitLab** (Render connects to both).

---

## How It Works

The deployment uses a **multi-stage Docker build**:

| Stage | What happens |
|-------|-------------|
| **Stage 1 – Builder** | Uses the `barichello/godot-ci:4.5.1` Docker image to export every compatible demo project to HTML5/WebAssembly. Incompatible demos (Mono, mobile-only, compute-shader, networking, XR) are excluded automatically. |
| **Stage 2 – Server** | Copies the exported files into an `nginx:alpine` container and serves them on port `10000` (Render's default) with the required COOP/COEP headers for `SharedArrayBuffer` support. |

---

## Option A – One-Click Blueprint Deploy

This is the easiest method. Render will auto-detect the included `render.yaml` file.

### Steps

1. **Push this repository** to your GitHub or GitLab account (fork or clone).

2. **Go to Render Dashboard** → [Blueprints](https://dashboard.render.com/blueprints).

3. Click **"New Blueprint Instance"**.

4. **Connect your repository** — select the repo containing this code.

5. Render detects `render.yaml` and shows the service it will create:
   - **Name:** `godot-demo-projects`
   - **Type:** Web Service (Docker)
   - **Plan:** Standard

6. Click **"Apply"** and wait for the build to complete.

7. Once deployed, Render provides a URL like:
   ```
   https://godot-demo-projects-xxxx.onrender.com
   ```
   Open it in your browser to see all the demos.

---

## Option B – Manual Docker Service Setup

If you prefer to configure the service manually instead of using the blueprint:

### Steps

1. **Push this repository** to GitHub or GitLab.

2. Go to [Render Dashboard](https://dashboard.render.com/) → **"New +"** → **"Web Service"**.

3. **Connect your repository.**

4. Configure the service:

   | Setting | Value |
   |---------|-------|
   | **Name** | `godot-demo-projects` (or any name you prefer) |
   | **Region** | Choose the closest to your users |
   | **Branch** | `master` (or your default branch) |
   | **Runtime** | **Docker** |
   | **Dockerfile Path** | `./Dockerfile` |
   | **Plan** | **Standard** or higher (see [Cost Considerations](#cost-considerations)) |

5. Under **Advanced** settings, verify:
   - **Docker Command:** leave empty (the Dockerfile has its own `CMD`)
   - **Health Check Path:** `/`

6. Click **"Create Web Service"**.

7. Wait for the build to finish (first build can take **15–30 minutes** because Godot exports every demo).

8. Access your site at the provided `.onrender.com` URL.

---

## Option C – Pre-Built Static Site Deploy

If you want a **faster deploy** and **free tier** hosting, you can export locally and deploy as a static site.

### Steps

1. **Export locally** using Docker on your machine:
   ```bash
   # Build the full image (this runs the Godot exports)
   docker build -t godot-demos .

   # Copy the exported files out of the image
   docker create --name temp-godot godot-demos
   docker cp temp-godot:/usr/share/nginx/html ./dist
   docker rm temp-godot
   ```

2. **Push the `dist/` folder** to a new branch or repository.

3. Go to Render Dashboard → **"New +"** → **"Static Site"**.

4. Connect your repo and set:

   | Setting | Value |
   |---------|-------|
   | **Build Command** | _(leave empty)_ |
   | **Publish Directory** | `dist` |

5. Under **Headers**, add these response headers (required for Godot's threading):

   | Path | Header | Value |
   |------|--------|-------|
   | `/*` | `Cross-Origin-Opener-Policy` | `same-origin` |
   | `/*` | `Cross-Origin-Embedder-Policy` | `require-corp` |

6. Click **"Create Static Site"** — deployment takes only seconds.

---

## Important Configuration Details

### Required HTTP Headers

Godot 4.x Web exports use `SharedArrayBuffer` for threading, which requires these response headers on **every page**:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

The provided `Dockerfile` and Nginx config already set these headers. If you deploy via a CDN or reverse proxy, make sure they are not stripped.

### Port

Render expects web services to listen on port **10000**. The Nginx config in the Dockerfile is already set to listen on this port.

### Build Resources

The Godot export process is resource-intensive:
- **RAM:** Each export can use 1–2 GB. The Standard plan (2 GB RAM) is recommended.
- **Disk:** The exported files total approximately 500 MB–1 GB.
- **Time:** First build takes 15–30 minutes. Subsequent builds use Docker layer caching and are faster.

### Custom Domain

1. In your Render service dashboard, go to **Settings** → **Custom Domains**.
2. Add your domain (e.g., `demos.yourdomain.com`).
3. Add the DNS records Render provides (CNAME or A record).
4. Render automatically provisions a TLS certificate via Let's Encrypt.

---

## Troubleshooting

### Black screen or "SharedArrayBuffer not available" error

The COOP/COEP headers are missing. Verify they are being sent:
```bash
curl -I https://your-service.onrender.com/
```
Look for `cross-origin-opener-policy` and `cross-origin-embedder-policy` in the response.

### Build fails with "Out of Memory"

Upgrade to the **Standard** plan or higher. The Free plan (512 MB RAM) is not enough for Godot exports.

### Build times out

Render has a default build timeout of 1 hour. The build should complete well within that, but if it doesn't:
- Go to **Settings** → **Build & Deploy** → increase the build timeout.

### Demos don't load / 404 errors

Make sure the Nginx `try_files` directive is working. Check the Render logs:
- Dashboard → your service → **Logs** tab.

### WASM file not loading

Verify the MIME type `application/wasm` is being served for `.wasm` files. The Nginx config in the Dockerfile handles this.

---

## Cost Considerations

| Render Plan | RAM | Suitable? | Monthly Cost (approx.) |
|-------------|-----|-----------|----------------------|
| **Free** | 512 MB | No — build will fail (OOM) | $0 |
| **Starter** | 1 GB | Possible but tight | ~$7 |
| **Standard** | 2 GB | Recommended | ~$25 |
| **Pro** | 4 GB | Comfortable | ~$85 |

**Tip:** Use [Option C (Static Site)](#option-c--pre-built-static-site-deploy) to export locally and deploy for free on Render's static site hosting.

---

## Updating

When you push new commits to your connected branch, Render will automatically rebuild and redeploy. To trigger a manual deploy:

1. Go to your service in the Render dashboard.
2. Click **"Manual Deploy"** → **"Deploy latest commit"**.
