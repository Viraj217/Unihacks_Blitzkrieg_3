
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
