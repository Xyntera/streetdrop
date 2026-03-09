const express = require("express");
const multer = require("multer");
const router = express.Router();
const supabase = require("../lib/supabase");
const { pinFile, pinJson } = require("../lib/pinata");
const { createMerkleTree } = require("../lib/solana");
const { boundingBox } = require("../lib/gps");

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// ─── GET /drops/nearby?lat=&lng=&radius=5 ───────────────────────────────────
router.get("/nearby", async (req, res) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lng = parseFloat(req.query.lng);
    const radiusKm = parseFloat(req.query.radius || "5");

    if (isNaN(lat) || isNaN(lng)) {
      return res.status(400).json({ error: "lat and lng required" });
    }

    const box = boundingBox(lat, lng, radiusKm);
    const now = new Date().toISOString();

    const { data, error } = await supabase
      .from("drops")
      .select("id, name, description, image_url, lat, lng, radius_meters, supply, claimed_count, ends_at")
      .eq("is_active", true)
      .lte("starts_at", now)
      .gte("ends_at", now)
      .gte("lat", box.minLat)
      .lte("lat", box.maxLat)
      .gte("lng", box.minLng)
      .lte("lng", box.maxLng);

    if (error) throw error;

    // Filter out fully claimed drops
    const available = data.filter((d) => d.claimed_count < d.supply);

    res.json({ drops: available });
  } catch (err) {
    console.error("[GET /drops/nearby]", err);
    res.status(500).json({ error: "Failed to fetch drops" });
  }
});

// ─── GET /drops/:id ──────────────────────────────────────────────────────────
router.get("/:id", async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("drops")
      .select("*")
      .eq("id", req.params.id)
      .single();

    if (error || !data) return res.status(404).json({ error: "Drop not found" });

    res.json({ drop: data });
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch drop" });
  }
});

// ─── POST /drops — create a new drop ────────────────────────────────────────
// Fields: name, description, creatorWallet, lat, lng, radiusMeters, supply, startsAt, endsAt
// File: image (multipart)
router.post("/", upload.single("image"), async (req, res) => {
  try {
    const {
      name, description, creatorWallet,
      lat, lng, radiusMeters,
      supply, startsAt, endsAt,
    } = req.body;

    if (!req.file) return res.status(400).json({ error: "Image required" });
    if (!name || !creatorWallet || !lat || !lng || !supply) {
      return res.status(400).json({ error: "Missing required fields" });
    }

    // 1. Pin image to IPFS via Pinata
    console.log("[Drop] Pinning image to IPFS...");
    const imageUri = await pinFile(
      req.file.buffer,
      req.file.originalname,
      req.file.mimetype
    );

    // 2. Pin metadata JSON
    console.log("[Drop] Pinning metadata to IPFS...");
    const metadataUri = await pinJson(
      {
        name,
        symbol: "DROP",
        description: description || `StreetDrop: ${name}`,
        image: imageUri,
        attributes: [
          { trait_type: "Location", value: `${parseFloat(lat).toFixed(4)}, ${parseFloat(lng).toFixed(4)}` },
          { trait_type: "Drop Date", value: new Date(startsAt || Date.now()).toISOString().split("T")[0] },
          { trait_type: "Supply", value: String(supply) },
        ],
        properties: { files: [{ uri: imageUri, type: req.file.mimetype }] },
      },
      name.replace(/\s+/g, "-").toLowerCase()
    );

    // 3. Create Merkle tree on Solana
    console.log("[Drop] Creating Merkle tree on Solana...");
    const treeAddress = await createMerkleTree(parseInt(supply));

    // 4. Save to Supabase
    const { data, error } = await supabase
      .from("drops")
      .insert({
        name,
        description,
        image_url: imageUri,
        metadata_uri: metadataUri,
        creator_wallet: creatorWallet,
        lat: parseFloat(lat),
        lng: parseFloat(lng),
        radius_meters: parseInt(radiusMeters) || 50,
        supply: parseInt(supply),
        starts_at: startsAt || new Date().toISOString(),
        ends_at: endsAt || new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
        tree_address: treeAddress,
      })
      .select()
      .single();

    if (error) throw error;

    console.log(`[Drop] Created: ${data.id} | tree: ${treeAddress}`);
    res.status(201).json({ drop: data });
  } catch (err) {
    console.error("[POST /drops]", err);
    res.status(500).json({ error: err.message || "Failed to create drop" });
  }
});

module.exports = router;
