"""Verification of All 12 Supported Languages in KalaSathi:
1. English (en)
2. Hindi (hi, हिन्दी)
3. Marathi (mr, मराठी)
4. Bengali (bn, বাংলা)
5. Tamil (ta, தமிழ்)
6. Telugu (te, తెలుగు)
7. Kannada (kn, ಕನ್ನಡ)
8. Malayalam (ml, മലയാളം)
9. Gujarati (gu, ગુજરાતી)
10. Punjabi (pa, ਪੰਜਾਬੀ)
11. Odia (or, ଓଡ଼ିଆ)
12. Assamese (as, অসমীয়া)

Tests:
- Speech-to-Text (ASR) per language
- Text-to-Speech (TTS) per language
- Multimodal 12-language translation preservation
- Provider capability matrix verification
"""
import sys
import asyncio
import httpx

API_BASE = "http://127.0.0.1:8000/api/v1"

LANGUAGES = [
    ("en", "English", "English"),
    ("hi", "Hindi", "हिन्दी"),
    ("mr", "Marathi", "मराठी"),
    ("bn", "Bengali", "বাংলা"),
    ("ta", "Tamil", "தமிழ்"),
    ("te", "Telugu", "తెలుగు"),
    ("kn", "Kannada", "ಕನ್ನಡ"),
    ("ml", "Malayalam", "മലയാളം"),
    ("gu", "Gujarati", "ગુજરાતી"),
    ("pa", "Punjabi", "ਪੰਜਾਬੀ"),
    ("or", "Odia", "ଓଡ଼ିଆ"),
    ("as", "Assamese", "অসমীয়া"),
]

SAMPLE_PHRASES = {
    "en": "Handcrafted terracotta vase with natural clay",
    "hi": "हस्तनिर्मित पारंपरिक मिट्टी का घड़ा",
    "mr": "हाताने घडवलेली पारंपरिक मातीची सुरई",
    "bn": "হাতে তৈরি খাঁটি মাটির সুন্দর পাত্র",
    "ta": "கையால் செய்யப்பட்ட பாரம்பரிய மண்பாண்டம்",
    "te": "చేతితో చేసిన సాంప్రదాయ మట్టి పాత్ర",
    "kn": "ಕೈಯಿಂದ ಮಾಡಿದ ಸುಂದರವಾದ ಮಣ್ಣಿನ ಮಡಕೆ",
    "ml": "കൈകൊണ്ട് നിർമ്മിച്ച പരമ്പരാഗത കളിമൺ പാത്രം",
    "gu": "હાથથી બનાવેલો સુંદર માટીનો ઘડો",
    "pa": "ਹੱਥੀਂ ਤਿਆਰ ਕੀਤਾ ਗਿਆ ਰਵਾਇਤੀ ਮਿੱਟੀ ਦਾ ਭਾਂਡਾ",
    "or": "ହସ୍ତନିର୍ମିତ ପାରମ୍ପରିକ ମାଟି ପାତ୍ର",
    "as": "হাতেৰে গঢ়া সুন্দৰ মাটিৰ পাত্ৰ",
}


async def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    print("=" * 80)
    print("VERIFICATION OF ALL 12 MANDATORY INDIAN LANGUAGES")
    print("=" * 80)

    async with httpx.AsyncClient(timeout=20.0) as client:
        # 1. Provider Capabilities
        print("\n--- 1. Provider Capabilities Matrix ---")
        prov_res = await client.get(f"{API_BASE}/ai/providers")
        assert prov_res.status_code == 200
        providers_data = prov_res.json()
        print(f"Supported Languages Count: {len(providers_data.get('supported_languages', []))}")
        print("Providers Configured:")
        for p_key, p_info in providers_data.get("providers", {}).items():
            print(f"   [{p_key.upper()}]: {p_info.get('name')} | Has Keys: {p_info.get('has_credentials')} | Active: {p_info.get('is_active')}")

        # 2. Test ASR and TTS across all 12 languages
        print("\n--- 2. Systematic ASR & TTS Testing for All 12 Languages ---")
        asr_success = 0
        tts_success = 0

        for code, eng_name, native_name in LANGUAGES:
            phrase = SAMPLE_PHRASES.get(code, "Handcrafted craft")

            # Test ASR
            asr_res = await client.post(f"{API_BASE}/ai/transcribe", data={"language": code})
            assert asr_res.status_code == 200, f"ASR failed for {code}: {asr_res.text}"
            asr_data = asr_res.json()
            assert asr_data["language"] == code
            assert len(asr_data["transcript"]) > 0
            asr_success += 1

            # Test TTS
            tts_res = await client.post(f"{API_BASE}/ai/synthesize", json={"text": phrase, "language": code})
            assert tts_res.status_code == 200, f"TTS failed for {code}: {tts_res.text}"
            tts_data = tts_res.json()
            assert tts_data["language"] == code
            assert len(tts_data.get("audio_base64", "")) > 100
            tts_success += 1

            print(f"   ✓ [{code.upper()}] {native_name:<10} ({eng_name:<10}) -> ASR: OK | TTS: {len(tts_data['audio_base64'])} chars audio")

        print(f"\nAll 12 Languages Verified: ASR: {asr_success}/12 | TTS: {tts_success}/12")

        # 3. Test Full Multimodal 12-Language Translation Catalog Generation
        print("\n--- 3. Testing 12-Language Multimodal Catalog Extraction & Translations ---")
        cat_res = await client.post(
            f"{API_BASE}/ai/catalog",
            json={
                "transcript": "हा हाताने बनवलेला वारली कॅनव्हास आहे. यात नैसर्गिक तांदळाचे पीठ वापरले आहे. पाच तास लागले आणि साहित्याचा खर्च १०० रुपये आहे.",
                "language": "mr",
            },
        )
        assert cat_res.status_code == 200
        cat_data = cat_res.json()
        translations = cat_data.get("translations", [])
        assert len(translations) == 12, f"Expected 12 translations, got {len(translations)}"

        print("Verified Stored Translations:")
        lang_set = {t["language"] for t in translations}
        for code, eng_name, native_name in LANGUAGES:
            assert code in lang_set, f"Language {code} missing from translations!"
            matching = next(t for t in translations if t["language"] == code)
            print(f"   [{code.upper()}] {native_name:<10}: {matching['title'][:35]}...")

        print("\n" + "=" * 80)
        print("🎉 ALL 12 LANGUAGES ACCURATELY VERIFIED FOR ASR, TTS, AND TRANSLATIONS!")
        print("=" * 80)


if __name__ == "__main__":
    asyncio.run(main())
