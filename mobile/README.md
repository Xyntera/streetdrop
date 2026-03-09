# StreetDrop — Setup & Run Guide

## 1. Run the Supabase schema

Open https://supabase.com/dashboard/project/ifwtadocbchcqcbqpqka/sql

Paste and run the contents of `server/db/schema.sql`

---

## 2. Fund your drop authority wallet on devnet

```bash
# Install Solana CLI if you don't have it
# https://docs.solana.com/cli/install-solana-cli-tools

solana airdrop 2 $(solana-keygen pubkey drop-authority.json) --url devnet
# Repeat 2-3 times to get enough SOL for tree creation
```

Your authority public key will show in the server logs on startup.

---

## 3. Start the server

```bash
cd server
npm install
npm run dev
```

Server starts on http://localhost:3001

Test it:
```bash
curl http://localhost:3001/health
```

Expected response:
```json
{
  "status": "ok",
  "network": "devnet",
  "authority": "YourPublicKeyHere..."
}
```

---

## 4. Start the mobile app

```bash
cd mobile
npm install
npx expo start
```

Scan the QR code with Expo Go on your phone.

> ⚠️ If testing on a real device (not emulator), change `EXPO_PUBLIC_API_URL` in `mobile/.env` to your machine's local IP:
> `EXPO_PUBLIC_API_URL=http://192.168.1.100:3001`

---

## 5. Test the full claim loop manually (before touching mobile)

```bash
# Create a test drop
curl -X POST http://localhost:3001/drops \
  -F "name=Test Drop" \
  -F "creatorWallet=YourWalletAddress" \
  -F "lat=37.7749" \
  -F "lng=-122.4194" \
  -F "radiusMeters=10000" \
  -F "supply=10" \
  -F "image=@/path/to/image.png"

# Verify location (use the drop ID from above)
curl -X POST http://localhost:3001/verify \
  -H "Content-Type: application/json" \
  -d '{
    "dropId": "YOUR-DROP-ID",
    "lat": 37.7749,
    "lng": -122.4194,
    "walletAddress": "YourWalletAddress",
    "timestamp": '"$(date +%s000)"'
  }'

# Mint (use claimToken from verify response)
curl -X POST http://localhost:3001/mint \
  -H "Content-Type: application/json" \
  -d '{"claimToken": "CLAIM-TOKEN-HERE"}'
```

---

## 6. Switch to mainnet

In `server/.env`:
```
SOLANA_NETWORK=mainnet
```

Make sure your drop authority wallet has real SOL for tree creation costs.

---

## Architecture recap

```
Mobile App (React Native + Expo)
    ↓  POST /verify { dropId, lat, lng, wallet }
Verify Server (Node.js)
    ↓  haversine check + JWT issue
    ↓  POST /mint { claimToken }
    ↓  Metaplex Bubblegum
Solana (devnet / mainnet)
    ↓  cNFT minted to wallet
    ↓  metadata pinned on Pinata IPFS
```

---

## Key files

| File | What it does |
|---|---|
| `server/routes/verify.js` | GPS validation — the anti-cheat core |
| `server/routes/mint.js` | Claim token → cNFT mint |
| `server/routes/drops.js` | Create + fetch drops |
| `server/lib/solana.js` | Bubblegum tree creation + minting |
| `server/lib/pinata.js` | IPFS metadata upload |
| `mobile/src/screens/MapScreen.js` | Live drop map |
| `mobile/src/screens/ClaimScreen.js` | GPS verify + mint flow |
| `mobile/src/screens/CreatorScreen.js` | Create a new drop |

---

## ⚠️ Rotate your keys after the hackathon

All keys in `.env` files are for development. Before going public:
- Regenerate Helius API key
- Regenerate Pinata JWT
- Regenerate Supabase service role key
- Transfer any funds out of the drop authority wallet and generate a new one
