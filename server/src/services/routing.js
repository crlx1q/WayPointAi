import { cached } from './cache.js';
import { fetchJson } from './http.js';

const DAY = 24 * 3600;

/**
 * Маршрут через публичный OSRM (бесплатно): полилиния + дистанция + время.
 * points: [{lat, lon}, ...], profile: foot | driving
 */
export async function buildRoute(points, profile = 'foot') {
  if (!points || points.length < 2) return null;
  const osrmProfile = profile === 'driving' ? 'driving' : 'foot';
  const coords = points.map((p) => `${p.lon},${p.lat}`).join(';');
  const key = `route:${osrmProfile}:${coords}`;
  return cached(key, DAY, async () => {
    const url = `https://router.project-osrm.org/route/v1/${osrmProfile}/${coords}?overview=full&geometries=geojson`;
    const data = await fetchJson(url, { timeoutMs: 20000 });
    const route = data.routes?.[0];
    if (!route) return null;
    return {
      polyline: route.geometry.coordinates.map(([lon, lat]) => [lat, lon]),
      distanceKm: +(route.distance / 1000).toFixed(2),
      durationMin: Math.round(route.duration / 60),
      profile: osrmProfile
    };
  });
}

/** Deep-link в Google Maps по точкам маршрута. */
export function googleMapsDirUrl(points, mode = 'walking') {
  if (!points || points.length === 0) return null;
  const origin = points[0];
  const destination = points[points.length - 1];
  const waypoints = points.slice(1, -1);
  const params = new URLSearchParams({
    api: '1',
    origin: `${origin.lat},${origin.lon}`,
    destination: `${destination.lat},${destination.lon}`,
    travelmode: mode
  });
  if (waypoints.length) {
    params.set('waypoints', waypoints.map((p) => `${p.lat},${p.lon}`).join('|'));
  }
  return `https://www.google.com/maps/dir/?${params.toString()}`;
}

/** Deep-link в Google Maps на одну точку. */
export function googleMapsPlaceUrl(lat, lon, name) {
  const params = new URLSearchParams({ api: '1', query: name ? `${name} ${lat},${lon}` : `${lat},${lon}` });
  return `https://www.google.com/maps/search/?${params.toString()}`;
}
