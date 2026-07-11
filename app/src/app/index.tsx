// Scan home: capture up to 5 photos (camera or library), then scan. Ported from
// the Swift ScanHomeView. Camera works on device; the library picker is also
// how you test on a simulator with no camera.
import React, { useState } from "react";
import {
  View,
  Text,
  ScrollView,
  Image,
  StyleSheet,
  Pressable,
  Alert,
} from "react-native";
import {
  CameraView,
  useCameraPermissions,
  type CameraCapturedPicture,
} from "expo-camera";
import * as ImagePicker from "expo-image-picker";
import { useScanFlow } from "@/providers/ScanFlowProvider";
import { compressImage } from "@/media/compressImage";
import { LoadingOverlay } from "@/components/LoadingOverlay";
import { Button } from "@/components/ui";
import { Colors, Spacing, Radius } from "@/theme";

export default function ScanHome() {
  const flow = useScanFlow();
  const [permission, requestPermission] = useCameraPermissions();
  const [cameraOpen, setCameraOpen] = useState(false);
  const cameraRef = React.useRef<CameraView>(null);

  const openCamera = async () => {
    if (!permission?.granted) {
      const res = await requestPermission();
      if (!res.granted) {
        Alert.alert("Camera access needed", "Enable it in Settings to snap your fridge.");
        return;
      }
    }
    setCameraOpen(true);
  };

  const capture = async () => {
    const photo: CameraCapturedPicture | undefined =
      await cameraRef.current?.takePictureAsync();
    if (photo) {
      flow.addPhoto({ uri: photo.uri, width: photo.width, height: photo.height });
    }
    setCameraOpen(false);
  };

  const pickFromLibrary = async () => {
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ["images"],
      allowsMultipleSelection: true,
      selectionLimit: 5 - flow.photos.length,
    });
    if (!res.canceled) {
      res.assets.forEach((a) =>
        flow.addPhoto({ uri: a.uri, width: a.width ?? 0, height: a.height ?? 0 }),
      );
    }
  };

  if (cameraOpen) {
    return (
      <View style={styles.cameraWrap}>
        <CameraView ref={cameraRef} style={StyleSheet.absoluteFill} facing="back" />
        <View style={styles.cameraControls}>
          <Pressable onPress={() => setCameraOpen(false)} hitSlop={12}>
            <Text style={styles.cameraCancel}>Cancel</Text>
          </Pressable>
          <Pressable onPress={capture} style={styles.shutter} />
          <View style={{ width: 60 }} />
        </View>
      </View>
    );
  }

  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={styles.content}>
        {flow.photos.length === 0 ? (
          <View style={styles.empty}>
            <Text style={styles.emptyEmoji}>📸</Text>
            <Text style={styles.emptyTitle}>Point the camera at the problem</Text>
            <Text style={styles.emptyBody}>
              Take up to 5 photos of your fridge, pantry, or counter. We will
              figure out dinner from there.
            </Text>
          </View>
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.strip}>
            {flow.photos.map((p, i) => (
              <View key={`${p.uri}-${i}`} style={styles.thumbWrap}>
                <Image source={{ uri: p.uri }} style={styles.thumb} />
                <Pressable onPress={() => flow.removePhoto(i)} style={styles.thumbX} hitSlop={8}>
                  <Text style={styles.thumbXText}>✕</Text>
                </Pressable>
              </View>
            ))}
          </ScrollView>
        )}

        <View style={styles.captureRow}>
          <View style={{ flex: 1 }}>
            <Button
              title="Camera"
              variant="outline"
              onPress={openCamera}
              disabled={!flow.canAddMorePhotos}
            />
          </View>
          <View style={{ flex: 1 }}>
            <Button
              title="Photos"
              variant="outline"
              onPress={pickFromLibrary}
              disabled={!flow.canAddMorePhotos}
            />
          </View>
        </View>

        <Button
          title={
            flow.photos.length === 0
              ? "Add a photo to scan"
              : `Scan ${flow.photos.length} photo${flow.photos.length === 1 ? "" : "s"}`
          }
          onPress={() => flow.runScan((p) => compressImage(p.uri, p.width, p.height))}
          disabled={flow.photos.length === 0}
        />
      </ScrollView>

      {(flow.isScanning || flow.isGenerating) && (
        <LoadingOverlay
          message={flow.isScanning ? "Reading your fridge..." : "Inventing dinner..."}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.md, gap: Spacing.md },
  empty: { alignItems: "center", paddingVertical: 48, gap: 10 },
  emptyEmoji: { fontSize: 52 },
  emptyTitle: { fontSize: 20, fontWeight: "800", color: Colors.ink, textAlign: "center" },
  emptyBody: { fontSize: 15, color: Colors.inkSoft, textAlign: "center", paddingHorizontal: 20 },
  strip: { flexGrow: 0 },
  thumbWrap: { marginRight: 10 },
  thumb: { width: 110, height: 150, borderRadius: Radius.sm },
  thumbX: {
    position: "absolute",
    top: 6,
    right: 6,
    backgroundColor: "rgba(0,0,0,0.6)",
    width: 24,
    height: 24,
    borderRadius: 12,
    alignItems: "center",
    justifyContent: "center",
  },
  thumbXText: { color: "#fff", fontSize: 12, fontWeight: "700" },
  captureRow: { flexDirection: "row", gap: Spacing.sm },
  cameraWrap: { flex: 1, backgroundColor: "#000" },
  cameraControls: {
    position: "absolute",
    bottom: 48,
    left: 0,
    right: 0,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    paddingHorizontal: 32,
  },
  cameraCancel: { color: "#fff", fontSize: 16, fontWeight: "600", width: 60 },
  shutter: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: "#fff",
    borderWidth: 4,
    borderColor: "rgba(255,255,255,0.5)",
  },
});
