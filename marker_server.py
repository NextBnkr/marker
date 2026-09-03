import os
import io
import base64
import http.client
import logging
import socket
import tempfile
import shutil
import time
import urllib.request
import urllib.error
import traceback

import runpod

from marker.config.parser import ConfigParser
from marker.output import text_from_rendered
from marker.converters.pdf import PdfConverter
from marker.models import create_model_dict
from marker.settings import settings

MODELS = create_model_dict()

PDF_DOWNLOAD_TIMEOUT_SECONDS = 30
PDF_DOWNLOAD_MAX_RETRIES = 3
PDF_DOWNLOAD_RETRY_BACKOFF_SECONDS = 2
RETRYABLE_HTTP_STATUS_CODES = {408, 429, 500, 502, 503, 504}


class EmptyDownloadError(RuntimeError):
    pass


def _download_pdf(pdf_url, destination, headers=None):
    """Download a PDF with bounded retries for transient network failures."""
    part_path = f"{destination}.part"
    request = urllib.request.Request(pdf_url, headers=headers or {})

    try:
        for attempt in range(1, PDF_DOWNLOAD_MAX_RETRIES + 1):
            try:
                with urllib.request.urlopen(
                    request, timeout=PDF_DOWNLOAD_TIMEOUT_SECONDS
                ) as response, open(part_path, "wb") as output:
                    shutil.copyfileobj(response, output)

                if os.path.getsize(part_path) == 0:
                    raise EmptyDownloadError("downloaded PDF is empty")
                os.replace(part_path, destination)
                return
            except urllib.error.HTTPError as exc:
                retryable = exc.code in RETRYABLE_HTTP_STATUS_CODES
                if not retryable or attempt == PDF_DOWNLOAD_MAX_RETRIES:
                    raise
                error = f"HTTP {exc.code}"
            except (
                urllib.error.URLError,
                socket.timeout,
                TimeoutError,
                ConnectionError,
                http.client.HTTPException,
                EmptyDownloadError,
            ) as exc:
                if attempt == PDF_DOWNLOAD_MAX_RETRIES:
                    raise
                error = type(exc).__name__

            logging.warning(
                "PDF download attempt %s/%s failed: %s; retrying",
                attempt,
                PDF_DOWNLOAD_MAX_RETRIES,
                error,
            )
            time.sleep(PDF_DOWNLOAD_RETRY_BACKOFF_SECONDS * attempt)
    finally:
        if os.path.exists(part_path):
            os.remove(part_path)


def convert(common_params):
    options = dict(common_params or {})
    if "output_format" not in options:
        options["output_format"] = "markdown"
    fmt = options.get("output_format")
    assert fmt in ["markdown", "json", "html", "chunks"]
    config_parser = ConfigParser(options)
    config_dict = config_parser.generate_config_dict()
    if "force_ocr" in options:
        config_dict["force_ocr"] = bool(options["force_ocr"]) 
    config_dict["pdftext_workers"] = 1
    converter = PdfConverter(
        config=config_dict,
        artifact_dict=MODELS,
        processor_list=config_parser.get_processors(),
        renderer=config_parser.get_renderer(),
        llm_service=config_parser.get_llm_service(),
    )
    rendered = converter(options.get("filepath"))
    text, _, images = text_from_rendered(rendered)
    metadata = rendered.metadata
    encoded = {}
    for k, v in images.items():
        bs = io.BytesIO()
        v.save(bs, format=settings.OUTPUT_IMAGE_FORMAT)
        encoded[k] = base64.b64encode(bs.getvalue()).decode(settings.OUTPUT_ENCODING)
    return {
        "format": fmt,
        "output": text,
        "images": encoded,
        "metadata": metadata,
        "success": True,
    }

def handler(event):
    tmp_path = None
    try:
        job_input = event.get("input", {}) if isinstance(event, dict) else {}
        pdf_url = job_input.get("pdf_url")
        common_params = job_input.get("common_params") or {}
        if pdf_url:
            fd, tmp_path = tempfile.mkstemp(suffix=".pdf")
            os.close(fd)
            username = os.getenv("BASIC_AUTH_USERNAME")
            password = os.getenv("BASIC_AUTH_PASSWORD")
            if username and password:
                token = base64.b64encode(f"{username}:{password}".encode()).decode()
                headers = {"Authorization": f"Basic {token}"}
            else:
                headers = {}
            _download_pdf(pdf_url, tmp_path, headers=headers)
            common_params["filepath"] = tmp_path
        result = convert(common_params)
        return result
    except Exception as e:
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e),
        }
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)


if __name__ == "__main__":
    if os.getenv("RUN_LOCAL") == "1":
        test_url = os.getenv("TEST_PDF_URL")
        test_filepath = os.getenv("TEST_FILEPATH")
        event = {"input": {"pdf_url": test_url}} if test_url else {"input": {"common_params": {"filepath": test_filepath, "output_format": "markdown"}}}
        print(handler(event))
    else:
        runpod.serverless.start({"handler": handler})
