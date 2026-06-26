FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404
WORKDIR /app
RUN apt-get update && apt-get install -y python3.11 python3-pip curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"
COPY pyproject.toml poetry.lock* ./
RUN poetry config virtualenvs.in-project true && poetry install --no-root
COPY . .
 
# AWS CLI v2 + 阿里云 OSS 兼容性：关闭自动 checksum
ENV AWS_REQUEST_CHECKSUM_CALCULATION=when_required
 
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
CMD ["/app/entrypoint.sh"]
