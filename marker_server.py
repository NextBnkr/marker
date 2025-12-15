import os
import io
import base64
import tempfile
import shutil
import urllib.request
import traceback

import runpod

from marker.config.parser import ConfigParser
from marker.output import text_from_rendered
from marker.converters.pdf import PdfConverter
from marker.models import create_model_dict
from marker.settings import settings

MODELS = create_model_dict()

def convert(common_params):
    options = dict(common_params or {})
    if "output_format" not in options:
        options["output_format"] = "markdown"
    fmt = options.get("output_format")
    assert fmt in ["markdown", "json", "html", "chunks"]
    config_parser = ConfigParser(options)
    config_dict = config_parser.generate_config_dict()
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
    try:
        job_input = event.get("input", {}) if isinstance(event, dict) else {}
        pdf_url = job_input.get("pdf_url")
        common_params = job_input.get("common_params") or {}
        tmp_path = None
        if pdf_url:
            fd, tmp_path = tempfile.mkstemp(suffix=".pdf")
            os.close(fd)
            username = os.getenv("BASIC_AUTH_USERNAME")
            password = os.getenv("BASIC_AUTH_PASSWORD")
            if username and password:
                token = base64.b64encode(f"{username}:{password}".encode()).decode()
                req = urllib.request.Request(pdf_url, headers={"Authorization": f"Basic {token}"})
            else:
                req = urllib.request.Request(pdf_url)
            with urllib.request.urlopen(req) as r, open(tmp_path, "wb") as f:
                shutil.copyfileobj(r, f)
            common_params["filepath"] = tmp_path
        result = convert(common_params)
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
        return result
    except Exception as e:
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e),
        }

if __name__ == "__main__":
    if os.getenv("RUN_LOCAL") == "1":
        test_url = os.getenv("TEST_PDF_URL")
        test_filepath = os.getenv("TEST_FILEPATH")
        event = {"input": {"pdf_url": test_url}} if test_url else {"input": {"common_params": {"filepath": test_filepath, "output_format": "markdown"}}}
        print(handler(event))
    else:
        runpod.serverless.start({"handler": handler})
