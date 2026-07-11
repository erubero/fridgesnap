// Ingredient review: confirm, remove, add. Ported from Swift
// IngredientReviewView. Eat-me-first ordering and due labels come from core.
import React, { useState } from "react";
import {
  View,
  Text,
  ScrollView,
  Pressable,
  TextInput,
  StyleSheet,
} from "react-native";
import { router } from "expo-router";
import { useScanFlow } from "@/providers/ScanFlowProvider";
import { IngredientEditor } from "@/core/ingredientEditor";
import { dueLabel, categoryEmoji, ripenessDisplay } from "@/core/freshness";
import { isUseSoon, isSpoiled } from "@/core/types";
import { Button, Card } from "@/components/ui";
import { Colors, Spacing } from "@/theme";

export default function Review() {
  const flow = useScanFlow();
  const [query, setQuery] = useState("");
  const editor = flow.editor;
  const suggestions = IngredientEditor.matchingSuggestions(query, editor.ingredients);

  const add = (name: string) => {
    flow.setEditor(editor.add(name));
    setQuery("");
  };

  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.caption}>
          {editor.ingredients.length} items · {editor.useSoonCount} to use soon.
          Tap a card to remove it.
        </Text>

        {editor.ingredients.map((ing) => {
          const soon = isUseSoon(ing);
          const spoiled = isSpoiled(ing);
          const ripe = ripenessDisplay(ing);
          return (
            <Pressable key={ing.name} onPress={() => flow.setEditor(editor.remove(ing.name))}>
              <Card style={styles.row}>
                <Text style={styles.emoji}>{categoryEmoji(ing.category)}</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.name}>
                    {ing.name.charAt(0).toUpperCase() + ing.name.slice(1)}
                  </Text>
                  <Text style={styles.qty}>
                    {ing.quantity_estimate}
                    {ripe ? ` · ${ripe}` : ""}
                  </Text>
                </View>
                {ing.confidence === "low" && (
                  <Pressable
                    onPress={() => flow.setEditor(editor.confirm(ing.name))}
                    style={styles.chip}
                    hitSlop={8}
                  >
                    <Text style={styles.chipText}>?</Text>
                  </Pressable>
                )}
                <Text
                  style={[
                    styles.due,
                    spoiled ? styles.dueSpoiled : soon ? styles.dueSoon : styles.dueOk,
                  ]}
                >
                  {dueLabel(ing, flow.editor.scanDate)}
                </Text>
              </Card>
            </Pressable>
          );
        })}

        <View style={styles.addBox}>
          <TextInput
            value={query}
            onChangeText={setQuery}
            placeholder="Add something we missed"
            placeholderTextColor={Colors.inkMuted}
            style={styles.input}
            onSubmitEditing={() => query.trim() && add(query)}
            returnKeyType="done"
          />
          {suggestions.length > 0 && (
            <View style={styles.suggestions}>
              {suggestions.map((s) => (
                <Pressable key={s} onPress={() => add(s)} style={styles.suggestChip}>
                  <Text style={styles.suggestText}>{s}</Text>
                </Pressable>
              ))}
            </View>
          )}
        </View>
      </ScrollView>

      <View style={styles.footer}>
        <Button
          title="Pick an effort level"
          onPress={() => {
            if (editor.isEmpty) return;
            router.push("/effort");
          }}
          disabled={editor.isEmpty}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  content: { padding: Spacing.md, gap: Spacing.sm, paddingBottom: 24 },
  caption: { fontSize: 14, color: Colors.inkSoft, marginBottom: 4 },
  row: { flexDirection: "row", alignItems: "center", gap: 12 },
  emoji: { fontSize: 24 },
  name: { fontSize: 16, fontWeight: "700", color: Colors.ink },
  qty: { fontSize: 13, color: Colors.inkMuted },
  chip: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: Colors.greenLight,
    alignItems: "center",
    justifyContent: "center",
  },
  chipText: { color: Colors.greenDeep, fontWeight: "800" },
  due: { fontSize: 12, fontWeight: "700" },
  dueOk: { color: Colors.inkMuted },
  dueSoon: { color: Colors.amber },
  dueSpoiled: { color: Colors.red },
  addBox: { marginTop: 8, gap: 8 },
  input: {
    borderWidth: 1,
    borderColor: Colors.line,
    borderRadius: 14,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 15,
    color: Colors.ink,
    backgroundColor: Colors.card,
  },
  suggestions: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  suggestChip: {
    backgroundColor: Colors.greenLight,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 999,
  },
  suggestText: { color: Colors.greenDeep, fontWeight: "600", fontSize: 13 },
  footer: {
    padding: Spacing.md,
    borderTopWidth: 1,
    borderTopColor: Colors.line,
    backgroundColor: Colors.canvas,
  },
});
