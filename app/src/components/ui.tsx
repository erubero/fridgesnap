// Small shared UI kit in the brand palette (theme.ts). Plain StyleSheet.
import React from "react";
import {
  Text,
  Pressable,
  View,
  StyleSheet,
  ActivityIndicator,
  StyleProp,
  ViewStyle,
} from "react-native";
import { Colors, Radius, levelColors } from "../theme";
import { LazinessLevel, levelTitle } from "../core/types";

export const Button = ({
  title,
  onPress,
  variant = "primary",
  loading = false,
  disabled = false,
}: {
  title: string;
  onPress: () => void;
  variant?: "primary" | "dark" | "outline";
  loading?: boolean;
  disabled?: boolean;
}) => {
  const bg =
    variant === "primary"
      ? Colors.green
      : variant === "dark"
        ? Colors.ink
        : "transparent";
  const fg = variant === "outline" ? Colors.ink : "#fff";
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.btn,
        {
          backgroundColor: bg,
          borderWidth: variant === "outline" ? 1.5 : 0,
          borderColor: Colors.line,
          opacity: disabled ? 0.5 : pressed ? 0.85 : 1,
        },
      ]}
    >
      {loading ? (
        <ActivityIndicator color={fg} />
      ) : (
        <Text style={[styles.btnText, { color: fg }]}>{title}</Text>
      )}
    </Pressable>
  );
};

export const LevelBadge = ({ level }: { level: LazinessLevel }) => {
  const c = levelColors(level);
  return (
    <View style={[styles.badge, { backgroundColor: c.bg }]}>
      <Text style={[styles.badgeText, { color: c.fg }]}>
        {levelTitle(level).toUpperCase()}
      </Text>
    </View>
  );
};

export const MacroPill = ({ value, unit }: { value: string; unit: string }) => (
  <View style={styles.pill}>
    <Text style={styles.pillValue}>{value}</Text>
    <Text style={styles.pillUnit}>{unit}</Text>
  </View>
);

export const Card = ({
  children,
  style,
}: {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
}) => <View style={[styles.card, style]}>{children}</View>;

const styles = StyleSheet.create({
  btn: {
    height: 54,
    borderRadius: Radius.md,
    alignItems: "center",
    justifyContent: "center",
    paddingHorizontal: 20,
  },
  btnText: { fontSize: 17, fontWeight: "700" },
  badge: {
    alignSelf: "flex-start",
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 8,
  },
  badgeText: { fontSize: 12, fontWeight: "800", letterSpacing: 0.4 },
  pill: { alignItems: "center" },
  pillValue: { fontSize: 14, fontWeight: "700", color: Colors.ink },
  pillUnit: { fontSize: 11, color: Colors.inkMuted },
  card: {
    backgroundColor: Colors.card,
    borderRadius: Radius.md,
    borderWidth: 1,
    borderColor: Colors.line,
    padding: 18,
  },
});
