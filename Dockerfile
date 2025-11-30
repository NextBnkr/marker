FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

# Clone the repo, install Poetry, configure, and install dependencies
RUN bash -c '\
  curl -sSL https://install.python-poetry.org | python3 - && \
  export PATH="/root/.local/bin:$PATH" && \
  poetry config virtualenvs.in-project true && \
  poetry install \
'
