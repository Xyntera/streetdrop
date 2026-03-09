-- Run this in Supabase SQL Editor: https://supabase.com/dashboard/project/ifwtadocbchcqcbqpqka/sql

-- DROPS TABLE
CREATE TABLE IF NOT EXISTS drops (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT NOT NULL,        -- R2 public URL
  metadata_uri TEXT,              -- Pinata IPFS URI (set after pinning)
  creator_wallet TEXT NOT NULL,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  radius_meters INTEGER NOT NULL DEFAULT 50,
  supply INTEGER NOT NULL,
  claimed_count INTEGER NOT NULL DEFAULT 0,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  tree_address TEXT,              -- Bubblegum merkle tree (set after creation)
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- CLAIMS TABLE
CREATE TABLE IF NOT EXISTS claims (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  drop_id UUID REFERENCES drops(id) ON DELETE CASCADE,
  wallet_address TEXT NOT NULL,
  tx_signature TEXT,
  asset_id TEXT,
  claimed_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(drop_id, wallet_address)   -- one claim per wallet per drop
);

-- INDEXES
CREATE INDEX IF NOT EXISTS drops_active_idx ON drops(is_active, ends_at);
CREATE INDEX IF NOT EXISTS drops_location_idx ON drops(lat, lng);
CREATE INDEX IF NOT EXISTS claims_wallet_idx ON claims(wallet_address);
CREATE INDEX IF NOT EXISTS claims_drop_idx ON claims(drop_id);

-- RATE LIMIT TABLE (verify attempt throttling)
CREATE TABLE IF NOT EXISTS verify_attempts (
  wallet_address TEXT NOT NULL,
  drop_id UUID NOT NULL,
  attempted_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (wallet_address, drop_id)
);
