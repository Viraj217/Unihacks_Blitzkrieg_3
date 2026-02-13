# Unihacks_Blitzkrieg_3

CREATE TABLE profiles (
id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
username VARCHAR(50) UNIQUE NOT NULL,
display_name VARCHAR(100),
avatar_url TEXT,
bio TEXT,
phone_number VARCHAR(20),
is_ghost BOOLEAN DEFAULT false, -- for ghost feature ghost_until TIMESTAMP WITH TIME ZONE,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
last_seen TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE groups (
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
name VARCHAR(100) NOT NULL,
description TEXT,
avatar_url TEXT,
invite_code VARCHAR(10) UNIQUE NOT NULL, -- 6-8 char code
created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
is_active BOOLEAN DEFAULT true,
settings JSONB DEFAULT '{}', -- group preferences
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE group_join_requests (
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
requester_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
message TEXT,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
responded_at TIMESTAMP WITH TIME ZONE,
responded_by UUID REFERENCES profiles(id),
UNIQUE(group_id, requester_id, status)
);

CREATE TABLE time_capsules (
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
created_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
title VARCHAR(200) NOT NULL,
description TEXT,
unlock_date TIMESTAMP WITH TIME ZONE NOT NULL,
is_locked BOOLEAN DEFAULT true,
is_collaborative BOOLEAN DEFAULT false, -- can others contribute?
contribution_deadline TIMESTAMP WITH TIME ZONE, -- when to seal it
thumbnail_url TEXT,
created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
unlocked_at TIMESTAMP WITH TIME ZONE,
views_count INTEGER DEFAULT 0
);
