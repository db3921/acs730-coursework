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

## Why GHCR, tagged by commit SHA

The image is pushed to GHCR as `ghcr.io/db3921/acs730-lab4:sha-<12 characters of the commit>`. A SHA tag points at exactly one commit forever, so you can always tell which code is in a running image; `latest` would point at whatever was pushed last. Only the job that pushes has `packages: write`; every other job can only read.

## Composite action vs reusable workflow

The dependency setup is a composite action (`.github/actions/python-deps`) because it is a few steps that must run on the same runner as the tests, inside the existing test job. The image build is a reusable workflow (`.github/workflows/docker-build.yml`) because it is a whole job that needs `packages: write`, a permission the test job must not have.

## GitHub Actions vs AWS-native

The AWS-native equivalent of this pipeline is CodePipeline for the job graph, CodeBuild for the runners and ECR in place of GHCR. With GitHub Actions the runners are GitHub-hosted and the GHCR push uses the automatic, short-lived `GITHUB_TOKEN`; with CodeBuild the runners live in your AWS account and need an IAM service role. In an AWS Academy account, IAM writes are denied, so those service roles cannot be created. My recommendation for this course is GitHub Actions; in a real AWS account, the AWS-native tools are a reasonable choice when you want builds and images to stay inside AWS.

## Experiments

**1. Invert the layer order.** Prediction: moving `COPY app.py` above the requirements lines would make `pip install` re-run after any code change. Result: after a one-word edit to `app.py`, `pip install` re-ran and the rebuild took 4.6s, compared with 0.6s in the correct order. Because Docker rebuilds every layer after a changed one, the position of that one `COPY` decides whether every future code change also reinstalls all dependencies.

**2. Delete the .dockerignore.** Prediction: the build context would grow but the final image would not. Result: the image stayed at 130 MB with only `app.py` and `requirements.txt` in `/app`, and the context stayed at 473 B, because this Dockerfile copies those two files by name and the builder only sends files it needs. The naive Dockerfile uses `COPY . .`, so without a `.dockerignore` it would copy everything in the folder, including the README, screenshots and Dockerfiles, into the image.
