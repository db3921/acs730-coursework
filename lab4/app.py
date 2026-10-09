from flask import Flask

app = Flask(__name__)


@app.get("/")
def index():
    return "Hello from ACS730 lab 4\n"


@app.get("/health")
def health():
    return {"status": "ok"}


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
