"""Export all models so Alembic and the app can import them easily."""
from app.models.user import User, OTPCode  # noqa: F401
from app.models.artisan import ArtisanProfile  # noqa: F401
from app.models.product import Category, Product, ProductImage, ProductTranslation  # noqa: F401
from app.models.order import Order, OrderItem  # noqa: F401
from app.models.review import Review  # noqa: F401
from app.models.inquiry import Inquiry  # noqa: F401
from app.models.notification import Notification  # noqa: F401
from app.models.earning import Earning  # noqa: F401
