from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
import httpx
import os
from dotenv import load_dotenv
import re
import time

# Load environment variables
load_dotenv()

app = FastAPI(
    title="MotherTongue Translation API",
    description="Backend for MotherTongue app using Sarvam AI translation",
    version="1.0.0"
)

# CORS configuration - allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Sarvam API configuration
SARVAM_API_KEY = os.getenv("SARVAM_API_KEY")
SARVAM_API_URL = "https://api.sarvam.ai/translate"
SARVAM_TIMEOUT = 30  # seconds

if not SARVAM_API_KEY:
    print("WARNING: SARVAM_API_KEY not found in environment variables")

# Language code mapping: UI names to Sarvam API codes
LANGUAGE_CODE_MAP = {
    "hindi": "hi-IN",
    "english": "en-IN",
    "kannada": "kn-IN",
    "tamil": "ta-IN",
    "telugu": "te-IN",
    "malayalam": "ml-IN",
    "marathi": "mr-IN",
    "bengali": "bn-IN",
    "gujarati": "gu-IN",
    "punjabi": "pa-IN",
    "odia": "od-IN",
    "assamese": "as-IN",
    "bodo": "brx-IN",
    "dogri": "doi-IN",
    "konkani": "kok-IN",
    "kashmiri": "ks-IN",
    "maithili": "mai-IN",
    "manipuri": "mni-IN",
    "nepali": "ne-IN",
    "sanskrit": "sa-IN",
    "santali": "sat-IN",
    "sindhi": "sd-IN",
    "urdu": "ur-IN",
    # Also support direct codes
    "hi-IN": "hi-IN",
    "en-IN": "en-IN",
    "kn-IN": "kn-IN",
    "ta-IN": "ta-IN",
    "te-IN": "te-IN",
    "ml-IN": "ml-IN",
    "mr-IN": "mr-IN",
    "bn-IN": "bn-IN",
    "gu-IN": "gu-IN",
    "pa-IN": "pa-IN",
    "od-IN": "od-IN",
    "as-IN": "as-IN",
    "brx-IN": "brx-IN",
    "doi-IN": "doi-IN",
    "kok-IN": "kok-IN",
    "ks-IN": "ks-IN",
    "mai-IN": "mai-IN",
    "mni-IN": "mni-IN",
    "ne-IN": "ne-IN",
    "sa-IN": "sa-IN",
    "sat-IN": "sat-IN",
    "sd-IN": "sd-IN",
    "ur-IN": "ur-IN",
    "auto": "auto",
}

def normalize_language_code(lang: str) -> str:
    """Convert language name or code to Sarvam API code."""
    lang_lower = lang.lower()
    return LANGUAGE_CODE_MAP.get(lang_lower, lang)


class TextBlock(BaseModel):
    """A single text block with bounding box coordinates."""
    text: str = Field(..., description="The text content to translate")
    x: float = Field(..., description="Left coordinate")
    y: float = Field(..., description="Top coordinate")
    width: float = Field(..., description="Width of the bounding box")
    height: float = Field(..., description="Height of the bounding box")


class TranslationRequest(BaseModel):
    """Request model for translation."""
    text_blocks: List[TextBlock] = Field(..., description="List of text blocks to translate")
    source_language: str = Field(..., description="Source language code (e.g., hi-IN, en-IN)")
    target_language: str = Field(..., description="Target language code (e.g., kn-IN)")


class TranslatedBlock(BaseModel):
    """A translated text block with original bounding box."""
    text: str = Field(..., description="The translated text")
    x: float = Field(..., description="Left coordinate")
    y: float = Field(..., description="Top coordinate")
    width: float = Field(..., description="Width of the bounding box")
    height: float = Field(..., description="Height of the bounding box")


class TranslationResponse(BaseModel):
    """Response model for translation."""
    translated_blocks: List[TranslatedBlock] = Field(..., description="Translated text blocks")
    source_language: str = Field(..., description="Source language used")
    target_language: str = Field(..., description="Target language used")
    processing_time_ms: float = Field(..., description="Processing time in milliseconds")


def is_mathematical_content(text: str) -> bool:
    """
    Check if text is primarily mathematical content.
    Preserves numbers, operators, equations, and variables.
    """
    # Pattern for mathematical expressions: digits, operators, parentheses, and single-letter variables
    # Only matches if text is primarily mathematical (no multi-letter words)
    math_pattern = r'^[\d\s+\-*/=()\[\]{}.,xXyYzZ]+$'
    return bool(re.match(math_pattern, text.strip()))


async def call_sarvam_api(text: str, source_lang: str, target_lang: str) -> str:
    """
    Call Sarvam AI translation API for a single text.
    
    Args:
        text: Text to translate
        source_lang: Source language code
        target_lang: Target language code
    
    Returns:
        Translated text
    
    Raises:
        HTTPException: If API call fails
    """
    if not SARVAM_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="SARVAM_API_KEY not configured on server"
        )
    
    # Preserve mathematical content
    if is_mathematical_content(text):
        return text
    
    # Normalize language codes
    source_code = normalize_language_code(source_lang)
    target_code = normalize_language_code(target_lang)
    
    payload = {
        "source_language_code": source_code if source_code != "auto" else "auto",
        "target_language_code": target_code,
        "input": text,  # Sarvam API expects "input" not "text"
        "speaker_gender": "Female",
        "mode": "formal",
        "model": "mayura:v1"
    }
    
    headers = {
        "Content-Type": "application/json",
        "api-subscription-key": SARVAM_API_KEY
    }
    
    async with httpx.AsyncClient(timeout=SARVAM_TIMEOUT) as client:
        try:
            print(f"Calling Sarvam API: source={source_code}, target={target_code}, text_length={len(text)}")
            response = await client.post(
                SARVAM_API_URL,
                json=payload,
                headers=headers
            )
            
            if response.status_code != 200:
                # Log the error response for debugging (without exposing API key)
                try:
                    error_body = response.json()
                    print(f"Sarvam API error {response.status_code}: {error_body}")
                except:
                    print(f"Sarvam API error {response.status_code}: {response.text}")
                
                error_detail = f"Sarvam API error: {response.status_code}"
                raise HTTPException(
                    status_code=response.status_code,
                    detail=error_detail
                )
            
            data = response.json()
            translated_text = data.get("translated_text", text)
            return translated_text
            
        except httpx.TimeoutException:
            raise HTTPException(
                status_code=504,
                detail="Translation request timed out"
            )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=503,
                detail=f"Failed to connect to translation service: {str(e)}"
            )


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "service": "MotherTongue Translation API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "translate": "/translate",
            "health": "/health"
        }
    }


@app.get("/health")
async def health():
    """Health check endpoint."""
    return {
        "status": "healthy",
        "sarvam_configured": bool(SARVAM_API_KEY)
    }


@app.post("/translate", response_model=TranslationResponse)
async def translate(request: TranslationRequest):
    """
    Translate text blocks using Sarvam AI API.
    
    Args:
        request: Translation request with text blocks and language codes
    
    Returns:
        Translation response with translated blocks
    
    Raises:
        HTTPException: If translation fails
    """
    if not request.text_blocks:
        raise HTTPException(
            status_code=400,
            detail="No text blocks provided for translation"
        )
    
    # Normalize language codes
    normalized_source = normalize_language_code(request.source_language)
    normalized_target = normalize_language_code(request.target_language)
    
    print(f"Translation request: source={request.source_language} -> {normalized_source}, target={request.target_language} -> {normalized_target}, blocks={len(request.text_blocks)}")
    
    start_time = time.time()
    translated_blocks = []
    
    try:
        # Translate each text block
        for i, block in enumerate(request.text_blocks):
            if not block.text or not block.text.strip():
                print(f"Warning: Empty text block at index {i}, skipping")
                continue
            
            translated_text = await call_sarvam_api(
                block.text,
                normalized_source,
                normalized_target
            )
            
            translated_blocks.append(TranslatedBlock(
                text=translated_text,
                x=block.x,
                y=block.y,
                width=block.width,
                height=block.height
            ))
        
        if not translated_blocks:
            raise HTTPException(
                status_code=400,
                detail="No valid text blocks to translate after filtering empty blocks"
            )
        
        processing_time = (time.time() - start_time) * 1000  # Convert to milliseconds
        
        return TranslationResponse(
            translated_blocks=translated_blocks,
            source_language=normalized_source,
            target_language=normalized_target,
            processing_time_ms=processing_time
        )
        
    except HTTPException:
        raise
    except Exception as e:
        # Log error without exposing sensitive information
        print(f"Translation error: {str(e)}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected error occurred during translation: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
