import React from "react";
import { View, Text, TouchableOpacity, StyleSheet } from "react-native";

export default function SignInScreen({ navigation }: any) {
  const onGoogleSignIn = async () => {
    // call your google sign-in logic
  };

  return (
    <View style={styles.page}>
      <Text style={styles.title}>Sign in</Text>

      <TouchableOpacity style={styles.googleButton} onPress={onGoogleSignIn}>
        <Text style={styles.googleText}>Sign in with Google</Text>
      </TouchableOpacity>

      {/* Moved below Google button: Create Account then Forgot Password (swapped) */}
      <TouchableOpacity style={styles.link} onPress={() => navigation.navigate("CreateAccount")}>
        <Text style={styles.linkText}>Create Account</Text>
      </TouchableOpacity>

      <TouchableOpacity style={styles.link} onPress={() => navigation.navigate("ForgotPassword")}>
        <Text style={styles.linkText}>Forgot password?</Text>
      </TouchableOpacity>

      {/* other email/password form here if needed */}
    </View>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1, padding: 16, backgroundColor: "#fff" },
  title: { fontSize: 24, marginBottom: 16 },
  googleButton: { backgroundColor: "#4285F4", padding: 12, borderRadius: 6, alignItems: "center", marginBottom: 12 },
  googleText: { color: "white", fontWeight: "600" },
  link: { paddingVertical: 8 },
  linkText: { color: "#007AFF" },
});