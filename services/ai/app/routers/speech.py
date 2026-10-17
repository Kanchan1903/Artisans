"""Speech router: Speech-to-Text (ASR) and Text-to-Speech (TTS) for 12 Indian languages."""
from pydantic import BaseModel, Field
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, Query, status
from app.speech.service import (
    transcribe_with_resilient_fallback,
    synthesize_with_resilient_fallback,
    get_provider_status,
    verify_language_support,
    SUPPORTED_LANGUAGES,
    TranscriptionResult,
    SynthesisResult,
)

router = APIRouter(prefix="/ai", tags=["Speech Engine"])


class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1)
    language: str = Field(default="hi")
    simulate_failure: bool = False


@router.get("/providers")
async def get_speech_providers():
    """Check provider status, language capability matrices, and configured credentials."""
    return {
        "status": "success",
        "supported_languages": SUPPORTED_LANGUAGES,
        "providers": get_provider_status(),
    }


@router.post("/transcribe", response_model=TranscriptionResult)
async def transcribe_audio(
    file: UploadFile | None = File(None),
    language: str = Form("hi"),
    simulate_failure: bool = Form(False),
):
    """
    Transcribe spoken voice recording from artisan into text.
    Supports all 12 Indian languages using Bhashini / Google / high-fidelity mock.
    Performs verified fallback if primary provider credentials or language support are absent.
    """
    lang = language.lower()
    if lang not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Language '{language}' is not supported. Supported: {', '.join(SUPPORTED_LANGUAGES)}",
        )

    audio_bytes = b""
    if file:
        audio_bytes = await file.read()

    try:
        result = await transcribe_with_resilient_fallback(
            audio_bytes=audio_bytes,
            language=lang,
            simulate_failure=simulate_failure,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")


@router.post("/synthesize", response_model=SynthesisResult)
async def synthesize_speech(payload: TTSRequest):
    """
    Convert text back to spoken voice audio for low-literacy artisans in their native language.
    Returns base64 WAV audio stream.
    """
    lang = payload.language.lower()
    if lang not in SUPPORTED_LANGUAGES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Language '{payload.language}' is not supported. Supported: {', '.join(SUPPORTED_LANGUAGES)}",
        )

    try:
        result = await synthesize_with_resilient_fallback(
            text=payload.text,
            language=lang,
            simulate_failure=payload.simulate_failure,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Speech synthesis failed: {str(e)}")
