const express = require("express");
const router = express.Router();
const supabase = require("../lib/supabase");
const { verifyClaimToken } = require("../lib/jwt");
const { mintCompressedNFT } = require("../lib/solana");

// ─── POST /mint ──────────────────────────────────────────────────────────────
// Body: { claimToken }
// Returns: { txSignature, assetId, nft }
router.post("/", async (req, res) => {
  try {
    const { claimToken } = req.body;

    if (!claimToken) {
      return res.status(400).json({ error: "claimToken required" });
    }

    // ── 1. Verify claim token (checks signature + expiry) ────────────────────
    let payload;
    try {
      payload = verifyClaimToken(claimToken);
    } catch (err) {
      return res.status(401).json({ error: "Invalid or expired claim token. Please re-verify your location." });
    }

    const { dropId, walletAddress } = payload;

    // ── 2. Re-check wallet hasn't already claimed (race condition guard) ──────
    const { data: existingClaim } = await supabase
      .from("claims")
      .select("id, tx_signature")
      .eq("drop_id", dropId)
      .eq("wallet_address", walletAddress)
      .maybeSingle();

    if (existingClaim) {
      return res.status(400).json({
        error: "Already claimed",
        txSignature: existingClaim.tx_signature,
      });
    }

    // ── 3. Load drop ─────────────────────────────────────────────────────────
    const { data: drop, error: dropErr } = await supabase
      .from("drops")
      .select("*")
      .eq("id", dropId)
      .single();

    if (dropErr || !drop) {
      return res.status(404).json({ error: "Drop not found" });
    }

    if (!drop.tree_address) {
      return res.status(500).json({ error: "Drop Merkle tree not ready yet" });
    }

    // ── 4. Re-check supply (another race condition guard) ────────────────────
    if (drop.claimed_count >= drop.supply) {
      return res.status(400).json({ error: "Drop is sold out" });
    }

    // ── 5. Mint the compressed NFT ───────────────────────────────────────────
    console.log(`[Mint] Minting for ${walletAddress} on drop ${dropId}...`);

    const claimNumber = drop.claimed_count + 1;

    const metadata = {
      name: `${drop.name} #${claimNumber}`,
      symbol: "DROP",
      uri: drop.metadata_uri,
    };

    const { txSignature } = await mintCompressedNFT(
      drop.tree_address,
      walletAddress,
      metadata
    );

    // ── 6. Record the claim ───────────────────────────────────────────────────
    const { error: claimErr } = await supabase.from("claims").insert({
      drop_id: dropId,
      wallet_address: walletAddress,
      tx_signature: txSignature,
    });

    if (claimErr) {
      console.error("[Mint] Failed to record claim:", claimErr);
      // Don't fail — NFT already minted. Log and continue.
    }

    // ── 7. Increment claimed_count ────────────────────────────────────────────
    await supabase
      .from("drops")
      .update({ claimed_count: claimNumber })
      .eq("id", dropId);

    console.log(`[Mint] ✅ Success! claim #${claimNumber}/${drop.supply} | tx: ${txSignature}`);

    res.json({
      success: true,
      txSignature,
      claimNumber,
      totalSupply: drop.supply,
      nft: {
        name: metadata.name,
        image: drop.image_url,
        drop: drop.name,
      },
    });
  } catch (err) {
    console.error("[POST /mint]", err);
    res.status(500).json({ error: err.message || "Minting failed" });
  }
});

module.exports = router;
