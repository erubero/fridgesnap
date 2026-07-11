// Design tokens ported from the Swift Theme.swift (official logo palette:
// sage green + warm cream). Plain constants + StyleSheet, no NativeWind, so the
// UI has zero build-config risk. Semantic freshness colors stay separate from
// brand green, same as iOS.
export const Colors = {
  green: "#74966A",
  greenDeep: "#4E6B45", // small text on white; sage alone is only 3.3:1
  greenLight: "#EDF2E9",
  greenBright: "#A9C49E",
  amber: "#C06515",
  amberLight: "#FCEFE2",
  purple: "#5A4FBF",
  purpleLight: "#E9E7F8",
  red: "#C0392B",
  redLight: "#FCE8E4",
  ink: "#1B1E1A",
  inkSoft: "#5A6057",
  inkMuted: "#9BA097",
  darkCard: "#252923",
  canvas: "#FEF5EF", // warm cream, never pure white
  card: "#FFFFFF",
  line: "#E7E9E2",
};

import type { LazinessLevel } from "./core/types";

// Per-mode badge colors, mirroring the iOS LevelBadge.
export const levelColors = (
  level: LazinessLevel,
): { fg: string; bg: string } => {
  switch (level) {
    case "lazy_af":
      return { fg: Colors.amber, bg: Colors.amberLight };
    case "some_effort":
      return { fg: Colors.greenDeep, bg: Colors.greenLight };
    case "chef_mode":
      return { fg: Colors.purple, bg: Colors.purpleLight };
  }
};

export const Radius = { sm: 12, md: 18, lg: 24 };
export const Spacing = { xs: 6, sm: 10, md: 16, lg: 22, xl: 32 };
