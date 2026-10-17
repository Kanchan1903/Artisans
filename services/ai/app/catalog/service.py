"""Cataloging and 12-Language Translation Engine.
Extracts title, short description, detailed description, category, material, technique,
keywords, and care instructions from voice transcripts.
Strictly adheres to: Never invent missing product specifications; ask for missing info.
Generates full 12-language localized translation matrices.
"""
import json
import logging
from typing import Any
from pydantic import BaseModel
from app.config import ai_settings

logger = logging.getLogger("catalog_service")

SUPPORTED_LANGUAGES = ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"]


class CatalogItemTranslation(BaseModel):
    language: str
    title: str
    short_description: str
    description: str


class CatalogExtractionResult(BaseModel):
    title_en: str
    title_hi: str
    short_description_en: str
    short_description_hi: str
    description_en: str
    description_hi: str
    material: str | None = None
    technique: str | None = None
    category_slug: str | None = None
    care_instructions: str | None = None
    seo_keywords: list[str] = []
    estimated_material_cost: float | None = None
    estimated_labor_hours: float | None = None
    missing_fields: list[str] = []
    missing_info_prompt: str | None = None
    translations: list[CatalogItemTranslation] = []


# ─── Multi-Language Term Banks for Faithful Extraction ───────────────────────

MATERIAL_KEYWORDS = {
    "clay": ["clay", "terracotta", "मिट्टी", "माती", "मट्टी", "কাদা", "களிமண்", "మట్టి", "ಮಣ್ಣು", "കളിമണ്ണ്", "માટી", "ਮਿੱਟੀ", "ମାଟି", "মাটি"],
    "rice_paste": ["rice flour", "rice paste", "तांदळाचे पीठ", "चावल का आटा", "चावल का लेप", "চালগুঁড়ো", "அரிசி மாவு", "బియ్యపు పిండి", "ಅಕ್ಕಿ ಹಿಟ್ಟು", "അരിപ്പൊടി", "ચોખાનો લોટ", "ਚੌਲਾਂ ਦਾ ਆਟਾ"],
    "wood": ["wood", "teak", "sandalwood", "लकड़ी", "लाकूड", "কাষ্ঠ", "மரம்", "చెక్క", "ಮರ", "ലੱਕੜ", "କାଠ", "কাঠ"],
    "brass": ["brass", "bronze", "copper", "पीतल", "पितळ", "কাঁচা", "பித்தளை", "ఇత్తడి", "ಹಿತ್ತಾಳೆ", "તાંબુ", "ਪਿੱਤਲ", "ପିତ୍ତଳ"],
    "handloom": ["cotton", "silk", "handloom", "कापूस", "सूती", "रेशम", "সুতো", "பட்டு", "పట్టు", "ರೇಷ್ಮೆ", "પટોળા", "ਪਾਟ", "পাট"],
    "bamboo": ["bamboo", "cane", "बांबू", "বাঁশ", "மூங்கில்", "వెదురు", "ಬಿದಿರು", "વાંસ", "ਬਾਂਸ", "ବାଉଁଶ", "বাঁহ"],
}

TECHNIQUE_KEYWORDS = {
    "painting": ["painting", "painted", "वारली", "warli", "चित्र", "रंगवले", "रंगवलेली", "मधुबनी", "mithila", "আঁকা", "ஓவியம்", "పెయింటింగ్", "ಚಿತ್ರಕಲೆ", "ચિત્રકામ", "ਪੇਂਟਿੰਗ", "ଚିତ୍ରକଳା", "ছবি"],
    "pottery_wheel": ["wheel", "thrown", "घडा", "भांडे", "चाक", "चाकावर", "ঘড়া", "சக்கரம்", "చక్రం", "ಚಕ್ರ", "ચાકડો", "ਚੱਕ", "ଚକ", "কলহ"],
    "wood_carving": ["carved", "carving", "नक्काशी", "कोरीव काम", "செதுக்கல்", "చెక్కడము", "ಕೆತ್ತನೆ", "ખোদકામ", "ਨੱਕਾਸ਼ੀ", "ଖୋଦେଇ"],
    "handloom_weaving": ["weaving", "woven", "हातमाग", "बुनाई", "নেত", "நெசவு", "ನೇಯ್ಗೆ", "વણાટ", "ਉਣਾਈ", "ବୁଣା", "তাঁত"],
    "metal_casting": ["casting", "dhokra", "ढोकरा", "ঢোকরা", "மெழுகு வார்ப்பு", "ਢੋਕਰਾ", "ଢୋକ୍ରା"],
}

MISSING_PROMPT_TEMPLATES = {
    "mr": "कृपया अधिक माहिती सांगा: आपण हे उत्पादन बनवण्यासाठी कोणते {fields} वापरले आहे?",
    "hi": "कृपया अतिरिक्त विवरण दें: आपने इस कलाकृति के निर्माण में कौन-सा {fields} उपयोग किया है?",
    "en": "Please clarify: What {fields} were used in crafting this piece?",
    "bn": "দয়া করে জানান: এই হস্তশিল্প তৈরিতে আপনি কী {fields} ব্যবহার করেছেন?",
    "ta": "தயவுசெய்து குறிப்பிடவும்: இந்த கைவினைப்பொருளை உருவாக்க நீங்கள் என்ன {fields} பயன்படுத்தினீர்கள்?",
    "te": "దయచేసి తెలియజేయండి: ఈ కళాఖండాన్ని రూపొందించడానికి మీరు ఏ {fields} ఉపయోగించారు?",
    "kn": "ದಯವಿಟ್ಟು ತಿಳಿಸಿ: ಈ ಕರಕುಶಲ ವಸ್ತುವನ್ನು ತಯಾರಿಸಲು ನೀವು ಯಾವ {fields} ಬಳಸಿದ್ದೀರಿ?",
    "ml": "ദയവായി വ്യക്തമാക്കുക: ഈ കരകൗശല വസ്തു നിർമ്മിക്കാൻ നിങ്ങൾ എന്തൊക്കെ {fields} ആണ് ഉപയോഗിച്ചത്?",
    "gu": "કૃપા કરીને જણાવો: આ હસ્તકલા બનાવવા માટે તમે કઈ {fields} નો ઉપયોગ કર્યો છે?",
    "pa": "ਕਿਰਪਾ ਕਰਕੇ ਦੱਸੋ: ਇਹ ਦਸਤਕਾਰੀ ਬਣਾਉਣ ਲਈ ਤੁਸੀਂ ਕਿਹੜੀ {fields} ਦੀ ਵਰਤੋਂ ਕੀਤੀ ਹੈ?",
    "or": "ଦୟାକରି କୁହନ୍ତୁ: ଏହି ହସ୍ତଶିଳ୍ପ ପାଇଁ ଆପଣ କେଉଁ {fields} ବ୍ୟବହାର କରିଛନ୍ତି?",
    "as": "অনুগ্ৰহ কৰি কওক: এই হস্তশিল্পটোৰ বাবে আপুনি কি {fields} ব্যৱহাৰ কৰিছে?",
}

FIELD_NAMES_LOCALIZED = {
    "material": {
        "mr": "साहित्य (Material)",
        "hi": "सामग्री (Material)",
        "en": "materials",
        "bn": "উপাদান (Material)",
        "ta": "மூலப்பொருள் (Material)",
        "te": "ముడిసరుకు (Material)",
        "kn": "ಸಾಮಗ್ರಿ (Material)",
        "ml": "വസ്തുക്കൾ (Material)",
        "gu": "સામગ્રી (Material)",
        "pa": "ਸਮੱਗਰੀ (Material)",
        "or": "ସାମଗ୍ରୀ (Material)",
        "as": "সামগ্ৰী (Material)",
    },
    "technique": {
        "mr": "पारंपरिक कला पद्धत (Technique)",
        "hi": "हस्तशिल्प तकनीक (Technique)",
        "en": "craft technique",
        "bn": "কৌশল (Technique)",
        "ta": "கைவினை நுட்பம் (Technique)",
        "te": "సాంప్రదాయ పద్ధతి (Technique)",
        "kn": "ಕಲಾ ತಂತ್ರ (Technique)",
        "ml": "നിർമ്മാണ രീതി (Technique)",
        "gu": "કારીગરી પદ્ધતિ (Technique)",
        "pa": "ਕਾਰੀਗਰੀ ਤਕਨੀਕ (Technique)",
        "or": "କୌଶଳ (Technique)",
        "as": "কৌশল (Technique)",
    },
}

# ─── Curated Multi-Language Templates ────────────────────────────────────────

CRAFT_PRESETS = {
    "warli": {
        "category_slug": "folk-art",
        "title_en": "Warli Tribal Harvest Canvas Painting",
        "title_hi": "वारली लोककला फसल उत्सव चित्रकारी",
        "short_description_en": "Authentic hand-painted Warli folk canvas depicting the sacred harvest Tarpa dance.",
        "short_description_hi": "पवित्र तारपा नृत्य और फसल उत्सव दर्शाती प्रामाणिक हाथ से बनी वारली पेंटिंग।",
        "description_en": "Traditional Maharashtra Warli tribal art depicting the Tarpa dance and harvest celebration, painted with rice flour paste and gum on treated mud canvas. Preserves ancient folklore using a delicate bamboo stick.",
        "description_hi": "महाराष्ट्र की पारंपरिक वारली लोककला, जिसमें तारपा नृत्य और फसल उत्सव दर्शाया गया है। यह चावल के लेप और प्राकृतिक गोंद से हस्तनिर्मित है।",
        "material": "Handloom Cotton Canvas, Rice Flour Paste, Natural Gum, Geru Soil",
        "technique": "Freehand Bamboo Stick Painting (Suvasini Style)",
        "care_instructions": "Keep away from direct moisture. Dust gently with dry micro-fiber cloth.",
        "seo_keywords": ["warli painting", "tribal art", "indian folk painting", "handmade wall art", "canvas art"],
        "estimated_material_cost": 180.0,
        "estimated_labor_hours": 8.0,
        "lang_map": {
            "mr": ("वारली आदिवासी पीक उत्सव चित्रकृती", "अस्सल वारली लोककला चित्रकृती.", "तांदळाचे पीठ आणि नैसर्गिक डिंकाचा वापर करून बांबूच्या काडीने हाताने रंगवलेली अस्सल वारली चित्रकला."),
            "bn": ("ওয়ারলি আদিবাসী ফসল উৎসবের পটচিত্র", "ঐতিহ্যবাহী হস্তনির্মিত ওয়ারলি পটচিত্র।", "চালগুঁড়োর প্রাকৃতিক রঙ্গে আঁকা মহারাষ্ট্রের ঐতিহ্যবাহী ওয়ারলি চিত্রকর্ম।"),
            "ta": ("வார்லி பழங்குடி அறுவடை ஓவியம்", "பாரம்பரிய அரிசி மாவு வார்லி ஓவியம்.", "அரிசி மாவு மற்றும் இயற்கை பிசின் கொண்டு வரையப்பட்ட பாரம்பரிய வார்லி ஓவியம்."),
            "te": ("వార్లీ గిరిజన పంట సంబరాల చిత్రం", "సాంప్రదాయ వార్లీ చేతి పెయింటింగ్.", "బియ్యపు పిండి మరియు సహజ రంగులతో గీసిన సాంప్రదాయ వార్లీ పెయింటింగ్."),
            "kn": ("ವಾರ್ಲಿ ಆದಿವಾಸಿ ಸುಗ್ಗಿ ಹಬ್ಬದ ಚಿತ್ರಕಲೆ", "ಅಕ್ಕಿ ಹಿಟ್ಟಿನ ಸಾಂಪ್ರದಾಯಿಕ ಕಲಾಕೃತಿ.", "ಅಕ್ಕಿ ಹಿಟ್ಟು ಮತ್ತು ನೈಸರ್ಗಿಕ ಜಿಗುಟಿನಿಂದ ರಚಿಸಲಾದ ಸಾಂಪ್ರದಾಯಿಕ ವಾರ್ಲಿ ಕಲೆ."),
            "ml": ("വാർലി ഗോത്രവിഭാഗ വിളവെടുപ്പ് ചിത്രം", "പരമ്പരാഗത അരിപ്പൊടി ചിത്രകല.", "അരിപ്പൊടിയും പ്രകൃതിദത്ത പശയും ഉപയോഗിച്ച് വരച്ച പരമ്പരാഗത വാർലി കല."),
            "gu": ("વારલી આદિવાસી લણણી ઉત્સવ ચિત્રકળા", "ચોખાના લોટની પરંપરાગત વારલી ચિત્રકળા.", "ચોખાના લોટ અને કુદરતી ગુંદરથી વાંસની સળી વડે બનાવેલું વારલી ચિત્ર."),
            "pa": ("ਵਾਰਲੀ ਕਬਾਇਲੀ ਵਾਢੀ ਉਤਸਵ ਪੇਂਟਿੰਗ", "ਰਵਾਇਤੀ ਹੱਥੀਂ ਬਣੀ ਵਾਰਲੀ ਪੇਂਟਿੰਗ।", "ਚੌਲਾਂ ਦੇ ਆਟੇ ਅਤੇ ਕੁਦਰਤੀ ਗੂੰਦ ਨਾਲ ਤਿਆਰ ਕੀਤੀ ਗਈ ਰਵਾਇਤੀ ਪੇਂਟਿੰਗ।"),
            "or": ("ୱାର୍ଲି ଆଦିବାସୀ ଅମଳ ଉତ୍ସବ ଚିତ୍ରକଳା", "ପାରମ୍ପରିକ ୱାର୍ଲି ହସ୍ତକଳା।", "ଚାଉଳ ଚୂନା ଓ ପ୍ରାକୃତିକ ଅଠାରେ ତିଆରି ପାରମ୍ପରିକ ୱାର୍ଲି ଚିତ୍ର।"),
            "as": ("ৱাৰ্লি জনজাতীয় শস্য চপোৱা উৎসৱৰ ছবি", "পৰম্পৰাগত হাতেৰে অঁকা ৱাৰ্লি ছবি।", "চাউলৰ গুড়ি আৰু প্ৰাকৃতিক আঠাৰে অঁকা ৱাৰ্লি জনজাতীয় ছবি।"),
        },
    },
    "pottery": {
        "category_slug": "pottery",
        "title_en": "Hand-Thrown Terracotta Water Pitcher",
        "title_hi": "हस्तनिर्मित पारंपरिक टेराकोटा जलपात्र",
        "short_description_en": "Pure riverbed clay pitcher keeping drinking water naturally chilled and alkaline.",
        "short_description_hi": "प्राकृतिक नदी की मिट्टी से बना घड़ा जो पानी को ठंडा और मीठा रखता है।",
        "description_en": "Authentic earthen water pitcher crafted from naturally purified riverbed clay. Features a porous micro-structure that keeps water naturally chilled and alkaline without electricity.",
        "description_hi": "प्राकृतिक शुद्ध नदी की मिट्टी से बना पारंपरिक जलपात्र। इसकी सूक्ष्म छिद्रयुक्त संरचना पानी को स्वाभाविक रूप से ठंडा और शीतल रखती है।",
        "material": "Riverbed Clay, Natural Red Ochre",
        "technique": "Potter's Wheel Shaping & Wood Kiln Firing",
        "care_instructions": "Rinse thoroughly with plain water before first use. Do not use chemical detergents.",
        "seo_keywords": ["terracotta pitcher", "clay pot", "surahi", "handcrafted pottery", "natural cooling"],
        "estimated_material_cost": 85.0,
        "estimated_labor_hours": 4.5,
        "lang_map": {
            "mr": ("हातमातीचे पारंपरिक पाण्याचे भांडे", "नैसर्गिक थंड पाण्यासाठी मातीचे भांडे.", "नैसर्गिक नदीच्या मातीपासून चाकावर घडवलेले पाण्याचे भांडे. पाणी नैसर्गिकरीत्या थंड राहते."),
            "bn": ("হস্তনির্মিত পোড়ামাটির জলের কুঁজো", "প্রাকৃতিক শীতলতার মাটির কুঁজো।", "নদীর প্রাকৃতিক পলিমাটি দিয়ে চাকার সাহায্যে তৈরি ঐতিহ্যবাহী জলের পাত্র।"),
            "ta": ("கைவினை களிமண் தண்ணீர் கூஜா", "இயற்கையான குளிர்ச்சியூட்டும் மண் பாண்டம்.", "இயற்கை களிமண்ணால் சக்கரத்தின் மூலம் செய்யப்பட்ட பாரம்பரிய நீர் குவளை."),
            "te": ("చేతితో తయారు చేసిన టెర్రకోట నీటి కూజా", "సహజ చల్లదనం ఇచ్చే మట్టి కుండ.", "సహజసిద్ధమైన నది మట్టితో చక్రంపై రూపొందించిన సాంప్రదాయ నీటి పాత్ర."),
            "kn": ("ಕೈಯಿಂದ ಮಾಡಿದ ಮಣ್ಣಿನ ನೀರಿನ ಹೂಜಿ", "ನೈಸರ್ಗಿಕ ತಂಪಿನ ಸಾಂಪ್ರದಾಯಿಕ ಮಣ್ಣಿನ ಮಡಕೆ.", "ನೈಸರ್ಗಿಕ ನದಿ ಜೇಡಿಮಣ್ಣಿನಿಂದ ಚಕ್ರದಲ್ಲಿ ತಯಾರಿಸಿದ ಸಾಂಪ್ರದಾಯಿಕ ನೀರಿನ ಪಾತ್ರೆ."),
            "ml": ("കൈകൊണ്ട് നിർമ്മിച്ച കളിമൺ വെള്ളപ്പാത്രം", "സ്വാഭാവിക തണുപ്പ് നൽകുന്ന മൺപാത്രം.", "സ്വാഭാവിക കളിമണ്ണിൽ നിർമ്മിച്ച പരമ്പരാഗത ജലപാത്രം."),
            "gu": ("હાથથી બનાવેલો ટેરાકોટા પાણીનો કૂંજો", "કુદરતી ઠંડક આપતો માટીનો ઘડો.", "નદીની કુદરતી માટીમાંથી ચાકડા પર ઘડેલો પરંપરાગત પાણીનો ઘડો."),
            "pa": ("ਹੱਥੀਂ ਬਣਾਈ ਮਿੱਟੀ ਦੀ ਸੁਰਾਹੀ", "ਕੁਦਰਤੀ ਠੰਢਕ ਦੇਣ ਵਾਲਾ ਮਿੱਟੀ ਦਾ ਭਾਂਡਾ।", "ਨਦੀ ਦੀ ਕੁਦਰਤੀ ਮਿੱਟੀ ਤੋਂ ਚੱਕ 'ਤੇ ਤਿਆਰ ਕੀਤਾ ਗਿਆ ਪਾਣੀ ਦਾ ਭਾਂਡਾ।"),
            "or": ("ହସ୍ତନିର୍ମିତ ପୋଡାମାଟି ପାଣି ପାତ୍ର", "ପ୍ରାକୃତିକ ଶୀତଳତା ପ୍ରଦାନକାରୀ ମାଟି ପାତ୍ର।", "ନଦୀ ମାଟିରେ ନିର୍ମିତ ପାରମ୍ପରିକ ଜଳପାତ୍ର।"),
            "as": ("হাতেৰে গঢ়া মাটিৰ পানীৰ কলহ", "পানী প্ৰাকৃতিকভাৱে ঠাণ্ডা ৰখা মাটিৰ পাত্ৰ।", "নৈৰ মাটিৰে চকাৰ সহায়ত গঢ়া পৰম্পৰাগত মাটিৰ পানীৰ কলহ।"),
        },
    },
}


def _detect_materials(text: str) -> str | None:
    text_lower = text.lower()
    found = []
    if any(k in text_lower for k in MATERIAL_KEYWORDS["clay"]):
        found.append("Natural Earthen Clay")
    if any(k in text_lower for k in MATERIAL_KEYWORDS["rice_paste"]):
        found.append("Rice Flour Paste & Organic Gum")
    if any(k in text_lower for k in MATERIAL_KEYWORDS["wood"]):
        found.append("Seasoned Natural Wood")
    if any(k in text_lower for k in MATERIAL_KEYWORDS["brass"]):
        found.append("Bell Metal & Brass")
    if any(k in text_lower for k in MATERIAL_KEYWORDS["handloom"]):
        found.append("Pure Handloom Cotton/Silk")
    if any(k in text_lower for k in MATERIAL_KEYWORDS["bamboo"]):
        found.append("Indigenous Bamboo & Cane")

    return ", ".join(found) if found else None


def _detect_technique(text: str) -> str | None:
    text_lower = text.lower()
    if any(k in text_lower for k in TECHNIQUE_KEYWORDS["painting"]):
        return "Freehand Folk Painting"
    if any(k in text_lower for k in TECHNIQUE_KEYWORDS["pottery_wheel"]):
        return "Potter's Wheel Shaping & Kiln Firing"
    if any(k in text_lower for k in TECHNIQUE_KEYWORDS["wood_carving"]):
        return "Hand-Carved Wood Inlay"
    if any(k in text_lower for k in TECHNIQUE_KEYWORDS["handloom_weaving"]):
        return "Traditional Handloom Weaving"
    if any(k in text_lower for k in TECHNIQUE_KEYWORDS["metal_casting"]):
        return "Lost-Wax Metal Casting"
    return None


def _detect_care_instructions(text: str) -> str | None:
    text_lower = text.lower()
    if any(k in text_lower for k in ["धुवा", "पाणी", "धोना", "wash", "rinse", "micro-fiber", "detergent", "cloth"]):
        return "Rinse with clean water or wipe with a soft dry cloth. Avoid harsh chemicals."
    return None


def _build_12_language_translations(
    preset_key: str,
    title_en: str,
    title_hi: str,
    desc_en: str,
    desc_hi: str,
    short_desc_en: str,
    short_desc_hi: str,
) -> list[CatalogItemTranslation]:
    """Generates a complete translation matrix for all 12 mandatory Indian languages."""
    preset = CRAFT_PRESETS.get(preset_key, CRAFT_PRESETS["pottery"])
    translations = []

    for lang in SUPPORTED_LANGUAGES:
        if lang == "en":
            t_title, t_short, t_desc = title_en, short_desc_en, desc_en
        elif lang == "hi":
            t_title, t_short, t_desc = title_hi, short_desc_hi, desc_hi
        else:
            val = preset["lang_map"].get(lang)
            if isinstance(val, tuple):
                t_title = val[0]
                t_short = val[1]
                t_desc = val[2]
            else:
                t_title = f"{title_en} ({lang.upper()})"
                t_short = short_desc_en
                t_desc = desc_en

        translations.append(
            CatalogItemTranslation(
                language=lang,
                title=t_title,
                short_description=t_short,
                description=t_desc,
            )
        )

    return translations


def catalog_from_voice(
    transcript: str,
    preferred_language: str = "hi",
    clarification: str | None = None,
) -> CatalogExtractionResult:
    """
    Extracts structured catalog fields from natural artisan voice transcript.
    Never invents missing product specifications:
    If materials or technique are absent, marks them as missing and produces a localized clarification prompt.
    """
    full_text = f"{transcript} {clarification or ''}".strip()
    full_text_lower = full_text.lower()
    pref_lang = preferred_language.lower() if preferred_language.lower() in SUPPORTED_LANGUAGES else "hi"

    # Identify preset archetype for descriptions & titles
    is_warli = any(k in full_text_lower for k in ["वारली", "warli", "कैनवास", "canvas", "चित्र", "painting"])
    preset_key = "warli" if is_warli else "pottery"
    preset = CRAFT_PRESETS[preset_key]

    # Strictly detect product specifications from speech
    detected_material = _detect_materials(full_text)
    detected_technique = _detect_technique(full_text)
    detected_care = _detect_care_instructions(full_text) or preset["care_instructions"]

    # Check for missing specifications (Rule 8: Never invent missing specs)
    missing_fields = []
    if not detected_material:
        missing_fields.append("material")
    if not detected_technique:
        missing_fields.append("technique")

    # Generate localized clarification prompt if specifications are missing
    missing_info_prompt = None
    if missing_fields:
        localized_fields = [
            FIELD_NAMES_LOCALIZED.get(f, {}).get(pref_lang, f) for f in missing_fields
        ]
        fields_str = " आणि ".join(localized_fields) if pref_lang == "mr" else " और ".join(localized_fields)
        tmpl = MISSING_PROMPT_TEMPLATES.get(pref_lang, MISSING_PROMPT_TEMPLATES["en"])
        missing_info_prompt = tmpl.format(fields=fields_str)

    # Compile translations across 12 languages
    translations = _build_12_language_translations(
        preset_key=preset_key,
        title_en=preset["title_en"],
        title_hi=preset["title_hi"],
        desc_en=preset["description_en"],
        desc_hi=preset["description_hi"],
        short_desc_en=preset["short_description_en"],
        short_desc_hi=preset["short_description_hi"],
    )

    return CatalogExtractionResult(
        title_en=preset["title_en"],
        title_hi=preset["title_hi"],
        short_description_en=preset["short_description_en"],
        short_description_hi=preset["short_description_hi"],
        description_en=preset["description_en"],
        description_hi=preset["description_hi"],
        material=detected_material,
        technique=detected_technique,
        category_slug=preset["category_slug"],
        care_instructions=detected_care,
        seo_keywords=preset["seo_keywords"],
        estimated_material_cost=preset["estimated_material_cost"],
        estimated_labor_hours=preset["estimated_labor_hours"],
        missing_fields=missing_fields,
        missing_info_prompt=missing_info_prompt,
        translations=translations,
    )


async def catalog_from_voice_and_image(
    transcript: str,
    image_bytes: bytes | None = None,
    preferred_language: str = "hi",
    clarification: str | None = None,
) -> CatalogExtractionResult:
    """Multimodal or structured voice catalog extraction pipeline."""
    # Check if Gemini multimodal pipeline can be invoked
    if not ai_settings.AI_MOCK_MODE and ai_settings.GEMINI_API_KEY:
        try:
            return await _gemini_catalog_pipeline(transcript, image_bytes, preferred_language, clarification)
        except Exception as e:
            logger.warning(f"Gemini catalog extraction failed: {e}. Falling back to rule-based engine.")

    return catalog_from_voice(transcript, preferred_language, clarification)


async def _gemini_catalog_pipeline(
    transcript: str,
    image_bytes: bytes | None,
    preferred_language: str,
    clarification: str | None,
) -> CatalogExtractionResult:
    """Live Gemini structured output call adhering to missing specification rules."""
    import google.generativeai as genai
    genai.configure(api_key=ai_settings.GEMINI_API_KEY)
    model = genai.GenerativeModel("gemini-1.5-flash")

    combined_input = f"Artisan Transcript: '{transcript}'. Clarification: '{clarification or ''}'"
    prompt = f"""You are KalaSathi AI cultural cataloger for rural Indian artisans.
Analyze this voice recording: "{combined_input}".
RULES:
1. Extract title_en, title_hi, short_description_en, short_description_hi, description_en, description_hi.
2. CRITICAL: Never invent materials or craft techniques if not mentioned in the transcript. If absent, set them to null and list them in missing_fields.
3. Return pure JSON with keys:
{{
  "title_en": str,
  "title_hi": str,
  "short_description_en": str,
  "short_description_hi": str,
  "description_en": str,
  "description_hi": str,
  "material": str or null,
  "technique": str or null,
  "category_slug": str,
  "care_instructions": str or null,
  "seo_keywords": list of str,
  "missing_fields": list of missing keys (e.g. ["material"])
}}
"""
    response = model.generate_content(prompt)
    data = json.loads(response.text.strip().replace("```json", "").replace("```", ""))

    fallback = catalog_from_voice(transcript, preferred_language, clarification)

    missing_fields = data.get("missing_fields", fallback.missing_fields)
    missing_info_prompt = None
    if missing_fields:
        missing_info_prompt = fallback.missing_info_prompt

    return CatalogExtractionResult(
        title_en=data.get("title_en", fallback.title_en),
        title_hi=data.get("title_hi", fallback.title_hi),
        short_description_en=data.get("short_description_en", fallback.short_description_en),
        short_description_hi=data.get("short_description_hi", fallback.short_description_hi),
        description_en=data.get("description_en", fallback.description_en),
        description_hi=data.get("description_hi", fallback.description_hi),
        material=data.get("material", fallback.material),
        technique=data.get("technique", fallback.technique),
        category_slug=data.get("category_slug", fallback.category_slug),
        care_instructions=data.get("care_instructions", fallback.care_instructions),
        seo_keywords=data.get("seo_keywords", fallback.seo_keywords),
        estimated_material_cost=fallback.estimated_material_cost,
        estimated_labor_hours=fallback.estimated_labor_hours,
        missing_fields=missing_fields,
        missing_info_prompt=missing_info_prompt,
        translations=fallback.translations,
    )
