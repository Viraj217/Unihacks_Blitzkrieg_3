
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_id UUID UNIQUE NOT NULL,
    username VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100),
    email VARCHAR(255) UNIQUE NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    phone_number VARCHAR(20),
    is_ghost BOOLEAN DEFAULT false,
    ghost_until TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    last_seen TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    avatar_url TEXT,
    invite_code VARCHAR(10) UNIQUE NOT NULL,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'member',
    joined_at TIMESTAMP DEFAULT NOW(),
    last_activity TIMESTAMP DEFAULT NOW(),
    UNIQUE(group_id, user_id)
);

CREATE TABLE IF NOT EXISTS group_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'pending',
    message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP,
    responded_by UUID REFERENCES profiles(id),
    UNIQUE(group_id, requester_id, status)
);

CREATE OR REPLACE FUNCTION generate_invite_code()
RETURNS TEXT AS $$
DECLARE
    new_code TEXT;
BEGIN
    LOOP
        new_code := substr(md5(random()::text), 1, 6);

        EXIT WHEN NOT EXISTS (
            SELECT 1 FROM groups WHERE invite_code = new_code
        );
    END LOOP;

    RETURN upper(new_code);
END;
$$ LANGUAGE plpgsql;


CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    message_type VARCHAR(20) DEFAULT 'text', -- text, image, voice, video, file
    content TEXT,
    media_url TEXT,
    reply_to_id UUID REFERENCES chat_messages(id),
    is_edited BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Message read receipts
CREATE TABLE IF NOT EXISTS message_read_receipts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES chat_messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    read_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(message_id, user_id)
);

-- Typing indicators (optional, can be in-memory only)
CREATE TABLE IF NOT EXISTS typing_indicators (
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    started_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY(group_id, user_id)
);

-- Indexes
CREATE INDEX idx_chat_messages_group_id ON chat_messages(group_id);
CREATE INDEX idx_chat_messages_sender_id ON chat_messages(sender_id);
CREATE INDEX idx_chat_messages_created_at ON chat_messages(created_at DESC);
CREATE INDEX idx_message_read_receipts_message_id ON message_read_receipts(message_id);
CREATE INDEX idx_message_read_receipts_user_id ON message_read_receipts(user_id);

-- Trigger for updated_at
CREATE TRIGGER update_chat_messages_updated_at 
    BEFORE UPDATE ON chat_messages
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();


-- Time capsules table
CREATE TABLE IF NOT EXISTS time_capsules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id UUID REFERENCES groups(id) ON DELETE CASCADE NOT NULL,
    created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    unlock_date TIMESTAMP NOT NULL,
    is_locked BOOLEAN DEFAULT true,
    is_collaborative BOOLEAN DEFAULT false,
    contribution_deadline TIMESTAMP,
    thumbnail_url TEXT,
    theme VARCHAR(50) DEFAULT 'default',
    created_at TIMESTAMP DEFAULT NOW(),
    unlocked_at TIMESTAMP,
    views_count INTEGER DEFAULT 0,
    is_read_only BOOLEAN DEFAULT false
);

-- Capsule contributors
CREATE TABLE IF NOT EXISTS capsule_contributors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capsule_id UUID REFERENCES time_capsules(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    has_contributed BOOLEAN DEFAULT false,
    contributed_at TIMESTAMP,
    UNIQUE(capsule_id, user_id)
);

-- Capsule contents
CREATE TABLE IF NOT EXISTS capsule_contents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capsule_id UUID REFERENCES time_capsules(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    content_type VARCHAR(20) NOT NULL CHECK (content_type IN ('photo', 'note', 'voice', 'video')),
    content_text TEXT,
    media_url TEXT,
    media_thumbnail_url TEXT,
    duration_seconds INTEGER,
    file_size_bytes BIGINT,
    metadata JSONB DEFAULT '{}',
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT content_check CHECK (
        (content_type = 'note' AND content_text IS NOT NULL) OR
        (content_type IN ('photo', 'voice', 'video') AND media_url IS NOT NULL)
    )
);

-- Capsule views
CREATE TABLE IF NOT EXISTS capsule_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capsule_id UUID REFERENCES time_capsules(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    viewed_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(capsule_id, user_id)
);

-- Capsule reactions
CREATE TABLE IF NOT EXISTS capsule_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capsule_id UUID REFERENCES time_capsules(id) ON DELETE CASCADE NOT NULL,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    emoji VARCHAR(10) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(capsule_id, user_id)
);

-- Indexes
CREATE INDEX idx_time_capsules_group_id ON time_capsules(group_id);
CREATE INDEX idx_time_capsules_unlock_date ON time_capsules(unlock_date) WHERE is_locked = true;
CREATE INDEX idx_capsule_contents_capsule_id ON capsule_contents(capsule_id);
CREATE INDEX idx_capsule_views_capsule_id ON capsule_views(capsule_id);

-- Triggers
CREATE OR REPLACE FUNCTION unlock_capsule()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.is_locked = true AND NEW.is_locked = false THEN
        NEW.unlocked_at = NOW();
        NEW.is_read_only = true;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_unlock_capsule
    BEFORE UPDATE ON time_capsules
    FOR EACH ROW
    EXECUTE FUNCTION unlock_capsule();

CREATE OR REPLACE FUNCTION increment_capsule_views()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE time_capsules
    SET views_count = views_count + 1
    WHERE id = NEW.capsule_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_increment_views
    AFTER INSERT ON capsule_views
    FOR EACH ROW
    EXECUTE FUNCTION increment_capsule_views();

CREATE OR REPLACE FUNCTION mark_contributor_contributed()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE capsule_contributors
    SET has_contributed = true, contributed_at = NOW()
    WHERE capsule_id = NEW.capsule_id AND user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_mark_contributed
    AFTER INSERT ON capsule_contents
    FOR EACH ROW
    EXECUTE FUNCTION mark_contributor_contributed();
