FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404
RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"
WORKDIR /app
COPY pyproject.toml poetry.lock* ./
RUN poetry config virtualenvs.in-project true \
  && poetry install --no-root
COPY . .

