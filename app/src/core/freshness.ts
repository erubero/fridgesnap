// Freshness helpers ported from the Swift Ingredient extension (DTOs.swift):
// due-date copy anchored to the scan date, plus category emoji. Pure functions
// so they unit-test without any UI.
import { Ingredient, Ripeness, ripenessLabel, isSpoiled } from "./types";

const DAY_MS = 24 * 60 * 60 * 1000;

const startOfDay = (d: Date): number => {
  const c = new Date(d);
  c.setHours(0, 0, 0, 0);
  return c.getTime();
};

const WEEKDAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

// "use today" / "use tomorrow" / "due Friday" / "due in N days", anchored to
// the scan date so due labels stay honest when an old scan is reused.
export const dueLabel = (
  ingredient: Ingredient,
  anchor: Date,
  now: Date = new Date(),
): string => {
  if (isSpoiled(ingredient)) return "past it, sorry";

  const due = new Date(anchor.getTime() + ingredient.perishability_days * DAY_MS);
  const days = Math.round((startOfDay(due) - startOfDay(now)) / DAY_MS);

  if (days < 0) return "past its date";
  if (days === 0) return "use today";
  if (days === 1) return "use tomorrow";
  if (days <= 6) return `due ${WEEKDAYS[due.getDay()]}`;
  if (days <= 20) return `due in ${days} days`;
  return `due in ${Math.floor(days / 7)} weeks`;
};

export const ripenessDisplay = (ingredient: Ingredient): string | null => {
  const r = ingredient.ripeness;
  if (!r || r === "not_applicable") return null;
  return ripenessLabel(r);
};

export const trimmedStorageTip = (ingredient: Ingredient): string | null => {
  const tip = ingredient.storage_tip?.trim();
  return tip ? tip : null;
};

const CATEGORY_EMOJI: Record<string, string> = {
  protein: "🍗",
  vegetable: "🥦",
  fruit: "🍎",
  dairy: "🧀",
  grain: "🍚",
  condiment: "🫙",
  beverage: "🥤",
};

export const categoryEmoji = (category: string): string =>
  CATEGORY_EMOJI[category] ?? "🍽️";

export type { Ripeness };
