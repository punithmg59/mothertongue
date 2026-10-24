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
    
    payload = {
        "source_language_code": source_lang if source_lang != "auto" else "auto",
        "target_language_code": target_lang,
        "text": text,
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
            response = await client.post(
                SARVAM_API_URL,
                json=payload,
                headers=headers
            )
            
            if response.status_code != 200:
                error_detail = f"Sarvam API error: {response.status_code}"
                # Don't expose API key in error messages
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
    
    start_time = time.time()
    translated_blocks = []
    
    try:
        # Translate each text block
        for block in request.text_blocks:
            translated_text = await call_sarvam_api(
                block.text,
                request.source_language,
                request.target_language
            )
            
            translated_blocks.append(TranslatedBlock(
                text=translated_text,
                x=block.x,
                y=block.y,
                width=block.width,
                height=block.height
            ))
        
        processing_time = (time.time() - start_time) * 1000  # Convert to milliseconds
        
        return TranslationResponse(
            translated_blocks=translated_blocks,
            source_language=request.source_language,
            target_language=request.target_language,
            processing_time_ms=processing_time
        )
        
    except HTTPException:
        raise
    except Exception as e:
        # Log error without exposing sensitive information
        print(f"Translation error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail="An unexpected error occurred during translation"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
