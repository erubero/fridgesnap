// Three recipe options plus regenerate. Ported from Swift RecipeResultsView.
import React from "react";
import { View, Text, ScrollView, Pressable, StyleSheet } from "react-native";
import { router } from "expo-router";
import { useScanFlow } from "@/providers/ScanFlowProvider";
import { LevelBadge, MacroPill, Card, Button } from "@/components/ui";
import { Colors, Spacing } from "@/theme";

export default function Results() {
  const flow = useScanFlow();

  return (
    <ScrollView contentContainerStyle={styles.content}>
      {flow.recipes.map((recipe, index) => (
        <Pressable
          key={recipe.id ?? recipe.title}
          onPress={() => router.push({ pathname: "/recipe", params: { index: String(index) } })}
        >
          <Card style={{ gap: 10 }}>
            <View style={styles.head}>
              <LevelBadge level={recipe.level} />
              <Text style={styles.meta}>
                {recipe.time_minutes} min · {recipe.steps.length} steps
              </Text>
            </View>
            <Text style={styles.title}>{recipe.title}</Text>
            <Text style={styles.desc}>{recipe.description}</Text>
            <View style={styles.macros}>
              <MacroPill value={`${recipe.nutrition_per_serving.calories}`} unit="cal" />
              <MacroPill value={`${recipe.nutrition_per_serving.protein_g}g`} unit="protein" />
              <MacroPill value={`${recipe.nutrition_per_serving.carbs_g}g`} unit="carbs" />
              <MacroPill value={`${recipe.nutrition_per_serving.fat_g}g`} unit="fat" />
            </View>
          </Card>
        </Pressable>
      ))}

      <Button
        title="None of these. Regenerate"
        variant="outline"
        loading={flow.isGenerating}
        onPress={() => flow.generate(true)}
      />
      {flow.errorMessage && <Text style={styles.error}>{flow.errorMessage}</Text>}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.md, gap: Spacing.md },
  head: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  meta: { fontSize: 12, color: Colors.inkMuted },
  title: { fontSize: 19, fontWeight: "800", color: Colors.ink },
  desc: { fontSize: 14, color: Colors.inkSoft },
  macros: { flexDirection: "row", gap: 18 },
  error: { color: Colors.red, fontSize: 13, textAlign: "center" },
});
