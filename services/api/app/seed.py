"""Database seed script for KalaSathi platform.

Seeds:
- 1 Admin user
- 3 Authentic rural artisans (Warli, Madhubani, Channapatna)
- 5 Verified buyers
- 5 Craft categories
- 20 Handcrafted products with 12-language translations and images
- Sample orders, order items, reviews, and inquiries
"""
import asyncio
import logging
from datetime import datetime, timezone
from sqlalchemy import select, delete
from app.database import AsyncSessionLocal, engine, Base, init_db
from app.models.user import User, UserRole, Language
from app.models.artisan import ArtisanProfile
from app.models.product import Category, Product, ProductImage, ProductTranslation, ProductStatus
from app.models.order import Order, OrderItem, OrderStatus, PaymentMethod
from app.models.review import Review
from app.models.inquiry import Inquiry
from app.models.notification import Notification
from app.models.earning import Earning, EarningStatus

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("seed")


CATEGORIES_DATA = [
    {"name": "Tribal & Folk Art", "name_hi": "जनजातीय और लोक कला", "slug": "folk-art", "icon_url": "palette"},
    {"name": "Woodcraft & Toys", "name_hi": "काष्ठकला और खिलौने", "slug": "woodcraft", "icon_url": "tree"},
    {"name": "Pottery & Terracotta", "name_hi": "मिट्टी के बर्तन और टेराकोटा", "slug": "pottery", "icon_url": "circle"},
    {"name": "Handloom & Textiles", "name_hi": "हथकरघा और वस्त्र", "slug": "handloom", "icon_url": "scissors"},
    {"name": "Jewelry & Metalcraft", "name_hi": "पारंपरिक आभूषण व धातुशिल्प", "slug": "jewelry", "icon_url": "sparkles"},
]

ARTISANS_DATA = [
    {
        "phone": "+919800000001",
        "name": "Sunita Bai Sonawane",
        "email": "sunita.warli@kalasathi.org",
        "language": Language.mr,
        "craft_type": "Warli Tribal Canvas Art",
        "village": "Ganjad",
        "district": "Palghar",
        "state": "Maharashtra",
        "years_experience": 18,
        "bio": "Sunita Bai preserves indigenous Warli folklore using natural rice-flour paste on treated earthen canvases.",
        "bio_hi": "सुनीता बाई पारंपरिक वारली लोककला की सिद्धहस्त कलाकार हैं जो चावल के आटे से प्रकृति और उत्सव के चित्र बनाती हैं।",
        "bio_mr": "सुनीता बाई या पालघरच्या गांजड गावातील मातब्बर वारली चित्रकार आहेत. त्या तांदळाच्या पिठाने पारंपरिक सण व निसर्गाचे सुंदर रेखाटन करतात.",
        "profile_photo_url": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400",
        "upi_id": "sunita.warli@upi",
    },
    {
        "phone": "+919800000002",
        "name": "Rameshwar Chitrakar",
        "email": "rameshwar.mithila@kalasathi.org",
        "language": Language.hi,
        "craft_type": "Madhubani (Mithila) Painting",
        "village": "Ranti",
        "district": "Madhubani",
        "state": "Bihar",
        "years_experience": 24,
        "bio": "Master artisan creating intricate Kachni and Bharni style paintings with bamboo twig pens and botanical inks.",
        "bio_hi": "रामेश्वर चित्रकार 24 वर्षों से मिथिला की पावन धरती पर बांस की कलम से प्राकृतिक रंगों द्वारा जीवन वृत्त व कोहबर बनाते हैं।",
        "bio_mr": "रामेश्वर चित्रकार हे गेल्या २४ वर्षांपासून बांबूच्या काडीने नैसर्गिक रंगांचा वापर करून प्रसिद्ध मिथिला चित्रे रेखाटतात.",
        "profile_photo_url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400",
        "upi_id": "rameshwar.mithila@upi",
    },
    {
        "phone": "+919800000003",
        "name": "Basavaraju Gudigar",
        "email": "basavaraju.toys@kalasathi.org",
        "language": Language.kn,
        "craft_type": "Channapatna Lacquerware Woodcraft",
        "village": "Channapatna",
        "district": "Ramanagara",
        "state": "Karnataka",
        "years_experience": 20,
        "bio": "State-awarded woodturner making child-safe, non-toxic lacquer toys and nesting dolls from ivory wood.",
        "bio_hi": "बसवराजू चन्नपटना की पारंपरिक खिलौना कला के विशेषज्ञ हैं जो प्राकृतिक वनस्पति लाख से विष-रहित खिलौने बनाते हैं।",
        "bio_mr": "बसवराजू हे चन्नपटना येथील पारंपारिक लाकडी खेळणी बनवणारे कसबी कारागीर आहेत. ते वनस्पती रंगांनी सुरक्षित खेळणी घडवतात.",
        "profile_photo_url": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400",
        "upi_id": "basavaraju.craft@upi",
    },
]

BUYERS_DATA = [
    {"phone": "+919820000001", "name": "Pooja Kulkarni", "email": "pooja.kulkarni@example.com", "language": Language.mr},
    {"phone": "+919820000002", "name": "Rajesh Varma", "email": "rajesh.varma@example.com", "language": Language.hi},
    {"phone": "+919820000003", "name": "Ananya Deshpande", "email": "ananya.d@example.com", "language": Language.mr},
    {"phone": "+919820000004", "name": "Vikramaditya Sen", "email": "vikram.sen@example.com", "language": Language.bn},
    {"phone": "+919820000005", "name": "Meera Swaminathan", "email": "meera.s@example.com", "language": Language.ta},
]

# 20 Authentic Products with images and 12-language translations
PRODUCTS_DATA = [
    # Sunita's Warli Products (1-7)
    {
        "artisan_idx": 0, "cat_slug": "folk-art", "price": 1800.0, "stock": 5,
        "title_en": "Warli Village Harvest Celebration Canvas",
        "desc_en": "Authentic handmade Warli painting on treated earthen canvas depicting the sacred Tarpa dance and bumper harvest celebration.",
        "title_hi": "वारली ग्राम फसल उत्सव कैनवास चित्रकला",
        "desc_hi": "चावल के आटे और प्राकृतिक गोंद से निर्मित पारंपरिक वारली चित्रकला, जिसमें तारपा नृत्य और फसल उत्सव दर्शाया गया है।",
        "material": "Handspun Cotton, Rice Flour Paste, Organic Gum",
        "technique": "Freehand Bamboo Twig Painting",
        "care": "Keep away from moisture. Dust gently with dry cloth.",
        "image": "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800",
    },
    {
        "artisan_idx": 0, "cat_slug": "folk-art", "price": 2400.0, "stock": 3,
        "title_en": "Sacred Tarpa Dance Circular Folk Painting",
        "desc_en": "Dynamic depiction of the communal spiral Tarpa dance honouring Mother Nature and tribal brotherhood.",
        "title_hi": "पवित्र तारपा नृत्य वारली वृत्त चित्रकला",
        "desc_hi": "आदिवासी समुदाय के पवित्र तारपा नृत्य का वृत्ताकार मनमोहक चित्रण।",
        "material": "Earthen Clay Washed Canvas, Rice Paste",
        "technique": "Lineage Spiral Warli Style",
        "care": "Frame under glass.",
        "image": "https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=800",
    },
    {
        "artisan_idx": 0, "cat_slug": "folk-art", "price": 1250.0, "stock": 8,
        "title_en": "Tree of Life and Forest Fauna Warli Panel",
        "desc_en": "Symbolic representation of harmony between village dwellers, sacred peepal trees, and forest creatures.",
        "title_hi": "वारली जीवन वृक्ष एवं वन्य प्राणी पटल",
        "desc_hi": "प्रकृति, वृक्ष और वन्य जीवन के सह-अस्तित्व को दर्शाता पारंपरिक वारली पैनल।",
        "material": "Treated Khadi Canvas, Organic Rice Dye",
        "technique": "Bamboo Stylus Sketching",
        "care": "Wipe with dry microfiber cloth.",
        "image": "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800",
    },
    {
        "artisan_idx": 0, "cat_slug": "pottery", "price": 750.0, "stock": 10,
        "title_en": "Handpainted Warli Terracotta Tea Kulhad Set (Set of 4)",
        "desc_en": "Porous natural riverbed clay kulhads hand-adorned with delicate Warli tribal figures.",
        "title_hi": "वारली हस्तचित्रित टेराकोटा चाय कुल्हड़ सेट (4 का सेट)",
        "desc_hi": "नदी की शुद्ध मिट्टी से चाक पर बने और वारली चित्रों से सजे पर्यावरण-अनुकूल कुल्हड़।",
        "material": "Riverbed Terracotta Clay, Non-toxic Rice Pigment",
        "technique": "Wheel Throwing & Fine Line Brush Art",
        "care": "Hand wash with plain water.",
        "image": "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800",
    },
    {
        "artisan_idx": 0, "cat_slug": "handloom", "price": 1600.0, "stock": 6,
        "title_en": "Warli Motifs Hand-Embroidered Cotton Table Runner",
        "desc_en": "Pure organic handwoven cotton table runner featuring traditional tribal marriage procession motifs.",
        "title_hi": "वारली हस्तकशीदाकारी सूती टेबल रनर",
        "desc_hi": "हाथ से काते सूती कपड़े पर वारली विवाह उत्सव की बारीक हाथ की कढ़ाई।",
        "material": "100% Organic Handloom Cotton",
        "technique": "Hand Embroidery with Cotton Floss",
        "care": "Gentle hand wash in cold water.",
        "image": "https://images.unsplash.com/photo-1606744837616-56c9a5c6a6eb?w=800",
    },
    {
        "artisan_idx": 0, "cat_slug": "folk-art", "price": 950.0, "stock": 12,
        "title_en": "Rustic Warli Sun & Moon Wall Hanging Plaque",
        "desc_en": "Handcrafted terracotta wall medallion paying homage to cosmic celestial deities.",
        "title_hi": "वारली सूर्य और चंद्र टेराकोटा दीवार पट्टिका",
        "desc_hi": "सूर्य और चंद्रमा के आशीर्वाद को दर्शाने वाली मिट्टी की सुंदर सजावटी पट्टिका।",
        "material": "Baked Terracotta, Natural Clay Washes",
        "technique": "Relief Clay Sculpting & Pigment Detailing",
        "care": "Indoor wall mount only.",
        "image": "https://images.unsplash.com/photo-1544816155-12df9643f363?w=800",
    },
    {
        "artisan_idx": 0, "cat_slug": "woodcraft", "price": 850.0, "stock": 9,
        "title_en": "Handcarved Warli Motif Teakwood Coaster Set",
        "desc_en": "Six reclaimed teak coasters engraved with village harvest and celebratory dance motifs.",
        "title_hi": "वारली नक्काशीदार सागौन लकड़ी कोस्टर सेट",
        "desc_hi": "छह कोस्टरों का सेट जिस पर वारली आकृतियों की बारीक नक्काशी की गई है।",
        "material": "Reclaimed Teakwood, Natural Beeswax",
        "technique": "Chisel Wood Relief Engraving",
        "care": "Wipe clean with moist sponge.",
        "image": "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=800",
    },

    # Rameshwar's Madhubani Products (8-14)
    {
        "artisan_idx": 1, "cat_slug": "folk-art", "price": 3200.0, "stock": 2,
        "title_en": "Madhubani Tree of Life Mithila Painting",
        "desc_en": "Intricate Kachni style Tree of Life canvas embodying spiritual harmony, peacocks, and prosperity.",
        "title_hi": "मधुबनी जीवन वृक्ष मिथिला चित्रकला",
        "desc_hi": "कचनी शैली में निर्मित मधुबनी जीवन वृक्ष, जो समृद्धि और प्राकृतिक सद्भाव का प्रतीक है।",
        "material": "Handmade Rag Paper, Plant Indigo, Turmeric Pigment",
        "technique": "Fine Line Kachni Style with Bamboo Nib",
        "care": "Frame under glass to protect from direct sunlight.",
        "image": "https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800",
    },
    {
        "artisan_idx": 1, "cat_slug": "folk-art", "price": 2800.0, "stock": 4,
        "title_en": "Mithila Kohbar Auspicious Lotus Canvas",
        "desc_en": "Traditional Mithila Kohbar artwork symbolizing fertility, marital longevity, and auspicious blessing.",
        "title_hi": "मिथिला कोहबर शुभ कमल चित्रकला",
        "desc_hi": "वैवाहिक सुख और मंगल कामना का प्रतीक पारंपरिक मिथिला कोहबर चित्र।",
        "material": "Tussar Silk Treated Cloth, Botanical Dyes",
        "technique": "Bharni Style Solid Natural Color Infilling",
        "care": "Dry clean silk canvas only.",
        "image": "https://images.unsplash.com/photo-1582562124811-c09040d0a901?w=800",
    },
    {
        "artisan_idx": 1, "cat_slug": "folk-art", "price": 2100.0, "stock": 5,
        "title_en": "Dancing Peacock Couple Mithila Painting",
        "desc_en": "Vibrant portrayal of rain peacocks rendered in natural green leaf extract and marigold yellow.",
        "title_hi": "नृत्यरत मयूर युगल मधुबनी चित्र",
        "desc_hi": "गेंदे के फूल और नीम के पत्तों के प्राकृतिक रंगों से बना मयूर युगल चित्र।",
        "material": "Handmade Cotton Rag Paper",
        "technique": "Double Line Nib Freehand Drawing",
        "care": "Avoid humid display areas.",
        "image": "https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=800",
    },
    {
        "artisan_idx": 1, "cat_slug": "handloom", "price": 4500.0, "stock": 3,
        "title_en": "Handpainted Madhubani Tussar Silk Dupatta",
        "desc_en": "Pure Bhagalpur Tussar silk stole hand-painted with Mithila floral vines and fish motifs along borders.",
        "title_hi": "हस्तचित्रित मधुबनी तसर सिल्क दुपट्टा",
        "desc_hi": "भागलपुरी तसर सिल्क पर हाथ से चित्रित सुंदर मधुबनी आकृतियों वाला दुपट्टा।",
        "material": "Pure Tussar Silk, Natural Pigments",
        "technique": "Textile Freehand Pen Painting",
        "care": "Dry clean only.",
        "image": "https://images.unsplash.com/photo-1606744837616-56c9a5c6a6eb?w=800",
    },
    {
        "artisan_idx": 1, "cat_slug": "folk-art", "price": 1400.0, "stock": 7,
        "title_en": "Sacred Fish of Mithila Folk Art Plaque",
        "desc_en": "Fish motifs symbolizing abundance and fertility, intricately rendered on handmade lokta paper.",
        "title_hi": "मिथिला मत्स्य मंगल लोककला पटल",
        "desc_hi": "समृद्धि और सौभाग्य का प्रतीक मधुबनी मछली चित्रकला।",
        "material": "Lokta Handmade Botanical Paper",
        "technique": "Bamboo Twig Hatching",
        "care": "Keep dry and framed.",
        "image": "https://images.unsplash.com/photo-1544816155-12df9643f363?w=800",
    },
    {
        "artisan_idx": 1, "cat_slug": "jewelry", "price": 850.0, "stock": 15,
        "title_en": "Madhubani Handpainted Wooden Pendant Necklace",
        "desc_en": "Lightweight mango wood medallion hand-painted with sun motifs strung on raw jute beads.",
        "title_hi": "मधुबनी हस्तचित्रित लकड़ी का पेंडेंट हार",
        "desc_hi": "आम की लकड़ी पर हाथ से चित्रित सूर्य आकृति वाला पारंपरिक आभूषण।",
        "material": "Seasoned Mango Wood, Jute Cord, Brass Clasp",
        "technique": "Miniature Wood Painting & Lacquer Seal",
        "care": "Avoid direct perfume spray.",
        "image": "https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=800",
    },
    {
        "artisan_idx": 1, "cat_slug": "pottery", "price": 600.0, "stock": 11,
        "title_en": "Handpainted Mithila Clay Diya Set of 6",
        "desc_en": "Festive baked terracotta oil lamps hand-detailed with Madhubani auspicious geometric petals.",
        "title_hi": "हस्तचित्रित मधुबनी मिट्टी के दीये (6 का सेट)",
        "desc_hi": "पारंपरिक शुभ त्योहारों के लिए मधुबनी कला से रंगे टेराकोटा दीपक।",
        "material": "Natural Red Clay, Water-based Pigments",
        "technique": "Wheel Turned & Painted with Fine Hair Brush",
        "care": "Use standard vegetable oil or ghee.",
        "image": "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800",
    },

    # Basavaraju's Channapatna Products (15-20)
    {
        "artisan_idx": 2, "cat_slug": "woodcraft", "price": 650.0, "stock": 14,
        "title_en": "Channapatna Eco-Friendly Wooden Stacking Toy",
        "desc_en": "Safe, smooth non-toxic wooden nesting toys for children hand-lathed from Wrightia tinctoria (Aale mara) wood.",
        "title_hi": "चन्नपटना पर्यावरण अनुकूल लकड़ी का खिलौना",
        "desc_hi": "शुद्ध हाथी लकड़ी और प्राकृतिक वनस्पति रंगों से बना सुरक्षित और विष-मुक्त पारंपरिक खिलौना।",
        "material": "Ivory Wood (Aale Mara), Vegetable Lacquer, Beeswax",
        "technique": "Traditional Lathe Turning & Friction Lacquering",
        "care": "Wipe clean with a damp cloth. Do not soak in water.",
        "image": "https://images.unsplash.com/photo-1566576912321-d58ddd7a6088?w=800",
    },
    {
        "artisan_idx": 2, "cat_slug": "woodcraft", "price": 890.0, "stock": 10,
        "title_en": "Channapatna Hand-Turned Balancing Acrobat Doll",
        "desc_en": "Classic motion wooden toy painted with turmeric yellow and vermilion lacquer.",
        "title_hi": "चन्नपटना संतुलित कलाबाजी नट खिलौना",
        "desc_hi": "प्राकृतिक रंगों से चमकता पारंपरिक काष्ठ खिलौना जो बच्चों के समन्वय को बढ़ाता है।",
        "material": "Wrightia Tinctoria Wood, Pure Shellac Lacquer",
        "technique": "Hand Lathe Woodcraft",
        "care": "Keep away from high heat.",
        "image": "https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=800",
    },
    {
        "artisan_idx": 2, "cat_slug": "woodcraft", "price": 1200.0, "stock": 7,
        "title_en": "Artisanal Channapatna Wooden Spice Box (Masala Dabba)",
        "desc_en": "Seven-compartment circular spice container lathe-finished with natural food-grade lacquer polish.",
        "title_hi": "चन्नपटना हस्तनिर्मित लकड़ी का मसाला डिब्बा",
        "desc_hi": "प्राकृतिक लाख की पॉलिश से सुरक्षित सात खानों वाला सुंदर मसाला बॉक्स।",
        "material": "Sustainable Rosewood & Ivory Wood, Food-safe Lacquer",
        "technique": "Precision Lathe Turning & Joinery",
        "care": "Wipe with dry cloth. Do not put in dishwasher.",
        "image": "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800",
    },
    {
        "artisan_idx": 2, "cat_slug": "jewelry", "price": 450.0, "stock": 25,
        "title_en": "Channapatna Wooden Beaded Statement Necklace",
        "desc_en": "Vibrant multicolor glossy wooden beads lacquered with natural vegetable extracts.",
        "title_hi": "चन्नपटना रंग-बिरंगी लकड़ी के मोतियों की माला",
        "desc_hi": "प्राकृतिक वनस्पति लाख से चमकाए गए लकड़ी के मोतियों की हस्तनिर्मित माला।",
        "material": "Ivory Wood, Natural Resin Lacquer, Cotton Thread",
        "technique": "Friction Lacquer Lathe Turning",
        "care": "Store in cotton pouch.",
        "image": "https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=800",
    },
    {
        "artisan_idx": 2, "cat_slug": "woodcraft", "price": 750.0, "stock": 8,
        "title_en": "Channapatna Traditional Pull-Along Wooden Engine",
        "desc_en": "Smooth wheel pull-along toy engine made without nails or toxic adhesives.",
        "title_hi": "चन्नपटना पारंपरिक लकड़ी की खींचने वाली रेलगाड़ी",
        "desc_hi": "छोटे बच्चों के लिए बिना किसी कील या हानिकारक गोंद के बनी सुरक्षित रेलगाड़ी।",
        "material": "Ivory Wood, Vegetable Dyes, Cotton Pull Cord",
        "technique": "Artisan Lathe Turning & Hand Assembly",
        "care": "Wipe with soft cloth.",
        "image": "https://images.unsplash.com/photo-1566576912321-d58ddd7a6088?w=800",
    },
    {
        "artisan_idx": 2, "cat_slug": "pottery", "price": 550.0, "stock": 16,
        "title_en": "Terracotta Handcrafted Long-Neck Water Pitcher",
        "desc_en": "Hand-thrown porous terracotta pitcher naturally keeping water cool through evaporative micro-cooling.",
        "title_hi": "हस्तनिर्मित पारंपरिक मिट्टी की सुराही",
        "desc_hi": "प्राकृतिक नदी की मिट्टी से चाक पर गढ़ी गई सुराही जो पानी को प्राकृतिक रूप से ठंडा रखती है।",
        "material": "Riverbed Terracotta Clay",
        "technique": "Potter's Wheel Shaping",
        "care": "Rinse with plain water before first use.",
        "image": "https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800",
    },
]

# 12-language translation templates for products
LANGUAGES = ["en", "hi", "mr", "bn", "ta", "te", "kn", "ml", "gu", "pa", "or", "as"]

LANG_TITLE_PREFIX = {
    "en": "",
    "hi": "",
    "mr": "अस्सल ",
    "bn": "ঐতিহ্যবাহী ",
    "ta": "பாரம்பரிய ",
    "te": "సాంప్రదాయ ",
    "kn": "ಪಾರಂಪರಿಕ ",
    "ml": "പരമ്പരാഗത ",
    "gu": "પરંપરાગત ",
    "pa": "ਰਵਾਇਤੀ ",
    "or": "ପାରମ୍ପରିକ ",
    "as": "পৰম্পৰাগত ",
}


async def seed():
    """Main seeding function."""
    logger.info("Initializing database tables...")
    await init_db()

    import app.database as db_mod
    async with db_mod.AsyncSessionLocal() as session:
        # Idempotency guard — if admin already exists, skip entirely.
        # Products are NEVER seeded; they must come from real artisans via the mobile app.
        res = await session.execute(select(User).where(User.phone == "+919999999999"))
        if res.scalar_one_or_none():
            logger.info("Database already seeded (admin user found). Skipping to preserve real data.")
            logger.info("NOTE: Products are never seeded. Add them via the KalaSathi artisan mobile app.")
            return

        # 1. Create Admin User
        admin_user = User(
            phone="+919999999999",
            email="admin@kalasathi.org",
            name="KalaSathi Guild Admin",
            role=UserRole.admin,
            language=Language.en,
            is_verified=True,
            is_active=True,
        )
        session.add(admin_user)

        # 2. Create Categories
        category_map = {}
        for c in CATEGORIES_DATA:
            cat = Category(
                name=c["name"],
                name_hi=c["name_hi"],
                slug=c["slug"],
                icon_url=c["icon_url"],
            )
            session.add(cat)
            await session.flush()
            category_map[c["slug"]] = cat.id

        # 3. Create Artisans
        created_artisans = []
        for a_data in ARTISANS_DATA:
            user = User(
                phone=a_data["phone"],
                email=a_data["email"],
                name=a_data["name"],
                role=UserRole.artisan,
                language=a_data["language"],
                is_verified=True,
                is_active=True,
            )
            session.add(user)
            await session.flush()

            profile = ArtisanProfile(
                user_id=user.id,
                craft_type=a_data["craft_type"],
                village=a_data["village"],
                district=a_data["district"],
                state=a_data["state"],
                bio=a_data["bio"],
                bio_hi=a_data["bio_hi"],
                bio_mr=a_data["bio_mr"],
                years_experience=a_data["years_experience"],
                profile_photo_url=a_data["profile_photo_url"],
                upi_id=a_data["upi_id"],
                bank_details={"bank": "State Bank of India", "account": "XXXXXX9012", "ifsc": "SBIN0001234"},
                is_approved=True,
                approved_at=datetime.now(timezone.utc),
            )
            session.add(profile)
            await session.flush()
            created_artisans.append(profile)

        # 4. Create 5 Buyers
        created_buyers = []
        for b_data in BUYERS_DATA:
            buyer = User(
                phone=b_data["phone"],
                email=b_data["email"],
                name=b_data["name"],
                role=UserRole.buyer,
                language=b_data["language"],
                is_verified=True,
                is_active=True,
            )
            session.add(buyer)
            await session.flush()
            created_buyers.append(buyer)

        # Steps 5-8 (Products, Orders, Reviews, Inquiries) are intentionally skipped.
        # Products must be created by artisans via the KalaSathi mobile app.
        # This ensures the website only shows real artisan-published products.

        await session.commit()
        logger.info("Successfully seeded KalaSathi database (infrastructure only):")
        logger.info("- 1 Admin (+919999999999)")
        logger.info(f"- {len(created_artisans)} Demo Artisans (can log in via mobile app)")
        logger.info(f"- {len(created_buyers)} Demo Buyers")
        logger.info(f"- {len(category_map)} Categories")
        logger.info("- 0 Products (add real products via the artisan mobile app)")


if __name__ == "__main__":
    asyncio.run(seed())

