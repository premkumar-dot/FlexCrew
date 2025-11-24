import React from "react";
import { Modal, View, Image, Text, TouchableOpacity, Linking, StyleSheet } from "react-native";

type Props = {
  visible: boolean;
  onClose: () => void;
  qrImage?: string | null;
  paymentUrl?: string | null;
};

export default function QRModal({ visible, onClose, qrImage, paymentUrl }: Props) {
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={styles.container}>
          <Text style={styles.title}>PayNow (bank direct)</Text>
          {qrImage ? (
            <Image source={{ uri: qrImage }} style={styles.qr} resizeMode="contain" />
          ) : (
            <Text>No QR available</Text>
          )}
          {paymentUrl ? (
            <TouchableOpacity
              onPress={() => Linking.openURL(paymentUrl)}
              style={styles.button}
            >
              <Text style={styles.buttonText}>Open Payment URL</Text>
            </TouchableOpacity>
          ) : null}
          <TouchableOpacity onPress={onClose} style={styles.close}>
            <Text style={styles.closeText}>Close</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: "rgba(0,0,0,0.5)", justifyContent: "center", alignItems: "center" },
  container: { width: "85%", backgroundColor: "white", padding: 16, borderRadius: 8, alignItems: "center" },
  title: { fontSize: 18, fontWeight: "600", marginBottom: 12 },
  qr: { width: 220, height: 220, marginBottom: 12 },
  button: { backgroundColor: "#007AFF", paddingHorizontal: 14, paddingVertical: 10, borderRadius: 6, marginBottom: 8 },
  buttonText: { color: "white", fontWeight: "600" },
  close: { padding: 8 },
  closeText: { color: "#333" },
});