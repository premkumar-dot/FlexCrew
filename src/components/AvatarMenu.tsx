import React from "react";
import { View, TouchableOpacity, Image, Text, StyleSheet } from "react-native";
import { useNavigation } from "@react-navigation/native";
import auth from "@react-native-firebase/auth";

/**
 * Simple AvatarMenu - include in your header on screens.
 * - Make sure your app passes the user photoURL to this component where available
 */
export default function AvatarMenu({ photoURL }: { photoURL?: string | null }) {
  const nav = useNavigation();

  const onPress = () => {
    // Navigate to profile/edit profile
    nav.navigate("Profile" as never);
  };

  const onSignOut = async () => {
    await auth().signOut();
    nav.navigate("SignIn" as never);
  };

  return (
    <View style={styles.container}>
      <TouchableOpacity onPress={onPress} style={styles.touch}>
        {photoURL ? <Image source={{ uri: photoURL }} style={styles.avatar} /> : <Text style={styles.letter}>U</Text>}
      </TouchableOpacity>
      <TouchableOpacity onPress={onSignOut} style={styles.signOut}>
        <Text style={styles.signOutText}>Sign out</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flexDirection: "row", alignItems: "center" },
  touch: { marginRight: 8 },
  avatar: { width: 36, height: 36, borderRadius: 18 },
  letter: { width: 36, height: 36, textAlign: "center", lineHeight: 36, backgroundColor: "#ccc", borderRadius: 18 },
  signOut: { paddingHorizontal: 8 },
  signOutText: { color: "#c00" },
});