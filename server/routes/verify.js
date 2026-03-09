const express = require("express");
const router = express.Router();
const supabase = require("../lib/supabase");
const { isWithinRadius } = require("../lib/gps");
const { issueClaimToken } = require("../lib/jwt");

// Max 1 verify attempt per wallet per drop per 30 seconds
const RATE_LIMIT_SECONDS = 30;
const recentAttempts = new Map(); // in-memory rate limiter (use Redis in prod)

// ─── POST /verify ────────────────────────────────────────────────────────────
// Body: { dropId, lat, lng, walletAddress, timestamp }
// Returns: { claimToken } or error
router.post("/", async (req, res) => {
  try {
    const { dropId, lat, lng, walletAddress, timestamp } = req.body;

    // ── 1. Basic validation ──────────────────────────────────────────────────
    if (!dropId || lat == null || lng == null || !walletAddress) {
      return res.status(400).json({ error: "dropId, lat, lng, walletAddress required" });
    }

    const userLat = parseFloat(lat);
    const userLng = parseFloat(lng);

    if (isNaN(userLat) || isNaN(userLng)) {
      return res.status(400).json({ error: "Invalid coordinates" });
    }

    // ── 2. Timestamp freshness (prevent replay) ───────────────────────────────
    const clientTs = parseInt(timestamp || Date.now(), 10);
    const delta = Math.abs(Date.now() - clientTs);
    if (delta > 15000) { // 15 second window
      return res.status(400).json({ error: "Request expired. Please try again." });
    }

    // ── 3. Rate limiting ─────────────────────────────────────────────────────
    const rateKey = `${walletAddress}:${dropId}`;
    const lastAttempt = recentAttempts.get(rateKey);
    if (lastAttempt && Date.now() - lastAttempt < RATE_LIMIT_SECONDS * 1000) {
      const waitSec = Math.ceil((RATE_LIMIT_SECONDS * 1000 - (Date.now() - lastAttempt)) / 1000);
      return res.status(429).json({ error: `Too many attempts. Wait ${waitSec}s.` });
    }
    recentAttempts.set(rateKey, Date.now());

    // ── 4. Load drop ─────────────────────────────────────────────────────────
    const { data: drop, error: dropErr } = await supabase
      .from("drops")
      .select("*")
      .eq("id", dropId)
      .single();

    if (dropErr || !drop) {
      return res.status(404).json({ error: "Drop not found" });
    }

    // ── 5. Drop is live? ─────────────────────────────────────────────────────
    const now = new Date();
    if (new Date(drop.starts_at) > now) {
      return res.status(400).json({ error: "Drop hasn't started yet" });
    }
    if (new Date(drop.ends_at) < now) {
      return res.status(400).json({ error: "Drop has expired" });
    }
    if (!drop.is_active) {
      return res.status(400).json({ error: "Drop is not active" });
    }

    // ── 6. Supply available? ─────────────────────────────────────────────────
    if (drop.claimed_count >= drop.supply) {
      return res.status(400).json({ error: "Drop is sold out" });
    }

    // ── 7. Wallet already claimed? ───────────────────────────────────────────
    const { data: existingClaim } = await supabase
      .from("claims")
      .select("id")
      .eq("drop_id", dropId)
      .eq("wallet_address", walletAddress)
      .maybeSingle();

    if (existingClaim) {
      return res.status(400).json({ error: "You already claimed this drop" });
    }

    // ── 8. GPS distance check ────────────────────────────────────────────────
    const { valid, distanceMetres } = isWithinRadius(
      userLat, userLng,
      drop.lat, drop.lng,
      drop.radius_meters
    );

    if (!valid) {
      return res.status(400).json({
        error: `You're ${distanceMetres}m away. Get within ${drop.radius_meters}m to claim.`,
        distanceMetres,
        radiusMetres: drop.radius_meters,
      });
    }

    // ── 9. All checks passed — issue claim token ─────────────────────────────
    const claimToken = issueClaimToken(dropId, walletAddress);
    console.log(`[Verify] ✅ ${walletAddress} verified for drop ${dropId} (${distanceMetres}m away)`);

    res.json({
      claimToken,
      distanceMetres,
      drop: {
        id: drop.id,
        name: drop.name,
        image_url: drop.image_url,
        supply: drop.supply,
        claimed_count: drop.claimed_count,
      },
    });
  } catch (err) {
    console.error("[POST /verify]", err);
    res.status(500).json({ error: "Verification failed" });
  }
});

module.exports = router;
