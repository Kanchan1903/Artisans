"""Initial schema for KalaSathi database

Revision ID: 001_initial_schema
Revises: 
Create Date: 2026-10-17 14:15:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '001_initial_schema'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. users
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('phone', sa.String(20), nullable=False, unique=True, index=True),
        sa.Column('email', sa.String(255), nullable=True, unique=True, index=True),
        sa.Column('name', sa.String(255), nullable=True),
        sa.Column('role', sa.String(50), nullable=False, server_default='buyer'),
        sa.Column('language', sa.String(10), nullable=False, server_default='en'),
        sa.Column('is_verified', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('fcm_token', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 2. otp_codes
    op.create_table(
        'otp_codes',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('phone', sa.String(20), nullable=False, index=True),
        sa.Column('code', sa.String(10), nullable=False),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('is_used', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 3. artisan_profiles
    op.create_table(
        'artisan_profiles',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), unique=True, nullable=False),
        sa.Column('craft_type', sa.String(100), nullable=True),
        sa.Column('village', sa.String(255), nullable=True),
        sa.Column('district', sa.String(255), nullable=True),
        sa.Column('state', sa.String(100), nullable=True),
        sa.Column('bio', sa.Text(), nullable=True),
        sa.Column('bio_hi', sa.Text(), nullable=True),
        sa.Column('bio_mr', sa.Text(), nullable=True),
        sa.Column('years_experience', sa.Integer(), nullable=True),
        sa.Column('profile_photo_url', sa.Text(), nullable=True),
        sa.Column('upi_id', sa.String(100), nullable=True),
        sa.Column('bank_details', sa.JSON(), nullable=True),
        sa.Column('is_approved', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('approved_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('rejection_reason', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 4. categories
    op.create_table(
        'categories',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('name', sa.String(100), unique=True, nullable=False),
        sa.Column('name_hi', sa.String(100), nullable=True),
        sa.Column('slug', sa.String(100), unique=True, index=True, nullable=False),
        sa.Column('icon_url', sa.Text(), nullable=True),
    )

    # 5. products
    op.create_table(
        'products',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('artisan_id', sa.Integer(), sa.ForeignKey('artisan_profiles.id'), nullable=False),
        sa.Column('category_id', sa.Integer(), sa.ForeignKey('categories.id'), nullable=True),
        sa.Column('title_en', sa.String(255), nullable=False),
        sa.Column('description_en', sa.Text(), nullable=True),
        sa.Column('title_hi', sa.String(255), nullable=True),
        sa.Column('description_hi', sa.Text(), nullable=True),
        sa.Column('material', sa.String(255), nullable=True),
        sa.Column('technique', sa.String(255), nullable=True),
        sa.Column('care_instructions', sa.Text(), nullable=True),
        sa.Column('seo_keywords', sa.JSON(), nullable=True),
        sa.Column('price', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('stock', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('status', sa.String(50), nullable=False, server_default='draft'),
        sa.Column('voice_transcript', sa.Text(), nullable=True),
        sa.Column('ai_generated', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('published_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 6. product_images
    op.create_table(
        'product_images',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=False),
        sa.Column('url', sa.Text(), nullable=False),
        sa.Column('is_primary', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('order_index', sa.Integer(), nullable=False, server_default='0'),
    )

    # 7. product_translations
    op.create_table(
        'product_translations',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=False),
        sa.Column('language', sa.String(10), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
    )

    # 8. orders
    op.create_table(
        'orders',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('buyer_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('status', sa.String(50), nullable=False, server_default='pending'),
        sa.Column('total', sa.Float(), nullable=False),
        sa.Column('shipping_address', sa.JSON(), nullable=False),
        sa.Column('payment_method', sa.String(50), nullable=False, server_default='cod'),
        sa.Column('payment_id', sa.String(100), nullable=True),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 9. order_items
    op.create_table(
        'order_items',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('order_id', sa.Integer(), sa.ForeignKey('orders.id'), nullable=False),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=False),
        sa.Column('artisan_id', sa.Integer(), sa.ForeignKey('artisan_profiles.id'), nullable=False),
        sa.Column('quantity', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('unit_price', sa.Float(), nullable=False),
    )

    # 10. earnings
    op.create_table(
        'earnings',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('artisan_id', sa.Integer(), sa.ForeignKey('artisan_profiles.id'), nullable=False),
        sa.Column('order_item_id', sa.Integer(), sa.ForeignKey('order_items.id'), nullable=True),
        sa.Column('amount', sa.Float(), nullable=False),
        sa.Column('status', sa.String(50), nullable=False, server_default='pending'),
        sa.Column('settled_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 11. inquiries
    op.create_table(
        'inquiries',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=False),
        sa.Column('artisan_id', sa.Integer(), sa.ForeignKey('artisan_profiles.id'), nullable=False),
        sa.Column('buyer_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=True),
        sa.Column('buyer_name', sa.Text(), nullable=True),
        sa.Column('buyer_email', sa.Text(), nullable=True),
        sa.Column('message_en', sa.Text(), nullable=False),
        sa.Column('message_translated', sa.Text(), nullable=True),
        sa.Column('is_b2b', sa.Boolean(), nullable=False, server_default=sa.text('true')),
        sa.Column('quantity_needed', sa.Integer(), nullable=True),
        sa.Column('is_read', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 12. notifications
    op.create_table(
        'notifications',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('type', sa.String(50), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('body', sa.Text(), nullable=True),
        sa.Column('data', sa.JSON(), nullable=True),
        sa.Column('is_read', sa.Boolean(), nullable=False, server_default=sa.text('false')),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    # 13. reviews
    op.create_table(
        'reviews',
        sa.Column('id', sa.Integer(), nullable=False, primary_key=True),
        sa.Column('product_id', sa.Integer(), sa.ForeignKey('products.id'), nullable=False),
        sa.Column('buyer_id', sa.Integer(), sa.ForeignKey('users.id'), nullable=False),
        sa.Column('rating', sa.Float(), nullable=False),
        sa.Column('comment', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    op.drop_table('reviews')
    op.drop_table('notifications')
    op.drop_table('inquiries')
    op.drop_table('earnings')
    op.drop_table('order_items')
    op.drop_table('orders')
    op.drop_table('product_translations')
    op.drop_table('product_images')
    op.drop_table('products')
    op.drop_table('categories')
    op.drop_table('artisan_profiles')
    op.drop_table('otp_codes')
    op.drop_table('users')
