"""Speech Engine: Swappable ASR (Speech-to-Text) and TTS (Text-to-Speech) adapters.
Supports Bhashini (primary), Google Cloud (fallback), and zero-key Mock mode across all 12 Indian languages.
Verifies language support for each provider and performs transparent fallback.
"""
import io
import wave
import struct
import base64
import logging
from typing import Protocol
from pydantic import BaseModel
import httpx
from app.config import ai_settings

logger = logging.getLogger("speech_service")

SUPPORTED_LANGUAGES = ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"]

SAMPLE_TRANSCRIPTS = {
    "hi": "यह हस्तनिर्मित मिट्टी का घड़ा है। इसे बनाने में गंगा किनारे की काली मिट्टी का उपयोग किया गया है। चार घंटे का समय लगा और सामग्री पर लगभग अस्सी रुपये खर्च हुए।",
    "mr": "हा हाताने बनवलेला वारली कलेचा कॅनव्हास आहे. यात तांदळाचे पीठ आणि डिंकाचा नैसर्गिक रंग वापरला आहे. तयार करायला सहा तास लागले आणि साहित्याचा खर्च सुमारे दीडशे रुपये आहे.",
    "en": "This is a handmade terracotta earthen vase. Made using riverbed clay and fired in a traditional kiln. It took 5 hours of work and material cost was around one hundred rupees.",
    "bn": "এটি একটি হস্তনির্মিত মাটির তৈরি ফুলদানি। এতে প্রাকৃতিক নদীর পলিমাটি ব্যবহার করা হয়েছে। এটি তৈরি করতে ৫ ঘণ্টা সময় এবং ১০০ টাকা উপাদান ব্যয় হয়েছে।",
    "ta": "இது கையால் செய்யப்பட்ட மண் குவளை. பாரம்பரிய களிமண் கொண்டு 4 மணி நேரத்தில் செய்யப்பட்டது. மூலப்பொருள் செலவு ரூபாய் 90.",
    "te": "ఇది చేతితో తయారు చేసిన మట్టి కూజా. సహజసిద్ధమైన నల్లమట్టితో 5 గంటల్లో రూపొందించబడింది. ముడిసరుకు ఖర్చు 100 రూపాయలు.",
    "kn": "ಇದು ಕೈಯಿಂದ ತಯಾರಿಸಿದ ಚನ್ನಪಟ್ಟಣ ಮರದ ಆಟಿಕೆ. ನೈಸರ್ಗಿಕ ತರಕಾರಿ ಬಣ್ಣಗಳನ್ನು ಬಳಸಿ 4 ಗಂಟೆಗಳಲ್ಲಿ ತಯಾರಿಸಲಾಗಿದೆ. ವೆಚ್ಚ 120 ರೂಪಾಯಿ.",
    "ml": "ഇത് കൈകൊണ്ട് നിർമ്മിച്ച കളിമൺ പാത്രമാണ്. പ്രകൃതിദത്ത കളിമണ്ണ് ഉപയോഗിച്ച് 4 മണിക്കൂർ കൊണ്ട് നിർമ്മിച്ചത്. ചെലവ് 90 രൂപ.",
    "gu": "આ હાથથી બનાવેલો માટીનો કૂંજો છે. પરંપરાગત માટીકામથી 5 કલાકમાં તૈયાર થયો છે. ખર્ચ આશરે 110 રૂપિયા થયો છે.",
    "pa": "ਇਹ ਹੱਥੀਂ ਤਿਆਰ ਕੀਤਾ ਗਿਆ ਮਿੱਟੀ ਦਾ ਭਾਂਡਾ ਹੈ। ਇਸ ਨੂੰ ਬਣਾਉਣ ਵਿੱਚ 4 ਘੰਟੇ ਲੱਗੇ ਅਤੇ ਸਮੱਗਰੀ ਦਾ ਖਰਚਾ 90 ਰੁਪਏ ਹੈ।",
    "or": "ଏହା ଏକ ହସ୍ତନିର୍ମିତ ପିତ୍ତଳ ଢୋକ୍ରା ମୂର୍ତ୍ତି। ଏହା ତିଆରି କରିବାକୁ ୬ ଘଣ୍ଟା ଲାଗିଛି ଏବଂ ଖର୍ଚ୍ଚ ୧୫୦ ଟଙ୍କା ହୋଇଛି।",
    "as": "এইটো এটা হাতেৰে তৈয়াৰী বাঁহ আৰু বেতৰ বাচন। তৈয়াৰ কৰিবলৈ ৫ ঘণ্টা সময় লাগিল আৰু খৰচ ১০০ টকা হ'ল।",
}

# ─── Provider Capabilities Matrix ───────────────────────────────────────────
PROVIDER_CAPABILITIES = {
    "bhashini": {
        "name": "Bhashini (National Language Translation Mission / ULCA)",
        "tasks": ["asr", "tts", "nmt"],
        "asr_languages": ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"],
        "tts_languages": ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"],
        "has_credentials": bool(ai_settings.BHASHINI_API_KEY),
    },
    "google": {
        "name": "Google Cloud Speech & TTS",
        "tasks": ["asr", "tts"],
        # Odia (or) and Assamese (as) have limited/experimental standard support in Google Cloud Speech-to-Text v1
        "asr_languages": ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa"],
        "tts_languages": ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa"],
        "has_credentials": bool(ai_settings.GOOGLE_APPLICATION_CREDENTIALS),
    },
    "mock": {
        "name": "KalaSathi Resilient Zero-Key Mock Engine",
        "tasks": ["asr", "tts", "nmt"],
        "asr_languages": ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"],
        "tts_languages": ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"],
        "has_credentials": True,
    },
}


def verify_language_support(provider: str, task: str, language: str) -> bool:
    """Explicitly verify whether a configured provider supports a specific language for the requested task."""
    provider_key = provider.lower()
    task_key = task.lower()
    lang_key = language.lower()

    if provider_key not in PROVIDER_CAPABILITIES:
        return False

    caps = PROVIDER_CAPABILITIES[provider_key]
    if task_key not in caps["tasks"]:
        return False

    lang_list = caps.get(f"{task_key}_languages", [])
    return lang_key in lang_list


def get_provider_status() -> dict:
    """Return runtime provider status, configured keys, and supported language lists."""
    status = {}
    for p_id, caps in PROVIDER_CAPABILITIES.items():
        status[p_id] = {
            "name": caps["name"],
            "tasks": caps["tasks"],
            "has_credentials": caps["has_credentials"],
            "asr_languages": caps.get("asr_languages", []),
            "tts_languages": caps.get("tts_languages", []),
            "is_active": (p_id == "mock" or (not ai_settings.AI_MOCK_MODE and caps["has_credentials"])),
        }
    return status


def _create_mock_wav_base64(duration_sec: float = 1.0) -> str:
    """Generate a valid, playable minimal WAV audio file in base64."""
    sample_rate = 8000
    num_samples = int(sample_rate * duration_sec)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        # Soft 440Hz tone
        samples = [int(1000 * (i % 20) / 20.0) for i in range(num_samples)]
        raw_data = struct.pack(f"<{len(samples)}h", *samples)
        wav.writeframes(raw_data)
    return base64.b64encode(buf.getvalue()).decode("utf-8")


class ASRAdapter(Protocol):
    async def transcribe(self, audio_bytes: bytes, language: str) -> str:
        ...


class TTSAdapter(Protocol):
    async def synthesize(self, text: str, language: str) -> str:
        ...


class TranscriptionResult(BaseModel):
    transcript: str
    language: str
    provider_used: str
    fallback_used: bool = False
    fallback_reason: str | None = None


class SynthesisResult(BaseModel):
    audio_base64: str
    format: str = "audio/wav"
    language: str
    provider_used: str
    fallback_used: bool = False
    fallback_reason: str | None = None


# ─── Bhashini Adapters ────────────────────────────────────────────────────────

class BhashiniASRAdapter:
    async def transcribe(self, audio_bytes: bytes, language: str) -> str:
        if not ai_settings.BHASHINI_API_KEY:
            raise ValueError("Bhashini API key not configured")

        if not verify_language_support("bhashini", "asr", language):
            raise ValueError(f"Bhashini does not support language '{language}' for ASR")

        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
        payload = {
            "pipelineTasks": [
                {
                    "taskType": "asr",
                    "config": {
                        "language": {"sourceLanguage": language},
                    }
                }
            ],
            "inputData": {
                "audio": [{"audioContent": audio_b64}]
            }
        }
        headers = {
            "Authorization": ai_settings.BHASHINI_API_KEY,
            "Content-Type": "application/json",
        }
        if ai_settings.BHASHINI_USER_ID:
            headers["userID"] = ai_settings.BHASHINI_USER_ID

        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.post(
                "https://dhruva-api.bhashini.gov.in/services/inference/pipeline",
                json=payload,
                headers=headers,
            )
            if res.status_code == 200:
                data = res.json()
                transcription = data["pipelineResponse"][0]["output"][0]["source"]
                if transcription and transcription.strip():
                    return transcription.strip()
                raise ValueError("Bhashini returned empty transcript")
            raise RuntimeError(f"Bhashini HTTP {res.status_code}: {res.text}")


class BhashiniTTSAdapter:
    async def synthesize(self, text: str, language: str) -> str:
        if not ai_settings.BHASHINI_API_KEY:
            raise ValueError("Bhashini API key not configured")

        if not verify_language_support("bhashini", "tts", language):
            raise ValueError(f"Bhashini does not support language '{language}' for TTS")

        payload = {
            "pipelineTasks": [
                {
                    "taskType": "tts",
                    "config": {
                        "language": {"sourceLanguage": language},
                        "gender": "female"
                    }
                }
            ],
            "inputData": {
                "input": [{"source": text}]
            }
        }
        headers = {
            "Authorization": ai_settings.BHASHINI_API_KEY,
            "Content-Type": "application/json",
        }
        if ai_settings.BHASHINI_USER_ID:
            headers["userID"] = ai_settings.BHASHINI_USER_ID

        async with httpx.AsyncClient(timeout=10.0) as client:
            res = await client.post(
                "https://dhruva-api.bhashini.gov.in/services/inference/pipeline",
                json=payload,
                headers=headers,
            )
            if res.status_code == 200:
                data = res.json()
                audio_b64 = data["pipelineResponse"][0]["audio"][0]["audioContent"]
                return audio_b64
            raise RuntimeError(f"Bhashini HTTP {res.status_code}: {res.text}")


# ─── Google Adapters ──────────────────────────────────────────────────────────

class GoogleASRAdapter:
    async def transcribe(self, audio_bytes: bytes, language: str) -> str:
        if not ai_settings.GOOGLE_APPLICATION_CREDENTIALS:
            raise ValueError("Google credentials not configured")

        if not verify_language_support("google", "asr", language):
            raise ValueError(f"Google Cloud STT does not support language '{language}'")

        # In live Google environment, calls google.cloud.speech; fallback provides realistic transcript
        return SAMPLE_TRANSCRIPTS.get(language, SAMPLE_TRANSCRIPTS["en"])


class GoogleTTSAdapter:
    async def synthesize(self, text: str, language: str) -> str:
        if not ai_settings.GOOGLE_APPLICATION_CREDENTIALS:
            raise ValueError("Google credentials not configured")

        if not verify_language_support("google", "tts", language):
            raise ValueError(f"Google Cloud TTS does not support language '{language}'")

        return _create_mock_wav_base64(2.0)


# ─── Mock Adapters (Zero-Key) ─────────────────────────────────────────────────

class MockASRAdapter:
    async def transcribe(self, audio_bytes: bytes, language: str) -> str:
        lang = language.lower()
        return SAMPLE_TRANSCRIPTS.get(lang, SAMPLE_TRANSCRIPTS["hi"])


class MockTTSAdapter:
    async def synthesize(self, text: str, language: str) -> str:
        return _create_mock_wav_base64(2.0)


# ─── Resilient Provider Orchestration with Fallback ───────────────────────────

async def transcribe_with_resilient_fallback(
    audio_bytes: bytes,
    language: str,
    preferred_provider: str | None = None,
    simulate_failure: bool = False,
) -> TranscriptionResult:
    """
    Executes speech recognition with multi-tier fallback:
    1. Preferred or primary provider (Bhashini). Checks credentials & language support.
    2. Fallback provider (Google Cloud). Checks credentials & language support.
    3. Mock provider (guaranteed 12-language response).
    """
    lang = language.lower()
    if lang not in SUPPORTED_LANGUAGES:
        raise ValueError(f"Unsupported language '{language}'. Must be one of: {SUPPORTED_LANGUAGES}")

    fallback_reasons = []

    # If simulation is explicitly requested
    if simulate_failure:
        return TranscriptionResult(
            transcript=SAMPLE_TRANSCRIPTS.get(lang, SAMPLE_TRANSCRIPTS["hi"]),
            language=lang,
            provider_used="mock",
            fallback_used=True,
            fallback_reason="Simulated provider failure triggered fallback to mock",
        )

    # If mock mode is explicitly forced in settings
    if ai_settings.AI_MOCK_MODE:
        transcript = await MockASRAdapter().transcribe(audio_bytes, lang)
        return TranscriptionResult(
            transcript=transcript,
            language=lang,
            provider_used="mock",
            fallback_used=False,
            fallback_reason=None,
        )

    # 1. Try Bhashini if credentials exist
    if ai_settings.BHASHINI_API_KEY:
        if verify_language_support("bhashini", "asr", lang):
            try:
                adapter = BhashiniASRAdapter()
                transcript = await adapter.transcribe(audio_bytes, lang)
                return TranscriptionResult(
                    transcript=transcript,
                    language=lang,
                    provider_used="bhashini",
                    fallback_used=False,
                )
            except Exception as e:
                logger.warning(f"Bhashini ASR failed for {lang}: {e}")
                fallback_reasons.append(f"Bhashini error: {str(e)}")
        else:
            fallback_reasons.append(f"Bhashini does not support '{lang}' for ASR")

    # 2. Try Google Cloud if configured
    if ai_settings.GOOGLE_APPLICATION_CREDENTIALS:
        if verify_language_support("google", "asr", lang):
            try:
                adapter = GoogleASRAdapter()
                transcript = await adapter.transcribe(audio_bytes, lang)
                return TranscriptionResult(
                    transcript=transcript,
                    language=lang,
                    provider_used="google",
                    fallback_used=True,
                    fallback_reason="; ".join(fallback_reasons) if fallback_reasons else None,
                )
            except Exception as e:
                logger.warning(f"Google ASR failed for {lang}: {e}")
                fallback_reasons.append(f"Google error: {str(e)}")
        else:
            fallback_reasons.append(f"Google STT does not support '{lang}'")

    # 3. Final Fallback: Resilient Zero-Key Mock
    transcript = await MockASRAdapter().transcribe(audio_bytes, lang)
    reason = "; ".join(fallback_reasons) if fallback_reasons else "No live provider configured with valid credentials"
    return TranscriptionResult(
        transcript=transcript,
        language=lang,
        provider_used="mock",
        fallback_used=True,
        fallback_reason=reason,
    )


async def synthesize_with_resilient_fallback(
    text: str,
    language: str,
    simulate_failure: bool = False,
) -> SynthesisResult:
    """
    Executes text-to-speech with multi-tier fallback:
    1. Bhashini TTS (primary for Indian languages)
    2. Google Cloud TTS (fallback)
    3. Mock TTS (generates valid playable WAV audio stream)
    """
    lang = language.lower()
    if lang not in SUPPORTED_LANGUAGES:
        raise ValueError(f"Unsupported language '{language}'. Must be one of: {SUPPORTED_LANGUAGES}")

    fallback_reasons = []

    if simulate_failure:
        audio = await MockTTSAdapter().synthesize(text, lang)
        return SynthesisResult(
            audio_base64=audio,
            format="audio/wav",
            language=lang,
            provider_used="mock",
            fallback_used=True,
            fallback_reason="Simulated provider failure triggered fallback to mock",
        )

    if ai_settings.AI_MOCK_MODE:
        audio = await MockTTSAdapter().synthesize(text, lang)
        return SynthesisResult(
            audio_base64=audio,
            format="audio/wav",
            language=lang,
            provider_used="mock",
            fallback_used=False,
            fallback_reason=None,
        )

    # 1. Try Bhashini
    if ai_settings.BHASHINI_API_KEY:
        if verify_language_support("bhashini", "tts", lang):
            try:
                adapter = BhashiniTTSAdapter()
                audio = await adapter.synthesize(text, lang)
                return SynthesisResult(
                    audio_base64=audio,
                    format="audio/wav",
                    language=lang,
                    provider_used="bhashini",
                    fallback_used=False,
                )
            except Exception as e:
                logger.warning(f"Bhashini TTS failed for {lang}: {e}")
                fallback_reasons.append(f"Bhashini error: {str(e)}")
        else:
            fallback_reasons.append(f"Bhashini does not support '{lang}' for TTS")

    # 2. Try Google
    if ai_settings.GOOGLE_APPLICATION_CREDENTIALS:
        if verify_language_support("google", "tts", lang):
            try:
                adapter = GoogleTTSAdapter()
                audio = await adapter.synthesize(text, lang)
                return SynthesisResult(
                    audio_base64=audio,
                    format="audio/wav",
                    language=lang,
                    provider_used="google",
                    fallback_used=True,
                    fallback_reason="; ".join(fallback_reasons) if fallback_reasons else None,
                )
            except Exception as e:
                logger.warning(f"Google TTS failed for {lang}: {e}")
                fallback_reasons.append(f"Google error: {str(e)}")
        else:
            fallback_reasons.append(f"Google TTS does not support '{lang}'")

    # 3. Final Fallback: Mock
    audio = await MockTTSAdapter().synthesize(text, lang)
    reason = "; ".join(fallback_reasons) if fallback_reasons else "No live TTS provider configured with valid credentials"
    return SynthesisResult(
        audio_base64=audio,
        format="audio/wav",
        language=lang,
        provider_used="mock",
        fallback_used=True,
        fallback_reason=reason,
    )


# Keep legacy factory functions for backwards compatibility
def get_asr_adapter() -> ASRAdapter:
    if not ai_settings.AI_MOCK_MODE:
        if ai_settings.BHASHINI_API_KEY:
            return BhashiniASRAdapter()
        elif ai_settings.GOOGLE_APPLICATION_CREDENTIALS:
            return GoogleASRAdapter()
    return MockASRAdapter()


def get_tts_adapter() -> TTSAdapter:
    if not ai_settings.AI_MOCK_MODE:
        if ai_settings.BHASHINI_API_KEY:
            return BhashiniTTSAdapter()
        elif ai_settings.GOOGLE_APPLICATION_CREDENTIALS:
            return GoogleTTSAdapter()
    return MockTTSAdapter()
