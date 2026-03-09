const jwt = require("jsonwebtoken");

const SECRET = process.env.JWT_SECRET;
const TTL = parseInt(process.env.CLAIM_TOKEN_TTL_SECONDS || "90", 10);

/**
 * Issue a short-lived claim token authorising one specific wallet
 * to mint one specific drop.
 */
function issueClaimToken(dropId, walletAddress) {
  return jwt.sign({ dropId, walletAddress }, SECRET, { expiresIn: TTL });
}

/**
 * Verify a claim token. Returns decoded payload or throws.
 */
function verifyClaimToken(token) {
  return jwt.verify(token, SECRET);
}

module.exports = { issueClaimToken, verifyClaimToken };
