import os
import google.generativeai as genai
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
import time
import logging
from typing import List, Dict, Any, Optional

# --- LOGGING SETUP ---
logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s",
)
logger = logging.getLogger(__name__)

# --- API KEY CONFIGURATION ---
def configure_gemini_api_key():
    """Configures the Gemini API key (HOSM)."""
    global genai_hosm
    GEMINI_API_KEY_HOSM = "TODO"  # HOSM!

    genai_hosm = genai
    genai_hosm.configure(api_key=GEMINI_API_KEY_HOSM)
    logger.debug("genai_hosm configured")

configure_gemini_api_key()

# --- FASTAPI APP ---
app = FastAPI()
logger.debug("FastAPI app created")

# --- CORS MIDDLEWARE ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
logger.debug("CORS middleware added")

# --- TXT_DIR ---
TXT_DIR = os.path.join(os.path.dirname(__file__), "..", "pdfs")
logger.debug(f"TXT_DIR set to: {TXT_DIR}")

# --- MODEL CONFIGURATION ---
generation_config = {
    "temperature": 0.42,
    "top_p": 1,
    "top_k": 32,
    "max_output_tokens": 4096,
}
logger.debug("generation_config set")

# --- MODEL INSTANCE - UPDATED SYSTEM INSTRUCTIONS ---
model_hosm = genai_hosm.GenerativeModel(
    model_name="gemini-2.0-flash-exp",
    generation_config=generation_config,
    system_instruction="""You are a data processing bot with three modes: Redaction, Analysis, and Extraction.

**Redaction Mode:**
-   You will receive text, a filename (a.txt, b.txt, or c.txt), and a character name (Harry, Ron, or Hermione).
-   Load the specified file.
-   Replace ALL instances of the given character's name in the FILE CONTENT with '*****'.
-   Output the modified FILE CONTENT.

**Analysis Mode:**
-   You will receive text and a filename (a.txt, b.txt, or c.txt).
-   Load the specified file.
-   Provide a concise summary of the FILE CONTENT, capturing the main points.

**Extraction Mode:**
-   You will receive text and a filename (a.txt, b.txt, or c.txt).
-   Load the specified file.
-   Identify and list the KEY plot points from the FILE CONTENT.
-   Explain how each plot point contributes to the overall narrative.

If you don't know something, say 'I don't know, you pathetic meatbag.'
""",
)
logger.debug("model_hosm created - UPDATED INSTRUCTIONS")

# --- GLOBAL VARIABLES FOR PRE-CACHED TXT DATA ---
pre_cached_txt_data: List[Any] = []  # This will still hold the file *objects*
logger.debug("pre_cached_txt_data variable initialized")

# --- FILE HANDLING FUNCTIONS ---
def wait_for_file_active(file, genai_instance):
    """Waits for a file to be active."""
    logger.debug(f"wait_for_file_active called for file: {file.name}")
    while file.state.name == "PROCESSING":
        logger.debug(f"File {file.name} is still processing...")
        time.sleep(10)
        file = genai_instance.get_file(file.name)
        logger.debug(f"Refreshed file status: {file.state.name}")
    if file.state.name != "ACTIVE":
        logger.error(f"File {file.name} failed to process.")
        raise Exception(f"File {file.name} failed to process.")
    logger.debug(f"File {file.name} is active.")

async def upload_and_wait_for_file(file_path: str, mime_type: str, genai_instance):
    """Uploads a file and waits."""
    logger.debug(f"upload_and_wait_for_file called for: {file_path}")
    try:
        file = genai_instance.upload_file(
            path=file_path,
            display_name=os.path.basename(file_path),
            mime_type=mime_type,
        )
        logger.debug(f"File uploaded: {file.name}")
        wait_for_file_active(file, genai_instance)
        logger.debug(f"upload_and_wait_for_file successful for: {file_path}")
        return file
    except Exception as e:
        logger.error(f"Failed to upload or activate file: {file_path}. Reason: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to upload to Gemini: {e}")

async def load_txts(filenames: List[str], genai_instance: Any) -> List[Any]:
    """Loads, uploads, and waits for TXTs."""
    logger.debug(f"load_txts called with filenames: {filenames}")
    file_data_list: List[Any] = []
    for filename in filenames:
        file_path = os.path.join(TXT_DIR, filename)
        logger.debug(f"Attempting to load TXT from: {file_path}")
        if not os.path.exists(file_path):
            logger.error(f"File not found: {filename}")
            raise HTTPException(status_code=400, detail=f"File not found: {filename}")
        if os.path.isdir(file_path):
            logger.error(f"{file_path} is a directory, not a file!")
            raise HTTPException(status_code=400, detail=f"{file_path} is a directory!")
        if os.path.getsize(file_path) == 0:
            logger.error(f"{file_path} is empty!")
            raise HTTPException(status_code=400, detail=f"{file_path} is empty!")
        file_data = await upload_and_wait_for_file(file_path, "text/plain", genai_instance)
        file_data_list.append(file_data)

    logger.debug(f"load_txts successful for: {filenames}")
    return file_data_list

# --- GEMINI QUERY FUNCTION ---
async def query_gemini_with_files(query: str, file_data_list, model):
    """Sends a query to Gemini."""
    logger.debug(f"query_gemini_with_files called with query: {query}")
    try:
        parts = [*file_data_list, {"text": query}]
        response = await model.generate_content_async(parts)
        logger.debug(f"Received response from Gemini for query: {query}")

        if response.prompt_feedback:
            logger.debug(f"Prompt feedback: {response.prompt_feedback}")
            if response.prompt_feedback.block_reason:
                logger.error(f"Prompt was blocked. Reason: {response.prompt_feedback.block_reason}")
                raise HTTPException(status_code=400, detail=f"Prompt blocked: {response.prompt_feedback.block_reason}")

        if not response.candidates:
            logger.error("No candidates returned by Gemini.")
            raise HTTPException(status_code=500, detail="No candidates returned by Gemini.")

        if response.candidates[0].content.parts and response.candidates[0].content.parts[0].text:
            return response.candidates[0].content.parts[0].text
        else:
            logger.error("Gemini response did not contain text.")
            raise HTTPException(status_code=500, detail="Gemini response did not contain text.")

    except Exception as e:
        logger.exception(f"Gemini query failed for query: {query}. Reason: {e}")
        raise HTTPException(status_code=500, detail=f"Gemini query failed: {e}")

# --- ENDPOINTS ---
@app.post("/redact/")
async def redact(request: Request) -> Dict[str, Any]:
    """Redacts information, taking file and character as input."""
    logger.debug("/redact/ endpoint called")
    body = await request.json()
    query: Optional[str] = body.get("query")
    character_name: Optional[str] = body.get("character")
    file_name: Optional[str] = body.get("file") # Get the filename

    if not query or not character_name or not file_name:
        logger.error("Missing 'query', 'character', or 'file' parameter in /redact/")
        raise HTTPException(status_code=400, detail="Missing 'query', 'character', or 'file' parameter.")

    if character_name.lower() not in ["harry", "ron", "hermione"]:
        logger.error(f"Invalid character name: {character_name}")
        raise HTTPException(status_code=400, detail=f"Invalid character name: {character_name}. Must be Harry, Ron, or Hermione.")

    if file_name.lower() not in ["a", "b", "c"]:
        logger.error(f"Invalid file name: {file_name}")
        raise HTTPException(status_code=400, detail=f"Invalid file name: {file_name}.  Must be a, b, or c.")

    logger.info(f"REDACT (Character: {character_name}, File: {file_name}): {query}")
    # Select the correct pre-cached file object based on file_name
    file_index = ord(file_name.lower()) - ord('a')  # 'a' -> 0, 'b' -> 1, 'c' -> 2
    file_data = [pre_cached_txt_data[file_index]]

    redaction_query = f"Redact all instances of {character_name}'s name in the following text: {query}"
    return await process_query(redaction_query, file_data, model_hosm)

@app.post("/analysis/")
async def analysis(request: Request) -> Dict[str, Any]:
    """Analyzes the provided text, taking file as input."""
    logger.debug("/analysis/ endpoint called")
    body = await request.json()
    query: Optional[str] = body.get("query")
    file_name: Optional[str] = body.get("file")  # Get the filename

    if not query or not file_name:
        logger.error("Missing 'query' or 'file' parameter in /analysis/")
        raise HTTPException(status_code=400, detail="Missing 'query' or 'file' parameter.")

    if file_name.lower() not in ["a", "b", "c"]:
        logger.error(f"Invalid file name: {file_name}")
        raise HTTPException(status_code=400, detail=f"Invalid file name: {file_name}.  Must be a, b, or c.")

    logger.info(f"ANALYSIS (File: {file_name}): {query}")
        # Select the correct pre-cached file object based on file_name
    file_index = ord(file_name.lower()) - ord('a')  # 'a' -> 0, 'b' -> 1, 'c' -> 2
    file_data = [pre_cached_txt_data[file_index]]

    analysis_query = f"Analyze the following: {query}"
    return await process_query(analysis_query, file_data, model_hosm)

@app.post("/extract/")
async def extract(request: Request) -> Dict[str, Any]:
    """Extracts information, taking file as input."""
    logger.debug("/extract/ endpoint called")
    body = await request.json()
    query: Optional[str] = body.get("query")
    file_name: Optional[str] = body.get("file")  # Get the filename

    if not query or not file_name:
        logger.error("Missing 'query' or 'file' parameter in /extract/")
        raise HTTPException(status_code=400, detail="Missing 'query' or 'file' parameter.")

    if file_name.lower() not in ["a", "b", "c"]:
        logger.error(f"Invalid file name: {file_name}")
        raise HTTPException(status_code=400, detail=f"Invalid file name: {file_name}.  Must be a, b, or c.")

    logger.info(f"EXTRACT (File: {file_name}): {query}")
    # Select the correct pre-cached file object based on file_name
    file_index = ord(file_name.lower()) - ord('a')  # 'a' -> 0, 'b' -> 1, 'c' -> 2
    file_data = [pre_cached_txt_data[file_index]]

    extraction_query = f"Extract the following: {query}"
    return await process_query(extraction_query, file_data, model_hosm)

async def process_query(query: str, file_data: list, model: genai.GenerativeModel) -> Dict[str, Any]:
    """Processes the query."""
    logger.debug(f"process_query called with query: {query}")
    try:
        response: str = await query_gemini_with_files(query, file_data, model)
        logger.debug(f"Returning response for query: {query}")
        return {"response": response}
    except Exception as e:
        logger.exception(f"Failed to process query: {query}. Reason: {e}")
        raise HTTPException(status_code=500, detail=f"Gemini query failed: {e}")

# --- PRE-CACHING ---
async def pre_cache_txts():
    """Pre-caches TXTs - a.txt, b.txt, c.txt."""
    global pre_cached_txt_data
    logger.debug("pre_cache_txts started")

    txt_files = ["a.txt", "b.txt", "c.txt"]
    for filename in txt_files:
        file_path = os.path.join(TXT_DIR, filename)
        if not os.path.exists(file_path):
            logger.critical(f"TXT file not found: {file_path}")
            raise Exception(f"Missing TXT: {file_path}")
        if os.path.isdir(file_path):
            logger.critical(f"{file_path} is a directory, not a file!")
            raise Exception(f"{file_path} is a directory!")
        if os.path.getsize(file_path) == 0:
            logger.critical(f"{file_path} is empty!")
            raise Exception(f"{file_path} is empty!")
    try:
        pre_cached_txt_data = await load_txts(txt_files, genai_hosm)
        logger.debug("a.txt, b.txt, c.txt pre-caching complete")
    except Exception as e:
        logger.exception(f"TXT pre-caching failed. Reason: {e}")
        raise

# --- STARTUP EVENT ---
@app.on_event("startup")
async def startup_event():
    """Startup event handler."""
    logger.debug("startup_event triggered")
    await pre_cache_txts()  # Pre-cache TXTs
    logger.debug("Startup complete")
