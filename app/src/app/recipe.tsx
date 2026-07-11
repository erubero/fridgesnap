// Full recipe detail: macros, ingredients, steps. Ported from Swift
// RecipeDetailView. Cook Mode button is a placeholder until the Cook Mode
// milestone. Reads the recipe by index from the flow.
import React from "react";
import { View, Text, ScrollView, StyleSheet } from "react-native";
import { useLocalSearchParams } from "expo-router";
import { useScanFlow } from "@/providers/ScanFlowProvider";
import { levelEmoji, levelTitle } from "@/core/types";
import { Button } from "@/components/ui";
import { Colors, Spacing } from "@/theme";

const formatTimer = (seconds: number): string => {
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  if (m > 0 && s > 0) return `${m} min ${s} sec`;
  if (m > 0) return `${m} min`;
  return `${s} sec`;
};

export default function RecipeDetail() {
  const { index } = useLocalSearchParams<{ index: string }>();
  const flow = useScanFlow();
  const recipe = flow.recipes[Number(index) || 0];

  if (!recipe) {
    return (
      <View style={styles.centered}>
        <Text style={{ color: Colors.inkSoft }}>Recipe not found.</Text>
      </View>
    );
  }

  const n = recipe.nutrition_per_serving;

  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.meta}>
          {levelEmoji(recipe.level)} {levelTitle(recipe.level)} · {recipe.time_minutes} min ·
          serves {recipe.servings}
        </Text>
        <Text style={styles.title}>{recipe.title}</Text>
        <Text style={styles.desc}>{recipe.description}</Text>

        <View style={styles.macroPanel}>
          <Macro big value={`${n.calories}`} unit="kcal" />
          <Macro value={`${n.protein_g}g`} unit="protein" />
          <Macro value={`${n.carbs_g}g`} unit="carbs" />
          <Macro value={`${n.fat_g}g`} unit="fat" />
        </View>
        <Text style={styles.estimated}>Estimated per serving</Text>

        <Text style={styles.section}>Ingredients</Text>
        {recipe.ingredients.map((item) => (
          <View key={item.name + item.amount} style={styles.ingRow}>
            <Text style={styles.ingName}>
              {item.name.charAt(0).toUpperCase() + item.name.slice(1)}
            </Text>
            <Text style={styles.ingAmount}>{item.amount}</Text>
          </View>
        ))}

        <Text style={styles.section}>Steps</Text>
        {recipe.steps.map((step) => (
          <View key={step.order} style={styles.stepRow}>
            <Text style={styles.stepNum}>{step.order}</Text>
            <View style={{ flex: 1 }}>
              <Text style={styles.stepText}>{step.text}</Text>
              {step.timer_seconds != null && (
                <Text style={styles.timer}>⏱ {formatTimer(step.timer_seconds)}</Text>
              )}
            </View>
          </View>
        ))}
      </ScrollView>

      <View style={styles.footer}>
        <Button title="Start cooking (soon)" variant="primary" onPress={() => {}} disabled />
      </View>
    </View>
  );
}

const Macro = ({ value, unit, big }: { value: string; unit: string; big?: boolean }) => (
  <View style={{ alignItems: "center" }}>
    <Text style={[styles.macroValue, big && { color: Colors.greenBright }]}>{value}</Text>
    <Text style={styles.macroUnit}>{unit}</Text>
  </View>
);

const styles = StyleSheet.create({
  centered: { flex: 1, alignItems: "center", justifyContent: "center" },
  content: { padding: Spacing.md, gap: 8, paddingBottom: 24 },
  meta: { fontSize: 13, fontWeight: "600", color: Colors.inkMuted },
  title: { fontSize: 28, fontWeight: "800", color: Colors.ink },
  desc: { fontSize: 15, color: Colors.inkSoft, marginBottom: 8 },
  macroPanel: {
    flexDirection: "row",
    justifyContent: "space-between",
    backgroundColor: Colors.ink,
    borderRadius: 18,
    padding: 18,
  },
  macroValue: { fontSize: 18, fontWeight: "800", color: "#fff" },
  macroUnit: { fontSize: 11, color: "#B9BEB2", marginTop: 2 },
  estimated: { fontSize: 11, color: Colors.inkMuted, textAlign: "center", marginTop: 6 },
  section: { fontSize: 17, fontWeight: "800", color: Colors.ink, marginTop: 18, marginBottom: 6 },
  ingRow: { flexDirection: "row", justifyContent: "space-between", paddingVertical: 4 },
  ingName: { fontSize: 15, color: Colors.ink },
  ingAmount: { fontSize: 15, color: Colors.inkMuted },
  stepRow: { flexDirection: "row", gap: 12, paddingVertical: 8 },
  stepNum: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: Colors.greenLight,
    color: Colors.greenDeep,
    fontWeight: "800",
    textAlign: "center",
    lineHeight: 28,
    overflow: "hidden",
  },
  stepText: { fontSize: 15, color: Colors.ink, lineHeight: 21 },
  timer: { fontSize: 13, fontWeight: "700", color: Colors.amber, marginTop: 4 },
  footer: {
    padding: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.line,
    backgroundColor: Colors.canvas,
  },
});
