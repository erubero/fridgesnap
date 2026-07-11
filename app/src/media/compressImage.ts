// Native side of the image pipeline: resize to <=1568px long edge and
// re-encode JPEG at 0.8, using the pure targetSize math from core so behavior
// matches the Swift ImagePipeline. Returns a CompressedImage (uri + dims) ready
// for upload.
import { ImageManipulator, SaveFormat } from "expo-image-manipulator";
import { targetSize, JPEG_QUALITY } from "../core/imagePipeline";
import type { CompressedImage } from "../services/interfaces";

export const compressImage = async (
  uri: string,
  width: number,
  height: number,
): Promise<CompressedImage> => {
  const target = targetSize({ width, height });

  const context = ImageManipulator.manipulate(uri);
  if (target.width !== width || target.height !== height) {
    context.resize({ width: target.width, height: target.height });
  }
  const rendered = await context.renderAsync();
  const result = await rendered.saveAsync({
    compress: JPEG_QUALITY,
    format: SaveFormat.JPEG,
  });

  return {
    uri: result.uri,
    width: result.width ?? target.width,
    height: result.height ?? target.height,
  };
};
