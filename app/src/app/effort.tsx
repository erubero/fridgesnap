// Effort selector. Ported from Swift LazinessSelectorView: mode cards, green
// selected state, servings stepper, generate.
import React from "react";
import { View, Text, ScrollView, Pressable, StyleSheet } from "react-native";
import { useScanFlow } from "@/providers/ScanFlowProvider";
import { LAZINESS_LEVELS, levelTitle, levelBlurb } from "@/core/types";
import { Button } from "@/components/ui";
import { Colors, Spacing, Radius } from "@/theme";

export default function Effort() {
  const flow = useScanFlow();

  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>How much do you care right now?</Text>
        <Text style={styles.sub}>No judgment. Okay, mild judgment.</Text>

        {LAZINESS_LEVELS.map((level) => {
          const selected = flow.selectedLevel === level;
          return (
            <Pressable
              key={level}
              onPress={() => flow.setLevel(level)}
              style={[styles.card, selected && styles.cardSelected]}
            >
              <View style={styles.cardHead}>
                <Text style={styles.cardTitle}>{levelTitle(level)}</Text>
                {selected && <Text style={styles.check}>✓</Text>}
              </View>
              <Text style={styles.blurb}>{levelBlurb(level)}</Text>
            </Pressable>
          );
        })}

        <View style={styles.stepper}>
          <Text style={styles.stepperLabel}>Servings: {flow.servings}</Text>
          <View style={styles.stepperBtns}>
            <Pressable
              onPress={() => flow.setServings(Math.max(1, flow.servings - 1))}
              style={styles.stepBtn}
            >
              <Text style={styles.stepBtnText}>−</Text>
            </Pressable>
            <Pressable
              onPress={() => flow.setServings(Math.min(8, flow.servings + 1))}
              style={styles.stepBtn}
            >
              <Text style={styles.stepBtnText}>+</Text>
            </Pressable>
          </View>
        </View>
      </ScrollView>

      <View style={styles.footer}>
        <Button
          title="Make my recipe"
          variant="dark"
          loading={flow.isGenerating}
          onPress={() => flow.generate(false)}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.md, gap: Spacing.sm },
  title: { fontSize: 22, fontWeight: "800", color: Colors.ink },
  sub: { fontSize: 14, color: Colors.inkSoft, marginBottom: 8 },
  card: {
    borderRadius: Radius.lg,
    borderWidth: 1.5,
    borderColor: Colors.line,
    backgroundColor: Colors.card,
    padding: Spacing.lg,
    gap: 8,
  },
  cardSelected: { borderColor: Colors.green, borderWidth: 2, backgroundColor: Colors.greenLight },
  cardHead: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  cardTitle: { fontSize: 19, fontWeight: "800", color: Colors.ink },
  check: {
    color: "#fff",
    fontWeight: "800",
    backgroundColor: Colors.green,
    width: 26,
    height: 26,
    borderRadius: 13,
    textAlign: "center",
    lineHeight: 26,
    overflow: "hidden",
  },
  blurb: { fontSize: 14, color: Colors.inkSoft },
  stepper: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginTop: 8,
    paddingHorizontal: 4,
  },
  stepperLabel: { fontSize: 16, fontWeight: "600", color: Colors.ink },
  stepperBtns: { flexDirection: "row", gap: 10 },
  stepBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: Colors.line,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: Colors.card,
  },
  stepBtnText: { fontSize: 22, fontWeight: "700", color: Colors.ink },
  footer: {
    padding: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.line,
    backgroundColor: Colors.canvas,
  },
});
