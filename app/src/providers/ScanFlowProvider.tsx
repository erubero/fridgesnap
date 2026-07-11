// Drives the whole core loop: photos -> scan -> review -> level -> recipes.
// Ported from Swift ScanFlowModel; navigation uses expo-router instead of a
// NavigationPath, so this holds only the data + async actions.
import React, { createContext, useContext, useState, useCallback } from "react";
import { router } from "expo-router";
import { useServices } from "./ServicesProvider";
import { IngredientEditor } from "../core/ingredientEditor";
import { ServiceError, LazinessLevel } from "../core/types";
import type { CompressedImage } from "../services/interfaces";

export interface CapturedPhoto {
  uri: string;
  width: number;
  height: number;
}

interface ScanFlow {
  photos: CapturedPhoto[];
  editor: IngredientEditor;
  selectedLevel: LazinessLevel;
  servings: number;
  recipes: import("../core/types").Recipe[];
  isScanning: boolean;
  isGenerating: boolean;
  errorMessage: string | null;
  freeLimitHit: boolean;
  canAddMorePhotos: boolean;

  addPhoto(p: CapturedPhoto): void;
  removePhoto(index: number): void;
  setLevel(l: LazinessLevel): void;
  setServings(n: number): void;
  setEditor(e: IngredientEditor): void;
  clearError(): void;
  dismissFreeLimit(): void;

  runScan(compress: (p: CapturedPhoto) => Promise<CompressedImage>): Promise<void>;
  generate(regenerate?: boolean): Promise<void>;
  startOver(): void;
}

const MAX_PHOTOS = 5;
const ScanFlowContext = createContext<ScanFlow | null>(null);

export const ScanFlowProvider = ({
  children,
}: {
  children: React.ReactNode;
}) => {
  const services = useServices();

  const [photos, setPhotos] = useState<CapturedPhoto[]>([]);
  const [scanId, setScanId] = useState<string | null>(null);
  const [editor, setEditor] = useState(new IngredientEditor([]));
  const [selectedLevel, setSelectedLevel] = useState<LazinessLevel>("lazy_af");
  const [servings, setServings] = useState(2);
  const [recipes, setRecipes] = useState<import("../core/types").Recipe[]>([]);
  const [isScanning, setIsScanning] = useState(false);
  const [isGenerating, setIsGenerating] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [freeLimitHit, setFreeLimitHit] = useState(false);

  const addPhoto = useCallback((p: CapturedPhoto) => {
    setPhotos((cur) => (cur.length < MAX_PHOTOS ? [...cur, p] : cur));
  }, []);

  const removePhoto = useCallback((index: number) => {
    setPhotos((cur) => cur.filter((_, i) => i !== index));
  }, []);

  const runScan = useCallback(
    async (compress: (p: CapturedPhoto) => Promise<CompressedImage>) => {
      if (photos.length === 0 || isScanning) return;
      setIsScanning(true);
      setErrorMessage(null);
      try {
        const compressed = await Promise.all(photos.map(compress));
        const response = await services.scan.scan(compressed);
        setScanId(response.scan_id);
        setEditor(new IngredientEditor(response.ingredients, new Date()));
        services.analytics.log("scan_completed", {
          count: response.ingredients.length,
        });
        router.push("/review");
      } catch (e) {
        if (e instanceof ServiceError && e.kind === "free_limit_reached") {
          setFreeLimitHit(true);
        } else {
          setErrorMessage(e instanceof Error ? e.message : "Scan failed.");
        }
      } finally {
        setIsScanning(false);
      }
    },
    [photos, isScanning, services],
  );

  const generate = useCallback(
    async (regenerate = false) => {
      if (!scanId || isGenerating) return;
      setIsGenerating(true);
      setErrorMessage(null);
      try {
        const result = await services.generation.generate({
          scanId,
          ingredients: editor.requestIngredients,
          level: selectedLevel,
          servings,
        });
        setRecipes(result);
        services.analytics.log("recipes_generated", {
          level: selectedLevel,
          regenerate,
        });
        if (!regenerate) router.push("/results");
      } catch (e) {
        if (e instanceof ServiceError && e.kind === "free_limit_reached") {
          setFreeLimitHit(true);
        } else if (e instanceof ServiceError && e.kind === "rate_limited") {
          setErrorMessage(e.message);
        } else {
          setErrorMessage(e instanceof Error ? e.message : "Generation failed.");
        }
      } finally {
        setIsGenerating(false);
      }
    },
    [scanId, isGenerating, editor, selectedLevel, servings, services],
  );

  const startOver = useCallback(() => {
    setPhotos([]);
    setScanId(null);
    setEditor(new IngredientEditor([]));
    setRecipes([]);
    setErrorMessage(null);
    router.dismissAll();
  }, []);

  const value: ScanFlow = {
    photos,
    editor,
    selectedLevel,
    servings,
    recipes,
    isScanning,
    isGenerating,
    errorMessage,
    freeLimitHit,
    canAddMorePhotos: photos.length < MAX_PHOTOS,
    addPhoto,
    removePhoto,
    setLevel: setSelectedLevel,
    setServings,
    setEditor,
    clearError: () => setErrorMessage(null),
    dismissFreeLimit: () => setFreeLimitHit(false),
    runScan,
    generate,
    startOver,
  };

  return (
    <ScanFlowContext.Provider value={value}>
      {children}
    </ScanFlowContext.Provider>
  );
};

export const useScanFlow = (): ScanFlow => {
  const ctx = useContext(ScanFlowContext);
  if (!ctx) throw new Error("useScanFlow must be used within ScanFlowProvider");
  return ctx;
};
