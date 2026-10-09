# Lab 4

Instructions for this section will be provided in class and on Blackboard when we reach it.

Put your work for Lab 4 in this folder.


# Lab 4: Docker Fundamentals and GitHub Actions

## Image size: before and after

| Image | Dockerfile | Base image | Size |
|---|---|---|---|
| lab4:naive | Dockerfile.naive | python:3.11 (full) | 1.12 GB |
| lab4:slim | Dockerfile | python:3.11.13-slim | 130 MB |

The shipped image is about 88% smaller (roughly 8.6x). Most of the saving comes
from the slim base image, which leaves out compilers and build tools the app
doesn't need at runtime. `--no-cache-dir` and the `.dockerignore` trim it further.

