# Lab 4: Docker Fundamentals and GitHub Actions

## Build and run

~~~bash
cd lab4
docker build -t acs730-lab4:slim .
docker run -d --name lab4 -p 8000:8000 acs730-lab4:slim
curl http://localhost:8000/healthz
~~~

## Image size: naive vs shipped

| Image | Base image | Size | Rebuild after a one-line code change |
|---|---|---|---|
| naive | python:latest | 1.15 GB | 6.9s (pip install re-ran) |
| slim | python:3.12-slim-bookworm | 130 MB | 0.6s (pip install CACHED) |

- **Base image:** almost all of the ~1.02 GB difference comes from the base image. `python:latest` is 1.13 GB and `python:3.12-slim-bookworm` is 124 MB, so the app and its dependencies add only about 6–20 MB on top of either.
- **Dependency layer:** on a code-only rebuild, `pip install` was CACHED in the slim image but re-ran in the naive image, because the naive Dockerfile copies the source (`COPY . .`) before installing dependencies.
- **.dockerignore:** it kept `.git`, `.github`, Python cache files, `evidence/`, screenshots, Markdown files and the Dockerfiles out of the build context, so only `app.py` and `requirements.txt` reach the image.

## CI timings: baseline vs cache miss vs cache hit

| Step | Baseline (no cache) | Cache miss | Cache hit | Worth it? |
|---|---|---|---|---|
| pip install (3.11 / 3.12) | 4s / 4s | 2s / 3s | 1s / 2s | Marginal |
| docker build | 14s | 15s (+2s to save the cache) | 5s | Yes |
| Whole workflow (wall clock) | 1m 2s | 1m 8s | 53s | Yes |

Runs: baseline 39896893146, miss 39897954504, hit 39898880267. The hit run's log shows "Cache restored from key" for pip and "importing cache manifest from gha" for Docker.

- **pip cache:** marginal. It saves about 2 seconds per test job, because this app only installs three small packages; it would matter much more with many or large dependencies, and it costs almost nothing to keep.
- **Docker layer cache:** worth it. It cut the build step from 14s to 5s by reusing the base image and `pip install` layers; the cache-miss run was slightly slower than baseline because it also had to save the cache.
