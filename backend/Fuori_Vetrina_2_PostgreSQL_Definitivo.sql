-- FUORI VETRINA 2.0
-- DATABASE DEFINITIVO - PostgreSQL 18
-- Costruzione basata sulla Lavagna Definitiva A-Z.
-- NOTA: questo script è PostgreSQL, non MySQL.

BEGIN;

-- =========================================================
-- 1. UTENTI
-- =========================================================
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    display_name VARCHAR(80),
    email VARCHAR(255) UNIQUE,
    password_hash VARCHAR(255),
    role VARCHAR(20) NOT NULL DEFAULT 'utente'
        CHECK (role IN ('utente','moderatore','amministratore')),
    status VARCHAR(20) NOT NULL DEFAULT 'attivo'
        CHECK (status IN ('attivo','bloccato','sospeso')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- 2. CATEGORIE
-- =========================================================
CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    slug VARCHAR(100) NOT NULL UNIQUE,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order INTEGER NOT NULL DEFAULT 0
);

INSERT INTO categories (name, slug, sort_order)
VALUES
    ('Vita','vita',1),
    ('Esperienze','esperienze',2),
    ('Persone','persone',3),
    ('Pensieri','pensieri',4),
    ('Incontri','incontri',5),
    ('Curiosità','curiosita',6)
ON CONFLICT (slug) DO NOTHING;

-- =========================================================
-- 3. STORIE / CONTRIBUTI
-- =========================================================
CREATE TABLE IF NOT EXISTS stories (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    author_name VARCHAR(80),
    title VARCHAR(120) NOT NULL,
    body TEXT NOT NULL,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    status VARCHAR(20) NOT NULL DEFAULT 'in_attesa'
        CHECK (status IN (
            'in_attesa','in_revisione','approvata',
            'pubblicata','rifiutata','archiviata','nascosta'
        )),
    consent_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    moderated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    moderated_at TIMESTAMPTZ,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_stories_status
    ON stories(status);
CREATE INDEX IF NOT EXISTS idx_stories_category
    ON stories(category_id);
CREATE INDEX IF NOT EXISTS idx_stories_published
    ON stories(published_at);

-- =========================================================
-- 4. COMMENTI
-- =========================================================
CREATE TABLE IF NOT EXISTS comments (
    id BIGSERIAL PRIMARY KEY,
    story_id BIGINT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    author_name VARCHAR(80),
    body TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'in_attesa'
        CHECK (status IN (
            'in_attesa','approvato','rifiutato','nascosto','archiviato'
        )),
    moderated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    moderated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_comments_story_status
    ON comments(story_id, status);

-- =========================================================
-- 5. SEGNALAZIONI
-- =========================================================
CREATE TABLE IF NOT EXISTS reports (
    id BIGSERIAL PRIMARY KEY,
    comment_id BIGINT REFERENCES comments(id) ON DELETE CASCADE,
    story_id BIGINT REFERENCES stories(id) ON DELETE CASCADE,
    reporter_user_id BIGINT REFERENCES users(id) ON DELETE SET NULL,
    reason VARCHAR(255) NOT NULL,
    details TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'aperta'
        CHECK (status IN ('aperta','in_esame','risolta','archiviata')),
    handled_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    handled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (comment_id IS NOT NULL OR story_id IS NOT NULL)
);

-- =========================================================
-- 6. BLOCCO / SOSPENSIONE UTENTI
-- =========================================================
CREATE TABLE IF NOT EXISTS user_blocks (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blocked_by BIGINT NOT NULL REFERENCES users(id),
    reason VARCHAR(255),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_user_blocks_active
    ON user_blocks(user_id, active);

-- =========================================================
-- 7. BUONE NOTIZIE
-- =========================================================
CREATE TABLE IF NOT EXISTS positive_news (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(180) NOT NULL,
    body TEXT NOT NULL,
    source_name VARCHAR(180) NOT NULL,
    source_url VARCHAR(1000),
    published_date DATE,
    status VARCHAR(20) NOT NULL DEFAULT 'bozza'
        CHECK (status IN ('bozza','in_verifica','approvata','pubblicata','archiviata')),
    created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- 8. FOTO DEL GIORNO
-- =========================================================
CREATE TABLE IF NOT EXISTS daily_photos (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(180),
    image_url VARCHAR(1000) NOT NULL,
    source_name VARCHAR(180),
    source_url VARCHAR(1000),
    license_text VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'bozza'
        CHECK (status IN ('bozza','in_verifica','approvata','pubblicata','archiviata')),
    published_for_date DATE,
    created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- 9. CONTENUTI BREVI DELLA HOME
-- =========================================================
CREATE TABLE IF NOT EXISTS home_content (
    id BIGSERIAL PRIMARY KEY,
    content_type VARCHAR(30) NOT NULL
        CHECK (content_type IN (
            'curiosita','domanda','buona_storia','ritorno_al_passato','una_pausa'
        )),
    title VARCHAR(180) NOT NULL,
    body TEXT NOT NULL,
    source_name VARCHAR(180),
    source_url VARCHAR(1000),
    status VARCHAR(20) NOT NULL DEFAULT 'bozza'
        CHECK (status IN ('bozza','in_verifica','approvato','pubblicato','archiviato')),
    publish_date DATE,
    created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_home_type_date
    ON home_content(content_type, publish_date);

-- =========================================================
-- 10. LETTURE EDITORIALI: RACCONTO / POESIA
-- =========================================================
CREATE TABLE IF NOT EXISTS readings (
    id BIGSERIAL PRIMARY KEY,
    kind VARCHAR(20) NOT NULL CHECK (kind IN ('racconto','poesia')),
    title VARCHAR(180) NOT NULL,
    author VARCHAR(180) NOT NULL,
    work_title VARCHAR(180),
    body TEXT NOT NULL,
    source_name VARCHAR(255),
    source_url VARCHAR(1000),
    rights_status VARCHAR(30) NOT NULL DEFAULT 'verifica_necessaria'
        CHECK (rights_status IN (
            'dominio_pubblico','licenza','permesso','verifica_necessaria'
        )),
    rights_notes TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'bozza'
        CHECK (status IN ('bozza','in_verifica','approvata','pubblicata','archiviata')),
    published_at TIMESTAMPTZ,
    created_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- 11. IMPOSTAZIONI DEL SITO
-- =========================================================
CREATE TABLE IF NOT EXISTS site_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value TEXT,
    updated_by BIGINT REFERENCES users(id) ON DELETE SET NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =========================================================
-- 12. REGISTRO MODERAZIONE / AUDIT
-- =========================================================
CREATE TABLE IF NOT EXISTS moderation_log (
    id BIGSERIAL PRIMARY KEY,
    moderator_id BIGINT NOT NULL REFERENCES users(id),
    entity_type VARCHAR(30) NOT NULL
        CHECK (entity_type IN (
            'story','comment','report','user','news',
            'photo','home_content','reading'
        )),
    entity_id BIGINT NOT NULL,
    action VARCHAR(80) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'stories';

COMMIT;
