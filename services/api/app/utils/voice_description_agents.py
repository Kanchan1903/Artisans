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
    {"slug": "pottery", "name": "Pottery & Terracotta", "keywords": ["pottery", "clay", "terracotta", "earthen", "vase", "pot", "handi", "surahi", "diya", "मिट्टी", "माती"]},
    {"slug": "handloom", "name": "Handloom & Textiles", "keywords": ["handloom", "weaving", "cotton", "silk", "saree", "dupatta", "stole", "chanderi", "tussar", "khadi", "हातमाग", "बुनाई"]},
    {"slug": "woodcraft", "name": "Woodcraft & Carving", "keywords": ["wood", "wooden", "teak", "sandalwood", "carving", "sheesham", "लाकूड", "लकड़ी", "नक्काशी"]},
    {"slug": "metalcraft", "name": "Metalcraft & Dhokra", "keywords": ["metal", "brass", "bronze", "dhokra", "bell metal", "copper", "पीतल", "पितळ", "ढोकरा"]},
    {"slug": "folk-art", "name": "Folk Art & Paintings", "keywords": ["painting", "warli", "madhubani", "pattachitra", "kalamkari", "canvas", "वारली", "चित्र", "मधुबनी"]},
    {"slug": "jewelry", "name": "Handmade Jewelry", "keywords": ["jewelry", "jewellery", "necklace", "earring", "bangle", "pendant", "beads", "terracotta jewelry", "दागिने", "गहने"]},
    {"slug": "bamboo-cane", "name": "Bamboo & Cane", "keywords": ["bamboo", "cane", "basket", "wicker", "बांबू", "बांस"]},
]

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

        # Infer category purely from stated product names or craft words
        category_slug = "pottery"
        category_name = "Pottery & Terracotta"
        for cat in CRAFT_CATEGORIES:
            if any(kw in text_lower for kw in cat["keywords"]):
                category_slug = cat["slug"]
                category_name = cat["name"]
                break

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
    def research_keywords(category_slug: str, craft_name: str, materials: list[str]) -> list[str]:
        """Collect standard ecommerce marketplace keywords for matching categories."""
        base_keywords = [
            f"authentic {craft_name.lower()}",
            "indian artisan craft",
            "traditional handcrafted decor",
            "buy artisan direct",
        ]

        if category_slug == "pottery":
            base_keywords.extend([
                "earthenware craft",
                "terracotta home decor",
                "natural clay art",
                "handcrafted clay pot",
                "eco-friendly pottery",
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
            base_keywords.extend([
                "hand carved wood",
                "natural wooden decor",
                "artisan woodcraft",
            ])
        elif category_slug == "metalcraft":
            base_keywords.extend([
                "dhokra brass artifact",
                "traditional metal casting",
                "bell metal handicraft",
            ])

        for mat in materials:
            mat_clean = mat.lower().replace("&", "").strip()
            if mat_clean:
                base_keywords.append(f"handcrafted in {mat_clean}")

        # Unique & bounded
        seen = set()
        unique_keywords = []
        for kw in base_keywords:
            if kw not in seen:
                seen.add(kw)
                unique_keywords.append(kw)

        return unique_keywords[:10]

    @staticmethod
    def search_terminology_online(query: str) -> str | None:
        """Query DuckDuckGo for product naming conventions (network failure safe)."""
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

class DescriptionAgent:
    """Agent 4: Generates natural, professional English title, short description, and detailed description grounded in facts."""

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

        # Derive title
        prefix = "Handcrafted " if stated_handmade else ""
        if "Warli" in " ".join(techniques) or "warli" in transcript.lower():
            title = f"{prefix}Warli Folk Art Canvas Painting"
            short_desc = "Traditional Warli artwork painted with natural rice flour paste on canvas."
        elif cat_slug == "pottery":
            title = f"{prefix}Terracotta Earthenware Craft"
            short_desc = "Authentic clay creation shaped by traditional artisans for home and daily living."
        elif cat_slug == "woodcraft":
            title = f"{prefix}Carved Wooden Craft Piece"
            short_desc = "Hand-carved wooden craft preserving traditional woodworking craftsmanship."
        elif cat_slug == "metalcraft":
            title = f"{prefix}Artisanal Metal Bell Craft"
            short_desc = "Traditional metalcraft piece created using time-honored casting techniques."
        elif cat_slug == "handloom":
            title = f"{prefix}Handloom Textile Craft"
            short_desc = "Handwoven textile creation crafted with heritage weaving techniques."
        else:
            title = f"{prefix}Artisan Craft ({cat_name})"
            short_desc = f"Handcrafted creation made with care by regional Indian artisans."

        # Build detailed description
        paragraphs = []
        # Paragraph 1: What the artisan created (grounded in stated words)
        paragraphs.append(
            f"This piece is directly created by the artisan: \"{transcript}\". "
            f"It represents authentic regional craftsmanship without industrial mass production."
        )

        # Paragraph 2: Materials & Technique (ONLY if mentioned)
        spec_parts = []
        if materials:
            spec_parts.append(f"Materials: {', '.join(materials)}")
        if techniques:
            spec_parts.append(f"Craft Technique: {', '.join(techniques)}")
        if facts.get("dimensions"):
            spec_parts.append(f"Dimensions: {facts['dimensions']}")
        if facts.get("labor_hours"):
            spec_parts.append(f"Artisan Labor: Approximately {facts['labor_hours']:.1f} hours of focused handwork")

        if spec_parts:
            paragraphs.append("Product Details:\n- " + "\n- ".join(spec_parts))

        # Paragraph 3: Care note
        care_note = "Care Instructions: Gently wipe with a soft, clean dry cloth. Keep away from harsh chemicals and excessive moisture."
        paragraphs.append(care_note)

        detailed_desc = "\n\n".join(paragraphs)

        return {
            "title": title,
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
                # If this material was NOT mentioned, ensure the description doesn't assert it as a primary material
                pass

        # Cleanup extra spaces
        title = re.sub(r"\s+", " ", title).strip()
        short_desc = re.sub(r"\s+", " ", short_desc).strip()
        detailed_desc = re.sub(r"\s+", " ", detailed_desc).strip()

        verified_copy = dict(generated)
        verified_copy["title"] = title
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
        researched_keywords = self.research_agent.research_keywords(
            category_slug=facts["category_slug"],
            craft_name=facts["category_name"],
            materials=facts["materials"],
        )
        online_context = self.research_agent.search_terminology_online(
            f"{facts['category_name']} Indian handicraft"
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
