# ATTRIBUTION — Third-Party Dependencies

> MINT uses the following open-source libraries. We are grateful to their authors.

---

## Flutter (Dart)

### Runtime Dependencies

| Package | License | Usage |
|---------|---------|-------|
| flutter | BSD-3-Clause | UI framework (Google) |
| flutter_localizations | BSD-3-Clause | Internationalization support (fr, de, en, es, it, pt) |
| cupertino_icons | MIT | iOS-style icon set |
| http | BSD-3-Clause | HTTP client for API communication |
| provider | MIT | State management (ChangeNotifier-based) |
| go_router | BSD-3-Clause | Declarative routing and navigation |
| intl | BSD-3-Clause | Date/number formatting and localization |
| url_launcher | BSD-3-Clause | Opening external URLs (browser, phone, email) |
| google_fonts | Apache-2.0 | Montserrat and Inter font loading |
| uuid | MIT | Unique identifier generation for sessions |
| pdf | Apache-2.0 | PDF document generation (financial reports) |
| printing | Apache-2.0 | PDF printing and sharing support |
| fl_chart | MIT | Interactive charts and data visualizations |
| shared_preferences | BSD-3-Clause | Local key-value storage (user preferences) |
| flutter_secure_storage | BSD-3-Clause | Encrypted storage for sensitive data |
| file_picker | MIT | File selection for document upload (Phase 2) |

### Dev Dependencies

| Package | License | Usage |
|---------|---------|-------|
| flutter_test | BSD-3-Clause | Widget and unit testing framework |
| integration_test | BSD-3-Clause | End-to-end integration testing |
| flutter_lints | BSD-3-Clause | Recommended lint rules for Flutter |

---

## Backend (Python)

### Core Dependencies

| Package | License | Usage |
|---------|---------|-------|
| fastapi | MIT | REST API framework |
| uvicorn | BSD-3-Clause | ASGI server (with standard extras) |
| pydantic | MIT | Data validation and serialization (v2) |
| pydantic-settings | MIT | Settings management with environment variables |
| python-multipart | Apache-2.0 | Form data and file upload parsing |
| sqlalchemy | MIT | Database ORM and query builder |
| pyjwt | MIT | JSON Web Token encoding/decoding |
| passlib | BSD-3-Clause | Password hashing utilities |
| bcrypt | Apache-2.0 | Bcrypt password hashing algorithm |
| email-validator | CC0-1.0 | Email address validation |

### Dev Dependencies

| Package | License | Usage |
|---------|---------|-------|
| pytest | MIT | Test framework |
| pytest-asyncio | Apache-2.0 | Async test support for FastAPI |
| ruff | MIT | Fast Python linter and formatter |
| httpx | BSD-3-Clause | Async HTTP client for API testing |

### Optional: RAG Dependencies

| Package | License | Usage |
|---------|---------|-------|
| chromadb | Apache-2.0 | Vector database for document embeddings |
| anthropic | MIT | Claude API client for AI-assisted features |
| openai | MIT | OpenAI API client (embeddings) |
| tiktoken | MIT | Token counting for LLM context management |

### Optional: Document Processing Dependencies

| Package | License | Usage |
|---------|---------|-------|
| pdfplumber | MIT | PDF text extraction (LPP certificates, bank statements) |

---

## License Compliance Notes

- All dependencies use permissive open-source licenses (MIT, BSD, Apache-2.0).
- No copyleft (GPL/LGPL) dependencies are included.
- MINT itself is released under the MIT License (see `LICENSE`).
- License information was verified at the time of inclusion. For current license terms, refer to each package's official repository.

---

*Last updated: February 2026*
