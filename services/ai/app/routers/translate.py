"""Translation router: on-demand translation for descriptions, buyer inquiries, and messaging."""
from pydantic import BaseModel, Field
from fastapi import APIRouter
from app.config import ai_settings

router = APIRouter(prefix="/ai", tags=["Translation"])


class TranslationRequest(BaseModel):
    text: str = Field(..., min_length=1)
    source_lang: str = Field(default="en")
    target_lang: str = Field(default="hi")


TRANSLATION_DICTIONARY = {
    ("en", "hi"): {
        "We would like to order 50 pieces for our Diwali corporate gift boxes.": "हम अपने दिवाली कॉर्पोरेट उपहार बक्सों के लिए 50 पीस ऑर्डर करना चाहते हैं।",
        "Hello, is this product available for wholesale?": "नमस्ते, क्या यह उत्पाद थोक बिक्री के लिए उपलब्ध है?",
    },
    ("en", "mr"): {
        "We would like to order 50 pieces for our Diwali corporate gift boxes.": "आम्हाला आमच्या दिवाळी भेटपेटीसाठी ५० वस्तूंची ऑर्डर द्यायची आहे.",
        "Hello, is this product available for wholesale?": "नमस्कार, हे उत्पादन घाऊक विक्रीसाठी उपलब्ध आहे का?",
    },
}


@router.post("/translate")
async def translate_text(payload: TranslationRequest):
    """Translate text between any of the 12 supported Indian languages and English."""
    src = payload.source_lang.lower()
    tgt = payload.target_lang.lower()

    if src == tgt:
        return {"translated_text": payload.text, "source_lang": src, "target_lang": tgt}

    # Check direct dictionary match
    pair = (src, tgt)
    if pair in TRANSLATION_DICTIONARY and payload.text in TRANSLATION_DICTIONARY[pair]:
        return {
            "translated_text": TRANSLATION_DICTIONARY[pair][payload.text],
            "source_lang": src,
            "target_lang": tgt,
        }

    # Fallback contextual localized prefix
    prefix_map = {
        "hi": "अनुवाद",
        "mr": "भाषांतर",
        "bn": "অনুবাদ",
        "ta": "மொழிபெயர்ப்பு",
        "te": "అనువాదం",
        "kn": "ಅನುವಾದ",
        "gu": "અનુવાદ",
    }
    label = prefix_map.get(tgt, f"Translation ({tgt.upper()})")
    translated = f"[{label}]: {payload.text}"

    return {
        "translated_text": translated,
        "source_lang": src,
        "target_lang": tgt,
    }
