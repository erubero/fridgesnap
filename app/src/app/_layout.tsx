import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { ServicesProvider } from "@/providers/ServicesProvider";
import { ScanFlowProvider } from "@/providers/ScanFlowProvider";
import { Colors } from "@/theme";

export default function RootLayout() {
  return (
    <ServicesProvider>
      <ScanFlowProvider>
        <StatusBar style="dark" />
        <Stack
          screenOptions={{
            headerStyle: { backgroundColor: Colors.canvas },
            headerTintColor: Colors.ink,
            headerTitleStyle: { fontWeight: "700" },
            contentStyle: { backgroundColor: Colors.canvas },
          }}
        >
          <Stack.Screen name="index" options={{ title: "Scan" }} />
          <Stack.Screen name="review" options={{ title: "Your ingredients" }} />
          <Stack.Screen name="effort" options={{ title: "Effort level" }} />
          <Stack.Screen name="results" options={{ title: "Pick one" }} />
          <Stack.Screen name="recipe" options={{ title: "" }} />
        </Stack>
      </ScanFlowProvider>
    </ServicesProvider>
  );
}
