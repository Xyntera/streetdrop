const axios = require("axios");
const FormData = require("form-data");
const fs = require("fs");

const JWT = process.env.PINATA_JWT;
const GATEWAY = "https://gateway.pinata.cloud/ipfs";

/**
 * Pin a file buffer to IPFS via Pinata.
 * Returns the IPFS URI: ipfs://CID
 */
async function pinFile(buffer, filename, mimeType) {
  const form = new FormData();
  form.append("file", buffer, { filename, contentType: mimeType });
  form.append(
    "pinataMetadata",
    JSON.stringify({ name: `streetdrop-${filename}` })
  );

  const res = await axios.post(
    "https://api.pinata.cloud/pinning/pinFileToIPFS",
    form,
    {
      headers: {
        Authorization: `Bearer ${JWT}`,
        ...form.getHeaders(),
      },
      maxBodyLength: Infinity,
    }
  );

  return `ipfs://${res.data.IpfsHash}`;
}

/**
 * Pin JSON metadata to IPFS.
 * Returns the IPFS URI: ipfs://CID
 */
async function pinJson(metadata, name) {
  const res = await axios.post(
    "https://api.pinata.cloud/pinning/pinJSONToIPFS",
    {
      pinataMetadata: { name: `streetdrop-meta-${name}` },
      pinataContent: metadata,
    },
    {
      headers: {
        Authorization: `Bearer ${JWT}`,
        "Content-Type": "application/json",
      },
    }
  );

  return `ipfs://${res.data.IpfsHash}`;
}

/**
 * Convert ipfs:// URI to a fetchable gateway URL
 */
function ipfsToHttp(uri) {
  if (uri.startsWith("ipfs://")) {
    return `${GATEWAY}/${uri.slice(7)}`;
  }
  return uri;
}

module.exports = { pinFile, pinJson, ipfsToHttp };
