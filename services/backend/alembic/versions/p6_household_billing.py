"""P6: household billing schema changes

Revision ID: p6_household_billing
Revises: d73dcc3968c9
Create Date: 2026-03-01 10:00:00.000000

Adds:
- last_event_at to subscriptions
- subscription_id + outcome to billing_webhook_events
- households table
- household_members table
- admin_audit_events table
- role to users (HIGH-4 RBAC)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = 'p6_household_billing'
down_revision: Union[str, Sequence[str]] = 'd73dcc3968c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema for P6 household billing."""
    bind = op.get_bind()

    def _has_table(table_name: str) -> bool:
        return inspect(bind).has_table(table_name)

    def _has_column(table_name: str, column_name: str) -> bool:
        return any(
            c.get("name") == column_name for c in inspect(bind).get_columns(table_name)
        )

    def _has_index(table_name: str, index_name: str) -> bool:
        return any(
            idx.get("name") == index_name for idx in inspect(bind).get_indexes(table_name)
        )

    def _has_fk(table_name: str, fk_name: str) -> bool:
        return any(
            fk.get("name") == fk_name for fk in inspect(bind).get_foreign_keys(table_name)
        )

    # 1. Add last_event_at to subscriptions
    if _has_table('subscriptions') and not _has_column('subscriptions', 'last_event_at'):
        with op.batch_alter_table('subscriptions', schema=None) as batch_op:
            batch_op.add_column(sa.Column('last_event_at', sa.DateTime(), nullable=True))

    # 2. Add subscription_id + outcome to billing_webhook_events
    if _has_table('billing_webhook_events'):
        if not _has_column('billing_webhook_events', 'subscription_id'):
            with op.batch_alter_table('billing_webhook_events', schema=None) as batch_op:
                batch_op.add_column(sa.Column('subscription_id', sa.String(), nullable=True))
        if not _has_column('billing_webhook_events', 'outcome'):
            with op.batch_alter_table('billing_webhook_events', schema=None) as batch_op:
                batch_op.add_column(
                    sa.Column('outcome', sa.String(), nullable=False, server_default='applied')
                )
        if not _has_fk('billing_webhook_events', 'fk_billing_webhook_events_subscription_id'):
            with op.batch_alter_table('billing_webhook_events', schema=None) as batch_op:
                batch_op.create_foreign_key(
                    'fk_billing_webhook_events_subscription_id',
                    'subscriptions',
                    ['subscription_id'],
                    ['id'],
                )
        if not _has_index('billing_webhook_events', 'ix_billing_webhook_events_subscription_id'):
            op.create_index(
                'ix_billing_webhook_events_subscription_id',
                'billing_webhook_events',
                ['subscription_id'],
                unique=False,
            )

    # 3. Create households table
    if not _has_table('households'):
        op.create_table(
            'households',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('household_owner_user_id', sa.String(), nullable=False),
            sa.Column('billing_owner_user_id', sa.String(), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.Column('updated_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['household_owner_user_id'], ['users.id']),
            sa.ForeignKeyConstraint(['billing_owner_user_id'], ['users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
    if not _has_index('households', 'ix_households_household_owner_user_id'):
        op.create_index(
            'ix_households_household_owner_user_id',
            'households',
            ['household_owner_user_id'],
            unique=False,
        )
    if not _has_index('households', 'ix_households_billing_owner_user_id'):
        op.create_index(
            'ix_households_billing_owner_user_id',
            'households',
            ['billing_owner_user_id'],
            unique=False,
        )

    # 4. Create household_members table
    if not _has_table('household_members'):
        op.create_table(
            'household_members',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('household_id', sa.String(), nullable=False),
            sa.Column('user_id', sa.String(), nullable=False),
            sa.Column('role', sa.String(), nullable=False),
            sa.Column('status', sa.String(), nullable=False),
            sa.Column('invitation_code', sa.String(), nullable=True),
            sa.Column('invited_at', sa.DateTime(), nullable=False),
            sa.Column('accepted_at', sa.DateTime(), nullable=True),
            sa.Column('cooldown_override', sa.Boolean(), nullable=False, server_default='0'),
            sa.ForeignKeyConstraint(['household_id'], ['households.id']),
            sa.ForeignKeyConstraint(['user_id'], ['users.id']),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('user_id', name='uq_household_member_user'),
            sa.CheckConstraint("role IN ('owner', 'partner')", name='ck_household_member_role'),
            sa.CheckConstraint(
                "status IN ('pending', 'active', 'revoked')",
                name='ck_household_member_status',
            ),
        )
    if not _has_index('household_members', 'ix_household_members_household_id'):
        op.create_index(
            'ix_household_members_household_id',
            'household_members',
            ['household_id'],
            unique=False,
        )
    if not _has_index('household_members', 'ix_household_members_user_id'):
        op.create_index(
            'ix_household_members_user_id',
            'household_members',
            ['user_id'],
            unique=False,
        )
    if not _has_index('household_members', 'ix_household_members_invitation_code'):
        op.create_index(
            'ix_household_members_invitation_code',
            'household_members',
            ['invitation_code'],
            unique=True,
        )

    # 5. Create admin_audit_events table
    if not _has_table('admin_audit_events'):
        op.create_table(
            'admin_audit_events',
            sa.Column('id', sa.String(), nullable=False),
            sa.Column('admin_user_id', sa.String(), nullable=False),
            sa.Column('action', sa.String(), nullable=False),
            sa.Column('target_user_id', sa.String(), nullable=False),
            sa.Column('reason', sa.Text(), nullable=False),
            sa.Column('ip_address', sa.String(), nullable=True),
            sa.Column('user_agent', sa.String(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['admin_user_id'], ['users.id']),
            sa.PrimaryKeyConstraint('id'),
        )
    if not _has_index('admin_audit_events', 'ix_admin_audit_events_admin_user_id'):
        op.create_index(
            'ix_admin_audit_events_admin_user_id',
            'admin_audit_events',
            ['admin_user_id'],
            unique=False,
        )
    if not _has_index('admin_audit_events', 'ix_admin_audit_events_action'):
        op.create_index(
            'ix_admin_audit_events_action',
            'admin_audit_events',
            ['action'],
            unique=False,
        )
    if not _has_index('admin_audit_events', 'ix_admin_audit_events_target_user_id'):
        op.create_index(
            'ix_admin_audit_events_target_user_id',
            'admin_audit_events',
            ['target_user_id'],
            unique=False,
        )

    # 6. Add role to users (HIGH-4 RBAC)
    if _has_table('users') and not _has_column('users', 'role'):
        with op.batch_alter_table('users', schema=None) as batch_op:
            batch_op.add_column(
                sa.Column('role', sa.String(), nullable=True, server_default=None)
            )


def downgrade() -> None:
    """Downgrade: remove P6 schema changes."""

    # Remove role from users
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('role')

    # Drop admin_audit_events
    with op.batch_alter_table('admin_audit_events', schema=None) as batch_op:
        batch_op.drop_index('ix_admin_audit_events_target_user_id')
        batch_op.drop_index('ix_admin_audit_events_action')
        batch_op.drop_index('ix_admin_audit_events_admin_user_id')
    op.drop_table('admin_audit_events')

    # Drop household_members
    with op.batch_alter_table('household_members', schema=None) as batch_op:
        batch_op.drop_index('ix_household_members_invitation_code')
        batch_op.drop_index('ix_household_members_user_id')
        batch_op.drop_index('ix_household_members_household_id')
    op.drop_table('household_members')

    # Drop households
    with op.batch_alter_table('households', schema=None) as batch_op:
        batch_op.drop_index('ix_households_billing_owner_user_id')
        batch_op.drop_index('ix_households_household_owner_user_id')
    op.drop_table('households')

    # Remove subscription_id + outcome from billing_webhook_events
    with op.batch_alter_table('billing_webhook_events', schema=None) as batch_op:
        batch_op.drop_index('ix_billing_webhook_events_subscription_id')
        batch_op.drop_constraint(
            'fk_billing_webhook_events_subscription_id', type_='foreignkey'
        )
        batch_op.drop_column('outcome')
        batch_op.drop_column('subscription_id')

    # Remove last_event_at from subscriptions
    with op.batch_alter_table('subscriptions', schema=None) as batch_op:
        batch_op.drop_column('last_event_at')
