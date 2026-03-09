const { createUmi } = require("@metaplex-foundation/umi-bundle-defaults");
const {
  mplBubblegum,
  createTree,
  mintV1,
  findLeafAssetIdPda,
} = require("@metaplex-foundation/mpl-bubblegum");
const {
  keypairIdentity,
  publicKey,
  generateSigner,
  percentAmount,
  none,
  some,
} = require("@metaplex-foundation/umi");
const { bs58 } = require("@metaplex-foundation/umi/serializers");
const web3bs58 = require("bs58");

// ─── Network selection ───────────────────────────────────────────────────────
function getRpcUrl() {
  const network = process.env.SOLANA_NETWORK || "devnet";
  return network === "mainnet"
    ? process.env.SOLANA_RPC_MAINNET
    : process.env.SOLANA_RPC_DEVNET;
}

// ─── UMI instance (singleton) ────────────────────────────────────────────────
let _umi = null;

function getUmi() {
  if (_umi) return _umi;

  const rpcUrl = getRpcUrl();
  _umi = createUmi(rpcUrl).use(mplBubblegum());

  // Load drop authority from base58 private key
  const privKeyBase58 = process.env.DROP_AUTHORITY_PRIVATE_KEY;
  const privKeyBytes = web3bs58.decode(privKeyBase58);
  const keypair = _umi.eddsa.createKeypairFromSecretKey(privKeyBytes);
  _umi.use(keypairIdentity(keypair));

  return _umi;
}

/**
 * Create a new Merkle tree for a drop.
 * maxDepth=14 supports up to 16,384 NFTs.
 * Returns the tree address as a base58 string.
 */
async function createMerkleTree(supply) {
  const umi = getUmi();

  // Pick tree size based on supply
  let maxDepth = 14;
  let maxBufferSize = 64;
  if (supply <= 100) { maxDepth = 10; maxBufferSize = 32; }
  else if (supply <= 1000) { maxDepth = 14; maxBufferSize = 64; }
  else { maxDepth = 20; maxBufferSize = 256; }

  const merkleTree = generateSigner(umi);

  const builder = await createTree(umi, {
    merkleTree,
    maxDepth,
    maxBufferSize,
  });

  const { signature } = await builder.sendAndConfirm(umi);

  console.log(
    `[Solana] Merkle tree created: ${merkleTree.publicKey} (tx: ${Buffer.from(signature).toString("hex")})`
  );

  return merkleTree.publicKey.toString();
}

/**
 * Mint a compressed NFT to a recipient wallet.
 * Returns { txSignature, assetId }
 */
async function mintCompressedNFT(treeAddress, recipientWallet, metadata) {
  const umi = getUmi();

  const leafOwner = publicKey(recipientWallet);
  const merkleTree = publicKey(treeAddress);

  const { signature, result } = await mintV1(umi, {
    leafOwner,
    merkleTree,
    metadata: {
      name: metadata.name,
      symbol: metadata.symbol || "DROP",
      uri: metadata.uri,
      sellerFeeBasisPoints: percentAmount(0),
      collection: none(),
      creators: [
        {
          address: umi.identity.publicKey,
          verified: true,
          share: 100,
        },
      ],
      uses: none(),
      isMutable: true,
      primarySaleHappened: false,
      editionNonce: none(),
      tokenStandard: some({ __kind: "NonFungible" }),
      tokenProgramVersion: { __kind: "Original" },
    },
  }).sendAndConfirm(umi);

  const txSignature = Buffer.from(signature).toString("base64");
  console.log(`[Solana] cNFT minted to ${recipientWallet} | tx: ${txSignature}`);

  return { txSignature, assetId: null }; // assetId resolved via Helius DAS
}

/**
 * Get the drop authority public key (for display/verification)
 */
function getAuthorityPublicKey() {
  const umi = getUmi();
  return umi.identity.publicKey.toString();
}

module.exports = {
  createMerkleTree,
  mintCompressedNFT,
  getAuthorityPublicKey,
};
