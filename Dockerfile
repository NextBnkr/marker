FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

WORKDIR /app
RUN apt-get update && apt-get install -y python3.11 python3-pip curl && rm -rf /var/lib/apt/lists/*
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"
COPY pyproject.toml poetry.lock* ./
RUN poetry config virtualenvs.in-project true && poetry install --no-root
COPY . .
ENV PORT=8000
EXPOSE 8000
CMD ["sh","-lc","ln -sfn /workspace /root/.cache/datalab && .venv/bin/python ./marker_server.py --host 0.0.0.0 --port ${PORT:-8000}"]

