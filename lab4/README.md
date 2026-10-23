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
