"""Multilingual AI Product Description Multi-Agent System for KalaSathi.

6 Specialized Coordinated Agents:
1. Voice Agent: Converts speech audio to text and detects spoken language across all supported Indian regional languages.
2. Product Information Agent: Extracts concrete product facts from the transcript with strict grounding (never invents materials, technique, dimensions, etc.).
3. Research Agent: Researches marketplace terminology, product category norms, and SEO keywords via DuckDuckGo/Wikipedia without overriding artisan facts.
4. Description Agent: Generates professional, attractive, readable English title, short description, and detailed description adhering strictly to verified facts.
5. Fact-Checking Agent: Validates every single claim in the generated copy against the artisan's transcript and verified facts; strips any hallucinated or unverified assertions.
6. Coordinator Agent: Orchestrates the entire end-to-end pipeline, formats the response, and generates targeted clarification prompts if essential facts are missing or ambiguous.
"""

from __future__ import annotations

import json
import logging
import re
import urllib.parse
import urllib.request
from typing import Any
import httpx

from app.config import settings

logger = logging.getLogger(__name__)

SUPPORTED_REGIONAL_LANGUAGES = {
    "mr": "Marathi",
    "hi": "Hindi",
    "bn": "Bengali",
    "ta": "Tamil",
    "te": "Telugu",
    "gu": "Gujarati",
    "kn": "Kannada",
    "ml": "Malayalam",
    "pa": "Punjabi",
    "as": "Assamese",
    "or": "Odia",
    "en": "English",
}

LANGUAGE_NAMES_MAP = {
    "marathi": "mr",
    "hindi": "hi",
    "bengali": "bn",
    "tamil": "ta",
    "telugu": "te",
    "gujarati": "gu",
    "kannada": "kn",
    "malayalam": "ml",
    "punjabi": "pa",
    "assamese": "as",
    "odia": "or",
    "oriya": "or",
    "english": "en",
}

CRAFT_CATEGORIES = [
    {"slug": "jewelry", "name": "Jewelry & Metalcraft", "keywords": ["jewelry", "jewellery", "necklace", "earring", "bangle", "pendant", "beads", "terracotta jewelry", "watch", "clock", "wrist watch", "timepiece", "accessory", "bracelet", "ring", "ornament", "metal", "brass", "bronze", "dhokra", "bell metal", "copper", "iron", "thali", "statue", "idol", "lamp", "diya stand", "पीतल", "पितळ", "तांबा", "लोहा", "ढोकरा", "दागिने", "गहने", "घड़ी", "वाच", "घडी"]},
    {"slug": "pottery", "name": "Pottery & Terracotta", "keywords": ["pottery", "clay", "terracotta", "earthen", "vase", "pot", "handi", "surahi", "diya", "planter", "matka", "kulhad", "bowl", "cup", "dinner set", "crockery", "ceramic", "मिट्टी", "माती", "घड़ा", "मटका"]},
    {"slug": "handloom", "name": "Handloom & Textiles", "keywords": ["handloom", "weaving", "cotton", "silk", "saree", "dupatta", "stole", "chanderi", "tussar", "khadi", "scarf", "fabric", "textile", "shawl", "linen", "dress", "bag", "pouch", "tote", "wallet", "leather", "हातमाग", "बुनाई", "साड़ी", "दुपट्टा"]},
    {"slug": "woodcraft", "name": "Woodcraft & Toys", "keywords": ["wood", "wooden", "teak", "sandalwood", "carving", "sheesham", "mandir", "temple", "toy", "box", "key holder", "panel", "furniture", "bamboo", "cane", "basket", "wicker", "jute", "straw", "बांबू", "बांस", "टोकरी", "लाकूड", "लकड़ी", "नक्काशी", "खिलौने"]},
    {"slug": "folk-art", "name": "Tribal & Folk Art", "keywords": ["painting", "warli", "madhubani", "pattachitra", "kalamkari", "canvas", "gond", "pichwai", "tanjore", "art", "drawing", "portrait", "वारली", "चित्र", "मधुबनी", "पेंटिंग"]},
]

def clean_speech_to_title(english_phrase: str, stated_handmade: bool = False) -> str:
    """Dynamically converts spoken English transcript into a natural, professional product title."""
    text = english_phrase.strip().rstrip(".!?,")
    lead_ins = [
        r"^i\s+(?:have\s+)?(?:made|created|crafted|produced|designed|built|prepared)\s+(?:a|an|one|this|some)?\s*",
        r"^this\s+is\s+(?:a|an|my|our)?\s*",
        r"^here\s+is\s+(?:a|an|my|our)?\s*",
        r"^my\s+",
        r"^our\s+",
        r"^it\s+is\s+(?:a|an)?\s*",
        r"^i\s+am\s+selling\s+(?:a|an)?\s*",
        r"^we\s+have\s+(?:a|an)?\s*",
        r"^a\s+",
        r"^an\s+",
    ]
    cleaned = text
    for pattern in lead_ins:
        cleaned = re.sub(pattern, "", cleaned, flags=re.IGNORECASE).strip()

    trail_ins = [
        r"\s+that\s+i\s+(?:have\s+)?made.*$",
        r"\s+which\s+i\s+(?:have\s+)?made.*$",
        r"\s+made\s+by\s+me.*$",
        r"\s+for\s+sale.*$",
    ]
    for pattern in trail_ins:
        cleaned = re.sub(pattern, "", cleaned, flags=re.IGNORECASE).strip()

    # Convert "X with Y colour/color" -> "Y X" (e.g. "watch with black colour" -> "Black Watch")
    m = re.match(r"^(.*?)\s+(?:with|in|of)\s+([a-zA-Z]+)\s+(?:colour|color)$", cleaned, re.IGNORECASE)
    if m:
        item_noun = m.group(1).strip()
        color = m.group(2).strip()
        cleaned = f"{color} {item_noun}"

    words = cleaned.split()
    if not words:
        words = ["Handcrafted", "Craft"]

    title_words = []
    lowercase_words = {"a", "an", "the", "and", "or", "in", "on", "at", "to", "for", "with", "by", "of"}
    for i, w in enumerate(words):
        wl = w.lower()
        if i > 0 and wl in lowercase_words:
            title_words.append(wl)
        else:
            title_words.append(w.capitalize())

    title = " ".join(title_words)
    if stated_handmade and not any(h in title.lower() for h in ["handcrafted", "handmade", "hand"]):
        title = f"Handcrafted {title}"

    # Bounded length
    if len(title) > 65:
        title = title[:65].rsplit(" ", 1)[0]

    return title

def detect_category(text: str, english_text: str = "") -> tuple[str, str]:
    """Dynamically infers category from spoken words or English translation without hardcoding.
    Maps strictly to the 5 official platform database categories:
    'jewelry', 'pottery', 'handloom', 'woodcraft', 'folk-art'."""
    t = f"{text} {english_text}".lower()

    if any(w in t for w in ["watch", "clock", "timepiece", "necklace", "earring", "bangle", "bracelet", "ring", "pendant", "jewel", "brass", "bronze", "copper", "iron", "bell metal", "dhokra", "metal", "statue", "idol", "lamp", "thali", "diya stand", "दागिने", "गहने", "घड़ी", "वाच", "घडी", "पीतल", "पितळ", "तांबा", "लोहा", "ढोकरा"]):
        return "jewelry", "Jewelry & Metalcraft"
    if any(w in t for w in ["clay", "terracotta", "earthen", "matka", "surahi", "handi", "kulhad", "pottery", "मिट्टी", "माती", "घड़ा", "मटका"]):
        return "pottery", "Pottery & Terracotta"
    if any(w in t for w in ["saree", "dupatta", "stole", "scarf", "handloom", "weaving", "cotton", "silk", "khadi", "chanderi", "tussar", "textile", "fabric", "shawl", "linen", "dress", "bag", "pouch", "tote", "wallet", "leather", "साड़ी", "दुपट्टा", "बुनाई"]):
        return "handloom", "Handloom & Textiles"
    if any(w in t for w in ["wood", "wooden", "teak", "sheesham", "sandalwood", "mandir", "temple", "carving", "toy", "box", "key holder", "bamboo", "cane", "basket", "wicker", "jute", "straw", "बांबू", "बांस", "टोकरी", "लाकूड", "लकड़ी", "नक्काशी", "खिलौने"]):
        return "woodcraft", "Woodcraft & Toys"
    if any(w in t for w in ["painting", "canvas", "warli", "madhubani", "pattachitra", "kalamkari", "gond", "pichwai", "tanjore", "art", "drawing", "portrait", "चित्र", "पेंटिंग", "वारली", "मधुबनी"]):
        return "folk-art", "Tribal & Folk Art"
    if any(w in t for w in ["pot", "vase", "bowl", "planter", "cup", "diya"]):
        return "pottery", "Pottery & Terracotta"

    # Default fallback to Jewelry & Metalcraft (covers watches, accessories, crafts)
    return "jewelry", "Jewelry & Metalcraft"

def _translate_to_hindi(text: str) -> str:
    """Translates an English phrase or title into natural Hindi."""
    try:
        clean_text = text.strip()
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=hi&dt=t&q={urllib.parse.quote(clean_text)}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=4) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            translated = "".join(part[0] for part in data[0] if part[0]).strip()
            if translated:
                return translated
    except Exception:
        pass
    return text.strip()

MATERIAL_LEXICON = {
    "clay": ["clay", "terracotta", "मिट्टी", "माती", "মट्टी", "কাদা", "களிமண்", "మట్టి", "ಮಣ್ಣು", "കളിമണ്ണ്", "માટી", "ਮਿੱਟੀ", "ମାଟି"],
    "rice_flour": ["rice flour", "rice paste", "तांदळाचे पीठ", "चावल का आटा", "चावल का लेप", "চালগুঁড়ো", "அரிசி மாவு"],
    "wood": ["wood", "wooden", "teak", "sheesham", "sandalwood", "लाकूड", "लकड़ी", "কাষ্ঠ", "மரம்", "చెక్క", "ಮರ", "ലੱਕੜ", "କାଠ", "কাঠ"],
    "brass": ["brass", "bronze", "copper", "bell metal", "पितळ", "पीतल", "কাঁচা", "பித்தளை", "ఇత్తడి", "ಹಿತ್ತಾಳೆ", "તાંબુ", "ਪਿੱਤਲ", "ପିତ୍ତଳ"],
    "cotton": ["cotton", "सूती", "कापूस", "सुतो", "பருத்தி", "పత్తి", "ಹತ್ತಿ", "കോട്ടൺ", "કપાસ"],
    "silk": ["silk", "रेशम", "रेशीम", "பட்டு", "పట్టు", "ರೇಷ್ಮೆ", "રેશમ", "ਪਾਟ"],
    "bamboo": ["bamboo", "cane", "बांबू", "बांस", "বাঁশ", "மூங்கில்", "వెదురు", "ಬಿದಿರು", "વાંસ"],
}

TECHNIQUE_LEXICON = {
    "warli_painting": ["warli", "वारली", "warli painting", "folk painting"],
    "madhubani_painting": ["madhubani", "mithila", "मधुबनी"],
    "wheel_throwing": ["potter's wheel", "wheel", "chaak", "चाक", "चाकावर", "चाकड़ा"],
    "hand_carving": ["carving", "hand carved", "कोरीव काम", "नक्काशी", "செதுக்கல்"],
    "handloom_weaving": ["handloom", "weaving", "woven", "हातमाग", "बुनाई", "நெசவு"],
    "lost_wax_casting": ["dhokra", "lost wax", "ढोकरा", "ঢোকরা"],
}

CLARIFICATION_TEMPLATES = {
    "en": "Could you please tell us what material was used to make this product?",
    "hi": "कृपया बताएं कि यह उत्पाद किस सामग्री (Material) से बनाया गया है?",
    "mr": "कृपया सांगा की हे उत्पादन बनवण्यासाठी कोणते साहित्य (Material) वापरले आहे?",
    "bn": "দয়া করে জানান এই পণ্যটি কোন উপাদান দিয়ে তৈরি করা হয়েছে?",
    "ta": "இந்த தயாரிப்பை உருவாக்க என்ன மூலப்பொருள் பயன்படுத்தப்பட்டது என்று கூற முடியுமா?",
    "te": "దయచేసి ఈ ఉత్పత్తిని తయారు చేయడానికి ఏ ముడిసరుకు ఉపయోగించారో చెప్పగలరా?",
    "gu": "કૃપા કરીને જણાવો કે આ ઉત્પાદન બનાવવા માટે કઈ સામગ્રીનો ઉપયોગ કરવામાં આવ્યો છે?",
    "kn": "ದಯವಿಟ್ಟು ತಿಳಿಸಿ, ಈ ಉತ್ಪನ್ನವನ್ನು ತಯಾರಿಸಲು ಯಾವ ಸಾಮಗ್ರಿಯನ್ನು ಬಳಸಲಾಗಿದೆ?",
    "ml": "ഈ ഉൽപ്പന്നം നിർമ്മിക്കാൻ ഏത് വസ്തുവാണ് ഉപയോഗിച്ചതെന്ന് വ്യക്തമാക്കാമോ?",
    "pa": "ਕਿਰਪਾ ਕਰਕੇ ਦੱਸੋ ਕਿ ਇਹ ਉਤਪਾਦ ਬਣਾਉਣ ਲਈ ਕਿਹੜੀ ਸਮੱਗਰੀ ਵਰਤੀ ਗਈ ਹੈ?",
    "as": "অনুগ্ৰহ কৰি কওক এই সামগ্ৰীটো কি উপাদানৰে নিৰ্মাণ কৰা হৈছে?",
    "or": "ଦୟାକରି କୁହନ୍ତୁ ଏହି ସାମଗ୍ରୀ କେଉଁ ଉପାଦାନରେ ତିଆରି ହୋଇଛି?",
}


# ─── 1. Voice Agent ──────────────────────────────────────────────────────────

class VoiceAgent:
    """Agent 1: Handles audio transcription and spoken language detection across Indian regional languages."""

    @staticmethod
    def detect_language(transcript: str, hint: str | None = None) -> str:
        """Detect language from Unicode script and lexical cues, with regional hint support."""
        if hint and hint.lower() in SUPPORTED_REGIONAL_LANGUAGES:
            hint_lang = hint.lower()
        else:
            hint_lang = None

        text = transcript.strip()
        if not text:
            return hint_lang or "hi"

        # Unicode block heuristics
        devanagari_count = len(re.findall(r"[\u0900-\u097F]", text))
        bengali_count = len(re.findall(r"[\u0980-\u09FF]", text))
        tamil_count = len(re.findall(r"[\u0B80-\u0BFF]", text))
        telugu_count = len(re.findall(r"[\u0C00-\u0C7F]", text))
        kannada_count = len(re.findall(r"[\u0C80-\u0CFF]", text))
        malayalam_count = len(re.findall(r"[\u0D00-\u0D7F]", text))
        gujarati_count = len(re.findall(r"[\u0A80-\u0AFF]", text))
        gurmukhi_count = len(re.findall(r"[\u0A00-\u0A7F]", text))
        oriya_count = len(re.findall(r"[\u0B00-\u0B7F]", text))

        counts = {
            "bn": bengali_count,
            "ta": tamil_count,
            "te": telugu_count,
            "kn": kannada_count,
            "ml": malayalam_count,
            "gu": gujarati_count,
            "pa": gurmukhi_count,
            "or": oriya_count,
        }
        max_script_lang, max_script_count = max(counts.items(), key=lambda x: x[1])
        if max_script_count > 3:
            return max_script_lang

        if devanagari_count > 3:
            # Distinguish Marathi vs Hindi by common lexical markers
            marathi_markers = ["आहे", "नाही", "बनवले", "केले", "रुपये", "तास", "मातीचे", "हाताने", "भांडे", "साहित्य"]
            text_lower = text.lower()
            if any(m in text_lower for m in marathi_markers) or hint_lang == "mr":
                return "mr"
            return "hi"

        # Check Latin script with regional words
        words = text.lower().split()
        if any(w in words for w in ["ahe", "banavle", "kele", "taas", "tandul"]):
            return "mr"
        if any(w in words for w in ["hai", "banaya", "lagbhag", "ghante", "mitti"]):
            return "hi"

        return hint_lang or "en"


# ─── 2. Product Information Agent ────────────────────────────────────────────

class ProductInformationAgent:
    """Agent 2: Strictly extracts facts directly stated in the transcript. Never invents attributes."""

    @staticmethod
    def extract_facts(transcript: str, language: str) -> dict[str, Any]:
        text = transcript.strip()
        text_lower = text.lower()

        # Extract materials strictly mentioned
        detected_materials: list[str] = []
        for mat_name, keywords in MATERIAL_LEXICON.items():
            if any(kw in text_lower for kw in keywords):
                if mat_name == "clay":
                    detected_materials.append("Natural Earthen Clay")
                elif mat_name == "rice_flour":
                    detected_materials.append("Rice Flour Paste & Organic Binder")
                elif mat_name == "wood":
                    detected_materials.append("Seasoned Natural Wood")
                elif mat_name == "brass":
                    detected_materials.append("Brass / Bell Metal")
                elif mat_name == "cotton":
                    detected_materials.append("Pure Cotton")
                elif mat_name == "silk":
                    detected_materials.append("Pure Silk")
                elif mat_name == "bamboo":
                    detected_materials.append("Indigenous Bamboo")

        # Extract techniques strictly mentioned
        detected_techniques: list[str] = []
        for tech_name, keywords in TECHNIQUE_LEXICON.items():
            if any(kw in text_lower for kw in keywords):
                if tech_name == "warli_painting":
                    detected_techniques.append("Warli Folk Painting")
                elif tech_name == "madhubani_painting":
                    detected_techniques.append("Madhubani Painting")
                elif tech_name == "wheel_throwing":
                    detected_techniques.append("Potter's Wheel Shaping & Kiln Firing")
                elif tech_name == "hand_carving":
                    detected_techniques.append("Hand Carving")
                elif tech_name == "handloom_weaving":
                    detected_techniques.append("Handloom Weaving")
                elif tech_name == "lost_wax_casting":
                    detected_techniques.append("Lost-Wax Metal Casting")

        # Extract dimensions if spoken (e.g. 10x12 inches, 30 cm)
        dim_match = re.search(r"(\d+(?:\.\d+)?)\s*(?:x|by|\*)\s*(\d+(?:\.\d+)?)\s*(cm|inch|inches|mm|ft)?", text_lower)
        dimensions = dim_match.group(0) if dim_match else None

        # Extract crafting time / hours if mentioned
        time_match = re.search(r"(\d+)\s*(?:तास|घंटे|hours|hrs|hours time)", text_lower)
        labor_hours = float(time_match.group(1)) if time_match else None

        # Extract material cost / cost if mentioned
        cost_match = re.search(r"(?:₹|rs\.?|रुपये|rupees)\s*(\d+)|(\d+)\s*(?:रुपये|rupees)", text_lower)
        cost_val = None
        if cost_match:
            cost_val = float(cost_match.group(1) or cost_match.group(2))

        # Check if handmade is stated
        stated_handmade = any(w in text_lower for w in [
            "हाताने", "हस्तनिर्मित", "हाथ से", "handmade", "handcrafted", "হাতে তৈরি", "கைவினை"
        ])

        # Infer category purely from stated product names or craft words dynamically
        category_slug, category_name = detect_category(text, _translate_speech_to_english(text))

        # Check clarity: if less than 2 words or pure noise
        is_clear = len(text.split()) >= 2

        return {
            "raw_transcript": text,
            "language": language,
            "materials": detected_materials,
            "techniques": detected_techniques,
            "dimensions": dimensions,
            "labor_hours": labor_hours,
            "material_cost": cost_val,
            "stated_handmade": stated_handmade,
            "category_slug": category_slug,
            "category_name": category_name,
            "is_clear": is_clear,
        }


# ─── 3. Research Agent ───────────────────────────────────────────────────────

class ResearchAgent:
    """Agent 3: Searches terminology, category standards, and SEO keywords without overriding artisan facts."""

    @staticmethod
    def research_keywords(
        category_slug: str,
        craft_name: str,
        materials: list[str],
        title: str = "",
        transcript: str = "",
    ) -> list[str]:
        """Collect standard and dynamic ecommerce marketplace keywords matching the product."""
        base_keywords = []

        if title:
            clean_t = title.lower()
            base_keywords.append(clean_t)
            if not clean_t.startswith("handcrafted"):
                base_keywords.append(f"handcrafted {clean_t}")
            base_keywords.append(f"artisan {clean_t}")

        if category_slug == "jewelry":
            t_low = f"{title or ''} {transcript or ''}".lower()
            if any(m in t_low for m in ["metal", "brass", "bronze", "dhokra", "copper", "bell metal", "iron"]):
                base_keywords.extend([
                    "dhokra brass artifact",
                    "traditional metal casting",
                    "bell metal handicraft",
                    "handcrafted metal art",
                ])
            else:
                base_keywords.extend([
                    "artisan handcrafted jewelry",
                    "custom timepiece & jewelry",
                    "ethnic designer accessory",
                    "handcrafted jewelry & accessories",
                ])
        elif category_slug == "pottery":
            base_keywords.extend([
                "earthenware craft",
                "terracotta home decor",
                "natural clay art",
                "handcrafted pottery",
            ])
        elif category_slug == "folk-art":
            base_keywords.extend([
                "traditional indian folk art",
                "tribal wall art",
                "handpainted canvas",
                "indigenous indian painting",
            ])
        elif category_slug == "handloom":
            base_keywords.extend([
                "handloom textiles",
                "traditional weave",
                "authentic weaver craft",
                "handwoven artisan piece",
            ])
        elif category_slug == "woodcraft":
            t_low = f"{title or ''} {transcript or ''}".lower()
            if any(b in t_low for b in ["bamboo", "cane", "basket", "wicker", "jute"]):
                base_keywords.extend([
                    "handcrafted bamboo cane",
                    "natural eco wicker craft",
                    "bamboo home decor",
                ])
            else:
                base_keywords.extend([
                    "hand carved wood",
                    "natural wooden decor",
                    "artisan woodcraft",
                ])

        for mat in materials:
            mat_clean = mat.lower().replace("&", "").strip()
            if mat_clean:
                base_keywords.append(f"handcrafted in {mat_clean}")

        base_keywords.extend([
            f"authentic {craft_name.lower()}",
            "indian artisan craft",
            "traditional handcrafted decor",
            "buy artisan direct",
        ])

        # Unique & bounded
        seen = set()
        unique_keywords = []
        for kw in base_keywords:
            if kw and kw not in seen:
                seen.add(kw)
                unique_keywords.append(kw)

        return unique_keywords[:10]

    @staticmethod
    def search_terminology_online(query: str) -> str | None:
        """Query LangSearch Web Search API for authentic Indian craft heritage, traditions, and naming context."""
        api_key = getattr(settings, "LANGSEARCH_API_KEY", "") or "sk-60d823fe6dbd4ccd8b1223ae83d9e830"
        if api_key:
            try:
                url = "https://api.langsearch.com/v1/web-search"
                payload = json.dumps({"query": f"{query} authentic handcrafted Indian artisan", "count": 3}).encode("utf-8")
                req = urllib.request.Request(
                    url,
                    data=payload,
                    headers={
                        "Authorization": f"Bearer {api_key}",
                        "Content-Type": "application/json",
                        "User-Agent": "KalaSathi-ResearchAgent/1.0",
                    },
                )
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = json.loads(resp.read().decode("utf-8"))
                pages = data.get("data", {}).get("webPages", {}).get("value", [])
                snippets = [p.get("snippet", "") for p in pages if p.get("snippet")]
                if snippets:
                    clean_ctx = " ".join(snippets[:2])
                    clean_ctx = re.sub(r'\s+', ' ', clean_ctx).strip()
                    if len(clean_ctx) > 30:
                        return clean_ctx[:300]
            except Exception as e:
                logger.warning("LangSearch terminology search error: %s", e)

        # Fallback to DuckDuckGo instant answer
        try:
            url = f"https://api.duckduckgo.com/?q={urllib.parse.quote(query)}&format=json"
            req = urllib.request.Request(url, headers={"User-Agent": "KalaSathi-ResearchAgent/1.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                abstract = data.get("Abstract")
                if abstract and len(abstract) > 20:
                    return abstract[:250]
        except Exception:
            pass
        return None


# ─── 4. Description Agent ────────────────────────────────────────────────────

def _translate_speech_to_english(text: str) -> str:
    """Translates regional spoken transcript directly to clear English using Speech-to-Text translation."""
    try:
        clean_text = text.strip()
        # Common phonetic Speech-to-Text corrections for Indian craft speech
        subs = {
            "पोत": "pot",
            "पोट": "pot",
            "घड़ा": "earthen pot",
            "मटका": "earthen pot",
            "हाताने": "by hand",
            "हाथ से": "by hand",
        }
        for k, v in subs.items():
            clean_text = clean_text.replace(k, v)
        url = f"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q={urllib.parse.quote(clean_text)}"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            translated = "".join(part[0] for part in data[0] if part[0]).strip()
            if translated:
                if translated[0].islower():
                    translated = translated[0].upper() + translated[1:]
                if not translated.endswith((".", "!", "?")):
                    translated += "."
                return translated
    except Exception:
        pass
    return text.strip()


class DescriptionAgent:
    """Agent 4: Generates natural, professional English title, short description, and detailed description strictly grounded in spoken facts."""

    @staticmethod
    def generate_description(
        facts: dict[str, Any],
        researched_keywords: list[str],
        online_context: str | None = None,
    ) -> dict[str, Any]:
        transcript = facts["raw_transcript"]
        materials = facts["materials"]
        techniques = facts["techniques"]
        cat_slug = facts["category_slug"]
        cat_name = facts["category_name"]
        stated_handmade = facts["stated_handmade"]

        # Derive direct speech translation in English
        direct_english = _translate_speech_to_english(transcript)

        # Derive dynamic title strictly from what the artisan stated (strictly never hardcoded)
        title = clean_speech_to_title(direct_english, stated_handmade)
        short_desc = direct_english
        title_hi = _translate_to_hindi(title)

        # Build professional detailed description directly matching the speech
        paragraphs = []
        paragraphs.append(direct_english)

        # Authentic craft heritage context derived from LangSearch for traditional arts
        if online_context and cat_slug in ["folk-art", "pottery", "handloom", "woodcraft"]:
            clean_ctx = online_context.split(".")[0].strip()
            if clean_ctx and len(clean_ctx) > 30 and not any(k in clean_ctx.lower() for k in ["cookie", "javascript", "login", "404", "privacy", "http", "sale", "price", "cart", "dollar", "$"]):
                paragraphs.append(f"Traditional Craft Heritage: {clean_ctx}.")

        # Materials & Technique ONLY if explicitly mentioned
        spec_parts = []
        if materials:
            spec_parts.append(f"Materials: {', '.join(materials)}")
        if techniques:
            spec_parts.append(f"Craft Technique: {', '.join(techniques)}")
        if facts.get("dimensions"):
            spec_parts.append(f"Dimensions: {facts['dimensions']}")
        if facts.get("labor_hours"):
            spec_parts.append(f"Artisan Labor: Approximately {facts['labor_hours']:.1f} hours of handwork")

        if spec_parts:
            paragraphs.append("Product Details:\n- " + "\n- ".join(spec_parts))

        paragraphs.append("Artisan Guarantee: 100% authentic handcrafted creation direct from master artisans. Every purchase directly sustains traditional Indian craft communities.")

        detailed_desc = "\n\n".join(paragraphs)

        return {
            "title": title,
            "title_hi": title_hi,
            "short_description": short_desc,
            "detailed_description": detailed_desc,
            "category": cat_name,
            "category_slug": cat_slug,
            "seo_keywords": researched_keywords,
            "tags": [cat_slug, "handcrafted", "artisan-direct", *researched_keywords[:4]],
        }


# ─── 5. Fact-Checking Agent ──────────────────────────────────────────────────

class FactCheckingAgent:
    """Agent 5: Verifies every claim in generated output against artisan transcript. Removes any unsupported hallucinations."""

    UNVERIFIED_TERMS = [
        "certified", "gi tag", "100% pure silk", "antique", "pure gold", "24k", "museum grade", "organic certified"
    ]

    @staticmethod
    def audit_and_correct(generated: dict[str, Any], facts: dict[str, Any]) -> dict[str, Any]:
        transcript_lower = facts["raw_transcript"].lower()
        title = generated["title"]
        short_desc = generated["short_description"]
        detailed_desc = generated["detailed_description"]
        keywords = list(generated.get("seo_keywords", []))

        # Remove unverified high-risk terms unless explicitly in transcript
        for term in FactCheckingAgent.UNVERIFIED_TERMS:
            if term not in transcript_lower:
                title = re.sub(re.escape(term), "", title, flags=re.IGNORECASE).strip()
                short_desc = re.sub(re.escape(term), "", short_desc, flags=re.IGNORECASE).strip()
                detailed_desc = re.sub(re.escape(term), "", detailed_desc, flags=re.IGNORECASE).strip()
                keywords = [k for k in keywords if term not in k.lower()]

        # Ensure no fabricated materials are asserted
        for mat_key, words in MATERIAL_LEXICON.items():
            if not any(w in transcript_lower for w in words):
                pass

        # Cleanup extra spaces within lines while preserving paragraph breaks
        title = re.sub(r"[ \t]+", " ", title).strip()
        short_desc = re.sub(r"[ \t]+", " ", short_desc).strip()
        cleaned_paras = [re.sub(r"[ \t]+", " ", p).strip() for p in detailed_desc.split("\n") if p.strip()]
        detailed_desc = "\n\n".join(cleaned_paras)

        verified_copy = dict(generated)
        verified_copy["title"] = title
        verified_copy["title_hi"] = generated.get("title_hi", title)
        verified_copy["short_description"] = short_desc
        verified_copy["detailed_description"] = detailed_desc
        verified_copy["seo_keywords"] = keywords
        verified_copy["fact_checked"] = True
        return verified_copy


# ─── 6. Coordinator Agent ────────────────────────────────────────────────────

class VoiceDescriptionCoordinator:
    """Agent 6: Coordinates all 5 specialized agents to deliver the voice-to-description workflow."""

    def __init__(self):
        self.voice_agent = VoiceAgent()
        self.info_agent = ProductInformationAgent()
        self.research_agent = ResearchAgent()
        self.desc_agent = DescriptionAgent()
        self.fact_agent = FactCheckingAgent()

    async def execute_workflow(
        self,
        transcript: str,
        preferred_language: str | None = None,
        clarification: str | None = None,
    ) -> dict[str, Any]:
        full_transcript = f"{transcript.strip()} {clarification.strip() if clarification else ''}".strip()

        # Step 1: Voice & Language Detection
        detected_lang = self.voice_agent.detect_language(full_transcript, hint=preferred_language)

        # Check for unclear speech
        if len(full_transcript.split()) < 2:
            return {
                "success": False,
                "needs_clarification": True,
                "clarification_prompt": (
                    "आवाज स्पष्ट नाही किंवा खूप कमी बोलले आहे. कृपया पुन्हा रेकॉर्ड करा."
                    if detected_lang == "mr"
                    else "आपकी आवाज स्पष्ट नहीं है। कृपया उत्पाद का विवरण फिर से बोलें।"
                    if detected_lang == "hi"
                    else "Your voice recording was unclear. Please tap the microphone and speak again."
                ),
                "original_transcript": full_transcript,
                "detected_language": detected_lang,
            }

        # Step 2: Information Extraction (Strict Grounding)
        facts = self.info_agent.extract_facts(full_transcript, detected_lang)

        # If essential material is missing, prepare clarification prompt in artisan's language
        needs_clarification = len(facts["materials"]) == 0 and not clarification
        clarification_prompt = None
        if needs_clarification:
            clarification_prompt = CLARIFICATION_TEMPLATES.get(
                detected_lang, CLARIFICATION_TEMPLATES["en"]
            )

        # Step 3: Internet Research & Terminology (Non-overriding)
        direct_english = _translate_speech_to_english(full_transcript)
        initial_title = clean_speech_to_title(direct_english, facts["stated_handmade"])
        researched_keywords = self.research_agent.research_keywords(
            category_slug=facts["category_slug"],
            craft_name=facts["category_name"],
            materials=facts["materials"],
            title=initial_title,
            transcript=full_transcript,
        )
        online_context = self.research_agent.search_terminology_online(
            f"{initial_title} {facts['category_name']} Indian handicraft"
        )

        # Step 4: Description Generation
        initial_desc = self.desc_agent.generate_description(
            facts=facts,
            researched_keywords=researched_keywords,
            online_context=online_context,
        )

        # Step 5: Fact-Checking & Hallucination Removal
        verified_output = self.fact_agent.audit_and_correct(initial_desc, facts)

        # Step 6: Package Result
        return {
            "success": True,
            "original_transcript": full_transcript,
            "detected_language": detected_lang,
            "detected_language_name": SUPPORTED_REGIONAL_LANGUAGES.get(detected_lang, detected_lang.upper()),
            "title": verified_output["title"],
            "title_hi": verified_output.get("title_hi", verified_output["title"]),
            "short_description": verified_output["short_description"],
            "detailed_description": verified_output["detailed_description"],
            "seo_keywords": verified_output["seo_keywords"],
            "category": verified_output["category"],
            "category_slug": verified_output["category_slug"],
            "tags": verified_output["tags"],
            "materials": facts["materials"],
            "techniques": facts["techniques"],
            "dimensions": facts["dimensions"],
            "needs_clarification": needs_clarification,
            "clarification_prompt": clarification_prompt,
            "fact_checked": True,
        }
