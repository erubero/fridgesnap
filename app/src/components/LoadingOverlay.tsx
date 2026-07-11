// Full-screen wait state shown while a scan or generation call runs. Plays one
// of the owner's Lottie loaders at random, ported from the Swift LoadingOverlay.
import React, { useRef } from "react";
import { View, Text, StyleSheet } from "react-native";
import LottieView from "lottie-react-native";
import { Colors } from "../theme";

const ANIMATIONS = [
  require("../../assets/animations/cooking-food.json"),
  require("../../assets/animations/food.json"),
  require("../../assets/animations/food-alt.json"),
  require("../../assets/animations/fried-food.json"),
];

export const LoadingOverlay = ({ message }: { message: string }) => {
  // Pick once per mount so a single wait does not reshuffle on re-render.
  const source = useRef(
    ANIMATIONS[Math.floor(Math.random() * ANIMATIONS.length)],
  ).current;

  return (
    <View style={styles.overlay}>
      <LottieView autoPlay loop source={source} style={styles.lottie} />
      <Text style={styles.message}>{message}</Text>
      <Text style={styles.sub}>Takes a few seconds</Text>
    </View>
  );
};

const styles = StyleSheet.create({
  overlay: {
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: Colors.canvas,
    alignItems: "center",
    justifyContent: "center",
    zIndex: 10,
  },
  lottie: { width: 220, height: 220 },
  message: { fontSize: 18, fontWeight: "700", color: Colors.ink, marginTop: 4 },
  sub: { fontSize: 13, color: Colors.inkMuted, marginTop: 2 },
});
