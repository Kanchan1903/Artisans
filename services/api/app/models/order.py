"""Order and OrderItem models."""
import enum
from datetime import datetime
from sqlalchemy import String, Integer, Float, DateTime, Enum as SAEnum, ForeignKey, JSON, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base


class OrderStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    packed = "packed"
    shipped = "shipped"
    delivered = "delivered"
    cancelled = "cancelled"


class PaymentMethod(str, enum.Enum):
    razorpay = "razorpay"
    cod = "cod"  # cash on delivery


class Order(Base):
    """Buyer order."""
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    buyer_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)

    status: Mapped[OrderStatus] = mapped_column(SAEnum(OrderStatus, native_enum=False), default=OrderStatus.pending)
    total: Mapped[float] = mapped_column(Float, nullable=False)
    shipping_address: Mapped[dict] = mapped_column(JSON, nullable=False)  # {name, phone, line1, city, state, pincode}
    payment_method: Mapped[PaymentMethod] = mapped_column(SAEnum(PaymentMethod, native_enum=False), default=PaymentMethod.cod)
    payment_id: Mapped[str | None] = mapped_column(String(100), nullable=True)  # Razorpay payment id
    payment_status: Mapped[str] = mapped_column(String(50), default="unpaid")  # "paid", "unpaid", "refunded", "cod_pending"
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # Relationships
    buyer: Mapped["User"] = relationship(back_populates="orders", foreign_keys=[buyer_id])  # type: ignore # noqa: F821
    items: Mapped[list["OrderItem"]] = relationship(back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    """Line item within an order."""
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    order_id: Mapped[int] = mapped_column(Integer, ForeignKey("orders.id"), nullable=False)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id"), nullable=False)
    artisan_id: Mapped[int] = mapped_column(Integer, ForeignKey("artisan_profiles.id"), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[float] = mapped_column(Float, nullable=False)

    order: Mapped["Order"] = relationship(back_populates="items")
    product: Mapped["Product"] = relationship(back_populates="order_items")  # type: ignore # noqa: F821
    artisan: Mapped["ArtisanProfile"] = relationship(back_populates="order_items")  # type: ignore # noqa: F821
    earning: Mapped["Earning | None"] = relationship(back_populates="order_item")  # type: ignore # noqa: F821
