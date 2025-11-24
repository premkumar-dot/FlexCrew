import React, { useState } from "react";
import { View, Text, TextInput, TouchableOpacity, StyleSheet, Alert } from "react-native";
import QRModal from "../components/QRModal";
import { createPayNowPayment } from "../services/paynow_service";

export default function WalletScreen() {
  const [amountText, setAmountText] = useState("");
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [paymentUrl, setPaymentUrl] = useState<string | null>(null);
  const [qrImage, setQrImage] = useState<string | null>(null);

  const onTopUp = async () => {
    const amount = Number(amountText);
    if (!amount || amount <= 0) {
      Alert.alert("Invalid amount");
      return;
    }
    try {
      setLoading(true);
      const result = await createPayNowPayment(amount);
      setPaymentUrl(result.paymentUrl || null);
      setQrImage(result.qrImage || null);
      setModalVisible(true);
    } catch (err: any) {
      Alert.alert("Top-up failed", err.message || String(err));
    } finally {
      setLoading(false);
    }
  };

  return (
    <View style={styles.page}>
      <Text style={styles.title}>Wallet Top-up (PayNow)</Text>
      <TextInput
        value={amountText}
        onChangeText={setAmountText}
        keyboardType="numeric"
        placeholder="Amount (SGD)"
        style={styles.input}
      />
      <TouchableOpacity style={styles.button} onPress={onTopUp} disabled={loading}>
        <Text style={styles.buttonText}>{loading ? "Processing..." : "PayNow (bank direct)"}</Text>
      </TouchableOpacity>

      <QRModal
        visible={modalVisible}
        onClose={() => setModalVisible(false)}
        qrImage={qrImage}
        paymentUrl={paymentUrl}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  page: { flex: 1, padding: 16, backgroundColor: "#fff" },
  title: { fontSize: 20, fontWeight: "600", marginBottom: 12 },
  input: {
    borderWidth: 1,
    borderColor: "#ddd",
    borderRadius: 6,
    padding: 10,
    marginBottom: 12,
    width: "50%",
  },
  button: { backgroundColor: "#007AFF", padding: 12, borderRadius: 6, width: "50%", alignItems: "center" },
  buttonText: { color: "white", fontWeight: "600" },
});