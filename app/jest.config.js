// jest-expo preset so tests run against the Expo/RN module resolution. The core
// logic under src/core is framework-agnostic TS, but the preset also lets later
// component tests import from react-native without extra setup.
module.exports = {
  preset: "jest-expo",
  transformIgnorePatterns: [
    "node_modules/(?!((jest-)?react-native|@react-native(-community)?|expo(nent)?|@expo(nent)?/.*|@expo-google-fonts/.*|react-navigation|@react-navigation/.*|@sentry/react-native|native-base|react-native-svg))",
  ],
};
