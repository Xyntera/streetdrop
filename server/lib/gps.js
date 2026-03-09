/**
 * Calculate distance in metres between two GPS coordinates
 * using the Haversine formula.
 */
function haversineDistance(lat1, lng1, lat2, lng2) {
  const R = 6371000; // Earth radius in metres
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

/**
 * Check if a coordinate is within a drop's radius.
 * Returns { valid: bool, distanceMetres: number }
 */
function isWithinRadius(userLat, userLng, dropLat, dropLng, radiusMetres) {
  const dist = haversineDistance(userLat, userLng, dropLat, dropLng);
  return {
    valid: dist <= radiusMetres,
    distanceMetres: Math.round(dist),
  };
}

/**
 * Build a bounding box for a lat/lng + km radius (for DB pre-filter)
 * Returns { minLat, maxLat, minLng, maxLng }
 */
function boundingBox(lat, lng, radiusKm) {
  const latDelta = radiusKm / 111;
  const lngDelta = radiusKm / (111 * Math.cos(toRad(lat)));
  return {
    minLat: lat - latDelta,
    maxLat: lat + latDelta,
    minLng: lng - lngDelta,
    maxLng: lng + lngDelta,
  };
}

module.exports = { haversineDistance, isWithinRadius, boundingBox };
