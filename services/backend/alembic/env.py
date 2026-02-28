"""
Alembic environment configuration.

Supports both SQLite (dev/test) and PostgreSQL (production).
Database URL is read from app.core.config.settings.DATABASE_URL,
which itself reads from the DATABASE_URL environment variable
(default: sqlite:///./mint.db).
"""

from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context

# -- Alembic Config object (provides access to alembic.ini values) -----------
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# -- Import application settings & models ------------------------------------
from app.core.config import settings  # noqa: E402

# Import Base so target_metadata is available
from app.core.database import Base  # noqa: E402

# Import all models so their tables are registered on Base.metadata.
# The app.models package re-exports every model via __init__.py.
import app.models  # noqa: E402, F401

target_metadata = Base.metadata

# -- Override sqlalchemy.url from application settings -----------------------
# This ensures env.py always uses the same DATABASE_URL as the application,
# regardless of what is written in alembic.ini (which keeps a placeholder).
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL)


# ---------------------------------------------------------------------------
# Offline mode (generates SQL scripts without a live database connection)
# ---------------------------------------------------------------------------
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    Configures the context with just a URL (no Engine needed).
    Calls to context.execute() emit SQL to the script output.
    """
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=url.startswith("sqlite"),  # SQLite needs batch mode for ALTER
    )

    with context.begin_transaction():
        context.run_migrations()


# ---------------------------------------------------------------------------
# Online mode (connects to the database and runs migrations directly)
# ---------------------------------------------------------------------------
def run_migrations_online() -> None:
    """Run migrations in 'online' mode.

    Creates an Engine and associates a connection with the context.
    """
    # Build engine config from alembic.ini [alembic] section
    engine_config = config.get_section(config.config_ini_section, {})

    # Add SQLite-specific connect_args if needed
    url = engine_config.get("sqlalchemy.url", "")
    connect_args = {}
    if url.startswith("sqlite"):
        connect_args["check_same_thread"] = False

    connectable = engine_from_config(
        engine_config,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=url.startswith("sqlite"),  # SQLite batch mode
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
