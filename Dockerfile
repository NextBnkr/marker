FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

WORKDIR /app
RUN apt-get update && apt-get install -y python3.11 python3-pip curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"
COPY pyproject.toml poetry.lock* ./
RUN poetry config virtualenvs.in-project true && poetry install --no-root
COPY . .
CMD ["sh","-lc","mkdir -p /root/.cache/datalab/models && aws s3 cp s3://cgsejtyd4d/models /root/.cache/datalab/models --recursive --endpoint-url https://s3api-eu-ro-1.runpod.io --region eu-ro-1 && .venv/bin/python ./marker_server.py"]
