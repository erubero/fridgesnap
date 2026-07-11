// Client-side compression math before upload (spec section 4.1): max 1568px on
// the long edge, JPEG quality 0.8. Ported from Swift ImagePipeline.swift. Only
// the pure targetSize math lives here so it unit-tests without any native
// module; the actual pixel resize wraps expo-image-manipulator in the media
// layer (see media/compressImage.ts, added in the UI phase).

export const MAX_LONG_EDGE = 1568;
export const JPEG_QUALITY = 0.8;

export interface Size {
  width: number;
  height: number;
}

export const targetSize = (
  size: Size,
  maxLongEdge: number = MAX_LONG_EDGE,
): Size => {
  const longEdge = Math.max(size.width, size.height);
  if (longEdge <= maxLongEdge || longEdge <= 0) return size;
  const scale = maxLongEdge / longEdge;
  return {
    width: Math.round(size.width * scale),
    height: Math.round(size.height * scale),
  };
};
