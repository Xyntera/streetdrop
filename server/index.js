require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { getAuthorityPublicKey } = require("./lib/solana");

const app = express();
const PORT = process.env.PORT || 3001;

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use(express.urlencoded({ extended: true }));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.use("/drops", require("./routes/drops"));
app.use("/verify", require("./routes/verify"));
app.use("/mint", require("./routes/mint"));

// ─── Health check ─────────────────────────────────────────────────────────────
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    network: process.env.SOLANA_NETWORK || "devnet",
    authority: getAuthorityPublicKey(),
    ts: new Date().toISOString(),
  });
});

// ─── Start ────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  const network = process.env.SOLANA_NETWORK || "devnet";
  console.log(`
  ╔══════════════════════════════════════╗
  ║     STREETDROP SERVER RUNNING        ║
  ║  Port:    ${PORT}                       ║
  ║  Network: ${network.padEnd(8)}               ║
  ╚══════════════════════════════════════╝
  `);
  console.log(`[Auth] Drop authority: ${getAuthorityPublicKey()}`);
  console.log(`[DB]   Supabase: ${process.env.SUPABASE_URL}`);
  console.log(`[IPFS] Pinata connected`);
  console.log(`\n  Health: http://localhost:${PORT}/health`);
  console.log(`  Drops:  http://localhost:${PORT}/drops/nearby?lat=0&lng=0`);
});

module.exports = app;
